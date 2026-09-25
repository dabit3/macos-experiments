import Foundation

enum Direction: String, CaseIterable {
  case up, left, down, right

  var symbol: String {
    switch self {
    case .up: "arrow.up"
    case .left: "arrow.left"
    case .down: "arrow.down"
    case .right: "arrow.right"
    }
  }
}

enum Watcher: Equatable {
  case none
  case window(Int)
  case cat(Int)

  func isAwake(on beat: Int) -> Bool {
    switch self {
    case .none: false
    case .window(let phase): (beat + phase) % 4 >= 2
    case .cat(let phase): (beat + phase) % 4 == 0
    }
  }

  var name: String {
    switch self {
    case .none: "Garden"
    case .window: "Window"
    case .cat: "Cat"
    }
  }
}

struct Roof: Identifiable {
  let id: Int
  let garden: Bool
  let snack: Bool
  let watcher: Watcher

  var row: Int { id / 3 }
  var column: Int { id % 3 }
  func danger(on beat: Int) -> Bool { !garden && watcher.isAwake(on: beat) }
}

struct District: Identifiable {
  let id: Int
  let name: String
  let subtitle: String
  let budget: Int
  let requiredLoot: Int
  let roofs: [Roof]

  static let all: [District] = [
    make(id: 0, name: "Saffron Heights", subtitle: "THE FIRST HEIST", budget: 18, required: 4),
    make(id: 1, name: "Mint Quarter", subtitle: "CATS AFTER CURFEW", budget: 17, required: 5),
    make(id: 2, name: "Midnight Market", subtitle: "ONE LAST BITE", budget: 16, required: 6),
  ]

  private static func make(id: Int, name: String, subtitle: String, budget: Int, required: Int)
    -> District
  {
    let gardens: Set<Int> = [0, 2, 3, 5, 7, 9, 11]
    let snacks: Set<Int> = [1, 3, 4, 5, 6, 7, 10]
    let roofs = (0..<12).map { index in
      let watcher: Watcher
      switch index {
      case 1: watcher = .window(1 + id)
      case 4: watcher = .cat(1 + id)
      case 6: watcher = .window(2 + id)
      case 8: watcher = .cat(id)
      case 10: watcher = .window(id)
      default: watcher = .none
      }
      return Roof(
        id: index, garden: gardens.contains(index), snack: snacks.contains(index), watcher: watcher)
    }
    return District(
      id: id, name: name, subtitle: subtitle, budget: budget, requiredLoot: required, roofs: roofs)
  }
}

enum MissionPhase: Equatable {
  case playing, escaped, caught, dawn
}

struct Mission {
  let district: District
  private(set) var position = 9
  private(set) var beat = 0
  private(set) var alarm = 0
  private(set) var collected: Set<Int> = []
  private(set) var phase: MissionPhase = .playing
  private(set) var message = "Swipe a direction or tap a connected roof."

  var loot: Int { collected.count }
  var remaining: Int { district.budget - beat }
  var canEscape: Bool { loot >= district.requiredLoot }
  var score: Int { phase == .escaped ? max(0, loot * 120 + remaining * 25 - alarm * 150) : 0 }
  var rating: String {
    if phase != .escaped { return phase == .caught ? "BUSTED, BUT ADORABLE" : "OUT PAST BEDTIME" }
    if alarm == 0 && loot == 7 { return "THE SNACK PHANTOM" }
    if alarm == 0 { return "SILENT & SNACKY" }
    if alarm == 1 { return "SMOOTH CRIMINAL" }
    return "CHAOTIC GOOD"
  }

  func neighbor(_ direction: Direction) -> Int? {
    let row = position / 3
    let column = position % 3
    switch direction {
    case .up: return row > 0 ? position - 3 : nil
    case .down: return row < 3 ? position + 3 : nil
    case .left: return column > 0 ? position - 1 : nil
    case .right: return column < 2 ? position + 1 : nil
    }
  }

  func isNeighbor(_ target: Int) -> Bool {
    Direction.allCases.contains { neighbor($0) == target }
  }

  mutating func move(to target: Int) {
    guard phase == .playing else { return }
    guard isNeighbor(target) else {
      message = "One roof at a time. Follow the little bridges."
      return
    }
    position = target
    advance()
  }

  mutating func move(_ direction: Direction) {
    guard let target = neighbor(direction) else {
      message = "That's the edge of town. Try another direction."
      return
    }
    move(to: target)
  }

  mutating func wait() {
    guard phase == .playing else { return }
    advance()
  }

  private mutating func advance() {
    beat += 1
    let roof = district.roofs[position]
    let spotted = roof.danger(on: beat)
    if spotted { alarm += 1 }
    let newSnack = roof.snack && !collected.contains(position)
    if newSnack { collected.insert(position) }
    if alarm >= 3 {
      phase = .caught
      message = "Three sightings. The neighborhood is onto you."
    } else if position == 2 && canEscape {
      phase = .escaped
      message = "The snacks are safe. Your reputation? Questionable."
    } else if beat >= district.budget {
      phase = .dawn
      message = "Sunrise! Even snack bandits need a bedtime."
    } else if spotted {
      message = "Spotted! \(3 - alarm) \(alarm == 2 ? "chance" : "chances") left."
    } else if position == 2 {
      let needed = district.requiredLoot - loot
      message =
        "The tower needs \(needed) more \(needed == 1 ? "snack" : "snacks"). Keep exploring."
    } else if newSnack {
      message =
        canEscape
        ? "Bag secured! Reach the striped water tower to escape."
        : "Snack nabbed. \(district.requiredLoot - loot) more, then the water tower."
    } else {
      message =
        roof.garden
        ? "Hidden in the mint. Wait here to shift the city beat."
        : "Nice timing. Check the next-beat rings before moving."
    }
  }
}

struct Progress: Codable {
  var unlocked = 0
  var best: [String: Int] = [:]
  var totalEscapes = 0
  var tutorialSeen = false
  var sound = true
  var haptics = true

  mutating func record(_ mission: Mission) {
    guard mission.phase == .escaped else { return }
    totalEscapes += 1
    unlocked = max(unlocked, min(2, mission.district.id + 1))
    let key = String(mission.district.id)
    best[key] = max(best[key, default: 0], mission.score)
  }
}
