import XCTest

@testable import FabTycoonCore

final class GameTests: XCTestCase {
  func testFormatting() {
    XCTAssertEqual(NumberFormat.format(0), "0")
    XCTAssertEqual(NumberFormat.format(999), "999")
    XCTAssertEqual(NumberFormat.format(1000), "1.00K")
    XCTAssertEqual(NumberFormat.format(1_234_000), "1.23M")
    XCTAssertEqual(NumberFormat.format(4.56e12), "4.56T")
    XCTAssertTrue(NumberFormat.format(1e36).contains("e"))
    XCTAssertEqual(NumberFormat.format(-1), "0")
  }
  func testBuildingCostGrowthAndPurchase() {
    var engine = GameEngine()
    engine.state.cash = 100
    XCTAssertEqual(engine.cost(of: .garageBench), 15, accuracy: 0.001)
    XCTAssertTrue(engine.buy(.garageBench))
    XCTAssertEqual(engine.state.cash, 85, accuracy: 0.001)
    XCTAssertEqual(engine.cost(of: .garageBench), 17.25, accuracy: 0.001)
    XCTAssertFalse(engine.buy(.orbitalFoundry))
  }
  func testTapAndProduction() {
    var engine = GameEngine()
    engine.state.cash = 100
    let tap = engine.tap()
    XCTAssertEqual(tap.cash, 1, accuracy: 0.001)
    XCTAssertEqual(engine.state.taps, 1)
    engine.state.cash = 100
    XCTAssertTrue(engine.buy(.fabLine))
    engine.state.gpusShipped = 0
    let result = engine.tick(dt: 10)
    XCTAssertEqual(engine.state.gpusShipped, 10, accuracy: 0.001)
    XCTAssertEqual(engine.state.cash, 10, accuracy: 0.001)
    XCTAssertTrue(result.newlyUnlocked.contains { $0.id == "hundred-gpus" } == false)
  }
  func testNodesAIAndPrestige() {
    var engine = GameEngine()
    engine.state.researchPoints = 50
    XCTAssertTrue(engine.advanceNode())
    XCTAssertEqual(engine.state.node, .n16)
    engine.state.gpusShipped = 1_000_000
    let tick = engine.tick(dt: 1)
    XCTAssertTrue(tick.aiWaveJustTriggered)
    XCTAssertEqual(engine.pricePerGPU, 10, accuracy: 0.001)
    engine.state.lifetimeCash = 1e9
    XCTAssertTrue(engine.canPrestige)
    XCTAssertTrue(engine.prestige())
    XCTAssertEqual(engine.state.cash, 0)
    XCTAssertEqual(engine.state.node, .n28)
    XCTAssertEqual(engine.state.generation, 1)
  }
  func testOfflineAndAchievements() {
    var engine = GameEngine()
    engine.state.lastSaved = Date(timeIntervalSinceNow: -10 * 3600)
    let report = engine.applyOffline(now: Date())
    XCTAssertNotNil(report)
    XCTAssertEqual(report!.elapsed, 8 * 3600, accuracy: 0.1)
    XCTAssertEqual(report!.cash, 0, accuracy: 0.1)
    let first = engine.tap()
    XCTAssertEqual(first.cash, 1, accuracy: 0.001)
    let achievements = engine.tick(dt: 0)
    XCTAssertTrue(achievements.newlyUnlocked.contains { $0.id == "first-tap" })
    XCTAssertFalse(engine.tick(dt: 0).newlyUnlocked.contains { $0.id == "first-tap" })
  }
  func testStockHistoryCodableAndDeterminism() throws {
    var a = GameEngine()
    var b = GameEngine()
    a.state.cash = 100
    b.state.cash = 100
    XCTAssertTrue(a.buy(.fabLine))
    XCTAssertTrue(b.buy(.fabLine))
    for _ in 0..<500 {
      _ = a.tick(dt: 0.5)
      _ = b.tick(dt: 0.5)
    }
    XCTAssertEqual(a.state.stockHistory.count, 240)
    XCTAssertEqual(a.state.stockHistory, b.state.stockHistory)
    let data = try JSONEncoder().encode(a.state)
    XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: data), a.state)
  }

  func testBatchCostMatchesManualSum() {
    var engine = GameEngine()
    engine.state.cash = 200_000_000
    XCTAssertTrue(engine.buy(.garageBench))
    let manual = (1..<4).reduce(0.0) {
      $0 + BuildingKind.garageBench.baseCost * pow(1.15, Double($1))
    }
    XCTAssertEqual(engine.cost(of: .garageBench, count: 3), manual, accuracy: 0.001)
    XCTAssertEqual(engine.affordableCount(of: .garageBench), 100)
  }

  func testGlobalUpgradeEffect() {
    var engine = GameEngine()
    engine.state.cash = 100_000
    XCTAssertTrue(engine.buy(.fabLine))
    let base = engine.gpusPerSecond
    XCTAssertTrue(engine.buyUpgrade(id: "cuda-cores"))
    XCTAssertEqual(engine.gpusPerSecond, base * 1.5, accuracy: 0.001)
  }

  func testTapUpgradeEffect() {
    var engine = GameEngine()
    engine.state.cash = 1_000
    let base = engine.tapValueGPUs
    XCTAssertTrue(engine.buyUpgrade(id: "thermal-paste"))
    XCTAssertEqual(engine.tapValueGPUs, base * 2, accuracy: 0.001)
  }

  func testPriceUpgradeEffect() {
    var engine = GameEngine()
    engine.state.cash = 6_000_000
    XCTAssertTrue(engine.buyUpgrade(id: "founders"))
    XCTAssertEqual(engine.pricePerGPU, 1.5, accuracy: 0.001)
  }

  func testUpgradeFailsWhenPoorOrAlreadyOwned() {
    var engine = GameEngine()
    XCTAssertFalse(engine.buyUpgrade(id: "thermal-paste"))
    engine.state.cash = 100
    XCTAssertTrue(engine.buyUpgrade(id: "thermal-paste"))
    XCTAssertFalse(engine.buyUpgrade(id: "thermal-paste"))
  }

  func testResearcherCostGrowthAndProduction() {
    var engine = GameEngine()
    engine.state.cash = 2_000
    XCTAssertEqual(engine.researcherCost, 500, accuracy: 0.001)
    XCTAssertTrue(engine.hireResearcher())
    XCTAssertEqual(engine.researcherCost, 625, accuracy: 0.001)
    XCTAssertTrue(engine.hireResearcher())
    XCTAssertEqual(engine.researchPerSecond, 2, accuracy: 0.001)
  }

  func testAdvanceNodeFailsWithoutResearchAndRaisesMultiplier() {
    var engine = GameEngine()
    XCTAssertFalse(engine.advanceNode())
    engine.state.researchPoints = 50
    XCTAssertTrue(engine.advanceNode())
    XCTAssertEqual(engine.state.node, .n16)
    XCTAssertEqual(engine.productionMultiplier, 2, accuracy: 0.001)
  }

  func testOfflineLessThanTenSecondsReturnsNil() {
    var engine = GameEngine()
    let now = Date()
    engine.state.lastSaved = now.addingTimeInterval(-9)
    XCTAssertNil(engine.applyOffline(now: now))
  }

  func testOfflineEarningsUseFiftyPercentEfficiencyForOneHour() {
    var engine = GameEngine()
    engine.state.cash = 100
    XCTAssertTrue(engine.buy(.fabLine))
    let now = Date()
    engine.state.lastSaved = now.addingTimeInterval(-3600)
    let report = engine.applyOffline(now: now)
    XCTAssertEqual(report!.elapsed, 3600, accuracy: 0.001)
    XCTAssertEqual(report!.cash, 1800, accuracy: 0.001)
  }

  func testEarnedArchitecturePointsMath() {
    var engine = GameEngine()
    engine.state.lifetimeCash = 4e9
    XCTAssertEqual(engine.earnedArchitecturePoints, 2)
    engine.state.architecturePoints = 2
    XCTAssertEqual(engine.earnedArchitecturePoints, 0)
  }

  func testPrestigeKeepsAchievementsLifetimeAndSettings() {
    var engine = GameEngine()
    engine.state.lifetimeCash = 1e9
    engine.state.cash = 100
    engine.state.buildings = [.fabLine: 1]
    engine.state.purchasedUpgrades = ["thermal-paste"]
    engine.state.researchers = 2
    engine.state.researchPoints = 100
    engine.state.unlockedAchievements = ["first-tap"]
    engine.state.soundEnabled = false
    engine.state.hapticsEnabled = false
    XCTAssertTrue(engine.prestige())
    XCTAssertEqual(engine.state.lifetimeCash, 1e9)
    XCTAssertEqual(engine.state.unlockedAchievements, ["first-tap"])
    XCTAssertFalse(engine.state.soundEnabled)
    XCTAssertFalse(engine.state.hapticsEnabled)
    XCTAssertTrue(engine.state.buildings.isEmpty)
    XCTAssertTrue(engine.state.purchasedUpgrades.isEmpty)
    XCTAssertEqual(engine.state.researchers, 0)
    XCTAssertEqual(engine.state.researchPoints, 0, accuracy: 0.001)
  }
}
