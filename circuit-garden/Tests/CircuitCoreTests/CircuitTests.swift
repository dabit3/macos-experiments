import Foundation
import Testing

@testable import CircuitCore

@Test func ohmsLawAndLampPower() {
  let result = CircuitSolver.solve(.example())
  #expect(result.status == .flowing)
  #expect(abs(result.current - 9.0 / 320) < 0.000001)
  #expect(abs(result.lampPower - 0.0791015625) < 0.000001)
  #expect(abs(result.brightness - 0.6591796875) < 0.000001)
}

@Test func increasedResistanceDimsLamp() {
  let bright = CircuitSolver.solve(.example())
  let dimmed = CircuitSolver.solve(.example(dimmed: true))
  #expect(dimmed.current < bright.current)
  #expect(dimmed.brightness < bright.brightness)
  #expect(abs(dimmed.current - 9.0 / 570) < 0.000001)
}

@Test func resistorOnlyLoopHasNoLampOutput() {
  var circuit = Circuit.example()
  circuit.components[3].kind = .resistor
  let result = CircuitSolver.solve(circuit)
  #expect(result.status == .flowing)
  #expect(result.current > 0)
  #expect(result.lampPower == 0)
  #expect(result.brightness == 0)
}

@Test func voltageChangesCurrent() {
  var board = Circuit.example()
  board.components[0].value = 18
  #expect(CircuitSolver.solve(board).current == 2 * CircuitSolver.solve(.example()).current)
}

@Test func openSwitchAndBrokenWireStopCurrent() {
  var circuit = Circuit.example()
  circuit.components[1].closed = false
  #expect(CircuitSolver.solve(circuit).status == .open)
  #expect(CircuitSolver.solve(circuit).current == 0)
  circuit.components[1].closed = true
  let removed = circuit.wires.removeLast()
  #expect(CircuitSolver.solve(circuit).current == 0)
  circuit.wires.append(removed)
  #expect(CircuitSolver.solve(circuit).status == .flowing)
}

@Test func branchesAndDisconnectedLoopsAreRejected() {
  var circuit = Circuit.example()
  circuit.wires.append(
    Wire(from: circuit.components[0].terminal(1), to: circuit.components[2].terminal(1)))
  #expect(CircuitSolver.solve(circuit).status == .unsupported)
  circuit = .example()
  let a = Component(kind: .resistor, x: 0.5, y: 0.5, value: 100)
  let b = Component(kind: .lamp, x: 0.6, y: 0.6, value: 100)
  circuit.components += [a, b]
  circuit.wires += [
    Wire(from: a.terminal(0), to: b.terminal(0)),
    Wire(from: a.terminal(1), to: b.terminal(1)),
  ]
  #expect(CircuitSolver.solve(circuit).status == .unsupported)
}

@Test func idealShortAndMissingBattery() {
  let a = Component(kind: .battery, x: 0.2, y: 0.5, value: 9)
  let b = Component(kind: .toggle, x: 0.7, y: 0.5, value: 0, closed: true)
  let circuit = Circuit(
    components: [a, b],
    wires: [
      Wire(from: a.terminal(0), to: b.terminal(0)),
      Wire(from: a.terminal(1), to: b.terminal(1)),
    ])
  #expect(CircuitSolver.solve(circuit).status == .unsafe)
  #expect(CircuitSolver.solve(Circuit(components: [b])).status == .unsupported)
}

@Test func serializationRoundTripAndValidation() throws {
  let circuit = Circuit.example()
  #expect(try Circuit.decode(circuit.encoded()) == circuit)
  var invalid = circuit
  invalid.components[0].value = -1
  #expect(throws: CircuitError.self) { try invalid.encoded() }
  invalid = circuit
  invalid.wires[0].to.side = 7
  #expect(throws: CircuitError.self) { try invalid.validated() }
  #expect(throws: (any Error).self) { try Circuit.decode(Data("broken".utf8)) }
}

@Test func duplicateIDsAndOutOfBoundsPositionsAreRejected() {
  var circuit = Circuit.example()
  circuit.components[1].id = circuit.components[0].id
  #expect(throws: CircuitError.self) { try circuit.validated() }
  circuit = .example()
  circuit.components[0].x = .infinity
  #expect(throws: CircuitError.self) { try circuit.validated() }
}
