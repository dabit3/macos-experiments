import Foundation

@main
struct EngineTests {
  static var checks = 0

  static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    guard condition() else {
      fatalError("FAIL: \(message)")
    }
  }

  static func crossNext(_ engine: inout DriftEngine) -> [FlightEvent] {
    guard let wave = engine.approaching else { fatalError("Expected approaching wave") }
    var events: [FlightEvent] = []
    for _ in 0..<1000 {
      events += engine.tick(0.05)
      if !engine.waves.contains(where: { $0.id == wave.id }) { break }
    }
    return events
  }

  static func main() {
    var engine = DriftEngine()
    expect(engine.phase == .ready && engine.score == 0, "Fresh state")
    engine.steer(to: 2)
    expect(engine.lane == 1, "Cannot steer outside a flight")
    engine.start(.practice)
    engine.steer(to: -5)
    expect(engine.lane == 0, "Left steering clamps")
    engine.steer(to: 100)
    expect(engine.lane == 2, "Right steering clamps")
    print("PASS: phase and lane boundaries")

    engine.steer(to: 0)
    let capture = crossNext(&engine)
    expect(capture == [.nearMiss(35), .energy(100)], "Real collection and adjacent near miss")
    expect(
      engine.energy == 1 && engine.bonus == 135 && engine.shields == 2,
      "Collection updates score, not shields")
    expect(engine.score >= 218, "Distance contributes to score")
    print("PASS: energy, distance and near-miss scoring")

    engine.start(.practice)
    for hit in 0..<3 {
      engine.steer(to: engine.approaching!.hazard)
      let events = crossNext(&engine)
      expect(events.contains(.collision), "Collision at the crossing")
      expect(engine.shields == max(0, 1 - hit), "Shield consumed once per wave")
      expect(engine.energy == 0, "Collisions cannot award a cell")
      if hit < 2 {
        expect(engine.phase == .running, "Shield absorbs an impact")
      } else {
        expect(engine.phase == .ended && events.contains(.gameOver), "Third impact ends the run")
      }
    }
    let finalScore = engine.score
    _ = engine.tick(0.1)
    expect(engine.score == finalScore, "Ended score is frozen")
    print("PASS: two shields, fair third-impact game over, frozen result")

    engine.start(.practice)
    engine.steer(to: 2)
    _ = crossNext(&engine)
    expect(engine.energy == 0 && engine.nearMisses == 1, "Adjacent pass without collecting")
    engine.steer(to: 2)
    _ = crossNext(&engine)
    expect(engine.combo == 0, "Distant pass breaks combo")
    print("PASS: collection lane and combo reset")

    engine.start(.practice)
    for _ in 0..<8 {
      let hazard = engine.approaching!.hazard
      engine.steer(to: hazard == 0 ? 1 : hazard - 1)
      _ = crossNext(&engine)
    }
    expect(engine.combo == 8 && engine.multiplier == 4, "Near-miss chain caps at 4x")
    expect(engine.nearMisses == 8, "Near-miss count")
    engine.steer(to: engine.approaching!.hazard)
    _ = crossNext(&engine)
    expect(engine.combo == 0 && engine.multiplier == 1, "Impact resets multiplier")
    print("PASS: combo growth, cap and collision reset")

    engine.start(.endless)
    _ = engine.tick(0.2)
    engine.pause()
    let distance = engine.distance
    let waves = engine.waves
    engine.steer(to: 0)
    expect(engine.tick(0.2).isEmpty, "Paused emits no events")
    expect(
      engine.distance == distance && engine.waves == waves && engine.lane == 1,
      "Paused state stays fixed")
    engine.resume()
    _ = engine.tick(0.2)
    expect(engine.distance > distance, "Resume progresses")
    let valid = engine.distance
    for invalid in [Double.nan, Double.infinity, -1, 0, 100] {
      expect(
        engine.tick(invalid).isEmpty && engine.distance == valid, "Invalid clock input is rejected")
    }
    print("PASS: pause, resume and invalid clock recovery")

    engine.start(.practice)
    expect(
      engine.shields == 2 && engine.score == 0 && engine.energy == 0 && engine.lane == 1,
      "Restart restores clean state")
    print("PASS: restart recovery")

    var a = DriftEngine()
    var b = DriftEngine()
    a.start(.endless, seed: 867)
    b.start(.endless, seed: 867)
    var ids = Set<Int>()
    for _ in 0..<12000 {
      if let wave = a.approaching {
        a.steer(to: wave.energy)
        b.steer(to: wave.energy)
      }
      _ = a.tick(0.05)
      _ = b.tick(0.05)
      expect(a.waves == b.waves && a.score == b.score, "Seed is deterministic")
      for wave in a.waves {
        ids.insert(wave.id)
        expect(
          (0...2).contains(wave.hazard) && (0...2).contains(wave.energy), "Generated lanes valid")
        expect(wave.hazard != wave.energy, "Reward is always reachable")
      }
      expect(a.shields == 2, "Choosing the reward lane survives")
      expect(a.mode.spacing / a.speed > 1.7, "Minimum safe wave spacing even at max speed")
    }
    expect(
      ids.count > 250 && a.phase == .running && a.energy > 250, "Long endless run remains playable")
    expect(a.speed == 1.65, "Speed has a cap")
    print("PASS: seeded procedural fairness across \(ids.count) waves")

    a.start(.practice)
    b.start(.practice)
    a.steer(to: 0)
    b.steer(to: 0)
    for _ in 0..<900 { _ = a.tick(1.0 / 60) }
    for _ in 0..<300 { _ = b.tick(1.0 / 20) }
    expect(
      abs(a.distance - b.distance) < 0.000_001 && a.bonus == b.bonus,
      "Frame-rate-independent simulation")
    print("PASS: frame rate independence")

    let suite = "lumen-drift.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = FlightStore(defaults: defaults)
    expect(store.load() == FlightRecord(), "Missing save recovers")
    defaults.set(Data("invalid".utf8), forKey: "lumen-drift.records.v1")
    expect(store.load() == FlightRecord(), "Corrupt save recovers")
    var record = FlightRecord()
    record.save(mode: .practice, score: 950, energy: 5)
    record.save(mode: .practice, score: 10, energy: 1)
    record.save(mode: .endless, score: 400, energy: 3)
    store.save(record)
    let reloaded = FlightStore(defaults: defaults).load()
    expect(reloaded == record, "Persistence roundtrip")
    expect(
      reloaded.practiceBest == 950 && reloaded.endlessBest == 400,
      "Mode records isolated and monotonic")
    expect(reloaded.flights == 3 && reloaded.totalEnergy == 9, "Lifetime stats accumulate")
    print("PASS: durable mode records, corruption recovery and serialization")
    print("ALL PASSED: \(checks) assertions")
  }
}
