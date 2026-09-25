import Foundation

public struct MapPoint: Codable, Equatable, Sendable {
  public var x: Double
  public var y: Double
  public init(_ x: Double, _ y: Double) {
    self.x = x
    self.y = y
  }
  public func distance(to other: MapPoint) -> Double { hypot(x - other.x, y - other.y) }
}

public enum Station: String, Codable, CaseIterable, Sendable {
  case alder, summit, harbor
  public var title: String {
    switch self {
    case .alder: "Alder Grove"
    case .summit: "Pine Summit"
    case .harbor: "Stillwater"
    }
  }
  public var code: String {
    switch self {
    case .alder: "ALD"
    case .summit: "PNE"
    case .harbor: "STW"
    }
  }
  public var point: MapPoint {
    switch self {
    case .alder: MapPoint(140, 395)
    case .summit: MapPoint(795, 225)
    case .harbor: MapPoint(795, 590)
    }
  }
}

public struct Track: Sendable {
  public let id: String
  public let from: String
  public let to: String
  public let points: [MapPoint]
  public var length: Double {
    zip(points, points.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
  }
  public func point(at fraction: Double, reversed: Bool = false) -> MapPoint {
    let t = min(1, max(0, reversed ? 1 - fraction : fraction))
    var remaining = t * length
    for (a, b) in zip(points, points.dropFirst()) {
      let segment = a.distance(to: b)
      if remaining <= segment {
        let f = segment > 0 ? remaining / segment : 0
        return MapPoint(a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f)
      }
      remaining -= segment
    }
    return points.last ?? MapPoint(0, 0)
  }
}

public enum Network {
  public static let tracks: [Track] = [
    Track(id: "west", from: "alder", to: "j1", points: [MapPoint(140, 395), MapPoint(370, 395)]),
    Track(id: "main", from: "j1", to: "j2", points: [MapPoint(370, 395), MapPoint(590, 395)]),
    Track(
      id: "scenic", from: "j1", to: "j2",
      points: [
        MapPoint(370, 395), MapPoint(395, 350), MapPoint(410, 290), MapPoint(440, 265),
        MapPoint(490, 265), MapPoint(540, 290), MapPoint(565, 350), MapPoint(590, 395),
      ]),
    Track(
      id: "north", from: "j2", to: "summit",
      points: [
        MapPoint(590, 395), MapPoint(635, 365), MapPoint(665, 310), MapPoint(690, 260),
        MapPoint(725, 230), MapPoint(755, 225), MapPoint(795, 225),
      ]),
    Track(
      id: "south", from: "j2", to: "harbor",
      points: [
        MapPoint(590, 395), MapPoint(630, 425), MapPoint(655, 480), MapPoint(680, 540),
        MapPoint(715, 578), MapPoint(750, 590), MapPoint(795, 590),
      ]),
  ]
  public static func track(_ id: String) -> Track { tracks.first { $0.id == id }! }
  public static func route(from: Station, to: Station, scenic: Bool) -> [Leg] {
    guard from != to else { return [] }
    let allowed = tracks.filter { $0.id != (scenic ? "main" : "scenic") }
    var queue: [(String, [Leg])] = [(from.rawValue, [])]
    var visited: Set<String> = [from.rawValue]
    while !queue.isEmpty {
      let (node, path) = queue.removeFirst()
      for edge in allowed where edge.from == node || edge.to == node {
        let reversed = edge.to == node
        let next = reversed ? edge.from : edge.to
        let newPath = path + [Leg(trackID: edge.id, reversed: reversed)]
        if next == to.rawValue { return newPath }
        if visited.insert(next).inserted { queue.append((next, newPath)) }
      }
    }
    return []
  }
}

public struct Leg: Codable, Equatable, Sendable {
  public let trackID: String
  public let reversed: Bool
}
