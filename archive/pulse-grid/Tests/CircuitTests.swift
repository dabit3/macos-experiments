import XCTest

@testable import PulseGrid

final class CircuitTests: XCTestCase {
  func testRotationCyclesAndNegativeTurns() {
    XCTAssertEqual(Direction.rotate(1, turns: 1), 2)
    XCTAssertEqual(Direction.rotate(1, turns: 2), 4)
    XCTAssertEqual(Direction.rotate(1, turns: 3), 8)
    XCTAssertEqual(Direction.rotate(1, turns: 4), 1)
    XCTAssertEqual(Direction.rotate(1, turns: -1), 8)
    XCTAssertEqual(Direction.rotate(5, turns: 2), 5)
    XCTAssertEqual(Direction.rotate(7, turns: 1), 14)
  }

  func testAllTenLayoutsAreConnectedAndInitiallyUnsolved() {
    XCTAssertEqual(Circuits.all.count, 10)
    for level in Circuits.all {
      let turns = Array(repeating: 0, count: level.masks.count)
      XCTAssertTrue(level.isSolved(turns: turns), level.name)
      XCTAssertEqual(level.connected(turns: turns).count, level.activeCount, level.name)
      XCTAssertFalse(level.isSolved(turns: level.initialTurns), level.name)
      XCTAssertTrue(CircuitSession(level: level).isValid(for: level))
    }
  }

  func testBothEndsMustMeet() {
    let level = CircuitLevel(id: 0, name: "Test", subtitle: "", size: 3, paths: [[3, 4, 5]])
    XCTAssertTrue(level.isSolved(turns: [0, 0, 0, 0, 0, 0, 0, 0, 0]))
    let turns = [0, 0, 0, 0, 1, 0, 0, 0, 0]
    XCTAssertEqual(Set(level.connected(turns: turns).keys), [3])
    XCTAssertFalse(level.isSolved(turns: turns))
  }

  func testEdgesNeverWrapRows() {
    let level = CircuitLevel(id: 0, name: "Edge", subtitle: "", size: 3, paths: [[2, 1, 0, 3]])
    var turns = Array(repeating: 0, count: 9)
    turns[2] = 2
    XCTAssertEqual(Set(level.connected(turns: turns).keys), [2])
  }

  func testLoopTerminatesAndReachesBranchReceivers() {
    let level = Circuits.all[8]
    let network = level.connected(turns: Array(repeating: 0, count: 25))
    XCTAssertEqual(network.count, level.activeCount)
    XCTAssertEqual(network[level.source], 0)
    XCTAssertEqual(level.receivers.count, 3)
    for receiver in level.receivers { XCTAssertNotNil(network[receiver]) }
    XCTAssertTrue(network.values.allSatisfy { $0 < 25 })
  }

  func testOnePoweredReceiverDoesNotCompleteBranches() {
    let level = CircuitLevel(
      id: 0, name: "Branch", subtitle: "", size: 3,
      paths: [[3, 4, 1, 2], [3, 4, 7, 8]])
    var turns = Array(repeating: 0, count: 9)
    turns[7] = 1
    let network = level.connected(turns: turns)
    XCTAssertNotNil(network[2])
    XCTAssertNil(network[8])
    XCTAssertFalse(level.isSolved(turns: turns))
  }

  func testBlockedCellsNeverPower() {
    let level = Circuits.all[0]
    let connected = level.connected(turns: Array(repeating: 0, count: 16))
    for index in level.masks.indices where level.masks[index] == 0 {
      XCTAssertNil(connected[index])
      XCTAssertFalse(level.isRotatable(index))
    }
  }

  func testFixedTerminalsAndSolvedBoardCannotRotate() {
    let level = Circuits.all[0]
    var session = CircuitSession(level: level)
    let original = session
    session.rotate(level.source, in: level)
    session.rotate(level.receivers[0], in: level)
    session.rotate(0, in: level)
    session.rotate(-1, in: level)
    XCTAssertEqual(session, original)
    session.turns = Array(repeating: 0, count: 16)
    session.rotate(9, in: level)
    XCTAssertEqual(session.moves, 0)
  }

