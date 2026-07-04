import Foundation

// PRISM: RELEASE Agent-B 2026-07-02 — bundled nonogram puzzle bank (tester: "only one level")
//
// A hand-authored bank of nonogram (picross) puzzles. Each level's picture is
// written as ASCII art so it stays readable and reviewable in source: a `#`
// (or any non-space, non-`.` character) means a filled cell, `.` or space means
// empty. Rows are validated to be square (size × size) via `isWellFormed`, and
// `NonogramLevelBank.validationErrors` surfaces any malformed art for the tests
// to assert against.
//
// The model (`NonogramGame`) already derives row/column clues from the solution
// grid, so a level only needs a correct boolean picture — clues follow for free.

/// One bundled nonogram puzzle: a name, a grid size, and the solution picture.
struct NonogramLevel: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let size: Int
    /// ASCII-art rows. A filled cell is any non-space, non-`.` glyph; `.`/space is empty.
    let art: [String]

    init(id: String, name: String, size: Int, art: [String]) {
        self.id = id
        self.name = name
        self.size = size
        self.art = art
    }

    /// The solution as a flat row-major boolean grid, matching `NonogramGame.solution`.
    /// Missing/short rows are padded with empties and over-long rows are truncated so a
    /// typo in the art can never crash the app — `isWellFormed` reports such mistakes.
    var solution: [Bool] {
        var cells: [Bool] = []
        cells.reserveCapacity(size * size)
        for r in 0..<size {
            let row = r < art.count ? art[r] : ""
            let chars = Array(row)
            for c in 0..<size {
                let ch = c < chars.count ? chars[c] : " "
                cells.append(NonogramLevel.isFilled(ch))
            }
        }
        return cells
    }

    /// True when the art is exactly `size` rows, each exactly `size` glyphs wide.
    var isWellFormed: Bool {
        art.count == size && art.allSatisfy { $0.count == size } && size > 0
    }

    /// A ready-to-play game seeded with this level's solution.
    func makeGame() -> NonogramGame {
        NonogramGame(size: size, solution: solution)
    }

    private static func isFilled(_ ch: Character) -> Bool {
        ch != " " && ch != "."
    }
}

/// The catalog of bundled puzzles, ordered easiest-ish first.
enum NonogramLevelBank {
    static let levels: [NonogramLevel] = [
        // 0 — the original built-in, kept so existing saves still make sense.
        NonogramLevel(id: "cross", name: "Cross", size: 5, art: [
            "..#..",
            ".###.",
            "#####",
            ".###.",
            "..#..",
        ]),
        // 1
        NonogramLevel(id: "heart", name: "Heart", size: 5, art: [
            ".#.#.",
            "#####",
            "#####",
            ".###.",
            "..#..",
        ]),
        // 2
        NonogramLevel(id: "smiley", name: "Smiley", size: 5, art: [
            ".#.#.",
            ".#.#.",
            ".....",
            "#...#",
            ".###.",
        ]),
        // 3
        NonogramLevel(id: "arrow", name: "Arrow", size: 5, art: [
            "..#..",
            ".###.",
            "#####",
            "..#..",
            "..#..",
        ]),
        // 4 — open diamond outline (distinct from the solid Cross above)
        NonogramLevel(id: "diamond", name: "Diamond", size: 5, art: [
            "..#..",
            ".#.#.",
            "#...#",
            ".#.#.",
            "..#..",
        ]),
        // 5
        NonogramLevel(id: "camera", name: "Camera", size: 10, art: [
            "..........",
            "...####...",
            ".########.",
            ".########.",
            ".##....##.",
            ".##.##.##.",
            ".##....##.",
            ".########.",
            "..........",
            "..........",
        ]),
        // 6
        NonogramLevel(id: "house", name: "House", size: 10, art: [
            "....##....",
            "...####...",
            "..######..",
            ".########.",
            "##########",
            ".##....##.",
            ".##.##.##.",
            ".##.##.##.",
            ".##....##.",
            ".########.",
        ]),
        // 7
        NonogramLevel(id: "cat", name: "Cat", size: 10, art: [
            "##......##",
            "###....###",
            "##########",
            "#.######.#",
            "##########",
            "##########",
            "#.######.#",
            "##########",
            ".##....##.",
            ".##....##.",
        ]),
        // 8
        NonogramLevel(id: "duck", name: "Duck", size: 10, art: [
            "...####...",
            "..######..",
            "..##.###..",
            "..######.#",
            "..#######.",
            ".########.",
            "##########",
            "##########",
            ".########.",
            "..######..",
        ]),
        // 9
        NonogramLevel(id: "anchor", name: "Anchor", size: 10, art: [
            "....##....",
            "...#..#...",
            "....##....",
            "..######..",
            "....##....",
            "....##....",
            "#...##...#",
            "#...##...#",
            ".#.####.#.",
            "..######..",
        ]),
        // 10
        NonogramLevel(id: "tree", name: "Tree", size: 10, art: [
            "....##....",
            "...####...",
            "..######..",
            ".########.",
            "..######..",
            ".########.",
            "##########",
            "....##....",
            "....##....",
            "...####...",
        ]),
        // 11
        NonogramLevel(id: "space-invader", name: "Invader", size: 10, art: [
            "..#....#..",
            "...#..#...",
            "..######..",
            ".##.##.##.",
            "##########",
            "#.######.#",
            "#.#....#.#",
            "...##.##..",
            "..##..##..",
            ".##....##.",
        ]),
    ]

    /// Levels whose art is malformed (wrong number of rows/columns). Empty in a
    /// healthy bank; the test suite asserts it stays empty.
    static var validationErrors: [String] {
        levels.filter { !$0.isWellFormed }.map { "\($0.id): art is not \($0.size)×\($0.size)" }
    }

    static func level(at index: Int) -> NonogramLevel {
        guard levels.indices.contains(index) else { return levels[0] }
        return levels[index]
    }
}
