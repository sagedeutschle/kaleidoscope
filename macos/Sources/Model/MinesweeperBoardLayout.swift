import Foundation

struct MinesweeperBoardLayout: Equatable {
    static let minCellSize = 22.5
    static let maxCellSize = 48.0

    static let tight = MinesweeperBoardLayout(
        cellSize: 30,
        cellSpacing: 2,
        boardPadding: 8,
        cornerRadius: 4,
        numberFontSize: 15,
        symbolFontSize: 14
    )

    let cellSize: Double
    let cellSpacing: Double
    let boardPadding: Double
    let cornerRadius: Double
    let numberFontSize: Double
    let symbolFontSize: Double

    func scaled(by scale: Double) -> MinesweeperBoardLayout {
        let clampedScale = min(max(scale, 0.75), 1.6)
        let scaledCell = min(max(cellSize * clampedScale, Self.minCellSize), Self.maxCellSize)
        let cellRatio = scaledCell / cellSize

        return MinesweeperBoardLayout(
            cellSize: scaledCell,
            cellSpacing: min(max(cellSpacing * clampedScale, 0), 3),
            boardPadding: min(max(boardPadding * clampedScale, 6), 14),
            cornerRadius: min(max(cornerRadius * clampedScale, 3), 7),
            numberFontSize: min(numberFontSize * cellRatio, scaledCell * 0.68),
            symbolFontSize: min(symbolFontSize * cellRatio, scaledCell * 0.66)
        )
    }
}
