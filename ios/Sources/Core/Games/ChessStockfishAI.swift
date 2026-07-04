import Foundation

#if canImport(StockFishKit_iOS)
import StockFishKit_iOS
#endif

extension Position {
    func stockfishFEN(fullmoveNumber: Int = 1) -> String {
        [
            fenBoard,
            sideToMove == .white ? "w" : "b",
            fenCastlingRights,
            enPassant?.algebraic ?? "-",
            "\(halfmoveClock)",
            "\(max(1, fullmoveNumber))"
        ].joined(separator: " ")
    }

    private var fenBoard: String {
        (0..<8).reversed().map { rank in
            var emptyCount = 0
            var row = ""
            for file in 0..<8 {
                if let piece = piece(at: Square(file: file, rank: rank)) {
                    if emptyCount > 0 {
                        row += "\(emptyCount)"
                        emptyCount = 0
                    }
                    row += piece.fenLetter
                } else {
                    emptyCount += 1
                }
            }
            if emptyCount > 0 { row += "\(emptyCount)" }
            return row
        }.joined(separator: "/")
    }

    private var fenCastlingRights: String {
        var rights = ""
        if castling.whiteKingside { rights += "K" }
        if castling.whiteQueenside { rights += "Q" }
        if castling.blackKingside { rights += "k" }
        if castling.blackQueenside { rights += "q" }
        return rights.isEmpty ? "-" : rights
    }
}

extension Piece {
    fileprivate var fenLetter: String {
        let letter: String
        switch type {
        case .pawn: letter = "p"
        case .knight: letter = "n"
        case .bishop: letter = "b"
        case .rook: letter = "r"
        case .queen: letter = "q"
        case .king: letter = "k"
        }
        return color == .white ? letter.uppercased() : letter
    }
}

extension Square {
    init?(algebraic: String) {
        guard algebraic.count == 2,
              let fileScalar = algebraic.unicodeScalars.first,
              let rankScalar = algebraic.unicodeScalars.dropFirst().first else {
            return nil
        }
        let file = Int(fileScalar.value) - Int(UnicodeScalar("a").value)
        let rank = Int(rankScalar.value) - Int(UnicodeScalar("1").value)
        guard let square = Square.at(file: file, rank: rank) else { return nil }
        self = square
    }
}

extension Move {
    var uciNotation: String {
        var value = from.algebraic + to.algebraic
        if let promotion {
            value += promotion.uciPromotionLetter
        }
        return value
    }

    static func fromUCI(_ uci: String, in position: Position) -> Move? {
        let trimmed = uci.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 4 else { return nil }
        let start = trimmed.startIndex
        let fromEnd = trimmed.index(start, offsetBy: 2)
        let toEnd = trimmed.index(start, offsetBy: 4)
        guard let from = Square(algebraic: String(trimmed[start..<fromEnd])),
              let to = Square(algebraic: String(trimmed[fromEnd..<toEnd])) else {
            return nil
        }
        let promotion: PieceType?
        if trimmed.count >= 5 {
            promotion = PieceType(uciPromotionLetter: String(trimmed[toEnd]))
        } else {
            promotion = nil
        }
        return MoveGenerator.legalMoves(in: position).first {
            $0.from == from && $0.to == to && $0.promotion == promotion
        }
    }
}

extension PieceType {
    fileprivate var uciPromotionLetter: String {
        switch self {
        case .queen: return "q"
        case .rook: return "r"
        case .bishop: return "b"
        case .knight: return "n"
        case .pawn, .king: return ""
        }
    }

    fileprivate init?(uciPromotionLetter: String) {
        switch uciPromotionLetter {
        case "q": self = .queen
        case "r": self = .rook
        case "b": self = .bishop
        case "n": self = .knight
        default: return nil
        }
    }
}

