import Foundation

public enum ServiceState: String, Codable, Sendable {
  case ready, running, delivered
}

public struct Train: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var name: String
  public var origin: Station
  public var destination: Station
  public var state: ServiceState = .ready
  public var route: [Leg] = []
  public var legIndex = 0
  public var progress = 0.0
  public var waiting = ""
  public var departure: Double?
  public var arrival: Double?
  public var point: MapPoint {
    guard !route.isEmpty else { return origin.point }
    if state == .delivered { return destination.point }
    let leg = route[min(legIndex, route.count - 1)]
    return Network.track(leg.trackID).point(at: progress, reversed: leg.reversed)
  }
  public var angle: Double {
    guard !route.isEmpty else { return 0 }
    let leg = route[min(legIndex, route.count - 1)]
    let track = Network.track(leg.trackID)
    let a = track.point(at: max(0, progress - 0.02), reversed: leg.reversed)
    let b = track.point(at: min(1, progress + 0.02), reversed: leg.reversed)
    return atan2(b.y - a.y, b.x - a.x)
  }
}

public struct JournalEntry: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID = UUID()
  public let time: Double
  public let text: String
}

public struct Simulation: Codable, Equatable, Sendable {
  public var version = 1
  public var trains: [Train] = [
    Train(id: "R01", name: "The Fox", origin: .alder, destination: .summit),
    Train(id: "B02", name: "Bluebird", origin: .harbor, destination: .alder),
  ]
  public var signals: [String: Bool] = ["alder": true, "summit": true, "harbor": false]
  public var scenic = false
  public var eastSwitch: Station = .summit
  public var corridorOwner: String?
  public var elapsed = 0.0
  public var paused = true
  public var speed = 1.0
  public var journal: [JournalEntry] = []

