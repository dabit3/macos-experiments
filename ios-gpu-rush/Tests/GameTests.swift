import XCTest

@testable import GPURushCore

final class GameTests: XCTestCase {
  private func runningSim(seed: UInt64 = 7) -> RunSimulation {
    var sim = RunSimulation(seed: seed)
    sim.start()
    return sim
  }

  /// Moves one lane toward a lane that is free in the nearest obstacle row.
  /// Rows never block all three lanes, so this keeps a run alive forever.
  private func autoSteer(_ sim: inout RunSimulation) {
    let obstacles = sim.state.entities.filter {
      if case .obstacle = $0.kind {
        let lead = $0.distance - sim.state.runDistance
        return lead > 0 && lead < 10
      }
      return false
    }
    guard let nearest = obstacles.min(by: { $0.distance < $1.distance }) else { return }
    let blocked = Set(obstacles.filter { abs($0.distance - nearest.distance) < 1 }.map { $0.lane })
    guard blocked.contains(sim.state.lane) else { return }
    for lane in Lane.allCases where !blocked.contains(lane) {
      if lane.rawValue < sim.state.lane.rawValue {
        if sim.moveLeft() { return }
      } else if sim.moveRight() {
        return
      }
    }
  }

  private func step(_ sim: inout RunSimulation, seconds: Double) -> [RunEvent] {
    var events: [RunEvent] = []
    var remaining = seconds
    while remaining > 0 {
      let dt = min(0.05, remaining)
      autoSteer(&sim)
      events.append(contentsOf: sim.advance(by: dt))
      remaining -= dt
    }
    return events
  }

  func testLaneMovementIsBounded() {
    var sim = runningSim()
    XCTAssertTrue(sim.moveLeft())
    XCTAssertEqual(sim.state.lane, .left)
    XCTAssertFalse(sim.moveLeft())
    XCTAssertEqual(sim.state.lane, .left)
    XCTAssertTrue(sim.moveRight())
    XCTAssertTrue(sim.moveRight())
    XCTAssertFalse(sim.moveRight())
    XCTAssertEqual(sim.state.lane, .right)
  }

  func testSpeedRampsAndCaps() {
    var sim = runningSim()
    var last = sim.state.baseSpeed
    for _ in 0..<4000 {
      autoSteer(&sim)
      sim.advance(by: 0.05)
      XCTAssertGreaterThanOrEqual(sim.state.baseSpeed, last)
      last = sim.state.baseSpeed
    }
    XCTAssertEqual(sim.state.baseSpeed, sim.config.maxBaseSpeed)
    let expected =
      sim.state.baseSpeed * (sim.state.dlssActive ? sim.config.dlssMultiplier : 1)
    XCTAssertEqual(sim.state.speed, expected, accuracy: 0.001)
  }

  func testDlssOrbTriplesThenExpires() {
    var sim = runningSim()
    sim.insertEntity(
      Entity(id: 900, lane: .center, distance: sim.state.runDistance + 0.5, kind: .pickup(.dlssOrb))
    )
    let events = sim.advance(by: 0.05)
    XCTAssertTrue(events.contains(.dlssActivated))
    autoSteer(&sim)
    sim.advance(by: 0.05)
    let boosted = sim.state.speed
    XCTAssertEqual(boosted, sim.state.baseSpeed * sim.config.dlssMultiplier, accuracy: 0.001)
    let stream = step(&sim, seconds: 6)
    XCTAssertTrue(stream.contains(.dlssEnded))
    XCTAssertFalse(sim.state.dlssActive)
    XCTAssertEqual(sim.state.speed, sim.state.baseSpeed, accuracy: 0.001)
    XCTAssertLessThan(sim.state.speed, boosted)
  }

  func testHeatWaveWithoutJumpCrashes() {
    var sim = runningSim()
    sim.insertEntity(
      Entity(
        id: 901, lane: .center, distance: sim.state.runDistance + 2, kind: .obstacle(.heatWave)))
    var crashed = false
    for _ in 0..<40 {
      if sim.advance(by: 0.05).contains(.crashed(.heatWave)) { crashed = true }
    }
    XCTAssertTrue(crashed)
    XCTAssertEqual(sim.state.phase, .crashed)
    XCTAssertTrue(sim.advance(by: 0.05).isEmpty)
  }

  func testJumpClearsHeatWave() {
    var sim = runningSim()
    sim.insertEntity(
      Entity(
        id: 902, lane: .center, distance: sim.state.runDistance + 4, kind: .obstacle(.heatWave)))
    sim.jump()
    for _ in 0..<20 { sim.advance(by: 0.05) }
    XCTAssertEqual(sim.state.phase, .running)
    XCTAssertFalse(sim.state.entities.contains { $0.id == 902 })
  }

