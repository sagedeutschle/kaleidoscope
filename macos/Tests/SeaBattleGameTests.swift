import XCTest
@testable import Prismet

final class SeaBattleGameTests: XCTestCase {
    func testNewGamePlacesFleetForBothPlayers() {
        let game = SeaBattleGame.newGame(seed: 11)

        XCTAssertEqual(game.board(for: .host).shipCells.count, SeaBattleGame.fleet.reduce(0, +))
        XCTAssertEqual(game.board(for: .guest).shipCells.count, SeaBattleGame.fleet.reduce(0, +))
        XCTAssertEqual(game.currentPlayer, .host)
    }

    func testShotRecordsHitAndPassesTurn() throws {
        let target = SeaBattlePoint(row: 2, col: 3)
        var game = SeaBattleGame(
            boards: [
                .host: SeaBattleBoard(shipCells: []),
                .guest: SeaBattleBoard(shipCells: [target])
            ],
            currentPlayer: .host
        )

        XCTAssertEqual(game.fire(at: target), .hit)
        XCTAssertTrue(game.board(for: .guest).shots.contains(target))
        XCTAssertEqual(game.currentPlayer, .host)
        XCTAssertEqual(game.winner, .host)
    }

    func testRepeatedShotIsRejected() {
        let target = SeaBattlePoint(row: 1, col: 1)
        var game = SeaBattleGame(
            boards: [
                .host: SeaBattleBoard(shipCells: []),
                .guest: SeaBattleBoard(shipCells: [], shots: [target])
            ],
            currentPlayer: .host
        )

        XCTAssertEqual(game.fire(at: target), .alreadyTried)
        XCTAssertEqual(game.currentPlayer, .host)
    }

    func testMissPassesTurnToOpponent() {
        var game = SeaBattleGame(
            boards: [
                .host: SeaBattleBoard(shipCells: []),
                .guest: SeaBattleBoard(shipCells: [])
            ],
            currentPlayer: .host
        )

        XCTAssertEqual(game.fire(at: SeaBattlePoint(row: 0, col: 0)), .miss)
        XCTAssertEqual(game.currentPlayer, .guest)
    }

    func testFleetDeploymentAcceptsStandardBattleshipFleet() {
        var deployment = SeaBattleFleetDeployment()

        XCTAssertTrue(deployment.place(length: 5, at: SeaBattlePoint(row: 0, col: 0), orientation: .horizontal))
        XCTAssertTrue(deployment.place(length: 4, at: SeaBattlePoint(row: 2, col: 0), orientation: .horizontal))
        XCTAssertTrue(deployment.place(length: 3, at: SeaBattlePoint(row: 4, col: 0), orientation: .horizontal))
        XCTAssertTrue(deployment.place(length: 3, at: SeaBattlePoint(row: 6, col: 0), orientation: .horizontal))
        XCTAssertTrue(deployment.place(length: 2, at: SeaBattlePoint(row: 8, col: 0), orientation: .horizontal))

        XCTAssertTrue(deployment.isComplete)
        XCTAssertEqual(deployment.shipCells.count, SeaBattleGame.fleet.reduce(0, +))
    }

    func testFleetDeploymentRejectsOffBoardShip() {
        var deployment = SeaBattleFleetDeployment()

        XCTAssertFalse(deployment.place(length: 5, at: SeaBattlePoint(row: 0, col: 6), orientation: .horizontal))

        XCTAssertFalse(deployment.isComplete)
        XCTAssertTrue(deployment.shipCells.isEmpty)
    }

    func testFleetDeploymentRejectsOverlappingShip() {
        var deployment = SeaBattleFleetDeployment()

        XCTAssertTrue(deployment.place(length: 5, at: SeaBattlePoint(row: 0, col: 0), orientation: .horizontal))
        XCTAssertFalse(deployment.place(length: 4, at: SeaBattlePoint(row: 0, col: 3), orientation: .horizontal))

        XCTAssertEqual(deployment.shipCells.count, 5)
    }

    func testFleetDeploymentMovesExistingShipWhenDropIsValid() throws {
        var deployment = SeaBattleFleetDeployment()
        XCTAssertTrue(deployment.place(length: 5, at: SeaBattlePoint(row: 0, col: 0), orientation: .horizontal))
        XCTAssertTrue(deployment.place(length: 4, at: SeaBattlePoint(row: 2, col: 0), orientation: .horizontal))
        let carrier = try XCTUnwrap(deployment.placements.first { $0.length == 5 })

        XCTAssertTrue(deployment.moveShip(id: carrier.id, to: SeaBattlePoint(row: 5, col: 4), orientation: .vertical))

        let moved = try XCTUnwrap(deployment.placements.first { $0.id == carrier.id })
        XCTAssertEqual(moved.origin, SeaBattlePoint(row: 5, col: 4))
        XCTAssertEqual(moved.orientation, .vertical)
        XCTAssertEqual(deployment.placements.map(\.length).sorted(), [4, 5])
        XCTAssertEqual(deployment.shipCells.count, 9)
    }

