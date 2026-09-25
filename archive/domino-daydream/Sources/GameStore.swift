import AudioToolbox
import Combine
import Foundation
import UIKit

struct SavedBoard: Codable {
  var placed: [String: Piece] = [:]
  var attempts: Int = 0
  var hints: Int = 0
}

struct ProgressRecord: Codable {
  var scores: [String: Int] = [:]
  var drafts: [String: SavedBoard] = [:]
}

@MainActor
final class GameStore: ObservableObject {
  @Published var puzzle = Puzzle.all[0]
  @Published var placed: [Cell: Piece] = [:]
  @Published var selected: Cell?
  @Published var tool: PieceKind = .straight
  @Published var rotation = 0
  @Published var phase: Phase = .editing
  @Published var beat: Double = -1
  @Published var result: ChainResult?
  @Published var message = ""
  @Published var progress: ProgressRecord
  @Published var hints = 0
  @Published var attempts = 0
  @Published var sound: Bool { didSet { defaults.set(sound, forKey: "sound") } }
  @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
  @Published var guides: Bool { didSet { defaults.set(guides, forKey: "guides") } }
  private let defaults: UserDefaults
  private var history: [[Cell: Piece]] = []
  private var runTask: Task<Void, Never>?

  enum Phase { case editing, running, paused, result }
  var canUndo: Bool { !history.isEmpty }
  var completed: Int { progress.scores.keys.filter { $0 != "8" }.count }
  var unlocked: Int {
    (0..<8).first { progress.scores[String($0)] == nil } ?? 7
  }
  var currentScore: Int { result?.score(hints: hints, attempts: attempts) ?? 0 }
  var best: Int { progress.scores[String(puzzle.id)] ?? 0 }
  var allPieces: [Cell: Piece] { puzzle.fixed.merging(placed) { fixed, _ in fixed } }
  var totalBeat: Int { result?.events.map(\.beat).max() ?? 1 }
  var bellsRung: Int {
    result?.events.filter { puzzle.targets.contains($0.cell) && Double($0.beat) <= beat }.count ?? 0
  }
  var firstFailure: Cell? {
    result?.failures.keys.sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }.first
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    sound = defaults.object(forKey: "sound") as? Bool ?? true
    haptics = defaults.object(forKey: "haptics") as? Bool ?? true
    guides = defaults.object(forKey: "guides") as? Bool ?? true
    progress =
      defaults.data(forKey: "progress").flatMap {
        try? JSONDecoder().decode(ProgressRecord.self, from: $0)
      } ?? ProgressRecord()
  }

  func load(_ index: Int) {
    runTask?.cancel()
    puzzle = Puzzle.all[index]
    let draft = progress.drafts[String(index)] ?? SavedBoard()
    placed = Dictionary(
      uniqueKeysWithValues: draft.placed.compactMap { key, piece in
        let values = key.split(separator: ",").compactMap { Int($0) }
        guard values.count == 2 else { return nil }
        let cell = Cell(x: values[0], y: values[1])
        return puzzle.canEdit(cell) ? (cell, piece) : nil
      })
    attempts = draft.attempts
    hints = draft.hints
    selected = nil
    history = []
    rotation = 0
    tool = .straight
    phase = .editing
    result = nil
    beat = -1
    message = puzzle.lesson
  }

  func remaining(_ kind: PieceKind) -> Int {
    if puzzle.sandbox { return 99 }
    return max(0, (puzzle.inventory[kind] ?? 0) - placed.values.filter { $0.kind == kind }.count)
  }

  func choose(_ kind: PieceKind) {
    tool = kind
    rotation = 0
    if let selected, let old = placed[selected], old.kind != kind, remaining(kind) > 0 {
      remember()
      placed[selected] = Piece(kind: kind)
      save()
    }
    tactile()
  }

  func tap(_ cell: Cell) {
    guard phase == .editing else { return }
    guard puzzle.canEdit(cell) else {
      message =
        cell == puzzle.start
        ? "The coral trigger pushes to the right."
        : puzzle.targets.contains(cell)
          ? "A brass bell. Reach every bell to finish."
          : "Porcelain rails are fixed. Build in the dotted sockets."
      return
    }
    selected = cell
    if let piece = placed[cell] {
      tool = piece.kind
      rotation = piece.rotation
      message = "\(piece.kind.title) selected. Rotate it, swap it, or lift it away."
    } else if remaining(tool) > 0 {
      remember()
      placed[cell] = Piece(kind: tool, rotation: rotation)
      message = "Placed. The arrows show where the nudge can travel."
      save()
      tactile()
    } else {
      message = "No \(tool.title.lowercased()) pieces left. Choose another piece or undo."
    }
  }

  func rotate() {
    guard phase == .editing else { return }
    rotation = (rotation + 1) % 4
    if let selected, let piece = placed[selected] {
      remember()
      placed[selected] = piece.rotated
      rotation = placed[selected]?.rotation ?? rotation
      save()
    }
    message = "Quarter turn. Match the open edges to the neighboring rails."
    tactile()
  }

  func erase() {
    guard phase == .editing, let selected, placed[selected] != nil else { return }
    remember()
    placed.removeValue(forKey: selected)
    save()
    tactile()
  }

  func undo() {
    guard phase == .editing, let previous = history.popLast() else { return }
    placed = previous
    selected = nil
    message = "One step back. Your inventory is restored."
    save()
    tactile()
  }

  func hint() {
    guard phase == .editing, !puzzle.sandbox else { return }
    let cell =
      selected.flatMap { puzzle.solution[$0] != nil && puzzle.fixed[$0] == nil ? $0 : nil }
      ?? puzzle.sockets.first { placed[$0] != puzzle.solution[$0] }
    guard let cell, let correct = puzzle.solution[cell] else {
      message = "The route is ready. Tap Start chain."
      return
    }
    selected = cell
    hints += 1
    message =
      "Blueprint: \(correct.kind.title), \(correct.rotation) quarter turns from its tray position. −75 points."
    save()
  }

  func reset() {
    runTask?.cancel()
    if !placed.isEmpty { remember() }
    placed = [:]
    phase = .editing
    result = nil
    beat = -1
    selected = nil
    message = "A clean table. Attempts and hints still count toward this score."
    save()
  }

  func editAgain() {
    runTask?.cancel()
    phase = .editing
    beat = -1
    selected = firstFailure.flatMap { puzzle.canEdit($0) ? $0 : nil }
    message = firstFailure.flatMap { result?.failures[$0] } ?? puzzle.lesson
    result = nil
  }

  func trigger() {
    guard phase == .editing else { return }
    attempts += 1
    selected = nil
    result = ChainEngine.run(puzzle: puzzle, placed: placed)
    phase = .running
    beat = -0.5
    message = "Following the route to each bell."
    save()
    animate()
  }

  func pause() {
    guard phase == .running else { return }
    phase = .paused
    runTask?.cancel()
  }

  func resume() {
    guard phase == .paused else { return }
    phase = .running
    animate()
  }

  func save() {
    progress.drafts[String(puzzle.id)] = SavedBoard(
      placed: Dictionary(uniqueKeysWithValues: placed.map { ($0.key.id, $0.value) }),
      attempts: attempts, hints: hints)
    persist()
  }

  private func persist() {
    if let data = try? JSONEncoder().encode(progress) { defaults.set(data, forKey: "progress") }
  }

  private func remember() {
    history.append(placed)
    if history.count > 100 { history.removeFirst() }
  }

  private func animate() {
    runTask?.cancel()
    runTask = Task { [weak self] in
      guard let self else { return }
      var lastSoundBeat = Int(self.beat)
      while !Task.isCancelled && self.phase == .running {
        do { try await Task.sleep(for: .milliseconds(25)) } catch { return }
        self.beat += 0.075
        if Int(self.beat) > lastSoundBeat {
          lastSoundBeat = Int(self.beat)
          if self.sound { AudioServicesPlaySystemSound(1104) }
        }
        if self.beat > Double(self.totalBeat) + 1.8 {
          self.finish()
          return
        }
      }
    }
  }

  private func finish() {
    phase = .result
    if result?.won == true {
      progress.scores[String(puzzle.id)] = max(best, currentScore)
      persist()
      if sound { AudioServicesPlaySystemSound(1025) }
      if haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    } else if haptics {
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
  }

  private func tactile() {
    if haptics { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
  }
}
