import CoreGraphics
import Foundation

enum InkTone: String, Codable, CaseIterable {
  case ink, sage, honey, rose, paper

  var name: String {
    switch self {
    case .ink: "Atlantic"
    case .sage: "Sage"
    case .honey: "Marigold"
    case .rose: "Clay"
    case .paper: "Chalk"
    }
  }

  var fill: String {
    switch self {
    case .ink: "#244858"
    case .sage: "#DBE6DA"
    case .honey: "#F2D791"
    case .rose: "#ECD3C8"
    case .paper: "#FFFEF9"
    }
  }

  var line: String {
    switch self {
    case .ink, .paper: "#244858"
    case .sage: "#527565"
    case .honey: "#A87826"
    case .rose: "#AC6E5B"
    }
  }
}

enum ElementKind: String, Codable {
  case card, ellipse, text, stroke
}

struct BoardElement: Codable, Equatable, Identifiable {
  var id = UUID()
  var kind: ElementKind
  var frame: CGRect
  var text: String = ""
  var detail: String = ""
  var tone: InkTone = .paper
  var points: [CGPoint] = []
  var lineWidth: CGFloat = 3

  var center: CGPoint { CGPoint(x: frame.midX, y: frame.midY) }
}

struct Connection: Codable, Equatable, Identifiable {
  var id = UUID()
  var from: UUID
  var to: UUID
  var tone: InkTone = .ink
}

struct Board: Codable, Equatable, Identifiable {
  var id = UUID()
  var title: String
  var subtitle: String
  var elements: [BoardElement] = []
  var connections: [Connection] = []
  var updated = Date()

  var contentBounds: CGRect {
    elements.reduce(CGRect.null) { $0.union($1.frame) }
  }

  mutating func remove(_ id: UUID) {
    elements.removeAll { $0.id == id }
    connections.removeAll { $0.from == id || $0.to == id }
  }

  mutating func connect(_ from: UUID, _ to: UUID, tone: InkTone) {
    guard from != to,
      elements.contains(where: { $0.id == from && $0.kind != .stroke }),
      elements.contains(where: { $0.id == to && $0.kind != .stroke }),
      !connections.contains(where: { $0.from == from && $0.to == to })
    else { return }
    connections.append(Connection(from: from, to: to, tone: tone))
  }

  func endpoints(for connection: Connection) -> (CGPoint, CGPoint)? {
    guard let from = elements.first(where: { $0.id == connection.from }),
      let to = elements.first(where: { $0.id == connection.to })
    else { return nil }
    return (
      Geometry.anchor(on: from.frame, toward: to.center, ellipse: from.kind == .ellipse),
      Geometry.anchor(on: to.frame, toward: from.center, ellipse: to.kind == .ellipse)
    )
  }
}

enum Geometry {
  static func anchor(on rect: CGRect, toward point: CGPoint, ellipse: Bool = false) -> CGPoint {
    let dx = point.x - rect.midX
    let dy = point.y - rect.midY
    guard abs(dx) + abs(dy) > 0.001 else { return CGPoint(x: rect.maxX, y: rect.midY) }
    let halfWidth = max(rect.width / 2, 1)
    let halfHeight = max(rect.height / 2, 1)
    let divisor =
      ellipse
      ? sqrt(pow(dx / halfWidth, 2) + pow(dy / halfHeight, 2))
      : max(abs(dx) / halfWidth, abs(dy) / halfHeight)
    return CGPoint(x: rect.midX + dx / divisor, y: rect.midY + dy / divisor)
  }

  static func rect(from start: CGPoint, to end: CGPoint, minimum: CGFloat = 60) -> CGRect {
    CGRect(
      x: min(start.x, end.x), y: min(start.y, end.y),
      width: max(minimum, abs(end.x - start.x)),
      height: max(minimum, abs(end.y - start.y))
    )
  }

  static func stroke(_ points: [CGPoint], tone: InkTone, width: CGFloat) -> BoardElement? {
    guard let first = points.first else { return nil }
    let bounds = points.reduce(CGRect(origin: first, size: .zero)) {
      $0.union(CGRect(origin: $1, size: .zero))
    }
    let frame = CGRect(
      x: bounds.minX, y: bounds.minY, width: max(1, bounds.width), height: max(1, bounds.height)
    )
    return BoardElement(
      kind: .stroke, frame: frame, tone: tone,
      points: points.map {
        CGPoint(x: ($0.x - frame.minX) / frame.width, y: ($0.y - frame.minY) / frame.height)
      }, lineWidth: width
    )
  }
}

struct BoardHistory {
  private(set) var undoStack: [Board] = []
  private(set) var redoStack: [Board] = []

  mutating func record(_ previous: Board, current: Board) {
    guard previous != current else { return }
    undoStack.append(previous)
    if undoStack.count > 80 { undoStack.removeFirst() }
    redoStack.removeAll()
  }

  mutating func undo(_ current: Board) -> Board? {
    guard let previous = undoStack.popLast() else { return nil }
    redoStack.append(current)
    return previous
  }

