import Foundation

/// The 10x20 silicon die. Cells hold the kernel that locked there, or nil.
public struct Board: Equatable, Codable, Sendable {
  public static let width = 10
  public static let height = 20
  /// Hidden rows above the visible die where pieces spawn.
  public static let buffer = 2

  public private(set) var cells: [[Kernel?]]

  public init() {
    cells = Array(
      repeating: Array(repeating: nil, count: Board.width),
      count: Board.height + Board.buffer)
  }

  public var totalRows: Int { cells.count }

  public subscript(_ cell: Cell) -> Kernel? {
    get { cells[cell.row][cell.col] }
    set { cells[cell.row][cell.col] = newValue }
  }

  public func contains(_ cell: Cell) -> Bool {
    cell.row >= 0 && cell.row < totalRows && cell.col >= 0 && cell.col < Board.width
  }

  public func isFree(_ cell: Cell) -> Bool {
    contains(cell) && cells[cell.row][cell.col] == nil
  }

  public func fits(_ piece: Piece) -> Bool {
    piece.cells.allSatisfy(isFree)
  }

  public mutating func lock(_ piece: Piece) {
    for c in piece.cells where contains(c) { cells[c.row][c.col] = piece.kernel }
  }

  /// Indices of completely filled rows.
  public func fullRows() -> [Int] {
    cells.indices.filter { row in cells[row].allSatisfy { $0 != nil } }
  }

  /// Removes the given rows and drops everything above. Returns count cleared.
  @discardableResult
  public mutating func clear(rows: [Int]) -> Int {
    guard !rows.isEmpty else { return 0 }
    let set = Set(rows)
    var kept = cells.enumerated().filter { !set.contains($0.offset) }.map(\.element)
    let empty: [Kernel?] = Array(repeating: nil, count: Board.width)
    while kept.count < totalRows { kept.insert(empty, at: 0) }
    cells = kept
    return rows.count
  }

  /// True if any locked cell sits in the hidden buffer (topped out).
  public var isToppedOut: Bool {
    (0..<Board.buffer).contains { row in cells[row].contains { $0 != nil } }
  }

  /// Number of filled cells in the visible area.
  public var occupiedCount: Int {
    cells.dropFirst(Board.buffer).reduce(0) { $0 + $1.compactMap { $0 }.count }
  }

  /// Height of the tallest visible column (0 = empty die).
  public var stackHeight: Int {
    for row in 0..<totalRows where cells[row].contains(where: { $0 != nil }) {
      return totalRows - row
    }
    return 0
  }
}