  public init() {
    record("Morning shift ready. Stillwater signal is at STOP.")
  }
  public var delivered: Int { trains.filter { $0.state == .delivered }.count }
  public var corridorLabel: String { corridorOwner.map { "Reserved · \($0)" } ?? "Clear" }
  public mutating func record(_ text: String) {
    journal.insert(JournalEntry(time: elapsed, text: text), at: 0)
    if journal.count > 80 { journal.removeLast() }
  }
  @discardableResult
  public mutating func dispatch(_ id: String) -> Bool {
    guard let i = trains.firstIndex(where: { $0.id == id }), trains[i].state == .ready,
      trains[i].origin != trains[i].destination
    else { return false }
    trains[i].route = Network.route(
      from: trains[i].origin, to: trains[i].destination, scenic: scenic)
    trains[i].state = .running
    trains[i].departure = elapsed
    record("\(id) dispatched to \(trains[i].destination.title).")
    return true
  }
  public mutating func setDestination(_ id: String, station: Station) {
    guard let i = trains.firstIndex(where: { $0.id == id }), trains[i].state == .ready,
      trains[i].origin != station
    else { return }
    trains[i].destination = station
  }
  public mutating func toggleSignal(_ station: Station) {
    signals[station.rawValue] = !(signals[station.rawValue] ?? false)
    record("\(station.title) signal → \(signals[station.rawValue] == true ? "CLEAR" : "STOP").")
  }
  @discardableResult
  public mutating func toggleWestSwitch() -> Bool {
    guard corridorOwner == nil else { return false }
    scenic.toggle()
    rerouteApproaching()
    record("W1 points → \(scenic ? "forest loop" : "main line").")
    return true
  }
  @discardableResult
  public mutating func toggleEastSwitch() -> Bool {
    guard corridorOwner == nil else { return false }
    eastSwitch = eastSwitch == .summit ? .harbor : .summit
    record("W2 points → \(eastSwitch.title).")
    return true
  }
  private mutating func rerouteApproaching() {
    for i in trains.indices where trains[i].state == .running && trains[i].legIndex == 0 {
      trains[i].route = Network.route(
        from: trains[i].origin, to: trains[i].destination, scenic: scenic)
    }
  }
  private func admissionReason(for train: Train) -> String {
    if signals[train.origin.rawValue] != true { return "Held at signal" }
    if let owner = corridorOwner, owner != train.id { return "Block occupied by \(owner)" }
    let eastStation = train.origin == .alder ? train.destination : train.origin
    if eastSwitch != eastStation { return "Set W2 to \(eastStation.code)" }
    let occupied = trains.contains { other in
      guard other.id != train.id else { return false }
      if other.state == .delivered { return other.destination == train.destination }
      return other.origin == train.destination && (other.state == .ready || other.legIndex == 0)
    }
    if occupied { return "Destination platform occupied" }
    return ""
  }
  public mutating func tick(_ seconds: Double) {
    guard !paused, seconds.isFinite, seconds > 0 else { return }
    var remaining = min(seconds, 5) * speed
    while remaining > 0.00001 {
      let dt = min(remaining, 0.05)
      step(dt)
      remaining -= dt
    }
  }
  private mutating func step(_ dt: Double) {
    elapsed += dt
    for i in trains.indices where trains[i].state == .running {
      let leg = trains[i].route[trains[i].legIndex]
      let length = Network.track(leg.trackID).length
      let next = trains[i].progress + dt * 28 / length
      if trains[i].legIndex == 0 && next >= 0.82 && corridorOwner != trains[i].id {
        let reason = admissionReason(for: trains[i])
        trains[i].waiting = reason
        if !reason.isEmpty {
          trains[i].progress = 0.82
          continue
        }
        corridorOwner = trains[i].id
        record("Block 01 reserved for \(trains[i].id). Points locked.")
      }
      trains[i].waiting = ""
      trains[i].progress = min(next, 1)
      if next >= 1 {
        if trains[i].legIndex + 1 == trains[i].route.count {
          trains[i].state = .delivered
          trains[i].arrival = elapsed
          if corridorOwner == trains[i].id { corridorOwner = nil }
          record("\(trains[i].id) arrived at \(trains[i].destination.title). Block released.")
        } else {
          trains[i].legIndex += 1
          trains[i].progress = 0
        }
      }
    }
  }
  public func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }
  public static func decoded(_ data: Data) throws -> Simulation {
    let state = try JSONDecoder().decode(Simulation.self, from: data)
    guard state.version == 1, state.trains.count == 2,
      Set(state.trains.map(\.id)) == Set(["R01", "B02"]),
      state.elapsed.isFinite, state.elapsed >= 0,
      [1.0, 2.0, 4.0].contains(state.speed),
      state.eastSwitch != .alder,
      Set(state.signals.keys) == Set(Station.allCases.map(\.rawValue)),
      state.journal.count <= 80,
      state.journal.allSatisfy({ $0.time.isFinite && $0.time >= 0 }),
      state.trains.allSatisfy({ train in
        guard train.origin != train.destination, train.progress.isFinite,
          (0...1).contains(train.progress), train.legIndex >= 0,
          train.departure.map({ $0.isFinite && $0 >= 0 }) ?? true,
          train.arrival.map({ $0.isFinite && $0 >= 0 }) ?? true
        else { return false }
        if train.state == .ready {
          return train.route.isEmpty && train.legIndex == 0 && train.progress == 0
        }
        let direct = Network.route(from: train.origin, to: train.destination, scenic: false)
        let loop = Network.route(from: train.origin, to: train.destination, scenic: true)
        return (train.route == direct || train.route == loop) && train.legIndex < train.route.count
      })
    else { throw SaveError.invalid }
    let admitted = state.trains.filter {
      $0.state == .running && ($0.legIndex > 0 || $0.progress > 0.82)
    }
    guard admitted.count <= 1,
      admitted.allSatisfy({ $0.id == state.corridorOwner }),
      state.corridorOwner == nil
        || state.trains.contains(where: {
          $0.id == state.corridorOwner && $0.state == .running
            && ($0.legIndex > 0 || $0.progress >= 0.82)
        })
    else { throw SaveError.invalid }
    return state
  }
}

public enum SaveError: Error, LocalizedError {
  case invalid
  public var errorDescription: String? {
    "This save contains an invalid or incompatible railway state."
  }
}
