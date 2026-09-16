import Foundation

public enum TSpinKind: String, Codable, Sendable {
  case mini, full
}

/// Something that happened during a step; the app layer turns these into sound, haptics, VFX.
public enum GameEvent: Equatable, Sendable {
  case moved
  case rotated(kicked: Bool)
  case blocked
  case softDropped
  case hardDropped(rows: Int)
  case held
  case locked(kernel: Kernel)
  case warpsDispatched(rows: [Int], count: Int, tSpin: TSpinKind?, points: Int)
  case tensorCore(multiplier: Int)
  case perfectClear
  case levelUp(level: Int)
  case gameOver
}

/// Full snapshot of a run. Codable so an in-progress game can be resumed.
public struct GameState: Codable, Equatable, Sendable {
  public var board = Board()
  public var current: Piece?
  public var hold: Kernel?
  public var canHold = true
  public var queue: [Kernel] = []
  public var bag: KernelBag
  public var score = 0
  public var lines = 0
  public var level: Int
  public var startLevel: Int
  public var multiplier = 1
  public var combo = -1
  public var backToBack = false
  public var tensorCores = 0
  public var tSpins = 0
  public var piecesPlaced = 0
  public var elapsed: TimeInterval = 0
  public var isOver = false
  public var lastMoveWasRotation = false
  public var lastKickIndex = 0
  /// Seconds accumulated toward the next gravity step.
  var gravityAccumulator: TimeInterval = 0
  /// Seconds the piece has rested on the stack.
  var lockTimer: TimeInterval = 0
  /// Lock delay resets remaining for the current piece.
  var lockResets = 15
  var lowestRow = 0

  public init(seed: UInt64, startLevel: Int = 1) {
    bag = KernelBag(seed: seed)
    level = max(1, startLevel)
    self.startLevel = level
  }
}

/// Deterministic rules engine. No timers of its own: the app drives `advance(by:)`.
public struct GameEngine: Sendable {
  public static let previewCount = 5
  public static let lockDelay: TimeInterval = 0.5
  public static let softDropFactor: Double = 20

  public private(set) var state: GameState

  public init(seed: UInt64 = UInt64.random(in: 1...UInt64.max), startLevel: Int = 1) {
    state = GameState(seed: seed, startLevel: startLevel)
    while state.queue.count < GameEngine.previewCount { state.queue.append(state.bag.next()) }
    _ = spawn()
  }

  public init(resuming state: GameState) {
    self.state = state
  }

  // MARK: - Derived

  public var board: Board { state.board }
  public var current: Piece? { state.current }
  public var isOver: Bool { state.isOver }

  /// Gravity interval in seconds per row for the current level (Guideline curve).
  public var gravityInterval: TimeInterval {
    let l = Double(min(state.level, 20) - 1)
    return max(0.02, pow(0.8 - l * 0.007, l))
  }

  /// The piece as it would rest if hard-dropped right now.
  public var ghost: Piece? {
    guard let p = state.current else { return nil }
    return dropped(p)
  }

  /// Progress of the lock timer, 0...1. Drives the "about to lock" pulse.
  public var lockProgress: Double {
    guard state.current != nil, isResting else { return 0 }
    return min(1, state.lockTimer / GameEngine.lockDelay)
  }

  var isResting: Bool {
    guard let p = state.current else { return false }
    return !state.board.fits(p.moved(by: 1, 0))
  }

  private func dropped(_ piece: Piece) -> Piece {
    var p = piece
    while state.board.fits(p.moved(by: 1, 0)) { p = p.moved(by: 1, 0) }
    return p
  }

  // MARK: - Time

