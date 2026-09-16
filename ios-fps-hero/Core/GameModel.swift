import Foundation

// MARK: - Deterministic RNG

public struct SeededRandom {
  public var state: UInt64
  public init(seed: UInt64) { state = seed }
  public mutating func next() -> Double {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Double(state >> 11) / Double(UInt64.max >> 11)
  }
  public mutating func nextInt(_ range: Range<Int>) -> Int {
    range.lowerBound + Int(next() * Double(range.count))
  }
}

// MARK: - Track

public struct Track: Equatable {
  public var id: String
  public var title: String
  public var bpm: Double
  public var duration: Double
  public var rootMidi: Int
  /// Midi triads, one per bar.
  public var chordProgression: [[Int]]
  /// Midi notes per 8th-note slot of a bar (repeats). 0 = rest.
  public var bassPattern: [Int]
  /// Semitone offsets from the bar's chord root, one per 16th slot.
  public var arpPattern: [Int]
  public var difficulty: String

  public var secondsPerBeat: Double { 60.0 / bpm }
  public var secondsPerBar: Double { secondsPerBeat * 4 }

  public static let tensorDrift = Track(
    id: "tensor-drift",
    title: "Tensor Drift",
    bpm: 104,
    duration: 60,
    rootMidi: 45,  // A1
    chordProgression: [
      [45, 52, 57, 60],  // Am
      [41, 48, 53, 57],  // F
      [43, 50, 55, 59],  // G
      [40, 47, 52, 55],  // Em
    ],
    bassPattern: [0, 0, 0, 0, 0, 0, 12, 0],
    arpPattern: [0, 7, 12, 16, 19, 16, 12, 7],
    difficulty: "chill")

  public static let rasterRush = Track(
    id: "raster-rush",
    title: "Raster Rush",
    bpm: 128,
    duration: 75,
    rootMidi: 43,  // G1
    chordProgression: [
      [43, 50, 55, 58],  // Gm
      [39, 46, 51, 55],  // Eb
      [41, 48, 53, 58],  // F
      [38, 45, 50, 53],  // D
    ],
    bassPattern: [0, 0, 7, 0, 0, 10, 0, 7],
    arpPattern: [0, 12, 7, 12, 19, 12, 7, 12, 0, 12, 7, 12, 22, 19, 12, 7],
    difficulty: "medium")

  public static let overclockOverdrive = Track(
    id: "overclock-overdrive",
    title: "Overclock Overdrive",
    bpm: 150,
    duration: 90,
    rootMidi: 41,  // F1
    chordProgression: [
      [41, 48, 53, 56],  // Fm
      [37, 44, 49, 53],  // Db
      [39, 46, 51, 56],  // Eb
      [36, 43, 48, 51],  // C
    ],
    bassPattern: [0, 0, 0, 7, 0, 0, 10, 12],
    arpPattern: [0, 7, 12, 15, 19, 15, 12, 7, 0, 7, 12, 19, 24, 19, 12, 7],
    difficulty: "hard")

  public static let all: [Track] = [tensorDrift, rasterRush, overclockOverdrive]
}

// MARK: - Notes & chart generation

public enum NoteKind: Equatable {
  case tap
  case hold(Double)
}

public struct Note: Equatable {
  public var id: Int
  public var lane: Int  // 0..3
  public var time: Double  // seconds; the moment it should be tapped
  public var kind: NoteKind
}

public enum ChartGenerator {
  public static let leadIn: Double = 2.0
  public static let tail: Double = 1.5
  public static let minLaneSpacing: Double = 0.12

