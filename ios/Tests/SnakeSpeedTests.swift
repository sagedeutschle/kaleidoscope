import XCTest
@testable import Kaleidoscope

final class SnakeSpeedTests: XCTestCase {

    // MARK: Speed curve

    /// The snake must start at a pace a human can react to. Tester feedback was
    /// "could start slower" — assert the opening tick is comfortably gentle.
    func testInitialIntervalIsGentle() {
        let gentleThreshold = 0.28
        XCTAssertGreaterThanOrEqual(SnakeGame.tickInterval(forScore: 0), gentleThreshold)
        XCTAssertEqual(SnakeGame.tickInterval(forScore: 0), SnakeGame.initialTickInterval, accuracy: 1e-9)
    }

    /// Difficulty must ramp smoothly: never speed *down* as the score grows.
    func testIntervalIsMonotonicNonIncreasing() {
        var previous = SnakeGame.tickInterval(forScore: 0)
        for score in 1...200 {
            let current = SnakeGame.tickInterval(forScore: score)
            XCTAssertLessThanOrEqual(current, previous, "interval increased at score \(score)")
            previous = current
        }
    }

    /// The ramp actually happens for a while (not flat from the start).
    func testIntervalDecreasesEarly() {
        XCTAssertLessThan(SnakeGame.tickInterval(forScore: 5), SnakeGame.tickInterval(forScore: 0))
    }

    /// Speed is clamped so late-game never becomes impossible.
    func testIntervalClampsAtFloor() {
        XCTAssertEqual(SnakeGame.tickInterval(forScore: 100_000), SnakeGame.minTickInterval, accuracy: 1e-9)
        for score in 0...100_000 where score % 137 == 0 {
            XCTAssertGreaterThanOrEqual(SnakeGame.tickInterval(forScore: score), SnakeGame.minTickInterval)
        }
    }

    /// Negative / defensive input never explodes the interval past the start pace.
    func testIntervalNeverExceedsStart() {
        XCTAssertLessThanOrEqual(SnakeGame.tickInterval(forScore: -50), SnakeGame.initialTickInterval)
        XCTAssertGreaterThanOrEqual(SnakeGame.tickInterval(forScore: -50), SnakeGame.minTickInterval)
    }

    // MARK: Responsiveness — buffered input + reversal guard

    /// A turn is buffered, then committed on the next step.
    func testBufferedTurnCommitsOnStep() {
        var rng = SeededGenerator(seed: 1)
        var game = SnakeGame() // heading .right
        game.turn(.up)
        XCTAssertEqual(game.direction, .right, "turn should not mutate heading before a step")
        XCTAssertEqual(game.pendingDirection, .up)
        game.step(rng: &rng)
        XCTAssertEqual(game.direction, .up)
        XCTAssertNil(game.pendingDirection, "pending turn is consumed by the step")
    }

    /// A direct 180° reversal is ignored (would drive the head into the neck).
    func testInstantReversalIsRejected() {
        var rng = SeededGenerator(seed: 1)
        var game = SnakeGame() // heading .right
        game.turn(.left)       // opposite — must be ignored
        XCTAssertNil(game.pendingDirection)
        game.step(rng: &rng)
        XCTAssertEqual(game.direction, .right)
    }

    /// Two quick swipes: the last valid one wins and only one turn commits per tick.
    func testLatestValidTurnWinsWithinOneTick() {
        var rng = SeededGenerator(seed: 1)
        var game = SnakeGame() // heading .right
        game.turn(.up)
        game.turn(.down)       // both are valid 90° turns off .right; the later one replaces the buffer
        XCTAssertEqual(game.pendingDirection, .down)
        game.step(rng: &rng)
        XCTAssertEqual(game.direction, .down)
    }

    /// A fast right → up → (attempt) right-reversal flick can't fold the snake back:
    /// while heading right, a down-then-up sequence must not sneak a reversal in.
    func testFlickCannotProduceReversal() {
        var rng = SeededGenerator(seed: 1)
        var game = SnakeGame() // heading .right
        game.turn(.up)         // valid, buffered
        game.step(rng: &rng)   // now heading .up
        game.turn(.down)       // .down is opposite of .up — must be ignored
        XCTAssertNil(game.pendingDirection)
        game.step(rng: &rng)
        XCTAssertEqual(game.direction, .up)
    }
}
