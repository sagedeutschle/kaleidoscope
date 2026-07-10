import XCTest
@testable import Prismet

final class ChessAITests: XCTestCase {
    func testPieceGlyphsUseColorSpecificChessSymbols() {
        XCTAssertEqual(Piece(color: .white, type: .king).glyph, "♔")
        XCTAssertEqual(Piece(color: .white, type: .queen).glyph, "♕")
        XCTAssertEqual(Piece(color: .white, type: .rook).glyph, "♖")
        XCTAssertEqual(Piece(color: .white, type: .bishop).glyph, "♗")
        XCTAssertEqual(Piece(color: .white, type: .knight).glyph, "♘")
        XCTAssertEqual(Piece(color: .white, type: .pawn).glyph, "♙")

        XCTAssertEqual(Piece(color: .black, type: .king).glyph, "♚")
        XCTAssertEqual(Piece(color: .black, type: .queen).glyph, "♛")
        XCTAssertEqual(Piece(color: .black, type: .rook).glyph, "♜")
        XCTAssertEqual(Piece(color: .black, type: .bishop).glyph, "♝")
        XCTAssertEqual(Piece(color: .black, type: .knight).glyph, "♞")
        XCTAssertEqual(Piece(color: .black, type: .pawn).glyph, "♟")
    }

    func testELOClampsAndSynchronizesLegacyLevel() {
        let ai = MinimaxAI()

        ai.configure(elo: 100)
        XCTAssertEqual(ai.targetELO, 600)
        XCTAssertEqual(ai.level, 1)

        ai.configure(elo: 2400)
        XCTAssertEqual(ai.targetELO, 2400)
        XCTAssertEqual(ai.level, 10)

        ai.level = 5
        XCTAssertEqual(ai.level, 5)
        XCTAssertEqual(ai.targetELO, 1400)
    }

    func testELOSearchDepthBandsIncreaseWithStrength() {
        // Finer bands than the original model, with a genuine depth-5 top tier so
        // the strong end of the slider keeps getting sharper (the old model capped
        // every ELO >= 1700 at depth 4, making the top third feel identical).
        XCTAssertEqual(MinimaxAI.searchDepth(forELO: 600), 1)
        XCTAssertEqual(MinimaxAI.searchDepth(forELO: 900), 2)
        XCTAssertEqual(MinimaxAI.searchDepth(forELO: 1300), 3)
        XCTAssertEqual(MinimaxAI.searchDepth(forELO: 1600), 4)
        XCTAssertEqual(MinimaxAI.searchDepth(forELO: 2000), 5)
        XCTAssertEqual(MinimaxAI.searchDepth(forELO: 2400), 5)
        // Monotonic non-decreasing across the whole range.
        let depths = stride(from: 600, through: 2400, by: 100).map { MinimaxAI.searchDepth(forELO: $0) }
        XCTAssertEqual(depths, depths.sorted())
    }

    func testTemperatureFallsSmoothlyAsStrengthRises() {
        // Temperature is the continuous "feel" dial: high (loose, beatable) at low
        // ELO, easing toward best-only at high ELO. Strictly decreasing, and clamped
        // outside the slider range.
        XCTAssertGreaterThan(MinimaxAI.temperature(forELO: 600), MinimaxAI.temperature(forELO: 1200))
        XCTAssertGreaterThan(MinimaxAI.temperature(forELO: 1200), MinimaxAI.temperature(forELO: 1800))
        XCTAssertGreaterThan(MinimaxAI.temperature(forELO: 1800), MinimaxAI.temperature(forELO: 2400))
        // Strictly monotonic across every slider step (no flat region anywhere).
        let temps = stride(from: 600, through: 2400, by: 100).map { MinimaxAI.temperature(forELO: $0) }
        for i in 1..<temps.count {
            XCTAssertLessThan(temps[i], temps[i - 1], "temperature should strictly decrease at every step")
        }
        // Clamped at the extremes.
        XCTAssertEqual(MinimaxAI.temperature(forELO: 100), MinimaxAI.temperature(forELO: 600))
        XCTAssertEqual(MinimaxAI.temperature(forELO: 9000), MinimaxAI.temperature(forELO: 2400))
    }

