import Foundation

struct RhythmNote: Identifiable, Equatable {
  let id: Int
  let lane: Int
  let time: Double
}

struct Composition: Identifiable {
  let id: Int
  let name: String
  let subtitle: String
  let tempo: String
  let notes: [RhythmNote]
  var duration: Double { (notes.last?.time ?? 0) + 2 }

  static let all: [Composition] = [
    make(
      0, "First light", "A quiet awakening", "SLOW • 12 NOTES",
      lanes: [0, 1, 2, 0, 2, 1, 0, 1, 2, 1, 0, 2],
      intervals: [2.8]),
    make(
      1, "Jade current", "Follow the changing water", "FLOWING • 16 NOTES",
      lanes: [0, 2, 1, 0, 1, 2, 2, 0, 1, 2, 0, 1, 2, 1, 0, 2],
      intervals: [2.2, 1.8, 2.2, 2.6]),
    make(
      2, "Moon ballet", "A little wild, a little luminous", "SWIFT • 20 NOTES",
      lanes: [2, 0, 1, 2, 1, 0, 0, 2, 1, 0, 2, 1, 2, 0, 1, 2, 0, 2, 1, 0],
      intervals: [1.5, 1.5, 2.1, 1.8]),
  ]

  private static func make(
    _ id: Int, _ name: String, _ subtitle: String, _ tempo: String,
    lanes: [Int], intervals: [Double]
  ) -> Composition {
    var time = 3.0
    let notes = lanes.enumerated().map { index, lane in
      defer { time += intervals[index % intervals.count] }
      return RhythmNote(id: index, lane: lane, time: time)
    }
    return Composition(id: id, name: name, subtitle: subtitle, tempo: tempo, notes: notes)
  }
}

enum Judgement: String, Codable {
  case perfect = "Perfect"
  case good = "Lovely"
  case miss = "Miss"
  var value: Int {
    switch self {
    case .perfect: return 100
    case .good: return 70
    case .miss: return 0
    }
  }
}

struct TimingRules {
  let forgiving: Bool
  var perfectWindow: Double { forgiving ? 0.36 : 0.16 }
  var hitWindow: Double { forgiving ? 0.85 : 0.32 }
  let approachTime = 1.8

  func judge(offset: Double) -> Judgement {
    if abs(offset) <= perfectWindow { return .perfect }
    if abs(offset) <= hitWindow { return .good }
    return .miss
  }
}

struct Performance: Codable, Equatable {
  let compositionID: Int
  let perfect: Int
  let good: Int
  let missed: Int
  let maxCombo: Int
  let forgiving: Bool
  var total: Int { perfect + good + missed }
  var accuracy: Int {
    guard total > 0 else { return 0 }
    return Int((Double(perfect * 100 + good * 70) / Double(total)).rounded())
  }
  var cleared: Bool {
    total > 0 && accuracy >= 60 && perfect + good >= Int(ceil(Double(total) * 0.7))
  }
  var rank: String {
    if accuracy == 100 { return "Moon virtuoso" }
    if accuracy >= 90 { return "Luminous" }
    if cleared { return "In bloom" }
    return "Still learning"
  }
}

struct RhythmEngine {
  let composition: Composition
  let rules: TimingRules
  private(set) var judgements: [Int: Judgement] = [:]
  private(set) var combo = 0
  private(set) var maxCombo = 0
  private(set) var perfectPhrases = 0
  private var consecutivePerfect = 0

  init(composition: Composition, rules: TimingRules) {
    self.composition = composition
    self.rules = rules
  }

  mutating func tap(lane: Int, at time: Double) -> Judgement? {
    guard
      let note = composition.notes
        .filter({
          $0.lane == lane && judgements[$0.id] == nil && abs($0.time - time) <= rules.hitWindow
        })
        .min(by: { abs($0.time - time) < abs($1.time - time) })
    else { return nil }
    let judgement = rules.judge(offset: time - note.time)
    record(note.id, judgement)
    return judgement
  }

  @discardableResult
  mutating func expire(at time: Double) -> Int {
    let expired = composition.notes.filter {
      judgements[$0.id] == nil && time > $0.time + rules.hitWindow
    }
    for note in expired { record(note.id, .miss) }
    return expired.count
  }

  private mutating func record(_ id: Int, _ judgement: Judgement) {
    judgements[id] = judgement
    combo = judgement == .miss ? 0 : combo + 1
    maxCombo = max(maxCombo, combo)
    consecutivePerfect = judgement == .perfect ? consecutivePerfect + 1 : 0
    if consecutivePerfect == 4 {
      perfectPhrases += 1
      consecutivePerfect = 0
    }
  }

  var performance: Performance {
    Performance(
      compositionID: composition.id,
      perfect: judgements.values.filter { $0 == .perfect }.count,
      good: judgements.values.filter { $0 == .good }.count,
      missed: judgements.values.filter { $0 == .miss }.count,
      maxCombo: maxCombo, forgiving: rules.forgiving
    )
  }
}
