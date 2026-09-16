import XCTest

@testable import CableChaosCore

final class CableChaosTests: XCTestCase {
  func testDirectionRotationAndOpposites() {
    XCTAssertEqual(Direction.up.rotated(by: 1), .right)
    XCTAssertEqual(Direction.up.rotated(by: -1), .left)
    XCTAssertEqual(Direction.left.rotated(by: 5), .up)
    for d in Direction.allCases { XCTAssertEqual(d.opposite.opposite, d) }
  }

  func testTileOpeningsFollowRotation() {
    var corner = Tile(.corner)
    XCTAssertEqual(corner.openings, [.up, .right])
    corner.rotation = 1
    XCTAssertEqual(corner.openings, [.right, .down])
    corner.rotation = 7
    XCTAssertEqual(corner.openings, [.left, .up])
    XCTAssertEqual(Tile(.straight, rotation: 3).openings, [.left, .right])
    XCTAssertEqual(Tile(.tee).turnsToInclude([.left, .down]), 1)
    XCTAssertEqual(Tile(.tee).turnsToInclude([.left, .up]), 2)
    XCTAssertNil(Tile(.straight).turnsToInclude([.up, .right]))
    XCTAssertEqual(Tile(.cross).turnsToMatch(Set(Direction.allCases)), 0)
  }

  func testSeededRNGIsDeterministic() {
    var a = SeededRNG(seed: 99)
    var b = SeededRNG(seed: 99)
    for _ in 0..<50 { XCTAssertEqual(a.next(), b.next()) }
  }

  func testFirstLevelSolvesWithOneRotationAndPowersGPU() {
    var board = Board(level: LevelCatalog.level(1))
    XCTAssertEqual(board.phase, .ready)
    XCTAssertFalse(board.flow().isComplete)
    XCTAssertEqual(board.level.par, 2)
    board.rotate(at: GridPoint(1, 1))
    board.rotate(at: GridPoint(2, 1))
    XCTAssertEqual(board.phase, .solved)
    XCTAssertEqual(board.flow().sinksPowered, [.power])
    XCTAssertEqual(board.moves, 2)
    XCTAssertEqual(board.stars, 3)
  }

  func testRotatingLockedTilesIsRejected() {
    var board = Board(level: LevelCatalog.level(1))
    XCTAssertFalse(board.rotate(at: GridPoint(0, 1)))
    XCTAssertFalse(board.rotate(at: GridPoint(3, 1)))
    XCTAssertFalse(board.rotate(at: GridPoint(9, 9)))
    XCTAssertEqual(board.moves, 0)
  }

  func testEveryCatalogLevelIsSolvableNotPreSolvedAndDeterministic() {
    for id in 1...LevelCatalog.count {
      let level = LevelCatalog.level(id)
      let again = LevelCatalog.level(id)
      XCTAssertEqual(level, again, "Level \(id) must be deterministic")
      let board = Board(level: level)
      XCTAssertTrue(board.flow().sinksPowered.isEmpty, "Level \(id) starts with a routed net")
      XCTAssertTrue(Solver.isSolvable(board, avoidHeat: true), "Level \(id) has no safe route")
      XCTAssertGreaterThan(level.par, 0, "Level \(id) par")
      XCTAssertEqual(level.tiles.count, level.width * level.height)
      XCTAssertEqual(level.nets.count, id >= 14 && id % 3 != 1 ? 2 : 1, "Level \(id) nets")
      if id >= 10 { XCTAssertTrue(level.hasHeat, "Level \(id) should have heat") }
    }
  }

  func testSolverParRouteActuallySolvesGeneratedLevels() {
    for id in [9, 12, 20, 33, 40] {
      var board = Board(level: LevelCatalog.level(id))
      for net in board.level.nets {
        guard let steps = Solver.route(board, net: net, avoidHeat: true) else {
          return XCTFail("No route for level \(id) net \(net)")
        }
        for step in steps where board[step.cell].kind.isCable {
          guard let exit = step.exited else { continue }
          let turns = board[step.cell].turnsToInclude([step.entered.opposite, exit]) ?? 0
          for _ in 0..<turns { board.rotate(at: step.cell) }
        }
      }
      XCTAssertEqual(board.phase, .solved, "Following the solver's route should solve level \(id)")
      XCTAssertLessThanOrEqual(board.moves, board.level.par)
    }
  }

  func testShortCircuitBlocksCompletion() {
    // Two sources feed one straight cable that reaches both sinks: a short.
    let tiles: [Tile] = [
      Tile(.source(.power)), Tile(.straight, rotation: 1), Tile(.sink(.power), rotation: 2),
      Tile(.empty), Tile(.straight), Tile(.empty),
      Tile(.source(.pcie)), Tile(.straight, rotation: 1), Tile(.sink(.pcie), rotation: 2),
    ]
    let level = Level(
      id: 99, name: "Short", subtitle: "", width: 3, height: 3, tiles: tiles, timeLimit: 30, par: 1,
      seed: 1)
    var board = Board(level: level)
    XCTAssertTrue(board.flow().isComplete)
    board.tiles[1] = Tile(.tee, rotation: 1)
    board.tiles[7] = Tile(.tee, rotation: 3)
    let flow = board.flow()
    XCTAssertTrue(flow.shorts.isSuperset(of: [GridPoint(1, 0), GridPoint(1, 1), GridPoint(1, 2)]))
    XCTAssertTrue(flow.sinksPowered.isEmpty)
    XCTAssertFalse(flow.isComplete)
  }