  func testHintsEventuallySolveEveryLevelAndCountSeparately() {
    for level in Circuits.all {
      var session = CircuitSession(level: level)
      for _ in 0..<level.masks.count {
        if level.isSolved(turns: session.turns) { break }
        let index = session.hint(in: level)
        XCTAssertNotNil(index)
        if let index {
          XCTAssertEqual(level.mask(at: index, turns: session.turns), level.masks[index])
        }
      }
      XCTAssertTrue(level.isSolved(turns: session.turns), level.name)
      XCTAssertEqual(session.moves, 0)
      XCTAssertGreaterThan(session.hints, 0)
      XCTAssertNil(session.hint(in: level))
    }
  }

  func testRotationsAndResetRestoreExactLayout() {
    let level = Circuits.all[0]
    var session = CircuitSession(level: level)
    session.rotate(9, in: level)
    XCTAssertEqual(session.moves, 1)
    XCTAssertEqual(session.turns[9], level.initialTurns[9] + 1)
    session.hint(in: level)
    XCTAssertGreaterThan(session.hints, 0)
    session = CircuitSession(level: level)
    XCTAssertEqual(session.turns, level.initialTurns)
    XCTAssertEqual(session.moves, 0)
    XCTAssertEqual(session.hints, 0)
  }

  @MainActor
  func testPersistenceRelaunchAndResetPreserveCompletion() {
    let suite = "pulse-grid.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let level = Circuits.all[2]
    let store = ProgressStore(defaults: defaults)
    var session = CircuitSession(level: level)
    session.rotate(9, in: level)
    store.save(session, for: level)
    let reloaded = ProgressStore(defaults: defaults)
    XCTAssertEqual(reloaded.session(for: level), session)
    XCTAssertEqual(reloaded.suggestedLevel, level.id)
    session.turns = Array(repeating: 0, count: 16)
    reloaded.save(session, for: level)
    reloaded.save(CircuitSession(level: level), for: level)
    let again = ProgressStore(defaults: defaults)
    XCTAssertEqual(again.completedCount, 1)
    XCTAssertEqual(again.session(for: level).moves, 0)
    XCTAssertFalse(level.isSolved(turns: again.session(for: level).turns))
  }

  @MainActor
  func testBestRecordFavorsFewerHintsAndThenFewerMoves() {
    let suite = "pulse-grid.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = ProgressStore(defaults: defaults)
    let level = Circuits.all[0]
    var session = CircuitSession(level: level)
    session.turns = Array(repeating: 0, count: 16)
    session.moves = 20
    store.save(session, for: level)
    session.moves = 1
    session.hints = 1
    store.save(session, for: level)
    XCTAssertEqual(store.data.completions[0]?.moves, 20)
    session.hints = 0
    session.moves = 12
    store.save(session, for: level)
    XCTAssertEqual(store.data.completions[0]?.moves, 12)
  }

  @MainActor
  func testCorruptStorageRecoveryAndErase() {
    let suite = "pulse-grid.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(Data("not valid".utf8), forKey: "pulse-grid.progress.v1")
    let store = ProgressStore(defaults: defaults)
    XCTAssertEqual(store.completedCount, 0)
    store.setHaptics(false)
    XCTAssertFalse(ProgressStore(defaults: defaults).data.haptics)
    store.erase()
    XCTAssertTrue(ProgressStore(defaults: defaults).data.haptics)
    XCTAssertTrue(store.data.sessions.isEmpty)
  }

  func testInvalidSessionDataIsRejected() {
    let level = Circuits.all[0]
    var session = CircuitSession(level: level)
    session.turns = []
    XCTAssertFalse(session.isValid(for: level))
    session = CircuitSession(level: level)
    session.turns[level.source] = 1
    XCTAssertFalse(session.isValid(for: level))
    session = CircuitSession(level: level)
    session.moves = -1
    XCTAssertFalse(session.isValid(for: level))
  }
}
