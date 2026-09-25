import Foundation

struct Tile: Hashable, Codable {
  let x: Int
  let y: Int

  func isNeighbor(of other: Tile) -> Bool {
    abs(x - other.x) + abs(y - other.y) == 1
  }
}

enum LanternColor: Int, CaseIterable, Codable {
  case amber, rose, jade

  var name: String { ["Amber", "Rose", "Jade"][rawValue] }
  var symbol: String { ["sun.max.fill", "heart.fill", "leaf.fill"][rawValue] }
}

struct Puzzle: Identifiable {
  let id: String
  let title: String
  let subtitle: String
  let size: Int
  let solution: [Tile]
  let blocked: Set<Tile>
  let lanterns: [Tile: LanternColor]
  let gates: [Tile: LanternColor]

  var start: Tile { solution[0] }
  var finish: Tile { solution[solution.count - 1] }
  var par: Int { solution.count - 1 }

  init(
    id: String, title: String, subtitle: String, size: Int, indices: [Int],
    transform: Int = 0
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.size = size
    func tile(_ index: Int) -> Tile {
      var x = index % size
      var y = index / size
      if transform & 1 != 0 { x = size - 1 - x }
      if transform & 2 != 0 { y = size - 1 - y }
      if transform & 4 != 0 { swap(&x, &y) }
      return Tile(x: x, y: y)
    }
    let route = indices.map(tile)
    solution = route
    let pickup = [2, route.count / 2, route.count - 3]
    lanterns = Dictionary(
      uniqueKeysWithValues: zip(pickup, LanternColor.allCases).map { (route[$0], $1) })
    gates = [route[3]: .amber, route[route.count / 2 + 1]: .rose]
    blocked = Set(
      (0..<(size * size)).filter {
        !indices.contains($0) && ($0 * 7 + indices[0]) % 5 < 2
      }.map(tile))
  }
}

enum Towns {
  struct Blueprint {
    let title: String
    let subtitle: String
    let size: Int
    let route: [Int]
  }

  static let blueprints: [Blueprint] = [
    .init(
      title: "First Light", subtitle: "Every festival begins with a spark.", size: 5,
      route: [20, 15, 10, 5, 0, 1, 2, 7, 12, 13, 14, 19, 24]),
    .init(
      title: "Petal Lane", subtitle: "Follow the hush of falling blossoms.", size: 5,
      route: [0, 1, 2, 3, 4, 9, 14, 13, 12, 11, 10, 15, 20]),
    .init(
      title: "Copper Bridge", subtitle: "A ribbon across the sleeping town.", size: 5,
      route: [24, 23, 22, 17, 12, 7, 2, 1, 0, 5, 10, 11, 16, 21, 20]),
    .init(
      title: "The Tea House", subtitle: "Take the long way past the eaves.", size: 5,
      route: [4, 9, 14, 19, 24, 23, 22, 17, 12, 7, 6, 5, 10, 15, 20]),
    .init(
      title: "Moonwell", subtitle: "Leave room for those who follow.", size: 5,
      route: [20, 21, 22, 23, 24, 19, 14, 9, 4, 3, 2, 7, 12, 11, 10, 5, 0]),
    .init(
      title: "Paper & Pine", subtitle: "Three colors, one unbroken thread.", size: 5,
      route: [0, 5, 10, 15, 20, 21, 22, 17, 12, 7, 2, 3, 4, 9, 14, 19, 24]),
    .init(
      title: "Indigo Steps", subtitle: "Climb where the lantern makers live.", size: 6,
      route: [30, 24, 18, 12, 6, 0, 1, 2, 8, 14, 20, 26, 32, 33, 34, 28, 22, 16, 10, 4, 5]),
    .init(
      title: "Sakura Bend", subtitle: "The blossoms know another way.", size: 6,
      route: [5, 11, 17, 23, 29, 35, 34, 33, 32, 31, 30, 24, 18, 12, 13, 14, 8, 2, 1, 0]),
    .init(
      title: "The Quiet Market", subtitle: "Wind between the shuttered stalls.", size: 6,
      route: [0, 1, 2, 3, 4, 5, 11, 17, 16, 15, 14, 13, 12, 18, 24, 25, 26, 27, 28, 29, 35]),
    .init(
      title: "Firefly Crossing", subtitle: "Let the small lights lead you.", size: 6,
      route: [35, 34, 33, 32, 31, 30, 24, 18, 12, 6, 0, 1, 2, 8, 14, 20, 21, 22, 16, 10, 4, 5]),
    .init(
      title: "Midnight Garden", subtitle: "A delicate turn. A brighter night.", size: 6,
      route: [30, 31, 32, 33, 34, 35, 29, 23, 17, 11, 5, 4, 3, 9, 15, 21, 20, 19, 18, 12, 6, 0]),
    .init(
      title: "Festival of Stars", subtitle: "Bring the whole town into the light.", size: 6,
      route: [0, 6, 12, 18, 24, 30, 31, 32, 26, 20, 14, 8, 2, 3, 4, 5, 11, 17, 23, 29, 35, 34, 33]),
  ]

