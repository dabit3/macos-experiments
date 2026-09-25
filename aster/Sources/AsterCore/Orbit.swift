import Foundation

public struct Vector: Codable, Equatable, Sendable {
  public var x: Double
  public var y: Double
  public init(_ x: Double, _ y: Double) {
    self.x = x
    self.y = y
  }
  public var magnitude: Double { hypot(x, y) }
  public var unit: Vector { self / max(magnitude, 1e-12) }
  public static func + (lhs: Self, rhs: Self) -> Self { Vector(lhs.x + rhs.x, lhs.y + rhs.y) }
  public static func - (lhs: Self, rhs: Self) -> Self { Vector(lhs.x - rhs.x, lhs.y - rhs.y) }
  public static func * (lhs: Self, rhs: Double) -> Self { Vector(lhs.x * rhs, lhs.y * rhs) }
  public static func / (lhs: Self, rhs: Double) -> Self { Vector(lhs.x / rhs, lhs.y / rhs) }
  public func dot(_ rhs: Self) -> Double { x * rhs.x + y * rhs.y }
  public var isFinite: Bool { x.isFinite && y.isFinite }
}

public struct FlightState: Codable, Equatable, Sendable {
  public var position: Vector
  public var velocity: Vector
  public var time: Double
  public init(position: Vector, velocity: Vector, time: Double = 0) {
    self.position = position
    self.velocity = velocity
    self.time = time
  }
  public var altitude: Double { position.magnitude - Orbit.earthRadius }
  public var energy: Double { velocity.dot(velocity) / 2 - Orbit.mu / position.magnitude }
  public var angularMomentum: Double { position.x * velocity.y - position.y * velocity.x }
  public var impacted: Bool { altitude <= 0 }
}

public struct Elements: Sendable {
  public let periapsis: Double
  public let apoapsis: Double?
  public let eccentricity: Double
  public let period: Double?
}

public struct TrajectoryPoint: Sendable {
  public let state: FlightState
}

public enum Orbit {
  public static let mu = 398_600.4418
  public static let earthRadius = 6_371.0
  public static let goalAltitude = 2_400.0

  public static func circular(altitude: Double = 450) -> FlightState {
    let radius = earthRadius + altitude
    return FlightState(position: Vector(radius, 0), velocity: Vector(0, sqrt(mu / radius)))
  }

  public static func elements(_ state: FlightState) -> Elements {
    let h = state.angularMomentum
    let eccentricity = sqrt(max(0, 1 + 2 * state.energy * h * h / (mu * mu)))
    let p = h * h / mu
    let bound = state.energy < 0 && eccentricity < 1
    let a = -mu / (2 * min(state.energy, -1e-12))
    return Elements(
      periapsis: p / (1 + eccentricity) - earthRadius,
      apoapsis: bound ? p / (1 - eccentricity) - earthRadius : nil,
      eccentricity: eccentricity,
      period: bound ? 2 * .pi * sqrt(a * a * a / mu) : nil
    )
  }

  public static func acceleration(_ position: Vector) -> Vector {
    let radius = max(position.magnitude, 1)
    return position * (-mu / (radius * radius * radius))
  }

  public static func advance(_ state: FlightState, seconds: Double, maxStep: Double = 2)
    -> FlightState
  {
    guard seconds.isFinite, seconds > 0, maxStep.isFinite, maxStep > 0 else { return state }
    var next = state
    let steps = Int(ceil(seconds / maxStep))
    let dt = seconds / Double(steps)
    for _ in 0..<steps {
      guard !next.impacted else { break }
      let a = acceleration(next.position)
      let position = next.position + next.velocity * dt + a * (0.5 * dt * dt)
      next.velocity = next.velocity + (a + acceleration(position)) * (0.5 * dt)
      next.position = position
      next.time += dt
    }
    return next
  }

  public static func burn(_ state: FlightState, prograde: Double, radial: Double) -> FlightState {
    var next = state
    next.velocity =
      state.velocity + state.velocity.unit * (prograde / 1_000)
      + state.position.unit * (radial / 1_000)
    return next
  }

  public static func prediction(_ state: FlightState, count: Int = 420) -> [TrajectoryPoint] {
    guard count > 0 else { return [] }
    let duration = min(elements(state).period ?? 14_400, 43_200)
    var points = [TrajectoryPoint(state: state)]
    var next = state
    for _ in 0..<count {
      next = advance(next, seconds: duration / Double(count), maxStep: 5)
      points.append(TrajectoryPoint(state: next))
      if next.impacted { break }
    }
    return points
  }

  public static func goalMet(_ state: FlightState) -> Bool {
    let orbit = elements(state)
    guard let apoapsis = orbit.apoapsis else { return false }
    return !state.impacted && abs(apoapsis - goalAltitude) <= 120 && orbit.periapsis >= 300
  }

  public static func trajectoryCSV(_ state: FlightState) -> String {
    let header = "time_s,x_km,y_km,vx_km_s,vy_km_s,altitude_km,speed_km_s\n"
    return header
      + prediction(state).map {
        let s = $0.state
        return [
          s.time, s.position.x, s.position.y, s.velocity.x, s.velocity.y, s.altitude,
          s.velocity.magnitude,
        ]
        .map { String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), $0) }
        .joined(separator: ",")
      }.joined(separator: "\n") + "\n"
  }
}
