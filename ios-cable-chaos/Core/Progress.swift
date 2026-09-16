import Foundation

/// Per-level best results. Codable so the app can persist it as JSON.
public struct Progress: Codable, Equatable, Sendable {
  public struct Result: Codable, Equatable, Sendable {
    public var stars: Int
    public var bestTime: Double
    public var bestMoves: Int
    public init(stars: Int, bestTime: Double, bestMoves: Int) {
      self.stars = stars
      self.bestTime = bestTime
      self.bestMoves = bestMoves
    }
  }

  public var results: [Int: Result] = [:]
  public var soundEnabled = true
  public var hapticsEnabled = true

  public init() {}

  public var totalStars: Int { results.values.reduce(0) { $0 + $1.stars } }
  public var solvedCount: Int { results.count }

  /// Highest level id the player may attempt (the first unsolved one, or the last level).
  public func isUnlocked(_ id: Int) -> Bool {
    id <= 1 || results[id - 1] != nil
  }

  public var nextLevel: Int {
    min(LevelCatalog.count, (results.keys.max() ?? 0) + 1)
  }

  /// Merges a finished board, keeping the best of each stat. Returns true if anything improved.
  @discardableResult
  public mutating func record(_ board: Board) -> Bool {
    guard board.phase == .solved else { return false }
    let fresh = Result(stars: board.stars, bestTime: board.elapsed, bestMoves: board.moves)
    guard let old = results[board.level.id] else {
      results[board.level.id] = fresh
      return true
    }
    let merged = Result(
      stars: max(old.stars, fresh.stars), bestTime: min(old.bestTime, fresh.bestTime),
      bestMoves: min(old.bestMoves, fresh.bestMoves))
    results[board.level.id] = merged
    return merged != old
  }

  public func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(self)
  }

  public static func decode(_ data: Data) -> Progress {
    (try? JSONDecoder().decode(Progress.self, from: data)) ?? Progress()
  }
}