    func testStrengthProfileMakesLowELOBlunderAndHighELOGreedy() {
        let low = MinimaxAI.strengthProfile(forELO: 600)
        let high = MinimaxAI.strengthProfile(forELO: 2400)

        XCTAssertGreaterThan(low.blunderChance, 0.60)
        XCTAssertLessThan(high.blunderChance, 0.02)
        XCTAssertGreaterThan(low.blunderWindowCentipawns, high.blunderWindowCentipawns)
        XCTAssertGreaterThan(high.depth, low.depth)
    }

    func testLowELOCanChooseWeakerBandWhileHighELOTakesTacticalMaterial() throws {
        var board = [Piece?](repeating: nil, count: 64)
        board[Square(file: 0, rank: 0).index] = Piece(color: .white, type: .king)
        board[Square(file: 7, rank: 7).index] = Piece(color: .black, type: .king)
        board[Square(file: 3, rank: 0).index] = Piece(color: .white, type: .queen)
        board[Square(file: 3, rank: 7).index] = Piece(color: .black, type: .rook)
        let position = Position(
            board: board,
            sideToMove: .white,
            castling: CastlingRights(whiteKingside: false, whiteQueenside: false, blackKingside: false, blackQueenside: false)
        )
        let winningCapture = try XCTUnwrap(Move.fromUCI("d1d8", in: position))

        let lowMove = MinimaxAI.selectMove(position, profile: MinimaxAI.strengthProfile(forELO: 600), randomFraction: 0)
        let highMove = MinimaxAI.selectMove(position, profile: MinimaxAI.strengthProfile(forELO: 2400), randomFraction: 0)

        XCTAssertNotEqual(lowMove, winningCapture)
        XCTAssertEqual(highMove, winningCapture)
    }

    func testSelectMoveReturnsALegalMoveAcrossTemperatures() {
        // The softmax path must degrade cleanly at both extremes (greedy at temp 0,
        // spread at high temp) and always return a legal move from a live position.
        for temp in [0.0, 6.0, 210.0] {
            XCTAssertNotNil(MinimaxAI.selectMove(.initial, depth: 2, temperature: temp))
        }
    }

    func testInitialPositionExportsStockfishFEN() {
        XCTAssertEqual(
            Position.initial.stockfishFEN(),
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        )
    }

    func testUCIMoveMatchesLegalInitialMove() {
        let move = Move.fromUCI("e2e4", in: .initial)

        XCTAssertEqual(move?.from.algebraic, "e2")
        XCTAssertEqual(move?.to.algebraic, "e4")
        XCTAssertTrue(move?.isDoublePawnPush == true)
        XCTAssertEqual(move?.uciNotation, "e2e4")
    }

    func testUCIMoveMatchesPromotionChoice() {
        var board = [Piece?](repeating: nil, count: 64)
        board[Square(file: 4, rank: 0).index] = Piece(color: .white, type: .king)
        board[Square(file: 4, rank: 7).index] = Piece(color: .black, type: .king)
        board[Square(file: 0, rank: 6).index] = Piece(color: .white, type: .pawn)
        let position = Position(
            board: board,
            sideToMove: .white,
            castling: CastlingRights(whiteKingside: false, whiteQueenside: false, blackKingside: false, blackQueenside: false)
        )

        let move = Move.fromUCI("a7a8q", in: position)

        XCTAssertEqual(move?.promotion, .queen)
        XCTAssertEqual(move?.uciNotation, "a7a8q")
    }

    func testStockfishELOConfigurationUsesLimitStrengthWhenSupported() {
        XCTAssertEqual(StockfishAI.skillLevel(forELO: 600), 0)
        XCTAssertEqual(StockfishAI.skillLevel(forELO: 2400), 20)
        XCTAssertEqual(StockfishAI.stockfishLimitELO(forELO: 600), 1320)
        XCTAssertEqual(StockfishAI.stockfishLimitELO(forELO: 2400), 2400)
        XCTAssertEqual(
            StockfishAI.optionCommands(forELO: 1200),
            [
                "setoption name UCI_LimitStrength value true",
                "setoption name UCI_Elo value 1320",
                "setoption name Skill Level value 7"
            ]
        )
        XCTAssertEqual(
            StockfishAI.optionCommands(forELO: 1800),
            [
                "setoption name UCI_LimitStrength value true",
                "setoption name UCI_Elo value 1800",
                "setoption name Skill Level value 13"
            ]
        )
    }
}
