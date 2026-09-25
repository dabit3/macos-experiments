import XCTest

@testable import MoonMarket

final class MarketTests: XCTestCase {
  func testDeterministicMarketAndUTCDaily() {
    XCTAssertEqual(
      MarketDay.make(seed: 20_260_912, round: 4), MarketDay.make(seed: 20_260_912, round: 4))
    XCTAssertNotEqual(
      MarketDay.make(seed: 20_260_912, round: 4), MarketDay.make(seed: 20_260_912, round: 5))
    let date = ISO8601DateFormatter().date(from: "2026-09-12T23:59:59Z")!
    XCTAssertEqual(Run.dailySeed(date: date), 20_260_912)
    XCTAssertEqual(Run.dailySeed(date: date.addingTimeInterval(1)), 20_260_913)
  }

  func testOrdersRespectBudgetCapacityAndInvalidInput() {
    var run = Run(seed: 42, daily: false)
    for _ in 0..<100 { run.adjust(0, by: 1) }
    XCTAssertLessThanOrEqual(run.orderCost, run.cash - Run.rent)
    XCTAssertLessThanOrEqual(run.occupied, Run.capacity)
    XCTAssertFalse(run.adjust(-1, by: 1))
    XCTAssertFalse(run.adjust(3, by: 1))
    for _ in 0..<100 { run.adjust(0, by: -1) }
    XCTAssertEqual(run.order, [0, 0, 0])
    run.cash = 1000
    for _ in 0..<100 { run.adjust(1, by: 1) }
    XCTAssertEqual(run.occupied, Run.capacity)
  }

  func testSettlementMatchesPreviewAndRetainsUnsoldStock() {
    var run = Run(seed: 7, daily: false)
    run.cash = 500
    for _ in 0..<10 { run.adjust(0, by: 1) }
    let forecast = run.projectedCash
    let sold = run.expectedSold[0]
    run.openMarket()
    XCTAssertEqual(run.cash, forecast)
    XCTAssertEqual(run.inventory[0], 10 - sold)
    XCTAssertEqual(run.orderCost, 0)
    let settled = run
    run.openMarket()
    XCTAssertEqual(run, settled)
    XCTAssertFalse(run.adjust(0, by: 1))
    run.advance()
    XCTAssertEqual(run.round, 2)
  }

  func testEightRoundsAndFailureCannotCreateNegativeBalance() {
    var run = Run(seed: 42, daily: false)
    run.cash = 2
    for _ in 0..<8 {
      run.openMarket()
      run.advance()
    }
    XCTAssertEqual(run.cash, 0)
    XCTAssertTrue(run.finished)
    XCTAssertFalse(run.won)
    XCTAssertEqual(run.history.count, 8)
    let finished = run
    run.openMarket()
    run.advance()
    run.clearInventory()
    XCTAssertEqual(run, finished)
  }

  func testGreedyDemandStrategyCanWinAcrossSeeds() {
    for seed in 1...60 {
      var run = Run(seed: UInt64(seed), daily: false)
      for _ in 0..<8 {
        let priorities = (0..<3).sorted {
          run.market.quotes[$0].sell - run.market.quotes[$0].buy
            > run.market.quotes[$1].sell - run.market.quotes[$1].buy
        }
        for index in priorities {
          while run.inventory[index] + run.order[index] < run.market.quotes[index].demand
            && run.canAdd(index)
          {
            run.adjust(index, by: 1)
          }
        }
        run.openMarket()
        run.advance()
        XCTAssertGreaterThanOrEqual(run.cash, 0)
      }
      XCTAssertTrue(run.won, "Seed \(seed) ended with \(run.cash)")
    }
  }

  func testClearanceAndFinalLiquidation() {
    var run = Run(seed: 12, daily: false)
    run.inventory = [2, 3, 1]
    let value = run.salvageValue
    run.clearInventory()
    XCTAssertEqual(run.cash, Run.openingCash + value)
    XCTAssertEqual(run.inventory, [0, 0, 0])
    run.round = 8
    run.inventory = [12, 0, 0]
    run.openMarket()
    let finalCash = run.cash + run.salvageValue
    run.advance()
    XCTAssertEqual(run.cash, finalCash)
    XCTAssertTrue(run.finished)
  }

  @MainActor
  func testRelaunchRestoresPendingSettlementAndAwardsOnce() {
    let suite = "moon-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = MarketStore(defaults: defaults)
    store.start(daily: true, seed: 20_260_912)
    store.change {
      $0.adjust(0, by: 1)
      $0.openMarket()
    }
    let restored = MarketStore(defaults: defaults)
    XCTAssertEqual(restored.run, store.run)
    for _ in 0..<8 {
      restored.change {
        $0.openMarket()
        $0.advance()
      }
    }
    XCTAssertTrue(restored.run.finished)
    XCTAssertEqual(restored.archive.completed, 1)
    restored.change { $0.advance() }
    XCTAssertEqual(restored.archive.completed, 1)
    XCTAssertEqual(MarketStore(defaults: defaults).archive.best, restored.run.cash)
  }
}
