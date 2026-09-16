import Foundation

/// A grid coordinate. `row` 0 is the top of the die; `col` 0 is the left edge.
public struct Cell: Hashable, Codable, Sendable {
  public var row: Int
  public var col: Int
  public init(_ row: Int, _ col: Int) {
    self.row = row
    self.col = col
  }
}

/// The seven kernel shapes. Names are CUDA-flavored but the geometry is classic.
public enum Kernel: Int, CaseIterable, Codable, Sendable {
  case i, o, t, s, z, j, l

  public var name: String {
    switch self {
    case .i: return "I-kernel"
    case .o: return "O-kernel"
    case .t: return "T-kernel"
    case .s: return "S-kernel"
    case .z: return "Z-kernel"
    case .j: return "J-kernel"
    case .l: return "L-kernel"
    }
  }

  /// Cells for rotation state 0, relative to a 4x4 (I) or 3x3 bounding box origin.
  var baseCells: [Cell] {
    switch self {
    case .i: return [Cell(1, 0), Cell(1, 1), Cell(1, 2), Cell(1, 3)]
    case .o: return [Cell(0, 1), Cell(0, 2), Cell(1, 1), Cell(1, 2)]
    case .t: return [Cell(0, 1), Cell(1, 0), Cell(1, 1), Cell(1, 2)]
    case .s: return [Cell(0, 1), Cell(0, 2), Cell(1, 0), Cell(1, 1)]
    case .z: return [Cell(0, 0), Cell(0, 1), Cell(1, 1), Cell(1, 2)]
    case .j: return [Cell(0, 0), Cell(1, 0), Cell(1, 1), Cell(1, 2)]
    case .l: return [Cell(0, 2), Cell(1, 0), Cell(1, 1), Cell(1, 2)]
    }
  }

  var boxSize: Int { self == .i ? 4 : 3 }

  /// Cells for a given rotation (0...3, clockwise), relative to the bounding box origin.
  public func cells(rotation: Int) -> [Cell] {
    let r = ((rotation % 4) + 4) % 4
    if self == .o { return baseCells }
    let n = boxSize
    return baseCells.map { c in
      var cell = c
      for _ in 0..<r {
        // clockwise rotation in an n x n box: (row, col) -> (col, n-1-row)
        cell = Cell(cell.col, n - 1 - cell.row)
      }
      return cell
    }
  }
}

/// A live piece on the board.
public struct Piece: Equatable, Codable, Sendable {
  public var kernel: Kernel
  public var rotation: Int
  public var origin: Cell

  public init(kernel: Kernel, rotation: Int = 0, origin: Cell) {
    self.kernel = kernel
    self.rotation = rotation
    self.origin = origin
  }

  public var cells: [Cell] {
    kernel.cells(rotation: rotation).map { Cell($0.row + origin.row, $0.col + origin.col) }
  }

  public func moved(by dRow: Int, _ dCol: Int) -> Piece {
    var p = self
    p.origin = Cell(origin.row + dRow, origin.col + dCol)
    return p
  }

  public func rotated(by delta: Int) -> Piece {
    var p = self
    p.rotation = (((rotation + delta) % 4) + 4) % 4
    return p
  }
}

/// Super Rotation System wall kicks. Returns offsets (dRow, dCol) tried in order.
public enum SRS {
  /// Offsets in (x, y) screen convention where +y is up, converted to (row, col).
  static func kicks(for kernel: Kernel, from: Int, to: Int) -> [(Int, Int)] {
    if kernel == .o { return [(0, 0)] }
    let table: [[(Int, Int)]]
    if kernel == .i {
      table = [
        [(0, 0), (-1, 0), (2, 0), (-1, 0), (2, 0)],  // 0
        [(-1, 0), (0, 0), (0, 0), (0, 1), (0, -2)],  // R
        [(-1, 1), (1, 1), (-2, 1), (1, 0), (-2, 0)],  // 2
        [(0, 1), (0, 1), (0, 1), (0, -1), (0, 2)],  // L
      ]
    } else {
      table = [
        [(0, 0), (0, 0), (0, 0), (0, 0), (0, 0)],
        [(0, 0), (1, 0), (1, -1), (0, 2), (1, 2)],
        [(0, 0), (0, 0), (0, 0), (0, 0), (0, 0)],
        [(0, 0), (-1, 0), (-1, -1), (0, 2), (-1, 2)],
      ]
    }
    let a = table[from]
    let b = table[to]
    return (0..<5).map { i in
      let dx = a[i].0 - b[i].0
      let dy = a[i].1 - b[i].1
      return (-dy, dx)  // +y up -> row decreases
    }
  }
}
