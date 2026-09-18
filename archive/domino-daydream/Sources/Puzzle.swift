import Foundation

struct Cell: Hashable, Codable, Identifiable {
  let x: Int
  let y: Int
  var id: String { "\(x),\(y)" }
  func moved(_ direction: Direction, distance: Int = 1) -> Cell {
    Cell(x: x + direction.dx * distance, y: y + direction.dy * distance)
  }
  func direction(to other: Cell) -> Direction {
    if other.x > x { return .east }
    if other.x < x { return .west }
    return other.y > y ? .south : .north
  }
}

enum Direction: Int, CaseIterable, Codable {
  case east, south, west, north
  var dx: Int { [1, 0, -1, 0][rawValue] }
  var dy: Int { [0, 1, 0, -1][rawValue] }
  var opposite: Direction { rotated(2) }
  func rotated(_ steps: Int) -> Direction {
    Direction(rawValue: (rawValue + steps + 4) % 4) ?? .east
  }
}

enum PieceKind: String, CaseIterable, Codable, Identifiable {
  case straight, turn, bridge, fork
  var id: String { rawValue }
  var title: String {
    switch self {
    case .straight: "Line"
    case .turn: "Turn"
    case .bridge: "Bridge"
    case .fork: "Split"
    }
  }
  var symbol: String {
    switch self {
    case .straight: "minus"
    case .turn: "arrow.turn.down.right"
    case .bridge: "water.waves"
    case .fork: "arrow.triangle.branch"
    }
  }
  var basePorts: [Direction] {
    switch self {
    case .straight, .bridge: [.west, .east]
    case .turn: [.west, .south]
    case .fork: [.west, .east, .south]
    }
  }
}

struct Piece: Codable, Equatable {
  let kind: PieceKind
  var rotation: Int = 0
  var ports: [Direction] { kind.basePorts.map { $0.rotated(rotation) } }
  var rotated: Piece { Piece(kind: kind, rotation: (rotation + 1) % 4) }
}

struct Puzzle: Identifiable {
  let id: Int
  let title: String
  let subtitle: String
  let lesson: String
  let start: Cell
  let targets: [Cell]
  let solution: [Cell: Piece]
  let fixed: [Cell: Piece]
  let water: Set<Cell>
  let inventory: [PieceKind: Int]
  let town: Cell
  var sandbox: Bool { id == 8 }
  var sockets: [Cell] {
    solution.keys.filter { fixed[$0] == nil }.sorted {
      $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
    }
  }
  func contains(_ cell: Cell) -> Bool {
    (0..<7).contains(cell.x) && (0..<9).contains(cell.y)
  }
  func canEdit(_ cell: Cell) -> Bool {
    contains(cell) && fixed[cell] == nil && cell != start
      && !targets.contains(cell) && !water.contains(cell)
      && (sandbox || sockets.contains(cell))
  }

