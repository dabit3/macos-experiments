import Foundation

enum ComponentKind: String, Codable, CaseIterable, Sendable {
  case battery, toggle, resistor, lamp

  var title: String {
    switch self {
    case .battery: "Battery"
    case .toggle: "Switch"
    case .resistor: "Resistor"
    case .lamp: "Lamp"
    }
  }

  var symbol: String {
    switch self {
    case .battery: "battery.100percent"
    case .toggle: "switch.2"
    case .resistor: "waveform.path"
    case .lamp: "lightbulb"
    }
  }

  var defaultValue: Double {
    switch self {
    case .battery: 9
    case .resistor: 220
    case .lamp: 100
    case .toggle: 0
    }
  }
}

struct Component: Identifiable, Codable, Equatable, Sendable {
  var id = UUID()
  var kind: ComponentKind
  var x: Double
  var y: Double
  var value: Double
  var closed = false

  func terminal(_ side: Int) -> Terminal {
    Terminal(componentID: id, side: side)
  }
}

struct Terminal: Codable, Hashable, Sendable {
  var componentID: UUID
  var side: Int
}

struct Wire: Identifiable, Codable, Equatable, Sendable {
  var id = UUID()
  var from: Terminal
  var to: Terminal
}

struct Circuit: Codable, Equatable, Sendable {
  var title = "Untitled circuit"
  var components: [Component] = []
  var wires: [Wire] = []

  static func example(dimmed: Bool = false) -> Circuit {
    let battery = Component(kind: .battery, x: 0.25, y: 0.29, value: 9)
    let toggle = Component(kind: .toggle, x: 0.73, y: 0.29, value: 0, closed: true)
    let resistor = Component(kind: .resistor, x: 0.73, y: 0.72, value: dimmed ? 470 : 220)
    let lamp = Component(kind: .lamp, x: 0.25, y: 0.72, value: 100)
    return Circuit(
      title: dimmed ? "A softer glow" : "First light",
      components: [battery, toggle, resistor, lamp],
      wires: [
        Wire(from: battery.terminal(1), to: toggle.terminal(0)),
        Wire(from: toggle.terminal(1), to: resistor.terminal(1)),
        Wire(from: resistor.terminal(0), to: lamp.terminal(1)),
        Wire(from: lamp.terminal(0), to: battery.terminal(0)),
      ]
    )
  }

  func validated() throws -> Circuit {
    guard components.count <= 8, wires.count <= 16, title.count <= 80,
      Set(components.map(\.id)).count == components.count,
      Set(wires.map(\.id)).count == wires.count
    else { throw CircuitError.invalidProject }
    for component in components {
      guard component.x.isFinite, component.y.isFinite,
        (0...1).contains(component.x), (0...1).contains(component.y),
        component.value.isFinite
      else { throw CircuitError.invalidProject }
      let validValue: Bool
      switch component.kind {
      case .battery: validValue = (1...24).contains(component.value)
      case .resistor: validValue = (10...2000).contains(component.value)
      case .lamp: validValue = component.value == 100
      case .toggle: validValue = component.value == 0
      }
      guard validValue else { throw CircuitError.invalidProject }
    }
    let ids = Set(components.map(\.id))
    for wire in wires {
      guard ids.contains(wire.from.componentID), ids.contains(wire.to.componentID),
        (0...1).contains(wire.from.side), (0...1).contains(wire.to.side),
        wire.from.componentID != wire.to.componentID
      else { throw CircuitError.invalidProject }
    }
    return self
  }

  func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(validated())
  }

  static func decode(_ data: Data) throws -> Circuit {
    try JSONDecoder().decode(Circuit.self, from: data).validated()
  }
}

enum CircuitError: Error, LocalizedError {
  case invalidProject

  var errorDescription: String? {
    "This project contains invalid components or values. Your current board is unchanged."
  }
}

enum CircuitStatus: String, Sendable {
  case empty = "Ready to grow"
  case open = "Open circuit"
  case flowing = "Current flowing"
  case unsupported = "Check topology"
  case unsafe = "No load"
}

struct CircuitReading: Sendable {
  var status: CircuitStatus
  var detail: String
  var voltage: Double = 0
  var resistance: Double = 0
  var current: Double = 0
  var lampCount: Int = 0

  var lampPower: Double { lampCount > 0 ? current * current * 100 : 0 }
  var brightness: Double { min(1, lampPower / 0.12) }
  var milliamps: String { String(format: "%.1f", current * 1000) }
}

enum CircuitSolver {
  static func solve(_ circuit: Circuit) -> CircuitReading {
    guard !circuit.components.isEmpty else {
      return CircuitReading(
        status: .empty, detail: "Place four parts, then join their brass terminals.")
    }
    guard (try? circuit.validated()) != nil else {
      return CircuitReading(
        status: .unsupported, detail: "Invalid project data. Reset or reopen a saved project.")
    }
    let batteries = circuit.components.filter { $0.kind == .battery }
    guard batteries.count == 1 else {
      return CircuitReading(
        status: .unsupported, detail: "Use exactly one battery in a single series loop.")
    }
    let voltage = batteries[0].value
    let resistance = circuit.components.filter { $0.kind == .resistor || $0.kind == .lamp }
      .reduce(0) { $0 + $1.value }
    var reading = CircuitReading(
      status: .open, detail: "", voltage: voltage, resistance: resistance,
      lampCount: circuit.components.filter { $0.kind == .lamp }.count)
    var counts: [Terminal: Int] = [:]
    var adjacency: [UUID: Set<UUID>] = [:]
    for wire in circuit.wires {
      counts[wire.from, default: 0] += 1
      counts[wire.to, default: 0] += 1
      adjacency[wire.from.componentID, default: []].insert(wire.to.componentID)
      adjacency[wire.to.componentID, default: []].insert(wire.from.componentID)
    }
    guard counts.values.allSatisfy({ $0 <= 1 }) else {
      reading.status = .unsupported
      reading.detail = "Branching is outside this model. Use one wire per terminal."
      return reading
    }
    let missing = circuit.components.flatMap { [$0.terminal(0), $0.terminal(1)] }
      .filter { counts[$0, default: 0] == 0 }.count
    guard missing == 0 else {
      reading.detail =
        "\(missing) unconnected terminal\(missing == 1 ? "" : "s"). Join the loop to let current flow."
      return reading
    }
    var visited = Set<UUID>()
    var pending = [batteries[0].id]
    while let id = pending.popLast() {
      if visited.insert(id).inserted {
        pending.append(contentsOf: adjacency[id, default: []].subtracting(visited))
      }
    }
    guard visited.count == circuit.components.count else {
      reading.status = .unsupported
      reading.detail = "Separate loops detected. Connect all components in one series loop."
      return reading
    }
    guard !circuit.components.contains(where: { $0.kind == .toggle && !$0.closed }) else {
      reading.detail = "The switch is open. Close it to complete the path."
      return reading
    }
    guard resistance > 0 else {
      reading.status = .unsafe
      reading.detail = "An ideal short has no finite current. Add a resistor or lamp."
      return reading
    }
    reading.status = .flowing
    reading.current = voltage / resistance
    reading.detail = "A complete series loop. The same current passes through every part."
    return reading
  }
}
