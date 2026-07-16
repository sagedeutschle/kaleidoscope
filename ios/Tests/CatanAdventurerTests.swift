import XCTest
@testable import Prismet

final class CatanAdventurerTests: XCTestCase {
    func testSRDChoiceCountsAndNamesArePinned() {
        XCTAssertEqual(CatanAdventurerClass.allCases.map(\.displayName), [
            "Barbarian", "Bard", "Cleric", "Druid", "Fighter", "Monk",
            "Paladin", "Ranger", "Rogue", "Sorcerer", "Warlock", "Wizard"
        ])
        XCTAssertEqual(CatanAdventurerSpecies.allCases.map(\.displayName), [
            "Dragonborn", "Dwarf", "Elf", "Gnome", "Goliath", "Halfling", "Human", "Orc", "Tiefling"
        ])
        XCTAssertEqual(CatanAdventurerBackground.allCases.map(\.displayName), [
            "Acolyte", "Criminal", "Sage", "Soldier"
        ])
        XCTAssertEqual(CatanAdventurerCrest.allCases.count, 6)
    }

    func testClassRecommendationUsesStandardArrayExactlyOnce() {
        let scores = CatanAbilityScores.recommended(for: .wizard)
        XCTAssertEqual(scores[.intelligence], 15)
        XCTAssertTrue(scores.isStandardArray)
        XCTAssertEqual(scores.values.sorted(by: >), [15, 14, 13, 12, 10, 8])
    }

    func testEveryClassRecommendationIsACompleteAbilityPermutation() {
        for choice in CatanAdventurerClass.allCases {
            XCTAssertEqual(choice.recommendedAbilityOrder.count, CatanAbility.allCases.count)
            XCTAssertEqual(Set(choice.recommendedAbilityOrder), Set(CatanAbility.allCases))
            XCTAssertTrue(CatanAbilityScores.recommended(for: choice).isStandardArray)
        }
    }

    func testAssigningAcceptsOnlyTheStandardArrayAndCompleteAbilityOrder() throws {
        let charismaFirst: [CatanAbility] = [
            .charisma, .dexterity, .constitution, .wisdom, .intelligence, .strength
        ]
        let scores = try XCTUnwrap(CatanAbilityScores.assigning([15, 14, 13, 12, 10, 8], in: charismaFirst))
        XCTAssertEqual(scores[.charisma], 15)
        XCTAssertEqual(scores[.strength], 8)
        XCTAssertNil(CatanAbilityScores.assigning([15, 14, 13, 12, 10, 9], in: charismaFirst))
        XCTAssertNil(CatanAbilityScores.assigning([15, 14, 13, 12, 10, 8], in: Array(repeating: .strength, count: 6)))
    }

    func testAbilityModifiersUseFloorSemantics() {
        XCTAssertEqual(CatanAbilityScores.modifier(forScore: 15), 2)
        XCTAssertEqual(CatanAbilityScores.modifier(forScore: 10), 0)
        XCTAssertEqual(CatanAbilityScores.modifier(forScore: 9), -1)
        XCTAssertEqual(CatanAbilityScores.modifier(forScore: 8), -1)
    }

    func testMakeTrimsNameAndLocksLevelOne() throws {
        var draft = CatanAdventurerDraft.new()
        draft.name = "  Rowan  "
        let character = try CatanAdventurer.make(from: draft)
        XCTAssertEqual(character.name, "Rowan")
        XCTAssertEqual(character.level, 1)
        XCTAssertEqual(character.schemaVersion, 1)
    }

