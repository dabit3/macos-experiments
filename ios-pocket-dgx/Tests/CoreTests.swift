import XCTest

@testable import PocketDGXCore

final class CoreTests: XCTestCase {
  func testPowerOnBootsThenRuns() {
    var rig = RigSimulation(kind: .rack)
    XCTAssertEqual(rig.phase, .off)
    XCTAssertEqual(rig.togglePower(), .booting)
    for _ in 0..<40 { rig.tick(1 / 60) }
    XCTAssertEqual(rig.phase, .booting)
    XCTAssertGreaterThan(rig.fan, 0)
    for _ in 0..<200 { rig.tick(1 / 60) }
    XCTAssertEqual(rig.phase, .running)
    XCTAssertGreaterThan(rig.uptime, 0)
    XCTAssertGreaterThan(rig.tokensPerSecond, 0)
  }

  func testRunningApproachesPeakThroughput() {
    var rig = RigSimulation(kind: .card)
    rig.togglePower()
    for _ in 0..<600 { rig.tick(1 / 60) }
    XCTAssertEqual(rig.phase, .running)
    XCTAssertEqual(
      rig.tokensPerSecond, RigKind.card.peakTokensPerSecond,
      accuracy: RigKind.card.peakTokensPerSecond * 0.08)
    XCTAssertGreaterThan(rig.totalTokens, 0)
    XCTAssertEqual(rig.fan, 1, accuracy: 0.05)
  }

  func testShutdownSpinsDownAndGoesDark() {
    var rig = RigSimulation(kind: .rack)
    rig.togglePower()
    for _ in 0..<300 { rig.tick(1 / 60) }
    XCTAssertEqual(rig.togglePower(), .shuttingDown)
    for _ in 0..<600 { rig.tick(1 / 60) }
    XCTAssertEqual(rig.phase, .off)
    XCTAssertEqual(rig.fan, 0)
    XCTAssertEqual(rig.tokensPerSecond, 0)
    XCTAssertEqual(rig.ledPulse, 0)
    XCTAssertEqual(rig.watts, 0)
  }

  func testTogglingDuringBootStartsShutdown() {
    var rig = RigSimulation(kind: .rack)
    rig.togglePower()
    rig.tick(0.5)
    XCTAssertEqual(rig.togglePower(), .shuttingDown)
  }

  func testDeltaIsCappedSoHitchesDoNotSkipBoot() {
    var rig = RigSimulation(kind: .rack)
    rig.togglePower()
    rig.tick(10)
    XCTAssertEqual(rig.phase, .booting)
    XCTAssertEqual(rig.transition, 0.05 / RigSimulation.bootDuration, accuracy: 1e-9)
    rig.tick(-1)
    XCTAssertEqual(rig.transition, 0.05 / RigSimulation.bootDuration, accuracy: 1e-9)
  }

  func testFanAngleOnlyAdvancesWhileSpinning() {
    var rig = RigSimulation(kind: .card)
    for _ in 0..<60 { rig.tick(1 / 60) }
    XCTAssertEqual(rig.fanAngle, 0)
    rig.togglePower()
    for _ in 0..<60 { rig.tick(1 / 60) }
    XCTAssertGreaterThan(rig.fanAngle, 0)
  }

  func testPulseCurveStaysInUnitRange() {
    for phase in [PowerPhase.off, .booting, .running, .shuttingDown] {
      for step in 0...50 {
        let t = Double(step) / 50
        let value = RigSimulation.pulse(phase: phase, transition: t, clock: t * 13)
        XCTAssertGreaterThanOrEqual(value, 0)
        XCTAssertLessThanOrEqual(value, 1.0001)
      }
    }
  }

  func testScalePresetsSnapAndClamp() {
    XCTAssertEqual(ScalePreset.nearest(to: 1.1), .life)
    XCTAssertEqual(ScalePreset.nearest(to: 0.2), .desk)
    XCTAssertEqual(ScalePreset.nearest(to: 3), .room)
    XCTAssertEqual(ScalePreset.nearest(to: 40), .house)
    XCTAssertEqual(ScalePreset.clamp(0.0001), ScalePreset.minimum)
    XCTAssertEqual(ScalePreset.clamp(999), ScalePreset.maximum)
    XCTAssertEqual(
      ScalePreset.allCases.map(\.multiplier), ScalePreset.allCases.map(\.multiplier).sorted())
  }

  func testRackLayoutFitsInsideCabinet() {
    let centers = RackLayout.bladeCenters()
    XCTAssertEqual(centers.count, RackLayout.bladeCount)
    XCTAssertGreaterThan(centers.first! - RackLayout.bladeHeight / 2, 0)
    XCTAssertLessThan(centers.last! + RackLayout.bladeHeight / 2, RackLayout.height)
    let fans = RackLayout.fanCenters()
    XCTAssertEqual(fans.count, RackLayout.fansPerBlade)
    XCTAssertEqual(fans.reduce(0, +), 0, accuracy: 1e-9)
    XCTAssertLessThan(abs(fans.last!), RackLayout.width / 2)
  }

  func testBootSequenceCoversWholeProgressRange() {
    for kind in RigKind.allCases {
      let lines = BootSequence.lines(for: kind)
      XCTAssertEqual(BootSequence.line(for: kind, progress: 0), lines.first)
      XCTAssertEqual(BootSequence.line(for: kind, progress: 1), lines.last)
      XCTAssertEqual(BootSequence.line(for: kind, progress: 2), lines.last)
      XCTAssertEqual(BootSequence.line(for: kind, progress: -1), lines.first)
    }
  }

  func testFormatting() {
    XCTAssertEqual(Format.tokens(1_800_000), "1.80M")
    XCTAssertEqual(Format.tokens(14_200), "14.2K")
    XCTAssertEqual(Format.tokens(42), "42")
    XCTAssertEqual(Format.watts(120_000), "120.0 kW")
    XCTAssertEqual(Format.watts(600), "600 W")
    XCTAssertEqual(Format.scale(1, kind: .rack), "2.0 m tall")
    XCTAssertEqual(Format.scale(0.18, kind: .rack), "36 cm tall")
    XCTAssertEqual(Format.uptime(125), "02:05")
  }

  func testStatsRankAndRecordingRoundTrip() throws {
    var stats = RigStats()
    XCTAssertEqual(stats.rank, "Intern")
    stats.totalTokens = 6_000_000
    XCTAssertEqual(stats.rank, "CUDA Whisperer")
    stats.totalTokens = 60_000_000
    XCTAssertEqual(stats.rank, "Tensor Wrangler")
    var rig = RigSimulation(kind: .rack, scale: 7)
    rig.togglePower()
    for _ in 0..<400 { rig.tick(1 / 60) }
    stats.record(rig)
    XCTAssertEqual(stats.largestScale, 7)
    XCTAssertGreaterThan(stats.longestUptime, 0)
    let data = try JSONEncoder().encode(stats)
    XCTAssertEqual(try JSONDecoder().decode(RigStats.self, from: data), stats)
  }

  func testLoreCaptionIsDeterministic() {
    XCTAssertEqual(Lore.caption(seed: 3), Lore.caption(seed: 3))
    XCTAssertEqual(Lore.caption(seed: -3), Lore.caption(seed: 3))
    XCTAssertEqual(Set(Lore.captions).count, Lore.captions.count)
  }
}
