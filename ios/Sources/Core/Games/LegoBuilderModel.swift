// PRISM: RELEASE Agent-Design(brickbench) 2026-07-03 — added canonical LegoBrickColor rgb/swatch appearance (ported from desktop)
// PRISM: RELEASE Agent-Design(brickbench-3d) 2026-07-03 — added uiColor accessor for SceneKit materials
import Foundation
import SwiftUI
import UIKit

struct LegoGridPoint: Hashable, Codable {
    var x: Int
    var y: Int
}

enum LegoElementKind: String, CaseIterable, Identifiable, Codable {
    case brick
    case plate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .brick: return "Brick"
        case .plate: return "Plate"
        }
    }
}

enum LegoBrickSize: String, CaseIterable, Identifiable, Codable {
    case oneByOne
    case oneByTwo
    case oneByFour
    case twoByTwo
    case twoByFour
    case twoBySix
    case oneByOnePlate
    case oneByTwoPlate
    case oneByFourPlate
    case twoByTwoPlate
    case twoByFourPlate
    case twoBySixPlate

    var id: String { rawValue }

    var studsWide: Int {
        switch self {
        case .oneByOne, .oneByTwo, .oneByFour, .oneByOnePlate, .oneByTwoPlate, .oneByFourPlate:
            return 1
        case .twoByTwo, .twoByFour, .twoBySix, .twoByTwoPlate, .twoByFourPlate, .twoBySixPlate:
            return 2
        }
    }

    var studsDeep: Int {
        switch self {
        case .oneByOne, .oneByOnePlate:
            return 1
        case .oneByTwo, .twoByTwo, .oneByTwoPlate, .twoByTwoPlate:
            return 2
        case .oneByFour, .twoByFour, .oneByFourPlate, .twoByFourPlate:
            return 4
        case .twoBySix, .twoBySixPlate:
            return 6
        }
    }

    var elementKind: LegoElementKind {
        switch self {
        case .oneByOne, .oneByTwo, .oneByFour, .twoByTwo, .twoByFour, .twoBySix:
            return .brick
        case .oneByOnePlate, .oneByTwoPlate, .oneByFourPlate, .twoByTwoPlate, .twoByFourPlate, .twoBySixPlate:
            return .plate
        }
    }

    var partNumber: String {
        switch self {
        case .oneByOne: return "3005"
        case .oneByTwo: return "3004"
        case .oneByFour: return "3010"
        case .twoByTwo: return "3003"
        case .twoByFour: return "3001"
        case .twoBySix: return "2456"
        case .oneByOnePlate: return "3024"
        case .oneByTwoPlate: return "3023"
        case .oneByFourPlate: return "3710"
        case .twoByTwoPlate: return "3022"
        case .twoByFourPlate: return "3020"
        case .twoBySixPlate: return "3795"
        }
    }

    var displayName: String {
        switch self {
        case .oneByOne: return "1 x 1 Brick"
        case .oneByTwo: return "1 x 2 Brick"
        case .oneByFour: return "1 x 4 Brick"
        case .twoByTwo: return "2 x 2 Brick"
        case .twoByFour: return "2 x 4 Brick"
        case .twoBySix: return "2 x 6 Brick"
        case .oneByOnePlate: return "1 x 1 Plate"
        case .oneByTwoPlate: return "1 x 2 Plate"
        case .oneByFourPlate: return "1 x 4 Plate"
        case .twoByTwoPlate: return "2 x 2 Plate"
        case .twoByFourPlate: return "2 x 4 Plate"
        case .twoBySixPlate: return "2 x 6 Plate"
        }
    }

    static func partNumber(_ partNumber: String) -> LegoBrickSize? {
        allCases.first { $0.partNumber == partNumber }
    }
}

enum LegoBrickColor: String, CaseIterable, Identifiable, Codable {
    case classicRed
    case brightBlue
    case brightYellow
    case orange
    case tan
    case black
    case white
    case darkGreen
    case lightBluishGray
    case darkBluishGray
    case reddishBrown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classicRed: return "Red"
        case .brightBlue: return "Blue"
        case .brightYellow: return "Yellow"
        case .orange: return "Orange"
        case .tan: return "Tan"
        case .black: return "Black"
        case .white: return "White"
        case .darkGreen: return "Green"
        case .lightBluishGray: return "Light Gray"
        case .darkBluishGray: return "Dark Gray"
        case .reddishBrown: return "Brown"
        }
    }

    /// BrickLink catalog color IDs for compatible wanted-list export.
    var brickLinkColorId: Int {
        switch self {
        case .white: return 1
        case .tan: return 2
        case .brightYellow: return 3
        case .orange: return 4
        case .classicRed: return 5
        case .darkGreen: return 6
        case .brightBlue: return 7
        case .black: return 11
        case .darkBluishGray: return 85
        case .lightBluishGray: return 86
        case .reddishBrown: return 88
        }
    }

    static func brickLinkColorId(_ id: Int) -> LegoBrickColor? {
        allCases.first { $0.brickLinkColorId == id }
    }
}

