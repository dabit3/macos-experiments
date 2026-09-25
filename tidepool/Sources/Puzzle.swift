import Foundation

enum Habitat: String, Codable, CaseIterable {
  case rock, sand, water
  var title: String { rawValue.capitalized }
}

enum Creature: String, CaseIterable, Codable, Identifiable {
  case coral, anemone, clownfish, seastar, urchin
  var id: String { rawValue }
  var name: String {
    switch self {
    case .coral: "Coral"
    case .anemone: "Anemone"
    case .clownfish: "Clownfish"
    case .seastar: "Sea star"
    case .urchin: "Urchin"
    }
  }
  var habitat: Habitat {
    switch self {
    case .coral, .anemone, .urchin: .rock
    case .clownfish: .water
    case .seastar: .sand
    }
  }
  var rule: String {
    switch self {
    case .coral: "Anchor on rock. Coral creates shelter for its neighbors."
    case .anemone: "Anchor on rock, beside coral."
    case .clownfish: "Swim in water, beside an anemone."
    case .seastar: "Rest on sand. Check this pool’s special goal."
    case .urchin: "Anchor on rock. Keep at least one neighboring space empty."
    }
  }
  var journal: String {
    switch self {
    case .coral:
      "A tiny architect. Branching colonies turn bare rock into a home for a whole community."
    case .anemone:
      "A flower that is an animal. Its swaying tentacles offer clownfish a sheltered place to hide."
    case .clownfish:
      "A bright little neighbor. In the wild, clownfish and anemones help protect one another."
    case .seastar:
      "A patient explorer. Hundreds of tiny tube feet carry this tidepool resident across the shore."
    case .urchin:
      "A spiny gardener. Grazing urchins help keep algae in balance when an ecosystem is healthy."
    }
  }
}

struct Placement: Codable, Equatable {
  let creature: Creature
  var cell: Int
}

struct PoolLevel: Identifiable {
  let id: Int
  let title: String
  let subtitle: String
  let goal: String
  let terrain: [Habitat]
  let inhabitants: [Creature]
  let reference: [Placement]

  static let all: [PoolLevel] = [
    make(
      0, "First light", "A little shelter goes a long way.",
      "Build a chain: coral → anemone → clownfish.",
      ["rrww", "srww", "ssww", "rssr"],
      [(.coral, 0), (.anemone, 1), (.clownfish, 2)]),
    make(
      1, "Sandy neighbors", "Life returns to the shallows.",
      "Give the sea star a coral neighbor, too.",
      ["wwws", "srrs", "wwss", "rssw"],
      [(.coral, 5), (.anemone, 6), (.clownfish, 2), (.seastar, 4)]),
    make(
      2, "Room to grow", "A healthy reef needs breathing room.",
      "Keep corals 3+ steps apart. Sea star beside urchin.",
      ["rrsw", "rwsw", "srww", "ssrr"],
      [(.coral, 0), (.coral, 9), (.urchin, 1), (.seastar, 2)]),
    make(
      3, "Quiet refuge", "Make space for the shy gardeners.",
      "Keep the urchin away from coral and anemones.",
      ["rrww", "swwr", "ssrw", "rssw"],
      [(.coral, 0), (.anemone, 1), (.clownfish, 2), (.seastar, 4), (.urchin, 10)]),
    make(
      4, "A living mosaic", "One small pool. A world of connections.",
      "Both anemones share coral. Sea star beside coral.",
      ["wrww", "wrrw", "ssrr", "ssww"],
      [
        (.coral, 5), (.anemone, 1), (.anemone, 6), (.clownfish, 0), (.clownfish, 7),
        (.seastar, 9), (.urchin, 10),
      ]),
  ]

  private static func make(
    _ id: Int, _ title: String, _ subtitle: String, _ goal: String, _ rows: [String],
    _ solution: [(Creature, Int)]
  ) -> PoolLevel {
    let terrain = rows.joined().map { character -> Habitat in
      switch character {
      case "r": .rock
      case "s": .sand
      default: .water
      }
    }
    return PoolLevel(
      id: id, title: title, subtitle: subtitle, goal: goal, terrain: terrain,
      inhabitants: solution.map(\.0),
      reference: solution.map { Placement(creature: $0.0, cell: $0.1) })
  }
}

