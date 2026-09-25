import XCTest

@testable import LanternParade

final class ParadeTests: XCTestCase {
  func testAllTwelveAuthoredRoutesAreSolvableAndEarnThreeStars() {
    XCTAssertEqual(Towns.all.count, 12)
    for puzzle in Towns.all {
      XCTAssertEqual(Set(puzzle.solution).count, puzzle.solution.count, puzzle.title)
      XCTAssertEqual(puzzle.lanterns.count, 3)
      var parade = Parade(puzzle: puzzle)
      for tile in puzzle.solution.dropFirst() {
        let outcome = parade.move(to: tile, in: puzzle)
        XCTAssertTrue(
          outcome == .moved || outcome == .completed, "\(puzzle.title): \(tile), \(outcome)")
      }
      XCTAssertTrue(parade.completed, puzzle.title)
      XCTAssertEqual(parade.stars(in: puzzle), 3, puzzle.title)
      XCTAssertEqual(parade.collected(in: puzzle), LanternColor.allCases)
    }
  }

  func testCrossingIsRejectedWithoutCorruptingRoute() {
    let puzzle = Towns.all[0]
    var parade = Parade(puzzle: puzzle)
    for tile in [Tile(x: 1, y: 4), Tile(x: 1, y: 3), Tile(x: 0, y: 3)] {
      XCTAssertEqual(parade.move(to: tile, in: puzzle), .moved)
    }
    let before = parade.route
    XCTAssertEqual(parade.move(to: puzzle.start, in: puzzle), .tangled)
    XCTAssertEqual(parade.route, before)
    XCTAssertEqual(parade.mistakes, 1)
  }

  func testUndoAndBackwardDrawingRemoveCollectedLight() {
    let puzzle = Towns.all[0]
    var parade = Parade(puzzle: puzzle)
    for tile in puzzle.solution[1...2] { _ = parade.move(to: tile, in: puzzle) }
    XCTAssertEqual(parade.collected(in: puzzle), [.amber])
    XCTAssertNil(parade.rejection(for: puzzle.solution[3], in: puzzle))
    XCTAssertEqual(parade.move(to: puzzle.solution[1], in: puzzle), .moved)
    XCTAssertEqual(parade.collected(in: puzzle), [])
    XCTAssertNotNil(parade.rejection(for: puzzle.solution[3], in: puzzle))
    parade.undo()
    parade.undo()
    XCTAssertEqual(parade.route, [puzzle.start])
  }

  func testColorOrderGatesSquareAndRooftopsAreEnforced() {
    let puzzle = Towns.all[0]
    let parade = Parade(puzzle: puzzle)
    let rose = puzzle.lanterns.first { $0.value == .rose }!.key
    XCTAssertNotNil(parade.rejection(for: rose, in: puzzle))
    XCTAssertNotNil(parade.rejection(for: puzzle.finish, in: puzzle))
    XCTAssertNotNil(parade.rejection(for: puzzle.solution[3], in: puzzle))
    for tile in puzzle.blocked { XCTAssertNotNil(parade.rejection(for: tile, in: puzzle)) }
  }

  func testNonAdjacentAndOutOfBoundsMovesDoNotCount() {
    let puzzle = Towns.all[0]
    var parade = Parade(puzzle: puzzle)
    XCTAssertEqual(parade.move(to: Tile(x: -1, y: 4), in: puzzle), .ignored)
    XCTAssertEqual(parade.move(to: puzzle.finish, in: puzzle), .ignored)
    XCTAssertEqual(parade.route, [puzzle.start])
    XCTAssertEqual(parade.mistakes, 0)
  }

  func testDailySeedsAreStableAndEveryTransformRemainsSolvable() {
    for day in 1...31 {
      let key = String(format: "2026-09-%02d", day)
      let puzzle = Towns.daily(key)
      XCTAssertEqual(puzzle.solution, Towns.daily(key).solution)
      var parade = Parade(puzzle: puzzle)
      for tile in puzzle.solution.dropFirst() { _ = parade.move(to: tile, in: puzzle) }
      XCTAssertTrue(parade.completed, key)
    }
    XCTAssertEqual(Towns.dayKey(Date(timeIntervalSince1970: 0)), "1970-01-01")
    XCTAssertNotEqual(Towns.daily("2026-09-12").id, Towns.daily("2026-09-13").id)
  }

  func testScoringRewardsCleanRoutesAndNeverAwardsIncompletePlay() {
    let puzzle = Towns.all[0]
    var parade = Parade(puzzle: puzzle)
    XCTAssertEqual(parade.stars(in: puzzle), 0)
    for tile in puzzle.solution.dropFirst() { _ = parade.move(to: tile, in: puzzle) }
    XCTAssertEqual(parade.stars(in: puzzle), 3)
    parade.hints = 1
    XCTAssertEqual(parade.stars(in: puzzle), 2)
    parade.hints = 2
    XCTAssertEqual(parade.stars(in: puzzle), 1)
    let route = parade.route
    parade.undo()
    XCTAssertEqual(parade.route, route)
  }

  func testBoardGeometryRoundTripsAndRejectsOutsideTouches() {
    for side in [296.0, 369.0, 440.0] {
      let geometry = BoardGeometry(side: side, count: 6)
      for y in 0..<6 {
        for x in 0..<6 {
          let tile = Tile(x: x, y: y)
          XCTAssertEqual(geometry.tile(at: geometry.point(tile)), tile)
        }
      }
      XCTAssertNil(geometry.tile(at: CGPoint(x: -40, y: -40)))
    }
  }

  @MainActor
  func testBestStarsAndInProgressRouteSurviveRelaunch() {
    let name = "LanternParadeTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let progress = Progress(defaults: defaults)
    let puzzle = Towns.all[0]
    var parade = Parade(puzzle: puzzle)
    _ = parade.move(to: puzzle.solution[1], in: puzzle)
    progress.save(parade)
    XCTAssertEqual(Progress(defaults: defaults).saved?.route, parade.route)
    for tile in puzzle.solution.dropFirst(2) { _ = parade.move(to: tile, in: puzzle) }
    progress.complete(parade, puzzle: puzzle)
    parade.hints = 4
    progress.complete(parade, puzzle: puzzle)
    let restored = Progress(defaults: defaults)
    XCTAssertEqual(restored.best[puzzle.id], 3)
    XCTAssertEqual(restored.completedCount, 1)
  }
}
