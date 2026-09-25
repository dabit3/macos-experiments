import Foundation

public struct Cell: Codable, Hashable, Sendable {
  public let x: Int
  public let y: Int
  public init(_ x: Int, _ y: Int) {
    self.x = x
    self.y = y
  }
  public var label: String { "\(UnicodeScalar(65 + x)! )\(y + 1)" }
  public func moved(_ direction: Direction) -> Cell {
    Cell(x + direction.dx, y + direction.dy)
  }
}

public enum Direction: Int, Codable, CaseIterable, Sendable {
  case east, south, west, north
  public var dx: Int { [1, 0, -1, 0][rawValue] }
  public var dy: Int { [0, 1, 0, -1][rawValue] }
  public var left: Direction { Direction(rawValue: (rawValue + 3) % 4)! }
  public var right: Direction { Direction(rawValue: (rawValue + 1) % 4)! }
  public func reflected(slash: Bool) -> Direction {
    if slash { return [.north, .west, .south, .east][rawValue] }
    return [.south, .east, .north, .west][rawValue]
  }
}

public enum Spectrum: String, Codable, CaseIterable, Sendable {
  case white, red, green, blue
  public var title: String {
    switch self {
    case .white: "Pearl"
    case .red: "Coral"
    case .green: "Jade"
    case .blue: "Azure"
    }
  }
}

public enum OpticKind: String, Codable, Sendable { case mirror, prism }

public struct Optic: Identifiable, Sendable {
  public var id: String { cell.label }
  public let cell: Cell
  public let kind: OpticKind
  public let initial: Int
  public var turns: Int { kind == .mirror ? 2 : 4 }
  public init(_ x: Int, _ y: Int, _ kind: OpticKind = .mirror, _ initial: Int = 1) {
    cell = Cell(x, y)
    self.kind = kind
    self.initial = initial
  }
}

public struct Receiver: Identifiable, Sendable {
  public var id: String { cell.label }
  public let cell: Cell
  public let color: Spectrum
  public init(_ x: Int, _ y: Int, _ color: Spectrum) {
    cell = Cell(x, y)
    self.color = color
  }
}

public struct Chamber: Identifiable, Sendable {
  public let id: Int
  public let title: String
  public let subtitle: String
  public let lesson: String
  public let hint: String
  public let source: Cell
  public let color: Spectrum
  public let optics: [Optic]
  public let receivers: [Receiver]
  public let walls: Set<Cell>
  public var initial: [String: Int] {
    Dictionary(uniqueKeysWithValues: optics.map { ($0.id, $0.initial) })
  }
  public func normalized(_ values: [String: Int]) -> [String: Int] {
    Dictionary(
      uniqueKeysWithValues: optics.map {
        let value = values[$0.id] ?? $0.initial
        return ($0.id, (0..<$0.turns).contains(value) ? value : $0.initial)
      })
  }
}

public struct Beam: Sendable {
  public let start: Cell
  public let end: Cell
  public let color: Spectrum
}

public struct Trace: Sendable {
  public let beams: [Beam]
  public let powered: Set<String>
  public let solved: Bool
}

private struct Ray: Hashable {
  let cell: Cell
  let direction: Direction
  let color: Spectrum
}

public enum RayTracer {
  public static func trace(_ chamber: Chamber, orientations: [String: Int]) -> Trace {
    let angles = chamber.normalized(orientations)
    let optics = Dictionary(uniqueKeysWithValues: chamber.optics.map { ($0.cell, $0) })
    let receivers = Dictionary(uniqueKeysWithValues: chamber.receivers.map { ($0.cell, $0) })
    var rays = [Ray(cell: chamber.source, direction: .east, color: chamber.color)]
    var visited = Set<Ray>()
    var beams = [Beam]()
    var powered = Set<String>()
    while let ray = rays.popLast() {
      guard visited.insert(ray).inserted else { continue }
      let next = ray.cell.moved(ray.direction)
      beams.append(Beam(start: ray.cell, end: next, color: ray.color))
      guard (0..<7).contains(next.x), (0..<9).contains(next.y),
        !chamber.walls.contains(next)
      else { continue }
      if let receiver = receivers[next] {
        if receiver.color == ray.color { powered.insert(receiver.id) }
        continue
      }
      guard let optic = optics[next] else {
        rays.append(Ray(cell: next, direction: ray.direction, color: ray.color))
        continue
      }
      let angle = angles[optic.id]!
      if optic.kind == .mirror {
        rays.append(
          Ray(cell: next, direction: ray.direction.reflected(slash: angle == 0), color: ray.color))
      } else if angle == ray.direction.rawValue {
        let colors: [Spectrum] = ray.color == .white ? [.red, .green, .blue] : [ray.color]
        for color in colors {
          let direction =
            color == .red
            ? ray.direction
            : (color == .green ? ray.direction.left : ray.direction.right)
          rays.append(Ray(cell: next, direction: direction, color: color))
        }
      }
    }
    return Trace(
      beams: beams, powered: powered,
      solved: !chamber.receivers.isEmpty && powered.count == chamber.receivers.count)
  }
}

