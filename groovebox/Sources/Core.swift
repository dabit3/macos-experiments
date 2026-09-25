import Foundation

enum Drum: Int, Codable, CaseIterable {
  case kick, snare, hat, clap

  var name: String { ["Kick", "Snare", "Hi-hat", "Clap"][rawValue] }
  var detail: String { ["SUB / 808", "NOISE / SNAP", "METAL / CLOSED", "BURST / WIDE"][rawValue] }
}

struct Pattern: Codable, Equatable, Identifiable {
  var id = UUID()
  var name: String
  var bpm: Double = 112
  var swing: Double = 0.12
  var volume: Double = 0.8
  var steps: [[Bool]] = Array(repeating: Array(repeating: false, count: 16), count: 4)
  var muted: [Bool] = Array(repeating: false, count: 4)
  var solo: Int?

  var isValid: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 40
      && bpm.isFinite && (50...200).contains(bpm)
      && swing.isFinite && (0...0.5).contains(swing)
      && volume.isFinite && (0...1).contains(volume)
      && steps.count == 4 && steps.allSatisfy { $0.count == 16 }
      && muted.count == 4 && (solo == nil || (0..<4).contains(solo!))
  }

  func audible(_ track: Int) -> Bool {
    !muted[track] && (solo == nil || solo == track)
  }

  func stepDuration(_ step: Int, sampleRate: Double) -> Double {
    sampleRate * 60 / bpm / 4 * (step.isMultiple(of: 2) ? 1 + swing : 1 - swing)
  }

  static var presets: [Pattern] {
    [
      make(
        "Midnight circuit", bpm: 112, swing: 0.12,
        hits: [[0, 6, 8, 10], [4, 12], [0, 2, 4, 6, 8, 10, 12, 14], [12, 15]]),
      make(
        "Four on the floor", bpm: 124, swing: 0,
        hits: [[0, 4, 8, 12], [4, 12], [2, 6, 10, 14], [4, 12]]),
      make(
        "Broken satellites", bpm: 92, swing: 0.3,
        hits: [[0, 3, 10], [4, 12, 14], [0, 2, 5, 6, 8, 11, 14], [7, 15]]),
    ]
  }

  static func make(_ name: String, bpm: Double, swing: Double, hits: [[Int]]) -> Pattern {
    var result = Pattern(name: name, bpm: bpm, swing: swing)
    for (track, positions) in hits.enumerated() {
      for position in positions { result.steps[track][position] = true }
    }
    return result
  }
}

enum DrumSynth {
  static let sampleRate = 48_000.0

  static func voice(_ drum: Drum, sampleRate: Double = sampleRate) -> [Float] {
    let duration = [0.52, 0.24, 0.095, 0.29][drum.rawValue]
    var seed: UInt64 = UInt64(drum.rawValue + 1) * 9277
    var phase = 0.0
    var previousNoise = 0.0
    return (0..<Int(duration * sampleRate)).map { index in
      let time = Double(index) / sampleRate
      seed = seed &* 6_364_136_223_846_793_005 &+ 1
      let noise = Double(seed >> 40) / Double(1 << 24) * 2 - 1
      let high = (noise - previousNoise) * 0.5
      previousNoise = noise
      let attack = min(1, time * 4000)
      let sample: Double
      switch drum {
      case .kick:
        phase += 2 * .pi * (46 + 135 * exp(-time * 45)) / sampleRate
        sample =
          sin(phase) * exp(-time * 10) * 0.92
          + high * exp(-time * 150) * 0.17
      case .snare:
        sample = (noise * 0.65 + sin(2 * .pi * 185 * time) * 0.4) * exp(-time * 23)
      case .hat:
        let metal = sin(2 * .pi * 6310 * time) * sin(2 * .pi * 8190 * time)
        sample = (high * 0.65 + metal * 0.2) * exp(-time * 55)
      case .clap:
        let burst = [0.0, 0.011, 0.023].reduce(0.0) { value, onset in
          value + (time >= onset ? exp(-(time - onset) * 95) : 0)
        }
        sample = high * (burst * 0.47 + exp(-time * 18) * 0.38)
      }
      let endFade = min(1, (duration - time) * 500)
      return Float(sample * attack * endFade)
    }
  }
}

