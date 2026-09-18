import Combine
import Foundation

struct Cell: Codable, Hashable {
  var x: Int
  var y: Int

  func moved(_ direction: Direction) -> Cell {
    Cell(x: x + direction.dx, y: y + direction.dy)
  }
}

enum Direction: String, CaseIterable {
  case up, left, right, down
  var dx: Int { self == .left ? -1 : self == .right ? 1 : 0 }
  var dy: Int { self == .up ? -1 : self == .down ? 1 : 0 }
  var symbol: String { "arrow.\(rawValue)" }
}

struct Room: Identifiable {
  let id: Int
  let title: String
  let subtitle: String
  let story: String
  let light: Int
  let rows: [String]

  var width: Int { rows[0].count }
  var height: Int { rows.count }
  var cells: [Cell] {
    (0..<height).flatMap { y in (0..<width).map { Cell(x: $0, y: y) } }
  }
  func tile(at cell: Cell) -> Character {
    guard cell.y >= 0, cell.y < height, cell.x >= 0, cell.x < width else { return "#" }
    return Array(rows[cell.y])[cell.x]
  }
  var start: Cell { cells.first { tile(at: $0) == "S" } ?? Cell(x: 1, y: 1) }
  var embers: Int { cells.filter { tile(at: $0) == "e" }.count }
  var chapter: String { String(format: "%02d", id + 1) }

  static let all: [Room] = [
    Room(
      id: 0, title: "The First Spark", subtitle: "Learn to carry the light",
      story:
        "Below the sleeping forest, a lantern stirs. Follow the embers. Something still remembers the way.",
      light: 8,
      rows: [
        "#######", "#S.e###", "###.###", "#k..###", "#.#####", "#..D.X#", "#######",
      ]),
    Room(
      id: 1, title: "Hollow Steps", subtitle: "Not every path leads onward",
      story: "Footsteps linger in the hollow. A golden key waits where the passage turns away.",
      light: 10,
      rows: [
        "#########", "#S..#..X#", "#.#.#.#D#", "#.#e..#.#", "#.#####.#",
        "#..k..e.#", "#########",
      ]),
    Room(
      id: 2, title: "The Cinder Well", subtitle: "A little light goes a long way",
      story: "The well has long run dry. In its depths, the last cinders glow.",
      light: 9,
      rows: [
        "#########", "#S...#X##", "###e.#D##", "#k...#.##", "#.####.##",
        "#...e..##", "#########",
      ]),
    Room(
      id: 3, title: "Root & Ruin", subtitle: "Find a way through the dark",
      story: "Roots hold the old stones together. Their shadows hide a small, stubborn warmth.",
      light: 9,
      rows: [
        "#########", "#S..#k..#", "#.#e###.#", "#.#...e.#", "#.#####.#",
        "#...e#..#", "###.##D##", "#.....X##", "#########",
      ]),
    Room(
      id: 4, title: "The Watchtower", subtitle: "Take the long way home",
      story: "Once, this tower guided travelers. Bring its light back to the highest window.",
      light: 10,
      rows: [
        "#########", "#S.e#..X#", "###.#.#D#", "#...#.#.#", "#.###e#.#",
        "#...#.#e#", "###.#.#.#", "#k..e...#", "#########",
      ]),
    Room(
      id: 5, title: "Ashen Garden", subtitle: "Gather what the fire left",
      story: "Nothing flowers here but embers. Pick your way gently through the ashes.",
      light: 8,
      rows: [
        "#########", "#S.e....#", "#.#####.#", "#...#k#e#", "###.#.#.#",
        "#e..e...#", "#.#####D#", "#......X#", "#########",
      ]),
    Room(
      id: 6, title: "The Deep Quiet", subtitle: "Every step is a promise",
      story: "Even the echoes fall silent. Count your steps; trust the warmth in your hands.",
      light: 9,
      rows: [
        "#########", "#S..#k..#", "###e###.#", "#...e...#", "#.#####.#",
        "#e....#e#", "#####.#.#", "#X.D....#", "#########",
      ]),
    Room(
      id: 7, title: "Dawn's Threshold", subtitle: "Bring the night to its end",
      story: "Beyond this door, morning. Carry one last spark into the world above.",
      light: 9,
      rows: [
        "#########", "#S.e....#", "#####.#.#", "#k..#e#.#", "#.#.#.#.#",
        "#e#...#e#", "#.#####.#", "#....D.X#", "#########",
      ]),
  ]
}