  static let all: [Puzzle] = [
    make(
      id: 0, title: "A little nudge", subtitle: "THE FIRST AFTERNOON",
      lesson: "Fill the two dotted sockets with Line pieces. Ring both brass bells.",
      main: [(0, 5), (1, 5), (2, 5), (3, 5), (4, 5), (5, 5), (6, 5)],
      branch: [(4, 5), (4, 4), (4, 3)],
      missing: [(2, 5), (5, 5)], town: (2, 2)),
    make(
      id: 1, title: "Around the corner", subtitle: "THE ROSE COURTYARD",
      lesson: "Turns connect two neighboring edges. Rotate a piece to match the little rails.",
      main: [(0, 6), (1, 6), (2, 6), (3, 6), (3, 5), (3, 4), (4, 4), (5, 4), (5, 3), (5, 2)],
      branch: [(3, 6), (4, 6), (5, 6)],
      missing: [(2, 6), (3, 4), (5, 4)], town: (1, 3)),
    make(
      id: 2, title: "Across the blue", subtitle: "A CANAL-SIDE WALK",
      lesson:
        "A Bridge vaults one blue water square. Its arrow must face along the canal crossing.",
      main: [(0, 5), (1, 5), (3, 5), (4, 5), (5, 5), (5, 4), (5, 3), (5, 2)],
      branch: [(4, 5), (4, 6), (4, 7)],
      missing: [(1, 5), (5, 5), (5, 3)], bridges: [(1, 5)], town: (2, 2)),
    make(
      id: 3, title: "Two ways home", subtitle: "THE LITTLE JUNCTION",
      lesson: "A Split sends the nudge down two routes. Every bell needs a visit.",
      main: [(0, 6), (1, 6), (2, 6), (3, 6), (4, 6), (5, 6), (5, 5), (5, 4), (5, 3)],
      branch: [(3, 6), (3, 5), (3, 4), (2, 4), (1, 4)],
      missing: [(3, 6), (3, 4), (5, 6), (1, 6)], town: (2, 1)),
    make(
      id: 4, title: "Petal promenade", subtitle: "THE LONG WAY ROUND",
      lesson: "Follow the porcelain rails. Think about which edge the nudge enters.",
      main: [
        (0, 7), (1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (6, 7), (6, 6), (6, 5),
        (6, 4), (6, 3), (5, 3), (4, 3), (3, 3), (2, 3), (2, 4), (2, 5),
      ],
      branch: [(4, 7), (4, 6), (4, 5)],
      missing: [(2, 7), (4, 7), (6, 7), (6, 3), (2, 3)], town: (3, 1)),
    make(
      id: 5, title: "A pocket of water", subtitle: "THE ENAMEL GARDEN",
      lesson: "Two bridges, two banks. A falling chain cannot cross open water by itself.",
      main: [
        (0, 6), (1, 6), (3, 6), (4, 6), (5, 6), (5, 5), (5, 3), (5, 2), (4, 2),
        (3, 2), (2, 2), (1, 2), (1, 3),
      ],
      branch: [(4, 6), (4, 7), (4, 8)],
      missing: [(1, 6), (5, 5), (5, 2), (1, 2), (4, 6)], bridges: [(1, 6), (5, 5)],
      town: (2, 4)),
    make(
      id: 6, title: "Brass & branches", subtitle: "THREE BELLS AT DUSK",
      lesson: "A tiny orchestra. All three bells must ring in a single chain.",
      main: [
        (0, 7), (1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (6, 7), (6, 6), (6, 5),
        (6, 4), (6, 3), (6, 2), (5, 2), (4, 2), (3, 2), (2, 2), (1, 2),
      ],
      branch: [(3, 7), (3, 6), (3, 5), (2, 5), (1, 5)],
      extra: [(6, 4), (5, 4), (4, 4)],
      missing: [(3, 7), (6, 7), (6, 4), (6, 2), (3, 5), (3, 2)], town: (2, 3)),
    make(
      id: 7, title: "The daydream spiral", subtitle: "ONE IRRESISTIBLE FINALE",
      lesson: "Circle the miniature town, then let the final bell sing.",
      main: [
        (0, 7), (1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (6, 7), (6, 6), (6, 5),
        (6, 4), (6, 3), (6, 2), (6, 1), (5, 1), (4, 1), (3, 1), (2, 1), (1, 1),
        (0, 1), (0, 2), (0, 3), (0, 4), (1, 4), (2, 4), (3, 4), (3, 5),
      ],
      branch: [(4, 7), (4, 6), (4, 5)],
      missing: [(2, 7), (4, 7), (6, 7), (6, 1), (3, 1), (0, 1), (0, 4), (3, 4)],
      town: (2, 2)),
    make(
      id: 8, title: "Your little world", subtitle: "THE OPEN TABLE",
      lesson:
        "Build anywhere on the dots. Start pushes right; connect both bells. Pieces are unlimited.",
      main: [(0, 6), (1, 6), (2, 6), (3, 6), (4, 6), (5, 6), (6, 6)],
      branch: [(4, 6), (4, 5), (4, 4), (4, 3), (4, 2)],
      missing: [(1, 6), (2, 6), (3, 6), (4, 6), (5, 6), (4, 5), (4, 4), (4, 3)],
      town: (1, 1)),
  ]

  private static func make(
    id: Int, title: String, subtitle: String, lesson: String,
    main: [(Int, Int)], branch: [(Int, Int)], extra: [(Int, Int)] = [],
    missing: [(Int, Int)], bridges: [(Int, Int)] = [], town: (Int, Int)
  ) -> Puzzle {
    let paths = [main, branch, extra].filter { !$0.isEmpty }.map {
      $0.map { Cell(x: $0.0, y: $0.1) }
    }
    let start = paths[0][0]
    let targets = paths.compactMap(\.last)
    let bridgeCells = Set(bridges.map { Cell(x: $0.0, y: $0.1) })
    let holes = Set(missing.map { Cell(x: $0.0, y: $0.1) })
    var connections: [Cell: Set<Direction>] = [:]
    var water = Set<Cell>()
    for path in paths {
      for index in 0..<(path.count - 1) {
        let a = path[index]
        let b = path[index + 1]
        let direction = a.direction(to: b)
        connections[a, default: []].insert(direction)
        connections[b, default: []].insert(direction.opposite)
        if abs(a.x - b.x) + abs(a.y - b.y) == 2 {
          water.insert(a.moved(direction))
        }
      }
    }
    var solution: [Cell: Piece] = [:]
    for (cell, ports) in connections where cell != start && !targets.contains(cell) {
      let kind: PieceKind =
        bridgeCells.contains(cell)
        ? .bridge
        : ports.count == 3
          ? .fork
          : ports.contains(.east) && ports.contains(.west)
            || ports.contains(.north) && ports.contains(.south) ? .straight : .turn
      for rotation in 0..<4 {
        let piece = Piece(kind: kind, rotation: rotation)
        if Set(piece.ports) == ports {
          solution[cell] = piece
          break
        }
      }
    }
    let fixed = solution.filter { !holes.contains($0.key) }
    var inventory: [PieceKind: Int] = [:]
    for cell in holes {
      if let piece = solution[cell] { inventory[piece.kind, default: 0] += 1 }
    }
    return Puzzle(
      id: id, title: title, subtitle: subtitle, lesson: lesson, start: start,
      targets: targets, solution: solution, fixed: fixed, water: water,
      inventory: inventory, town: Cell(x: town.0, y: town.1))
  }
}

struct ChainEvent: Equatable {
  let cell: Cell
  let direction: Direction
  let beat: Int
}

struct ChainResult {
  let events: [ChainEvent]
  let reached: Set<Cell>
  let failures: [Cell: String]
  let totalTargets: Int
  let dominoCount: Int
  var won: Bool { reached.count == totalTargets }
  var chainLength: Int { dominoCount }
  func score(hints: Int, attempts: Int) -> Int {
    guard won else { return reached.count * 100 }
    return max(100, chainLength * 20 + totalTargets * 200 - hints * 75 - max(0, attempts - 1) * 25)
  }
}

enum ChainEngine {
  static func run(puzzle: Puzzle, placed: [Cell: Piece]) -> ChainResult {
    let pieces = puzzle.fixed.merging(placed) { fixed, _ in fixed }
    var queue = [ChainEvent(cell: puzzle.start.moved(.east), direction: .east, beat: 1)]
    var events = [ChainEvent(cell: puzzle.start, direction: .east, beat: 0)]
    var visited: Set<Cell> = [puzzle.start]
    var reached = Set<Cell>()
    var failures: [Cell: String] = [:]
    var index = 0
    while index < queue.count {
      let event = queue[index]
      index += 1
      guard !visited.contains(event.cell) else { continue }
      if puzzle.targets.contains(event.cell) {
        visited.insert(event.cell)
        reached.insert(event.cell)
        events.append(event)
        continue
      }
      guard let piece = pieces[event.cell] else {
        failures[event.cell] =
          puzzle.water.contains(event.cell)
          ? "The chain fell into the canal. Use a Bridge."
          : "The nudge reached an empty socket. Add a piece here."
        continue
      }
      let inlet = event.direction.opposite
      guard piece.ports.contains(inlet) else {
        failures[event.cell] = "The nudge hit a closed edge. Rotate this piece."
        continue
      }
      visited.insert(event.cell)
      failures.removeValue(forKey: event.cell)
      events.append(event)
      for exit in piece.ports where exit != inlet {
        queue.append(
          ChainEvent(
            cell: event.cell.moved(exit, distance: piece.kind == .bridge ? 2 : 1),
            direction: exit, beat: event.beat + 1))
      }
    }
    let dominoCount = events.reduce(0) { count, event in
      count + (pieces[event.cell].map { $0.ports.count + 1 } ?? 0)
    }
    return ChainResult(
      events: events, reached: reached, failures: failures,
      totalTargets: puzzle.targets.count, dominoCount: dominoCount)
  }
}
