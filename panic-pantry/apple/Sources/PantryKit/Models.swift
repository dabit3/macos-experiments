import Foundation

enum Ingredient: String, Codable, CaseIterable {
  case tomato, onion, mushroom, lettuce
}

enum Dish: String, Codable, CaseIterable {
  case tomatoSoup, onionSoup, mushroomSoup, gardenSalad
  var label: String {
    switch self {
    case .tomatoSoup: return "Tomato Soup"
    case .onionSoup: return "Onion Soup"
    case .mushroomSoup: return "Mushroom Soup"
    case .gardenSalad: return "Garden Salad"
    }
  }
  var ingredients: [Ingredient] {
    switch self {
    case .tomatoSoup: return [.tomato, .tomato, .tomato]
    case .onionSoup: return [.onion, .onion, .onion]
    case .mushroomSoup: return [.mushroom, .mushroom, .mushroom]
    case .gardenSalad: return [.lettuce, .tomato]
    }
  }
  var cooked: Bool { self != .gardenSalad }
}

enum Item: Codable, Equatable {
  case ingredient(Ingredient, chopped: Bool)
  case pot(contents: [Ingredient], cook: Double, burn: Double, burnt: Bool)
  case plate(contents: [Ingredient], cooked: Bool)
  case stack(count: Int, dirty: Bool)
  case extinguisher

  private enum Keys: String, CodingKey { case t, i, c, n, k, b, x, d }
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: Keys.self)
    switch try c.decode(String.self, forKey: .t) {
    case "ing":
      self = .ingredient(
        try c.decode(Ingredient.self, forKey: .i),
        chopped: try c.decodeIfPresent(Bool.self, forKey: .c) ?? false)
    case "pot":
      self = .pot(
        contents: try c.decode([Ingredient].self, forKey: .n),
        cook: try c.decode(Double.self, forKey: .k),
        burn: try c.decode(Double.self, forKey: .b),
        burnt: try c.decode(Bool.self, forKey: .x))
    case "plate":
      self = .plate(
        contents: try c.decode([Ingredient].self, forKey: .n),
        cooked: try c.decode(Bool.self, forKey: .k))
    case "stack":
      self = .stack(
        count: try c.decode(Int.self, forKey: .c),
        dirty: try c.decode(Bool.self, forKey: .d))
    case "ext": self = .extinguisher
    default:
      throw DecodingError.dataCorruptedError(forKey: .t, in: c, debugDescription: "Unknown item")
    }
  }
  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    switch self {
    case .ingredient(let ingredient, let chopped):
      try c.encode("ing", forKey: .t)
      try c.encode(ingredient, forKey: .i)
      try c.encode(chopped, forKey: .c)
    case .pot(let contents, let cook, let burn, let burnt):
      try c.encode("pot", forKey: .t)
      try c.encode(contents, forKey: .n)
      try c.encode(cook, forKey: .k)
      try c.encode(burn, forKey: .b)
      try c.encode(burnt, forKey: .x)
    case .plate(let contents, let cooked):
      try c.encode("plate", forKey: .t)
      try c.encode(contents, forKey: .n)
      try c.encode(cooked, forKey: .k)
    case .stack(let count, let dirty):
      try c.encode("stack", forKey: .t)
      try c.encode(count, forKey: .c)
      try c.encode(dirty, forKey: .d)
    case .extinguisher: try c.encode("ext", forKey: .t)
    }
  }
  var label: String {
    switch self {
    case .ingredient(let i, let chopped): return "\(chopped ? "Chopped " : "")\(i.rawValue)"
    case .pot(let contents, let cook, _, let burnt):
      return burnt ? "Burnt pot" : "Pot · \(contents.count)/3 · \(cook >= 1 ? "ready" : "cooking")"
    case .plate(let contents, let cooked):
      return contents.isEmpty ? "Empty plate" : (cooked ? "Soup" : "Salad")
    case .stack(let count, let dirty): return "\(count) \(dirty ? "dirty" : "clean") plates"
    case .extinguisher: return "Extinguisher"
    }
  }
}

struct Mover: Codable, Identifiable {
  let id: String
  let x, y: Int
  let rows: [String]
  let axis: String
  let range: Int
  let travel, dwell, phase: Double
  var width: Int { rows.first?.count ?? 0 }
  var height: Int { rows.count }
}

struct Level: Codable, Identifiable {
  let id, name, tagline, gimmick: String
  let rows: [String]
  let menu: [Dish]
  let roundSeconds: Int
  let starThresholds: [Int]
  let movers: [Mover]
  let orderInterval, orderDuration: Double
  let startingPlates: Int
  let tutorial: Bool
  let accent: UInt32
  var width: Int { rows.first?.count ?? 0 }
  var height: Int { rows.count }
  func thresholds(players: Int) -> [Int] {
    let factor = [100, 140, 170, 200][min(4, max(1, players)) - 1]
    return starThresholds.map { $0 * factor / 100 }
  }
}

