import Foundation

enum SeaBattleAIDifficulty: String, CaseIterable, Codable, Hashable, Identifiable {
    case easy
    case normal
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        }
    }
}

struct SeaBattleAI: Equatable, Hashable {
    var difficulty: SeaBattleAIDifficulty
    var seed: UInt64

    func shot(for player: SeaBattlePlayer, in game: SeaBattleGame) -> SeaBattlePoint? {
        guard !game.isGameOver, game.currentPlayer == player else { return nil }
        let targetBoard = game.board(for: player.opponent)
        let candidates = Self.allPoints.filter { !targetBoard.shots.contains($0) }
        guard !candidates.isEmpty else { return nil }

        switch difficulty {
        case .easy:
            return randomShot(from: candidates)
        case .normal:
            return focusedShot(on: targetBoard, candidates: candidates) ?? randomShot(from: candidates)
        case .hard:
            return lineShot(on: targetBoard, candidates: candidates)
                ?? focusedShot(on: targetBoard, candidates: candidates)
                ?? parityShot(from: candidates)
                ?? randomShot(from: candidates)
        }
    }

    private static let allPoints: [SeaBattlePoint] = (0..<SeaBattleGame.size).flatMap { row in
        (0..<SeaBattleGame.size).map { col in SeaBattlePoint(row: row, col: col) }
    }

    private func randomShot(from candidates: [SeaBattlePoint]) -> SeaBattlePoint? {
        guard !candidates.isEmpty else { return nil }
        var rng = SeededGenerator(seed: seed)
        return sorted(candidates)[rng.nextInt(upperBound: candidates.count)]
    }

    private func parityShot(from candidates: [SeaBattlePoint]) -> SeaBattlePoint? {
        let checkerboard = candidates.filter { ($0.row + $0.col).isMultiple(of: 2) }
        return randomShot(from: checkerboard.isEmpty ? candidates : checkerboard)
    }

    private func focusedShot(on board: SeaBattleBoard, candidates: [SeaBattlePoint]) -> SeaBattlePoint? {
        let candidateSet = Set(candidates)
        for hit in unresolvedHits(on: board) {
            for neighbor in orderedNeighbors(of: hit) where candidateSet.contains(neighbor) {
                return neighbor
            }
        }
        return nil
    }

    private func lineShot(on board: SeaBattleBoard, candidates: [SeaBattlePoint]) -> SeaBattlePoint? {
        let candidateSet = Set(candidates)
        let hits = unresolvedHits(on: board)
        guard hits.count >= 2 else { return nil }

        let rows = Dictionary(grouping: hits, by: \.row)
        for group in rows.values.map(sorted).sorted(by: compareGroups) where group.count >= 2 {
            let cols = group.map(\.col).sorted()
            for run in contiguousRuns(cols) where run.count >= 2 {
                let row = group[0].row
                let right = SeaBattlePoint(row: row, col: run.last! + 1)
                if isValid(right), candidateSet.contains(right) { return right }
                let left = SeaBattlePoint(row: row, col: run.first! - 1)
                if isValid(left), candidateSet.contains(left) { return left }
            }
        }

        let cols = Dictionary(grouping: hits, by: \.col)
        for group in cols.values.map(sorted).sorted(by: compareGroups) where group.count >= 2 {
            let rows = group.map(\.row).sorted()
            for run in contiguousRuns(rows) where run.count >= 2 {
                let col = group[0].col
                let down = SeaBattlePoint(row: run.last! + 1, col: col)
                if isValid(down), candidateSet.contains(down) { return down }
                let up = SeaBattlePoint(row: run.first! - 1, col: col)
                if isValid(up), candidateSet.contains(up) { return up }
            }
        }

        return nil
    }

    private func unresolvedHits(on board: SeaBattleBoard) -> [SeaBattlePoint] {
        let hitCells = board.shipCells.intersection(board.shots)
        let sunk = sunkCells(on: board)
        return sorted(hitCells.subtracting(sunk))
    }

    private func sunkCells(on board: SeaBattleBoard) -> Set<SeaBattlePoint> {
        var remaining = board.shipCells
        var sunk = Set<SeaBattlePoint>()

        while let start = remaining.first {
            var stack = [start]
            var segment = Set<SeaBattlePoint>()
            remaining.remove(start)

            while let point = stack.popLast() {
                segment.insert(point)
                for neighbor in orderedNeighbors(of: point) where remaining.contains(neighbor) {
                    remaining.remove(neighbor)
                    stack.append(neighbor)
                }
            }

            if segment.isSubset(of: board.shots) {
                sunk.formUnion(segment)
            }
        }

        return sunk
    }

    private func orderedNeighbors(of point: SeaBattlePoint) -> [SeaBattlePoint] {
        [
            SeaBattlePoint(row: point.row, col: point.col + 1),
            SeaBattlePoint(row: point.row + 1, col: point.col),
            SeaBattlePoint(row: point.row, col: point.col - 1),
            SeaBattlePoint(row: point.row - 1, col: point.col)
        ].filter(Self.isValid)
    }

    private func contiguousRuns(_ values: [Int]) -> [[Int]] {
        guard let first = values.first else { return [] }
        var runs = [[first]]
        for value in values.dropFirst() {
            if value == runs[runs.count - 1].last! + 1 {
                runs[runs.count - 1].append(value)
            } else {
                runs.append([value])
            }
        }
        return runs.sorted { $0.count == $1.count ? $0[0] < $1[0] : $0.count > $1.count }
    }

    private func sorted<S: Sequence>(_ points: S) -> [SeaBattlePoint] where S.Element == SeaBattlePoint {
        points.sorted { ($0.row, $0.col) < ($1.row, $1.col) }
    }

    private func compareGroups(_ lhs: [SeaBattlePoint], _ rhs: [SeaBattlePoint]) -> Bool {
        guard let left = lhs.first, let right = rhs.first else { return lhs.count > rhs.count }
        return (left.row, left.col) < (right.row, right.col)
    }

    private static func isValid(_ point: SeaBattlePoint) -> Bool {
        (0..<SeaBattleGame.size).contains(point.row) && (0..<SeaBattleGame.size).contains(point.col)
    }

    private func isValid(_ point: SeaBattlePoint) -> Bool {
        Self.isValid(point)
    }
}
