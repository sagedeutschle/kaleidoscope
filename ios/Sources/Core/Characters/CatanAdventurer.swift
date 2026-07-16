import Foundation

enum CatanAbility: String, CaseIterable, Codable, Hashable {
    case strength, dexterity, constitution, intelligence, wisdom, charisma

    var displayName: String { rawValue.capitalized }
}

struct CatanAbilityScores: Codable, Equatable, Hashable {
    var strength: Int
    var dexterity: Int
    var constitution: Int
    var intelligence: Int
    var wisdom: Int
    var charisma: Int

    static let standardArray = [15, 14, 13, 12, 10, 8]

    var values: [Int] { CatanAbility.allCases.map { self[$0] } }
    var isStandardArray: Bool { values.sorted(by: >) == Self.standardArray }

    subscript(_ ability: CatanAbility) -> Int {
        get {
            switch ability {
            case .strength: return strength
            case .dexterity: return dexterity
            case .constitution: return constitution
            case .intelligence: return intelligence
            case .wisdom: return wisdom
            case .charisma: return charisma
            }
        }
        set {
            switch ability {
            case .strength: strength = newValue
            case .dexterity: dexterity = newValue
            case .constitution: constitution = newValue
            case .intelligence: intelligence = newValue
            case .wisdom: wisdom = newValue
            case .charisma: charisma = newValue
            }
        }
    }

    static func modifier(forScore score: Int) -> Int {
        Int(floor(Double(score - 10) / 2.0))
    }

    static func assigning(_ values: [Int], in order: [CatanAbility]) -> Self? {
        guard values.sorted(by: >) == standardArray,
              order.count == CatanAbility.allCases.count,
              Set(order) == Set(CatanAbility.allCases)
        else { return nil }

        var result = Self(strength: 8, dexterity: 8, constitution: 8, intelligence: 8, wisdom: 8, charisma: 8)
        for (ability, value) in zip(order, values) {
            result[ability] = value
        }
        return result
    }

    static func recommended(for choice: CatanAdventurerClass) -> Self {
        guard let scores = assigning(standardArray, in: choice.recommendedAbilityOrder) else {
            preconditionFailure("Every class recommendation must assign the complete standard array")
        }
        return scores
    }
}

enum CatanAdventurerClass: String, CaseIterable, Codable, Hashable, Identifiable {
    case barbarian, bard, cleric, druid, fighter, monk
    case paladin, ranger, rogue, sorcerer, warlock, wizard

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var summary: String {
        switch self {
        case .barbarian: return "Meet every challenge with fearless momentum."
        case .bard: return "Turn a clever word into a memorable opening."
        case .cleric: return "Bring steady purpose to the party's path."
        case .druid: return "Read the wild world and move with it."
        case .fighter: return "Choose a clear plan and hold the line."
        case .monk: return "Find focus before making the next move."
        case .paladin: return "Lead with a promise worth keeping."
        case .ranger: return "Scout the horizon and prepare the route."
        case .rogue: return "Spot an opening others might overlook."
        case .sorcerer: return "Let bold instinct light the way."
        case .warlock: return "Make a daring choice with intent."
        case .wizard: return "Study the pattern before you act."
        }
    }

    var symbolName: String {
        switch self {
        case .barbarian: return "flame.fill"
        case .bard: return "music.note"
        case .cleric: return "cross.case.fill"
        case .druid: return "leaf.fill"
        case .fighter: return "shield.fill"
        case .monk: return "figure.mind.and.body"
        case .paladin: return "shield.lefthalf.filled"
        case .ranger: return "scope"
        case .rogue: return "eye.fill"
        case .sorcerer: return "sparkles"
        case .warlock: return "moon.stars.fill"
        case .wizard: return "wand.and.stars"
        }
    }

