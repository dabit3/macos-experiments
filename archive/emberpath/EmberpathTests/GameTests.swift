import XCTest

@testable import Emberpath

final class GameTests: XCTestCase {
  func testWallsDoNotConsumeLightOrCreateUndo() {
    var game = Journey(room: Room.all[0])
    let initial = game.turn
    game.move(.up)
    XCTAssertEqual(game.turn, initial)
    XCTAssertTrue(game.history.isEmpty)
  }

  func testEmberCollectionAndUndoAreAtomic() {
    var game = Journey(room: Room.all[0])
    game.move(.right)
    let before = game.turn
    game.move(.right)
    XCTAssertEqual(game.turn.light, 12)
    XCTAssertEqual(game.turn.collected.count, 1)
    game.undo()
    XCTAssertEqual(game.turn, before)
    game.move(.right)
    game.move(.left)
    game.move(.right)
    XCTAssertEqual(game.turn.light, 10)
  }

  func testFirstRoomKeyDoorEscapeAndUndo() {
    var game = Journey(room: Room.all[0])
    let solution: [Direction] = [
      .right, .right, .down, .down, .left, .left, .down, .down, .right, .right, .right, .right,
    ]
    for direction in solution { game.move(direction) }
    XCTAssertEqual(game.turn.outcome, .escaped)
    XCTAssertEqual(game.turn.light, 2)
    XCTAssertEqual(game.turn.keys, 0)
    XCTAssertEqual(game.turn.opened.count, 1)
    game.undo()
    XCTAssertEqual(game.turn.outcome, .exploring)
    XCTAssertEqual(game.turn.light, 3)
  }

  func testLockedDoorDoesNotConsumeTurn() {
    var game = Journey(room: Room.all[0])
    game.turn.position = Cell(x: 2, y: 5)
    let before = game.turn
    game.move(.right)
    XCTAssertEqual(game.turn, before)
  }

  func testLossStopsMovementAndUndoRevives() {
    var game = Journey(room: Room.all[0])
    for _ in 0..<4 {
      game.move(.right)
      game.move(.left)
    }
    XCTAssertEqual(game.turn.outcome, .extinguished)
    XCTAssertEqual(game.turn.light, 0)
    let lost = game.turn
    game.move(.right)
    XCTAssertEqual(game.turn, lost)
    game.undo()
    XCTAssertEqual(game.turn.light, 1)
    XCTAssertEqual(game.turn.outcome, .exploring)
  }

  func testLastLightCanCollectEmberButCannotEscape() {
    var game = Journey(room: Room.all[0])
    game.turn.position = Cell(x: 2, y: 1)
    game.turn.light = 1
    game.move(.right)
    XCTAssertEqual(game.turn.light, 6)
    XCTAssertEqual(game.turn.outcome, .exploring)
    game.turn.position = Cell(x: 4, y: 5)
    game.turn.light = 1
    game.move(.right)
    XCTAssertEqual(game.turn.outcome, .extinguished)
  }

  func testFuelCapAndFogMemory() {
    var game = Journey(room: Room.all[0])
    game.turn.position = Cell(x: 2, y: 1)
    game.turn.light = 18
    let seen = game.turn.revealed
    game.move(.right)
    XCTAssertEqual(game.turn.light, 18)
    XCTAssertTrue(seen.isSubset(of: game.turn.revealed))
  }

  func testAllEightDesignedRoomsHaveValidSolutions() {
    for room in Room.all {
      XCTAssertTrue(room.rows.allSatisfy { $0.count == room.width }, room.title)
      XCTAssertEqual(room.cells.filter { room.tile(at: $0) == "S" }.count, 1)
      XCTAssertEqual(room.cells.filter { room.tile(at: $0) == "X" }.count, 1)
      let solution = solve(room)
      XCTAssertNotNil(solution, "\(room.title) must be solvable")
      if let solution {
        var game = Journey(room: room)
        for move in solution { game.move(move) }
        XCTAssertEqual(game.turn.outcome, .escaped)
        print(
          "SOLUTION \(room.chapter) \(room.title): \(solution.map(\.rawValue).joined(separator: ",")); light=\(game.turn.light)"
        )
      }
    }
  }

  @MainActor
  func testPersistenceUnlocksRestartAndReset() throws {
    let suite = "emberpath.tests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = GameStore(defaults: defaults)
    store.start(Room.all[0])
    for move in try XCTUnwrap(solve(Room.all[0])) { store.move(move) }
    store.setHaptics(false)
    let restored = GameStore(defaults: defaults)
    XCTAssertEqual(restored.archive.unlocked, 1)
    XCTAssertEqual(restored.archive.bestMoves[0], 12)
    XCTAssertEqual(restored.archive.journey?.turn.outcome, .escaped)
    XCTAssertFalse(restored.archive.haptics)
    restored.start(Room.all[1])
    restored.move(.right)
    let resumed = GameStore(defaults: defaults)
    XCTAssertEqual(resumed.archive.journey?.turn.position, Cell(x: 2, y: 1))
    resumed.undo()
    XCTAssertEqual(resumed.archive.journey?.turn.position, Room.all[1].start)
    resumed.restart()
    XCTAssertEqual(resumed.archive.journey?.turn.moves, 0)
    XCTAssertEqual(resumed.archive.unlocked, 1)
    resumed.reset()
    XCTAssertEqual(GameStore(defaults: defaults).archive.unlocked, 0)
    XCTAssertNil(resumed.archive.journey)
  }

  private func solve(_ room: Room) -> [Direction]? {
    struct State: Hashable {
      let position: Cell
      let keys: Int
      let collected: Set<Cell>
      let opened: Set<Cell>
    }
    var queue: [(Journey, [Direction])] = [(Journey(room: room), [])]
    var bestLight: [State: Int] = [:]
    var index = 0
    while index < queue.count, index < 100_000 {
      let (game, path) = queue[index]
      index += 1
      for direction in Direction.allCases {
        var next = game
        next.history = []
        next.move(direction)
        if next.turn.outcome == .escaped { return path + [direction] }
        if next.turn.outcome != .exploring || next.turn.position == game.turn.position { continue }
        let state = State(
          position: next.turn.position, keys: next.turn.keys,
          collected: next.turn.collected, opened: next.turn.opened)
        if (bestLight[state] ?? -1) >= next.turn.light { continue }
        bestLight[state] = next.turn.light
        queue.append((next, path + [direction]))
      }
    }
    return nil
  }
}
