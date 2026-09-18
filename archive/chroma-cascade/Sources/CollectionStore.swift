import SwiftUI
import UIKit

@MainActor
final class CollectionStore: ObservableObject {
  @Published private(set) var saved: SavedCollection
  private let defaults: UserDefaults
  private let key = "chroma.cascade.collection.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: key),
      let value = try? JSONDecoder().decode(SavedCollection.self, from: data),
      value.isValid
    {
      saved = value
    } else {
      saved = SavedCollection()
    }
  }

  func puzzle(_ id: Int) -> Puzzle { saved.puzzles[id] ?? Puzzle(vessels: Study.all[id].vessels) }

  func open(_ id: Int) {
    saved.currentLevel = id
    persist()
  }

  @discardableResult
  func pour(_ id: Int, from source: Int, to destination: Int) throws -> Int {
    var board = puzzle(id)
    let amount = try board.pour(from: source, to: destination)
    saved.puzzles[id] = board
    if board.isSolved {
      saved.bestMoves[id] = min(saved.bestMoves[id] ?? Int.max, board.moves)
    }
    persist()
    return amount
  }

  func undo(_ id: Int) {
    var board = puzzle(id)
    board.undo()
    saved.puzzles[id] = board
    persist()
  }

  func restart(_ id: Int) {
    saved.puzzles[id] = Puzzle(vessels: Study.all[id].vessels)
    persist()
  }

  func setSymbols(_ value: Bool) {
    saved.symbols = value
    persist()
  }

  func setHaptics(_ value: Bool) {
    saved.haptics = value
    persist()
  }

  func resetCollection() {
    let symbols = saved.symbols
    let haptics = saved.haptics
    saved = SavedCollection(symbols: symbols, haptics: haptics)
    persist()
  }

  func feedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    if saved.haptics { UINotificationFeedbackGenerator().notificationOccurred(type) }
  }

  private func persist() {
    if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: key) }
  }
}