    var recommendedAbilityOrder: [CatanAbility] {
        switch self {
        case .barbarian: return [.strength, .constitution, .dexterity, .wisdom, .charisma, .intelligence]
        case .bard: return [.charisma, .dexterity, .constitution, .wisdom, .intelligence, .strength]
        case .cleric: return [.wisdom, .constitution, .strength, .charisma, .dexterity, .intelligence]
        case .druid: return [.wisdom, .constitution, .dexterity, .intelligence, .charisma, .strength]
        case .fighter: return [.strength, .constitution, .dexterity, .wisdom, .charisma, .intelligence]
        case .monk: return [.dexterity, .wisdom, .constitution, .strength, .charisma, .intelligence]
        case .paladin: return [.strength, .charisma, .constitution, .wisdom, .dexterity, .intelligence]
        case .ranger: return [.dexterity, .wisdom, .constitution, .strength, .charisma, .intelligence]
        case .rogue: return [.dexterity, .constitution, .charisma, .wisdom, .intelligence, .strength]
        case .sorcerer: return [.charisma, .constitution, .dexterity, .wisdom, .intelligence, .strength]
        case .warlock: return [.charisma, .constitution, .dexterity, .wisdom, .intelligence, .strength]
        case .wizard: return [.intelligence, .constitution, .dexterity, .wisdom, .charisma, .strength]
        }
    }
}

enum CatanAdventurerSpecies: String, CaseIterable, Codable, Hashable, Identifiable {
    case dragonborn, dwarf, elf, gnome, goliath, halfling, human, orc, tiefling

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var summary: String {
        switch self {
        case .dragonborn: return "Carry a proud spark into every new place."
        case .dwarf: return "Build trust through patience and craft."
        case .elf: return "Bring long sight to the road ahead."
        case .gnome: return "Keep wonder close at hand."
        case .goliath: return "Face tall odds with a calm heart."
        case .halfling: return "Find courage in the small details."
        case .human: return "Make room for every kind of possibility."
        case .orc: return "Move forward with honest strength."
        case .tiefling: return "Choose your own bright path."
        }
    }

    var symbolName: String {
        switch self {
        case .dragonborn: return "flame.fill"
        case .dwarf: return "hammer.fill"
        case .elf: return "leaf.fill"
        case .gnome: return "gearshape.fill"
        case .goliath: return "mountain.2.fill"
        case .halfling: return "hands.clap.fill"
        case .human: return "person.fill"
        case .orc: return "figure.strengthtraining.traditional"
        case .tiefling: return "moon.fill"
        }
    }
}

enum CatanAdventurerBackground: String, CaseIterable, Codable, Hashable, Identifiable {
    case acolyte, criminal, sage, soldier

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var summary: String {
        switch self {
        case .acolyte: return "A life shaped by service and reflection."
        case .criminal: return "A survivor with a talent for reading a room."
        case .sage: return "A curious mind always gathering clues."
        case .soldier: return "A teammate who understands preparation."
        }
    }

    var symbolName: String {
        switch self {
        case .acolyte: return "candle.fill"
        case .criminal: return "key.fill"
        case .sage: return "book.closed.fill"
        case .soldier: return "shield.fill"
        }
    }
}

enum CatanAdventurerCrest: String, CaseIterable, Codable, Hashable, Identifiable {
    case shield, star, wave, leaf, flame, mountain

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var summary: String {
        switch self {
        case .shield: return "A steady emblem for a dependable guide."
        case .star: return "A bright mark for a hopeful explorer."
        case .wave: return "A flowing seal for an adaptable traveler."
        case .leaf: return "A living sign for a thoughtful pathfinder."
        case .flame: return "A warm banner for a bold companion."
        case .mountain: return "A high standard for a patient climber."
        }
    }

    var symbolName: String {
        switch self {
        case .shield: return "shield.fill"
        case .star: return "star.fill"
        case .wave: return "water.waves"
        case .leaf: return "leaf.fill"
        case .flame: return "flame.fill"
        case .mountain: return "mountain.2.fill"
        }
    }
}

enum CatanCreatorStep: String, CaseIterable, Codable, Hashable, Identifiable {
    case calling, origin, abilities, identity, review

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum CatanAdventurerValidationError: Error, Equatable {
    case emptyName, nameTooLong, invalidStandardArray
}

struct CatanAdventurerDraft: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var classChoice: CatanAdventurerClass
    var species: CatanAdventurerSpecies
    var background: CatanAdventurerBackground
    var abilities: CatanAbilityScores
    var crest: CatanAdventurerCrest
    var step: CatanCreatorStep
    var didCustomizeAbilities: Bool

