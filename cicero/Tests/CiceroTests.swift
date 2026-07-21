import XCTest
import UIKit
@testable import Cicero

final class CiceroTests: XCTestCase {

    // MARK: JSONValue

    func testJSONValueRoundTrip() throws {
        let value: JSONValue = .object([
            "a": .string("x"),
            "n": .number(3),
            "b": .bool(true),
            "arr": .array([.number(1), .null]),
        ])
        let data = try JSONEncoder().encode(value)
        let back = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(back, value)
        XCTAssertEqual(back["a"]?.stringValue, "x")
        XCTAssertNil(back["missing"])
    }

    // MARK: Request / response wire format

    func testRequestEncodesSnakeCaseKeys() throws {
        let request = MessagesRequest(
            model: "claude-opus-4-8",
            maxTokens: 1024,
            system: "sys",
            messages: [.user("hi")],
            tools: AgentTools.all,
            outputConfig: .init(effort: "high"))
        let json = String(data: try JSONEncoder().encode(request), encoding: .utf8)!
        XCTAssertTrue(json.contains("\"max_tokens\":1024"))
        XCTAssertTrue(json.contains("\"output_config\""))
        XCTAssertTrue(json.contains("\"input_schema\""))
        XCTAssertTrue(json.contains("claude-opus-4-8"))
    }

    func testToolResultBlockEncoding() throws {
        let block = ContentBlock.toolResult(toolUseID: "t1", text: "ok", isError: false)
        let json = String(data: try JSONEncoder().encode(block), encoding: .utf8)!
        XCTAssertTrue(json.contains("\"type\":\"tool_result\""))
        XCTAssertTrue(json.contains("\"tool_use_id\":\"t1\""))
        XCTAssertTrue(json.contains("\"is_error\":false"))
    }

    func testResponseDecodingTextAndToolUse() throws {
        let sample = """
        {"id":"m","model":"claude-opus-4-8","role":"assistant","stop_reason":"tool_use",
         "content":[{"type":"text","text":"reading"},
                    {"type":"tool_use","id":"tu1","name":"read_file","input":{"path":"a.swift"}}]}
        """
        let response = try JSONDecoder().decode(MessagesResponse.self, from: Data(sample.utf8))
        XCTAssertEqual(response.joinedText, "reading")
        XCTAssertEqual(response.stopReason, "tool_use")
        XCTAssertEqual(response.toolUses.count, 1)
        XCTAssertEqual(response.toolUses.first?.name, "read_file")
        XCTAssertEqual(response.toolUses.first?.input["path"]?.stringValue, "a.swift")
    }

    // MARK: Syntax highlighting

    func testHighlighterPreservesText() {
        let source = "func greet() { return 42 } // hi"
        let attributed = SyntaxHighlighter(language: .swift).attributed(for: source)
        XCTAssertEqual(attributed.string, source)
    }

    func testHighlighterColorsKeywordsDifferently() {
        let source = "func x = 1"
        let attributed = SyntaxHighlighter(language: .swift).attributed(for: source)
        let keywordColor = attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        let identifierColor = attributed.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(keywordColor)
        XCTAssertNotNil(identifierColor)
        XCTAssertNotEqual(rgba(keywordColor!), rgba(identifierColor!))
    }

    func testPlainLanguageIsUnstyled() {
        let source = "func let var"
        let attributed = SyntaxHighlighter(language: .plain).attributed(for: source)
        let a = attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        let b = attributed.attribute(.foregroundColor, at: source.count - 1, effectiveRange: nil) as? UIColor
        XCTAssertEqual(rgba(a!), rgba(b!)) // one uniform color, no keyword coloring
    }

    func testLanguageDetection() {
        XCTAssertEqual(Language(filename: "main.swift"), .swift)
        XCTAssertEqual(Language(filename: "app.py"), .python)
        XCTAssertEqual(Language(filename: "index.tsx"), .javascript)
        XCTAssertEqual(Language(filename: "data.json"), .json)
        XCTAssertEqual(Language(filename: "notes.txt"), .plain)
    }

    // MARK: Project path safety

    @MainActor
    func testProjectPathSafety() {
        let store = ProjectStore()
        XCTAssertNil(store.resolve("../escape"))
        XCTAssertNil(store.resolve("a/../../escape"))
        XCTAssertNil(store.resolve(""))
        XCTAssertNotNil(store.resolve("a/b.txt"))
        XCTAssertNotNil(store.resolve("hello.swift"))
    }

    // MARK: Tic-Tac-Toe AI

    func testTicTacToeAIBlocksImmediateLoss() {
        var game = TicTacToe()
        game.play(0) // X @0
        game.play(4) // O @4
        game.play(1) // X @1  -> X threatens to win at 2; O to move
        XCTAssertEqual(game.current, .o)
        XCTAssertEqual(game.bestMove(for: .o), 2, "O must block X's win on the top row")
    }

    func testTicTacToeDetectsWinner() {
        var game = TicTacToe()
        // X:0, O:3, X:1, O:4, X:2  -> X wins top row
        for move in [0, 3, 1, 4, 2] { game.play(move) }
        XCTAssertEqual(game.winner, .x)
        XCTAssertTrue(game.isOver)
    }

    func testTicTacToeOptimalPlayNeverLoses() {
        // Two optimal players must draw.
        var game = TicTacToe()
        var guardRail = 0
        while !game.isOver && guardRail < 9 {
            if let move = game.bestMove(for: game.current) { game.play(move) }
            guardRail += 1
        }
        XCTAssertNil(game.winner, "optimal vs optimal should draw")
        XCTAssertTrue(game.isFull)
    }

    // MARK: Lights Out

    func testLightsOutStartsUnsolved() {
        let game = LightsOut()
        XCTAssertFalse(game.isSolved)
    }

    func testLightsOutTapIsInvolution() {
        var game = LightsOut()
        let before = game.grid
        game.tap(row: 2, col: 2)
        game.tap(row: 2, col: 2)
        XCTAssertEqual(game.grid, before, "tapping the same cell twice cancels out")
        XCTAssertEqual(game.moves, 2)
    }

    // MARK: Helpers

    private func rgba(_ color: UIColor) -> [CGFloat] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }
}
