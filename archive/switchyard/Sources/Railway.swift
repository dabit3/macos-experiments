import Foundation
import Observation

enum Freight: String, Codable, CaseIterable {
  case coral, blue, gold
  var station: String {
    switch self {
    case .coral: "Rosebay"
    case .blue: "Lakeview"
    case .gold: "Sunfield"
    }
  }
  var code: String {
    switch self {
    case .coral: "R"
    case .blue: "L"
    case .gold: "S"
    }
  }
}

enum Entrance: String, Codable { case west, east }

struct Arrival: Identifiable {
  let id: Int
  let time: Double
  let freight: Freight
  let entrance: Entrance
}

struct Scenario: Identifiable {
  let id: Int
  let title: String
  let subtitle: String
  let note: String
  let arrivals: [Arrival]
  var target: Int { arrivals.count }

  private static func schedule(_ items: [(Double, Freight, Entrance)]) -> [Arrival] {
    items.enumerated().map {
      Arrival(id: $0.offset, time: $0.element.0, freight: $0.element.1, entrance: $0.element.2)
    }
  }

  static let all: [Scenario] = [
    Scenario(
      id: 0, title: "First light", subtitle: "Three trains. One quiet morning.",
      note: "Route R to Rosebay with A. Then set A to onward; B chooses Lakeview or Sunfield.",
      arrivals: schedule([(0, .coral, .west), (15, .blue, .west), (30, .gold, .west)])),
    Scenario(
      id: 1, title: "The meet", subtitle: "Two arrivals, one shared line.",
      note: "East begins on hold. Release it after the west train clears the merge.",
      arrivals: schedule([
        (0, .blue, .west), (0, .coral, .east), (20, .gold, .west), (26, .blue, .east),
      ])),
    Scenario(
      id: 2, title: "Garden local", subtitle: "A little rhythm goes a long way.",
      note: "Watch the arrival strip. Set the next route before each train reaches a switch.",
      arrivals: schedule([
        (0, .gold, .west), (9, .coral, .west), (18, .blue, .east), (28, .gold, .west),
        (36, .coral, .east),
      ])),
    Scenario(
      id: 3, title: "Crossing hours", subtitle: "Make room at the junction.",
      note: "Two pairs arrive together. Use the signals to take turns through the merge.",
      arrivals: schedule([
        (0, .coral, .west), (0, .gold, .east), (18, .blue, .west), (18, .coral, .east),
        (34, .gold, .west), (40, .blue, .east),
      ])),
    Scenario(
      id: 4, title: "Evening express", subtitle: "A busier kind of beautiful.",
      note: "Hold one entrance while the other clears. Pause at any time to plan your next move.",
      arrivals: schedule([
        (0, .blue, .east), (5, .coral, .west), (12, .gold, .east), (18, .blue, .west),
        (24, .coral, .east), (30, .gold, .west), (39, .blue, .east),
      ])),
    Scenario(
      id: 5, title: "The grand shift", subtitle: "Your railway. In perfect harmony.",
      note: "Eight trains, all three stations. A clean shift earns your final dispatch stamp.",
      arrivals: schedule([
        (0, .gold, .west), (0, .blue, .east), (14, .coral, .west), (20, .gold, .east),
        (28, .blue, .west), (28, .coral, .east), (42, .gold, .west), (47, .blue, .east),
      ])),
  ]
}

struct RailPoint: Equatable {
  var x: Double
  var y: Double
  func distance(to other: RailPoint) -> Double { hypot(x - other.x, y - other.y) }
}

enum Node: String {
  case west, east, westSignal, eastSignal, merge, a, b, rose, lake, sun
  var point: RailPoint {
    switch self {
    case .west: RailPoint(x: 25, y: 398)
    case .east: RailPoint(x: 335, y: 398)
    case .westSignal: RailPoint(x: 105, y: 326)
    case .eastSignal: RailPoint(x: 255, y: 326)
    case .merge: RailPoint(x: 180, y: 284)
    case .a: RailPoint(x: 180, y: 226)
    case .b: RailPoint(x: 218, y: 146)
    case .rose: RailPoint(x: 64, y: 100)
    case .lake: RailPoint(x: 180, y: 60)
    case .sun: RailPoint(x: 301, y: 100)
    }
  }
  static let tracks: [(Node, Node)] = [
    (.west, .westSignal), (.east, .eastSignal), (.westSignal, .merge),
    (.eastSignal, .merge), (.merge, .a), (.a, .rose), (.a, .b), (.b, .lake), (.b, .sun),
  ]
}

