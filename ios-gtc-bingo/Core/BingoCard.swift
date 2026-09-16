import Foundation

public struct SplitMix64: RandomNumberGenerator {
  private var state: UInt64

  public init(seed: UInt64) {
    state = seed
  }

  public mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    return value ^ (value >> 31)
  }
}

public struct BingoCard: Codable, Equatable {
  public let cells: [String]
  public var marked: Set<Int>
  public let seed: UInt64
  public var bingoAwarded: Bool

  public init(seed: UInt64, deck: [String] = BingoDeck.tropes) {
    var generator = SplitMix64(seed: seed)
    var shuffled = deck
    shuffled.shuffle(using: &generator)
    var selected = Array(shuffled.prefix(25))
    if selected.count == 25 {
      selected[12] = "GPU FREE SPACE"
    }
    cells = selected
    marked = [12]
    self.seed = seed
    bingoAwarded = false
  }

  public static let lines: [[Int]] = {
    let rows = (0..<5).map { row in (0..<5).map { row * 5 + $0 } }
    let columns = (0..<5).map { column in (0..<5).map { $0 * 5 + column } }
    return rows + columns + [[0, 6, 12, 18, 24], [4, 8, 12, 16, 20]]
  }()

  public var completedLines: [[Int]] {
    Self.lines.filter { line in line.allSatisfy(marked.contains) }
  }

  public var hasBingo: Bool {
    !completedLines.isEmpty
  }

  public var markedCount: Int {
    marked.count
  }

  public mutating func toggle(_ index: Int) {
    guard cells.indices.contains(index), index != 12 else { return }
    if marked.contains(index) {
      marked.remove(index)
    } else {
      marked.insert(index)
    }
  }

  public func wouldCompleteLine(byMarking index: Int) -> Bool {
    guard cells.indices.contains(index), !marked.contains(index), index != 12 else { return false }
    return Self.lines.contains { line in
      line.contains(index) && line.allSatisfy { $0 == index || marked.contains($0) }
    }
  }
}
