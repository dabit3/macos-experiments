import XCTest

@testable import NectarDash

final class GardenStoreTests: XCTestCase {
  @MainActor
  func testElapsedTimeDrivesFlightAndPauseFreezesBoth() throws {
    let suite = "nectar.clock.tests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(true, forKey: "nectar.tutorialSeen")
    let store = GardenStore(defaults: defaults)
    store.start(.meadow(1))
    store.tap(store.rules.flowers[0].position)
    store.step(0.2)
    let inFlight = store.beeVisual
    XCTAssertNotEqual(inFlight, .hive)
    XCTAssertTrue(store.isFlying)
    store.paused = true
    store.step(30)
    XCTAssertEqual(store.rules.timeRemaining, 84.8, accuracy: 0.0001)
    XCTAssertEqual(store.beeVisual, inFlight)
    store.paused = false
    store.step(1.8)
    XCTAssertEqual(store.rules.timeRemaining, 83, accuracy: 0.0001)
    XCTAssertEqual(store.rules.pollen, 1)
    XCTAssertFalse(store.isFlying)
  }

  func testEveryAuthoredGardenCanBeWonWithoutHazardDamage() {
    for stage in 1...3 {
      var game = GardenRules(mode: .meadow(stage))
      for _ in 0..<(stage == 1 ? 1 : 2) {
        for index in [0, 1, 2, 3, 4, 5] {
          var path = [game.bee]
          if index == 5 {
            path.append(GardenPoint(x: 0.20, y: 0.20))
          }
          path.append(game.flowers[index].position)
          game.tick(1.5)
          let event = game.fly(along: path)
          XCTAssertEqual(
            event, index == 5 ? .blossomWave : .bloom, "Garden \(stage), bloom \(index)")
        }
        game.tick(1.5)
        XCTAssertEqual(game.fly(along: [game.bee, .hive]), .bank(120))
      }
      XCTAssertEqual(game.end, .blooming)
      XCTAssertEqual(game.hearts, 3)
      XCTAssertGreaterThan(game.timeRemaining, 0)
    }
  }
}
