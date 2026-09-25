import Foundation

enum Direction: Int, CaseIterable {
  case north, east, south, west

  var bit: Int { 1 << rawValue }
  var opposite: Direction { Direction(rawValue: (rawValue + 2) % 4)! }
  var rowOffset: Int { self == .north ? -1 : (self == .south ? 1 : 0) }
  var columnOffset: Int { self == .west ? -1 : (self == .east ? 1 : 0) }

  static func rotate(_ mask: Int, turns: Int) -> Int {
    let normalized = ((turns % 4) + 4) % 4
    return ((mask << normalized) | (mask >> (4 - normalized))) & 15
  }
}

struct CircuitLevel: Identifiable {
  let id: Int
  let name: String
  let subtitle: String
  let size: Int
  let source: Int
  let receivers: [Int]
  let masks: [Int]
  let initialTurns: [Int]

  init(id: Int, name: String, subtitle: String, size: Int, paths: [[Int]]) {
    self.id = id
    self.name = name
    self.subtitle = subtitle
    self.size = size
    let sourceIndex = paths[0][0]
    let receiverIndices = Array(Set(paths.map { $0.last! })).sorted()
    source = sourceIndex
    receivers = receiverIndices
    var connections = Array(repeating: 0, count: size * size)
    for path in paths {
      for (first, second) in zip(path, path.dropFirst()) {
        let direction = Direction.allCases.first {
          first / size + $0.rowOffset == second / size
            && first % size + $0.columnOffset == second % size
        }!
        connections[first] |= direction.bit
        connections[second] |= direction.opposite.bit
      }
    }
    masks = connections
    initialTurns = connections.indices.map { index in
      if connections[index] == 0 || index == sourceIndex || receiverIndices.contains(index) {
        return 0
      }
      return ((index * 7 + id * 3) % 3) + 1
    }
  }

  var receiverCount: Int { receivers.count }
  var activeCount: Int { masks.filter { $0 != 0 }.count }
  var complexity: String { id < 3 ? "FOUNDATIONS" : (id < 7 ? "BRANCHING" : "RESONANCE") }

  func isRotatable(_ index: Int) -> Bool {
    masks.indices.contains(index) && masks[index] != 0
      && index != source && !receivers.contains(index)
  }

  func mask(at index: Int, turns: [Int]) -> Int {
    Direction.rotate(masks[index], turns: turns[index])
  }

  func connected(turns: [Int]) -> [Int: Int] {
    guard turns.count == masks.count else { return [:] }
    var distances = [source: 0]
    var queue = [source]
    var cursor = 0
    while cursor < queue.count {
      let index = queue[cursor]
      cursor += 1
      let mask = mask(at: index, turns: turns)
      for direction in Direction.allCases where mask & direction.bit != 0 {
        let row = index / size + direction.rowOffset
        let column = index % size + direction.columnOffset
        guard (0..<size).contains(row), (0..<size).contains(column) else { continue }
        let neighbor = row * size + column
        guard distances[neighbor] == nil,
          self.mask(at: neighbor, turns: turns) & direction.opposite.bit != 0
        else { continue }
        distances[neighbor] = distances[index]! + 1
        queue.append(neighbor)
      }
    }
    return distances
  }

  func isSolved(turns: [Int]) -> Bool {
    let network = connected(turns: turns)
    return receivers.allSatisfy { network[$0] != nil }
  }

  func nextHint(turns: [Int]) -> Int? {
    let order = connected(turns: Array(repeating: 0, count: masks.count))
    return masks.indices
      .filter { isRotatable($0) && mask(at: $0, turns: turns) != masks[$0] }
      .sorted {
        let left = order[$0, default: Int.max]
        let right = order[$1, default: Int.max]
        return left == right ? $0 < $1 : left < right
      }.first
  }
}