enum Puzzle {
  static func adjacent(_ a: Int, _ b: Int) -> Bool { distance(a, b) == 1 }
  static func distance(_ a: Int, _ b: Int) -> Int { abs(a / 4 - b / 4) + abs(a % 4 - b % 4) }
  static func neighbors(_ cell: Int) -> [Int] { (0..<16).filter { adjacent(cell, $0) } }

  static func placementError(
    _ creature: Creature, cell: Int, in board: [Placement], level: PoolLevel
  ) -> String? {
    guard level.terrain.indices.contains(cell) else {
      return "Drop inside the pool to place a resident."
    }
    guard !board.contains(where: { $0.cell == cell }) else {
      return "That space is occupied. Try a free \(creature.habitat.rawValue) space."
    }
    guard level.terrain[cell] == creature.habitat else {
      return
        "\(creature.name) needs \(creature.habitat.rawValue), not \(level.terrain[cell].rawValue)."
    }
    guard
      board.filter({ $0.creature == creature }).count
        < level.inhabitants.filter({ $0 == creature }).count
    else { return "Every \(creature.name.lowercased()) is already in the pool." }
    return nil
  }

  static func healthy(_ item: Placement, board: [Placement], level: PoolLevel) -> Bool {
    func beside(_ species: Creature) -> Bool {
      board.contains { $0.creature == species && adjacent($0.cell, item.cell) }
    }
    switch item.creature {
    case .coral:
      if level.id == 2 {
        return !board.contains {
          $0.creature == .coral && $0.cell != item.cell && distance($0.cell, item.cell) < 3
        }
      }
      return true
    case .anemone: return beside(.coral)
    case .clownfish: return beside(.anemone)
    case .seastar:
      if level.id == 1 || level.id == 4 { return beside(.coral) }
      if level.id == 2 { return beside(.urchin) }
      return true
    case .urchin:
      let breathingRoom = neighbors(item.cell).contains { cell in
        !board.contains { $0.cell == cell }
      }
      return breathingRoom && (level.id != 3 || (!beside(.coral) && !beside(.anemone)))
    }
  }

  static func valid(_ board: [Placement], level: PoolLevel) -> Bool {
    var checked: [Placement] = []
    for item in board {
      guard placementError(item.creature, cell: item.cell, in: checked, level: level) == nil else {
        return false
      }
      checked.append(item)
    }
    return true
  }

  static func restored(_ board: [Placement], level: PoolLevel) -> Bool {
    valid(board, level: level) && board.count == level.inhabitants.count
      && board.allSatisfy { healthy($0, board: board, level: level) }
  }

  static func solution(level: PoolLevel, preserving board: [Placement]) -> [Placement]? {
    guard valid(board, level: level) else { return nil }
    var remaining = level.inhabitants
    for item in board {
      if let index = remaining.firstIndex(of: item.creature) { remaining.remove(at: index) }
    }
    func search(_ current: [Placement], _ index: Int) -> [Placement]? {
      if index == remaining.count { return restored(current, level: level) ? current : nil }
      let creature = remaining[index]
      for cell in 0..<16
      where placementError(creature, cell: cell, in: current, level: level) == nil {
        if let result = search(current + [Placement(creature: creature, cell: cell)], index + 1) {
          return result
        }
      }
      return nil
    }
    return search(board, 0)
  }
}

struct SavedProgress: Codable, Equatable {
  var version = 1
  var currentLevel = 0
  var completed: Set<Int> = []
  var boards: [Int: [Placement]] = [:]

  mutating func sanitize() {
    completed = completed.filter { (0..<PoolLevel.all.count).contains($0) }
    let unlocked = min((completed.max() ?? -1) + 1, PoolLevel.all.count - 1)
    currentLevel = min(max(0, currentLevel), unlocked)
    boards = boards.filter { id, board in
      PoolLevel.all.indices.contains(id) && Puzzle.valid(board, level: PoolLevel.all[id])
    }
  }
}

struct ProgressFile {
  let url: URL
  func load() -> SavedProgress {
    guard let data = try? Data(contentsOf: url),
      var saved = try? JSONDecoder().decode(SavedProgress.self, from: data), saved.version == 1
    else { return SavedProgress() }
    saved.sanitize()
    return saved
  }
  func save(_ progress: SavedProgress) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(progress).write(to: url, options: .atomic)
  }
}