/// Sample-clock sequencer shared by the audio callback and offline export.
final class RenderMachine {
  let sampleRate: Double
  let voices: [[Float]]
  private var cursors = Array(repeating: -1, count: 4)
  private var remaining = 0.0
  private(set) var step = -1
  private(set) var playing = false
  private(set) var pattern: Pattern

  init(pattern: Pattern, sampleRate: Double = DrumSynth.sampleRate) {
    self.pattern = pattern
    self.sampleRate = sampleRate
    voices = Drum.allCases.map { DrumSynth.voice($0, sampleRate: sampleRate) }
  }

  func update(_ next: Pattern) {
    guard next.isValid else { return }
    if step >= 0 {
      remaining *=
        next.stepDuration(step, sampleRate: sampleRate)
        / pattern.stepDuration(step, sampleRate: sampleRate)
    }
    pattern = next
  }

  func start() {
    step = -1
    remaining = 0
    playing = true
    cursors = Array(repeating: -1, count: 4)
  }

  func stop() {
    playing = false
    step = -1
    cursors = Array(repeating: -1, count: 4)
  }

  func hit(_ drum: Drum) { cursors[drum.rawValue] = 0 }

  func nextSample() -> Float {
    if playing {
      if remaining <= 0 {
        step = (step + 1) % 16
        remaining += pattern.stepDuration(step, sampleRate: sampleRate)
        for track in 0..<4 where pattern.steps[track][step] && pattern.audible(track) {
          cursors[track] = 0
        }
      }
      remaining -= 1
    }
    var sample: Float = 0
    for track in 0..<4 where cursors[track] >= 0 {
      sample += voices[track][cursors[track]]
      cursors[track] += 1
      if cursors[track] >= voices[track].count { cursors[track] = -1 }
    }
    return tanh(sample * 0.72) * Float(pattern.volume)
  }

  func endSequence() { playing = false }
}

enum WaveExport {
  static func samples(pattern: Pattern, bars: Int = 2) -> [Float] {
    let renderer = RenderMachine(pattern: pattern)
    renderer.start()
    let frames = Int((Double(bars) * 4 * 60 / pattern.bpm * DrumSynth.sampleRate).rounded())
    var result = (0..<frames).map { _ in renderer.nextSample() }
    renderer.endSequence()
    result += (0..<Int(DrumSynth.sampleRate * 0.55)).map { _ in renderer.nextSample() }
    return result
  }

  static func wav(_ samples: [Float]) -> Data {
    var data = Data()
    func text(_ string: String) { data.append(contentsOf: string.utf8) }
    func u16(_ value: UInt16) {
      data.append(UInt8(value & 255))
      data.append(UInt8(value >> 8))
    }
    func u32(_ value: UInt32) {
      u16(UInt16(value & 65535))
      u16(UInt16(value >> 16))
    }
    text("RIFF")
    u32(UInt32(samples.count * 2 + 36))
    text("WAVEfmt ")
    u32(16)
    u16(1)
    u16(1)
    u32(48_000)
    u32(96_000)
    u16(2)
    u16(16)
    text("data")
    u32(UInt32(samples.count * 2))
    for sample in samples {
      u16(UInt16(bitPattern: Int16((min(1, max(-1, sample)) * 32767).rounded())))
    }
    return data
  }
}

struct LibraryState: Codable {
  var current: Pattern
  var saved: [Pattern]

  func write(to url: URL) throws {
    try JSONEncoder().encode(self).write(to: url, options: .atomic)
  }

  static func read(from url: URL) throws -> LibraryState {
    let state = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    guard state.current.isValid && state.saved.allSatisfy(\.isValid) else {
      throw CocoaError(.fileReadCorruptFile)
    }
    return state
  }
}
