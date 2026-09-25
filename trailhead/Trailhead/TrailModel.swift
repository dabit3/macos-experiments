import Foundation

struct TrailPoint: Codable, Equatable {
  var latitude: Double
  var longitude: Double
  var elevation: Double

  func distance(to other: TrailPoint) -> Double {
    let radians = Double.pi / 180
    let dLat = (other.latitude - latitude) * radians
    let dLon = (other.longitude - longitude) * radians
    let a =
      pow(sin(dLat / 2), 2)
      + cos(latitude * radians) * cos(other.latitude * radians) * pow(sin(dLon / 2), 2)
    return 6_371 * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
  }
}

struct Trail: Identifiable {
  let id: String
  let name: String
  let region: String
  let landscape: String
  let difficulty: String
  let description: String
  let points: [TrailPoint]

  var distances: [Double] {
    var result = [0.0]
    for index in 1..<points.count {
      result.append(result[index - 1] + points[index - 1].distance(to: points[index]))
    }
    return result
  }
  var distance: Double { distances.last ?? 0 }
  var ascent: Double {
    zip(points, points.dropFirst()).reduce(0) {
      $0 + max(0, $1.1.elevation - $1.0.elevation)
    }
  }
  var durationHours: Double { distance / 4 + ascent / 600 }
  var duration: String {
    let minutes = Int((durationHours * 60).rounded())
    return "\(minutes / 60)h \(minutes % 60)m"
  }

  func point(at fraction: Double) -> TrailPoint {
    let target = min(1, max(0, fraction)) * distance
    let cumulative = distances
    for index in 1..<points.count where cumulative[index] >= target {
      let segment = cumulative[index] - cumulative[index - 1]
      let mix = segment > 0 ? (target - cumulative[index - 1]) / segment : 0
      let a = points[index - 1]
      let b = points[index]
      return TrailPoint(
        latitude: a.latitude + (b.latitude - a.latitude) * mix,
        longitude: a.longitude + (b.longitude - a.longitude) * mix,
        elevation: a.elevation + (b.elevation - a.elevation) * mix)
    }
    return points[points.count - 1]
  }
}

enum Trails {
  static let all: [Trail] = [
    Trail(
      id: "granite", name: "Granite Loop", region: "HIGH SIERRA STUDY",
      landscape: "Granite basin", difficulty: "Moderate",
      description:
        "A winding ascent through pine forest to an open granite basin. Pause at the overlook before tracing the creek home.",
      points: fixture([
        (37.720, -119.620, 1840), (37.724, -119.623, 1880),
        (37.729, -119.622, 1945), (37.733, -119.625, 2010),
        (37.738, -119.621, 2110), (37.744, -119.624, 2180),
        (37.748, -119.619, 2230), (37.752, -119.615, 2320),
        (37.750, -119.609, 2260), (37.746, -119.607, 2200),
        (37.742, -119.611, 2140), (37.737, -119.607, 2080),
        (37.732, -119.611, 2000), (37.727, -119.609, 1930),
        (37.724, -119.614, 1870), (37.720, -119.620, 1840),
      ])),
    Trail(
      id: "juniper", name: "Juniper Ridge", region: "RED ROCK STUDY",
      landscape: "Painted mesa", difficulty: "Challenging",
      description:
        "Follow ochre switchbacks to a quiet mesa above the juniper country. An exposed ridge rewards an early start.",
      points: fixture([
        (37.280, -113.020, 1250), (37.285, -113.022, 1330),
        (37.290, -113.017, 1410), (37.291, -113.023, 1460),
        (37.296, -113.018, 1520), (37.299, -113.024, 1580),
        (37.304, -113.020, 1630), (37.309, -113.018, 1740),
        (37.314, -113.011, 1780), (37.310, -113.007, 1750),
        (37.305, -113.010, 1690), (37.300, -113.007, 1600),
        (37.295, -113.011, 1510), (37.288, -113.008, 1410),
        (37.284, -113.013, 1320), (37.280, -113.020, 1250),
      ])),
    Trail(
      id: "mirror", name: "Mirror Lake", region: "ALPINE STUDY",
      landscape: "Stillwater valley", difficulty: "Easy",
      description:
        "An unhurried ramble around a glacial lake, with sheltered woodland and a lakeside stop for your field journal.",
      points: fixture([
        (46.840, -121.750, 1540), (46.843, -121.754, 1570),
        (46.847, -121.755, 1610), (46.850, -121.752, 1640),
        (46.853, -121.748, 1680), (46.855, -121.743, 1690),
        (46.852, -121.738, 1660), (46.848, -121.736, 1630),
        (46.844, -121.739, 1590), (46.841, -121.742, 1560),
        (46.840, -121.750, 1540),
      ])),
  ]

  static func fixture(_ values: [(Double, Double, Double)]) -> [TrailPoint] {
    values.map { TrailPoint(latitude: $0.0, longitude: $0.1, elevation: $0.2) }
  }
  static func find(_ id: String) -> Trail { all.first { $0.id == id } ?? all[0] }
}

struct Waypoint: Codable, Identifiable, Equatable {
  var id = UUID()
  var name: String
  var fraction: Double
}

struct GearItem: Codable, Identifiable, Equatable {
  var id = UUID()
  var name: String
  var packed = false
}

struct Trip: Codable, Identifiable, Equatable {
  var id = UUID()
  var trailID: String
  var name: String
  var waypoints: [Waypoint]
  var gear: [GearItem]

  static func fresh(for trail: Trail) -> Trip {
    Trip(
      trailID: trail.id, name: "\(trail.name) expedition",
      waypoints: [Waypoint(name: "Trailhead", fraction: 0)],
      gear: [
        "Water · 2 liters", "Trail snacks", "Warm layer", "First aid kit", "Headlamp",
        "Sun protection",
      ]
      .map { GearItem(name: $0) })
  }

  mutating func addWaypoint(name: String, fraction: Double) -> Bool {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty, clean.count <= 60, fraction.isFinite else { return false }
    waypoints.append(Waypoint(name: clean, fraction: min(1, max(0, fraction))))
    waypoints.sort { $0.fraction < $1.fraction }
    return true
  }

  mutating func addGear(name: String) -> Bool {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty, clean.count <= 60 else { return false }
    gear.append(GearItem(name: clean))
    return true
  }
}

struct ExpeditionArchive: Codable, Equatable {
  var version = 1
  var selectedTrailID = Trails.all[0].id
  var drafts: [String: Trip] = [:]
  var saved: [Trip] = []

  mutating func save(_ trip: Trip) {
    if let index = saved.firstIndex(where: { $0.id == trip.id }) {
      saved[index] = trip
    } else {
      saved.insert(trip, at: 0)
    }
  }

  func write(to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(self).write(to: url, options: .atomic)
  }

  static func read(from url: URL) throws -> ExpeditionArchive {
    let archive = try JSONDecoder().decode(ExpeditionArchive.self, from: Data(contentsOf: url))
    guard archive.version == 1,
      Trails.all.contains(where: { $0.id == archive.selectedTrailID }),
      archive.drafts.allSatisfy({ key, trip in
        key == trip.trailID && valid(trip)
      }),
      archive.saved.allSatisfy(valid)
    else { throw CocoaError(.coderReadCorrupt) }
    return archive
  }

  static func valid(_ trip: Trip) -> Bool {
    Trails.all.contains { $0.id == trip.trailID }
      && !trip.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && trip.waypoints.allSatisfy {
        !$0.name.isEmpty && $0.fraction.isFinite && (0...1).contains($0.fraction)
      }
      && trip.gear.allSatisfy { !$0.name.isEmpty }
  }
}
