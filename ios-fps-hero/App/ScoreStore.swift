import Foundation

final class ScoreStore {
  static let shared = ScoreStore()

  private let recordsKey = "fpshero.records"
  private let runsKey = "fpshero.runs"
  private let soundKey = "fpshero.sound"
  private let hapticsKey = "fpshero.haptics"

  private(set) var records: [ScoreRecord] = []

  var runs: Int {
    get { UserDefaults.standard.integer(forKey: runsKey) }
    set { UserDefaults.standard.set(newValue, forKey: runsKey) }
  }

  var soundOn: Bool {
    get { UserDefaults.standard.object(forKey: soundKey) as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: soundKey) }
  }

  var hapticsOn: Bool {
    get { UserDefaults.standard.object(forKey: hapticsKey) as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: hapticsKey) }
  }

  init() {
    if let data = UserDefaults.standard.data(forKey: recordsKey),
      let decoded = try? JSONDecoder().decode([ScoreRecord].self, from: data)
    {
      records = decoded
    }
  }

  func best(for trackId: String) -> ScoreRecord? {
    records.filter { $0.trackId == trackId }.max(by: { $0.score < $1.score })
  }

  var overallBest: ScoreRecord? {
    records.max(by: { $0.score < $1.score })
  }

  /// Records a run. Returns true if it beat the track's previous best.
  @discardableResult
  func record(_ record: ScoreRecord) -> Bool {
    let previous = best(for: record.trackId)?.score ?? -1
    records.append(record)
    runs += 1
    if let data = try? JSONEncoder().encode(records) {
      UserDefaults.standard.set(data, forKey: recordsKey)
    }
    return record.score > previous
  }
}
