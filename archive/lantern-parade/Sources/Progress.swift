import SwiftUI
import UIKit

@MainActor
final class Progress: ObservableObject {
  @Published var best: [String: Int]
  @Published var saved: Parade?
  @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
  @Published var hasLearned: Bool { didSet { defaults.set(hasLearned, forKey: "learned") } }
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    best = defaults.dictionary(forKey: "best") as? [String: Int] ?? [:]
    haptics = defaults.object(forKey: "haptics") as? Bool ?? true
    hasLearned = defaults.bool(forKey: "learned")
    if let data = defaults.data(forKey: "parade"),
      let parade = try? JSONDecoder().decode(Parade.self, from: data),
      let puzzle = Towns.puzzle(id: parade.puzzleID)
    {
      var validated = Parade(puzzle: puzzle)
      for tile in parade.route.dropFirst() { _ = validated.move(to: tile, in: puzzle) }
      if parade.route == validated.route && parade.completed == validated.completed {
        saved = parade
      }
    }
  }

  var completedCount: Int { Towns.all.filter { best[$0.id] != nil }.count }
  var stars: Int { Towns.all.reduce(0) { $0 + (best[$1.id] ?? 0) } }
  var nextTown: Puzzle { Towns.all.first { best[$0.id] == nil } ?? Towns.all[0] }

  func save(_ parade: Parade) {
    saved = parade
    defaults.set(try? JSONEncoder().encode(parade), forKey: "parade")
  }

  func complete(_ parade: Parade, puzzle: Puzzle) {
    best[puzzle.id] = max(best[puzzle.id] ?? 0, parade.stars(in: puzzle))
    defaults.set(best, forKey: "best")
    save(parade)
  }

  func feedback(success: Bool = false) {
    guard haptics else { return }
    if success {
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    } else {
      UISelectionFeedbackGenerator().selectionChanged()
    }
  }
}