    func testMakeRejectsEmptyLongAndNonStandardDrafts() {
        var draft = CatanAdventurerDraft.new()
        XCTAssertThrowsError(try CatanAdventurer.make(from: draft)) {
            XCTAssertEqual($0 as? CatanAdventurerValidationError, .emptyName)
        }
        draft.name = String(repeating: "A", count: 25)
        XCTAssertThrowsError(try CatanAdventurer.make(from: draft)) {
            XCTAssertEqual($0 as? CatanAdventurerValidationError, .nameTooLong)
        }
        draft.name = "Rowan"
        draft.abilities.strength = 15
        draft.abilities.dexterity = 15
        XCTAssertThrowsError(try CatanAdventurer.make(from: draft)) {
            XCTAssertEqual($0 as? CatanAdventurerValidationError, .invalidStandardArray)
        }
    }

    func testNameLimitCountsExtendedGraphemeClusters() throws {
        var draft = CatanAdventurerDraft.new()
        draft.name = String(repeating: "👩🏽‍🚀", count: 24)
        XCTAssertNoThrow(try CatanAdventurer.make(from: draft))

        draft.name.append("👩🏽‍🚀")
        XCTAssertThrowsError(try CatanAdventurer.make(from: draft)) {
            XCTAssertEqual($0 as? CatanAdventurerValidationError, .nameTooLong)
        }
    }

    func testChoosingClassRefreshesUntouchedRecommendations() {
        var draft = CatanAdventurerDraft.new()
        draft.chooseClass(.wizard)

        XCTAssertEqual(draft.classChoice, .wizard)
        XCTAssertEqual(draft.abilities, .recommended(for: .wizard))
        XCTAssertFalse(draft.didCustomizeAbilities)
    }

    func testChoosingClassPreservesCustomizedAbilities() {
        var draft = CatanAdventurerDraft.new()
        draft.swapAbilities(.strength, .dexterity)
        let customized = draft.abilities

        draft.chooseClass(.wizard)

        XCTAssertEqual(draft.classChoice, .wizard)
        XCTAssertEqual(draft.abilities, customized)
        XCTAssertTrue(draft.didCustomizeAbilities)
    }

    func testSwappingAnAbilityWithItselfDoesNotMarkDraftCustomized() {
        var draft = CatanAdventurerDraft.new()
        draft.swapAbilities(.strength, .strength)

        XCTAssertFalse(draft.didCustomizeAbilities)
    }

    func testCharacterDecodingRejectsLevelAboveOne() throws {
        var draft = CatanAdventurerDraft.new()
        draft.name = "Rowan"
        let encoded = try JSONEncoder().encode(CatanAdventurer.make(from: draft))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["level"] = 2
        let invalid = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try JSONDecoder().decode(CatanAdventurer.self, from: invalid))
    }

    func testCharacterDecodingRejectsUnsupportedSchemaVersion() throws {
        var draft = CatanAdventurerDraft.new()
        draft.name = "Rowan"
        let encoded = try JSONEncoder().encode(CatanAdventurer.make(from: draft))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["schemaVersion"] = 2
        let invalid = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try JSONDecoder().decode(CatanAdventurer.self, from: invalid))
    }

    func testCharacterAndDraftRoundTrip() throws {
        var draft = CatanAdventurerDraft.new()
        draft.name = "Rowan"
        draft.step = .review
        let character = try CatanAdventurer.make(from: draft)
        XCTAssertEqual(try JSONDecoder().decode(CatanAdventurer.self, from: JSONEncoder().encode(character)), character)
        XCTAssertEqual(try JSONDecoder().decode(CatanAdventurerDraft.self, from: JSONEncoder().encode(draft)), draft)
    }

    func testAttributionPinsVersionSourceAndLicense() {
        let requiredNotice = "This work includes material from the System Reference Document 5.2.1 (\"SRD 5.2.1\") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode."
        XCTAssertEqual(CatanRulesAttribution.notice, requiredNotice)
        XCTAssertEqual(CatanRulesAttribution.version, "5.2.1")
        XCTAssertEqual(CatanRulesAttribution.sourceURL.absoluteString, "https://www.dndbeyond.com/srd")
        XCTAssertEqual(CatanRulesAttribution.licenseURL.absoluteString, "https://creativecommons.org/licenses/by/4.0/legalcode")
    }
}
