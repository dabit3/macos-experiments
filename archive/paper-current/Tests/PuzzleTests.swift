import XCTest

@testable import PaperCurrent

final class PuzzleTests: XCTestCase {
  func testAllTenRoutesAreContiguousAndSolvable() {
    XCTAssertEqual(Level.all.count, 10)
    for level in Level.all {
      XCTAssertEqual(Set(level.route).count, level.route.count)
      XCTAssertTrue(
        level.route.allSatisfy {
          (0..<level.size).contains($0.row) && (0..<level.size).contains($0.col)
        })
      var puzzle = PuzzleState(level: level)
      for index in puzzle.canals.indices {
        puzzle.canals[index].turns = 0
        puzzle.canals[index].open = true
      }
      let result = puzzle.preview
      XCTAssertTrue(result.success, "Level \(level.id): \(String(describing: result.problem))")
      XCTAssertEqual(result.cells, level.route)
      XCTAssertEqual(result.stamps.count, 3)
      XCTAssertLessThan(result.cells.count, level.tideLimit)
    }
  }

  func testInitialBoardsRequirePlanningAndHintsCanSolveAll() {
    for level in Level.all {
      var puzzle = PuzzleState(level: level)
      XCTAssertFalse(puzzle.preview.success)
      for _ in 0..<level.route.count { puzzle.hint() }
      XCTAssertTrue(puzzle.preview.success)
      XCTAssertLessThan(puzzle.rating, 3)
    }
  }

  func testClosedLockAndReversedCurrentHaveDistinctFailures() {
    let level = Level.all[2]
    var canals = level.initial
    for index in canals.indices {
      canals[index].turns = 0
      canals[index].open = true
    }
    canals[2].open = false
    XCTAssertEqual(Router.trace(level: level, canals: canals).problem, .closedLock)
    canals[2].open = true
    let current = level.currents.first!
    // Reverse entry and exit without disconnecting a straight current.
    let original = canals[current]
    canals[current] = Canal(
      cell: original.cell, entry: original.exit, exit: original.entry,
      isLock: false, isCurrent: true, hasStamp: original.hasStamp, turns: 0, open: true)
    XCTAssertEqual(Router.trace(level: level, canals: canals).problem, .wrongCurrent)
  }

  func testUndoRestoresRotationAndLockAndCountsMoves() {
    var puzzle = PuzzleState(level: Level.all[1])
    let initial = puzzle.canals
    puzzle.rotate(puzzle.level.route[1])
    puzzle.toggleLock(puzzle.level.route[2])
    XCTAssertEqual(puzzle.moves, 2)
    puzzle.undo()
    puzzle.undo()
    XCTAssertEqual(puzzle.canals, initial)
    XCTAssertEqual(puzzle.moves, 0)
    XCTAssertFalse(puzzle.canUndo)
    puzzle.rotate(puzzle.level.start)
    XCTAssertEqual(puzzle.moves, 0)
  }

  func testPersistenceKeepsBestAndUnlocksSequentially() {
    let suite = "PaperCurrentTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = ProgressStore(defaults: defaults)
    XCTAssertEqual(store.unlocked, 0)
    store.save(level: 0, moves: 8)
    store.save(level: 0, moves: 12)
    XCTAssertEqual(ProgressStore(defaults: defaults).completed["0"], 8)
    XCTAssertEqual(store.unlocked, 1)
    store.save(level: 0, moves: 6)
    XCTAssertEqual(store.completed["0"], 6)
    store.save(level: 4, moves: 3)
    XCTAssertEqual(store.unlocked, 1)
  }
}
