import Foundation

enum FlightMode: String, Codable, CaseIterable {
  case practice
  case endless

  var title: String { self == .practice ? "Practice" : "Endless" }
  var travelTime: Double { self == .practice ? 12 : 4.8 }
  var spacing: Double { self == .practice ? 11 : 2.9 }
}

enum FlightPhase: Equatable {
  case ready, running, paused, ended
}

struct FlightWave: Identifiable, Equatable {
  let id: Int
  let hazard: Int
  let energy: Int
  var progress: Double
}

enum FlightEvent: Equatable {
  case energy(Int)
  case nearMiss(Int)
  case collision
  case gameOver
}

struct FlightRecord: Codable, Equatable {
  var practiceBest = 0
  var endlessBest = 0
  var flights = 0
  var totalEnergy = 0

  func best(for mode: FlightMode) -> Int {
    mode == .practice ? practiceBest : endlessBest
  }

  mutating func save(mode: FlightMode, score: Int, energy: Int) {
    if mode == .practice {
      practiceBest = max(practiceBest, score)
    } else {
      endlessBest = max(endlessBest, score)
    }
    flights += 1
    totalEnergy += energy
  }
}

struct FlightStore {
  let defaults: UserDefaults
  private let key = "lumen-drift.records.v1"

  func load() -> FlightRecord {
    guard let data = defaults.data(forKey: key),
      let record = try? JSONDecoder().decode(FlightRecord.self, from: data)
    else { return FlightRecord() }
    return record
  }

  func save(_ record: FlightRecord) {
    guard let data = try? JSONEncoder().encode(record) else { return }
    defaults.set(data, forKey: key)
  }
}

struct DriftEngine {
  private(set) var mode: FlightMode = .practice
  private(set) var phase: FlightPhase = .ready
  private(set) var lane = 1
  private(set) var shields = 2
  private(set) var elapsed = 0.0
  private(set) var distance = 0.0
  private(set) var bonus = 0
  private(set) var energy = 0
  private(set) var combo = 0
  private(set) var nearMisses = 0
  private(set) var waves: [FlightWave] = []
  private var nextWave = 0.0
  private var sequence = 0
  private var randomState: UInt64 = 1

  var score: Int { Int(distance) + bonus }
  var multiplier: Int { min(4, 1 + combo / 2) }
  var speed: Double {
    mode == .practice ? 1 : min(1.65, 1 + elapsed / 180)
  }
  var approaching: FlightWave? { waves.max { $0.progress < $1.progress } }

  mutating func start(_ mode: FlightMode, seed: UInt64 = 42) {
    self = DriftEngine()
    self.mode = mode
    phase = .running
    randomState = max(1, seed)
    spawn()
    nextWave = mode.spacing
  }

  mutating func steer(to lane: Int) {
    guard phase == .running else { return }
    self.lane = min(2, max(0, lane))
  }

  mutating func pause() {
    if phase == .running { phase = .paused }
  }

  mutating func resume() {
    if phase == .paused { phase = .running }
  }

  mutating func tick(_ delta: Double) -> [FlightEvent] {
    guard phase == .running, delta.isFinite, delta > 0, delta <= 0.25 else {
      return []
    }
    elapsed += delta
    distance += delta * (mode == .practice ? 7 : 20) * speed
    nextWave -= delta * speed
    if nextWave <= 0 {
      spawn()
      nextWave += mode.spacing
    }
    var events: [FlightEvent] = []
    for index in waves.indices {
      waves[index].progress += delta * speed / mode.travelTime
    }
    let crossings = waves.filter { $0.progress >= 1 }
    waves.removeAll { $0.progress >= 1 }
    for wave in crossings {
      events += resolve(wave)
      if phase == .ended { break }
    }
    return events
  }

  private mutating func resolve(_ wave: FlightWave) -> [FlightEvent] {
    if lane == wave.hazard {
      combo = 0
      if shields > 0 {
        shields -= 1
        return [.collision]
      }
      phase = .ended
      return [.collision, .gameOver]
    }
    var result: [FlightEvent] = []
    if abs(lane - wave.hazard) == 1 {
      combo += 1
      nearMisses += 1
      let points = 35 * multiplier
      bonus += points
      result.append(.nearMiss(points))
    } else {
      combo = 0
    }
    if lane == wave.energy {
      energy += 1
      let points = 100 * multiplier
      bonus += points
      result.append(.energy(points))
    }
    return result
  }

  private mutating func spawn() {
    let hazard: Int
    let energy: Int
    if mode == .practice {
      let hazards = [1, 0, 2, 1, 0, 2]
      let cells = [0, 2, 1, 2, 1, 0]
      hazard = hazards[sequence % hazards.count]
      energy = cells[sequence % cells.count]
    } else {
      randomState = randomState &* 6_364_136_223_846_793_005 &+ 1
      hazard = Int((randomState >> 32) % 3)
      randomState = randomState &* 6_364_136_223_846_793_005 &+ 1
      energy = (hazard + 1 + Int((randomState >> 32) % 2)) % 3
    }
    waves.append(FlightWave(id: sequence, hazard: hazard, energy: energy, progress: 0))
    sequence += 1
  }
}
