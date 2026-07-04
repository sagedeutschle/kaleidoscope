import CoreGraphics

struct Game2048BoardLayout {
    struct Point: Equatable {
        let x: Double
        let y: Double
    }

    static let defaultTileSize: Double = 92
    static let minTileSize: Double = 60
    static let maxTileSize: Double = 120
    static let defaultGap: Double = 8
    static let cardPadding: Double = 0

    let tileSize: Double
    let gap: Double

    init(tileSize: Double = Self.defaultTileSize, gap: Double = Self.defaultGap) {
        self.tileSize = min(max(tileSize, Self.minTileSize), Self.maxTileSize)
        self.gap = gap
    }

    var regularTileFontSize: Double {
        max(24, tileSize * 0.38)
    }

    var largeTileFontSize: Double {
        max(20, tileSize * 0.30)
    }

    func boardSide(for boardSize: Int) -> Double {
        Double(boardSize) * tileSize + Double(boardSize - 1) * gap
    }

    func cardSide(for boardSize: Int) -> Double {
        boardSide(for: boardSize) + Self.cardPadding * 2
    }

    func tileOrigin(for index: Int, boardSize: Int) -> Point {
        let row = index / boardSize
        let column = index % boardSize
        let step = tileSize + gap

        return Point(x: Double(column) * step, y: Double(row) * step)
    }

    func tileCenter(for index: Int, boardSize: Int) -> Point {
        let origin = tileOrigin(for: index, boardSize: boardSize)
        let halfTile = tileSize / 2

        return Point(x: origin.x + halfTile, y: origin.y + halfTile)
    }
}
