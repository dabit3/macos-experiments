import XCTest

@testable import TinyTectonics

final class PuzzleTests: XCTestCase {
  func testSlopeBoundaries() {
    XCTAssertNil(SlopeRules.fault(from: 3, to: 3))
    XCTAssertNil(SlopeRules.fault(from: 3, to: 2))
    XCTAssertEqual(SlopeRules.fault(from: 2, to: 3), .uphill)
    XCTAssertEqual(SlopeRules.fault(from: 3, to: 1), .cliff)
  }

  func testFailureStopsBeforeUnreachableCollectibles() {
    let result = SlopeRules.evaluate([4, 3, 1, 0], fossils: [1, 2, 3])
    XCTAssertEqual(result, RouteOutcome(reached: 1, fault: .cliff, fossils: 1))
    XCTAssertEqual(
      SlopeRules.evaluate([3, 2, 2, 1, 0], fossils: [2, 3]),
      RouteOutcome(reached: 4, fault: nil, fossils: 2))
  }

  func testEveryDesignedPuzzleHasAnAchievableNontrivialSolution() {
    XCTAssertEqual(Landscape.all.count, 10)
    for level in Landscape.all {
      XCTAssertEqual(level.route.count, level.initial.count)
      XCTAssertNotNil(SlopeRules.evaluate(level.initial, fossils: level.fossils).fault, level.name)
      XCTAssertTrue((1...12).contains(level.par), "\(level.name): \(level.par)")
      XCTAssertTrue(level.fixed.contains(0) && level.fixed.contains(level.initial.count - 1))
      for pair in zip(level.route, level.route.dropFirst()) {
        XCTAssertEqual(abs(pair.0.x - pair.1.x) + abs(pair.0.y - pair.1.y), 1)
      }
      XCTAssertEqual(Set(level.route.map { "\($0.x),\($0.y)" }).count, level.route.count)
    }
  }

  func testOptimalMoveSolverRespectsAnchors() {
    XCTAssertEqual(SlopeRules.minimumMoves(initial: [3, 1, 2, 1, 0], fixed: [0, 4]), 1)
    XCTAssertEqual(SlopeRules.minimumMoves(initial: [4, 2, 3, 2, 1, 0], fixed: [0, 5]), 1)
    XCTAssertGreaterThan(SlopeRules.minimumMoves(initial: [0, 5], fixed: [0, 1]), 1_000)
  }

  @MainActor
  func testMoveBudgetUndoResetAndAnchors() {
    let store = GameStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    store.selected = 0
    store.adjust(-1)
    XCTAssertEqual(store.moves, 0)
    store.selected = 1
    store.adjust(1)
    XCTAssertEqual(store.heights, [3, 2, 2, 1, 0])
    store.undo()
    XCTAssertEqual(store.moves, 0)
    XCTAssertEqual(store.heights, store.level.initial)
    for _ in 0..<store.level.budget { store.adjust(1) }
    let heights = store.heights
    store.adjust(-1)
    XCTAssertEqual(store.heights, heights)
    store.reset()
    XCTAssertEqual(store.moves, 0)
    XCTAssertTrue(store.history.isEmpty)
  }

  @MainActor
  func testAllTenLandscapeSolutionsWinWithinTheirMoveLimits() {
    let solutions = [
      [3, 2, 2, 1, 0],
      [4, 3, 3, 2, 1, 0],
      [4, 3, 2, 2, 1, 0],
      [4, 3, 3, 2, 1, 1, 0],
      [3, 2, 2, 2, 2, 1, 0],
      [5, 4, 3, 2, 2, 1, 0],
      [5, 4, 4, 3, 3, 2, 1, 0],
      [5, 4, 3, 3, 2, 2, 1, 0],
      [5, 4, 3, 2, 1, 1, 1, 0, 0],
      [5, 4, 3, 3, 2, 1, 1, 0, 0],
    ]
    let store = GameStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    for (index, solution) in solutions.enumerated() {
      store.load(index)
      for plate in solution.indices {
        store.selected = plate
        let delta = solution[plate] - store.heights[plate]
        for _ in 0..<abs(delta) { store.adjust(delta > 0 ? 1 : -1) }
      }
      XCTAssertEqual(store.heights, solution, store.level.name)
      XCTAssertGreaterThanOrEqual(store.remaining, 0)
      store.simulate()
      store.tick(20)
      XCTAssertEqual(store.phase, .won, store.level.name)
      XCTAssertEqual(store.collected, store.level.fossils.count)
    }
    XCTAssertEqual(store.completed, 10)
    XCTAssertEqual(store.unlocked, 9)
  }

  @MainActor
  func testReturningFromValidSimulationPreservesEditableSelection() {
    let store = GameStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    store.selected = 1
    store.adjust(1)
    store.simulate()
    store.tick(2)
    store.togglePause()
    store.editAgain()
    XCTAssertEqual(store.selected, 1)
    XCTAssertTrue(store.canAdjust(-1))
    XCTAssertEqual(store.moves, 1)
    XCTAssertEqual(store.travel, 0)
  }

  @MainActor
  func testPauseFailureReplayAndPersistentBest() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let store = GameStore(defaults: defaults)
    store.simulate()
    store.tick(20)
    XCTAssertEqual(store.phase, .failed)
    XCTAssertEqual(store.completed, 0)
    store.editAgain()
    store.selected = 1
    store.adjust(1)
    store.simulate()
    store.togglePause()
    store.tick(10)
    XCTAssertEqual(store.travel, 0)
    store.togglePause()
    store.tick(20)
    XCTAssertEqual(store.phase, .won)
    XCTAssertEqual(store.best["0"], 3)
    XCTAssertEqual(GameStore(defaults: defaults).unlocked, 1)
    store.reset()
    XCTAssertEqual(store.best["0"], 3)
  }
}
