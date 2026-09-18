import Foundation

struct Cell: Codable, Equatable, Hashable {
  var x: Int
  var y: Int
}

enum Jewel: Int, Codable, CaseIterable, Sendable {
  case cyan = 1
  case gold, violet, green, rose, blue, amber

  var cells: [Cell] {
    switch self {
    case .cyan: return [Cell(x: 0, y: 1), Cell(x: 1, y: 1), Cell(x: 2, y: 1), Cell(x: 3, y: 1)]
    case .gold: return [Cell(x: 1, y: 0), Cell(x: 2, y: 0), Cell(x: 1, y: 1), Cell(x: 2, y: 1)]
    case .violet: return [Cell(x: 1, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1), Cell(x: 2, y: 1)]
    case .green: return [Cell(x: 1, y: 0), Cell(x: 2, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1)]
    case .rose: return [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 1, y: 1), Cell(x: 2, y: 1)]
    case .blue: return [Cell(x: 0, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1), Cell(x: 2, y: 1)]
    case .amber: return [Cell(x: 2, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1), Cell(x: 2, y: 1)]
    }
  }
}

struct Piece: Codable, Equatable {
  var jewel: Jewel
  var rotation = 0
  var x = 3
  var y = 1

  var cells: [Cell] {
    var result = jewel.cells
    if jewel != .gold {
      let size = jewel == .cyan ? 3 : 2
      for _ in 0..<rotation {
        result = result.map { Cell(x: size - $0.y, y: $0.x) }
      }
    }
    return result.map { Cell(x: $0.x + x, y: $0.y + y) }
  }
}

struct SeededRandom: RandomNumberGenerator, Codable {
  var state: UInt64

  mutating func next() -> UInt64 {
    state &+= 0x9e37_79b9_7f4a_7c15
    var z = state
    z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
    z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
    return z ^ (z >> 31)
  }
}

struct PrismEngine: Codable, Equatable {
  static let columns = 10
  static let rows = 22
  var board = Array(repeating: Array(repeating: 0, count: columns), count: rows)
  var active: Piece?
  var held: Jewel?
  var queue: [Jewel] = []
  var canHold = true
  var score = 0
  var lines = 0
  var pieces = 0
  var combo = -1
  var backToBack = false
  var isOver = false
  var lastClear = 0
  var clearedRows: [Int] = []
  var clearSerial = 0
  var lockSerial = 0
  var gravityClock = 0.0
  var lockClock = 0.0
  var lockResets = 0
  var random: SeededRandom

  var level: Int { lines / 10 + 1 }
  var gravityInterval: Double { max(0.07, 0.85 * pow(0.80, Double(level - 1))) }
  var ghost: Piece? {
    guard var piece = active else { return nil }
    while fits(shifted(piece, dx: 0, dy: 1)) { piece.y += 1 }
    return piece
  }

  init(seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
    random = SeededRandom(state: seed)
    refill()
    spawn()
  }

  static func == (lhs: PrismEngine, rhs: PrismEngine) -> Bool {
    lhs.board == rhs.board && lhs.active == rhs.active && lhs.queue == rhs.queue
      && lhs.held == rhs.held && lhs.score == rhs.score && lhs.lines == rhs.lines
      && lhs.isOver == rhs.isOver && lhs.random.state == rhs.random.state
  }

  func fits(_ piece: Piece) -> Bool {
    piece.cells.allSatisfy {
      $0.x >= 0 && $0.x < Self.columns && $0.y >= 0 && $0.y < Self.rows
        && board[$0.y][$0.x] == 0
    }
  }

  func shifted(_ piece: Piece, dx: Int, dy: Int) -> Piece {
    var result = piece
    result.x += dx
    result.y += dy
    return result
  }

  @discardableResult
  mutating func move(_ dx: Int) -> Bool {
    guard !isOver, let piece = active else { return false }
    let moved = shifted(piece, dx: dx, dy: 0)
    guard fits(moved) else { return false }
    resetLockAfterAction(piece)
    active = moved
    return true
  }

  @discardableResult
  mutating func rotate(clockwise: Bool = true) -> Bool {
    guard !isOver, let piece = active, piece.jewel != .gold else { return false }
    var rotated = piece
    rotated.rotation = (piece.rotation + (clockwise ? 1 : 3)) % 4
    for kick in kicks(jewel: piece.jewel, from: piece.rotation, to: rotated.rotation) {
      let candidate = shifted(rotated, dx: kick.x, dy: -kick.y)
      if fits(candidate) {
        resetLockAfterAction(piece)
        active = candidate
        return true
      }
    }
    return false
  }

