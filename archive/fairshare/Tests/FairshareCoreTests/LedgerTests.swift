import Foundation
import XCTest

@testable import FairshareCore

final class LedgerTests: XCTestCase {
  func testMoneyParsingUsesMinorUnits() throws {
    XCTAssertEqual(try Money.parse("123.45"), 12345)
    XCTAssertEqual(try Money.parse("0,01"), 1)
    XCTAssertEqual(try Money.parse(" 24.5 "), 2450)
    for invalid in ["", "-1", "NaN", "1.001", "1e5", "1,000.00", "0", "1000000", "."] {
      XCTAssertThrowsError(try Money.parse(invalid))
    }
    XCTAssertEqual(try Money.parse("0", allowZero: true), 0)
  }

  func testExportAmountDoesNotTruncateLargeAggregatePayments() {
    XCTAssertEqual(Money.edit(Money.maximum * 10_000), "9999999900.00")
    XCTAssertEqual(Money.edit(1), "0.01")
  }

  func testEqualSplitConservesEveryCentAndIsOrderIndependent() throws {
    var expense = Ledger.sample.expenses[0]
    expense.amount = 100
    expense.participants = ["you", "alex", "sam"]
    XCTAssertEqual(try expense.shares(), ["alex": 34, "sam": 33, "you": 33])
    expense.participants.reverse()
    XCTAssertEqual(try expense.shares(), ["alex": 34, "sam": 33, "you": 33])
  }

  func testExclusionAndPayerEdit() throws {
    var ledger = Ledger.sample
    ledger.expenses = [
      Expense(
        title: "Lunch", amount: 1000, payer: "you", participants: ["alex", "sam", "you"],
        category: .food)
    ]
    XCTAssertEqual(try ledger.balances()["jamie"], 0)
    XCTAssertEqual(try ledger.balances()["you"], 667)
    ledger.expenses[0].payer = "alex"
    XCTAssertEqual(try ledger.balances()["you"], -333)
    XCTAssertEqual(try ledger.balances()["alex"], 666)
    XCTAssertEqual(try ledger.balances().values.reduce(0, +), 0)
  }

  func testCustomSplitValidation() throws {
    var expense = Ledger.sample.expenses[0]
    expense.amount = 1000
    expense.customShares = ["alex": 100, "jamie": 200, "sam": 300, "you": 400]
    XCTAssertEqual(try expense.shares().values.reduce(0, +), 1000)
    expense.customShares?["you"] = 401
    XCTAssertThrowsError(try expense.shares())
    expense.customShares?["you"] = -1
    XCTAssertThrowsError(try expense.shares())
    expense.customShares = ["alex": 1000]
    XCTAssertThrowsError(try expense.shares())
  }

  func testBundledBalancesAndCompleteSettlement() throws {
    var ledger = Ledger.sample
    XCTAssertEqual(ledger.total, 98100)
    XCTAssertEqual(
      try ledger.balances(), ["alex": 4324, "jamie": -21726, "sam": -22074, "you": 39476])
    let plan = try ledger.settlementPlan()
    XCTAssertLessThanOrEqual(plan.count, 3)
    for transfer in plan { try ledger.record(transfer) }
    XCTAssertTrue(try ledger.balances().values.allSatisfy { $0 == 0 })
    XCTAssertTrue(try ledger.settlementPlan().isEmpty)
    XCTAssertEqual(ledger.total, 98100)
  }

  func testInvalidAndDuplicateSettlementRejected() throws {
    var ledger = Ledger.sample
    XCTAssertThrowsError(try ledger.record(Transfer(from: "you", to: "sam", amount: 100)))
    XCTAssertThrowsError(try ledger.record(Transfer(from: "sam", to: "you", amount: 999999)))
    let first = try XCTUnwrap(ledger.settlementPlan().first)
    try ledger.record(first)
    XCTAssertThrowsError(try ledger.record(first))
  }

  func testSettlementMayExceedSingleExpenseEntryLimit() throws {
    var ledger = Ledger.sample
    ledger.expenses = (0..<3).map { index in
      Expense(
        title: "Large expense \(index)", amount: Money.maximum, payer: "you",
        participants: ["sam"], category: .stay)
    }
    let plan = try ledger.settlementPlan()
    XCTAssertEqual(plan.count, 1)
    XCTAssertEqual(plan[0].amount, Money.maximum * 3)
    try ledger.record(plan[0])
    XCTAssertTrue(try ledger.balances().values.allSatisfy { $0 == 0 })
  }

  func testConservationAcrossManyAmountsAndParticipants() throws {
    for amount in stride(from: 1, through: 3000, by: 7) {
      for count in 1...4 {
        var ledger = Ledger.sample
        ledger.expenses = [
          Expense(
            title: "Generated", amount: amount, payer: "you",
            participants: Array(ledger.travelers.prefix(count).map(\.id)), category: .food)
        ]
        XCTAssertEqual(try ledger.expenses[0].shares().values.reduce(0, +), amount)
        XCTAssertEqual(try ledger.balances().values.reduce(0, +), 0)
        for transfer in try ledger.settlementPlan() { try ledger.record(transfer) }
        XCTAssertTrue(try ledger.balances().values.allSatisfy { $0 == 0 })
      }
    }
  }

  func testPersistenceRoundTripAndCorruption() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = LedgerFile(url: directory.appendingPathComponent("trip.json"))
    var ledger = Ledger.sample
    try ledger.record(XCTUnwrap(ledger.settlementPlan().first))
    try file.save(ledger)
    XCTAssertEqual(try file.load(), ledger)
    try Data("invalid".utf8).write(to: file.url)
    XCTAssertThrowsError(try file.load())
  }

  func testInvalidTravelerAndDuplicateParticipants() throws {
    var ledger = Ledger.sample
    ledger.expenses[0].payer = "missing"
    XCTAssertThrowsError(try ledger.validate())
    ledger = Ledger.sample
    ledger.expenses[0].participants = ["you", "you"]
    XCTAssertThrowsError(try ledger.validate())
  }

  func testCSVQuotesAndFormulaEscaping() throws {
    var ledger = Ledger.sample
    ledger.expenses[0].title = "=SUM(\"danger\")"
    let csv = try ledger.csv()
    XCTAssertTrue(csv.contains("\"'=SUM(\"\"danger\"\")\""))
    XCTAssertTrue(csv.contains("640.00"))
    XCTAssertTrue(csv.contains("Alex: 160.00"))
  }
}
