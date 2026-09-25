import Foundation

public struct BurnRecord: Codable, Equatable, Sendable {
  public let before: FlightState
  public let prograde: Double
  public let radial: Double
  public init(before: FlightState, prograde: Double, radial: Double) {
    self.before = before
    self.prograde = prograde
    self.radial = radial
  }
}

public struct Mission: Codable, Equatable, Sendable {
  public var version = 1
  public var state: FlightState
  public var plannedPrograde: Double = 0
  public var plannedRadial: Double = 0
  public var burns: [BurnRecord] = []
  public var warp: Double = 30
  public var preset: String = "Departure / 450 km"
  public init(state: FlightState = Orbit.circular()) { self.state = state }

  public var isValid: Bool {
    version == 1 && Self.valid(state) && plannedPrograde.isFinite && plannedRadial.isFinite
      && abs(plannedPrograde) <= 900 && abs(plannedRadial) <= 500
      && [1.0, 30, 120, 600].contains(warp) && burns.count <= 100
      && burns.allSatisfy {
        Self.valid($0.before) && $0.prograde.isFinite && $0.radial.isFinite
          && abs($0.prograde) <= 900 && abs($0.radial) <= 500
      }
  }

  private static func valid(_ state: FlightState) -> Bool {
    state.position.isFinite && state.velocity.isFinite && state.time.isFinite
      && state.time >= 0 && state.time <= 1e12
      && state.position.magnitude >= Orbit.earthRadius - 100
      && state.position.magnitude <= 1e12 && state.velocity.magnitude < 100
  }

  public static func decode(_ data: Data) throws -> Mission {
    let mission = try JSONDecoder().decode(Self.self, from: data)
    guard mission.isValid else { throw MissionError.invalid }
    return mission
  }

  public func encoded() throws -> Data {
    guard isValid else { throw MissionError.invalid }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }
}

public enum MissionError: LocalizedError {
  case invalid
  public var errorDescription: String? {
    "This mission contains unsupported or invalid orbital data."
  }
}