    func testFleetDeploymentKeepsShipInPlaceWhenDropIsInvalid() throws {
        var deployment = SeaBattleFleetDeployment()
        XCTAssertTrue(deployment.place(length: 5, at: SeaBattlePoint(row: 0, col: 0), orientation: .horizontal))
        XCTAssertTrue(deployment.place(length: 4, at: SeaBattlePoint(row: 2, col: 0), orientation: .horizontal))
        let carrier = try XCTUnwrap(deployment.placements.first { $0.length == 5 })

        XCTAssertFalse(deployment.moveShip(id: carrier.id, to: SeaBattlePoint(row: 2, col: 2), orientation: .horizontal))

        let unchanged = try XCTUnwrap(deployment.placements.first { $0.id == carrier.id })
        XCTAssertEqual(unchanged.origin, SeaBattlePoint(row: 0, col: 0))
        XCTAssertEqual(unchanged.orientation, .horizontal)
        XCTAssertEqual(deployment.shipCells.count, 9)
    }

    func testGameCanStartFromBothDeployments() throws {
        var host = SeaBattleFleetDeployment()
        XCTAssertTrue(host.place(length: 5, at: SeaBattlePoint(row: 0, col: 0), orientation: .horizontal))
        XCTAssertTrue(host.place(length: 4, at: SeaBattlePoint(row: 2, col: 0), orientation: .horizontal))
        XCTAssertTrue(host.place(length: 3, at: SeaBattlePoint(row: 4, col: 0), orientation: .horizontal))
        XCTAssertTrue(host.place(length: 3, at: SeaBattlePoint(row: 6, col: 0), orientation: .horizontal))
        XCTAssertTrue(host.place(length: 2, at: SeaBattlePoint(row: 8, col: 0), orientation: .horizontal))

        var guest = SeaBattleFleetDeployment()
        XCTAssertTrue(guest.place(length: 5, at: SeaBattlePoint(row: 0, col: 0), orientation: .vertical))
        XCTAssertTrue(guest.place(length: 4, at: SeaBattlePoint(row: 0, col: 2), orientation: .vertical))
        XCTAssertTrue(guest.place(length: 3, at: SeaBattlePoint(row: 0, col: 4), orientation: .vertical))
        XCTAssertTrue(guest.place(length: 3, at: SeaBattlePoint(row: 0, col: 6), orientation: .vertical))
        XCTAssertTrue(guest.place(length: 2, at: SeaBattlePoint(row: 0, col: 8), orientation: .vertical))

        let game = try XCTUnwrap(SeaBattleGame.gameFromDeployments(host: host, guest: guest))

        XCTAssertEqual(game.board(for: .host).shipCells.count, SeaBattleGame.fleet.reduce(0, +))
        XCTAssertEqual(game.board(for: .guest).shipCells.count, SeaBattleGame.fleet.reduce(0, +))
        XCTAssertEqual(game.currentPlayer, .host)
        XCTAssertTrue(game.board(for: .host).shots.isEmpty)
        XCTAssertTrue(game.board(for: .guest).shots.isEmpty)
    }

    func testAIDifficultyCasesAreOrdered() {
        XCTAssertEqual(SeaBattleAIDifficulty.allCases, [.easy, .normal, .hard])
        XCTAssertEqual(SeaBattleAIDifficulty.easy.title, "Easy")
        XCTAssertEqual(SeaBattleAIDifficulty.hard.title, "Hard")
    }

    func testEasyAIChoosesUntriedShot() throws {
        let tried = SeaBattlePoint(row: 0, col: 0)
        let game = SeaBattleGame(
            boards: [
                .host: SeaBattleBoard(shipCells: [SeaBattlePoint(row: 4, col: 4)], shots: [tried]),
                .guest: SeaBattleBoard(shipCells: [])
            ],
            currentPlayer: .guest
        )

        let shot = try XCTUnwrap(SeaBattleAI(difficulty: .easy, seed: 7).shot(for: .guest, in: game))

        XCTAssertNotEqual(shot, tried)
        XCTAssertFalse(game.board(for: .host).shots.contains(shot))
    }

    func testNormalAITargetsNeighborAfterHit() throws {
        let hit = SeaBattlePoint(row: 4, col: 4)
        let game = SeaBattleGame(
            boards: [
                .host: SeaBattleBoard(shipCells: [hit, SeaBattlePoint(row: 4, col: 5)], shots: [hit]),
                .guest: SeaBattleBoard(shipCells: [])
            ],
            currentPlayer: .guest
        )

        let shot = try XCTUnwrap(SeaBattleAI(difficulty: .normal, seed: 7).shot(for: .guest, in: game))
        let neighbors = Set([
            SeaBattlePoint(row: 3, col: 4),
            SeaBattlePoint(row: 5, col: 4),
            SeaBattlePoint(row: 4, col: 3),
            SeaBattlePoint(row: 4, col: 5)
        ])

        XCTAssertTrue(neighbors.contains(shot))
        XCTAssertFalse(game.board(for: .host).shots.contains(shot))
    }

    func testHardAIFollowsShipLineAfterTwoHits() throws {
        let first = SeaBattlePoint(row: 4, col: 4)
        let second = SeaBattlePoint(row: 4, col: 5)
        let game = SeaBattleGame(
            boards: [
                .host: SeaBattleBoard(shipCells: [first, second, SeaBattlePoint(row: 4, col: 6)], shots: [first, second]),
                .guest: SeaBattleBoard(shipCells: [])
            ],
            currentPlayer: .guest
        )

        let shot = try XCTUnwrap(SeaBattleAI(difficulty: .hard, seed: 7).shot(for: .guest, in: game))

        XCTAssertEqual(shot, SeaBattlePoint(row: 4, col: 6))
    }
}