// Canonical Brick Bench palette, ported from the desktop
// `LegoBrickColor+Appearance.swift` so a brick reads the same colour on iOS as
// it does on the Mac. The 2D board, palette swatches, and 3D preview all derive
// from `rgb`, so nothing drifts.
extension LegoBrickColor {
    var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .classicRed: return (0.76, 0.05, 0.08)
        case .brightBlue: return (0.04, 0.28, 0.72)
        case .brightYellow: return (0.95, 0.78, 0.08)
        case .orange: return (0.92, 0.36, 0.08)
        case .tan: return (0.70, 0.56, 0.38)
        case .black: return (0.05, 0.05, 0.05)
        case .white: return (1.00, 1.00, 1.00)
        case .darkGreen: return (0.05, 0.38, 0.18)
        case .lightBluishGray: return (0.62, 0.66, 0.68)
        case .darkBluishGray: return (0.25, 0.27, 0.28)
        case .reddishBrown: return (0.35, 0.16, 0.08)
        }
    }

    var swatch: Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// SceneKit material color, matching the desktop `nsColor` accessor so a
    /// brick reads the same in the 3D scene as in the 2D palette swatch.
    var uiColor: UIColor {
        UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}

struct LegoBrick: Identifiable, Hashable, Codable {
    var id: UUID
    var size: LegoBrickSize
    var color: LegoBrickColor
    var origin: LegoGridPoint
    var layer: Int
    /// Quarter-turns (0...3) about the vertical axis. Odd values swap the
    /// footprint so a 2x4 occupies 4x2 studs on the board.
    var rotationQuarters: Int

    init(id: UUID = UUID(), size: LegoBrickSize, color: LegoBrickColor,
         origin: LegoGridPoint, layer: Int, rotationQuarters: Int = 0) {
        self.id = id
        self.size = size
        self.color = color
        self.origin = origin
        self.layer = layer
        self.rotationQuarters = ((rotationQuarters % 4) + 4) % 4
    }

    /// Board footprint after rotation (studs along grid x).
    var footprintWide: Int { rotationQuarters % 2 == 0 ? size.studsWide : size.studsDeep }
    /// Board footprint after rotation (studs along grid y).
    var footprintDeep: Int { rotationQuarters % 2 == 0 ? size.studsDeep : size.studsWide }
}

struct LegoPartSummary: Hashable, Identifiable {
    var partNumber: String
    var color: LegoBrickColor
    var quantity: Int

    var id: String { "\(partNumber)-\(color.rawValue)" }
}

struct LegoBuildDocument: Hashable, Codable {
    var bricks: [LegoBrick] = []

    mutating func add(_ brick: LegoBrick) {
        bricks.append(brick)
    }

    mutating func clear() {
        bricks.removeAll()
    }

    /// Duplicate a placed brick one stud to the right when possible, preserving
    /// its size, colour, layer, and rotation. Returns the new brick id.
    mutating func duplicate(id: UUID, gridSize: Int) -> UUID? {
        guard let brick = bricks.first(where: { $0.id == id }) else { return nil }
        let copy = LegoBrick(
            size: brick.size,
            color: brick.color,
            origin: Self.clampOrigin(
                LegoGridPoint(x: brick.origin.x + 1, y: brick.origin.y),
                wide: brick.footprintWide,
                deep: brick.footprintDeep,
                gridSize: gridSize
            ),
            layer: brick.layer,
            rotationQuarters: brick.rotationQuarters
        )
        bricks.append(copy)
        return copy.id
    }

    /// Translate a placed brick by whole-stud / whole-layer deltas, keeping its
    /// footprint on the board and its layer at or above the baseplate. A no-op
    /// if no brick has the given id. (Translation only — never resizes.)
    mutating func move(id: UUID, dx: Int, dy: Int, dLayer: Int, gridSize: Int) {
        guard let i = bricks.firstIndex(where: { $0.id == id }) else { return }
        var brick = bricks[i]
        brick.origin = Self.clampOrigin(
            LegoGridPoint(x: brick.origin.x + dx, y: brick.origin.y + dy),
            wide: brick.footprintWide, deep: brick.footprintDeep, gridSize: gridSize
        )
        brick.layer = min(max(brick.layer + dLayer, 0), gridSize)
        bricks[i] = brick
    }