public enum Chambers {
  public static let all: [Chamber] = [
    Chamber(
      id: 0, title: "First light", subtitle: "THE AWAKENING",
      lesson: "Tap the mirror. Give the light a new direction.",
      hint: "A / mirror turns a beam arriving from the left upward. Tap D7 once.",
      source: Cell(-1, 6), color: .white,
      optics: [Optic(3, 6)], receivers: [Receiver(3, 1, .white)],
      walls: [Cell(1, 2), Cell(1, 3), Cell(5, 4), Cell(5, 5)]),
    Chamber(
      id: 1, title: "Quiet corners", subtitle: "THE REFLECTION",
      lesson: "Two turns. One uninterrupted thread of light.",
      hint: "Start at C8, then C4. Each mirror needs a / face: right → up → right.",
      source: Cell(-1, 7), color: .white,
      optics: [Optic(2, 7), Optic(2, 3)], receivers: [Receiver(6, 3, .white)],
      walls: [Cell(4, 6), Cell(5, 6), Cell(4, 1), Cell(4, 2)]),
    Chamber(
      id: 2, title: "A hidden spectrum", subtitle: "THE DISPERSION",
      lesson: "One pearl beam. Three colors waiting to be found.",
      hint:
        "Rotate D5 until its arrow points right. Coral continues; jade turns left; azure turns right.",
      source: Cell(-1, 4), color: .white,
      optics: [Optic(3, 4, .prism)],
      receivers: [
        Receiver(6, 4, .red), Receiver(3, 0, .green), Receiver(3, 8, .blue),
      ], walls: [Cell(1, 1), Cell(1, 2), Cell(5, 6), Cell(5, 7)]),
    Chamber(
      id: 3, title: "Chromatic garden", subtitle: "THE BRANCHING",
      lesson: "Guide each color to the jewel that shares its hue.",
      hint: "Face C5 right. F5 needs / to lift coral; C8 needs \\ to carry azure right.",
      source: Cell(-1, 4), color: .white,
      optics: [Optic(2, 4, .prism), Optic(5, 4), Optic(2, 7, .mirror, 0)],
      receivers: [Receiver(5, 1, .red), Receiver(2, 0, .green), Receiver(6, 7, .blue)],
      walls: [Cell(0, 1), Cell(0, 2), Cell(4, 6), Cell(5, 6)]),
    Chamber(
      id: 4, title: "The long way home", subtitle: "THE CONVERGENCE",
      lesson: "Let the architecture shape the journey.",
      hint:
        "Face D5 right. Coral rises at F5 (/), then turns left at F2 (\\). Jade turns right at D3 (/); azure at D8 (\\).",
      source: Cell(-1, 4), color: .white,
      optics: [
        Optic(3, 4, .prism), Optic(5, 4), Optic(5, 1, .mirror, 0),
        Optic(3, 2), Optic(3, 7, .mirror, 0),
      ],
      receivers: [Receiver(1, 1, .red), Receiver(6, 2, .green), Receiver(6, 7, .blue)],
      walls: [Cell(1, 5), Cell(1, 6), Cell(5, 6)]),
    Chamber(
      id: 5, title: "A perfect resonance", subtitle: "THE FINALE",
      lesson: "Three paths. A chamber held together by light.",
      hint: "Face C6 right. Coral: F6 \\ then F8 /. Jade: C3 /, F3 \\, F5 /. Azure: C9 \\.",
      source: Cell(-1, 5), color: .white,
      optics: [
        Optic(2, 5, .prism), Optic(5, 5, .mirror, 0), Optic(5, 7),
        Optic(2, 2), Optic(5, 2, .mirror, 0), Optic(5, 4),
        Optic(2, 8, .mirror, 0),
      ],
      receivers: [Receiver(1, 7, .red), Receiver(3, 4, .green), Receiver(6, 8, .blue)],
      walls: [Cell(0, 1), Cell(1, 1), Cell(3, 0), Cell(4, 0)]),
  ]
}
