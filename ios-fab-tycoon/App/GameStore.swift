import Combine
import SwiftUI
import UIKit

struct Toast: Identifiable {
  let id = UUID()
  let title: String
  let detail: String
  let dramatic: Bool
}

struct FloatingNumber: Identifiable {
  let id = UUID()
  let value: String
  let x: CGFloat
  let y: CGFloat
}

@MainActor final class GameStore: ObservableObject {
  @Published var engine: GameEngine
  @Published var screen: Screen = .title
  @Published var tab: GameTab = .fabs
  @Published var toasts: [Toast] = []
  @Published var floatingNumbers: [FloatingNumber] = []
  @Published var offlineReport: OfflineReport?
  @Published var showingSettings = false
  private var timer: AnyCancellable?
  private var lastFrame = Date()
  private var autosaveAccumulator = 0.0
  private let sound = SoundSynth()

  init() {
    if let data = UserDefaults.standard.data(forKey: "fabtycoon.save.v1"),
      let state = try? JSONDecoder().decode(GameState.self, from: data)
    {
      engine = GameEngine(state: state)
    } else {
      engine = GameEngine()
    }
  }
  var hasSave: Bool { engine.state.totalPlaySeconds > 0 || engine.state.taps > 0 }
  func start() {
    screen = .game
    lastFrame = Date()
    timer?.cancel()
    timer = Timer.publish(every: 1 / 30, on: .main, in: .common).autoconnect().sink {
      [weak self] _ in self?.frame()
    }
  }
  func frame() {
    guard screen == .game else { return }
    let now = Date()
    let dt = min(0.25, max(0, now.timeIntervalSince(lastFrame)))
    lastFrame = now
    let result = engine.tick(dt: dt)
    autosaveAccumulator += dt
    if autosaveAccumulator >= 5 {
      autosaveAccumulator = 0
      save()
    }
    for achievement in result.newlyUnlocked {
      toast("ACHIEVEMENT UNLOCKED", achievement.title)
      sound.achievement()
    }
    if result.aiWaveJustTriggered {
      toast("THE AI WAVE HAS ARRIVED", "Demand ×10", dramatic: true)
      sound.aiWave()
    }
  }
  func tap() {
    let result = engine.tap()
    floatingNumbers.append(
      FloatingNumber(
        value: "+" + NumberFormat.formatCash(result.cash), x: CGFloat.random(in: -58...58), y: 0))
    if floatingNumbers.count > 12 { floatingNumbers.removeFirst() }
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    sound.tap()
    let achievements = engine.tick(dt: 0).newlyUnlocked
    for achievement in achievements {
      toast("ACHIEVEMENT UNLOCKED", achievement.title)
      sound.achievement()
    }
  }
  func buy(_ kind: BuildingKind) {
    guard engine.buy(kind) else { return }
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    sound.purchase()
  }
  func buyUpgrade(_ id: String) {
    guard engine.buyUpgrade(id: id) else { return }
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    sound.purchase()
  }
  func hireResearcher() {
    guard engine.hireResearcher() else { return }
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    sound.purchase()
  }
  func advanceNode() {
    guard engine.advanceNode() else { return }
    sound.purchase()
  }
  func prestige() {
    guard engine.prestige() else { return }
    toast("ARCHITECTURE SHIFT", Architecture.name(for: engine.state.generation))
    sound.prestige()
  }
  func toast(_ title: String, _ detail: String, dramatic: Bool = false) {
    let item = Toast(title: title, detail: detail, dramatic: dramatic)
    toasts.append(item)
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
      self?.toasts.removeAll { $0.id == item.id }
    }
  }
  func save() {
    engine.state.lastSaved = Date()
    if let data = try? JSONEncoder().encode(engine.state) {
      UserDefaults.standard.set(data, forKey: "fabtycoon.save.v1")
    }
  }
  func applyOffline() {
    offlineReport = engine.applyOffline(now: Date())
  }
  func reset() {
    engine = GameEngine()
    save()
    screen = .title
  }
}