  mutating func redo(_ current: Board) -> Board? {
    guard let next = redoStack.popLast() else { return nil }
    undoStack.append(current)
    return next
  }
}

struct BoardLibrary: Codable {
  var version = 1
  var selectedID: UUID
  var boards: [Board]

  func validated() throws -> BoardLibrary {
    guard version == 1, !boards.isEmpty, Set(boards.map(\.id)).count == boards.count,
      boards.contains(where: { $0.id == selectedID })
    else { throw LibraryError.invalid }
    for board in boards {
      let ids = Set(board.elements.map(\.id))
      guard ids.count == board.elements.count else { throw LibraryError.invalid }
      for element in board.elements {
        let r = element.frame
        guard r.minX.isFinite, r.minY.isFinite, r.width.isFinite, r.height.isFinite,
          r.size.width > 0, r.size.height > 0, element.lineWidth.isFinite, element.lineWidth > 0,
          element.points.allSatisfy({ $0.x.isFinite && $0.y.isFinite })
        else { throw LibraryError.invalid }
      }
      guard
        board.connections.allSatisfy({
          ids.contains($0.from) && ids.contains($0.to) && $0.from != $0.to
        })
      else { throw LibraryError.invalid }
    }
    return self
  }
}

enum LibraryError: Error { case invalid }

enum Samples {
  static func quietCity() -> Board {
    let title = BoardElement(
      kind: .text, frame: CGRect(x: 54, y: 42, width: 680, height: 100),
      text: "The quiet city", detail: "A FIELD GUIDE TO MORE HUMAN PLACES", tone: .ink)
    let north = BoardElement(
      kind: .card, frame: CGRect(x: 65, y: 180, width: 235, height: 142),
      text: "Room to breathe", detail: "Pocket gardens\nA slower way through", tone: .sage)
    let east = BoardElement(
      kind: .card, frame: CGRect(x: 674, y: 176, width: 240, height: 143),
      text: "Small rituals", detail: "Morning markets\nMeet at the corner", tone: .honey)
    let center = BoardElement(
      kind: .ellipse, frame: CGRect(x: 370, y: 290, width: 236, height: 160),
      text: "Make space\nfor life", tone: .ink)
    let west = BoardElement(
      kind: .card, frame: CGRect(x: 75, y: 500, width: 236, height: 140),
      text: "Walk, wander, stay", detail: "Streets at a human pace\nCuriosity over efficiency",
      tone: .paper)
    let south = BoardElement(
      kind: .card, frame: CGRect(x: 684, y: 505, width: 240, height: 142),
      text: "After the rain", detail: "Let water find its way\nDesign with the seasons", tone: .rose
    )
    let annotation = BoardElement(
      kind: .text, frame: CGRect(x: 375, y: 558, width: 230, height: 70),
      text: "Start with one block.", detail: "THEN FOLLOW THE GOOD IDEAS", tone: .sage)
    var board = Board(
      title: "The quiet city", subtitle: "Urban living · Concept study",
      elements: [title, north, east, center, west, south, annotation])
    for item in [north, east, west, south] {
      board.connect(center.id, item.id, tone: .ink)
    }
    if let underline = Geometry.stroke(
      [
        CGPoint(x: 55, y: 132), CGPoint(x: 130, y: 128), CGPoint(x: 215, y: 132),
        CGPoint(x: 306, y: 129),
      ], tone: .honey, width: 7)
    {
      board.elements.append(underline)
    }
    if let flourish = Geometry.stroke(
      [
        CGPoint(x: 420, y: 670), CGPoint(x: 450, y: 681), CGPoint(x: 490, y: 670),
        CGPoint(x: 530, y: 681), CGPoint(x: 559, y: 670),
      ], tone: .sage, width: 2.5)
    {
      board.elements.append(flourish)
    }
    return board
  }

  static func blank(number: Int) -> Board {
    Board(title: "Untitled atlas \(number)", subtitle: "A little room for a big idea")
  }

  static func weekend() -> Board {
    var board = Board(title: "A weekend away", subtitle: "Little adventures · Travel notes")
    let heading = BoardElement(
      kind: .text, frame: CGRect(x: 75, y: 55, width: 700, height: 95),
      text: "Leave room for wonder", detail: "TWO DAYS · NO RUSH · GOOD COMPANY", tone: .ink)
    let one = BoardElement(
      kind: .card, frame: CGRect(x: 110, y: 230, width: 270, height: 165),
      text: "Saturday / coast", detail: "Coffee before sunrise\nThe long trail to the sea",
      tone: .sage)
    let two = BoardElement(
      kind: .card, frame: CGRect(x: 580, y: 230, width: 270, height: 165),
      text: "Sunday / forest", detail: "Find the hidden bookshop\nTake the scenic way home",
      tone: .honey)
    board.elements = [heading, one, two]
    board.connect(one.id, two.id, tone: .ink)
    return board
  }
}