struct Train: Identifiable {
  let id: Int
  let freight: Freight
  let entrance: Entrance
  var from: Node
  var to: Node
  var distance: Double = 0
  var length: Double { from.point.distance(to: to.point) }
  var point: RailPoint {
    let t = min(1, distance / length)
    return RailPoint(
      x: from.point.x + (to.point.x - from.point.x) * t,
      y: from.point.y + (to.point.y - from.point.y) * t)
  }
  var angle: Double { atan2(to.point.y - from.point.y, to.point.x - from.point.x) }
  var committedDestination: Freight? {
    switch to {
    case .rose: .coral
    case .lake: .blue
    case .sun: .gold
    default: nil
    }
  }
}

enum ShiftState: Equatable {
  case ready, running, paused, won
  case lost(String)
}

@Observable final class Railway {
  let scenario: Scenario
  var state: ShiftState = .ready
  var trains: [Train] = []
  var elapsed: Double = 0
  var delivered = 0
  var roseRoute = true
  var sunRoute = false
  var westOpen = true
  var eastOpen = false
  var speed = 1
  var lastDelivery: Freight?
  private var spawned = 0
  private var accumulator: Double = 0
  static let step = 1.0 / 60
  static let velocity = 30.0

  init(scenario: Scenario) { self.scenario = scenario }
  var remaining: [Arrival] { Array(scenario.arrivals.dropFirst(spawned)) }
  var score: Int { delivered * 100 }
  var isActive: Bool { state == .running || state == .paused || state == .ready }
  var route: Freight { roseRoute ? .coral : (sunRoute ? .gold : .blue) }

  func startPause() {
    switch state {
    case .ready, .paused: state = .running
    case .running: state = .paused
    default: break
    }
  }
  func advance(by delta: Double) {
    guard state == .running, delta.isFinite, delta > 0 else { return }
    accumulator += delta * Double(speed)
    while accumulator + 0.000_000_1 >= Self.step && state == .running {
      accumulator -= Self.step
      tick()
    }
  }
  private func tick() {
    elapsed += Self.step
    while spawned < scenario.arrivals.count && scenario.arrivals[spawned].time <= elapsed {
      let arrival = scenario.arrivals[spawned]
      trains.append(
        Train(
          id: arrival.id, freight: arrival.freight, entrance: arrival.entrance,
          from: arrival.entrance == .west ? .west : .east,
          to: arrival.entrance == .west ? .westSignal : .eastSignal))
      spawned += 1
    }
    let previous = trains
    var finished = Set<Int>()
    for index in trains.indices {
      let train = trains[index]
      let queued = previous.contains {
        $0.id != train.id && $0.from == train.from && $0.to == train.to
          && $0.distance > train.distance && $0.distance - train.distance < 30
      }
      if queued { continue }
      let held = (train.to == .westSignal && !westOpen) || (train.to == .eastSignal && !eastOpen)
      if held && train.distance >= train.length { continue }
      trains[index].distance += Self.velocity * Self.step
      if trains[index].distance >= train.length {
        if held {
          trains[index].distance = train.length
          continue
        }
        let overflow = trains[index].distance - train.length
        if let destination = destination(at: train.to) {
          guard destination == train.freight else {
            state = .lost(
              "\(train.freight.station) train reached \(destination.station). Set the route before the junction."
            )
            return
          }
          finished.insert(train.id)
          delivered += 1
          lastDelivery = destination
        } else {
          trains[index].from = train.to
          trains[index].to = next(after: train.to)
          trains[index].distance = overflow
        }
      }
    }
    trains.removeAll { finished.contains($0.id) }
    for first in trains.indices {
      for second in trains.indices where second > first {
        if trains[first].point.distance(to: trains[second].point) < 19 {
          state = .lost(
            "Two trains met at the merge. Hold one entrance until the other train is clear.")
          return
        }
      }
    }
    if delivered == scenario.target { state = .won }
  }
  private func destination(at node: Node) -> Freight? {
    switch node {
    case .rose: .coral
    case .lake: .blue
    case .sun: .gold
    default: nil
    }
  }
  private func next(after node: Node) -> Node {
    switch node {
    case .westSignal, .eastSignal: .merge
    case .merge: .a
    case .a: roseRoute ? .rose : .b
    case .b: sunRoute ? .sun : .lake
    default: node
    }
  }
}

@Observable final class DispatchBook {
  var scores: [String: Int]
  var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
  private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    scores = defaults.dictionary(forKey: "shiftScores") as? [String: Int] ?? [:]
    haptics = defaults.object(forKey: "haptics") as? Bool ?? true
  }
  func record(_ railway: Railway) {
    guard railway.state == .won else { return }
    let key = String(railway.scenario.id)
    scores[key] = max(scores[key] ?? 0, railway.score)
    defaults.set(scores, forKey: "shiftScores")
  }
  func unlocked(_ id: Int) -> Bool { id == 0 || scores[String(id - 1)] != nil }
  func reset() {
    scores = [:]
    defaults.removeObject(forKey: "shiftScores")
  }
}
