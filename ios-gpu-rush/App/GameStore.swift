import Combine
import Foundation
import SwiftUI
import UIKit

final class GameStore: ObservableObject {
  enum Screen { case title, playing, gameOver }
  enum Input { case left, right, jump, slide }

  @Published var screen: Screen = .title
  @Published private(set) var sim = RunSimulation(seed: 1)
  @Published private(set) var score = 0
  @Published private(set) var coins = 0
  @Published private(set) var fps = 0
  @Published private(set) var distance: Double = 0
  @Published private(set) var dlssActive = false
  @Published private(set) var dlssFraction: Double = 0
  @Published private(set) var banner: String?
  @Published private(set) var lastCrash: ObstacleKind?
  @Published private(set) var crashLine = ""
  @Published private(set) var newBest = false
  @Published var paused = false
  @Published private(set) var record: StreakTracker.Record
  @Published var soundEnabled: Bool {
    didSet { UserDefaults.standard.set(soundEnabled, forKey: "gpurush.sound") }
  }
  var reduceMotion = false

  let scene = HighwayScene()
  private let synth = Synth()
  private var flavorRNG = SeededRandom(state: UInt64(Date().timeIntervalSince1970) | 1)
  private var bannerTask: Task<Void, Never>?

  init() {
    if let data = UserDefaults.standard.data(forKey: "gpurush.record"),
      let saved = try? JSONDecoder().decode(StreakTracker.Record.self, from: data)
    {
      record = saved
    } else {
      record = StreakTracker.Record()
    }
    soundEnabled = UserDefaults.standard.object(forKey: "gpurush.sound") as? Bool ?? true
    scene.scaleMode = .resizeFill
    scene.store = self
  }

  func startRun() {
    sim = RunSimulation(seed: UInt64.random(in: 1...UInt64.max))
    sim.start()
    lastCrash = nil
    crashLine = ""
    newBest = false
    paused = false
    syncHUD()
    scene.resetForRun()
    screen = .playing
    play(.milestone)
  }

  func toTitle() {
    screen = .title
    paused = false
  }

  func pause() {
    if screen == .playing { paused = true }
  }

  func resume() { paused = false }

  func toggleSound() {
    soundEnabled.toggle()
    if soundEnabled { play(.milestone) }
  }

  func input(_ move: Input) {
    guard screen == .playing, !paused else { return }
    switch move {
    case .left: sim.moveLeft()
    case .right: sim.moveRight()
    case .jump: sim.jump()
    case .slide: sim.slide()
    }
  }

  @discardableResult
  func tick(_ delta: Double) -> [RunEvent] {
    guard screen == .playing, !paused else {
      synth.setBass(0)
      return []
    }
    let events = sim.advance(by: delta)
    syncHUD()
    synth.setBass(
      sim.state.phase == .running ? max(0, sim.state.speed * 0.07) : 0)
    handle(events)
    return events
  }

  private func syncHUD() {
    score = sim.state.score
    coins = sim.state.coins
    fps = sim.fps
    distance = sim.state.runDistance
    dlssActive = sim.state.dlssActive
    dlssFraction =
      sim.config.dlssDuration > 0
      ? sim.state.dlssTimeRemaining / sim.config.dlssDuration : 0
  }

  private func handle(_ events: [RunEvent]) {
    for event in events {
      switch event {
      case .coin:
        play(.coin)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      case .laneChanged:
        play(.laneShift)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      case .jumped:
        play(.jump)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      case .slid:
        play(.slide)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      case .dlssActivated:
        play(.dlss)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showBanner("DLSS 3× FRAME GEN ENGAGED")
      case .dlssEnded:
        showBanner("Frame gen offline.")
      case .milestone(let meters):
        play(.milestone)
        showBanner(FlavorText.milestoneLine(meters))
      case .crashed(let kind):
        play(.crash)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        lastCrash = kind
        crashLine = FlavorText.crashLine(for: kind, rng: &flavorRNG)
        finishRun()
      }
    }
  }

  private func finishRun() {
    let previous = record
    record = StreakTracker.recordRun(
      record, score: score, distance: distance, on: Date(), calendar: .current)
    newBest = score > previous.bestScore
    UserDefaults.standard.set(try? JSONEncoder().encode(record), forKey: "gpurush.record")
    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 1_200_000_000)
      guard !Task.isCancelled else { return }
      self?.screen = .gameOver
    }
  }

  private func showBanner(_ text: String) {
    banner = text
    bannerTask?.cancel()
    bannerTask = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 2_200_000_000)
      guard !Task.isCancelled else { return }
      self?.banner = nil
    }
  }

  private func play(_ tone: Synth.Tone) {
    if soundEnabled { synth.play(tone) }
  }
}
