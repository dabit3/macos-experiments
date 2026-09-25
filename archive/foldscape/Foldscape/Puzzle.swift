import Foundation

enum Pace: String, CaseIterable, Codable {
  case gentle, wandering

  var title: String { self == .gentle ? "Gentle" : "Wandering" }
  var steps: Int { self == .gentle ? 6 : 40 }
  var caption: String { self == .gentle ? "A few quiet moves" : "A longer little escape" }
}

struct BoardGeometry {
  let side: Double
  let gap: Double = 6

  func index(x: Double, y: Double) -> Int? {
    guard side > gap * 2, x.isFinite, y.isFinite,
      x >= 0, y >= 0, x < side, y < side
    else { return nil }
    let cell = (side - gap * 2) / 3
    let stride = cell + gap
    let column = Int(x / stride)
    let row = Int(y / stride)
    guard column < 3, row < 3,
      x - Double(column) * stride < cell,
      y - Double(row) * stride < cell
    else { return nil }
    return row * 3 + column
  }
}

struct Puzzle: Codable, Equatable {
  static let solved = Array(1...8) + [0]
  private(set) var tiles: [Int]
  private(set) var initial: [Int]
  private(set) var moves: Int
  let pace: Pace
  private(set) var trail: [[Int]]

  var isComplete: Bool { tiles == Self.solved }
  var blank: Int { tiles.firstIndex(of: 0) ?? 8 }
  var legalIndices: [Int] {
    tiles.indices.filter { Self.adjacent($0, blank) }
  }
  var hintIndex: Int? {
    guard !isComplete, let previous = trail.last,
      let previousBlank = previous.firstIndex(of: 0),
      legalIndices.contains(previousBlank)
    else { return nil }
    return previousBlank
  }

  init<R: RandomNumberGenerator>(pace: Pace, generator: inout R) {
    self.pace = pace
    tiles = Self.solved
    initial = Self.solved
    moves = 0
    trail = []
    var previousBlank: Int?
    for _ in 0..<pace.steps {
      let choices = legalIndices.filter { $0 != previousBlank }
      guard let target = choices.randomElement(using: &generator) else { continue }
      let oldBlank = blank
      trail.append(tiles)
      tiles.swapAt(target, oldBlank)
      previousBlank = oldBlank
    }
    if isComplete {
      let target = legalIndices[0]
      trail.append(tiles)
      tiles.swapAt(target, blank)
    }
    initial = tiles
  }

  @discardableResult
  mutating func move(at index: Int) -> Bool {
    guard !isComplete, legalIndices.contains(index) else { return false }
    var next = tiles
    next.swapAt(index, blank)
    if let found = trail.lastIndex(of: next) {
      trail.removeSubrange(found...)
    } else {
      trail.append(tiles)
    }
    tiles = next
    moves += 1
    return true
  }

  static func adjacent(_ first: Int, _ second: Int) -> Bool {
    abs(first / 3 - second / 3) + abs(first % 3 - second % 3) == 1
  }

  static func isSolvable(_ tiles: [Int]) -> Bool {
    guard tiles.sorted() == Array(0...8) else { return false }
    let values = tiles.filter { $0 != 0 }
    var inversions = 0
    for i in values.indices {
      for j in values.indices where j > i && values[i] > values[j] {
        inversions += 1
      }
    }
    return inversions.isMultiple(of: 2)
  }

  var isValid: Bool {
    guard moves >= 0, Self.isSolvable(tiles), Self.isSolvable(initial),
      trail.count <= 200_000, trail.first == Self.solved || isComplete
    else { return false }
    let chain = trail + [tiles]
    return zip(chain, chain.dropFirst()).allSatisfy { first, second in
      guard Self.isSolvable(first), Self.isSolvable(second),
        let a = first.firstIndex(of: 0), let b = second.firstIndex(of: 0),
        Self.adjacent(a, b)
      else { return false }
      var moved = first
      moved.swapAt(a, b)
      return moved == second
    }
  }
}

struct Completion: Codable, Equatable {
  var count: Int
  var bestMoves: Int
  var lastCompleted: Date
}

struct SavedAtlas: Codable {
  var puzzles: [String: Puzzle] = [:]
  var completions: [String: Completion] = [:]
}

@MainActor
final class AtlasStore: ObservableObject {
  @Published private(set) var saved: SavedAtlas
  @Published var saveError = false
  private let defaults: UserDefaults
  static let storageKey = "foldscape.atlas.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: Self.storageKey),
      var decoded = try? JSONDecoder().decode(SavedAtlas.self, from: data)
    {
      decoded.puzzles = decoded.puzzles.filter { $0.value.isValid }
      decoded.completions = decoded.completions.filter {
        $0.value.count > 0 && $0.value.bestMoves > 0
      }
      saved = decoded
    } else {
      saved = SavedAtlas()
    }
  }

  func begin(_ id: String, pace: Pace) {
    var generator = SystemRandomNumberGenerator()
    saved.puzzles[id] = Puzzle(pace: pace, generator: &generator)
    persist()
  }

  @discardableResult
  func move(_ id: String, at index: Int) -> Bool {
    guard var puzzle = saved.puzzles[id], puzzle.move(at: index) else { return false }
    saved.puzzles[id] = puzzle
    if puzzle.isComplete {
      let old = saved.completions[id]
      saved.completions[id] = Completion(
        count: (old?.count ?? 0) + 1,
        bestMoves: min(old?.bestMoves ?? Int.max, puzzle.moves), lastCompleted: Date())
    }
    persist()
    return true
  }

  func reset() {
    saved = SavedAtlas()
    persist()
  }

  func persist() {
    do {
      defaults.set(try JSONEncoder().encode(saved), forKey: Self.storageKey)
      saveError = false
    } catch {
      saveError = true
    }
  }
}
