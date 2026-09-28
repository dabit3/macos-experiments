import XCTest

@testable import OtterFlapRules

final class FlapEngineTests: XCTestCase {
  private func advance(_ engine: inout FlapEngine, seconds: Double) {
    for _ in 0..<Int(seconds * 60) { engine.advance(1.0 / 60.0) }
  }

  func testReadyHoversUntilFirstFlap() {
    var engine = FlapEngine()
    advance(&engine, seconds: 2)
    XCTAssertEqual(engine.phase, .ready)
    XCTAssertTrue(engine.gates.isEmpty)
    XCTAssertEqual(engine.y, 360, accuracy: 13)
    engine.flap()
    XCTAssertEqual(engine.phase, .flying)
    XCTAssertEqual(engine.velocity, FlapEngine.flapVelocity)
    XCTAssertEqual(engine.gates.count, 1)
  }

  func testFlapRisesThenGravityPullsDown() {
    var engine = FlapEngine()
    engine.flap()
    let start = engine.y
    advance(&engine, seconds: 0.15)
    XCTAssertLessThan(engine.y, start)
    advance(&engine, seconds: 0.5)
    XCTAssertGreaterThan(engine.velocity, 0)
  }

  func testFallingIntoWaterEndsRun() {
    var engine = FlapEngine()
    engine.flap()
    advance(&engine, seconds: 4)
    XCTAssertEqual(engine.phase, .over)
    XCTAssertEqual(engine.score, 0)
    engine.flap()
    XCTAssertEqual(engine.phase, .over)
  }

  func testCeilingClampsOtter() {
    var engine = FlapEngine()
    for _ in 0..<40 {
      engine.flap()
      advance(&engine, seconds: 0.05)
    }
    XCTAssertGreaterThanOrEqual(engine.y, FlapEngine.radius)
  }

  func testAutopilotThroughGapsScoresPoints() {
    var engine = FlapEngine(seed: 42)
    engine.flap()
    for _ in 0..<(60 * 30) {
      let target =
        engine.gates.first { $0.x + FlapEngine.gateWidth / 2 > engine.otterX - 30 }?
        .gapCenter ?? 360
      if engine.y > target + 18 && engine.velocity > -100 { engine.flap() }
      engine.advance(1.0 / 60.0)
    }
    XCTAssertEqual(engine.phase, .flying)
    XCTAssertGreaterThan(engine.score, 15)
    XCTAssertEqual(engine.gates.map(\.id), engine.gates.map(\.id).sorted())
  }

  func testGapsStayInsidePlayfield() {
    var engine = FlapEngine(seed: 9)
    engine.flap()
    for _ in 0..<(60 * 20) {
      if engine.y > 420 && engine.velocity > 0 { engine.flap() }
      engine.advance(1.0 / 60.0)
      for gate in engine.gates {
        XCTAssertGreaterThan(gate.gapCenter - engine.gap / 2, 80)
        XCTAssertLessThan(gate.gapCenter + engine.gap / 2, FlapEngine.waterLine)
      }
    }
  }

  func testFirstGateOpensNearStartHeight() {
    for seed in 1...50 {
      var engine = FlapEngine(seed: UInt64(seed))
      engine.flap()
      XCTAssertEqual(engine.gates[0].gapCenter, 360, accuracy: 60)
    }
  }

  func testMedals() {
    XCTAssertNil(FlapEngine.medal(for: 9))
    XCTAssertEqual(FlapEngine.medal(for: 10), "Bronze")
    XCTAssertEqual(FlapEngine.medal(for: 30), "Silver")
    XCTAssertEqual(FlapEngine.medal(for: 50), "Gold")
    XCTAssertEqual(FlapEngine.medal(for: 140), "Pearl")
  }
}
