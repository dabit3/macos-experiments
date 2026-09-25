import Foundation
import Observation

struct Vector: Codable, Equatable {
  var x: Double
  var y: Double
  static let zero = Vector(x: 0, y: 0)
  var length: Double { hypot(x, y) }
  static func + (lhs: Vector, rhs: Vector) -> Vector {
    Vector(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
  }
  static func - (lhs: Vector, rhs: Vector) -> Vector {
    Vector(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
  }
  static func * (lhs: Vector, rhs: Double) -> Vector {
    Vector(x: lhs.x * rhs, y: lhs.y * rhs)
  }
  func distance(to other: Vector) -> Double { (self - other).length }
}

struct Planet: Identifiable {
  let id: Int
  let center: Vector
  let radius: Double
  let gravity: Double
  let hue: Double
}

struct Mission: Identifiable {
  let id: Int
  let name: String
  let subtitle: String
  let briefing: String
  let origin: Vector
  let reference: Vector
  let planets: [Planet]
  let beacons: [Vector]
  let station: Vector
  var number: String { String(format: "%02d", id + 1) }
  var referenceAngle: Double { atan2(reference.x, -reference.y) * 180 / .pi }

  static let all: [Mission] = [
    Mission(
      id: 0, name: "First light", subtitle: "A gentle introduction to gravity",
      briefing:
        "Collect both cyan beacons, then dock at the ivory station. Gravity bends every flight.",
      origin: Vector(x: 52, y: 440), reference: Vector(x: 36, y: -112),
      planets: [
        Planet(id: 0, center: Vector(x: 225, y: 270), radius: 43, gravity: 150_000, hue: 0.07)
      ],
      beacons: [Vector(x: 89.4, y: 326.9), Vector(x: 133.6, y: 212.1)],
      station: Vector(x: 186.7, y: 102.3)),
    Mission(
      id: 1, name: "Copper bend", subtitle: "Let a heavier world turn you",
      briefing:
        "A stronger pull. Keep to the western edge and let the copper giant bend your course.",
      origin: Vector(x: 55, y: 452), reference: Vector(x: 12, y: -120),
      planets: [
        Planet(id: 0, center: Vector(x: 185, y: 270), radius: 52, gravity: 250_000, hue: 0.06)
      ],
      beacons: [Vector(x: 69.5, y: 329.4), Vector(x: 97.5, y: 202.7), Vector(x: 118, y: 142.3)],
      station: Vector(x: 140.1, y: 84.5)),
    Mission(
      id: 2, name: "Binary whisper", subtitle: "Two worlds. One fine line.",
      briefing:
        "Thread between two gravity wells. A little less thrust can make a very different arc.",
      origin: Vector(x: 310, y: 450), reference: Vector(x: -35, y: -117),
      planets: [
        Planet(id: 0, center: Vector(x: 130, y: 315), radius: 39, gravity: 135_000, hue: 0.58),
        Planet(id: 1, center: Vector(x: 257, y: 150), radius: 27, gravity: 75_000, hue: 0.07),
      ],
      beacons: [
        Vector(x: 273.3, y: 331.6), Vector(x: 230.7, y: 210.2), Vector(x: 210.1, y: 146.8),
      ],
      station: Vector(x: 195, y: 83.8)),
    Mission(
      id: 3, name: "The needle", subtitle: "A passage between giants",
      briefing:
        "The narrow corridor is your way through. Use the projected flight to find clear space.",
      origin: Vector(x: 50, y: 475), reference: Vector(x: 64, y: -110),
      planets: [
        Planet(id: 0, center: Vector(x: 100, y: 260), radius: 37, gravity: 135_000, hue: 0.08),
        Planet(id: 1, center: Vector(x: 270, y: 335), radius: 34, gravity: 115_000, hue: 0.63),
      ],
      beacons: [
        Vector(x: 115.3, y: 362.3), Vector(x: 178.4, y: 237.8), Vector(x: 204.4, y: 175.6),
      ],
      station: Vector(x: 229.1, y: 115.4)),
    Mission(
      id: 4, name: "Countercurrent", subtitle: "Find the balance of two pulls",
      briefing:
        "Cross the gap from east to west. The two worlds will take turns steering your probe.",
      origin: Vector(x: 310, y: 475), reference: Vector(x: -65, y: -95),
      planets: [
        Planet(id: 0, center: Vector(x: 250, y: 285), radius: 36, gravity: 120_000, hue: 0.55),
        Planet(id: 1, center: Vector(x: 90, y: 330), radius: 30, gravity: 95_000, hue: 0.07),
      ],
      beacons: [
        Vector(x: 243.7, y: 377.1), Vector(x: 180.4, y: 265.3), Vector(x: 130.5, y: 154.4),
      ],
      station: Vector(x: 106.7, y: 101.6)),
    Mission(
      id: 5, name: "Long way home", subtitle: "Trade speed for a deeper curve",
      briefing:
        "A massive sun makes a slow launch sweep around its limb. Think in curves, not straight lines.",
      origin: Vector(x: 60, y: 450), reference: Vector(x: 5, y: -80),
      planets: [
        Planet(id: 0, center: Vector(x: 185, y: 275), radius: 44, gravity: 650_000, hue: 0.055)
      ],
      beacons: [Vector(x: 70.9, y: 363.2), Vector(x: 111.7, y: 259.1), Vector(x: 227.6, y: 197)],
      station: Vector(x: 310, y: 203)),
    Mission(
      id: 6, name: "Three-body ballet", subtitle: "Choreograph a delicate escape",
      briefing:
        "Three worlds shape this flight. Keep an eye on the small planet near the final beacon.",
      origin: Vector(x: 45, y: 460), reference: Vector(x: 65, y: -118),
      planets: [
        Planet(id: 0, center: Vector(x: 70, y: 260), radius: 32, gravity: 105_000, hue: 0.61),
        Planet(id: 1, center: Vector(x: 240, y: 330), radius: 37, gravity: 125_000, hue: 0.07),
        Planet(id: 2, center: Vector(x: 255, y: 135), radius: 24, gravity: 65_000, hue: 0.53),
      ],
      beacons: [Vector(x: 111.6, y: 338.8), Vector(x: 178.3, y: 210), Vector(x: 211.4, y: 146.4)],
      station: Vector(x: 250.4, y: 85.1)),
    Mission(
      id: 7, name: "Foundry's arc", subtitle: "Your final orbital signature",
      briefing: "One last slingshot. Sweep around the copper sun and bring every signal home.",
      origin: Vector(x: 310, y: 460), reference: Vector(x: -5, y: -85),
      planets: [
        Planet(id: 0, center: Vector(x: 185, y: 275), radius: 43, gravity: 650_000, hue: 0.06),
        Planet(id: 1, center: Vector(x: 75, y: 410), radius: 24, gravity: 55_000, hue: 0.59),
      ],
      beacons: [Vector(x: 298, y: 366), Vector(x: 260, y: 258), Vector(x: 155, y: 190)],
      station: Vector(x: 65, y: 190)),
  ]
}

enum FlightOutcome: Equatable {
  case flying
  case docked
  case failed(String)
}

struct Flight {
  var position: Vector
  var velocity: Vector
  var collected: Set<Int> = []
  var elapsed: Double = 0
  var outcome: FlightOutcome = .flying
}

enum OrbitalPhysics {
  static let step = 1.0 / 120.0

  static func acceleration(at point: Vector, planets: [Planet]) -> Vector {
    planets.reduce(.zero) { result, planet in
      let offset = planet.center - point
      let softened = pow(offset.x * offset.x + offset.y * offset.y + 144, 1.5)
      return result + offset * (planet.gravity / softened)
    }
  }

  static func advance(_ flight: inout Flight, mission: Mission) {
    guard flight.outcome == .flying else { return }
    flight.velocity =
      flight.velocity + acceleration(at: flight.position, planets: mission.planets) * step
    flight.position = flight.position + flight.velocity * step
    flight.elapsed += step
    for (index, beacon) in mission.beacons.enumerated()
    where flight.position.distance(to: beacon) < 18 {
      flight.collected.insert(index)
    }
    if mission.planets.contains(where: { flight.position.distance(to: $0.center) < $0.radius + 4 })
    {
      flight.outcome = .failed("Surface contact")
    } else if flight.position.distance(to: mission.station) < 18 {
      flight.outcome =
        flight.collected.count == mission.beacons.count
        ? .docked : .failed("A signal was left behind")
    } else if flight.position.x < -12 || flight.position.x > 372
      || flight.position.y < -12 || flight.position.y > 552
    {
      flight.outcome = .failed("Beyond the flight boundary")
    } else if flight.elapsed > 12 {
      flight.outcome = .failed("Orbit window closed")
    }
  }

  static func prediction(mission: Mission, velocity: Vector) -> [Vector] {
    var flight = Flight(position: mission.origin, velocity: velocity)
    var points = [mission.origin]
    for index in 0..<1441 {
      advance(&flight, mission: mission)
      if index.isMultiple(of: 4) { points.append(flight.position) }
      if flight.outcome != .flying {
        points.append(flight.position)
        break
      }
    }
    return points
  }
}

struct FlightRecord: Codable, Equatable {
  var attempts: Int
  var seconds: Double
  var guided: Bool
  var stars: Int { attempts == 1 ? 3 : attempts <= 3 ? 2 : 1 }
}

struct Archive: Codable {
  var records: [String: FlightRecord] = [:]
  var launches = 0
  var haptics = true
}

@Observable
final class FlightStore {
  private let defaults: UserDefaults
  private let key = "orbit-foundry.archive.v1"
  var archive: Archive
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: key),
      let value = try? JSONDecoder().decode(Archive.self, from: data)
    {
      archive = value
    } else {
      archive = Archive()
    }
  }
  var completed: Int { Mission.all.filter { record(for: $0.id) != nil }.count }
  var nextMission: Mission { Mission.all.first { record(for: $0.id) == nil } ?? Mission.all[7] }
  func record(for id: Int) -> FlightRecord? { archive.records[String(id)] }
  func unlocked(_ id: Int) -> Bool { id == 0 || record(for: id - 1) != nil }
  func save() {
    if let data = try? JSONEncoder().encode(archive) { defaults.set(data, forKey: key) }
  }
  func registerLaunch() {
    archive.launches += 1
    save()
  }
  func complete(_ id: Int, attempts: Int, seconds: Double, guided: Bool) {
    guard unlocked(id), attempts > 0, seconds.isFinite, seconds > 0 else { return }
    let new = FlightRecord(attempts: attempts, seconds: seconds, guided: guided)
    if let old = record(for: id) {
      if new.attempts < old.attempts || (new.attempts == old.attempts && new.seconds < old.seconds)
      {
        archive.records[String(id)] = new
      }
    } else {
      archive.records[String(id)] = new
    }
    save()
  }
  func reset() {
    archive = Archive(haptics: archive.haptics)
    save()
  }
}

