import Combine
import QuartzCore
import SwiftUI
import UIKit

enum Screen: Hashable {
  case title, levels, game
}

/// Owns the current board, the frame clock, persistence and the sound/haptic cues.
@MainActor
final class GameStore: ObservableObject {
  @Published var screen: Screen = .title
  @Published var board: Board = Board(level: LevelCatalog.level(1))
  @Published var flow: Flow = Flow()
  @Published var progress: Progress
  @Published var isPaused = false
  @Published var lastMelted: [GridPoint] = []
  @Published var celebrationTick = 0
  @Published var newlyEarnedStars = 0

  let synth = Synth()
  private var link: DisplayLinkDriver?
  private var lastTimestamp: CFTimeInterval?
  private var poweredCount = 0
  private var solvedHandled = false
  private var backgrounded = false
  private let fileURL: URL = {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("progress.json")
  }()

  init() {
    let data = try? Data(contentsOf: fileURL)
    progress = data.map(Progress.decode) ?? Progress()
    synth.enabled = progress.soundEnabled
    Haptics.enabled = progress.hapticsEnabled
  }

  // MARK: Navigation

  func showLevels() {
    Haptics.tap()
    synth.play(.click)
    screen = .levels
  }

  func showTitle() {
    stopClock()
    screen = .title
  }

  func start(level id: Int) {
    guard progress.isUnlocked(id) else {
      synth.play(.deny)
      Haptics.warn()
      return
    }
    board = Board(level: LevelCatalog.level(id))
    flow = board.flow()
    poweredCount = flow.powered.count
    solvedHandled = false
    isPaused = false
    lastMelted = []
    newlyEarnedStars = 0
    screen = .game
    synth.play(.powerUp)
    Haptics.tap()
    startClock()
  }

  func restart() { start(level: board.level.id) }

  func nextLevel() {
    let next = min(LevelCatalog.count, board.level.id + 1)
    if next == board.level.id { showLevels() } else { start(level: next) }
  }

  // MARK: Play

  func tap(_ point: GridPoint) {
    guard !isPaused, board.isLive else { return }
    let before = flow
    guard board.rotate(at: point) else {
      synth.play(.deny)
      Haptics.deny()
      return
    }
    flow = board.flow()
    let nowPowered = flow.powered.count
    if !flow.shorts.isEmpty, before.shorts.isEmpty {
      synth.play(.short)
      Haptics.warn()
    } else if nowPowered > poweredCount {
      synth.play(.connect(pitch: Double(nowPowered)))
      Haptics.connect()
    } else {
      synth.play(.click)
      Haptics.tap()
    }
    poweredCount = nowPowered
    if board.phase == .solved { handleSolved() }
  }

  func togglePause() {
    guard board.isLive, board.phase == .routing else { return }
    isPaused.toggle()
    synth.play(.click)
    Haptics.tap()
  }

  private func handleSolved() {
    guard !solvedHandled else { return }
    solvedHandled = true
    stopClock()
    synth.setSizzle(0)
    let previous = progress.results[board.level.id]?.stars ?? 0
    progress.record(board)
    newlyEarnedStars = max(0, board.stars - previous)
    save()
    synth.play(.bootChime)
    Haptics.success()
    celebrationTick += 1
  }

  private func handleFailed() {
    stopClock()
    synth.play(.fail)
    Haptics.failure()
  }

  // MARK: Clock

  private func startClock() {
    stopClock()
    lastTimestamp = nil
    link = DisplayLinkDriver { [weak self] ts in self?.frame(ts) }
  }

  private func stopClock() {
    link?.invalidate()
    link = nil
  }

  private func frame(_ timestamp: CFTimeInterval) {
    defer { lastTimestamp = timestamp }
    guard let last = lastTimestamp else { return }
    let dt = min(0.05, timestamp - last)
    guard !isPaused, screen == .game, board.phase == .routing else { return }
    let melted = board.tick(dt)
    if !melted.isEmpty {
      lastMelted = melted
      flow = board.flow()
      poweredCount = flow.powered.count
      synth.play(.melt)
      Haptics.melt()
    }
    if board.level.hasHeat {
      let hottest = board.tiles.filter { $0.kind != .slag }.map(\.heat).max() ?? 0
      synth.setSizzle(hottest)
    }
    if case .failed = board.phase {
      synth.setSizzle(0)
      handleFailed()
    }
  }

  func pauseForBackground() {
    guard screen == .game, board.phase == .routing, !isPaused else { return }
    backgrounded = true
    isPaused = true
  }

  func resumeFromBackground() {
    if backgrounded {
      backgrounded = false
      lastTimestamp = nil
    }
  }

  // MARK: Settings & persistence

  func toggleSound() {
    progress.soundEnabled.toggle()
    synth.enabled = progress.soundEnabled
    if progress.soundEnabled { synth.play(.click) }
    save()
  }

  func toggleHaptics() {
    progress.hapticsEnabled.toggle()
    Haptics.enabled = progress.hapticsEnabled
    Haptics.tap()
    save()
  }

  func resetProgress() {
    progress.results = [:]
    save()
    synth.play(.deny)
  }

  private func save() {
    if let data = try? progress.encoded() { try? data.write(to: fileURL, options: .atomic) }
  }
}

/// CADisplayLink wrapper so the model ticks at the display's refresh rate.
final class DisplayLinkDriver {
  private var link: CADisplayLink?
  private let callback: (CFTimeInterval) -> Void
  init(_ callback: @escaping (CFTimeInterval) -> Void) {
    self.callback = callback
    let link = CADisplayLink(target: self, selector: #selector(step(_:)))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
    link.add(to: .main, forMode: .common)
    self.link = link
  }
  @objc private func step(_ link: CADisplayLink) { callback(link.timestamp) }
  func invalidate() {
    link?.invalidate()
    link = nil
  }
  deinit { invalidate() }
}

enum Haptics {
  static var enabled = true
  private static let light = UIImpactFeedbackGenerator(style: .light)
  private static let medium = UIImpactFeedbackGenerator(style: .medium)
  private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
  private static let notify = UINotificationFeedbackGenerator()

  static func tap() { if enabled { light.impactOccurred(intensity: 0.7) } }
  static func connect() { if enabled { rigid.impactOccurred(intensity: 1) } }
  static func deny() { if enabled { medium.impactOccurred(intensity: 0.4) } }
  static func warn() { if enabled { notify.notificationOccurred(.warning) } }
  static func melt() { if enabled { medium.impactOccurred(intensity: 1) } }
  static func success() { if enabled { notify.notificationOccurred(.success) } }
  static func failure() { if enabled { notify.notificationOccurred(.error) } }
}
