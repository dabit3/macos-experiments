import Foundation

struct Cell: Hashable, Codable {
  var x: Int
  var y: Int
}

enum Ingredient: String, Codable, CaseIterable {
  case salmon, tamago, onigiri, citrus, strawberry

  var isSweet: Bool { self == .citrus || self == .strawberry }
  var name: String {
    switch self {
    case .salmon: "Salmon"
    case .tamago: "Tamago"
    case .onigiri: "Onigiri"
    case .citrus: "Mandarin"
    case .strawberry: "Strawberry"
    }
  }
}

struct FoodPiece: Identifiable, Codable, Equatable {
  let id: String
  let ingredient: Ingredient
  let cells: [Cell]
  let solution: Cell

  func anchor(placingMarkedCellAt target: Cell, turns: Int) -> Cell {
    let marked = rotated(turns).first ?? Cell(x: 0, y: 0)
    return Cell(x: target.x - marked.x, y: target.y - marked.y)
  }

  func rotated(_ turns: Int) -> [Cell] {
    var result = cells
    for _ in 0..<((turns % 4 + 4) % 4) {
      result = result.map { Cell(x: -$0.y, y: $0.x) }
    }
    let minX = result.map(\.x).min() ?? 0
    let minY = result.map(\.y).min() ?? 0
    return result.map { Cell(x: $0.x - minX, y: $0.y - minY) }
      .sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }
  }
}

struct Lunch: Identifiable {
  let id: String
  let number: Int
  let title: String
  let subtitle: String
  let width: Int
  let height: Int
  let divider: Int
  let pieces: [FoodPiece]
  let initialTurns: Int
  let isDaily: Bool
  var par: Int { pieces.count }
  var moveLimit: Int { par + (number < 4 ? 4 : 3) }

  init(
    number: Int, title: String, subtitle: String, rows: [String],
    dailyID: String? = nil, initialTurns: Int = 0
  ) {
    self.number = number
    self.title = title
    self.subtitle = subtitle
    self.id = dailyID ?? "lunch-\(number)"
    self.isDaily = dailyID != nil
    self.initialTurns = initialTurns
    width = rows[0].count
    height = rows.count
    divider = width - 2
    var groups: [String: [Cell]] = [:]
    for (y, row) in rows.enumerated() {
      for (x, letter) in row.enumerated() {
        groups[String(letter), default: []].append(Cell(x: x, y: y))
      }
    }
    let savory: [Ingredient] = [.salmon, .tamago, .onigiri]
    var savoryIndex = 0
    var sweetIndex = 0
    let boundary = divider
    pieces = groups.keys.sorted().map { key in
      let cells = groups[key] ?? []
      let minX = cells.map(\.x).min() ?? 0
      let minY = cells.map(\.y).min() ?? 0
      let sweet = minX >= boundary
      let ingredient =
        sweet
        ? (sweetIndex.isMultiple(of: 2) ? Ingredient.citrus : .strawberry)
        : savory[savoryIndex % savory.count]
      if sweet { sweetIndex += 1 } else { savoryIndex += 1 }
      return FoodPiece(
        id: key, ingredient: ingredient,
        cells: cells.map { Cell(x: $0.x - minX, y: $0.y - minY) },
        solution: Cell(x: minX, y: minY)
      )
    }
  }
}

enum LunchBook {
  static let layouts: [[String]] = [
    ["AAXX", "ABXY", "BBYY"],
    ["AAXX", "AAXY", "BBZY", "BBZZ"],
    ["AAAXX", "ABBXX", "CBBYY", "CCCYY"],
    ["ABBDXX", "AABDXY", "ACCDYY", "CCCDZZ"],
    ["AAADXX", "ABBDYX", "CBBDYZ", "CCCDZZ"],
    ["AABBXX", "ACCBXY", "ACCBZY", "DDDDZZ"],
    ["AAADXX", "ABBDYX", "CCBDYY", "CCBDZZ"],
    ["AABBXX", "ACCBXY", "ACCBYY", "ADDDZZ"],
    ["AAABXX", "ACBBXY", "CCDBYY", "DDDDZZ"],
    ["ABBDXX", "ABDDXY", "ACDDYY", "ACCCZZ"],
    ["AAABXX", "CABBXX", "CCDBYY", "CDDDZY", "EEEEZZ"],
    ["AABBXX", "ACBDXX", "ACDDYY", "EEFDYY", "EGFFZZ"],
  ]
  static let names = [
    ("First departure", "A little lunch. A lovely beginning."),
    ("Morning market", "Fresh fruit for the slow train."),
    ("Kyoto gardens", "Leave a little room for quiet."),
    ("Coastal express", "A taste of the sea, neatly packed."),
    ("Golden hour", "Sunshine in every compartment."),
    ("Paper cranes", "A few folds. A perfect fit."),
    ("Orchard stop", "Something sweet along the way."),
    ("Green carriage", "Every good thing has its place."),
    ("Autumn picnic", "A lunch worth taking the long way."),
    ("Little detour", "An unexpected arrangement."),
    ("Evening lanterns", "Pack gently. The city is waking."),
    ("The last station", "Your most beautiful lunch yet."),
  ]