  static let all: [Puzzle] = blueprints.enumerated().map { index, blueprint in
    Puzzle(
      id: "town-\(index)", title: blueprint.title, subtitle: blueprint.subtitle,
      size: blueprint.size, indices: blueprint.route)
  }

  static func dayKey(_ date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  static func daily(_ key: String = dayKey()) -> Puzzle {
    let seed = key.utf8.reduce(UInt64(0)) { ($0 &* 31) &+ UInt64($1) }
    let blueprint = blueprints[Int(seed % UInt64(blueprints.count))]
    return Puzzle(
      id: "daily-\(key)", title: "Tonight's Parade",
      subtitle: "\(key) · A shared sky, your own route.",
      size: blueprint.size, indices: blueprint.route, transform: Int((seed / 12) % 8))
  }

  static func puzzle(id: String) -> Puzzle? {
    if id.hasPrefix("daily-") { return daily(String(id.dropFirst(6))) }
    return all.first { $0.id == id }
  }
}

enum MoveOutcome: Equatable {
  case moved, completed, ignored
  case rejected(String)
  case tangled
}

struct Parade: Codable {
  let puzzleID: String
  var route: [Tile]
  var mistakes = 0
  var hints = 0
  var completed = false

  init(puzzle: Puzzle) {
    puzzleID = puzzle.id
    route = [puzzle.start]
  }

  func collected(in puzzle: Puzzle) -> [LanternColor] {
    route.compactMap { puzzle.lanterns[$0] }
  }

  func rejection(for tile: Tile, in puzzle: Puzzle) -> String? {
    if puzzle.blocked.contains(tile) { return "Rooftops are quiet. Stay on the streets." }
    let colors = collected(in: puzzle)
    if let lantern = puzzle.lanterns[tile], lantern.rawValue != colors.count {
      return "Collect \(LanternColor.allCases[min(colors.count, 2)].name) next."
    }
    if let gate = puzzle.gates[tile], !colors.contains(gate) {
      return "The \(gate.name) gate needs its lantern first."
    }
    if tile == puzzle.finish && colors.count != 3 {
      return "The square needs all three lantern colors."
    }
    return nil
  }

  mutating func move(to tile: Tile, in puzzle: Puzzle) -> MoveOutcome {
    guard !completed, let head = route.last, tile != head else { return .ignored }
    guard (0..<puzzle.size).contains(tile.x), (0..<puzzle.size).contains(tile.y),
      head.isNeighbor(of: tile)
    else { return .ignored }
    if route.count > 1 && tile == route[route.count - 2] {
      route.removeLast()
      return .moved
    }
    if route.contains(tile) {
      mistakes += 1
      return .tangled
    }
    if let message = rejection(for: tile, in: puzzle) {
      mistakes += 1
      return .rejected(message)
    }
    route.append(tile)
    if tile == puzzle.finish {
      completed = true
      return .completed
    }
    return .moved
  }

  mutating func undo() {
    guard route.count > 1, !completed else { return }
    route.removeLast()
  }

  func stars(in puzzle: Puzzle) -> Int {
    guard completed else { return 0 }
    if hints == 0 && mistakes == 0 && route.count - 1 <= puzzle.par { return 3 }
    return hints <= 1 && mistakes <= 3 ? 2 : 1
  }
}