enum Phase: String, Codable { case lobby, countdown, playing, overtime, finished }

enum Direction: Int, Codable {
  case up, right, down, left
  var dx: Int { self == .right ? 1 : (self == .left ? -1 : 0) }
  var dy: Int { self == .down ? 1 : (self == .up ? -1 : 0) }
}

struct Chef: Codable, Identifiable {
  let id: String
  let slot: Int
  let name: String
  let bot: Bool
  var x, y: Double
  let facing: Direction
  let held: Item?
  let dash: Double?
  let working: Bool?
  let emote: Int?
  let offline: Bool?
  enum CodingKeys: String, CodingKey {
    case id, x, y
    case slot = "s"
    case name = "n"
    case bot = "b"
    case facing = "f"
    case held = "h"
    case dash = "d"
    case working = "w"
    case emote = "e"
    case offline = "off"
  }
  static let emotes = ["Plate!", "Chop!", "Fire!", "Nice!", "Help!", "Serve!"]
}

struct Order: Codable, Identifiable {
  let id: Int
  let dish: Dish
  let remaining, duration: Double
  enum CodingKeys: String, CodingKey {
    case id
    case dish = "d"
    case remaining = "r"
    case duration = "u"
  }
  var fraction: Double { duration > 0 ? min(1, max(0, remaining / duration)) : 0 }
}

struct GameEvent: Codable {
  let kind: String
  let x, y: Int?
  let chef: String?
  let value: Int?
  let text: String?
  enum CodingKeys: String, CodingKey {
    case x, y
    case kind = "k"
    case chef = "c"
    case value = "v"
    case text = "t"
  }
}

struct TileState: Codable, Equatable {
  var item: Item?
  var progress: Double?
  var conveyor: Double?
  var fire: Double?
  enum CodingKeys: String, CodingKey {
    case item = "i"
    case progress = "p"
    case conveyor = "c"
    case fire = "f"
  }
}

struct Snapshot: Codable {
  let tick: Int
  let time: Double
  let phase: Phase
  let countdown, timeLeft, overtime: Double
  let score, combo, served, expired: Int
  let tiles: [String: TileState]
  let movers: [[TileState]]
  let offsets: [Double]
  let chefs: [Chef]
  let orders: [Order]
  let events: [GameEvent]?
}

struct Results: Codable, Equatable {
  let levelId: String
  let score, stars: Int
  let thresholds: [Int]
  let served, expired, tips, bestCombo, wrongServes, burntPots: Int
  let servedByDish: [String: Int]
  let players, tick: Int
}

struct Player: Codable, Identifiable {
  let id, name: String
  let slot: Int
  let platform: String
  let ready, connected, bot: Bool
}

struct Room: Codable {
  let code: String
  let seed: Int
  let speed: Double
  let level: String
  let hostId: String?
  let phase: Phase
  let match, tick: Int
  let players: [Player]
  let maxPlayers: Int
  let results: Results?
}

struct KitchenCell: Identifiable {
  let id: String
  let x, y: Double
  let symbol: Character
  let platform: Bool
  let state: TileState
}

enum Kitchen {
  static func cells(level: Level, snapshot: Snapshot?) -> [KitchenCell] {
    var cells: [KitchenCell] = []
    func append(rows: [String], x: Double, y: Double, mover: Int?) {
      for (row, text) in rows.enumerated() {
        for (column, symbol) in text.prefix(rows.first?.count ?? 0).enumerated() {
          let key = "\(column),\(row)"
          var state = TileState()
          if let snapshot {
            if let mover, mover < snapshot.movers.count {
              let index = row * (rows.first?.count ?? 0) + column
              if index < snapshot.movers[mover].count { state = snapshot.movers[mover][index] }
            } else if mover == nil {
              state = snapshot.tiles[key] ?? TileState()
            }
          } else {
            if symbol == "S" { state.item = .pot(contents: [], cook: 0, burn: 0, burnt: false) }
            if symbol == "R" { state.item = .stack(count: level.startingPlates, dirty: false) }
            if symbol == "E" { state.item = .extinguisher }
          }
          cells.append(
            KitchenCell(
              id: "\(mover.map(String.init) ?? "base"):\(key)",
              x: x + Double(column), y: y + Double(row), symbol: symbol,
              platform: mover != nil, state: state))
        }
      }
    }
    append(rows: level.rows, x: 0, y: 0, mover: nil)
    for (index, mover) in level.movers.enumerated() {
      let offset = snapshot.flatMap { index < $0.offsets.count ? $0.offsets[index] : nil } ?? 0
      append(
        rows: mover.rows, x: Double(mover.x) + (mover.axis == "x" ? offset : 0),
        y: Double(mover.y) + (mover.axis == "y" ? offset : 0), mover: index)
    }
    return cells
  }
}
