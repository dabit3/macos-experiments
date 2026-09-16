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
}
