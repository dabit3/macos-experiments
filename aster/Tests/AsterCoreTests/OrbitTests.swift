import Foundation
import Testing

@testable import AsterCore

@Test func circularElementsAndPeriod() {
  let state = Orbit.circular()
  let elements = Orbit.elements(state)
  #expect(abs(elements.periapsis - 450) < 0.001)
  #expect(abs((elements.apoapsis ?? 0) - 450) < 0.001)
  #expect(abs((elements.period ?? 0) - 5_606.4) < 2)
}

@Test func unpoweredConservationForTenOrbits() {
  let initial = Orbit.circular()
  let period = Orbit.elements(initial).period ?? 0
  var state = initial
  var maxEnergyError = 0.0
  for _ in 0..<1_000 {
    state = Orbit.advance(state, seconds: period / 100)
    maxEnergyError = max(maxEnergyError, abs((state.energy - initial.energy) / initial.energy))
  }
  #expect(maxEnergyError < 1e-7)
  #expect(abs((state.angularMomentum - initial.angularMomentum) / initial.angularMomentum) < 1e-10)
  #expect((state.position - initial.position).magnitude < 10)
}

@Test func transferObjectiveAndRadialImpulse() {
  let state = Orbit.circular()
  let burned = Orbit.burn(state, prograde: 460, radial: 0)
  #expect(Orbit.goalMet(burned))
  #expect(abs(Orbit.elements(burned).periapsis - 450) < 0.001)
  let radial = Orbit.burn(state, prograde: 0, radial: 100)
  #expect(abs(radial.velocity.x - 0.1) < 1e-10)
  #expect(abs(radial.velocity.y - state.velocity.y) < 1e-10)
  #expect(!Orbit.goalMet(state))
}

@Test func eccentricConservationAndPrediction() {
  let initial = Orbit.burn(Orbit.circular(), prograde: 460, radial: 80)
  let points = Orbit.prediction(initial)
  #expect(points.count == 421)
  #expect(points.allSatisfy { abs(($0.state.energy - initial.energy) / initial.energy) < 1e-5 })
  #expect((points.last!.state.position - initial.position).magnitude < 5)
}

@Test func impactAndEscapeAreHonest() {
  let falling = FlightState(position: Vector(6_372, 0), velocity: Vector(-1, 0))
  let stopped = Orbit.advance(falling, seconds: 20)
  #expect(stopped.impacted)
  #expect(stopped.time < 20)
  #expect(Orbit.advance(stopped, seconds: 100) == stopped)
  let escaping = FlightState(position: Vector(7_000, 0), velocity: Vector(0, 12))
  #expect(Orbit.elements(escaping).apoapsis == nil)
  #expect(!Orbit.goalMet(escaping))
  #expect(Orbit.prediction(escaping).allSatisfy { $0.state.position.isFinite })
}

@Test func missionRoundTripAndInvalidInput() throws {
  var mission = Mission()
  mission.plannedPrograde = 460
  mission.burns = [BurnRecord(before: mission.state, prograde: 460, radial: 0)]
  mission.state = Orbit.burn(mission.state, prograde: 460, radial: 0)
  #expect(try Mission.decode(mission.encoded()) == mission)
  mission.version = 20
  #expect(throws: MissionError.self) { try mission.encoded() }
  #expect(throws: (any Error).self) { try Mission.decode(Data("broken".utf8)) }
  mission.version = 1
  mission.state.position = Vector(.infinity, 0)
  #expect(!mission.isValid)
}

@Test func exportIsNumericAndTimeMonotonic() {
  let csv = Orbit.trajectoryCSV(Orbit.circular())
  let lines = csv.split(separator: "\n")
  #expect(lines.count == 422)
  #expect(lines[0] == "time_s,x_km,y_km,vx_km_s,vy_km_s,altitude_km,speed_km_s")
  let times = lines.dropFirst().map { Double($0.split(separator: ",")[0])! }
  #expect(zip(times, times.dropFirst()).allSatisfy { $0 < $1 })
  #expect(lines.dropFirst().allSatisfy { $0.split(separator: ",").count == 7 })
}
