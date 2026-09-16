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
  let rotation: Double
  let birth: Date
}

@MainActor final class GameStore: ObservableObject {
  @Published var engine: GameEngine
  @Published var screen: Screen = .title
  @Published var tab: GameTab = .fabs
  @Published var toasts: [Toast] = []
  @Published var floatingNumbers: [FloatingNumber] = []
  @Published var offlineReport: OfflineReport?
  @Published var showingSettings = false
  @Published var flash = false
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
    sound.enabled = engine.state.soundEnabled
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
      playSound { $0.achievement() }
      notifySuccess()
    }
    if result.aiWaveJustTriggered {
      toast("THE AI WAVE HAS ARRIVED", "Demand ×10", dramatic: true)
      triggerFlash()
      playSound { $0.aiWave() }
      notifySuccess()
    }
  }
  func tap() {
    let result = engine.tap()
    let item = FloatingNumber(
      value: "+" + NumberFormat.formatCash(result.cash),
      x: CGFloat.random(in: -90...90),
      y: 0,
      rotation: Double.random(in: -8...8),
      birth: Date()
    )
    withAnimation(.easeOut(duration: 0.9)) {
      floatingNumbers.append(item)
    }
    if floatingNumbers.count > 12 { floatingNumbers.removeFirst() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      self?.floatingNumbers.removeAll { $0.id == item.id }
    }
    impact(.light)
    playSound { $0.tap() }
    let achievements = engine.tick(dt: 0).newlyUnlocked
    for achievement in achievements {
      toast("ACHIEVEMENT UNLOCKED", achievement.title)
      playSound { $0.achievement() }
      notifySuccess()
    }
  }
  func buy(_ kind: BuildingKind, quantity: Int = 1) {
    var bought = 0
    while bought < min(quantity, 100), engine.buy(kind) { bought += 1 }
    guard bought > 0 else { return }
    impact(.medium)
    playSound { $0.purchase() }
  }
  func buyUpgrade(_ id: String) {
    guard engine.buyUpgrade(id: id) else { return }
    impact(.medium)
    playSound { $0.purchase() }
  }
  func hireResearcher() {
    guard engine.hireResearcher() else { return }
    impact(.medium)
    playSound { $0.purchase() }
  }
  func advanceNode() {
    guard engine.advanceNode() else { return }
    impact(.medium)
    playSound { $0.purchase() }
  }
  func prestige() {
    guard engine.prestige() else { return }
    toast("ARCHITECTURE SHIFT", Architecture.name(for: engine.state.generation))
    triggerFlash()
    impact(.medium)
    playSound { $0.prestige() }
    notifySuccess()
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
  private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    guard engine.state.hapticsEnabled else { return }
    UIImpactFeedbackGenerator(style: style).impactOccurred()
  }
  private func notifySuccess() {
    guard engine.state.hapticsEnabled else { return }
    UINotificationFeedbackGenerator().notificationOccurred(.success)
  }
  private func playSound(_ action: (SoundSynth) -> Void) {
    sound.enabled = engine.state.soundEnabled
    guard sound.enabled else { return }
    action(sound)
  }
  func triggerFlash() {
    flash = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
      self?.flash = false
    }
  }
}
