import Foundation

/// An immutable puzzle definition.
public struct Level: Codable, Hashable, Sendable {
  public var id: Int
  public var name: String
  public var subtitle: String
  public var width: Int
  public var height: Int
  public var tiles: [Tile]
  public var timeLimit: Double
  /// Minimum taps found by the solver for the scrambled board.
  public var par: Int
  public var seed: UInt64

  public init(
    id: Int, name: String, subtitle: String, width: Int, height: Int, tiles: [Tile],
    timeLimit: Double, par: Int, seed: UInt64
  ) {
    self.id = id
    self.name = name
    self.subtitle = subtitle
    self.width = width
    self.height = height
    self.tiles = tiles
    self.timeLimit = timeLimit
    self.par = par
    self.seed = seed
  }

  public var nets: [Net] {
    Net.allCases.filter { net in tiles.contains { $0.kind == .source(net) } }
  }
  public var hasHeat: Bool { tiles.contains { $0.kind == .hot } }
}

/// Result of tracing electricity from every PSU connector.
public struct Flow: Equatable, Sendable {
  /// Nets reaching each cell (cells with no power are absent).
  public var powered: [GridPoint: Set<Net>] = [:]
  /// Nets whose GPU connector is energized.
  public var sinksPowered: Set<Net> = []
  /// Cells carrying two different nets at once.
  public var shorts: Set<GridPoint> = []
  public var isComplete: Bool { !required.isEmpty && required == sinksPowered && shorts.isEmpty }
  var required: Set<Net> = []
}

public enum BoardPhase: Codable, Hashable, Sendable {
  case ready
  case routing
  case solved
  case failed(FailReason)
}

public enum FailReason: Codable, Hashable, Sendable {
  case timeout
  case meltdown

  public var title: String {
    switch self {
    case .timeout: return "POST FAILED"
    case .meltdown: return "THERMAL SHUTDOWN"
    }
  }
  public var message: String {
    switch self {
    case .timeout: return "Power-on timer expired before the GPU received its lanes."
    case .meltdown: return "A melted cable severed every remaining route to the GPU."
    }
  }
}

/// Live puzzle state: the mutable board plus timer, move count and thermal simulation.
public struct Board: Codable, Hashable, Sendable {
  public static let meltSeconds = 4.0
  public static let coolSeconds = 1.4

  public let level: Level
  public var tiles: [Tile]
  public var moves: Int = 0
  public var elapsed: Double = 0
  public var phase: BoardPhase = .ready

  public init(level: Level) {
    self.level = level
    self.tiles = level.tiles
  }

  public var width: Int { level.width }
  public var height: Int { level.height }
  public var timeRemaining: Double { max(0, level.timeLimit - elapsed) }
  public var timeFraction: Double { level.timeLimit > 0 ? timeRemaining / level.timeLimit : 1 }
  public var isLive: Bool { phase == .ready || phase == .routing }

  public func contains(_ p: GridPoint) -> Bool {
    p.x >= 0 && p.y >= 0 && p.x < width && p.y < height
  }
  public func index(_ p: GridPoint) -> Int { p.y * width + p.x }
  public subscript(_ p: GridPoint) -> Tile {
    get { tiles[index(p)] }
    set { tiles[index(p)] = newValue }
  }
  public var points: [GridPoint] {
    (0..<height).flatMap { y in (0..<width).map { x in GridPoint(x, y) } }
  }

  /// Rotates a cable clockwise. Returns false if the cell cannot turn or the game is over.
  @discardableResult
  public mutating func rotate(at p: GridPoint) -> Bool {
    guard isLive, contains(p), self[p].isRotatable else { return false }
    self[p].rotation += 1
    moves += 1
    if phase == .ready { phase = .routing }
    if flow().isComplete { phase = .solved }
    return true
  }

  /// Traces every net from its PSU connector across mutually-connected openings.
  public func flow() -> Flow {
    var result = Flow()
    result.required = Set(level.nets)
    for p in points {
      guard case .source(let net) = self[p].kind else { continue }
      var stack = [p]
      var seen: Set<GridPoint> = [p]
      result.powered[p, default: []].insert(net)
      while let cur = stack.popLast() {
        let tile = self[cur]
        for dir in tile.openings {
          let next = cur.moved(dir)
          guard contains(next), !seen.contains(next) else { continue }
          let other = self[next]
          guard other.has(dir.opposite) else { continue }
          if case .source = other.kind { continue }
          seen.insert(next)
          result.powered[next, default: []].insert(net)
          if case .sink(let sinkNet) = other.kind {
            if sinkNet == net { result.sinksPowered.insert(net) }
            continue
          }
          stack.append(next)
        }
      }
    }
    for (p, nets) in result.powered where nets.count > 1 { result.shorts.insert(p) }
    if !result.shorts.isEmpty { result.sinksPowered = [] }
    return result
  }

  public func isAdjacentToHeat(_ p: GridPoint) -> Bool {
    p.neighbors.contains { contains($0.1) && self[$0.1].kind == .hot }
  }

  /// Advances the clock and thermal model. Returns cells that melted this tick.
  @discardableResult
  public mutating func tick(_ dt: Double) -> [GridPoint] {
    guard phase == .routing else { return [] }
    elapsed += dt
    var melted: [GridPoint] = []
    if level.hasHeat {
      let flow = flow()
      for p in points {
        var tile = self[p]
        guard tile.kind.isCable else { continue }
        let stressed = flow.powered[p] != nil && isAdjacentToHeat(p)
        if stressed {
          tile.heat = min(1, tile.heat + dt / Board.meltSeconds)
          if tile.heat >= 1 {
            tile.kind = .slag
            tile.heat = 1
            melted.append(p)
          }
        } else {
          tile.heat = max(0, tile.heat - dt / Board.coolSeconds)
        }
        self[p] = tile
      }
      if !melted.isEmpty, !Solver.isSolvable(self, avoidHeat: false) {
        phase = .failed(.meltdown)
        return melted
      }
    }
    if elapsed >= level.timeLimit {
      elapsed = level.timeLimit
      phase = .failed(.timeout)
    }
    return melted
  }

  /// 1–3 stars: solved, plus time bonus, plus par bonus.
  public var stars: Int {
    guard phase == .solved else { return 0 }
    var s = 1
    if timeFraction >= 0.4 { s += 1 }
    if moves <= level.par + max(2, level.par / 4) { s += 1 }
    return s
  }
}