enum Outcome: String, Codable { case exploring, escaped, extinguished }

struct Turn: Codable, Equatable {
  var position: Cell
  var light: Int
  var keys = 0
  var collected: Set<Cell> = []
  var opened: Set<Cell> = []
  var revealed: Set<Cell> = []
  var moves = 0
  var outcome: Outcome = .exploring
}

struct Journey: Codable {
  let roomID: Int
  var turn: Turn
  var history: [Turn] = []
  static let capacity = 18
  static let emberFuel = 6
  var room: Room { Room.all[roomID] }

  init(room: Room) {
    roomID = room.id
    turn = Turn(position: room.start, light: room.light)
    reveal()
  }

  mutating func reveal() {
    for cell in room.cells
    where abs(cell.x - turn.position.x) <= 2 && abs(cell.y - turn.position.y) <= 2 {
      turn.revealed.insert(cell)
    }
  }

  @discardableResult
  mutating func move(_ direction: Direction) -> String {
    guard turn.outcome == .exploring else { return "This journey has ended." }
    let destination = turn.position.moved(direction)
    let tile = room.tile(at: destination)
    guard tile != "#" else { return "Stone wall. Try another direction." }
    if tile == "D", !turn.opened.contains(destination), turn.keys == 0 {
      return "A sealed door. Find the golden key."
    }
    history.append(turn)
    turn.position = destination
    turn.moves += 1
    turn.light -= 1
    var message = "One step. One light."
    if tile == "e", !turn.collected.contains(destination) {
      let restored = min(Self.emberFuel, Self.capacity - turn.light)
      turn.light += restored
      turn.collected.insert(destination)
      message = "Ember gathered. +\(restored) light."
    }
    if tile == "k", !turn.collected.contains(destination) {
      turn.keys += 1
      turn.collected.insert(destination)
      message = "Golden key found. The door awaits."
    }
    if tile == "D", !turn.opened.contains(destination) {
      turn.keys -= 1
      turn.opened.insert(destination)
      message = "The door opens. Keep the light alive."
    }
    reveal()
    if tile == "X", turn.light > 0 {
      turn.outcome = .escaped
      message = "You carried the light."
    } else if turn.light <= 0 {
      turn.outcome = .extinguished
      message = "The lantern rests. Your next path awaits."
    }
    return message
  }

  mutating func undo() {
    if let previous = history.popLast() { turn = previous }
  }
}

struct Archive: Codable {
  var unlocked = 0
  var bestMoves: [Int: Int] = [:]
  var journey: Journey?
  var haptics = true
}

@MainActor
final class GameStore: ObservableObject {
  @Published private(set) var archive: Archive
  @Published var message = "Seek the embers. Find the key. Reach the exit."
  private let defaults: UserDefaults
  private static let storageKey = "emberpath.archive.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: Self.storageKey),
      let decoded = try? JSONDecoder().decode(Archive.self, from: data),
      (0..<Room.all.count).contains(decoded.unlocked),
      decoded.journey.map({ (0..<Room.all.count).contains($0.roomID) }) ?? true
    {
      archive = decoded
    } else {
      archive = Archive()
    }
  }

  func save() {
    if let data = try? JSONEncoder().encode(archive) {
      defaults.set(data, forKey: Self.storageKey)
    }
  }

  func start(_ room: Room) {
    guard room.id <= archive.unlocked else { return }
    archive.journey = Journey(room: room)
    message = "Seek the embers. Find the key. Reach the exit."
    save()
  }

  func move(_ direction: Direction) {
    guard var journey = archive.journey else { return }
    message = journey.move(direction)
    archive.journey = journey
    if journey.turn.outcome == .escaped {
      archive.unlocked = max(archive.unlocked, min(Room.all.count - 1, journey.roomID + 1))
      archive.bestMoves[journey.roomID] = min(
        archive.bestMoves[journey.roomID] ?? Int.max, journey.turn.moves)
    }
    save()
  }

  func undo() {
    archive.journey?.undo()
    message = "A step retraced. Light restored."
    save()
  }

  func restart() {
    guard let room = archive.journey?.room else { return }
    start(room)
  }

  func setHaptics(_ enabled: Bool) {
    archive.haptics = enabled
    save()
  }

  func reset() {
    archive = Archive()
    save()
  }
}
