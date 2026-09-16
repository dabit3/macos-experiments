import Foundation

/// Which electrical net a cable carries. Power is the 12VHPWR feed; PCIe is the data lane.
public enum Net: Int, CaseIterable, Codable, Hashable, Sendable {
  case power = 0
  case pcie = 1

  public var label: String {
    switch self {
    case .power: return "12VHPWR"
    case .pcie: return "PCIe x16"
    }
  }
}

public enum TileKind: Codable, Hashable, Sendable {
  case empty
  case straight
  case corner
  case tee
  case cross
  case source(Net)
  case sink(Net)
  case hot
  case slag

  /// Openings in the tile's base orientation (rotation 0).
  public var baseOpenings: Set<Direction> {
    switch self {
    case .empty, .hot, .slag: return []
    case .straight: return [.up, .down]
    case .corner: return [.up, .right]
    case .tee: return [.up, .right, .down]
    case .cross: return [.up, .right, .down, .left]
    case .source, .sink: return [.right]
    }
  }

  public var isCable: Bool {
    switch self {
    case .straight, .corner, .tee, .cross: return true
    default: return false
    }
  }

  /// Number of distinct orientations before the openings repeat.
  public var symmetry: Int {
    switch self {
    case .straight: return 2
    case .corner, .tee, .source, .sink: return 4
    default: return 1
    }
  }

  public var isRotatable: Bool { isCable }

  public var netOfTerminal: Net? {
    switch self {
    case .source(let n), .sink(let n): return n
    default: return nil
    }
  }
}

public struct Tile: Codable, Hashable, Sendable {
  public var kind: TileKind
  /// Cumulative clockwise quarter turns; only `rotation % 4` affects openings.
  /// Kept cumulative so animated views can spin continuously.
  public var rotation: Int
  /// 0...1 thermal load. Reaching 1 turns the tile into slag.
  public var heat: Double

  public init(_ kind: TileKind, rotation: Int = 0, heat: Double = 0) {
    self.kind = kind
    self.rotation = rotation
    self.heat = heat
  }

  public var openings: Set<Direction> {
    Set(kind.baseOpenings.map { $0.rotated(by: rotation) })
  }

  public func has(_ direction: Direction) -> Bool { openings.contains(direction) }

  public var isRotatable: Bool { kind.isRotatable }

  /// Quarter turns (clockwise) needed so the tile exposes exactly the given openings.
  /// Returns nil if the kind cannot produce that opening set.
  public func turnsToMatch(_ target: Set<Direction>) -> Int? {
    for turns in 0..<4 {
      var copy = self
      copy.rotation += turns
      if copy.openings == target { return turns }
    }
    return nil
  }

  /// Minimum clockwise turns so the tile has at least the given openings.
  public func turnsToInclude(_ required: Set<Direction>) -> Int? {
    for turns in 0..<4 {
      var copy = self
      copy.rotation += turns
      if required.isSubset(of: copy.openings) { return turns }
    }
    return nil
  }
}
