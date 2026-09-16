import XCTest

@testable import WaferSliceCore

final class GeometryTests: XCTestCase {
  func testSweptSegmentSlicesCircleItPassesThrough() {
    XCTAssertTrue(
      Geometry.segment(V2(x: -100, y: 0), V2(x: 100, y: 0), hitsCircleAt: .zero, radius: 20))
    XCTAssertTrue(
      Geometry.segment(V2(x: -100, y: 15), V2(x: 100, y: 15), hitsCircleAt: .zero, radius: 20))
    XCTAssertFalse(
      Geometry.segment(V2(x: -100, y: 25), V2(x: 100, y: 25), hitsCircleAt: .zero, radius: 20))
  }

  func testRestingFingerNeverSlices() {
    XCTAssertFalse(Geometry.segment(.zero, .zero, hitsCircleAt: .zero, radius: 50))
  }

  func testSegmentEndingShortOfCircleMisses() {
    XCTAssertFalse(
      Geometry.segment(V2(x: -100, y: 0), V2(x: -30, y: 0), hitsCircleAt: .zero, radius: 20))
  }

  func testSplitPolygonProducesTwoHalvesWithConservedArea() {
    let square = Geometry.regularPolygon(sides: 4, radius: 50, rotation: .pi / 4)
    let (left, right) = Geometry.split(polygon: square, along: V2(x: 0, y: -100), V2(x: 0, y: 100))
    XCTAssertGreaterThanOrEqual(left.count, 3)
    XCTAssertGreaterThanOrEqual(right.count, 3)
    let total = Geometry.area(of: square)
    XCTAssertEqual(Geometry.area(of: left) + Geometry.area(of: right), total, accuracy: 0.001)
    XCTAssertEqual(Geometry.area(of: left), total / 2, accuracy: 0.001)
    XCTAssertLessThan(Geometry.centroid(of: left).x, 0)
    XCTAssertGreaterThan(Geometry.centroid(of: right).x, 0)
  }

  func testSplitAlongMissingLineLeavesOneSideEmpty() {
    let square = Geometry.regularPolygon(sides: 4, radius: 10)
    let (left, right) = Geometry.split(polygon: square, along: V2(x: 500, y: -1), V2(x: 500, y: 1))
    XCTAssertTrue(left.isEmpty || right.isEmpty)
    XCTAssertEqual(
      Geometry.area(of: left) + Geometry.area(of: right), Geometry.area(of: square),
      accuracy: 0.001)
  }

  func testSeededRandomIsDeterministicAndInRange() {
    var a = SeededRandom(seed: 7)
    var b = SeededRandom(seed: 7)
    for _ in 0..<200 {
      let value = a.next()
      XCTAssertEqual(value, b.next())
      XCTAssertTrue((0..<1).contains(value))
    }
  }
}

final class GameSessionTests: XCTestCase {
  func testArcadeStartsWithThreeLivesAndSixtySeconds() {
    let session = GameSession(mode: .arcade)
    XCTAssertEqual(session.lives, 3)
    XCTAssertEqual(session.timeRemaining, 60)
    XCTAssertFalse(session.isOver)
  }

  func testArcadeEndsWhenTimeRunsOut() {
    var session = GameSession(mode: .arcade)
    for _ in 0..<1200 { session.advance(0.05) }
    XCTAssertTrue(session.isOver)
    XCTAssertEqual(session.endReason, .timeUp)
    XCTAssertEqual(session.timeRemaining, 0)
  }

  func testZenHasNoClockAndNoLives() {
    var session = GameSession(mode: .zen)
    XCTAssertNil(session.timeRemaining)
    for _ in 0..<5000 { session.advance(0.05) }
    XCTAssertFalse(session.isOver)
    session.registerHit(.defective)
    XCTAssertFalse(session.isOver)
    XCTAssertEqual(session.lives, 0)
    session.finish()
    XCTAssertEqual(session.endReason, .finished)
  }

  func testCleanSlicesAwardBasePoints() {
    var session = GameSession(mode: .arcade)
    session.beginSwipe()
    XCTAssertEqual(session.registerHit(.wafer)?.points, 10)
    XCTAssertEqual(session.registerHit(.chiplet)?.points, 15)
    XCTAssertEqual(session.registerHit(.heatsink)?.points, 20)
    XCTAssertEqual(session.score, 45)
    XCTAssertEqual(session.slicedCount, 3)
  }

  func testDefectiveDieCostsALifeAndThreeEndTheRun() {
    var session = GameSession(mode: .arcade)
    for expected in [2, 1, 0] {
      session.beginSwipe()
      let result = session.registerHit(.defective)
      XCTAssertEqual(result?.lostLife, true)
      XCTAssertEqual(result?.points, 0)
      XCTAssertEqual(session.lives, expected)
      session.endSwipe()
    }
    XCTAssertTrue(session.isOver)
    XCTAssertEqual(session.endReason, .outOfLives)
    XCTAssertNil(session.registerHit(.wafer))
  }

