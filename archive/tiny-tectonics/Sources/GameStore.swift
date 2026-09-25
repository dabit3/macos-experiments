import Combine
import Foundation
import UIKit

enum PlayPhase: Equatable {
  case editing, running, paused, won, failed
}

@MainActor
final class GameStore: ObservableObject {
  @Published var levelIndex = 0
  @Published var heights = Landscape.all[0].initial
  @Published var selected = 1
  @Published var moves = 0
  @Published var history: [[Int]] = []
  @Published var phase = PlayPhase.editing
  @Published var travel = 0.0
  @Published var best: [String: Int]
  @Published var haptics: Bool {
    didSet { defaults.set(haptics, forKey: "haptics") }
  }
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    best = defaults.dictionary(forKey: "best") as? [String: Int] ?? [:]
    haptics = defaults.object(forKey: "haptics") as? Bool ?? true
  }

  var level: Landscape { Landscape.all[levelIndex] }
  var outcome: RouteOutcome { SlopeRules.evaluate(heights, fossils: level.fossils) }
  var remaining: Int { level.budget - moves }
  var unlocked: Int {
    min(Landscape.all.count - 1, (0..<Landscape.all.count).first { best["\($0)"] == nil } ?? 9)
  }
  var completed: Int { best.count }
  var stars: Int { moves <= level.par ? 3 : (moves == level.par + 1 ? 2 : 1) }
  var collected: Int { level.fossils.filter { Double($0) <= travel }.count }
  var canUndo: Bool { !history.isEmpty && phase == .editing }

  func load(_ index: Int) {
    levelIndex = max(0, min(index, Landscape.all.count - 1))
    reset()
  }

  func reset() {
    heights = level.initial
    selected = heights.indices.first { !level.fixed.contains($0) } ?? 0
    moves = 0
    history = []
    travel = 0
    phase = .editing
  }

  func canAdjust(_ delta: Int) -> Bool {
    phase == .editing && remaining > 0 && !level.fixed.contains(selected)
      && (0...5).contains(heights[selected] + delta)
  }

  func adjust(_ delta: Int) {
    guard abs(delta) == 1, canAdjust(delta) else { return }
    history.append(heights)
    heights[selected] += delta
    moves += 1
    feedback()
  }

  func undo() {
    guard canUndo, let previous = history.popLast() else { return }
    heights = previous
    moves -= 1
    feedback()
  }

  func simulate() {
    guard phase == .editing else { return }
    travel = 0
    phase = .running
    feedback()
  }

  func togglePause() {
    if phase == .running { phase = .paused } else if phase == .paused { phase = .running }
  }

  func tick(_ delta: Double) {
    guard phase == .running else { return }
    let target = Double(outcome.reached) + (outcome.fault == nil ? 0.35 : 0.45)
    travel = min(target, travel + delta * 1.05)
    if travel >= target {
      if outcome.fault == nil {
        phase = .won
        best["\(levelIndex)"] = max(best["\(levelIndex)"] ?? 0, stars)
        defaults.set(best, forKey: "best")
        feedback(success: true)
      } else {
        phase = .failed
        feedback()
      }
    }
  }

  func editAgain() {
    travel = 0
    phase = .editing
    if outcome.fault != nil {
      let next = min(outcome.reached + 1, heights.count - 1)
      selected = level.fixed.contains(next) ? outcome.reached : next
    }
    if level.fixed.contains(selected) {
      selected = heights.indices.first { !level.fixed.contains($0) } ?? selected
    }
  }

  func feedback(success: Bool = false) {
    guard haptics else { return }
    if success {
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    } else {
      UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
  }
}
