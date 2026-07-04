import XCTest

final class Chess2DRenderingTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func chessSource() throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent("Sources/Features/Games/ChessView.swift"))
    }

    func testTwoDChessUsesAssetPiecesInsteadOfTextGlyphs() throws {
        let source = try chessSource()

        XCTAssertTrue(source.contains("ChessPieceGlyph(piece: piece"))
        XCTAssertTrue(source.contains("Image(assetName)"))
        XCTAssertFalse(source.contains("Text(piece.solidGlyph)"))
    }

    func testTwoDChessIncludesColorSpecificPawnAssets() {
        let assets = repoRoot.appendingPathComponent("Resources/Assets.xcassets")
        let whitePawn = assets.appendingPathComponent("wP.imageset/wP.pdf")
        let blackPawn = assets.appendingPathComponent("bP.imageset/bP.pdf")

        XCTAssertTrue(FileManager.default.fileExists(atPath: whitePawn.path), "Missing white pawn vector asset")
        XCTAssertTrue(FileManager.default.fileExists(atPath: blackPawn.path), "Missing black pawn vector asset")
    }
}
