import Foundation

func clamp(_ x: Double, _ low: Double, _ high: Double) -> Double { min(high, max(low, x)) }
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
func wrap(_ angle: Double) -> Double {
  var a = angle
  while a > .pi { a -= 2 * .pi }
  while a <= -.pi { a += 2 * .pi }
  return a
}
func turn(_ from: Double, _ to: Double, _ step: Double) -> Double {
  let d = wrap(to - from)
  return abs(d) <= step ? to : from + (d > 0 ? step : -step)
}
func mod(_ value: Int, _ count: Int) -> Int { (value % count + count) % count }

struct V2: Codable, Equatable {
  var x: Double
  var y: Double
  static let zero = V2(x: 0, y: 0)
  static func + (a: V2, b: V2) -> V2 { V2(x: a.x + b.x, y: a.y + b.y) }
  static func - (a: V2, b: V2) -> V2 { V2(x: a.x - b.x, y: a.y - b.y) }
  static func * (a: V2, b: Double) -> V2 { V2(x: a.x * b, y: a.y * b) }
  static func angle(_ a: Double, _ length: Double = 1) -> V2 {
    V2(x: cos(a) * length, y: sin(a) * length)
  }
  var length: Double { sqrt(x * x + y * y) }
  var angle: Double { atan2(y, x) }
  var normal: V2 { V2(x: -y, y: x) }
  var normalized: V2 { length > 0.000001 ? self * (1 / length) : .zero }
  func dot(_ b: V2) -> Double { x * b.x + y * b.y }
  func cross(_ b: V2) -> Double { x * b.y - y * b.x }
  func distance(_ b: V2) -> Double { (self - b).length }
  func interpolated(_ b: V2, _ t: Double) -> V2 { self + (b - self) * t }
}

final class Rng {
  private var state: Int
  init(_ seed: Int) { state = mod(seed, 2_147_483_646) + 1 }
  func nextInt(_ max: Int) -> Int {
    state = state * 48271 % 2_147_483_647
    return state % max
  }
  func nextDouble() -> Double {
    state = state * 48271 % 2_147_483_647
    return Double(state - 1) / 2_147_483_646
  }
  func weighted(_ weights: [Int]) -> Int {
    var value = nextInt(weights.reduce(0, +))
    for (i, weight) in weights.enumerated() {
      value -= weight
      if value < 0 { return i }
    }
    return weights.count - 1
  }
}

struct Tot: Codable, Identifiable {
  let id, name, tagline, weight: String
  let color: UInt32
  let speed, accel, handling, mass: Double
}
struct Kart: Codable, Identifiable {
  let id, name: String
  let speed, accel, handling, mass: Double
  let color: UInt32
}
struct Cup: Codable, Identifiable {
  let id, name: String
  let trackIds: [String]
  let color: UInt32
}
struct Stats {
  let speed, accel, handling, mass: Double
  init(_ character: String, _ kart: String) {
    let c = Catalog.shared.character(character)
    let k = Catalog.shared.kart(kart)
    speed = clamp(k.speed + c.speed, 1, 5.5) / 5
    accel = clamp(k.accel + c.accel, 1, 5.5) / 5
    handling = clamp(k.handling + c.handling, 1, 5.5) / 5
    mass = clamp(k.mass + c.mass, 1, 5.5) / 5
  }
}
struct TrackSample: Codable {
  let pos, tangent: V2
  let width, s: Double
  var normal: V2 { tangent.normal }
}
struct TrackTheme: Codable {
  let ground, groundAlt, road, roadEdge, curbA, curbB, shortcut, accent, sky: UInt32
}
struct Pad: Codable {
  let pos: V2
  let angle, length, width: Double
  func contains(_ p: V2) -> Bool {
    let d = p - pos
    let fwd = V2.angle(angle)
    return abs(d.dot(fwd)) <= length / 2 && abs(d.cross(fwd)) <= width / 2
  }
}
enum HazardKind: String, Codable { case oilSlick, pillar, roller }
struct Hazard: Codable {
  let kind: HazardKind
  let pos: V2
  let angle, range: Double
}
struct Shortcut: Codable {
  let name: String
  let polygon: [V2]
  func contains(_ p: V2) -> Bool {
    var inside = false
    var j = polygon.count - 1
    for i in polygon.indices {
      let a = polygon[i]
      let b = polygon[j]
      if (a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
        inside.toggle()
      }
      j = i
    }
    return inside
  }
}
enum Surface: Int, Codable { case road, offroad, shortcut, wall }
struct Track: Codable, Identifiable {
  let id, name, location, description: String
  let isArena: Bool
  let grassMargin, length: Double
  let boundsMin, boundsMax: V2
  let theme: TrackTheme
  let samples: [TrackSample]
  let startGrid: [V2]
  let boostPads, jumps: [Pad]
  let hazards: [Hazard]
  let itemBoxes: [V2]
  let shortcuts: [Shortcut]
  func nearest(_ p: V2, _ hint: Int? = nil) -> Int {
    if let hint, samples.indices.contains(hint) {
      var best = hint
      var distance = samples[hint].pos.distance(p)
      for k in -40...40 {
        let i = mod(hint + k, samples.count)
        let d = samples[i].pos.distance(p)
        if d < distance {
          best = i
          distance = d
        }
      }
      if distance < samples[best].width + grassMargin + 60 { return best }
    }
    var best = 0
    var distance = Double.infinity
    for (i, s) in samples.enumerated() {
      let d = s.pos.distance(p)
      if d < distance {
        best = i
        distance = d
      }
    }
    return best
  }
  func lateral(_ p: V2, _ i: Int) -> Double { samples[i].tangent.cross(p - samples[i].pos) }
  func surface(_ p: V2, _ i: Int) -> Surface {
    if shortcuts.contains(where: { $0.contains(p) }) { return .shortcut }
    let d = abs(lateral(p, i))
    let width = samples[i].width
    if d <= width / 2 { return .road }
    if !isArena && d <= width / 2 + grassMargin { return .offroad }
    return .wall
  }
  func checkpoint(_ i: Int) -> Int { i * 6 / samples.count }
}
struct Catalog: Codable {
  let characters: [Tot]
  let karts: [Kart]
  let cups: [Cup]
  let tracks: [Track]
  static let shared: Catalog = {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle.main
    #endif
    guard let url = bundle.url(forResource: "catalog", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let catalog = try? JSONDecoder().decode(Catalog.self, from: data)
    else {
      preconditionFailure("Missing or invalid native track catalog. Run tools/export_native.dart.")
    }
    return catalog
  }()
  func track(_ id: String) -> Track { tracks.first { $0.id == id } ?? tracks[0] }
  func character(_ id: String) -> Tot { characters.first { $0.id == id } ?? characters[0] }
  func kart(_ id: String) -> Kart { karts.first { $0.id == id } ?? karts[0] }
  func cup(_ id: String) -> Cup { cups.first { $0.id == id } ?? cups[0] }
}