  /// Advance the simulation. `softDropping` multiplies gravity.
  @discardableResult
  public mutating func advance(by dt: TimeInterval, softDropping: Bool = false) -> [GameEvent] {
    guard !state.isOver, state.current != nil else { return [] }
    var events: [GameEvent] = []
    state.elapsed += dt
    let interval = softDropping ? gravityInterval / GameEngine.softDropFactor : gravityInterval
    state.gravityAccumulator += dt
    var steps = 0
    while state.gravityAccumulator >= interval, steps < 40 {
      state.gravityAccumulator -= interval
      steps += 1
      if let p = state.current, state.board.fits(p.moved(by: 1, 0)) {
        state.current = p.moved(by: 1, 0)
        state.lastMoveWasRotation = false
        if softDropping {
          state.score += 1
          events.append(.softDropped)
        }
        noteDescent()
      } else {
        state.gravityAccumulator = 0
        break
      }
    }
    if isResting {
      state.lockTimer += dt
      if state.lockTimer >= GameEngine.lockDelay {
        events += lockCurrent()
      }
    } else {
      state.lockTimer = 0
    }
    return events
  }

  private mutating func noteDescent() {
    guard let p = state.current else { return }
    if p.origin.row > state.lowestRow {
      state.lowestRow = p.origin.row
      state.lockResets = 15
      state.lockTimer = 0
    }
  }

  private mutating func resetLockDelay() {
    guard state.lockResets > 0 else { return }
    state.lockResets -= 1
    state.lockTimer = 0
  }

  // MARK: - Input

  @discardableResult
  public mutating func move(_ dCol: Int) -> [GameEvent] {
    guard !state.isOver, let p = state.current else { return [] }
    let moved = p.moved(by: 0, dCol)
    guard state.board.fits(moved) else { return [.blocked] }
    state.current = moved
    state.lastMoveWasRotation = false
    resetLockDelay()
    return [.moved]
  }

  @discardableResult
  public mutating func rotate(clockwise: Bool = true) -> [GameEvent] {
    guard !state.isOver, let p = state.current else { return [] }
    let to = (((p.rotation + (clockwise ? 1 : -1)) % 4) + 4) % 4
    let kicks = SRS.kicks(for: p.kernel, from: p.rotation, to: to)
    for (index, kick) in kicks.enumerated() {
      let candidate = p.rotated(by: clockwise ? 1 : -1).moved(by: kick.0, kick.1)
      if state.board.fits(candidate) {
        state.current = candidate
        state.lastMoveWasRotation = true
        state.lastKickIndex = index
        resetLockDelay()
        return [.rotated(kicked: index > 0)]
      }
    }
    return [.blocked]
  }

  @discardableResult
  public mutating func softDropStep() -> [GameEvent] {
    guard !state.isOver, let p = state.current else { return [] }
    let down = p.moved(by: 1, 0)
    guard state.board.fits(down) else { return [] }
    state.current = down
    state.score += 1
    state.lastMoveWasRotation = false
    noteDescent()
    return [.softDropped]
  }

  @discardableResult
  public mutating func hardDrop() -> [GameEvent] {
    guard !state.isOver, let p = state.current else { return [] }
    let landed = dropped(p)
    let rows = landed.origin.row - p.origin.row
    state.current = landed
    if rows > 0 { state.lastMoveWasRotation = false }
    state.score += rows * 2
    var events: [GameEvent] = [.hardDropped(rows: rows)]
    events += lockCurrent()
    return events
  }

  @discardableResult
  public mutating func holdPiece() -> [GameEvent] {
    guard !state.isOver, state.canHold, let p = state.current else { return [.blocked] }
    let previous = state.hold
    state.hold = p.kernel
    state.canHold = false
    if let previous {
      _ = spawn(previous)
    } else {
      _ = spawn()
    }
    return state.isOver ? [.held, .gameOver] : [.held]
  }

  // MARK: - Locking & scoring