  func testTimerExpiresIntoTimeoutFailure() {
    var board = Board(level: LevelCatalog.level(2))
    board.tick(10)
    XCTAssertEqual(board.elapsed, 0, "Clock waits for the first move")
    board.rotate(at: GridPoint(1, 0))
    board.tick(board.level.timeLimit + 1)
    XCTAssertEqual(board.phase, .failed(.timeout))
    XCTAssertEqual(board.timeRemaining, 0)
    XCTAssertFalse(board.rotate(at: GridPoint(1, 0)))
  }

  func testPoweredCableBesideHeatMeltsAndCoolsWhenUnpowered() {
    let tiles: [Tile] = [
      Tile(.source(.power)), Tile(.straight), Tile(.corner, rotation: 2),
      Tile(.sink(.power), rotation: 2),
      Tile(.empty), Tile(.hot), Tile(.corner), Tile(.empty),
      Tile(.empty), Tile(.straight), Tile(.straight), Tile(.empty),
    ]
    let level = Level(
      id: 98, name: "Heat", subtitle: "", width: 4, height: 3, tiles: tiles, timeLimit: 60, par: 1,
      seed: 1)
    var board = Board(level: level)
    board.rotate(at: GridPoint(1, 0))  // horizontal: powered, but the corner dead-ends
    XCTAssertEqual(board.phase, .routing)
    XCTAssertNotNil(board.flow().powered[GridPoint(1, 0)])
    board.tick(1.0)
    XCTAssertEqual(board[GridPoint(1, 0)].heat, 1.0 / Board.meltSeconds, accuracy: 0.001)
    XCTAssertEqual(board[GridPoint(2, 0)].heat, 0, "Not adjacent to the hot tile")
    board.rotate(at: GridPoint(1, 0))  // vertical: depowered
    XCTAssertNil(board.flow().powered[GridPoint(1, 0)])
    board.tick(5)
    XCTAssertEqual(board[GridPoint(1, 0)].heat, 0)
    XCTAssertEqual(board[GridPoint(1, 0)].kind, .straight)
  }

  func testMeltdownWithNoRemainingRouteFailsLevel() {
    let tiles: [Tile] = [
      Tile(.source(.power)), Tile(.straight), Tile(.sink(.power), rotation: 2),
      Tile(.empty), Tile(.hot), Tile(.empty),
    ]
    let level = Level(
      id: 97, name: "Melt", subtitle: "", width: 3, height: 2, tiles: tiles, timeLimit: 60, par: 1,
      seed: 1)
    var board = Board(level: level)
    board.rotate(at: GridPoint(1, 0))
    XCTAssertEqual(board.phase, .solved)
    // Force routing state to simulate a dangling powered cable next to heat.
    board.phase = .routing
    board.tiles[2] = Tile(.sink(.power), rotation: 1)  // sink faces away: powered but unsolved
    var melted: [GridPoint] = []
    for _ in 0..<40 { melted += board.tick(0.1) }
    XCTAssertEqual(melted, [GridPoint(1, 0)])
    XCTAssertEqual(board[GridPoint(1, 0)].kind, .slag)
    XCTAssertEqual(board.phase, .failed(.meltdown))
  }

  func testStarsRewardSpeedAndEfficiency() {
    var board = Board(level: LevelCatalog.level(1))
    board.rotate(at: GridPoint(1, 1))
    board.tick(board.level.timeLimit * 0.9)
    board.rotate(at: GridPoint(2, 1))
    XCTAssertEqual(board.phase, .solved)
    XCTAssertEqual(board.stars, 2, "Slow solve loses the time star")
  }

  func testProgressPersistsBestResultsAndUnlocks() throws {
    var progress = Progress()
    XCTAssertTrue(progress.isUnlocked(1))
    XCTAssertFalse(progress.isUnlocked(2))
    var board = Board(level: LevelCatalog.level(1))
    board.rotate(at: GridPoint(1, 1))
    board.rotate(at: GridPoint(2, 1))
    XCTAssertTrue(progress.record(board))
    XCTAssertTrue(progress.isUnlocked(2))
    XCTAssertEqual(progress.totalStars, 3)
    XCTAssertEqual(progress.nextLevel, 2)
    XCTAssertFalse(progress.record(board), "Identical result is not an improvement")
    let data = try progress.encoded()
    XCTAssertEqual(Progress.decode(data), progress)
    XCTAssertEqual(Progress.decode(Data("garbage".utf8)), Progress())
  }
}