  public static func notes(for track: Track, seed: UInt64) -> [Note] {
    var rng = SeededRandom(seed: seed)
    var result: [Note] = []
    var lastTimeInLane = [Double](repeating: -10, count: 4)
    let step: Double  // in beats
    let density: Double
    let chordChance: Double
    switch track.difficulty {
    case "chill":
      step = 1.0
      density = 0.85
      chordChance = 0.06
    case "hard":
      step = 0.25
      density = 0.42
      chordChance = 0.12
    default:
      step = 0.5
      density = 0.58
      chordChance = 0.08
    }
    let stepSeconds = track.secondsPerBeat * step
    let end = track.duration - tail
    var t = leadIn
    var id = 0
    var prevLane = -1
    while t <= end {
      if rng.next() < density {
        var lane = rng.nextInt(0..<4)
        if lane == prevLane && rng.next() < 0.6 {
          lane = rng.nextInt(0..<4)
        }
        if t - lastTimeInLane[lane] >= minLaneSpacing {
          result.append(Note(id: id, lane: lane, time: t, kind: .tap))
          id += 1
          lastTimeInLane[lane] = t
          prevLane = lane
          if rng.next() < chordChance {
            var other = rng.nextInt(0..<4)
            while other == lane { other = rng.nextInt(0..<4) }
            if t - lastTimeInLane[other] >= minLaneSpacing {
              result.append(Note(id: id, lane: other, time: t, kind: .tap))
              id += 1
              lastTimeInLane[other] = t
            }
          }
        }
      }
      t += stepSeconds
    }
    return result.sorted { $0.time < $1.time || ($0.time == $1.time && $0.lane < $1.lane) }
  }
}

// MARK: - Judgment

public enum Judgment: String, Equatable, CaseIterable {
  case perfect, great, good, miss

  public static let perfectWindow = 0.045
  public static let greatWindow = 0.09
  public static let goodWindow = 0.14

  public static func forDelta(_ delta: Double) -> Judgment {
    let d = abs(delta)
    if d <= perfectWindow { return .perfect }
    if d <= greatWindow { return .great }
    if d <= goodWindow { return .good }
    return .miss
  }

  public var baseScore: Int {
    switch self {
    case .perfect: return 1000
    case .great: return 700
    case .good: return 300
    case .miss: return 0
    }
  }

  public var fpsDelta: Double {
    switch self {
    case .perfect: return 18
    case .great: return 10
    case .good: return 4
    case .miss: return -45
    }
  }

  public var dlssCharge: Double {
    switch self {
    case .perfect: return 0.04
    case .great: return 0.02
    default: return 0
    }
  }
}

// MARK: - Events

public enum GameEvent: Equatable {
  case missed(Note)
  case autoHit(Note)
  case finished
}

// MARK: - Phase

public enum GamePhase: Equatable {
  case countdown
  case playing
  case finished
}

// MARK: - DLSS

public struct DLSSState: Equatable {
  public var charge: Double = 0  // 0...1
  public var activeUntil: Double?
  public static let duration: Double = 4.0

  public var isFull: Bool { charge >= 1 }
  public func isActive(at time: Double) -> Bool {
    guard let until = activeUntil else { return false }
    return time < until
  }
}

// MARK: - GameState

public struct GameState {
  public var track: Track
  public var notes: [Note]
  public var hit: Set<Int> = []
  public var time: Double = 0
  public var score: Int = 0
  public var combo: Int = 0
  public var maxCombo: Int = 0
  public var counts: [Judgment: Int] = [:]
  public var fps: Double = 240
  public var phase: GamePhase = .countdown
  public var dlss = DLSSState()
  public private(set) var fpsIntegral: Double = 0
  public private(set) var fpsIntegralTime: Double = 0

  public init(track: Track, notes: [Note]) {
    self.track = track
    self.notes = notes
  }

  public var lag: Double { (240 - fps) / 210 }

  public var accuracy: Double {
    let total = notes.count
    guard total > 0 else { return 0 }
    var weighted = 0
    for (j, c) in counts { weighted += j.baseScore * c }
    return Double(weighted) / Double(total * 1000)
  }

  public var averageFPS: Double {
    fpsIntegralTime > 0 ? fpsIntegral / fpsIntegralTime : fps
  }

  public func multiplier(afterHit combo: Int) -> Double {
    1 + Double(min(combo, 50)) / 50
  }

