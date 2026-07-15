import Foundation
import XCTest
@testable import PrismetShared

final class PrismetBlackjackObservationTests: XCTestCase {
    func testActiveObservationConcealsSeedHoleCardAndDrawOrder() throws {
        let dealerHole = PrismetBlackjackFixtures.card(.king, .spades)
        let deck = PrismetBlackjackFixtures.deck(drawing: [
            PrismetBlackjackFixtures.card(.ten, .clubs),
            PrismetBlackjackFixtures.card(.five, .diamonds),
            PrismetBlackjackFixtures.card(.six, .hearts),
            dealerHole
        ])
        let started = try PrismetBlackjackEngine.start(seed: 847_211, shuffledDeck: deck)
        let observation = PrismetBlackjackEngine.observation(for: started.state)
        let json = String(decoding: try JSONEncoder().encode(observation), as: UTF8.self)

        XCTAssertEqual(observation.dealerCards.count, 2)
        XCTAssertEqual(observation.dealerCards.last, .faceDown)
        XCTAssertNil(observation.dealerFinalValue)
        XCTAssertFalse(json.contains(dealerHole.id))
        XCTAssertFalse(json.contains("seed"))
        XCTAssertFalse(json.contains("shuffledDeck"))
        XCTAssertFalse(json.contains("drawIndex"))
    }

    func testTerminalObservationRevealsDealerCardsAndFinalValue() throws {
        let dealerUp = PrismetBlackjackFixtures.card(.ten, .diamonds)
        let dealerHole = PrismetBlackjackFixtures.card(.eight, .spades)
        let deck = PrismetBlackjackFixtures.deck(drawing: [
            PrismetBlackjackFixtures.card(.ten, .clubs), dealerUp,
            PrismetBlackjackFixtures.card(.nine, .hearts), dealerHole
        ])
        let started = try PrismetBlackjackEngine.start(seed: 44, shuffledDeck: deck)

        let terminal = try PrismetBlackjackEngine.applying(.stand, to: started.state)
        let observation = PrismetBlackjackEngine.observation(for: terminal.state)

        XCTAssertEqual(observation.dealerCards, [.faceUp(dealerUp), .faceUp(dealerHole)])
        XCTAssertEqual(observation.dealerFinalValue?.total, 18)
        XCTAssertNil(observation.hitOdds)
    }
}
