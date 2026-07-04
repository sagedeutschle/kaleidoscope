import Foundation

struct SnakeTilePresentation: Equatable {
    enum Kind: Equatable {
        case empty
        case apple
        case head
        case body
        case tail
    }

    let kind: Kind
    let direction: SnakeGame.Direction?
    let assetName: String?

    static func presentation(for point: SnakePoint, in game: SnakeGame) -> SnakeTilePresentation {
        if game.apple == point {
            return SnakeTilePresentation(kind: .apple, direction: nil, assetName: "snake_apple")
        }
        guard let index = game.body.firstIndex(of: point) else {
            return SnakeTilePresentation(kind: .empty, direction: nil, assetName: nil)
        }
        if index == 0 {
            return SnakeTilePresentation(kind: .head, direction: game.direction, assetName: "snake_head_\(game.direction.assetSuffix)")
        }
        if index == game.body.count - 1 {
            let direction = direction(from: point, toward: game.body[index - 1])
            return SnakeTilePresentation(kind: .tail, direction: direction, assetName: direction.map { "snake_tail_\($0.assetSuffix)" })
        }

        let previous = game.body[index - 1]
        let next = game.body[index + 1]
        return SnakeTilePresentation(kind: .body, direction: nil, assetName: bodyAssetName(current: point, previous: previous, next: next))
    }

    private static func direction(from point: SnakePoint, toward next: SnakePoint) -> SnakeGame.Direction? {
        switch (next.row - point.row, next.col - point.col) {
        case (-1, 0): return .up
        case (1, 0): return .down
        case (0, -1): return .left
        case (0, 1): return .right
        default: return nil
        }
    }

    private static func bodyAssetName(current: SnakePoint, previous: SnakePoint, next: SnakePoint) -> String {
        let first = direction(from: current, toward: previous)
        let second = direction(from: current, toward: next)
        let directions = Set([first, second].compactMap { $0 })

        if directions == [.left, .right] { return "snake_body_horizontal" }
        if directions == [.up, .down] { return "snake_body_vertical" }
        if directions == [.down, .left] { return "snake_body_bottomleft" }
        if directions == [.down, .right] { return "snake_body_bottomright" }
        if directions == [.up, .left] { return "snake_body_topleft" }
        if directions == [.up, .right] { return "snake_body_topright" }
        return "snake_body_horizontal"
    }
}

private extension SnakeGame.Direction {
    var assetSuffix: String {
        switch self {
        case .up: return "up"
        case .down: return "down"
        case .left: return "left"
        case .right: return "right"
        }
    }
}
