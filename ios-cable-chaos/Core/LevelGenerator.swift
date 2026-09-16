import Foundation

public struct LevelSpec: Hashable, Sendable {
  public var id: Int
  public var name: String
  public var subtitle: String
  public var width: Int
  public var height: Int
  public var nets: Int
  public var hotTiles: Int
  public var timeLimit: Double
  public var seed: UInt64

  public init(
    id: Int, name: String, subtitle: String, width: Int, height: Int, nets: Int, hotTiles: Int,
    timeLimit: Double, seed: UInt64
  ) {
    self.id = id
    self.name = name
    self.subtitle = subtitle
    self.width = width
    self.height = height
    self.nets = nets
    self.hotTiles = hotTiles
    self.timeLimit = timeLimit
    self.seed = seed
  }
}

public enum LevelGenerator {
  public enum GenerationError: Error { case unsolvable }

  /// Builds a scrambled, solvable level. Deterministic for a given spec.
  public static func generate(_ spec: LevelSpec) -> Level {
    var attempt: UInt64 = 0
    while true {
      var rng = SeededRNG(seed: spec.seed &+ attempt &* 0x1F1F_1F1F)
      if let level = try? build(spec, rng: &rng) { return level }
      attempt += 1
      precondition(attempt < 500, "Level \(spec.id) could not be generated")
    }
  }

  static func build(_ spec: LevelSpec, rng: inout SeededRNG) throws -> Level {
    let w = spec.width
    let h = spec.height
    precondition(w >= 4 && h >= 3 && spec.nets >= 1 && spec.nets <= 2)
    var kinds = [TileKind](repeating: .empty, count: w * h)
    func idx(_ p: GridPoint) -> Int { p.y * w + p.x }
    func inside(_ p: GridPoint) -> Bool { p.x >= 0 && p.y >= 0 && p.x < w && p.y < h }

    // Terminals: PSU connectors down the left edge, GPU connectors down the right edge.
    var rows = Array(0..<h)
    rows.shuffle(using: &rng)
    var sinkRows = Array(0..<h)
    sinkRows.shuffle(using: &rng)
    let nets = Array(Net.allCases.prefix(spec.nets))
    var sources: [Net: GridPoint] = [:]
    var sinks: [Net: GridPoint] = [:]
    for (i, net) in nets.enumerated() {
      sources[net] = GridPoint(0, rows[i])
      sinks[net] = GridPoint(w - 1, sinkRows[i])
      kinds[idx(sources[net]!)] = .source(net)
      kinds[idx(sinks[net]!)] = .sink(net)
    }

    // Hot tiles live in the interior and never touch a terminal's first/last cable cell.
    var blocked = Set<GridPoint>()
    var hot = Set<GridPoint>()
    var hotAttempts = 0
    while hot.count < spec.hotTiles, hotAttempts < 200 {
      hotAttempts += 1
      let p = GridPoint(rng.int(2..<max(3, w - 2)), rng.int(0..<h))
      if hot.contains(p) || hot.contains(where: { abs($0.x - p.x) + abs($0.y - p.y) < 2 }) {
        continue
      }
      hot.insert(p)
    }
    for p in hot {
      kinds[idx(p)] = .hot
      blocked.insert(p)
      for (_, n) in p.neighbors where inside(n) { blocked.insert(n) }
    }
    for y in 0..<h {
      blocked.insert(GridPoint(0, y))
      blocked.insert(GridPoint(w - 1, y))
    }

    // One self-avoiding route per net, avoiding heat and other routes.
    var required: [GridPoint: Set<Direction>] = [:]
    for net in nets {
      let start = sources[net]!.moved(.right)
      let goal = sinks[net]!.moved(.left)
      guard !blocked.contains(start), !blocked.contains(goal) else {
        throw GenerationError.unsolvable
      }
      guard
        let path = randomPath(
          from: start, to: goal, blocked: blocked, width: w, height: h, rng: &rng)
      else { throw GenerationError.unsolvable }
      var previous = sources[net]!
      for (i, cell) in path.enumerated() {
        let entered = direction(from: previous, to: cell)
        let exited = i + 1 < path.count ? direction(from: cell, to: path[i + 1]) : Direction.right
        required[cell] = [entered.opposite, exited]
        blocked.insert(cell)
        for (_, n) in cell.neighbors where inside(n) && rng.chance(0.15) { blocked.insert(n) }
        previous = cell
      }
    }

    var tiles = kinds.map { kind -> Tile in
      if case .sink = kind { return Tile(kind, rotation: 2) }
      return Tile(kind)
    }
    for cell in required.keys.sorted(by: { ($0.y, $0.x) < ($1.y, $1.x) }) {
      let openings = required[cell]!
      var kind: TileKind
      let straight =
        openings.contains(.up) && openings.contains(.down)
        || openings.contains(.left) && openings.contains(.right)
      kind = straight ? .straight : .corner
      let roll = Double.random(in: 0..<1, using: &rng)
      if roll < 0.14 { kind = .tee } else if roll < 0.18 { kind = .cross }
      var tile = Tile(kind)
      guard let turns = tile.turnsToInclude(openings) else { throw GenerationError.unsolvable }
      tile.rotation = turns
      if kind == .tee, rng.chance(0.5) {
        // Two tee orientations satisfy a corner; vary which one.
        var alt = tile
        alt.rotation += 1
        if openings.isSubset(of: alt.openings) { tile = alt }
      }
      tiles[idx(cell)] = tile
    }

    // Decoys everywhere else.
    for y in 0..<h {
      for x in 0..<w {
        let p = GridPoint(x, y)
        guard kinds[idx(p)] == .empty, required[p] == nil else { continue }
        if x == 0 || x == w - 1 {
          continue
        }
        let roll = Double.random(in: 0..<1, using: &rng)
        let kind: TileKind =
          roll < 0.34
          ? .straight : roll < 0.68 ? .corner : roll < 0.84 ? .tee : roll < 0.9 ? .cross : .empty
        tiles[idx(p)] = Tile(kind, rotation: rng.int(0..<4))
      }
    }

    // Scramble.
    for i in tiles.indices where tiles[i].isRotatable {
      let sym = tiles[i].kind.symmetry
      tiles[i].rotation = (tiles[i].rotation + rng.int(0..<sym)) % 4
    }

    var level = Level(
      id: spec.id, name: spec.name, subtitle: spec.subtitle, width: w, height: h, tiles: tiles,
      timeLimit: spec.timeLimit, par: 0, seed: spec.seed)
    var board = Board(level: level)
    // No net may start out already routed: break each pre-solved route on one of its cells.
    for net in nets {
      guard board.flow().sinksPowered.contains(net) else { continue }
      let cells = required.keys.sorted(by: { ($0.y, $0.x) < ($1.y, $1.x) })
      guard
        let cell = cells.first(where: {
          board.flow().powered[$0]?.contains(net) == true && board[$0].kind.symmetry > 1
        })
      else { throw GenerationError.unsolvable }
      board[cell].rotation += 1
      level.tiles = board.tiles
      board = Board(level: level)
    }
    guard !board.flow().isComplete, Solver.isSolvable(board, avoidHeat: true),
      let par = Solver.par(board), par > 0
    else { throw GenerationError.unsolvable }
    level.par = par
    return level
  }

