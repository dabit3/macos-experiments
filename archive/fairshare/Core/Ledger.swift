import Foundation

struct Traveler: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let initials: String
}

enum Category: String, Codable, CaseIterable, Sendable {
  case stay = "Stay"
  case food = "Food"
  case travel = "Travel"
  case experiences = "Experiences"

  var symbol: String {
    switch self {
    case .stay: "bed.double"
    case .food: "fork.knife"
    case .travel: "tram"
    case .experiences: "sparkles"
    }
  }
}

struct Expense: Codable, Identifiable, Equatable, Sendable {
  var id = UUID()
  var title: String
  var amount: Int
  var payer: String
  var participants: [String]
  var customShares: [String: Int]?
  var category: Category
  var date = Date()

  func shares() throws -> [String: Int] {
    guard amount > 0, amount <= Money.maximum, !participants.isEmpty,
      Set(participants).count == participants.count
    else { throw LedgerError.invalidExpense }
    if let customShares {
      guard Set(customShares.keys) == Set(participants),
        customShares.values.allSatisfy({ (0...Money.maximum).contains($0) }),
        customShares.values.reduce(0, +) == amount
      else { throw LedgerError.invalidSplit }
      return customShares
    }
    let ordered = participants.sorted()
    let quotient = amount / ordered.count
    let remainder = amount % ordered.count
    return Dictionary(
      uniqueKeysWithValues: ordered.enumerated().map {
        ($0.element, quotient + ($0.offset < remainder ? 1 : 0))
      })
  }
}

struct Transfer: Codable, Identifiable, Equatable, Sendable {
  var id = UUID()
  let from: String
  let to: String
  let amount: Int
  var date = Date()
}

enum LedgerError: Error, LocalizedError {
  case invalidAmount, invalidExpense, invalidSplit, unknownTraveler, invalidTransfer, invalidFile

  var errorDescription: String? {
    switch self {
    case .invalidAmount: "Enter an amount from €0.01 to €999,999.99, with at most two decimals."
    case .invalidExpense: "Add a title, an amount and at least one traveler."
    case .invalidSplit: "Custom shares must be nonnegative and add up to the expense total."
    case .unknownTraveler: "This entry refers to a traveler who is not on the trip."
    case .invalidTransfer:
      "This payment must go from someone who owes to someone owed, within their balances."
    case .invalidFile: "The saved trip could not be read. Your file has not been overwritten."
    }
  }
}

enum Money {
  static let maximum = 99_999_999

  static func parse(_ input: String, allowZero: Bool = false) throws -> Int {
    let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: ",", with: ".")
    let pieces = value.split(separator: ".", omittingEmptySubsequences: false)
    guard (1...2).contains(pieces.count),
      !pieces[0].isEmpty,
      pieces[0].allSatisfy({ $0.isASCII && $0.isNumber }),
      pieces[0].count <= 6,
      pieces.count == 1
        || (pieces[1].count <= 2 && pieces[1].allSatisfy({ $0.isASCII && $0.isNumber })),
      let whole = Int(pieces[0])
    else { throw LedgerError.invalidAmount }
    let cents =
      pieces.count == 2 ? Int(pieces[1].padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0 : 0
    let amount = whole * 100 + cents
    guard (allowZero ? 0 : 1)...maximum ~= amount else { throw LedgerError.invalidAmount }
    return amount
  }

  static func edit(_ cents: Int) -> String {
    "\(cents / 100)." + String(format: "%02d", abs(cents % 100))
  }

  static func format(_ cents: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "EUR"
    formatter.locale = Locale(identifier: "en_IE")
    return formatter.string(from: NSDecimalNumber(value: cents).dividing(by: 100)) ?? "€0.00"
  }
}

struct Ledger: Codable, Equatable, Sendable {
  var version = 1
  var travelers: [Traveler]
  var expenses: [Expense]
  var transfers: [Transfer]

  var total: Int { expenses.reduce(0) { $0 + $1.amount } }

  func validate() throws {
    let ids = Set(travelers.map(\.id))
    guard version == 1, travelers.count == 4, ids.count == travelers.count,
      expenses.count <= 10_000, transfers.count <= 10_000
    else { throw LedgerError.invalidFile }
    for expense in expenses {
      guard !expense.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        expense.title.count <= 80
      else { throw LedgerError.invalidExpense }
      guard ids.contains(expense.payer), Set(expense.participants).isSubset(of: ids)
      else { throw LedgerError.unknownTraveler }
      _ = try expense.shares()
    }
    for transfer in transfers {
      guard ids.contains(transfer.from), ids.contains(transfer.to),
        transfer.from != transfer.to, (1...(Money.maximum * 10_000)).contains(transfer.amount)
      else { throw LedgerError.invalidTransfer }
    }
  }

