import Foundation

public struct LeaderboardEntry: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var name: String
  public var score: Int
  public var lines: Int
  public var level: Int
  public var tensorCores: Int
  public var date: Date

  public init(
    id: UUID = UUID(), name: String, score: Int, lines: Int, level: Int, tensorCores: Int,
    date: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.score = score
    self.lines = lines
    self.level = level
    self.tensorCores = tensorCores
    self.date = date
  }
}

/// Local-only top list. Pure value type; the app persists the encoded form.
public struct Leaderboard: Codable, Equatable, Sendable {
  public static let capacity = 10
  public private(set) var entries: [LeaderboardEntry] = []

  public init(entries: [LeaderboardEntry] = []) {
    self.entries = Array(entries.sorted { $0.score > $1.score }.prefix(Leaderboard.capacity))
  }

  /// Would a run with this score make the list?
  public func qualifies(score: Int) -> Bool {
    score > 0 && (entries.count < Leaderboard.capacity || score > (entries.last?.score ?? 0))
  }

  /// Inserts and returns the 1-based rank, or nil if it did not qualify.
  @discardableResult
  public mutating func submit(_ entry: LeaderboardEntry) -> Int? {
    guard qualifies(score: entry.score) else { return nil }
    entries.append(entry)
    entries.sort { $0.score > $1.score || ($0.score == $1.score && $0.date < $1.date) }
    if entries.count > Leaderboard.capacity {
      entries.removeLast(entries.count - Leaderboard.capacity)
    }
    return entries.firstIndex(where: { $0.id == entry.id }).map { $0 + 1 }
  }

  public var best: Int { entries.first?.score ?? 0 }

  public func encoded() throws -> Data { try JSONEncoder().encode(self) }

  public static func decode(_ data: Data) -> Leaderboard {
    (try? JSONDecoder().decode(Leaderboard.self, from: data)) ?? Leaderboard()
  }
}

/// Formats scores like a GPU spec sheet: 12,345 -> "12,345".
public enum ScoreFormat {
  public static func compact(_ value: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.groupingSeparator = ","
    return f.string(from: NSNumber(value: value)) ?? "\(value)"
  }

  /// Playful "clock" readout for the level: level 1 = 1.00 GHz, each level +0.15.
  public static func clock(level: Int) -> String {
    String(format: "%.2f GHz", 1.0 + Double(level - 1) * 0.15)
  }
}