  /// Advances game time. Emits misses for notes past the good window,
  /// auto-hits while DLSS frame generation is active, and .finished at track end.
  @discardableResult
  public mutating func advance(to newTime: Double) -> [GameEvent] {
    var events: [GameEvent] = []
    guard newTime > time else { return events }
    if phase == .countdown && newTime >= 0 { phase = .playing }
    if phase == .playing {
      fpsIntegral += fps * (newTime - time)
      fpsIntegralTime += newTime - time
    }
    for i in notes.indices {
      let note = notes[i]
      if hit.contains(note.id) { continue }
      if note.time > newTime { break }
      if dlss.isActive(at: note.time) {
        register(.perfect, note: note)
        hit.insert(note.id)
        events.append(.autoHit(note))
      } else if note.time + Judgment.goodWindow <= newTime {
        register(.miss, note: note)
        hit.insert(note.id)
        events.append(.missed(note))
      }
    }
    time = newTime
    if phase == .playing && newTime >= track.duration {
      phase = .finished
      events.append(.finished)
    }
    return events
  }

  /// Taps a lane. Returns the judgment of the nearest un-hit note in that lane
  /// within the good window, or nil for a whiff.
  @discardableResult
  public mutating func tap(lane: Int, at tapTime: Double) -> Judgment? {
    guard phase != .finished else { return nil }
    var best: Note?
    var bestDelta = Double.greatestFiniteMagnitude
    for note in notes {
      guard note.lane == lane, !hit.contains(note.id) else { continue }
      let d = abs(note.time - tapTime)
      if d <= Judgment.goodWindow && d < bestDelta {
        best = note
        bestDelta = d
      }
    }
    guard let note = best else { return nil }
    let judgment = Judgment.forDelta(note.time - tapTime)
    register(judgment, note: note)
    hit.insert(note.id)
    return judgment
  }

  public mutating func activateDLSS() -> Bool {
    guard dlss.isFull else { return false }
    dlss.charge = 0
    dlss.activeUntil = time + DLSSState.duration
    return true
  }

  private mutating func register(_ judgment: Judgment, note: Note) {
    counts[judgment, default: 0] += 1
    if judgment == .miss {
      combo = 0
    } else {
      combo += 1
      maxCombo = max(maxCombo, combo)
      let mult = 1 + Double(min(combo, 50)) / 50
      score += Int((Double(judgment.baseScore) * mult).rounded())
    }
    fps = min(240, max(30, fps + judgment.fpsDelta))
    dlss.charge = min(1, dlss.charge + judgment.dlssCharge)
  }
}

// MARK: - Grade

public enum Grade: String, Equatable, CaseIterable {
  case s = "S"
  case a = "A"
  case b = "B"
  case c = "C"
  case d = "D"

  public static func forAccuracy(_ accuracy: Double) -> Grade {
    if accuracy >= 0.95 { return .s }
    if accuracy >= 0.9 { return .a }
    if accuracy >= 0.8 { return .b }
    if accuracy >= 0.65 { return .c }
    return .d
  }

  public var title: String {
    switch self {
    case .s: return "RTX ON"
    case .a: return "TENSOR CORES ENGAGED"
    case .b: return "CUDA CORES WARMED UP"
    case .c: return "DRIVER UPDATE AVAILABLE (JUST KIDDING)"
    case .d: return "VRAM OVERFLOW"
    }
  }

  public var flavor: String {
    switch self {
    case .s: return "Wafer yield: 99%. Frame pacing: buttery."
    case .a: return "Ray reconstruction approved this run."
    case .b: return "Solid clocks. A little thermal headroom left."
    case .c: return "Frame pacing: mostly. Re-seat the GPU and retry."
    case .d: return "Thermal throttle! The silicon demands a rematch."
    }
  }
}

// MARK: - ScoreRecord

public struct ScoreRecord: Codable, Equatable {
  public var trackId: String
  public var score: Int
  public var grade: String
  public var maxCombo: Int
  public var accuracy: Double
  public var date: Date

  public init(
    trackId: String, score: Int, grade: Grade, maxCombo: Int, accuracy: Double, date: Date = Date()
  ) {
    self.trackId = trackId
    self.score = score
    self.grade = grade.rawValue
    self.maxCombo = maxCombo
    self.accuracy = accuracy
    self.date = date
  }
}