  @discardableResult
  mutating func softDrop() -> Bool {
    guard !isOver, let piece = active else { return false }
    let candidate = shifted(piece, dx: 0, dy: 1)
    guard fits(candidate) else { return false }
    active = candidate
    score += 1
    gravityClock = 0
    return true
  }

  mutating func hardDrop() {
    guard !isOver, let piece = active, let landing = ghost else { return }
    score += 2 * (landing.y - piece.y)
    active = landing
    lock()
  }

  mutating func hold() {
    guard !isOver, canHold, let piece = active else { return }
    let previous = held
    held = piece.jewel
    if let previous {
      active = Piece(jewel: previous)
      resetClocks()
      if let active, !fits(active) { isOver = true }
    } else {
      spawn()
    }
    canHold = false
  }

  mutating func tick(_ elapsed: Double) {
    guard !isOver, let piece = active else { return }
    let dt = max(0, min(elapsed, 0.1))
    if !fits(shifted(piece, dx: 0, dy: 1)) {
      lockClock += dt
      if lockClock >= 0.5 { lock() }
      return
    }
    gravityClock += dt
    if gravityClock >= gravityInterval {
      gravityClock -= gravityInterval
      active = shifted(piece, dx: 0, dy: 1)
    }
  }

  mutating func resetLockAfterAction(_ piece: Piece) {
    if !fits(shifted(piece, dx: 0, dy: 1)), lockResets < 15 {
      lockClock = 0
      lockResets += 1
    }
  }

  mutating func lock() {
    guard let piece = active else { return }
    for cell in piece.cells { board[cell.y][cell.x] = piece.jewel.rawValue }
    pieces += 1
    lockSerial += 1
    clearedRows = board.indices.filter { board[$0].allSatisfy { $0 != 0 } }
    lastClear = clearedRows.count
    let scoringLevel = level
    if lastClear > 0 {
      board = board.filter { $0.contains(0) }
      board.insert(
        contentsOf: Array(repeating: Array(repeating: 0, count: Self.columns), count: lastClear),
        at: 0)
      let base = [0, 100, 300, 500, 800][min(4, lastClear)]
      let bonus = lastClear == 4 && backToBack ? base / 2 : 0
      combo += 1
      score += (base + bonus + 50 * combo) * scoringLevel
      backToBack = lastClear == 4
      lines += lastClear
      clearSerial += 1
    } else {
      combo = -1
    }
    canHold = true
    if piece.cells.allSatisfy({ $0.y < 2 }) {
      isOver = true
      active = nil
    } else {
      spawn()
    }
  }

  mutating func resetClocks() {
    gravityClock = 0
    lockClock = 0
    lockResets = 0
  }

  mutating func refill() {
    while queue.count < 8 { queue.append(contentsOf: Jewel.allCases.shuffled(using: &random)) }
  }

  mutating func spawn() {
    refill()
    active = Piece(jewel: queue.removeFirst())
    resetClocks()
    if let active, !fits(active) { isOver = true }
  }

  func kicks(jewel: Jewel, from: Int, to: Int) -> [Cell] {
    let values: [(Int, Int)]
    if jewel == .cyan {
      switch (from, to) {
      case (0, 1), (3, 2): values = [(0, 0), (-2, 0), (1, 0), (-2, -1), (1, 2)]
      case (1, 0), (2, 3): values = [(0, 0), (2, 0), (-1, 0), (2, 1), (-1, -2)]
      case (1, 2), (0, 3): values = [(0, 0), (-1, 0), (2, 0), (-1, 2), (2, -1)]
      default: values = [(0, 0), (1, 0), (-2, 0), (1, -2), (-2, 1)]
      }
    } else {
      switch (from, to) {
      case (0, 1), (2, 1): values = [(0, 0), (-1, 0), (-1, 1), (0, -2), (-1, -2)]
      case (1, 0), (1, 2): values = [(0, 0), (1, 0), (1, -1), (0, 2), (1, 2)]
      case (2, 3), (0, 3): values = [(0, 0), (1, 0), (1, 1), (0, -2), (1, -2)]
      default: values = [(0, 0), (-1, 0), (-1, -1), (0, 2), (-1, 2)]
      }
    }
    return values.map { Cell(x: $0.0, y: $0.1) }
  }
}
