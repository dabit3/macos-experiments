import Foundation

struct Transfer: Codable, Equatable {
  let source: Int
  let destination: Int
}

enum PourError: String, Error {
  case sameVessel = "Choose a different vessel."
  case empty = "This vessel is empty. Select a color first."
  case full = "That vessel is full. Try an empty one."
  case mismatch = "Colors must match. Try an empty vessel instead."
  case invalidIndex = "Choose a vessel on the board."
}

struct Puzzle: Codable, Equatable {
  static let capacity = 4
  private(set) var vessels: [[Int]]
  private(set) var history: [[[Int]]] = []

  var moves: Int { history.count }
  var isSolved: Bool {
    vessels.allSatisfy { $0.isEmpty || ($0.count == Self.capacity && Set($0).count == 1) }
  }

  func amount(from source: Int, to destination: Int) throws -> Int {
    guard vessels.indices.contains(source), vessels.indices.contains(destination) else {
      throw PourError.invalidIndex
    }
    guard source != destination else { throw PourError.sameVessel }
    guard let color = vessels[source].last else { throw PourError.empty }
    guard vessels[destination].count < Self.capacity else { throw PourError.full }
    guard vessels[destination].last == nil || vessels[destination].last == color else {
      throw PourError.mismatch
    }
    let run = vessels[source].reversed().prefix { $0 == color }.count
    return min(run, Self.capacity - vessels[destination].count)
  }

  @discardableResult
  mutating func pour(from source: Int, to destination: Int) throws -> Int {
    let count = try amount(from: source, to: destination)
    history.append(vessels)
    let colors = vessels[source].suffix(count)
    vessels[destination].append(contentsOf: colors)
    vessels[source].removeLast(count)
    return count
  }

  mutating func undo() {
    guard let previous = history.popLast() else { return }
    vessels = previous
  }

  func isValid(for level: Study) -> Bool {
    let inventory = level.vessels.flatMap { $0 }.sorted()
    return ([vessels] + history).allSatisfy { board in
      board.count == level.vessels.count
        && board.allSatisfy { $0.count <= Self.capacity }
        && board.flatMap { $0 }.sorted() == inventory
    }
  }
}

struct Study: Identifiable {
  let id: Int
  let name: String
  let vessels: [[Int]]
  let solution: [Transfer]

  var chapter: Int { id / 4 }
  var number: String { String(format: "%02d", id + 1) }
  var pigmentCount: Int { Set(vessels.flatMap { $0 }).count }

  static let chapterNames = ["First light", "Earth & air", "After hours"]
  static let chapterNotes = [
    "Small beginnings. Beautiful order.",
    "Warm color. Deeper balance.",
    "Rich pigments. A little more mystery.",
  ]
  static let names = [
    "A quiet beginning", "Warm company", "Blue hour", "Soft symmetry",
    "Terracotta", "Still water", "Golden interval", "Grounded",
    "Velvet evening", "Between colors", "Night garden", "Perfect balance",
  ]

  static let all: [Study] = (0..<12).map { index in
    if index == 0 {
      return Study(
        id: 0, name: names[0],
        vessels: [[0, 0, 1, 1], [1, 1, 0, 0], [], []],
        solution: [
          Transfer(source: 0, destination: 2),
          Transfer(source: 1, destination: 0),
          Transfer(source: 2, destination: 1),
        ])
    }
    return generated(index: index)
  }

  private static func generated(index: Int) -> Study {
    let count = index < 4 ? 3 : (index < 8 ? 4 : 5)
    var board = (0..<count).map { Array(repeating: $0, count: 4) } + [[], []]
    var random = SeededRandom(state: UInt64(index + 1) * 7919)
    var reverse: [Transfer] = []
    var seen: Set<[[Int]]> = [board]
    for _ in 0..<(10 + index * 3) {
      var candidates: [([[Int]], Transfer)] = []
      for source in board.indices {
        guard let color = board[source].last else { continue }
        let run = board[source].reversed().prefix { $0 == color }.count
        for destination in board.indices where source != destination {
          let space = 4 - board[destination].count
          guard space > 0, board[destination].last != color else { continue }
          for amount in 1...min(run, space) {
            var next = board
            next[source].removeLast(amount)
            guard next[source].last == nil || next[source].last == color else {
              continue
            }
            next[destination].append(contentsOf: Array(repeating: color, count: amount))
            if !seen.contains(next) {
              candidates.append((next, Transfer(source: destination, destination: source)))
            }
          }
        }
      }
      guard !candidates.isEmpty else { break }
      let choice = candidates[Int(random.next() % UInt64(candidates.count))]
      board = choice.0
      reverse.append(choice.1)
      seen.insert(board)
    }
    return Study(id: index, name: names[index], vessels: board, solution: reverse.reversed())
  }
}

private struct SeededRandom {
  var state: UInt64
  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

struct SavedCollection: Codable {
  var currentLevel = 0
  var puzzles: [Int: Puzzle] = [:]
  var bestMoves: [Int: Int] = [:]
  var symbols = false
  var haptics = true

  var isValid: Bool {
    Study.all.indices.contains(currentLevel)
      && puzzles.allSatisfy { id, puzzle in
        Study.all.indices.contains(id) && puzzle.isValid(for: Study.all[id])
      }
      && bestMoves.allSatisfy { Study.all.indices.contains($0.key) && $0.value > 0 }
  }
}
