import Foundation

struct Hero: Decodable, Identifiable {
  let id: String
  let name: String
  let slot: Int
  let connected: Bool
  let ready: Bool
  let x: Double
  let z: Double
  let hp: Int
  let maxHP: Int
  let angle: Double
  let score: Int
  let gems: Int
  let kills: Int
  let charge: Int
  let weapon: String
  let bow: String
  let armor: String
  let down: Bool
  let revive: Double
  let potion: Int
  let dodge: Int
  let action: String
  let stats: HeroStats
}

struct HeroStats: Decodable {
  let melee: Int
  let ranged: Int
  let dodge: Int
  let heal: Int
  let revive: Int
  let hits: Int
  let equipment: Int
}

struct Foe: Decodable, Identifiable {
  let id: String
  let kind: String
  let x: Double
  let z: Double
  let hp: Int
  let maxHP: Int
  let angle: Double
  let action: String
  let telegraph: Int
}

struct Loot: Decodable, Identifiable {
  let id: String
  let kind: String
  let x: Double
  let z: Double
  let claimed: [String]?
}

struct Arrow: Decodable, Identifiable {
  let id: String
  let owner: String
  let x: Double
  let z: Double
  let vx: Double
  let vz: Double
}

struct WorldEvent: Decodable, Identifiable {
  let id: Int
  let kind: String
  let x: Double
  let z: Double
  let text: String
  let tick: Int
}

struct Notice: Identifiable, Equatable {
  static let kinds: Set<String> = ["start", "down", "artifact", "equip", "warning", "clear"]
  let id: Int
  let kind: String
  let text: String
  let tick: Int
}

struct Snapshot: Decodable {
  let code: String
  let phase: String
  let stage: Int
  let round: Int
  let tick: Int
  let completedStages: Int
  let objective: String
  let paused: Bool
  let players: [Hero]
  let enemies: [Foe]
  let loot: [Loot]
  let projectiles: [Arrow]
  let events: [WorldEvent]
}

struct Reply: Decodable {
  let type: String
  let id: String?
  let token: String?
  let code: String?
  let message: String?
  let seq: Int?
}

struct Command: Encodable {
  var type: String
  var name: String?
  var code: String?
  var create: Bool?
  var resume: String?
  var seq: Int?
  var x: Double?
  var z: Double?
  var action: String?
  var choice: String?
}

enum Launch {
  static func value(_ key: String) -> String? {
    let args = ProcessInfo.processInfo.arguments
    guard let index = args.firstIndex(of: "-\(key)"), index + 1 < args.count else {
      return nil
    }
    return args[index + 1]
  }
  static func has(_ key: String) -> Bool {
    ProcessInfo.processInfo.arguments.contains("-\(key)")
  }
}

struct GridCell: Hashable {
  let x: Int
  let z: Int
}

enum DungeonMap {
  static let areas: [(Double, Double, Double, Double)] = [
    (0, 0, 18, 16), (12, 0, 6, 4), (24, 0, 18, 16),
    (36, 0, 6, 4), (48, 0, 18, 18),
  ]
  static let columns: [(Double, Double)] = [(-2, -3), (3, 4), (21, 3), (26, -3), (43, -5), (52, 5)]

  static func walkable(_ x: Double, _ z: Double, stage: Int) -> Bool {
    guard areas.contains(where: { abs(x - $0.0) <= $0.2 / 2 && abs(z - $0.1) <= $0.3 / 2 - 0.4 })
    else { return false }
    if stage == 1 && x > 8.5 || stage == 2 && x > 32.5 { return false }
    return !columns.contains { abs(x - $0.0) < 1.5 && abs(z - $0.1) < 1.5 }
  }

  static func direction(from hero: Hero, to goal: (Double, Double), stage: Int) -> (Double, Double)
  {
    let start = GridCell(x: Int(hero.x.rounded()), z: Int(hero.z.rounded()))
    let end = GridCell(x: Int(goal.0.rounded()), z: Int(goal.1.rounded()))
    if start == end {
      return normalized(goal.0 - hero.x, goal.1 - hero.z)
    }
    var queue = [start]
    var parents: [GridCell: GridCell] = [:]
    var seen: Set<GridCell> = [start]
    var index = 0
    var best = start
    while index < queue.count && index < 1600 {
      let cell = queue[index]
      index += 1
      if abs(cell.x - end.x) + abs(cell.z - end.z) < abs(best.x - end.x) + abs(best.z - end.z) {
        best = cell
      }
      if cell == end {
        best = cell
        break
      }
      for (dx, dz) in [(1, 0), (0, 1), (-1, 0), (0, -1)] {
        let next = GridCell(x: cell.x + dx, z: cell.z + dz)
        if !seen.contains(next) && walkable(Double(next.x), Double(next.z), stage: stage) {
          seen.insert(next)
          parents[next] = cell
          queue.append(next)
        }
      }
    }
    while let parent = parents[best], parent != start { best = parent }
    return normalized(Double(best.x) - hero.x, Double(best.z) - hero.z)
  }

  static func normalized(_ x: Double, _ z: Double) -> (Double, Double) {
    let length = hypot(x, z)
    guard length > 0.05 else { return (0, 0) }
    return (x / max(1, length), z / max(1, length))
  }
}