    static func new(id: UUID = UUID()) -> Self {
        Self(id: id, name: "", classChoice: .fighter, species: .human,
             background: .soldier, abilities: .recommended(for: .fighter),
             crest: .shield, step: .calling, didCustomizeAbilities: false)
    }

    mutating func chooseClass(_ choice: CatanAdventurerClass) {
        classChoice = choice
        if !didCustomizeAbilities {
            abilities = .recommended(for: choice)
        }
    }

    mutating func swapAbilities(_ first: CatanAbility, _ second: CatanAbility) {
        guard first != second else { return }
        let old = abilities[first]
        abilities[first] = abilities[second]
        abilities[second] = old
        didCustomizeAbilities = true
    }
}

struct CatanAdventurer: Codable, Equatable, Hashable, Identifiable {
    static let currentSchemaVersion = 1

    var id: UUID
    let schemaVersion: Int
    var name: String
    var classChoice: CatanAdventurerClass
    var species: CatanAdventurerSpecies
    var background: CatanAdventurerBackground
    var abilities: CatanAbilityScores
    var crest: CatanAdventurerCrest
    let level: Int

    private enum CodingKeys: String, CodingKey {
        case id, schemaVersion, name, classChoice, species, background, abilities, crest, level
    }

    private init(id: UUID, schemaVersion: Int, name: String,
                 classChoice: CatanAdventurerClass, species: CatanAdventurerSpecies,
                 background: CatanAdventurerBackground, abilities: CatanAbilityScores,
                 crest: CatanAdventurerCrest, level: Int) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.classChoice = classChoice
        self.species = species
        self.background = background
        self.abilities = abilities
        self.crest = crest
        self.level = level
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSchemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard decodedSchemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported Quick Adventurer schema version."
            )
        }
        let decodedLevel = try container.decode(Int.self, forKey: .level)
        guard decodedLevel == 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .level,
                in: container,
                debugDescription: "Quick Adventurer supports level 1 characters only."
            )
        }
        id = try container.decode(UUID.self, forKey: .id)
        schemaVersion = decodedSchemaVersion
        name = try container.decode(String.self, forKey: .name)
        classChoice = try container.decode(CatanAdventurerClass.self, forKey: .classChoice)
        species = try container.decode(CatanAdventurerSpecies.self, forKey: .species)
        background = try container.decode(CatanAdventurerBackground.self, forKey: .background)
        abilities = try container.decode(CatanAbilityScores.self, forKey: .abilities)
        crest = try container.decode(CatanAdventurerCrest.self, forKey: .crest)
        level = decodedLevel
    }

    static func make(from draft: CatanAdventurerDraft) throws -> Self {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CatanAdventurerValidationError.emptyName }
        guard name.count <= 24 else { throw CatanAdventurerValidationError.nameTooLong }
        guard draft.abilities.isStandardArray else { throw CatanAdventurerValidationError.invalidStandardArray }
        return Self(id: draft.id, schemaVersion: currentSchemaVersion, name: name,
                    classChoice: draft.classChoice, species: draft.species,
                    background: draft.background, abilities: draft.abilities,
                    crest: draft.crest, level: 1)
    }

    var editableDraft: CatanAdventurerDraft {
        CatanAdventurerDraft(id: id, name: name, classChoice: classChoice,
                             species: species, background: background, abilities: abilities,
                             crest: crest, step: .calling, didCustomizeAbilities: true)
    }
}

enum CatanRulesAttribution {
    static let version = "5.2.1"
    static let sourceURL = URL(string: "https://www.dndbeyond.com/srd")!
    static let licenseURL = URL(string: "https://creativecommons.org/licenses/by/4.0/legalcode")!
    static let notice = "This work includes material from the System Reference Document 5.2.1 (\"SRD 5.2.1\") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode."
}
