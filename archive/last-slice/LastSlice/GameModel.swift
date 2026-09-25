import Observation
import SwiftUI
import UIKit

@MainActor @Observable
final class GameModel {
  enum Screen { case home, game, result }
  var screen: Screen = .home
  var dinnerIndex = 0
  var daily = false
  var cuts: [Cut] = []
  var preview: Cut?
  var notice = "Drag across the pizza to line up your knife."
  var showHelp = false
  var showSettings = false
  var showPause = false
  var showMenu = false
  var showHint = false
  var result: Verdict?
  var served = false
  var haptics: Bool {
    didSet { defaults.set(haptics, forKey: "haptics") }
  }
  var best: [Int] {
    didSet { defaults.set(best, forKey: "best") }
  }
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    haptics = defaults.object(forKey: "haptics") as? Bool ?? true
    let saved = defaults.array(forKey: "best") as? [Int] ?? []
    best =
      Array(saved.prefix(Menu.dinners.count))
      + Array(repeating: 0, count: max(0, Menu.dinners.count - saved.count))
    dinnerIndex = min(defaults.integer(forKey: "lastDinner"), Menu.dinners.count - 1)
  }

  var dinner: Dinner { Menu.dinners[dinnerIndex] }
  var completed: Int { best.filter { $0 > 0 }.count }
  var totalStars: Int { best.reduce(0, +) }
  var unlocked: Int { min(Menu.dinners.count - 1, (best.firstIndex(of: 0) ?? Menu.dinners.count)) }
  var portions: [Portion] { Rules.portions(cuts: cuts, toppings: dinner.toppings) }
  var previewPortions: [Portion] {
    Rules.portions(cuts: cuts + (preview.map { [$0] } ?? []), toppings: dinner.toppings)
  }
  var liveVerdict: Verdict { Rules.evaluate(previewPortions, guests: dinner.guests) }
  var canCut: Bool {
    preview.map { Rules.valid($0, after: cuts) } == true && cuts.count < dinner.budget
  }

  func start(index: Int, daily: Bool = false) {
    dinnerIndex = min(max(0, index), Menu.dinners.count - 1)
    self.daily = daily
    defaults.set(dinnerIndex, forKey: "lastDinner")
    reset()
    screen = .game
    if !defaults.bool(forKey: "tutorialSeen") { showHelp = true }
  }

  func reset() {
    cuts = []
    preview = nil
    result = nil
    served = false
    showHint = false
    notice = "Drag across the pizza to line up your knife."
  }

  func previewCut(_ cut: Cut) {
    guard cuts.count < dinner.budget else {
      notice = "Knife budget used. Serve, undo or reset."
      return
    }
    preview = cut
    notice =
      Rules.valid(cut, after: cuts)
      ? "Check the portions. Tap Cut to commit."
      : "Cross the crust. Each piece must be at least 1%."
  }

  func commitCut() {
    guard canCut, let preview else { return }
    cuts.append(preview)
    self.preview = nil
    notice =
      cuts.count == dinner.budget
      ? "Knife down. Ready to serve?" : "Beautiful. Line up your next cut."
    feedback()
  }

  func undo() {
    if preview != nil { preview = nil } else if !cuts.isEmpty { cuts.removeLast() }
    notice = "Take your time. Every great dinner gets a second try."
  }

  func serve() {
    guard !cuts.isEmpty, preview == nil else { return }
    result = Rules.evaluate(portions, guests: dinner.guests)
    if let result, result.success {
      best[dinnerIndex] = max(best[dinnerIndex], result.stars)
    }
    served = true
    screen = .result
    feedback(success: result?.success == true)
  }

  func finishTutorial() {
    defaults.set(true, forKey: "tutorialSeen")
    showHelp = false
  }

  func feedback(success: Bool = false) {
    guard haptics else { return }
    if success {
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    } else {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
  }

  func nextDinner() {
    start(index: min(dinnerIndex + 1, Menu.dinners.count - 1))
  }
}

@main
struct LastSliceApp: App {
  @State private var model = GameModel()
  @Environment(\.scenePhase) private var phase

  var body: some Scene {
    WindowGroup {
      ContentView(model: model)
        .preferredColorScheme(.light)
        .onChange(of: phase) { _, phase in
          if phase != .active, model.screen == .game, !model.showHelp {
            model.preview = nil
            model.showPause = true
          }
        }
    }
  }
}
