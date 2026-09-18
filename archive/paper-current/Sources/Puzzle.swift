import Foundation

enum Direction: Int, CaseIterable, Codable {
  case north, east, south, west

  var opposite: Direction { rotated(2) }
  func rotated(_ turns: Int) -> Direction {
    Direction(rawValue: (rawValue + turns + 8) % 4)!
  }
  var delta: (Int, Int) {
    switch self {
    case .north: return (-1, 0)
    case .east: return (0, 1)
    case .south: return (1, 0)
    case .west: return (0, -1)
    }
  }
}

struct Cell: Hashable, Codable {
  let row: Int
  let col: Int

  func neighbor(_ direction: Direction) -> Cell {
    Cell(row: row + direction.delta.0, col: col + direction.delta.1)
  }
  func direction(to other: Cell) -> Direction {
    Direction.allCases.first { neighbor($0) == other }!
  }
}

struct Canal: Equatable {
  let cell: Cell
  let entry: Direction
  let exit: Direction
  let isLock: Bool
  let isCurrent: Bool
  let hasStamp: Bool
  var turns: Int
  var open: Bool

  var ports: [Direction] { [entry.rotated(turns), exit.rotated(turns)] }
  var isAligned: Bool {
    if isCurrent { return turns % 4 == 0 }
    return Set(ports) == Set([entry, exit])
  }
}

struct Level: Identifiable {
  let id: Int
  let title: String
  let district: String
  let note: String
  let size: Int
  let route: [Cell]
  let locks: Set<Int>
  let currents: Set<Int>
  let stampIndices: Set<Int>

  var start: Cell { route[0] }
  var dock: Cell { route[route.count - 1] }
  var tideLimit: Int { route.count + 3 }
  var initial: [Canal] {
    route.enumerated().map { index, cell in
      let entry: Direction = index == 0 ? .west : cell.direction(to: route[index - 1])
      let exit: Direction =
        index == route.count - 1 ? .east : cell.direction(to: route[index + 1])
      let turns = index == 0 || index == route.count - 1 ? 0 : (index + id) % 4
      return Canal(
        cell: cell, entry: entry, exit: exit,
        isLock: locks.contains(index), isCurrent: currents.contains(index),
        hasStamp: stampIndices.contains(index), turns: turns,
        open: !locks.contains(index))
    }
  }

  static let all: [Level] = {
    let paths: [[(Int, Int)]] = [
      [(2, 0), (2, 1), (1, 1), (1, 2), (1, 3), (2, 3)],
      [(3, 0), (2, 0), (1, 0), (1, 1), (2, 1), (2, 2), (2, 3)],
      [(1, 0), (1, 1), (2, 1), (3, 1), (3, 2), (2, 2), (1, 2), (1, 3)],
      [(3, 0), (3, 1), (2, 1), (1, 1), (1, 2), (2, 2), (2, 3), (1, 3), (0, 3)],
      [(2, 0), (1, 0), (0, 0), (0, 1), (1, 1), (2, 1), (2, 2), (2, 3), (3, 3)],
      [(3, 0), (3, 1), (2, 1), (1, 1), (1, 2), (1, 3), (2, 3), (3, 3), (3, 4)],
      [(2, 0), (2, 1), (3, 1), (4, 1), (4, 2), (3, 2), (2, 2), (1, 2), (1, 3), (1, 4)],
      [(4, 0), (3, 0), (2, 0), (2, 1), (2, 2), (3, 2), (3, 3), (2, 3), (1, 3), (1, 4)],
      [
        (1, 0), (1, 1), (0, 1), (0, 2), (1, 2), (2, 2), (2, 1), (3, 1), (3, 2),
        (3, 3), (2, 3), (2, 4),
      ],
      [
        (4, 0), (3, 0), (2, 0), (2, 1), (1, 1), (1, 2), (2, 2), (3, 2), (3, 3),
        (2, 3), (1, 3), (1, 4), (2, 4), (3, 4),
      ],
    ]
    let titles = [
      "First-class rain", "The little lock", "Against the flow", "Lantern lane",
      "The long way home", "Across the rooftops", "Blue hour", "Three quiet locks",
      "Letters in the rain", "The last delivery",
    ]
    let notes = [
      "Tap a canal to turn it. Join the boat to the red postbox.",
      "Striped locks have a small latch. Tap it to let the water through.",
      "Arrow canals carry you one way. Match the direction of your journey.",
      "Follow the amber stamps. Every delivery needs all three.",
      "Take your time to plan. The tide only rises while you sail.",
      "A wider city, a longer letter. Trace the route before you launch.",
      "A current can look connected and still run the wrong way.",
      "Open every latch, then watch the locks release in sequence.",
      "Some letters take the scenic route. Leave no stamp behind.",
      "One small boat. A whole city of stories. Bring this one home.",
    ]
    return paths.enumerated().map { index, path in
      let count = path.count
      return Level(
        id: index, title: titles[index],
        district: index < 5 ? "THE OLD QUARTER" : "THE LANTERN DISTRICT",
        note: notes[index], size: index < 5 ? 4 : 5,
        route: path.map { Cell(row: $0.0, col: $0.1) },
        locks: index == 0 ? [] : (index >= 7 ? [2, 5, count - 2] : [2]),
        currents: index < 2 ? [] : [count - 3],
        stampIndices: [1, count / 2, count - 2])
    }
  }()
}