  func testCapacitorBarSlideAndJump() {
    var sim = runningSim(seed: 11)
    sim.insertEntity(
      Entity(
        id: 903, lane: .center, distance: sim.state.runDistance + 4, kind: .obstacle(.capacitorBar))
    )
    sim.slide()
    for _ in 0..<20 { sim.advance(by: 0.05) }
    XCTAssertEqual(sim.state.phase, .running)

    var sim2 = runningSim(seed: 11)
    sim2.insertEntity(
      Entity(
        id: 904, lane: .center, distance: sim2.state.runDistance + 4,
        kind: .obstacle(.capacitorBar)))
    sim2.jump()
    var crashed = false
    for _ in 0..<30 {
      if sim2.advance(by: 0.05).contains(.crashed(.capacitorBar)) { crashed = true }
    }
    XCTAssertTrue(crashed)
  }

  func testJumpWhileSlidingIgnored() {
    var sim = runningSim()
    sim.slide()
    sim.jump()
    XCTAssertEqual(sim.state.stance, .sliding)
  }

  func testCoinsAddToScoreAndDlssDoubles() {
    var sim = runningSim()
    sim.insertEntity(
      Entity(
        id: 905, lane: .center, distance: sim.state.runDistance + 0.4, kind: .pickup(.cudaCoin)))
    sim.insertEntity(
      Entity(
        id: 906, lane: .center, distance: sim.state.runDistance + 0.5, kind: .pickup(.cudaCoin)))
    let events = sim.advance(by: 0.05)
    XCTAssertTrue(events.contains(.coin(total: 2)))
    XCTAssertEqual(sim.state.coins, 2)
    XCTAssertEqual(sim.state.score, Int(sim.state.runDistance) + 20)
    sim.insertEntity(
      Entity(id: 907, lane: .center, distance: sim.state.runDistance + 0.3, kind: .pickup(.dlssOrb))
    )
    sim.advance(by: 0.05)
    XCTAssertEqual(sim.state.score, (Int(sim.state.runDistance) + sim.state.coins * 10) * 2)
  }

  func testSpawnRowsNeverBlockAllLanes() {
    for seed in 1...20 {
      var sim = RunSimulation(seed: UInt64(seed * 977))
      sim.start()
      _ = step(&sim, seconds: 220)
      var obstaclesByRow: [Int: Int] = [:]
      for entity in sim.state.entities where entity.distance > sim.state.runDistance {
        if case .obstacle = entity.kind {
          obstaclesByRow[Int(entity.distance.rounded()), default: 0] += 1
        }
      }
      for (row, count) in obstaclesByRow {
        XCTAssertLessThanOrEqual(count, 2, "row at \(row)m blocks all lanes (seed \(seed))")
      }
      XCTAssertFalse(obstaclesByRow.isEmpty)
    }
  }

  func testDeterminism() {
    var first = runningSim(seed: 4242)
    var second = runningSim(seed: 4242)
    for _ in 0..<1200 {
      autoSteer(&first)
      autoSteer(&second)
      first.advance(by: 0.05)
      second.advance(by: 0.05)
    }
    XCTAssertEqual(first.state, second.state)
  }

  func testStreakTracker() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let day1 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))!
    var record = StreakTracker.Record()
    record = StreakTracker.recordRun(
      record, score: 100, distance: 500, on: day1, calendar: calendar)
    XCTAssertEqual(record.streakDays, 1)
    XCTAssertTrue(StreakTracker.isStreakAlive(record, on: day1, calendar: calendar))
    record = StreakTracker.recordRun(record, score: 50, distance: 300, on: day1, calendar: calendar)
    XCTAssertEqual(record.streakDays, 1)
    let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
    record = StreakTracker.recordRun(
      record, score: 400, distance: 900, on: day2, calendar: calendar)
    XCTAssertEqual(record.streakDays, 2)
    XCTAssertTrue(StreakTracker.isStreakAlive(record, on: day2, calendar: calendar))
    XCTAssertEqual(record.bestScore, 400)
    XCTAssertEqual(record.bestDistance, 900)
    let day5 = calendar.date(byAdding: .day, value: 3, to: day2)!
    XCTAssertFalse(StreakTracker.isStreakAlive(record, on: day5, calendar: calendar))
    record = StreakTracker.recordRun(record, score: 10, distance: 50, on: day5, calendar: calendar)
    XCTAssertEqual(record.streakDays, 1)
    XCTAssertEqual(record.totalRuns, 4)
    XCTAssertEqual(record.bestScore, 400)
  }

  func testFpsPositiveAndTriplesUnderDlss() {
    var sim = runningSim()
    sim.advance(by: 0.05)
    let normal = sim.fps
    XCTAssertGreaterThan(normal, 0)
    sim.insertEntity(
      Entity(id: 908, lane: .center, distance: sim.state.runDistance + 0.3, kind: .pickup(.dlssOrb))
    )
    sim.advance(by: 0.05)
    sim.advance(by: 0.05)
    XCTAssertGreaterThan(sim.fps, normal * 2)
  }
}
