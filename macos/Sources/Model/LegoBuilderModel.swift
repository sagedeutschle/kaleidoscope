import Foundation

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