enum RouteProblem: Equatable {
  case disconnected, closedLock, wrongCurrent, missingStamps, tide

  var message: String {
    switch self {
    case .disconnected: return "A canal ends here. Turn the next piece to meet the water."
    case .closedLock: return "This lock is closed. Open its striped latch before sailing."
    case .wrongCurrent: return "This current runs the other way. Turn its arrow toward the dock."
    case .missingStamps: return "A stamp was left behind. Your letter needs every stamp."
    case .tide: return "The tide caught you in a loop. Find a shorter route to the postbox."
    }
  }
}

struct RouteResult {
  let cells: [Cell]
  let stamps: Set<Cell>
  let problem: RouteProblem?
  var success: Bool { problem == nil }
}

enum Router {
  static func trace(level: Level, canals: [Canal]) -> RouteResult {
    let map = Dictionary(uniqueKeysWithValues: canals.map { ($0.cell, $0) })
    var cell = level.start
    var incoming = Direction.west
    var visited: [Cell] = []
    var stamps: Set<Cell> = []
    func result(_ problem: RouteProblem?) -> RouteResult {
      RouteResult(cells: visited, stamps: stamps, problem: problem)
    }
    for _ in 0..<level.tideLimit {
      guard let canal = map[cell], canal.ports.contains(incoming) else {
        return result(.disconnected)
      }
      visited.append(cell)
      if canal.isLock && !canal.open { return result(.closedLock) }
      if canal.isCurrent && canal.ports[0] != incoming { return result(.wrongCurrent) }
      if canal.hasStamp { stamps.insert(cell) }
      if cell == level.dock {
        return result(stamps.count == level.stampIndices.count ? nil : .missingStamps)
      }
      let exit = canal.ports.first { $0 != incoming }!
      cell = cell.neighbor(exit)
      incoming = exit.opposite
    }
    return result(.tide)
  }
}

struct PuzzleState {
  let level: Level
  var canals: [Canal]
  var moves = 0
  var hints = 0
  private var history: [[Canal]] = []

  init(level: Level) {
    self.level = level
    canals = level.initial
  }
  var canUndo: Bool { !history.isEmpty }
  var preview: RouteResult { Router.trace(level: level, canals: canals) }
  var rating: Int { hints == 0 && moves <= par ? 3 : (hints <= 2 ? 2 : 1) }
  var par: Int {
    level.initial.dropFirst().dropLast().reduce(0) { total, canal in
      let rotations =
        (0..<4).first {
          var copy = canal
          copy.turns = (copy.turns + $0) % 4
          return copy.isAligned
        } ?? 0
      return total + rotations + (canal.open ? 0 : 1)
    }
  }
  mutating func rotate(_ cell: Cell) {
    guard cell != level.start, cell != level.dock,
      let index = canals.firstIndex(where: { $0.cell == cell })
    else { return }
    history.append(canals)
    canals[index].turns = (canals[index].turns + 1) % 4
    moves += 1
  }
  mutating func toggleLock(_ cell: Cell) {
    guard let index = canals.firstIndex(where: { $0.cell == cell && $0.isLock }) else {
      return
    }
    history.append(canals)
    canals[index].open.toggle()
    moves += 1
  }
  mutating func undo() {
    guard let previous = history.popLast() else { return }
    canals = previous
    moves = max(0, moves - 1)
  }
  mutating func hint() {
    guard
      let index = canals.indices.first(where: {
        !canals[$0].isAligned || !canals[$0].open
      })
    else { return }
    history.append(canals)
    canals[index].turns = 0
    canals[index].open = true
    moves += 1
    hints += 1
  }
}

struct ProgressStore {
  private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) { self.defaults = defaults }
  var completed: [String: Int] {
    defaults.dictionary(forKey: "paper.best") as? [String: Int] ?? [:]
  }
  var unlocked: Int {
    min(Level.all.count - 1, (0..<Level.all.count).first { completed[String($0)] == nil } ?? 9)
  }
  func save(level: Int, moves: Int) {
    var best = completed
    best[String(level)] = min(best[String(level)] ?? Int.max, moves)
    defaults.set(best, forKey: "paper.best")
  }
}
