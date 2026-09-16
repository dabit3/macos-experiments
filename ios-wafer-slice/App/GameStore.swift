import Combine
import SpriteKit
import SwiftUI

enum Screen: Equatable {
  case title
  case playing
  case leaderboard
  case howToPlay
}

/// Snapshot of the values the SwiftUI HUD needs. Published only when it
/// changes so the 60fps scene loop does not churn the view hierarchy.
struct HUDState: Equatable {
  var score = 0
  var lives = 0
  var maxLives = 0
  var timeRemaining: Double?
  var slowMoFraction: Double = 0
  var multiplier = 1
  var isPaused = false
  var isOver = false
  var mode: GameMode = .arcade

  var timeText: String {
    guard let remaining = timeRemaining else { return "∞" }
    let tenths = Int((remaining * 10).rounded(.up))
    return String(format: "%d.%d", tenths / 10, tenths % 10)
  }
  var isCountdown: Bool { (timeRemaining ?? 99) <= 5 }
}

final class GameStore: ObservableObject {
  @Published var screen: Screen = .title
  @Published private(set) var hud = HUDState()
  @Published private(set) var board: HighScoreBoard
  @Published private(set) var lastRun: RunSummary?
  @Published private(set) var lastRank: Int?
  @Published var soundOn: Bool { didSet { persistSettings() } }
  @Published var hapticsOn: Bool { didSet { persistSettings() } }
  @Published var reduceEffects = false

  private(set) var session = GameSession(mode: .arcade)
  private(set) var director = LaunchDirector(mode: .arcade, seed: 1)
  let synth = Synth()
  let haptics = Haptics()
  lazy var scene: GameScene = {
    let scene = GameScene(size: CGSize(width: 390, height: 844))
    scene.scaleMode = .resizeFill
    scene.store = self
    return scene
  }()

  private let defaults = UserDefaults.standard
  private let boardKey = "waferslice.board.v1"
  private var lastTickSecond = -1

  init() {
    board = HighScoreBoard.decode(defaults.data(forKey: boardKey) ?? Data())
    soundOn = defaults.object(forKey: "waferslice.sound") as? Bool ?? true
    hapticsOn = defaults.object(forKey: "waferslice.haptics") as? Bool ?? true
    synth.enabled = soundOn
    haptics.enabled = hapticsOn
  }

  private func persistSettings() {
    defaults.set(soundOn, forKey: "waferslice.sound")
    defaults.set(hapticsOn, forKey: "waferslice.haptics")
    synth.enabled = soundOn
    haptics.enabled = hapticsOn
  }

  private func persistBoard() {
    if let data = try? board.encoded() { defaults.set(data, forKey: boardKey) }
  }

  // MARK: - Flow

  func startRun(_ mode: GameMode) {
    click()
    session = GameSession(mode: mode)
    director = LaunchDirector(mode: mode, seed: UInt64(Date().timeIntervalSince1970 * 1000))
    lastRun = nil
    lastRank = nil
    lastTickSecond = -1
    screen = .playing
    scene.beginRun()
    refreshHUD()
  }

  func pause() {
    guard screen == .playing, session.isRunning else { return }
    click()
    session.pause()
    scene.setPaused(true)
    refreshHUD()
  }

  func resume() {
    guard session.isPaused else { return }
    click()
    session.resume()
    scene.setPaused(false)
    refreshHUD()
  }

  /// Ends a run early from the pause menu. Zen runs bank their score.
  func finishEarly() {
    guard screen == .playing, !session.isOver else { return }
    session.finish(.finished)
    scene.setPaused(false)
    completeRun()
  }

  func quitToTitle() {
    click()
    if screen == .playing, !session.isOver { session.finish(.finished) }
    screen = .title
    scene.beginAttract()
    refreshHUD()
  }

  func showLeaderboard() {
    click()
    screen = .leaderboard
  }

  func showHowToPlay() {
    click()
    screen = .howToPlay
  }

  func click() {
    synth.play(.click)
    haptics.tap()
  }

  func appDidLeaveForeground() {
    if screen == .playing, session.isRunning { pause() }
    synth.stop()
  }

  func appDidReturnToForeground() {
    if soundOn { synth.start() }
    haptics.prepare()
  }

  // MARK: - Scene callbacks (all on the main thread from the scene loop)

  func advance(_ dt: Double) {
    guard session.isRunning else { return }
    let wasSlowMo = session.isSlowMo
    session.advance(dt)
    if wasSlowMo && !session.isSlowMo { scene.slowMoEnded() }
    if let remaining = session.timeRemaining, remaining <= 5.05, remaining > 0 {
      let second = Int(remaining.rounded(.up))
      if second != lastTickSecond {
        lastTickSecond = second
        synth.play(.tick)
      }
    }
    if session.isOver { completeRun() }
    refreshHUD()
  }

  func nextWave(playfieldHeight: Double) -> [LaunchSpec]? {
    guard session.isRunning else { return nil }
    return director.wave(at: session.elapsed, playfieldHeight: playfieldHeight)
  }

  func beginSwipe() { session.beginSwipe() }

  func hit(_ kind: SliceableKind) -> HitResult? {
    guard let result = session.registerHit(kind) else { return nil }
    switch kind {
    case .defective:
      synth.play(.defective)
      haptics.defective()
    case .flagship:
      synth.play(.flagship)
      haptics.flagship()
      if result.refundedLife { synth.play(.lifeBack) }
    default:
      synth.play(.slice(pitch: result.swipeCount))
      haptics.slice(swipeCount: result.swipeCount)
    }
    if session.isOver { completeRun() }
    refreshHUD()
    return result
  }

  func endSwipe() -> SwipeSummary {
    let summary = session.endSwipe()
    if summary.isBinningBonus {
      synth.play(.binning)
      haptics.binning()
    }
    refreshHUD()
    return summary
  }

  func miss(_ kind: SliceableKind) { session.registerMiss(kind) }

  func launched() { synth.play(.launch) }

  var timeScale: Double { session.timeScale }

  private func completeRun() {
    guard lastRun == nil, session.isOver else { return }
    let summary = session.summary
    lastRun = summary
    lastRank = board.record(summary)
    persistBoard()
    synth.play(.gameOver)
    scene.runEnded()
    refreshHUD()
  }

  private func refreshHUD() {
    let state = HUDState(
      score: session.score, lives: session.lives, maxLives: session.mode.startingLives,
      timeRemaining: session.timeRemaining,
      slowMoFraction: session.slowMoRemaining / GameRules.flagshipSlowMoDuration,
      multiplier: session.multiplier, isPaused: session.isPaused, isOver: session.isOver,
      mode: session.mode)
    if state != hud { hud = state }
  }
}
