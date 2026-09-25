import Foundation

enum CargoKind: String, CaseIterable, Codable {
  case trunk, clock, plant, piano, telescope

  var title: String {
    switch self {
    case .trunk: "Voyager's trunk"
    case .clock: "Station clock"
    case .plant: "Winter garden"
    case .piano: "Grand piano"
    case .telescope: "Stargazer's scope"
    }
  }

  var weight: Double {
    switch self {
    case .trunk: 2
    case .clock: 3
    case .plant: 1
    case .piano: 5
    case .telescope: 2
    }
  }

  var width: Double {
    switch self {
    case .trunk: 68
    case .clock: 54
    case .plant: 64
    case .piano: 82
    case .telescope: 66
    }
  }

  var height: Double { 36 }
}

struct StackedCargo: Identifiable {
  let id: Int
  let kind: CargoKind
  let x: Double
}

struct Contract: Identifiable {
  let id: Int
  let title: String
  let subtitle: String
  let cargo: [CargoKind]
  let seconds: Double
  let swing: Double

  static let all: [Contract] = [
    Contract(
      id: 0, title: "The piano run", subtitle: "Four lost treasures. One tiny airship.",
      cargo: [.trunk, .plant, .clock, .piano], seconds: 90, swing: 0.8),
    Contract(
      id: 1, title: "Observatory bound", subtitle: "A little more swing. A taller order.",
      cargo: [.trunk, .clock, .telescope, .plant, .piano], seconds: 95, swing: 1.0),
    Contract(
      id: 2, title: "The grand salvage", subtitle: "Heavy freight for a steady hand.",
      cargo: [.piano, .clock, .trunk, .telescope, .plant, .piano], seconds: 110, swing: 1.12),
  ]
}

enum DockRules {
  static let dockX = 83.0
  static let shipX = 258.0
  static let deckWidth = 176.0

  static func canCatch(hookX: Double, cargo: CargoKind) -> Bool {
    abs(hookX - dockX) <= cargo.width * 0.5 + 10
  }

  static func hasSupport(x: Double, kind: CargoKind, stack: [StackedCargo]) -> Bool {
    let supportX = stack.last?.x ?? shipX
    let supportWidth = stack.last?.kind.width ?? deckWidth
    let overlap =
      min(x + kind.width / 2, supportX + supportWidth / 2)
      - max(x - kind.width / 2, supportX - supportWidth / 2)
    return overlap >= min(kind.width, supportWidth) * 0.34
  }

  static func balance(_ stack: [StackedCargo]) -> Double {
    let mass = stack.reduce(5.0) { $0 + $1.kind.weight }
    let torque = stack.reduce(0.0) { $0 + ($1.x - shipX) * $1.kind.weight }
    return torque / mass / 39
  }

  static func isStable(_ stack: [StackedCargo]) -> Bool {
    abs(balance(stack)) < 1
  }

  static func points(x: Double, kind: CargoKind, stack: [StackedCargo]) -> Int {
    let target = stack.last?.x ?? shipX
    let precision = max(0, 100 - Int(abs(x - target) * 2))
    return 100 + Int(kind.weight) * 20 + precision
  }
}