  func balances() throws -> [String: Int] {
    try validate()
    var result = Dictionary(uniqueKeysWithValues: travelers.map { ($0.id, 0) })
    for expense in expenses {
      result[expense.payer, default: 0] += expense.amount
      for (person, amount) in try expense.shares() {
        result[person, default: 0] -= amount
      }
    }
    for transfer in transfers {
      result[transfer.from, default: 0] += transfer.amount
      result[transfer.to, default: 0] -= transfer.amount
    }
    return result
  }

  func settlementPlan() throws -> [Transfer] {
    let balances = try balances()
    var debtors: [(id: String, amount: Int)] = []
    var creditors: [(id: String, amount: Int)] = []
    for (id, amount) in balances {
      if amount < 0 { debtors.append((id: id, amount: -amount)) }
      if amount > 0 { creditors.append((id: id, amount: amount)) }
    }
    func descending(_ lhs: (id: String, amount: Int), _ rhs: (id: String, amount: Int)) -> Bool {
      if lhs.amount == rhs.amount { return lhs.id < rhs.id }
      return lhs.amount > rhs.amount
    }
    debtors.sort(by: descending)
    creditors.sort(by: descending)
    var result: [Transfer] = []
    var d = 0
    var c = 0
    while d < debtors.count && c < creditors.count {
      let amount = min(debtors[d].amount, creditors[c].amount)
      result.append(Transfer(from: debtors[d].id, to: creditors[c].id, amount: amount))
      debtors[d].amount -= amount
      creditors[c].amount -= amount
      if debtors[d].amount == 0 { d += 1 }
      if creditors[c].amount == 0 { c += 1 }
    }
    return result
  }

  mutating func record(_ transfer: Transfer) throws {
    let balances = try balances()
    guard transfer.from != transfer.to, transfer.amount > 0,
      transfer.amount <= Money.maximum * 10_000,
      transfer.amount <= -(balances[transfer.from] ?? 0),
      transfer.amount <= (balances[transfer.to] ?? 0)
    else { throw LedgerError.invalidTransfer }
    transfers.append(transfer)
  }

  func name(_ id: String) -> String { travelers.first { $0.id == id }?.name ?? "Traveler" }

  func csv() throws -> String {
    try validate()
    func cell(_ value: String) -> String {
      let safe =
        ["=", "+", "-", "@", "\t", "\r"].contains(String(value.prefix(1))) ? "'" + value : value
      return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    var lines = ["type,title,from,to,amount_eur,category,shares_eur"]
    for expense in expenses {
      let shares = try expense.shares().sorted { $0.key < $1.key }
        .map { "\(name($0.key)): \(Money.edit($0.value))" }.joined(separator: "; ")
      lines.append(
        [
          "expense", expense.title, name(expense.payer), "", Money.edit(expense.amount),
          expense.category.rawValue, shares,
        ].map(cell).joined(separator: ","))
    }
    for transfer in transfers {
      lines.append(
        [
          "settlement", "Recorded payment", name(transfer.from), name(transfer.to),
          Money.edit(transfer.amount), "", "",
        ].map(cell).joined(separator: ","))
    }
    return lines.joined(separator: "\r\n") + "\r\n"
  }

  static var sample: Ledger {
    let people = [
      Traveler(id: "alex", name: "Alex", initials: "AL"),
      Traveler(id: "jamie", name: "Jamie", initials: "JA"),
      Traveler(id: "sam", name: "Sam", initials: "SA"),
      Traveler(id: "you", name: "You", initials: "YO"),
    ]
    let all = people.map(\.id)
    let date = Date(timeIntervalSince1970: 1_789_041_600)
    return Ledger(
      travelers: people,
      expenses: [
        Expense(
          title: "Alfama apartment", amount: 64000, payer: "you", participants: all,
          category: .stay, date: date),
        Expense(
          title: "Dinner at Prado", amount: 16850, payer: "alex", participants: all,
          category: .food, date: date.addingTimeInterval(3600)),
        Expense(
          title: "Tram 28 day passes", amount: 2800, payer: "jamie", participants: all,
          category: .travel, date: date.addingTimeInterval(7200)),
        Expense(
          title: "Pastéis & coffee", amount: 2450, payer: "sam", participants: all, category: .food,
          date: date.addingTimeInterval(10800)),
        Expense(
          title: "Sunset on the Tagus", amount: 12000, payer: "alex", participants: all,
          category: .experiences, date: date.addingTimeInterval(14400)),
      ],
      transfers: [])
  }
}

struct LedgerFile {
  let url: URL

  func load() throws -> Ledger {
    let ledger = try JSONDecoder().decode(Ledger.self, from: Data(contentsOf: url))
    try ledger.validate()
    return ledger
  }

  func save(_ ledger: Ledger) throws {
    try ledger.validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(ledger).write(to: url, options: .atomic)
  }
}
