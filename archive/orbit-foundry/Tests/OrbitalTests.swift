import XCTest

@testable import OrbitFoundry

final class OrbitalTests: XCTestCase {
  func testEveryHandDesignedMissionHasACompleteSolution() {
    XCTAssertEqual(Mission.all.count, 8)
    for mission in Mission.all {
      var flight = Flight(position: mission.origin, velocity: mission.reference)
      for _ in 0..<1500 { OrbitalPhysics.advance(&flight, mission: mission) }
      XCTAssertEqual(flight.outcome, .docked, "Mission \(mission.number): \(flight)")
      XCTAssertEqual(flight.collected.count, mission.beacons.count)
      XCTAssertLessThan(flight.elapsed, 12)
    }
  }

  func testPredictionAndActualFlightShareExactIntegration() {
    for mission in Mission.all {
      let prediction = OrbitalPhysics.prediction(mission: mission, velocity: mission.reference)
      var flight = Flight(position: mission.origin, velocity: mission.reference)
      for _ in 0..<1500 { OrbitalPhysics.advance(&flight, mission: mission) }
      XCTAssertEqual(prediction.last, flight.position)
    }
  }

  func testGravityIsFiniteEvenAtCenterAndPullsTowardPlanet() {
    let planet = Mission.all[0].planets[0]
    XCTAssertEqual(OrbitalPhysics.acceleration(at: planet.center, planets: [planet]), .zero)
    let acceleration = OrbitalPhysics.acceleration(at: Vector(x: 0, y: 0), planets: [planet])
    XCTAssertGreaterThan(acceleration.x, 0)
    XCTAssertGreaterThan(acceleration.y, 0)
    XCTAssertTrue(acceleration.length.isFinite)
  }

  func testBroadRangeOfTrajectoriesRemainFiniteAndTerminate() {
    for mission in Mission.all {
      for angle in stride(from: -80.0, through: 80, by: 20) {
        for thrust in [55.0, 100, 155] {
          let velocity = Vector(
            x: sin(angle * .pi / 180) * thrust, y: -cos(angle * .pi / 180) * thrust)
          var flight = Flight(position: mission.origin, velocity: velocity)
          for _ in 0..<1500 { OrbitalPhysics.advance(&flight, mission: mission) }
          XCTAssertTrue(flight.position.x.isFinite && flight.position.y.isFinite)
          XCTAssertNotEqual(flight.outcome, .flying)
        }
      }
    }
  }

  func testSurfaceContactAndMissingBeaconsAreFailures() {
    let mission = Mission.all[0]
    var contact = Flight(position: mission.planets[0].center, velocity: .zero)
    OrbitalPhysics.advance(&contact, mission: mission)
    XCTAssertEqual(contact.outcome, .failed("Surface contact"))
    var missed = Flight(position: mission.station, velocity: .zero)
    OrbitalPhysics.advance(&missed, mission: mission)
    XCTAssertEqual(missed.outcome, .failed("A signal was left behind"))
  }

  func testFinishedFlightDoesNotContinueOrChangeItsScore() {
    var flight = Flight(position: Mission.all[0].origin, velocity: Mission.all[0].reference)
    for _ in 0..<1500 { OrbitalPhysics.advance(&flight, mission: Mission.all[0]) }
    let elapsed = flight.elapsed
    let position = flight.position
    for _ in 0..<120 { OrbitalPhysics.advance(&flight, mission: Mission.all[0]) }
    XCTAssertEqual(flight.elapsed, elapsed)
    XCTAssertEqual(flight.position, position)
  }

  func testLaunchResetAndRepeatedLaunchProtection() {
    let controller = FlightController(mission: Mission.all[0])
    controller.launch()
    controller.launch()
    XCTAssertEqual(controller.attempts, 1)
    for _ in 0..<10 { controller.tick() }
    XCTAssertFalse(controller.trail.isEmpty)
    controller.reset()
    XCTAssertNil(controller.flight)
    XCTAssertTrue(controller.trail.isEmpty)
    XCTAssertEqual(controller.attempts, 1)
    controller.launch()
    XCTAssertEqual(controller.attempts, 2)
    XCTAssertEqual(controller.flight?.collected.count, 0)
  }

  func testAimClampsAndGuideRestoresKnownSolution() {
    let controller = FlightController(mission: Mission.all[5])
    controller.aim(toward: Vector(x: 9999, y: -9999))
    XCTAssertLessThanOrEqual(controller.thrust, 155)
    XCTAssertLessThanOrEqual(controller.angle, 80)
    controller.useGuide()
    XCTAssertEqual(controller.velocity.x, controller.mission.reference.x, accuracy: 0.00001)
    XCTAssertEqual(controller.velocity.y, controller.mission.reference.y, accuracy: 0.00001)
    XCTAssertTrue(controller.guided)
  }

  func testReplayAfterWinningStartsFreshScoreAndClearsCaptureEffects() {
    let controller = FlightController(mission: Mission.all[0])
    controller.useGuide()
    controller.launch()
    for _ in 0..<750 { controller.tick() }
    XCTAssertEqual(controller.flight?.outcome, .docked)
    XCTAssertEqual(controller.captureMoments.count, 2)
    controller.reset()
    XCTAssertEqual(controller.attempts, 0)
    XCTAssertFalse(controller.guided)
    XCTAssertTrue(controller.captureMoments.isEmpty)
    controller.launch()
    XCTAssertEqual(controller.attempts, 1)
  }

  func testProgressionPersistenceAndBestScores() throws {
    let suite = "orbit-foundry-test-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = FlightStore(defaults: defaults)
    XCTAssertTrue(store.unlocked(0))
    XCTAssertFalse(store.unlocked(1))
    store.complete(3, attempts: 1, seconds: 3, guided: false)
    XCTAssertNil(store.record(for: 3))
    store.registerLaunch()
    store.complete(0, attempts: 3, seconds: 4, guided: true)
    XCTAssertTrue(store.unlocked(1))
    store.complete(0, attempts: 4, seconds: 2, guided: false)
    XCTAssertEqual(store.record(for: 0)?.attempts, 3)
    store.complete(0, attempts: 1, seconds: 3, guided: false)
    store.complete(0, attempts: 1, seconds: 2.8, guided: false)
    let restored = FlightStore(defaults: defaults)
    XCTAssertEqual(restored.record(for: 0)?.attempts, 1)
    XCTAssertEqual(restored.record(for: 0)?.seconds, 2.8)
    XCTAssertEqual(restored.record(for: 0)?.stars, 3)
    XCTAssertEqual(restored.archive.launches, 1)
    XCTAssertEqual(restored.nextMission.id, 1)
    restored.reset()
    XCTAssertEqual(FlightStore(defaults: defaults).completed, 0)
    XCTAssertFalse(FlightStore(defaults: defaults).unlocked(1))
  }

  func testCorruptSavedDataFallsBackToFreshArchive() throws {
    let suite = "orbit-foundry-corrupt-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(Data("not-json".utf8), forKey: "orbit-foundry.archive.v1")
    XCTAssertEqual(FlightStore(defaults: defaults).completed, 0)
  }

  func testAllMissionsProgressAndFinalAtlasState() throws {
    let suite = "orbit-foundry-atlas-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = FlightStore(defaults: defaults)
    for mission in Mission.all {
      XCTAssertTrue(store.unlocked(mission.id))
      store.complete(mission.id, attempts: 1, seconds: 3, guided: true)
    }
    XCTAssertEqual(store.completed, 8)
    XCTAssertEqual(store.nextMission.id, 7)
    XCTAssertEqual(FlightStore(defaults: defaults).completed, 8)
  }
}
