import Combine
import Foundation

enum Produce: Int, CaseIterable, Codable, Identifiable {
  case moonpear, starcap, cometroot
  var id: Int { rawValue }
  var name: String { ["Moonpear", "Starcap", "Cometroot"][rawValue] }
  var subtitle: String {
    ["Orchard of Tranquility", "Grown in starlight", "A little solar spice"][rawValue]
  }
}

struct SeededRandom {
  var state: UInt64
  mutating func next(_ upper: Int) -> Int {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Int((state >> 32) % UInt64(upper))
  }
}

struct Quote: Codable, Equatable {
  let buy: Int
  let sell: Int
  let demand: Int
}

struct MarketDay: Equatable {
  let quotes: [Quote]
  let rival: Int
  let rivalProduct: Int

  var headline: String {
    ["Pip is drawing a crowd", "Mox shares a delivery", "Ora raises her prices"][rival]
  }
  var detail: String {
    let name = Produce.allCases[rivalProduct].name
    return [
      "\(name) demand −2. The queue below already includes this.",
      "\(name) costs 3 less to buy. A good night to stock up.",
      "\(name) sells for 4 more. Her customers are coming to you.",
    ][rival]
  }

  static func make(seed: UInt64, round: Int) -> MarketDay {
    var random = SeededRandom(state: seed &+ UInt64(round) &* 7919)
    let rival = random.next(3)
    let product = random.next(3)
    let quotes = Produce.allCases.map { produce in
      let base = [7, 10, 13][produce.rawValue]
      let buy = base + random.next(5) - (rival == 1 && product == produce.rawValue ? 3 : 0)
      let sell = base + 7 + random.next(7) + (rival == 2 && product == produce.rawValue ? 4 : 0)
      let demand = max(1, 2 + random.next(5) - (rival == 0 && product == produce.rawValue ? 2 : 0))
      return Quote(buy: buy, sell: sell, demand: demand)
    }
    return MarketDay(quotes: quotes, rival: rival, rivalProduct: product)
  }
}

struct Settlement: Codable, Equatable {
  let round: Int
  let sold: [Int]
  let revenue: Int
  let cost: Int
  let rent: Int
  let cash: Int
  var customers: Int { sold.reduce(0, +) }
  var net: Int { revenue - cost - rent }
}

struct Run: Codable, Equatable {
  static let openingCash = 90
  static let rent = 5
  static let capacity = 12
  static let goal = 600
  static let legendGoal = 800
  let seed: UInt64
  let daily: Bool
  var round = 1
  var cash = openingCash
  var inventory = [0, 0, 0]
  var order = [0, 0, 0]
  var history: [Settlement] = []
  var settlement: Settlement?
  var finished = false

  var market: MarketDay { .make(seed: seed, round: round) }
  var forecast: MarketDay { .make(seed: seed, round: min(8, round + 1)) }
  var orderCost: Int { zip(order, market.quotes).reduce(0) { $0 + $1.0 * $1.1.buy } }
  var occupied: Int { inventory.reduce(0, +) + order.reduce(0, +) }
  var expectedSold: [Int] {
    Produce.allCases.map {
      min(inventory[$0.rawValue] + order[$0.rawValue], market.quotes[$0.rawValue].demand)
    }
  }
  var expectedRevenue: Int {
    zip(expectedSold, market.quotes).reduce(0) { $0 + $1.0 * $1.1.sell }
  }
  var projectedCash: Int { max(0, cash - orderCost + expectedRevenue - Self.rent) }
  var salvageValue: Int { zip(inventory, market.quotes).reduce(0) { $0 + $1.0 * ($1.1.buy / 2) } }
  var profit: Int { cash - Self.openingCash }
  var won: Bool { finished && cash >= Self.goal }
  var rank: String {
    if cash >= Self.legendGoal { return "Lunar legend" }
    if cash >= Self.goal { return "Market luminary" }
    if cash >= Self.openingCash { return "Rising merchant" }
    return "Stardust apprentice"
  }

  func canAdd(_ index: Int) -> Bool {
    guard (0..<3).contains(index), !finished, settlement == nil else { return false }
    return occupied < Self.capacity
      && orderCost + market.quotes[index].buy <= max(0, cash - Self.rent)
  }

  @discardableResult
  mutating func adjust(_ index: Int, by amount: Int) -> Bool {
    guard (0..<3).contains(index), !finished, settlement == nil else { return false }
    if amount == 1 && canAdd(index) {
      order[index] += 1
      return true
    }
    if amount == -1 && order[index] > 0 {
      order[index] -= 1
      return true
    }
    return false
  }

  mutating func clearInventory() {
    guard !finished, settlement == nil else { return }
    cash += salvageValue
    inventory = [0, 0, 0]
  }

  mutating func openMarket() {
    guard !finished, settlement == nil else { return }
    let sold = expectedSold
    let revenue = expectedRevenue
    let cost = orderCost
    let paidRent = min(Self.rent, cash - cost + revenue)
    cash = cash - cost + revenue - paidRent
    inventory = (0..<3).map { inventory[$0] + order[$0] - sold[$0] }
    order = [0, 0, 0]
    let result = Settlement(
      round: round, sold: sold, revenue: revenue, cost: cost, rent: paidRent, cash: cash)
    history.append(result)
    settlement = result
  }

  mutating func advance() {
    guard settlement != nil, !finished else { return }
    settlement = nil
    if round == 8 {
      cash += salvageValue
      inventory = [0, 0, 0]
      finished = true
    } else {
      round += 1
    }
  }

  static func dailySeed(date: Date = Date()) -> UInt64 {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return UInt64((parts.year ?? 2026) * 10_000 + (parts.month ?? 1) * 100 + (parts.day ?? 1))
  }
}

struct Archive: Codable {
  var run: Run?
  var best = 0
  var completed = 0
  var dailyBest: [String: Int] = [:]
}

@MainActor
final class MarketStore: ObservableObject {
  @Published var archive: Archive
  @Published var atHome = true
  private let defaults: UserDefaults
  private let key = "moon-market.archive.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: key),
      let saved = try? JSONDecoder().decode(Archive.self, from: data)
    {
      archive = saved
    } else {
      archive = Archive()
    }
  }

  var run: Run { archive.run ?? Run(seed: 42, daily: false) }
  func save() {
    if let data = try? JSONEncoder().encode(archive) { defaults.set(data, forKey: key) }
  }
  func start(daily: Bool, seed: UInt64? = nil) {
    archive.run = Run(
      seed: seed ?? (daily ? Run.dailySeed() : UInt64.random(in: 1...9_999_999)), daily: daily)
    atHome = false
    save()
  }
  func change(_ operation: (inout Run) -> Void) {
    guard var run = archive.run else { return }
    let wasFinished = run.finished
    operation(&run)
    archive.run = run
    if run.finished && !wasFinished {
      archive.best = max(archive.best, run.cash)
      archive.completed += 1
      if run.daily {
        let seed = String(run.seed)
        archive.dailyBest[seed] = max(archive.dailyBest[seed] ?? 0, run.cash)
      }
    }
    save()
  }
}
