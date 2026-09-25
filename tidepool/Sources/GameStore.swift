import SwiftUI

@MainActor
final class GameStore: ObservableObject {
  @Published var progress: SavedProgress
  @Published var selected: Creature?
  @Published var message = "Drag a resident into its habitat. Tap one to learn."
  @Published var isError = false
  @Published var hintedCell: Int?
  @Published var celebrating = false
  @Published var saveWarning: String?
  @Published private var history: [[Placement]] = []
  let file: ProgressFile

  init() {
    let directory = URL.documentsDirectory.appending(path: "Tidepool", directoryHint: .isDirectory)
    file = ProgressFile(url: directory.appending(path: "progress.json"))
    progress = file.load()
    if restored {
      message = "Welcome back to a thriving pool."
    } else if !board.isEmpty {
      message = "Welcome back. Your residents are right where you left them."
    }
  }

  var level: PoolLevel { PoolLevel.all[progress.currentLevel] }
  var board: [Placement] { progress.boards[level.id] ?? [] }
  var canUndo: Bool { !history.isEmpty }
  var healthyCount: Int { board.filter { Puzzle.healthy($0, board: board, level: level) }.count }
  var restored: Bool { Puzzle.restored(board, level: level) }
  var unlocked: Int { min((progress.completed.max() ?? -1) + 1, 4) }

  func remaining(_ creature: Creature) -> Int {
    level.inhabitants.filter { $0 == creature }.count
      - board.filter { $0.creature == creature }.count
  }

  func place(_ creature: Creature, at cell: Int, movingFrom: Int? = nil) {
    let current = board
    let candidate = current.filter { $0.cell != movingFrom }
    if cell == movingFrom { return }
    if let error = Puzzle.placementError(creature, cell: cell, in: candidate, level: level) {
      announce(error, error: true)
      return
    }
    history.append(current)
    progress.boards[level.id] = candidate + [Placement(creature: creature, cell: cell)]
    hintedCell = nil
    if remaining(creature) == 0 { selected = nil }
    evaluate()
  }

  func announce(_ text: String, error: Bool = false) {
    message = text
    isError = error
    if error { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
  }

  func evaluate() {
    if restored {
      progress.completed.insert(level.id)
      celebrating = true
      announce("Balance restored. Your little ecosystem is thriving.")
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    } else {
      celebrating = false
      let waiting = board.count - healthyCount
      announce(
        waiting > 0
          ? "\(waiting) resident\(waiting == 1 ? "" : "s") waiting for the right neighbor."
          : "Looking healthy. \(level.inhabitants.count - board.count) more to welcome.")
    }
    persist()
  }

  func undo() {
    guard let previous = history.popLast() else { return }
    progress.boards[level.id] = previous
    celebrating = false
    hintedCell = nil
    selected = nil
    announce("Last placement undone. Try a different home.")
    persist()
  }

  func reset() {
    guard !board.isEmpty else {
      announce("A fresh pool, ready for its first resident.")
      return
    }
    history.append(board)
    progress.boards[level.id] = []
    celebrating = false
    hintedCell = nil
    selected = nil
    announce("A fresh start. You can undo this reset.")
    persist()
  }

  func hint() {
    if restored {
      announce("This pool is thriving. Explore the next shoreline.")
      return
    }
    if let solved = Puzzle.solution(level: level, preserving: board),
      let next = solved.first(where: { item in !board.contains { $0.cell == item.cell } })
    {
      selected = next.creature
      hintedCell = next.cell
      announce(
        "Try \(next.creature.name.lowercased()) at row \(next.cell / 4 + 1), column \(next.cell % 4 + 1)."
      )
    } else {
      announce("These homes can’t all thrive together. Undo or move a resident, then ask again.")
    }
  }

  func switchLevel(_ id: Int) {
    guard (0...unlocked).contains(id) else { return }
    progress.currentLevel = id
    history = []
    selected = nil
    hintedCell = nil
    celebrating = false
    announce(restored ? "Welcome back to a thriving pool." : "Drag a resident into its habitat.")
    persist()
  }

  func persist() {
    do {
      try file.save(progress)
      saveWarning = nil
    } catch {
      saveWarning = "Progress couldn’t be saved. Keep the app open and try again."
    }
  }
}
