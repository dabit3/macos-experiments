import XCTest

@testable import NectarDash

final class GardenRulesTests: XCTestCase {
  func testSixBloomSequenceCreatesWaveAndBanksToWin() {
    var game = GardenRules(mode: .meadow(1))
    for index in [0, 1, 2, 3, 4, 5] {
      let event = game.fly(along: [game.bee, game.flowers[index].position])
      XCTAssertEqual(event, index == 5 ? .blossomWave : .bloom)
    }
    XCTAssertEqual(game.pollen, 6)
    XCTAssertEqual(game.carriedScore, 120)
    XCTAssertEqual(game.score, 0, "Unbanked honey must not count toward the goal")
    XCTAssertNil(game.end)
    XCTAssertEqual(game.fly(along: [game.bee, .hive]), .bank(120))
    XCTAssertEqual(game.end, .blooming)
    XCTAssertEqual(game.score, 120)
    XCTAssertEqual(game.longestChain, 6)
  }

  func testSmallerBankResetsSequenceButKeepsScore() {
    var game = GardenRules(mode: .meadow(1))
    _ = game.fly(along: [game.bee, game.flowers[0].position])
    _ = game.fly(along: [game.bee, game.flowers[1].position])
    XCTAssertEqual(game.fly(along: [game.bee, .hive]), .bank(20))
    XCTAssertEqual(game.expected, .gold)
    XCTAssertEqual(game.pollen, 0)
    XCTAssertEqual(game.carriedScore, 0)
    XCTAssertNil(game.end)
  }

  func testWrongColorPenalizesTimeWithoutAwardingPollen() {
    var game = GardenRules(mode: .meadow(1))
    let initial = game.timeRemaining
    XCTAssertEqual(game.fly(along: [game.bee, game.flowers[1].position]), .wrongColor)
    XCTAssertEqual(game.timeRemaining, initial - 3)
    XCTAssertEqual(game.pollen, 0)
    XCTAssertEqual(game.expected, .gold)
  }

  func testWebChecksWholeRouteNotOnlyDestinationAndDropsCargo() {
    var game = GardenRules(mode: .meadow(1))
    _ = game.fly(along: [game.bee, game.flowers[0].position])
    let web = game.hazards[0].position
    XCTAssertEqual(game.fly(along: [game.bee, web, game.flowers[1].position]), .web)
    XCTAssertEqual(game.hearts, 2)
    XCTAssertEqual(game.bee, .hive)
    XCTAssertEqual(game.pollen, 0)
    XCTAssertEqual(game.carriedScore, 0)
    XCTAssertEqual(game.expected, .gold)
  }

  func testCurvedDetourAvoidsWeb() {
    var game = GardenRules(mode: .meadow(1))
    game.bee = GardenPoint(x: 0.85, y: 0.7)
    let target = game.flowers[3].position
    XCTAssertTrue(GardenRules.touches(game.hazards[0], along: [game.bee, target]))
    let detour = [game.bee, GardenPoint(x: 0.64, y: 0.62), GardenPoint(x: 0.64, y: 0.38), target]
    XCTAssertFalse(GardenRules.touches(game.hazards[0], along: detour))
    XCTAssertEqual(game.fly(along: detour), .bloom)
  }

  func testThreeWebHitsEndRoundAndFurtherFlightsAreIgnored() {
    var game = GardenRules(mode: .meadow(1))
    for _ in 0..<3 {
      _ = game.fly(along: [game.bee, game.hazards[0].position])
    }
    XCTAssertEqual(game.end, .tangled)
    XCTAssertEqual(game.hearts, 0)
    XCTAssertEqual(game.fly(along: [game.bee, game.flowers[0].position]), .missed)
    XCTAssertEqual(game.score, 0)
  }

  func testWindLullsAreDeterministicAndGustConsumesFiveSeconds() {
    var game = GardenRules(mode: .meadow(2))
    let wind = game.hazards[1].position
    XCTAssertTrue(game.windActive)
    XCTAssertEqual(game.fly(along: [game.bee, wind]), .wind)
    XCTAssertEqual(game.timeRemaining, 90)
    XCTAssertFalse(game.windActive)
    game.tick(4)
    XCTAssertTrue(game.windActive)
  }

  func testCooldownAndTimeoutClamp() {
    var game = GardenRules(mode: .meadow(1))
    _ = game.fly(along: [game.bee, game.flowers[0].position])
    XCTAssertEqual(game.fly(along: [game.bee, game.flowers[0].position]), .resting)
    game.tick(9)
    XCTAssertEqual(game.flowers[0].cooldown, 0)
    game.tick(1_000)
    XCTAssertEqual(game.timeRemaining, 0)
    XCTAssertEqual(game.end, .timeout)
    XCTAssertEqual(game.score, 0)
  }

  func testCapacityCannotBeExceeded() {
    var game = GardenRules(mode: .meadow(1))
    for index in [0, 1, 2, 3, 4, 5] {
      _ = game.fly(along: [game.bee, game.flowers[index].position])
    }
    XCTAssertEqual(game.fly(along: [game.bee, game.flowers[6].position]), .full)
    XCTAssertEqual(game.pollen, 6)
    XCTAssertEqual(game.carriedScore, 120)
  }

  func testDailySeedStableWithinUTCDayAndChangesNextDay() {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let first = GardenMode.daily(on: date)
    let sameDay = GardenMode.daily(on: date.addingTimeInterval(60))
    let nextDay = GardenMode.daily(on: date.addingTimeInterval(86_400))
    XCTAssertEqual(first, sameDay)
    XCTAssertNotEqual(first.dailySeed, nextDay.dailySeed)
    XCTAssertEqual(
      GardenRules(mode: first).flowers.map(\.position),
      GardenRules(mode: sameDay).flowers.map(\.position))
    XCTAssertNotEqual(
      GardenRules(mode: first).flowers.map(\.position),
      GardenRules(mode: nextDay).flowers.map(\.position))
    var game = GardenRules(mode: first)
    game.tick(90)
    XCTAssertEqual(game.end, .dailyComplete)
  }

  func testGeometryHandlesDegenerateSegmentsAndClampsProjection() {
    let point = GardenPoint(x: 1, y: 1)
    let a = GardenPoint(x: 0, y: 0)
    XCTAssertEqual(GardenRules.distance(from: point, toSegment: a, a), sqrt(2), accuracy: 0.0001)
    let b = GardenPoint(x: 0.5, y: 0)
    XCTAssertEqual(GardenRules.distance(from: point, toSegment: a, b), sqrt(1.25), accuracy: 0.0001)
  }

  func testProgressUnlocksOnlyOnWinAndRoundTripsThroughStorage() throws {
    let suite = "nectar.tests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    var progress = GardenProgress()
    var game = GardenRules(mode: .meadow(1))
    game.score = 30
    game.end = .timeout
    progress.record(game)
    XCTAssertEqual(progress.unlockedStage, 1)
    game.score = 120
    game.end = .blooming
    progress.record(game)
    progress.record(game)
    XCTAssertEqual(progress.unlockedStage, 2)
    XCTAssertEqual(progress.completed, [1])
    XCTAssertEqual(progress.bestScore, 120)
    progress.save(to: defaults)
    XCTAssertEqual(GardenProgress.load(from: defaults), progress)
  }
}