  func testBinningBonusRequiresThreeCleanSlicesInOneSwipe() {
    var session = GameSession(mode: .arcade)
    session.beginSwipe()
    session.registerHit(.wafer)
    session.registerHit(.wafer)
    var summary = session.endSwipe()
    XCTAssertFalse(summary.isBinningBonus)
    XCTAssertEqual(session.score, 20)

    session.beginSwipe()
    session.registerHit(.wafer)
    session.registerHit(.chiplet)
    session.registerHit(.heatsink)
    summary = session.endSwipe()
    XCTAssertTrue(summary.isBinningBonus)
    XCTAssertEqual(summary.slicedCount, 3)
    XCTAssertEqual(summary.binningBonus, 60)
    XCTAssertEqual(session.score, 20 + 45 + 60)
    XCTAssertEqual(session.binningBonuses, 1)
    XCTAssertEqual(session.bestSwipe, 3)
  }

  func testDefectiveDiesDoNotCountTowardBinningBonus() {
    var session = GameSession(mode: .arcade)
    session.beginSwipe()
    session.registerHit(.wafer)
    session.registerHit(.wafer)
    session.registerHit(.defective)
    let summary = session.endSwipe()
    XCTAssertFalse(summary.isBinningBonus)
    XCTAssertEqual(session.lives, 2)
  }

  func testNoBinningBonusWhenTheSwipeEndsTheRun() {
    var session = GameSession(mode: .arcade)
    session.beginSwipe()
    session.registerHit(.defective)
    session.endSwipe()
    session.beginSwipe()
    session.registerHit(.defective)
    session.endSwipe()
    session.beginSwipe()
    session.registerHit(.wafer)
    session.registerHit(.wafer)
    session.registerHit(.wafer)
    session.registerHit(.defective)
    XCTAssertTrue(session.isOver)
    XCTAssertEqual(session.score, 30)
  }

  func testFlagshipStartsSlowMoAndDoublesYield() {
    var session = GameSession(mode: .arcade)
    session.beginSwipe()
    let flagship = session.registerHit(.flagship)
    XCTAssertEqual(flagship?.startedSlowMo, true)
    XCTAssertEqual(flagship?.points, 100)
    XCTAssertTrue(session.isSlowMo)
    XCTAssertEqual(session.timeScale, GameRules.flagshipTimeScale)
    XCTAssertEqual(session.multiplier, 2)
    XCTAssertEqual(session.registerHit(.wafer)?.points, 20)
    XCTAssertEqual(session.registerHit(.heatsink)?.points, 40)
    let summary = session.endSwipe()
    XCTAssertEqual(summary.binningBonus, 3 * 20 * 2)
    XCTAssertEqual(session.score, 100 + 20 + 40 + 120)

    session.advance(GameRules.flagshipSlowMoDuration + 0.05)
    XCTAssertFalse(session.isSlowMo)
    XCTAssertEqual(session.timeScale, 1)
    XCTAssertEqual(session.multiplier, 1)
  }

  func testFlagshipRefundsOneLostLifeInArcade() {
    var session = GameSession(mode: .arcade)
    session.registerHit(.defective)
    session.endSwipe()
    XCTAssertEqual(session.lives, 2)
    let result = session.registerHit(.flagship)
    XCTAssertEqual(result?.refundedLife, true)
    XCTAssertEqual(session.lives, 3)
    session.endSwipe()
    XCTAssertEqual(session.registerHit(.flagship)?.refundedLife, false)
    XCTAssertEqual(session.lives, 3)
  }

  func testSlowMoWindowStillConsumesRoundTime() {
    var session = GameSession(mode: .arcade)
    session.registerHit(.flagship)
    session.endSwipe()
    session.advance(1)
    XCTAssertEqual(session.timeRemaining ?? 0, 59, accuracy: 0.0001)
    XCTAssertEqual(session.slowMoRemaining, GameRules.flagshipSlowMoDuration - 1, accuracy: 0.0001)
  }

  func testPauseFreezesClockAndIgnoresHits() {
    var session = GameSession(mode: .arcade)
    session.advance(1)
    session.pause()
    session.advance(5)
    XCTAssertEqual(session.elapsed, 1)
    XCTAssertNil(session.registerHit(.wafer))
    session.resume()
    session.advance(1)
    XCTAssertEqual(session.elapsed, 2)
    XCTAssertNotNil(session.registerHit(.wafer))
  }

  func testMissesFeedYieldStatsButNeverCostLives() {
    var session = GameSession(mode: .arcade)
    session.registerHit(.wafer)
    session.endSwipe()
    session.registerMiss(.wafer)
    session.registerMiss(.defective)
    XCTAssertEqual(session.lives, 3)
    XCTAssertEqual(session.missedCount, 1)
    XCTAssertEqual(session.summary.yieldPercent, 50)
  }