    /// Rotate a placed brick by `quarters` 90° turns, re-clamping its (possibly
    /// swapped) footprint back onto the board. No-op for an unknown id.
    mutating func rotate(id: UUID, by quarters: Int, gridSize: Int) {
        guard let i = bricks.firstIndex(where: { $0.id == id }) else { return }
        var brick = bricks[i]
        brick.rotationQuarters = (((brick.rotationQuarters + quarters) % 4) + 4) % 4
        brick.origin = Self.clampOrigin(brick.origin,
                                        wide: brick.footprintWide, deep: brick.footprintDeep,
                                        gridSize: gridSize)
        bricks[i] = brick
    }

    private static func clampOrigin(_ origin: LegoGridPoint, wide: Int, deep: Int, gridSize: Int) -> LegoGridPoint {
        LegoGridPoint(
            x: min(max(origin.x, 0), max(0, gridSize - wide)),
            y: min(max(origin.y, 0), max(0, gridSize - deep))
        )
    }

    var partsSummary: [LegoPartSummary] {
        let grouped = Dictionary(grouping: bricks) { brick in
            "\(brick.size.partNumber)|\(brick.color.rawValue)"
        }

        return grouped.values.map { group in
            let first = group[0]
            return LegoPartSummary(
                partNumber: first.size.partNumber,
                color: first.color,
                quantity: group.count
            )
        }
        .sorted {
            if $0.partNumber == $1.partNumber {
                return $0.color.displayName < $1.color.displayName
            }
            return $0.partNumber < $1.partNumber
        }
    }
}

enum BrickLinkWantedListExporter {
    static func xml(for document: LegoBuildDocument) -> String {
        var lines = ["<INVENTORY>"]
        for part in document.partsSummary {
            lines.append("  <ITEM>")
            lines.append("    <ITEMTYPE>P</ITEMTYPE>")
            lines.append("    <ITEMID>\(part.partNumber)</ITEMID>")
            lines.append("    <COLOR>\(part.color.brickLinkColorId)</COLOR>")
            lines.append("    <MINQTY>\(part.quantity)</MINQTY>")
            lines.append("    <CONDITION>N</CONDITION>")
            lines.append("  </ITEM>")
        }
        lines.append("</INVENTORY>")
        return lines.joined(separator: "\n")
    }
}

enum BrickLinkWantedListImporter {
    static func document(from xml: String) throws -> LegoBuildDocument {
        let parser = BrickLinkWantedListXMLParser()
        return try parser.parse(xml)
    }
}

enum BrickLinkWantedListImportError: Error {
    case invalidXML
}

private final class BrickLinkWantedListXMLParser: NSObject, XMLParserDelegate {
    private var document = LegoBuildDocument()
    private var currentElement = ""
    private var currentItem: [String: String] = [:]
    private var currentText = ""
    private var parseError: Error?

    func parse(_ xml: String) throws -> LegoBuildDocument {
        guard let data = xml.data(using: .utf8) else {
            throw BrickLinkWantedListImportError.invalidXML
        }

        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse(), parseError == nil else {
            throw parseError ?? parser.parserError ?? BrickLinkWantedListImportError.invalidXML
        }
        return document
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName.uppercased()
        currentText = ""
        if currentElement == "ITEM" {
            currentItem = [:]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let normalized = elementName.uppercased()
        if normalized == "ITEM" {
            appendCurrentItem()
            currentItem = [:]
        } else if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            currentItem[normalized] = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        currentElement = ""
        currentText = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    private func appendCurrentItem() {
        guard currentItem["ITEMTYPE"] == nil || currentItem["ITEMTYPE"] == "P",
              let itemId = currentItem["ITEMID"],
              let size = LegoBrickSize.partNumber(itemId),
              let colorText = currentItem["COLOR"],
              let colorId = Int(colorText),
              let color = LegoBrickColor.brickLinkColorId(colorId) else {
            return
        }

        let quantity = max(1, Int(currentItem["MINQTY"] ?? "") ?? 1)
        for index in 0..<quantity {
            document.add(LegoBrick(
                size: size,
                color: color,
                origin: LegoGridPoint(x: (index * size.studsWide) % 12, y: ((index * size.studsWide) / 12) * size.studsDeep),
                layer: 0
            ))
        }
    }
}
