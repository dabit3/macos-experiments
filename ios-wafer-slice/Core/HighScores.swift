import Foundation

public struct HighScoreEntry: Codable, Equatable, Identifiable {
  public var id: UUID
  public var score: Int
  public var bin: String
  public var sliced: Int
  public var bestSwipe: Int
  public var date: Date

  public init(
    id: UUID = UUID(), score: Int, bin: String, sliced: Int, bestSwipe: Int, date: Date
  ) {
    self.id = id
    self.score = score
    self.bin = bin
    self.sliced = sliced
    self.bestSwipe = bestSwipe
    self.date = date
  }
}

/// Local-only leaderboard with a top list per mode plus lifetime fab stats.
public struct HighScoreBoard: Codable, Equatable {
  public static let capacity = 10

  public private(set) var entries: [GameMode: [HighScoreEntry]] = [:]
  public private(set) var lifetimeSliced = 0
  public private(set) var lifetimeRuns = 0
  public private(set) var lifetimeFlagships = 0

  public init() {}

  public func top(_ mode: GameMode) -> [HighScoreEntry] { entries[mode] ?? [] }

  public func best(_ mode: GameMode) -> Int { top(mode).first?.score ?? 0 }

  /// Records a finished run. Returns the 1-based rank when the run made the
  /// list, or nil when it did not qualify.
  @discardableResult
  public mutating func record(_ run: RunSummary, date: Date = Date()) -> Int? {
    lifetimeRuns += 1
    lifetimeSliced += run.sliced - run.defectiveHits
    lifetimeFlagships += run.flagshipHits
    guard run.score > 0 else { return nil }
    var list = top(run.mode)
    let entry = HighScoreEntry(
      score: run.score, bin: run.bin, sliced: run.sliced - run.defectiveHits,
      bestSwipe: run.bestSwipe, date: date)
    let index = list.firstIndex { $0.score < entry.score } ?? list.count
    guard index < Self.capacity else { return nil }
    list.insert(entry, at: index)
    if list.count > Self.capacity { list.removeLast(list.count - Self.capacity) }
    entries[run.mode] = list
    return index + 1
  }

  public func encoded() throws -> Data { try JSONEncoder().encode(self) }

  public static func decode(_ data: Data) -> HighScoreBoard {
    (try? JSONDecoder().decode(HighScoreBoard.self, from: data)) ?? HighScoreBoard()
  }
}
