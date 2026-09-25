import AVFoundation
import SwiftUI
import UIKit

struct BoardRecord: Codable {
  var score: Int
  var stars: Int
}

@MainActor
final class GameStore: ObservableObject {
  @Published var game = GameRules(board: Board.all[0])
  @Published var screen = Screen.home
  @Published var paused = false
  @Published var help = false
  @Published var sound = UserDefaults.standard.object(forKey: "golden.sound") as? Bool ?? true
  @Published var records: [String: BoardRecord] = [:]
  @Published var toast = ""
  @Published var toastLife = 0.0
  @Published var lastShotSummary = ""
  @Published var newRecord = false
  @Published var particles: [Spark] = []
  var clock: Timer?
  var lastTick: CFTimeInterval?
  var tonePlayer: AVAudioPlayer?
  enum Screen { case home, boards, play }
  struct Spark: Identifiable {
    let id = UUID()
    var position: Vector
    var age: Double
    var gold: Bool
  }

  init() {
    if let data = UserDefaults.standard.data(forKey: "golden.records"),
      let saved = try? JSONDecoder().decode([String: BoardRecord].self, from: data)
    {
      records = saved
    }
  }

  func startClock() {
    guard clock == nil else { return }
    lastTick = nil
    clock = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.tick() }
    }
  }

  func stopClock() {
    clock?.invalidate()
    clock = nil
    lastTick = nil
  }

  func start(_ board: Board) {
    game = GameRules(board: board)
    screen = .play
    paused = false
    toast = ""
    lastShotSummary = ""
    newRecord = false
    particles = []
    lastTick = nil
    if !UserDefaults.standard.bool(forKey: "golden.learned") { help = true }
  }

  func dismissHelp() {
    help = false
    UserDefaults.standard.set(true, forKey: "golden.learned")
    lastTick = nil
  }

  func toggleSound() {
    sound.toggle()
    UserDefaults.standard.set(sound, forKey: "golden.sound")
  }

  func fire() {
    guard !paused, !help else { return }
    lastShotSummary = ""
    toastLife = 0
    game.launch()
    feedback(.soft)
    tone("launch")
  }

  func background() {
    if screen == .play && (game.phase == .aiming || game.phase == .flying) { paused = true }
    stopClock()
  }

  func tick() {
    let now = CACurrentMediaTime()
    let elapsed = min(1.0 / 30, now - (lastTick ?? now))
    lastTick = now
    guard screen == .play, !paused, !help else { return }
    var remaining = elapsed
    while remaining > 0 {
      let delta = min(1.0 / 120, remaining)
      game.step(delta)
      remaining -= delta
    }
    particles = particles.compactMap {
      var spark = $0
      spark.age += elapsed
      return spark.age < 0.8 ? spark : nil
    }
    toastLife -= elapsed
    for event in game.events {
      switch event.kind {
      case .peg:
        particles.append(.init(position: event.position, age: 0, gold: true))
        tone("peg")
        feedback(.light)
        if event.text == "+1 BALL" {
          toast = "EMERALD GIFT  ·  +1 BALL"
          toastLife = 2.5
        }
      case .catchBall:
        toast = event.text
        toastLife = 3
        tone("catch")
        feedback(.medium)
      case .multiplier:
        toast =
          toastLife > 0 && toast.contains("GIFT")
          ? "GIFT +1 BALL  ·  BOOST ×\(game.multiplier)" : event.text
        toastLife = 2.5
      case .settled:
        lastShotSummary = event.text
      case .finale:
        toast = event.text
        toastLife = 2.5
        tone("finale")
        feedback(.heavy)
      case .finished:
        save()
      }
    }
    game.events = []
  }

  func save() {
    let key = String(game.board.id)
    let old = records[key] ?? .init(score: 0, stars: 0)
    newRecord = game.score > old.score
    records[key] = .init(score: max(old.score, game.score), stars: max(old.stars, game.stars))
    if let data = try? JSONEncoder().encode(records) {
      UserDefaults.standard.set(data, forKey: "golden.records")
    }
  }

  func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
  }

  func tone(_ name: String) {
    guard sound, let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    tonePlayer = try? AVAudioPlayer(contentsOf: url)
    tonePlayer?.volume = 0.24
    tonePlayer?.play()
  }
}
