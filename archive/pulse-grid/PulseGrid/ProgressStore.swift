import Foundation
import SwiftUI

struct CompletionRecord: Codable {
  var moves: Int
  var hints: Int
}

struct SavedProgress: Codable {
  var sessions: [Int: CircuitSession] = [:]
  var completions: [Int: CompletionRecord] = [:]
  var lastLevel = 0
  var haptics = true
}

@MainActor
final class ProgressStore: ObservableObject {
  @Published private(set) var data: SavedProgress
  private let defaults: UserDefaults
  private let key = "pulse-grid.progress.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let encoded = defaults.data(forKey: key),
      var decoded = try? JSONDecoder().decode(SavedProgress.self, from: encoded)
    {
      decoded.sessions = decoded.sessions.filter { id, session in
        Circuits.all.indices.contains(id) && session.isValid(for: Circuits.all[id])
      }
      decoded.completions = decoded.completions.filter { id, record in
        Circuits.all.indices.contains(id) && record.moves >= 0 && record.hints >= 0
      }
      decoded.lastLevel = Circuits.all.indices.contains(decoded.lastLevel) ? decoded.lastLevel : 0
      data = decoded
    } else {
      data = SavedProgress()
    }
  }

  var completedCount: Int { data.completions.count }
  var suggestedLevel: Int {
    if data.sessions[data.lastLevel] != nil,
      data.completions[data.lastLevel] == nil
    {
      return data.lastLevel
    }
    return Circuits.all.first { data.completions[$0.id] == nil }?.id ?? data.lastLevel
  }

  func session(for level: CircuitLevel) -> CircuitSession {
    data.sessions[level.id] ?? CircuitSession(level: level)
  }

  func save(_ session: CircuitSession, for level: CircuitLevel) {
    guard session.isValid(for: level) else { return }
    data.sessions[level.id] = session
    data.lastLevel = level.id
    if level.isSolved(turns: session.turns) {
      let record = CompletionRecord(moves: session.moves, hints: session.hints)
      let previous = data.completions[level.id]
      if previous == nil || record.hints < previous!.hints
        || (record.hints == previous!.hints && record.moves < previous!.moves)
      {
        data.completions[level.id] = record
      }
    }
    persist()
  }

  func setHaptics(_ enabled: Bool) {
    data.haptics = enabled
    persist()
  }

  func erase() {
    data = SavedProgress()
    persist()
  }

  private func persist() {
    guard let encoded = try? JSONEncoder().encode(data) else { return }
    defaults.set(encoded, forKey: key)
  }
}