@Observable
final class FlightController {
  let mission: Mission
  var angle: Double
  var thrust: Double
  var flight: Flight?
  var trail: [Vector] = []
  var attempts = 0
  var guided = false
  var isAiming = false
  var savedResult = false
  var captureMoments: [Int: Double] = [:]
  init(mission: Mission) {
    self.mission = mission
    angle = mission.id == 0 ? mission.referenceAngle : mission.referenceAngle + 8
    thrust = mission.reference.length
  }
  var velocity: Vector {
    Vector(x: sin(angle * .pi / 180) * thrust, y: -cos(angle * .pi / 180) * thrust)
  }
  var isFlying: Bool { flight?.outcome == .flying }
  var isReady: Bool { flight == nil }
  var prediction: [Vector] { OrbitalPhysics.prediction(mission: mission, velocity: velocity) }
  func aim(toward point: Vector) {
    guard isReady else { return }
    let delta = point - mission.origin
    guard delta.length > 8 else { return }
    angle = min(80, max(-80, atan2(delta.x, -delta.y) * 180 / .pi))
    thrust = min(155, max(55, delta.length * 1.2))
  }
  func useGuide() {
    guard isReady else { return }
    angle = mission.referenceAngle
    thrust = mission.reference.length
    guided = true
  }
  func launch() {
    guard isReady else { return }
    attempts += 1
    trail = [mission.origin]
    flight = Flight(position: mission.origin, velocity: velocity)
  }
  func tick() {
    guard var current = flight, current.outcome == .flying else { return }
    let previous = current.collected
    for _ in 0..<2 { OrbitalPhysics.advance(&current, mission: mission) }
    for index in current.collected.subtracting(previous) {
      captureMoments[index] = current.elapsed
    }
    trail.append(current.position)
    flight = current
  }
  func reset() {
    if flight?.outcome == .docked {
      attempts = 0
      guided = false
      angle = mission.id == 0 ? mission.referenceAngle : mission.referenceAngle + 8
      thrust = mission.reference.length
    }
    flight = nil
    trail = []
    isAiming = false
    savedResult = false
    captureMoments = [:]
  }
}