  static var all: [Lunch] {
    layouts.enumerated().map { index, rows in
      Lunch(
        number: index + 1, title: names[index].0,
        subtitle: names[index].1, rows: rows, initialTurns: index % 4
      )
    }
  }

  static func daily(on date: Date = Date()) -> Lunch {
    let key = dayKey(date)
    let seed = key.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) }
    let index = Int(seed % UInt64(layouts.count - 2)) + 2
    return Lunch(
      number: index + 1, title: "The daily parcel", subtitle: key + " · one lunch, everywhere",
      rows: layouts[index], dailyID: "daily-\(key)", initialTurns: Int(seed % 4)
    )
  }

  static func dayKey(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}

struct Placement: Codable, Equatable {
  let anchor: Cell
  let turns: Int
}

struct TurnSnapshot: Codable {
  let placements: [String: Placement]
  let moves: Int
}

struct PackingGame: Codable {
  let lunchID: String
  var placements: [String: Placement] = [:]
  var moves = 0
  var history: [TurnSnapshot] = []
  var usedGuide = false

  init(lunch: Lunch) { lunchID = lunch.id }

  func cells(for piece: FoodPiece, at placement: Placement) -> [Cell] {
    piece.rotated(placement.turns).map {
      Cell(x: $0.x + placement.anchor.x, y: $0.y + placement.anchor.y)
    }
  }

  func problem(piece: FoodPiece, at placement: Placement, lunch: Lunch) -> String? {
    let target = cells(for: piece, at: placement)
    if target.contains(where: {
      $0.x < 0 || $0.y < 0 || $0.x >= lunch.width || $0.y >= lunch.height
    }) {
      return "Keep the whole piece inside the box."
    }
    if target.contains(where: { ($0.x >= lunch.divider) != piece.ingredient.isSweet }) {
      return piece.ingredient.isSweet
        ? "Fruit belongs in the right compartment." : "Savory pieces belong on the left."
    }
    for other in lunch.pieces where other.id != piece.id {
      if let existing = placements[other.id],
        !Set(cells(for: other, at: existing)).isDisjoint(with: target)
      {
        return "That space is already deliciously occupied."
      }
    }
    return nil
  }

  @discardableResult
  mutating func place(_ piece: FoodPiece, at placement: Placement, lunch: Lunch) -> String? {
    guard !isComplete(lunch), moves < lunch.moveLimit else {
      return "No moves left. Undo or repack."
    }
    if let error = problem(piece: piece, at: placement, lunch: lunch) { return error }
    if let existing = placements[piece.id],
      Set(cells(for: piece, at: existing)) == Set(cells(for: piece, at: placement))
    {
      return "Already neatly placed there."
    }
    history.append(TurnSnapshot(placements: placements, moves: moves))
    placements[piece.id] = placement
    moves += 1
    return nil
  }

  mutating func undo() {
    guard let last = history.popLast() else { return }
    placements = last.placements
    moves = last.moves
  }

  func isComplete(_ lunch: Lunch) -> Bool { placements.count == lunch.pieces.count }
  func isFailed(_ lunch: Lunch) -> Bool { moves >= lunch.moveLimit && !isComplete(lunch) }
  func stars(_ lunch: Lunch) -> Int {
    guard isComplete(lunch) else { return 0 }
    return usedGuide ? 1 : (moves == lunch.par ? 3 : 2)
  }

  func isValid(for lunch: Lunch) -> Bool {
    guard lunchID == lunch.id, moves >= placements.count, moves <= lunch.moveLimit else {
      return false
    }
    return placements.allSatisfy { id, placement in
      guard let piece = lunch.pieces.first(where: { $0.id == id }) else { return false }
      return problem(piece: piece, at: placement, lunch: lunch) == nil
    }
  }
}
