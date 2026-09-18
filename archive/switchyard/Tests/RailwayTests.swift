import XCTest

@testable import Switchyard

final class RailwayTests: XCTestCase {
  func testAppIconIsIncludedInHostBundle() {
    XCTAssertNotNil(Bundle.main.url(forResource: "Assets", withExtension: "car"))
    XCTAssertNotNil(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons"))
  }

  func testSignalHoldsAndReleases() {
    let railway = Railway(scenario: Scenario.all[0])
    railway.westOpen = false
    railway.startPause()
    railway.advance(by: 8)
    XCTAssertEqual(railway.trains.count, 1)
    XCTAssertEqual(railway.trains[0].to, .westSignal)
    XCTAssertEqual(railway.trains[0].distance, railway.trains[0].length, accuracy: 0.001)
    railway.westOpen = true
    railway.advance(by: 0.5)
    XCTAssertEqual(railway.trains[0].to, .merge)
  }

  func testCollisionAtMerge() {
    let railway = Railway(scenario: Scenario.all[1])
    railway.eastOpen = true
    railway.startPause()
    railway.advance(by: 10)
    guard case .lost(let reason) = railway.state else { return XCTFail("Expected collision") }
    XCTAssertTrue(reason.contains("merge"))
    XCTAssertEqual(railway.delivered, 0)
  }

  func testWrongStationFails() {
    let railway = Railway(scenario: Scenario.all[0])
    railway.roseRoute = false
    railway.startPause()
    railway.advance(by: 16)
    guard case .lost(let reason) = railway.state else { return XCTFail("Expected wrong station") }
    XCTAssertTrue(reason.contains("Lakeview"))
  }

  func testPauseFreezesSimulationAndSpeedDoublesTime() {
    let railway = Railway(scenario: Scenario.all[0])
    railway.startPause()
    railway.advance(by: 1)
    railway.startPause()
    railway.advance(by: 10)
    XCTAssertEqual(railway.elapsed, 1, accuracy: 0.0001)
    railway.startPause()
    railway.speed = 2
    railway.advance(by: 1)
    XCTAssertEqual(railway.elapsed, 3, accuracy: 0.0001)
  }

  func testChangingSwitchAfterJunctionPreservesCommittedDestination() {
    let railway = Railway(scenario: Scenario.all[0])
    railway.startPause()
    railway.advance(by: 9)
    XCTAssertEqual(railway.trains.first?.committedDestination, .coral)
    railway.roseRoute = false
    railway.sunRoute = true
    railway.advance(by: 6)
    XCTAssertEqual(railway.delivered, 1)
    XCTAssertEqual(railway.lastDelivery, .coral)
    XCTAssertEqual(railway.state, .running)
  }

  func testTimeStepConsistency() {
    let whole = Railway(scenario: Scenario.all[0])
    let chunks = Railway(scenario: Scenario.all[0])
    whole.startPause()
    chunks.startPause()
    whole.advance(by: 6)
    for _ in 0..<240 { chunks.advance(by: 0.025) }
    XCTAssertEqual(whole.elapsed, chunks.elapsed, accuracy: 0.0001)
    XCTAssertEqual(whole.trains[0].point.x, chunks.trains[0].point.x, accuracy: 0.0001)
    XCTAssertEqual(whole.trains[0].point.y, chunks.trains[0].point.y, accuracy: 0.0001)
  }

  func testEveryAuthoredScenarioCanBeCompleted() {
    for scenario in Scenario.all {
      let railway = Railway(scenario: scenario)
      railway.westOpen = false
      railway.eastOpen = false
      railway.startPause()
      for _ in 0..<24_000 {
        let active = railway.trains.filter { $0.from != .west && $0.from != .east }
        if let leader = active.first {
          railway.westOpen = false
          railway.eastOpen = false
          railway.roseRoute = leader.freight == .coral
          railway.sunRoute = leader.freight == .gold
        } else if let next = railway.trains.first {
          railway.westOpen = next.entrance == .west
          railway.eastOpen = next.entrance == .east
          railway.roseRoute = next.freight == .coral
          railway.sunRoute = next.freight == .gold
        }
        railway.advance(by: Railway.step)
        if !railway.isActive { break }
      }
      XCTAssertEqual(railway.state, .won, "Scenario \(scenario.id): \(railway.state)")
      XCTAssertEqual(railway.delivered, scenario.target)
      XCTAssertEqual(railway.score, scenario.target * 100)
    }
  }

  func testCompletedProgressPersistsAndResetClearsIt() throws {
    let name = "SwitchyardTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let book = DispatchBook(defaults: defaults)
    XCTAssertFalse(book.unlocked(1))
    let railway = Railway(scenario: Scenario.all[0])
    railway.delivered = 3
    book.record(railway)
    XCTAssertTrue(book.scores.isEmpty)
    railway.state = .won
    book.record(railway)
    let reloaded = DispatchBook(defaults: defaults)
    XCTAssertEqual(reloaded.scores["0"], 300)
    XCTAssertTrue(reloaded.unlocked(1))
    reloaded.reset()
    XCTAssertTrue(DispatchBook(defaults: defaults).scores.isEmpty)
  }

  func testInvalidTimeCannotCorruptState() {
    let railway = Railway(scenario: Scenario.all[0])
    railway.startPause()
    railway.advance(by: .nan)
    railway.advance(by: -.infinity)
    railway.advance(by: -1)
    XCTAssertEqual(railway.elapsed, 0)
  }
}