  private mutating func lockCurrent() -> [GameEvent] {
    guard let p = state.current else { return [] }
    var events: [GameEvent] = []
    let tSpin = detectTSpin(p)
    state.board.lock(p)
    state.piecesPlaced += 1
    events.append(.locked(kernel: p.kernel))

    let full = state.board.fullRows()
    if !full.isEmpty {
      let count = full.count
      state.board.clear(rows: full)
      state.lines += count
      state.combo += 1
      var base: Int
      switch (tSpin, count) {
      case (.full, 1): base = 800
      case (.full, 2): base = 1200
      case (.full, 3): base = 1600
      case (.mini, 1): base = 200
      case (.mini, 2): base = 400
      case (_, 1): base = 100
      case (_, 2): base = 300
      case (_, 3): base = 500
      default: base = 800
      }
      let isTensor = count == 4
      let difficult = isTensor || tSpin != nil
      if difficult && state.backToBack { base = base * 3 / 2 }
      state.backToBack = difficult
      if isTensor {
        state.tensorCores += 1
        state.multiplier = min(16, state.multiplier * 2)
      } else if tSpin == nil {
        state.multiplier = max(1, state.multiplier / 2)
      }
      if tSpin != nil { state.tSpins += 1 }
      var points = base * state.level * state.multiplier
      if state.combo > 0 { points += 50 * state.combo * state.level }
      if state.board.occupiedCount == 0 {
        points += 2000 * state.level
        events.append(.perfectClear)
      }
      state.score += points
      events.append(.warpsDispatched(rows: full, count: count, tSpin: tSpin, points: points))
      if isTensor { events.append(.tensorCore(multiplier: state.multiplier)) }
      let newLevel = max(state.startLevel, state.lines / 10 + 1)
      if newLevel > state.level {
        state.level = newLevel
        events.append(.levelUp(level: newLevel))
      }
    } else {
      state.combo = -1
      if tSpin != nil {
        // A T-spin with no clear still counts for style: a small bonus.
        state.score += 100 * state.level
        state.tSpins += 1
      }
    }

    if state.board.isToppedOut {
      state.isOver = true
      state.current = nil
      events.append(.gameOver)
      return events
    }
    state.canHold = true
    if !spawn() { events.append(.gameOver) }
    return events
  }

  /// Guideline three-corner T-spin rule.
  private func detectTSpin(_ p: Piece) -> TSpinKind? {
    guard p.kernel == .t, state.lastMoveWasRotation else { return nil }
    let center = Cell(p.origin.row + 1, p.origin.col + 1)
    let corners = [
      Cell(center.row - 1, center.col - 1), Cell(center.row - 1, center.col + 1),
      Cell(center.row + 1, center.col - 1), Cell(center.row + 1, center.col + 1),
    ]
    let filled = corners.map { !state.board.isFree($0) }
    guard filled.filter({ $0 }).count >= 3 else { return nil }
    // Front corners are the two on the side the T points toward.
    let front: [Int]
    switch p.rotation {
    case 0: front = [0, 1]
    case 1: front = [1, 3]
    case 2: front = [2, 3]
    default: front = [0, 2]
    }
    let frontFilled = front.allSatisfy { filled[$0] }
    if frontFilled || state.lastKickIndex == 4 { return .full }
    return .mini
  }

  /// Spawns `kernel` (or the next queued kernel). Returns false if it collides (game over).
  private mutating func spawn(_ kernel: Kernel? = nil) -> Bool {
    let k: Kernel
    if let kernel {
      k = kernel
    } else {
      k = state.queue.removeFirst()
      state.queue.append(state.bag.next())
    }
    var piece = Piece(kernel: k, rotation: 0, origin: Cell(Board.buffer - 1, 3))
    state.lockTimer = 0
    state.lockResets = 15
    state.lowestRow = piece.origin.row
    state.gravityAccumulator = 0
    state.lastMoveWasRotation = false
    state.lastKickIndex = 0
    if !state.board.fits(piece) {
      piece = piece.moved(by: -1, 0)
      if !state.board.fits(piece) {
        state.current = nil
        state.isOver = true
        return false
      }
    }
    state.current = piece
    return true
  }
}