actor StockfishResponseRouter {
    private struct Pending {
        let id: UUID
        let continuation: CheckedContinuation<String?, Never>
    }

    private var bufferedBestMoves: [String] = []
    private var pending: [Pending] = []

    func reset() {
        bufferedBestMoves.removeAll()
    }

    func receive(_ message: String) {
        guard let bestMove = Self.bestMove(from: message) else { return }
        if pending.isEmpty {
            bufferedBestMoves.append(bestMove)
        } else {
            let waiter = pending.removeFirst()
            waiter.continuation.resume(returning: bestMove)
        }
    }

    func nextBestMove() async -> String? {
        if !bufferedBestMoves.isEmpty {
            return bufferedBestMoves.removeFirst()
        }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                pending.append(Pending(id: id, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancel(id: id) }
        }
    }

    private func cancel(id: UUID) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let waiter = pending.remove(at: index)
        waiter.continuation.resume(returning: nil)
    }

    private static func bestMove(from message: String) -> String? {
        let fields = message.split(separator: " ")
        guard fields.first == "bestmove", fields.count >= 2 else { return nil }
        let move = String(fields[1])
        return move == "(none)" ? nil : move
    }
}

/// Stockfish-backed chess bot. The open-source engine handles move choice; the
/// local move generator still validates every UCI move before applying it.
final class StockfishAI: ChessAI, @unchecked Sendable {
    private let lock = NSLock()
    private let router = StockfishResponseRouter()
    private let fallback = MinimaxAI()
    private var _targetELO = 1200

    var level: Int {
        get { Self.level(forELO: targetELO) }
        set { configure(elo: MinimaxAI.elo(forLevel: newValue)) }
    }

    var targetELO: Int {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _targetELO
        }
        set { configure(elo: newValue) }
    }

    func configure(elo: Int) {
        let clamped = min(2400, max(600, elo))
        lock.lock()
        _targetELO = clamped
        lock.unlock()
        fallback.configure(elo: clamped)
    }

    func bestMove(for position: Position) async -> Move? {
        let elo = targetELO
        guard !MoveGenerator.legalMoves(in: position).isEmpty else { return nil }

        #if canImport(StockFishKit_iOS)
        await router.reset()
        await MainActor.run {
            let engine = StockFish_iOS.shared
            engine.initEngine()
            engine.onMessageReceived = { [router] message in
                Task { await router.receive(message) }
            }
            for command in Self.optionCommands(forELO: elo) {
                engine.send(command)
            }
            engine.send("position fen \(position.stockfishFEN())")
            engine.send("go depth \(Self.searchDepth(forELO: elo))")
        }

        if let uci = await nextBestMove(timeoutNanoseconds: Self.timeoutNanoseconds(forELO: elo)),
           let move = Move.fromUCI(uci, in: position) {
            return move
        }
        #endif

        return await fallback.bestMove(for: position)
    }

    static func optionCommands(forELO elo: Int) -> [String] {
        let clamped = min(2400, max(600, elo))
        let skillCommand = "setoption name Skill Level value \(skillLevel(forELO: clamped))"
        return [
            "setoption name UCI_LimitStrength value true",
            "setoption name UCI_Elo value \(stockfishLimitELO(forELO: clamped))",
            skillCommand
        ]
    }

    static func stockfishLimitELO(forELO elo: Int) -> Int {
        min(2400, max(1320, elo))
    }

    static func skillLevel(forELO elo: Int) -> Int {
        let clamped = min(2400, max(600, elo))
        let scaled = Double(clamped - 600) / Double(2400 - 600) * 20.0
        return min(20, max(0, Int(scaled.rounded())))
    }

    private static func level(forELO elo: Int) -> Int {
        let clamped = min(2400, max(600, elo))
        let scaled = 1.0 + Double(clamped - 600) / Double(2400 - 600) * 9.0
        return min(10, max(1, Int(scaled.rounded())))
    }

    private static func searchDepth(forELO elo: Int) -> Int {
        switch min(2400, max(600, elo)) {
        case ..<900: return 2
        case 900..<1300: return 4
        case 1300..<1700: return 6
        case 1700..<2100: return 8
        default: return 10
        }
    }

    private static func timeoutNanoseconds(forELO elo: Int) -> UInt64 {
        switch min(2400, max(600, elo)) {
        case ..<1300: return 1_500_000_000
        case 1300..<2100: return 2_500_000_000
        default: return 4_000_000_000
        }
    }

    private func nextBestMove(timeoutNanoseconds: UInt64) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { await self.router.nextBestMove() }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }
}
