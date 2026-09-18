import SwiftUI

@main
struct FairshareApp: App {
  @State private var store = TripStore()

  var body: some Scene {
    WindowGroup {
      TripView(store: store)
        .preferredColorScheme(.light)
    }
  }
}

@Observable
final class TripStore {
  private(set) var ledger: Ledger
  private(set) var previous: Ledger?
  var error: String?
  var loadFailed = false
  var notice: String?
  private let file: LedgerFile

  init() {
    let directory = URL.documentsDirectory
    file = LedgerFile(url: directory.appendingPathComponent("fairshare-trip.json"))
    if FileManager.default.fileExists(atPath: file.url.path) {
      do {
        ledger = try file.load()
      } catch {
        ledger = .sample
        loadFailed = true
        self.error = LedgerError.invalidFile.localizedDescription
      }
    } else {
      ledger = .sample
      do { try file.save(ledger) } catch { self.error = error.localizedDescription }
    }
  }

  var balances: [String: Int] { (try? ledger.balances()) ?? [:] }
  var plan: [Transfer] { (try? ledger.settlementPlan()) ?? [] }
  var yourShare: Int {
    ledger.expenses.reduce(0) { $0 + ((try? $1.shares()["you"]) ?? 0) }
  }

  @discardableResult
  func change(_ transform: (inout Ledger) throws -> Void, notice: String) -> Bool {
    guard !loadFailed else {
      error = LedgerError.invalidFile.localizedDescription
      return false
    }
    do {
      var next = ledger
      try transform(&next)
      try file.save(next)
      previous = ledger
      ledger = next
      self.notice = notice
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }

  func save(_ expense: Expense) -> Bool {
    change(
      {
        if let index = $0.expenses.firstIndex(where: { $0.id == expense.id }) {
          $0.expenses[index] = expense
        } else {
          $0.expenses.append(expense)
        }
      }, notice: "Expense saved")
  }

  func delete(_ expense: Expense) -> Bool {
    change({ $0.expenses.removeAll { $0.id == expense.id } }, notice: "Expense deleted")
  }

  func undo() {
    guard let previous else { return }
    do {
      try file.save(previous)
      ledger = previous
      self.previous = nil
      notice = "Last change undone"
    } catch { self.error = error.localizedDescription }
  }

  func reset() {
    if loadFailed {
      do {
        let backup = file.url.deletingPathExtension().appendingPathExtension(
          "unreadable-\(UUID().uuidString).json")
        try FileManager.default.copyItem(at: file.url, to: backup)
        try file.save(.sample)
        ledger = .sample
        previous = nil
        loadFailed = false
        error = nil
        notice = "Example trip restored. Original file preserved."
      } catch { self.error = error.localizedDescription }
    } else {
      _ = change({ $0 = .sample }, notice: "Example trip restored")
    }
  }

  func export() -> URL? {
    do {
      let url = URL.documentsDirectory.appendingPathComponent("Fairshare-Lisbon.csv")
      try ledger.csv().write(to: url, atomically: true, encoding: .utf8)
      return url
    } catch {
      self.error = error.localizedDescription
      return nil
    }
  }
}
