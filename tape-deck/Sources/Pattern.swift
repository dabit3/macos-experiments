import Foundation

enum Drum: Int, CaseIterable, Codable, Identifiable {
  case kick, snare, hat, clap

  var id: Int { rawValue }
  var name: String { ["Kick", "Snare", "Hat", "Clap"][rawValue] }
  var subtitle: String { ["ROUND / LOW", "DUST / SNAP", "AIR / TICK", "ROOM / HAND"][rawValue] }
}

struct Pattern: Codable, Equatable {
  var name: String
  var tempo: Double
  var swing: Double
  var steps: [[Bool]]
  var muted: [Bool]
  var soloed: [Bool]

  init(name: String = "Untitled tape", tempo: Double = 96, swing: Double = 0) {
    self.name = name
    self.tempo = tempo
    self.swing = swing
    steps = Array(repeating: Array(repeating: false, count: 16), count: 4)
    muted = Array(repeating: false, count: 4)
    soloed = Array(repeating: false, count: 4)
  }

  var activeMask: Int {
    let hasSolo = soloed.contains(true)
    return Drum.allCases.reduce(0) { result, drum in
      let index = drum.rawValue
      return result | ((!muted[index] && (!hasSolo || soloed[index])) ? (1 << index) : 0)
    }
  }

  func normalized() -> Pattern {
    var copy = self
    copy.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
    if copy.name.isEmpty { copy.name = "Untitled tape" }
    copy.tempo = tempo.isFinite ? min(180, max(60, tempo.rounded())) : 96
    copy.swing = swing.isFinite ? min(0.6, max(0, swing)) : 0
    copy.steps = (0..<4).map { track in
      (0..<16).map { step in
        steps.indices.contains(track) && steps[track].indices.contains(step)
          ? steps[track][step] : false
      }
    }
    copy.muted = (0..<4).map { muted.indices.contains($0) ? muted[$0] : false }
    copy.soloed = (0..<4).map { soloed.indices.contains($0) ? soloed[$0] : false }
    return copy
  }

  static let presets: [Pattern] = {
    let definitions: [(String, Double, Double, [[Int]])] = [
      ("Warm start", 96, 0.16, [[0, 6, 8, 14], [4, 12], [0, 2, 4, 6, 8, 10, 12, 14], [12]]),
      ("Night drive", 118, 0, [[0, 4, 8, 12], [4, 12], [2, 6, 10, 14], [4, 12]]),
      ("Loose change", 82, 0.42, [[0, 7, 10], [4, 12, 15], [0, 2, 3, 6, 8, 10, 11, 14], [13]]),
      (
        "Broken radio", 132, 0.08,
        [[0, 3, 8, 10], [4, 11, 12], [0, 2, 6, 8, 10, 14, 15], [7, 15]]
      ),
    ]
    return definitions.map { name, tempo, swing, hits in
      var pattern = Pattern(name: name, tempo: tempo, swing: swing)
      for track in 0..<4 {
        for step in hits[track] { pattern.steps[track][step] = true }
      }
      return pattern
    }
  }()
}

enum SequencerClock {
  static func duration(step: Int, tempo: Double, swing: Double) -> Double {
    let safeTempo = tempo.isFinite ? min(180, max(60, tempo)) : 96
    let safeSwing = swing.isFinite ? min(0.6, max(0, swing)) : 0
    return 60 / safeTempo / 4 * (step.isMultiple(of: 2) ? 1 + safeSwing : 1 - safeSwing)
  }

  static func barDuration(tempo: Double) -> Double {
    (0..<16).reduce(0) { $0 + duration(step: $1, tempo: tempo, swing: 0) }
  }
}

struct SavedTape: Codable, Identifiable, Equatable {
  var id = UUID()
  var pattern: Pattern
  var created = Date()
}

struct TapeArchive: Codable, Equatable {
  var version = 1
  var current = Pattern.presets[0]
  var tapes: [SavedTape] = []
}

struct TapeRepository {
  let url: URL

  func load() throws -> TapeArchive {
    guard FileManager.default.fileExists(atPath: url.path) else { return TapeArchive() }
    var archive = try JSONDecoder().decode(TapeArchive.self, from: Data(contentsOf: url))
    guard archive.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
    archive.current = archive.current.normalized()
    archive.tapes = archive.tapes.map {
      var tape = $0
      tape.pattern = tape.pattern.normalized()
      return tape
    }
    return archive
  }

  func save(_ archive: TapeArchive) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(archive).write(to: url, options: .atomic)
  }
}