  func testRunSummaryBinsScaleWithScore() {
    var summary = GameSession(mode: .arcade).summary
    XCTAssertEqual(summary.bin, "Engineering Sample")
    summary.score = 600
    XCTAssertEqual(summary.bin, "Founders Edition")
    summary.score = 5000
    XCTAssertEqual(summary.bin, "Tensor Core Legend")
  }
}

final class LaunchDirectorTests: XCTestCase {
  private func launches(mode: GameMode, seed: UInt64, seconds: Double) -> [LaunchSpec] {
    var director = LaunchDirector(mode: mode, seed: seed)
    var specs: [LaunchSpec] = []
    var time = 0.0
    while time < seconds {
      if let wave = director.wave(at: time, playfieldHeight: 800) { specs += wave }
      time += 1.0 / 60
    }
    return specs
  }

  func testOpeningWavesAreSafeAndSpecsStayInBounds() {
    for seed in 1...20 {
      let specs = launches(mode: .arcade, seed: UInt64(seed), seconds: 60)
      XCTAssertGreaterThan(specs.count, 40)
      for spec in specs {
        XCTAssertTrue((0.14...0.86).contains(spec.xFraction))
        XCTAssertGreaterThan(spec.velocityY, 0)
        XCTAssertGreaterThanOrEqual(spec.delay, 0)
      }
      XCTAssertFalse(specs.prefix(3).contains { $0.kind == .defective })
    }
  }

  func testArcadeLaunchesDefectiveAndFlagshipDies() {
    let specs = launches(mode: .arcade, seed: 3, seconds: 60)
    XCTAssertTrue(specs.contains { $0.kind == .defective })
    XCTAssertTrue(specs.contains { $0.kind == .flagship })
  }

  func testZenNeverLaunchesDefectiveDies() {
    for seed in 1...20 {
      let specs = launches(mode: .zen, seed: UInt64(seed), seconds: 120)
      XCTAssertFalse(specs.contains { $0.kind == .defective })
      XCTAssertTrue(specs.contains { $0.kind == .flagship })
    }
  }

  func testDirectorIsDeterministicForASeed() {
    XCTAssertEqual(
      launches(mode: .arcade, seed: 99, seconds: 30), launches(mode: .arcade, seed: 99, seconds: 30)
    )
  }

  func testLaunchVelocityReachesWithinPlayfield() {
    let specs = launches(mode: .arcade, seed: 5, seconds: 30)
    for spec in specs {
      let apex = spec.velocityY * spec.velocityY / (2 * GameRules.gravity)
      XCTAssertGreaterThan(apex, 800 * 0.6)
      XCTAssertLessThan(apex, 800 * 0.86)
    }
  }
}

final class HighScoreBoardTests: XCTestCase {
  private func run(_ mode: GameMode, score: Int) -> RunSummary {
    RunSummary(
      mode: mode, score: score, sliced: score / 10, missed: 0, defectiveHits: 0, flagshipHits: 1,
      binningBonuses: 0, bestSwipe: 3, duration: 60, endReason: .timeUp)
  }

  func testRecordsRankedTopTenPerMode() {
    var board = HighScoreBoard()
    for score in stride(from: 100, through: 1200, by: 100) {
      _ = board.record(run(.arcade, score: score))
    }
    XCTAssertEqual(board.top(.arcade).count, HighScoreBoard.capacity)
    XCTAssertEqual(board.best(.arcade), 1200)
    XCTAssertEqual(board.top(.arcade).last?.score, 300)
    XCTAssertEqual(board.record(run(.arcade, score: 650)), 7)
    XCTAssertNil(board.record(run(.arcade, score: 50)))
    XCTAssertEqual(board.record(run(.zen, score: 5)), 1)
    XCTAssertEqual(board.best(.zen), 5)
    XCTAssertEqual(board.lifetimeRuns, 15)
    XCTAssertEqual(board.lifetimeFlagships, 15)
  }

  func testZeroScoreRunsCountButDoNotRank() {
    var board = HighScoreBoard()
    XCTAssertNil(board.record(run(.arcade, score: 0)))
    XCTAssertEqual(board.lifetimeRuns, 1)
    XCTAssertTrue(board.top(.arcade).isEmpty)
  }

  func testRoundTripsThroughJSON() throws {
    var board = HighScoreBoard()
    board.record(run(.arcade, score: 420))
    board.record(run(.zen, score: 99))
    let data = try board.encoded()
    let decoded = HighScoreBoard.decode(data)
    XCTAssertEqual(decoded, board)
    XCTAssertEqual(HighScoreBoard.decode(Data("garbage".utf8)), HighScoreBoard())
  }
}
