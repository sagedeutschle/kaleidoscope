import Foundation

struct Game2048VisualShuffle: Equatable {
    struct TileEffect: Equatable {
        let xOffset: Double
        let yOffset: Double
        let rotationDegrees: Double
        let scale: Double

        var isNeutral: Bool {
            xOffset == 0 && yOffset == 0 && rotationDegrees == 0 && scale == 1
        }
    }

    let effectsByTileIndex: [TileEffect]

    init(seed: UInt64, slotCount: Int) {
        precondition(slotCount > 0)
        var rng = SeededGenerator(seed: seed)
        effectsByTileIndex = (0..<slotCount).map { _ in
            let x = Double(rng.nextInt(upperBound: 7) - 3)
            let y = Double(rng.nextInt(upperBound: 7) - 3)
            let rotation = Double(rng.nextInt(upperBound: 15) - 7)
            let scale = 0.96 + (Double(rng.nextInt(upperBound: 9)) * 0.01)
            return TileEffect(xOffset: x, yOffset: y, rotationDegrees: rotation, scale: scale)
        }
    }

    func effect(forTileIndex index: Int) -> TileEffect {
        effectsByTileIndex[index]
    }
}
