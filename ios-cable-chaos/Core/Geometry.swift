import Foundation

/// Cardinal direction on the board. Raw values increase clockwise so rotation is arithmetic.
public enum Direction: Int, CaseIterable, Codable, Hashable, Sendable {
  case up = 0
  case right, down, left

  public var opposite: Direction { Direction(rawValue: (rawValue + 2) % 4)! }

  /// Rotates clockwise by the given number of quarter turns (negative turns counter-clockwise).
  public func rotated(by quarters: Int) -> Direction {
    Direction(rawValue: ((rawValue + quarters) % 4 + 4) % 4)!
  }

  public var delta: (dx: Int, dy: Int) {
    switch self {
    case .up: return (0, -1)
    case .right: return (1, 0)
    case .down: return (0, 1)
    case .left: return (-1, 0)
    }
  }

  public var isHorizontal: Bool { self == .left || self == .right }
}

public struct GridPoint: Hashable, Codable, Sendable {
  public var x: Int
  public var y: Int
  public init(_ x: Int, _ y: Int) {
    self.x = x
    self.y = y
  }
  public func moved(_ direction: Direction) -> GridPoint {
    let d = direction.delta
    return GridPoint(x + d.dx, y + d.dy)
  }
  public var neighbors: [(Direction, GridPoint)] {
    Direction.allCases.map { ($0, moved($0)) }
  }
}

/// SplitMix64: tiny, fast, deterministic across platforms.
public struct SeededRNG: RandomNumberGenerator, Sendable {
  private var state: UInt64
  public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
  public mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
  public mutating func int(_ range: Range<Int>) -> Int {
    Int.random(in: range, using: &self)
  }
  public mutating func chance(_ probability: Double) -> Bool {
    Double.random(in: 0..<1, using: &self) < probability
  }
}
