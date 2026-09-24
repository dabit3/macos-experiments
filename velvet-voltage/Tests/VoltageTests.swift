import XCTest

@testable import VelvetVoltage

final class VoltageTests: XCTestCase {
  @MainActor
  func testRelaunchInstructionRetainsDistrictProgress() {
    let suite = "voltage-relaunch-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let session = GameSession(defaults: defaults)
    session.sound = false
    session.haptics = false
    session.newGame()
    session.launch()
    for _ in 0..<18000 where session.engine.inFlight {
      session.consume(session.engine.advance(1 / 120))
    }
    XCTAssertEqual(session.score.nextDistrict, 1)
    session.launch()
    XCTAssertEqual(session.banner, "NEXT · THE SPIRE")
  }

  func testPlungerPowerScalesLaunchSpeedWithinBounds() {
    let soft = PinballEngine()
    let hard = PinballEngine()
    let wild = PinballEngine()
    soft.launch(power: 0)
    hard.launch(power: 1)
    wild.launch(power: 7)
    XCTAssertEqual(soft.velocity.y, PinballEngine.launchSpeeds.lowerBound)
    XCTAssertEqual(hard.velocity.y, PinballEngine.launchSpeeds.upperBound)
    XCTAssertEqual(wild.velocity, hard.velocity)
    for engine in [soft, hard] {
      for _ in 0..<18000 where engine.inFlight {
        _ = engine.advance(1 / 120)
        XCTAssertGreaterThan(engine.ball.x, 0)
        XCTAssertLessThan(engine.ball.x, 390)
      }
      XCTAssertFalse(engine.inFlight)
    }
  }

  @MainActor
  func testCoachingEndsAfterFirstFlipAndPlungerIgnoredInFlight() {
    let suite = "voltage-coach-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let session = GameSession(defaults: defaults)
    session.sound = false
    session.haptics = false
    session.newGame()
    XCTAssertTrue(session.coaching)
    session.pullPlunger(0.6)
    XCTAssertEqual(session.plungerPull, 0.6)
    session.launch(power: session.plungerPull)
    XCTAssertEqual(session.plungerPull, 0)
    XCTAssertEqual(session.banner, "TOUCH EITHER SIDE TO FLIP")
    session.pullPlunger(1)
    XCTAssertEqual(session.plungerPull, 0)
    session.setFlipper(left: true, pressed: true)
    XCTAssertTrue(session.leftHeld)
    XCTAssertFalse(session.coaching)
    XCTAssertEqual(session.banner, "NEXT · THE ARCADE")
    session.newGame()
    XCTAssertFalse(session.coaching)
  }

  func testBallRemainsInsideSideRailsThroughoutAPlayedGame() {
    let engine = PinballEngine()
    for frame in 0..<15000 {
      if !engine.inFlight { engine.launch() }
      engine.leftPressed = frame % 90 < 45
      engine.rightPressed = frame % 75 < 30
      _ = engine.advance(1 / 120)
      XCTAssertGreaterThan(engine.ball.x, 0)
      XCTAssertLessThan(engine.ball.x, 390)
      if engine.finished { break }
    }
    XCTAssertTrue(engine.finished)
    XCTAssertGreaterThan(engine.score.circuits, 0)
  }

  func testOrderedCircuitAndMultiplierScoring() {
    var score = ScoreCard()
    XCTAssertFalse(score.hit(2))
    XCTAssertEqual(score.nextDistrict, 0)
    XCTAssertFalse(score.hit(0))
    XCTAssertFalse(score.hit(1))
    XCTAssertTrue(score.hit(2))
    XCTAssertEqual(score.points, 2650)
    XCTAssertEqual(score.circuits, 1)
    XCTAssertEqual(score.multiplier, 2)
    XCTAssertEqual(score.nextDistrict, 0)
    for _ in 0..<8 { for district in 0..<3 { _ = score.hit(district) } }
    XCTAssertEqual(score.multiplier, 5)
  }

  func testSegmentProjectionClampsToEndpoints() {
    let rail = Rail(a: Vector(x: 0, y: 0), b: Vector(x: 10, y: 0))
    XCTAssertEqual(rail.closest(to: Vector(x: 5, y: 10)), Vector(x: 5, y: 0))
    XCTAssertEqual(rail.closest(to: Vector(x: 20, y: -5)), Vector(x: 10, y: 0))
    XCTAssertEqual(rail.closest(to: Vector(x: -20, y: 5)), .zero)
  }

  func testThreeBallGameTerminatesAndCannotRelaunch() {
    let engine = PinballEngine()
    for ball in 1...3 {
      engine.launch()
      engine.launch()
      XCTAssertEqual(engine.ballsUsed, ball)
      for _ in 0..<18000 where engine.inFlight { _ = engine.advance(1 / 120) }
      XCTAssertFalse(engine.inFlight, "Ball must eventually drain without input")
    }
    XCTAssertTrue(engine.finished)
    engine.launch()
    XCTAssertFalse(engine.inFlight)
    XCTAssertEqual(engine.ballsRemaining, 0)
  }

  func testPhysicsIsStableAndFixedStepRepeatable() {
    let a = PinballEngine()
    let b = PinballEngine()
    a.launch()
    b.launch()
    for frame in 0..<2400 {
      let flip = frame % 90 < 45
      a.leftPressed = flip
      b.leftPressed = flip
      a.rightPressed = !flip
      b.rightPressed = !flip
      _ = a.advance(1 / 120)
      _ = b.advance(1 / 120)
      XCTAssertTrue(a.ball.x.isFinite && a.ball.y.isFinite)
      XCTAssertLessThanOrEqual(a.velocity.length, 1100.001)
      XCTAssertEqual(a.ball, b.ball)
    }
    XCTAssertGreaterThan(a.score.points, 0)
  }

  func testFlipperMovesUpwardAndReleases() {
    let engine = PinballEngine()
    let initial = engine.flipper(left: true).b.y
    engine.leftPressed = true
    for _ in 0..<30 { _ = engine.advance(1 / 120) }
    XCTAssertGreaterThan(engine.flipper(left: true).b.y, initial + 40)
    engine.leftPressed = false
    for _ in 0..<50 { _ = engine.advance(1 / 120) }
    XCTAssertEqual(engine.flipper(left: true).b.y, initial, accuracy: 0.1)
  }

  @MainActor
  func testRecordsAndSettingsSurviveNewSession() {
    let suite = "voltage-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(12500, forKey: "best")
    defaults.set(4, forKey: "circuits")
    let session = GameSession(defaults: defaults)
    session.sound = false
    session.haptics = false
    let restored = GameSession(defaults: defaults)
    XCTAssertEqual(restored.best, 12500)
    XCTAssertEqual(restored.lifetimeCircuits, 4)
    XCTAssertFalse(restored.sound)
    XCTAssertFalse(restored.haptics)
    restored.newGame()
    XCTAssertEqual(restored.best, 12500)
    XCTAssertEqual(restored.score.points, 0)
  }
}