enum Circuits {
  static let all: [CircuitLevel] = [
    CircuitLevel(
      id: 0, name: "First light", subtitle: "Every connection begins with a turn.",
      size: 4, paths: [[8, 9, 5, 6, 10, 11]]),
    CircuitLevel(
      id: 1, name: "Long way home", subtitle: "Let the current take the scenic route.",
      size: 4, paths: [[12, 8, 4, 5, 6, 2, 3, 7, 11, 15]]),
    CircuitLevel(
      id: 2, name: "Split signal", subtitle: "One source. Two destinations.",
      size: 4, paths: [[8, 9, 5, 1, 2, 3], [8, 9, 5, 6, 10, 14, 15]]),
    CircuitLevel(
      id: 3, name: "Switchback", subtitle: "Follow the bends beyond the obvious.",
      size: 5, paths: [[20, 15, 10, 11, 6, 7, 8, 13, 18, 17, 22, 23, 24]]),
    CircuitLevel(
      id: 4, name: "Twin current", subtitle: "Find balance on both sides.",
      size: 5,
      paths: [[22, 17, 12, 7, 6, 5, 0], [22, 17, 12, 7, 8, 9, 4]]),
    CircuitLevel(
      id: 5, name: "Three wishes", subtitle: "A little energy goes a long way.",
      size: 5,
      paths: [
        [10, 11, 12, 7, 2, 3, 4],
        [10, 11, 12, 13, 14],
        [10, 11, 12, 17, 22, 23, 24],
      ]),
    CircuitLevel(
      id: 6, name: "Inner orbit", subtitle: "A circuit can return to where it began.",
      size: 5,
      paths: [
        [10, 11, 6, 7, 8, 13, 18, 17, 16, 11, 12, 7, 2, 3, 4],
        [10, 11, 16, 21, 22, 23, 24],
      ]),
    CircuitLevel(
      id: 7, name: "Afterimage", subtitle: "Trace three signals through the dark.",
      size: 5,
      paths: [
        [20, 15, 16, 11, 6, 1, 2, 3, 4],
        [20, 15, 16, 11, 12, 13, 8, 9],
        [20, 15, 16, 17, 18, 23, 24],
      ]),
    CircuitLevel(
      id: 8, name: "Parallel worlds", subtitle: "Everything is connected, eventually.",
      size: 5,
      paths: [
        [10, 11, 6, 1, 2, 3, 8, 13, 12, 11, 16, 21, 22, 23, 18, 13, 14],
        [10, 11, 6, 7, 8, 9, 4],
        [10, 11, 16, 17, 18, 19, 24],
      ]),
    CircuitLevel(
      id: 9, name: "Full spectrum", subtitle: "Bring the whole instrument to life.",
      size: 5,
      paths: [
        [22, 17, 12, 7, 2, 1, 0],
        [22, 17, 12, 7, 2, 3, 4],
        [22, 17, 12, 11, 6, 5, 10, 15, 20],
        [22, 17, 12, 13, 8, 9, 14, 19, 24],
      ]),
  ]
}

struct CircuitSession: Codable, Equatable {
  var turns: [Int]
  var moves = 0
  var hints = 0

  init(level: CircuitLevel) {
    turns = level.initialTurns
  }

  mutating func rotate(_ index: Int, in level: CircuitLevel) {
    guard level.isRotatable(index), !level.isSolved(turns: turns) else { return }
    turns[index] += 1
    moves += 1
  }

  @discardableResult
  mutating func hint(in level: CircuitLevel) -> Int? {
    guard !level.isSolved(turns: turns), let index = level.nextHint(turns: turns) else {
      return nil
    }
    while level.mask(at: index, turns: turns) != level.masks[index] {
      turns[index] += 1
    }
    hints += 1
    return index
  }

  func isValid(for level: CircuitLevel) -> Bool {
    turns.count == level.masks.count && moves >= 0 && hints >= 0
      && turns.allSatisfy { (0...1_000_000).contains($0) }
      && level.masks.indices.allSatisfy { level.isRotatable($0) || turns[$0] == 0 }
  }
}