  static func direction(from a: GridPoint, to b: GridPoint) -> Direction {
    if b.x > a.x { return .right }
    if b.x < a.x { return .left }
    if b.y > a.y { return .down }
    return .up
  }

  /// Randomized depth-first self-avoiding walk with a mild pull toward the goal.
  static func randomPath(
    from start: GridPoint, to goal: GridPoint, blocked: Set<GridPoint>, width: Int, height: Int,
    rng: inout SeededRNG
  ) -> [GridPoint]? {
    var visited: Set<GridPoint> = [start]
    var path: [GridPoint] = [start]
    var expansions = 0
    func inside(_ p: GridPoint) -> Bool { p.x >= 0 && p.y >= 0 && p.x < width && p.y < height }
    func dfs(_ cur: GridPoint) -> Bool {
      if cur == goal { return true }
      expansions += 1
      if expansions > 6000 { return false }
      var options = cur.neighbors.map(\.1).filter {
        inside($0) && !blocked.contains($0) && !visited.contains($0)
      }
      options.shuffle(using: &rng)
      // Nudge toward the goal roughly half the time so routes stay wiggly but finite.
      if rng.chance(0.5) {
        options.sort {
          abs($0.x - goal.x) + abs($0.y - goal.y) < abs($1.x - goal.x) + abs($1.y - goal.y)
        }
      }
      for next in options {
        visited.insert(next)
        path.append(next)
        if dfs(next) { return true }
        path.removeLast()
      }
      return false
    }
    return dfs(start) ? path : nil
  }
}
