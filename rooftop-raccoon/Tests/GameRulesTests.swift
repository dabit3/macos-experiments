import XCTest

@testable import RooftopRaccoon

final class GameRulesTests: XCTestCase {
  func testEdgesDoNotWrapOrConsumeBeats() {
    var mission = Mission(district: District.all[0])
    XCTAssertNil(mission.neighbor(.left))
    XCTAssertNil(mission.neighbor(.down))
    mission.move(to: 11)
    XCTAssertEqual(mission.position, 9)
    XCTAssertEqual(mission.beat, 0)
    mission.move(.up)
    XCTAssertEqual(mission.position, 6)
    XCTAssertEqual(mission.beat, 1)
  }

  func testForecastMatchesArrivalAndGardensAlwaysProtect() {
    for district in District.all {
      for roof in district.roofs {
        for beat in 1...20 {
          if roof.garden { XCTAssertFalse(roof.danger(on: beat)) }
        }
      }
    }
    XCTAssertFalse(Watcher.window(0).isAwake(on: 1))
    XCTAssertTrue(Watcher.window(0).isAwake(on: 2))
    XCTAssertTrue(Watcher.window(0).isAwake(on: 3))
    XCTAssertFalse(Watcher.window(0).isAwake(on: 4))
    XCTAssertTrue(Watcher.cat(1).isAwake(on: 3))
    XCTAssertFalse(Watcher.cat(1).isAwake(on: 4))
    var mission = Mission(district: District.all[0])
    mission.wait()
    let forecast = mission.district.roofs[10].danger(on: mission.beat + 1)
    mission.move(to: 10)
    XCTAssertTrue(forecast)
    XCTAssertEqual(mission.alarm, 1)
  }

  func testSnacksCannotBeFarmedAndTowerRequiresLoot() {
    var mission = Mission(district: District.all[0])
    mission.move(to: 6)
    mission.move(to: 9)
    mission.move(to: 6)
    XCTAssertEqual(mission.loot, 1)
    mission.move(to: 3)
    mission.move(to: 0)
    mission.move(to: 1)
    mission.move(to: 2)
    XCTAssertEqual(mission.loot, 3)
    XCTAssertEqual(mission.phase, .playing)
    XCTAssertFalse(mission.canEscape)
  }

  func testPlannedGardenWaitEnablesCleanEscapeAndExactScore() {
    var mission = Mission(district: District.all[0])
    for target in [10, 7] { mission.move(to: target) }
    mission.wait()
    for target in [4, 5, 2] { mission.move(to: target) }
    XCTAssertEqual(mission.phase, .escaped)
    XCTAssertEqual(mission.alarm, 0)
    XCTAssertEqual(mission.loot, 4)
    XCTAssertEqual(mission.score, 780)
    XCTAssertEqual(mission.rating, "SILENT & SNACKY")
    mission.wait()
    mission.move(to: 5)
    XCTAssertEqual(mission.beat, 6)
    XCTAssertEqual(mission.position, 2)
  }

  func testThreeSightingsAndDawnAreDistinctLosses() {
    var caught = Mission(district: District.all[0])
    caught.move(to: 10)
    for _ in 0..<5 { caught.wait() }
    XCTAssertEqual(caught.alarm, 3)
    XCTAssertEqual(caught.phase, .caught)
    XCTAssertEqual(caught.score, 0)
    var dawn = Mission(district: District.all[0])
    for _ in 0..<18 { dawn.wait() }
    XCTAssertEqual(dawn.phase, .dawn)
    XCTAssertEqual(dawn.alarm, 0)
    XCTAssertEqual(dawn.remaining, 0)
  }

  func testEscapeOnLastBeatWinsBeforeDawn() {
    var mission = Mission(district: District.all[0])
    for _ in 0..<12 { mission.wait() }
    for target in [10, 7] { mission.move(to: target) }
    mission.wait()
    for target in [4, 5, 2] { mission.move(to: target) }
    XCTAssertEqual(mission.beat, 18)
    XCTAssertEqual(mission.phase, .escaped)
  }

  func testEveryDistrictAllowsPerfectSevenSnackEscape() {
    for district in District.all {
      var queue = [Mission(district: district)]
      var cursor = 0
      var visited: Set<String> = []
      var solution: Mission?
      while cursor < queue.count {
        let current = queue[cursor]
        cursor += 1
        if current.phase == .escaped && current.loot == 7 {
          solution = current
          break
        }
        guard current.phase == .playing else { continue }
        for target in Direction.allCases.compactMap({ current.neighbor($0) }) + [current.position] {
          var next = current
          if target == current.position { next.wait() } else { next.move(to: target) }
          guard next.alarm == 0 else { continue }
          let mask = next.collected.reduce(0) { $0 | (1 << $1) }
          let key = "\(next.position):\(next.beat):\(mask)"
          if visited.insert(key).inserted { queue.append(next) }
        }
      }
      XCTAssertNotNil(solution, "\(district.name) must have an achievable perfect route")
      XCTAssertEqual(solution?.rating, "THE SNACK PHANTOM")
    }
  }

  func testProgressOnlyRecordsEscapesAndNeverLowersBest() throws {
    var progress = Progress()
    progress.record(Mission(district: District.all[0]))
    XCTAssertEqual(progress.totalEscapes, 0)
    var mission = Mission(district: District.all[0])
    for target in [10, 7] { mission.move(to: target) }
    mission.wait()
    for target in [4, 5, 2] { mission.move(to: target) }
    progress.record(mission)
    XCTAssertEqual(progress.unlocked, 1)
    XCTAssertEqual(progress.best["0"], 780)
    progress.best["0"] = 2_000
    progress.record(mission)
    XCTAssertEqual(progress.best["0"], 2_000)
    let decoded = try JSONDecoder().decode(Progress.self, from: JSONEncoder().encode(progress))
    XCTAssertEqual(decoded.unlocked, 1)
    XCTAssertEqual(decoded.totalEscapes, 2)
    XCTAssertEqual(decoded.best["0"], 2_000)
  }

  @MainActor func testPersistenceAcrossFreshStoreAndPauseGuards() throws {
    let suite = "RooftopRaccoonTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = GameStore(defaults: defaults)
    store.progress.sound = false
    store.progress.haptics = false
    store.start()
    store.act(10)
    XCTAssertEqual(store.mission?.beat, 0, "Tutorial blocks game input")
    store.finishTutorial()
    store.paused = true
    store.act(10)
    XCTAssertEqual(store.mission?.beat, 0, "Pause blocks game input")
    store.paused = false
    for target in [10, 7] { store.act(target) }
    store.act(nil)
    for target in [4, 5, 2] { store.act(target) }
    let restored = GameStore(defaults: defaults)
    XCTAssertEqual(restored.progress.best["0"], 780)
    XCTAssertEqual(restored.progress.unlocked, 1)
    XCTAssertTrue(restored.progress.tutorialSeen)
    XCTAssertFalse(restored.progress.sound)
    XCTAssertFalse(restored.progress.haptics)
    XCTAssertNil(restored.mission)
  }
}
