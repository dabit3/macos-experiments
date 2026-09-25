@testable import ImpossiblePostcards
import XCTest

@MainActor
final class GameModelTests: XCTestCase {
    func testTurnRejectsWalkingAndRepeatedTurnsUntilAligned() async throws {
        let game = makeGame()
        game.start(0)
        game.rotate(0)
        let turningState = game.state
        XCTAssertTrue(game.turning)
        game.walk(to: 1)
        game.rotate(0)
        XCTAssertEqual(game.state, turningState)
        XCTAssertFalse(game.walking)
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertFalse(game.turning)
        game.walk(to: 1)
        XCTAssertTrue(game.walking)
        game.setPaused(true)
    }

    func testSealAndMovesCommitOnlyAfterVisualArrival() async throws {
        let game = makeGame()
        game.start(2)
        game.walk(to: 3)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(game.movingTo, 1)
        XCTAssertEqual(game.state.tile, 0)
        XCTAssertEqual(game.state.moves, 0)
        XCTAssertEqual(game.seals, 0)
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertEqual(game.movingTo, 3)
        XCTAssertEqual(game.state.tile, 2)
        XCTAssertEqual(game.state.moves, 2)
        XCTAssertEqual(game.seals, 0)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(game.state.tile, 3)
        XCTAssertEqual(game.state.moves, 3)
        XCTAssertEqual(game.seals, 1)
        XCTAssertFalse(game.walking)
    }

    func testPauseCancelsUnfinishedStepWithoutPersistingArrival() async throws {
        let suite = "postcards.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let game = GameModel(defaults: defaults)
        game.journal.sound = false
        game.start(2)
        game.walk(to: 3)
        try await Task.sleep(for: .milliseconds(100))
        game.setPaused(true)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertNil(game.movingTo)
        XCTAssertEqual(game.state, game.chapter.initialState)
        let restored = GameModel(defaults: defaults)
        XCTAssertEqual(restored.state, game.chapter.initialState)
        XCTAssertFalse(restored.journal.sound)
    }

    func testRestartCannotReceiveAnOldRoutesArrival() async throws {
        let game = makeGame()
        game.start(2)
        game.walk(to: 3)
        try await Task.sleep(for: .milliseconds(100))
        game.start(0)
        game.walk(to: 1)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(game.walking)
        XCTAssertEqual(game.state.moves, 0)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(game.state.tile, 1)
        XCTAssertEqual(game.state.moves, 1)
        XCTAssertEqual(game.seals, 0)
        XCTAssertFalse(game.walking)
    }

    private func makeGame() -> GameModel {
        let suite = "postcards.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let game = GameModel(defaults: defaults)
        game.journal.sound = false
        return game
    }
}
