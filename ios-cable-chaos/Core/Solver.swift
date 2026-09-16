import Foundation

/// Route search that treats every cable as freely rotatable, so it answers
/// "can this net still reach its GPU connector?" in polynomial time.
public enum Solver {
  public struct Step: Hashable, Sendable {
    public var cell: GridPoint
    /// Direction travelled to enter this cell.
    public var entered: Direction
    /// Direction travelled to leave (nil at the sink).
    public var exited: Direction?
  }

  /// Directions a cable can exit given it was entered travelling `entered`.
  static func exits(for kind: TileKind, entered d: Direction) -> [Direction] {
    switch kind {
    case .straight: return [d]
    case .corner: return [d.rotated(by: 1), d.rotated(by: -1)]
    case .tee, .cross: return [d, d.rotated(by: 1), d.rotated(by: -1)]
    default: return []
    }
  }

  /// Shortest cable route for a net, or nil if none exists.
  public static func route(_ board: Board, net: Net, avoidHeat: Bool) -> [Step]? {
    guard let source = board.points.first(where: { board[$0].kind == .source(net) }) else {
      return nil
    }
    let sourceTile = board[source]
    guard let out = sourceTile.openings.first else { return nil }
    let start = source.moved(out)
    guard board.contains(start) else { return nil }
    struct State: Hashable {
      var cell: GridPoint
      var entered: Direction
    }
    var queue: [State] = [State(cell: start, entered: out)]
    var parent: [State: State?] = [State(cell: start, entered: out): nil]
    var head = 0
    var goal: State?
    while head < queue.count {
      let s = queue[head]
      head += 1
      let tile = board[s.cell]
      if case .sink(let n) = tile.kind {
        if n == net, tile.has(s.entered.opposite) { goal = s }
        continue
      }
      guard tile.kind.isCable else { continue }
      if avoidHeat, board.isAdjacentToHeat(s.cell) { continue }
      for exit in exits(for: tile.kind, entered: s.entered) {
        let next = s.cell.moved(exit)
        guard board.contains(next) else { continue }
        let nextState = State(cell: next, entered: exit)
        if parent[nextState] != nil { continue }
        let nextKind = board[next].kind
        guard nextKind.isCable || nextKind == .sink(net) else { continue }
        parent[nextState] = .some(s)
        queue.append(nextState)
      }
      if goal != nil { break }
    }
    guard let found = goal else { return nil }
    var chain: [State] = []
    var cursor: State? = found
    while let c = cursor {
      chain.append(c)
      cursor = parent[c] ?? nil
    }
    chain.reverse()
    var steps: [Step] = []
    for (i, s) in chain.enumerated() {
      let exited: Direction? = i + 1 < chain.count ? chain[i + 1].entered : nil
      steps.append(Step(cell: s.cell, entered: s.entered, exited: exited))
    }
    return steps
  }

  public static func isSolvable(_ board: Board, avoidHeat: Bool) -> Bool {
    board.level.nets.allSatisfy { route(board, net: $0, avoidHeat: avoidHeat) != nil }
  }

  /// Total clockwise taps needed to realize the found routes from the current orientation.
  public static func par(_ board: Board) -> Int? {
    var total = 0
    for net in board.level.nets {
      guard
        let steps = route(board, net: net, avoidHeat: true)
          ?? route(board, net: net, avoidHeat: false)
      else { return nil }
      for step in steps {
        let tile = board[step.cell]
        guard tile.kind.isCable, let exit = step.exited else { continue }
        let required: Set<Direction> = [step.entered.opposite, exit]
        guard let turns = tile.turnsToInclude(required) else { return nil }
        total += turns
      }
    }
    return total
  }
}
