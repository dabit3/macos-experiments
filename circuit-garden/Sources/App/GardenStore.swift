import Foundation
import SwiftUI

struct SavedProject: Codable, Identifiable {
  var id = UUID()
  var savedAt = Date()
  var circuit: Circuit
}

@MainActor
final class GardenStore: ObservableObject {
  @Published var circuit = Circuit.example()
  @Published var selectedID: UUID?
  @Published var pendingTerminal: Terminal?
  @Published var selectedWireID: UUID?
  @Published var dragOffsets: [UUID: CGSize] = [:]
  @Published var notice = "Tap a part to explore. Tap two brass terminals to wire."
  @Published var projects: [SavedProject] = []
  @Published var error: String?
  @Published private(set) var history: [Circuit] = []
  private let folder: URL

  var reading: CircuitReading { CircuitSolver.solve(circuit) }
  var selected: Component? { circuit.components.first { $0.id == selectedID } }
  var canUndo: Bool { !history.isEmpty }

  init() {
    folder = URL.documentsDirectory.appending(path: "CircuitGarden", directoryHint: .isDirectory)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let current = folder.appending(path: "autosave.json")
      if FileManager.default.fileExists(atPath: current.path) {
        circuit = try Circuit.decode(Data(contentsOf: current))
      }
      let library = folder.appending(path: "projects.json")
      if FileManager.default.fileExists(atPath: library.path) {
        let decoded = try JSONDecoder().decode([SavedProject].self, from: Data(contentsOf: library))
        projects = try decoded.map { project in
          _ = try project.circuit.validated()
          return project
        }
      }
    } catch {
      self.error = "Could not restore saved data: \(error.localizedDescription)"
    }
  }

  func change(_ transform: (inout Circuit) -> Void) {
    var next = circuit
    transform(&next)
    guard next != circuit else { return }
    history.append(circuit)
    if history.count > 60 { history.removeFirst() }
    circuit = next
    persist()
  }

  func persist() {
    do {
      try circuit.encoded().write(to: folder.appending(path: "autosave.json"), options: .atomic)
    } catch {
      self.error = "Could not save this board: \(error.localizedDescription)"
    }
  }

  func undo() {
    guard let previous = history.popLast() else { return }
    circuit = previous
    clearSelection()
    notice = "Last change undone."
    persist()
  }

  func clearSelection() {
    selectedID = nil
    selectedWireID = nil
    pendingTerminal = nil
    dragOffsets.removeAll()
  }

  func load(_ next: Circuit) {
    change { $0 = next }
    clearSelection()
    notice = "Board opened. Your changes are saved automatically."
  }

  func add(_ kind: ComponentKind) {
    guard circuit.components.count < 8 else {
      notice = "This small workbench holds eight parts. Remove a part to make room."
      return
    }
    let slots: [(Double, Double)] = [
      (0.25, 0.29), (0.73, 0.29), (0.73, 0.72), (0.25, 0.72),
      (0.49, 0.5), (0.25, 0.5), (0.73, 0.5), (0.49, 0.29),
    ]
    let preferred: Int
    switch kind {
    case .battery: preferred = 0
    case .toggle: preferred = 1
    case .resistor: preferred = 2
    case .lamp: preferred = 3
    }
    let ordered = [slots[preferred]] + slots
    let slot =
      ordered.first { spot in
        !circuit.components.contains { abs($0.x - spot.0) < 0.12 && abs($0.y - spot.1) < 0.12 }
      } ?? slots[circuit.components.count]
    let part = Component(kind: kind, x: slot.0, y: slot.1, value: kind.defaultValue)
    change { $0.components.append(part) }
    selectedID = part.id
    pendingTerminal = nil
    selectedWireID = nil
    notice = "\(kind.title) placed. Drag its body to move it."
  }

  func select(_ id: UUID) {
    selectedID = id
    selectedWireID = nil
  }

  func terminalTapped(_ terminal: Terminal) {
    if let wire = circuit.wires.first(where: { $0.from == terminal || $0.to == terminal }) {
      selectedWireID = wire.id
      selectedID = nil
      pendingTerminal = nil
      notice = "Wire selected. Disconnect it in the inspector, or tap a free terminal."
      return
    }
    selectedWireID = nil
    if let first = pendingTerminal {
      guard first != terminal else {
        pendingTerminal = nil
        notice = "Wiring cancelled."
        return
      }
      guard first.componentID != terminal.componentID else {
        notice = "Connect to a terminal on a different component."
        return
      }
      change { $0.wires.append(Wire(from: first, to: terminal)) }
      pendingTerminal = nil
      notice = "Connection made. Every terminal accepts one wire."
    } else {
      pendingTerminal = terminal
      notice = "Now tap a free terminal on another part."
    }
  }

  func disconnect() {
    guard let id = selectedWireID else { return }
    change { $0.wires.removeAll { $0.id == id } }
    selectedWireID = nil
    notice = "Wire removed. Reconnect the two free terminals, or Undo."
  }

  func removeSelected() {
    guard let id = selectedID else { return }
    change {
      $0.components.removeAll { $0.id == id }
      $0.wires.removeAll { $0.from.componentID == id || $0.to.componentID == id }
    }
    clearSelection()
    notice = "Part and attached wires removed."
  }

  func setValue(_ value: Double, id: UUID) {
    change { board in
      guard let index = board.components.firstIndex(where: { $0.id == id }) else { return }
      board.components[index].value = value
    }
  }

  func toggle(_ id: UUID) {
    select(id)
    change { board in
      guard let index = board.components.firstIndex(where: { $0.id == id }) else { return }
      board.components[index].closed.toggle()
    }
  }

  func move(_ id: UUID, x: Double, y: Double) {
    change { board in
      guard let index = board.components.firstIndex(where: { $0.id == id }) else { return }
      board.components[index].x = min(0.81, max(0.19, x))
      board.components[index].y = min(0.82, max(0.22, y))
    }
  }

  func saveProject(name: String) {
    let title = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
    guard !title.isEmpty else {
      error = "Give this circuit a name before saving."
      return
    }
    change { $0.title = title }
    var updated = projects
    if let index = updated.firstIndex(where: { $0.circuit.title == title }) {
      updated[index].circuit = circuit
      updated[index].savedAt = Date()
    } else {
      updated.insert(SavedProject(circuit: circuit), at: 0)
    }
    do {
      try JSONEncoder().encode(updated).write(
        to: folder.appending(path: "projects.json"), options: .atomic)
      projects = updated
      notice = "“\(title)” saved to Projects."
    } catch {
      self.error = "Could not save project: \(error.localizedDescription)"
    }
  }

  func export() -> [URL] {
    do {
      let exports = folder.appending(path: "Exports", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
      let json = exports.appending(path: "CircuitGarden-project.json")
      let text = exports.appending(path: "CircuitGarden-readings.txt")
      try circuit.encoded().write(to: json, options: .atomic)
      let result = reading
      let report = """
        CIRCUIT GARDEN — \(circuit.title)
        Status: \(result.status.rawValue)
        \(result.detail)
        Source: \(result.voltage) V
        Total series resistance: \(result.resistance) ohm
        Current: \(result.milliamps) mA
        Lamp power: \(String(format: "%.4f", result.lampPower)) W per lamp
        Lamp brightness: \(Int(result.brightness * 100))%
        Components: \(circuit.components.count); wires: \(circuit.wires.count)

        Model: one ideal DC battery, one connected series loop, ideal wires and
        switches, fixed resistors, 100-ohm linear lamps. I = V / sum(R).
        Brightness is min(I² × 100 / 0.12, 1), an illustrative power mapping.
        No diode, thermal, transient, parallel-network or hardware simulation.
        Wire animation indicates activity; it is not electron speed.
        """
      try report.write(to: text, atomically: true, encoding: .utf8)
      notice = "Project JSON and measurement report exported."
      return [json, text]
    } catch {
      self.error = "Could not export: \(error.localizedDescription)"
      return []
    }
  }
}
