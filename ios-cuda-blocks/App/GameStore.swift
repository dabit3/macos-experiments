import Combine
import CudaBlocksCore
import QuartzCore
import SwiftUI

enum Screen: Equatable {
  case title, playing, paused, gameOver, leaderboard
}

struct Shockwave: Identifiable {
  let id = UUID()
  var centerRow: Double
  var born: TimeInterval
  var tensor: Bool
}

struct Spark: Identifiable {
  let id = UUID()
  var x: Double
  var y: Double
  var vx: Double
  var vy: Double
  var born: TimeInterval
  var life: TimeInterval
  var hue: Double
}

struct RowFlash: Identifiable {
  let id = UUID()
  var row: Int
  var born: TimeInterval
}

struct Toast: Identifiable, Equatable {
  let id = UUID()
  var title: String
  var subtitle: String?
  var born: TimeInterval
  var tensor = false
}

/// Drives the engine at display refresh, turns events into sound/haptics/VFX, persists state.
@MainActor
final class GameStore: ObservableObject {
  @Published var screen: Screen = .title
  @Published private(set) var engine = GameEngine()
  @Published var leaderboard = Leaderboard()
  @Published var shockwaves: [Shockwave] = []
  @Published var sparks: [Spark] = []
  @Published var rowFlashes: [RowFlash] = []
  @Published var toasts: [Toast] = []
  @Published var shake: Double = 0
  @Published var flash: Double = 0
  @Published var lastRank: Int?
  @Published var playerName: String
  @Published var soundEnabled: Bool { didSet { persistSettings() } }
  @Published var hapticsEnabled: Bool { didSet { persistSettings() } }
  @Published var hasSavedRun: Bool
  @Published var softDropping = false
  @Published var lifetimeWarps: Int
  @Published var lifetimeTensorCores: Int

  private(set) var now: TimeInterval = 0
  private var displayLink: CADisplayLink?
  private var lastTimestamp: CFTimeInterval = 0
  private var proxy: DisplayLinkProxy?
  private var pendingSubmit = false

  private let defaults = UserDefaults.standard
  private enum Keys {
    static let leaderboard = "cuda.leaderboard"
    static let savedRun = "cuda.savedRun"
    static let name = "cuda.playerName"
    static let sound = "cuda.sound"
    static let haptics = "cuda.haptics"
    static let warps = "cuda.lifetimeWarps"
    static let tensors = "cuda.lifetimeTensor"
  }

  init() {
    if let data = defaults.data(forKey: Keys.leaderboard) { leaderboard = Leaderboard.decode(data) }
    playerName = defaults.string(forKey: Keys.name) ?? "SM-\(Int.random(in: 10...99))"
    soundEnabled = defaults.object(forKey: Keys.sound) as? Bool ?? true
    hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
    hasSavedRun = defaults.data(forKey: Keys.savedRun) != nil
    lifetimeWarps = defaults.integer(forKey: Keys.warps)
    lifetimeTensorCores = defaults.integer(forKey: Keys.tensors)
    SoundEngine.shared.isEnabled = soundEnabled
    Haptics.isEnabled = hapticsEnabled
  }

  // MARK: - Lifecycle

  func startAudio() {
    SoundEngine.shared.start()
    Haptics.prepare()
  }

  func newGame(startLevel: Int = 1) {
    engine = GameEngine(startLevel: startLevel)
    clearEffects()
    lastRank = nil
    pendingSubmit = false
    screen = .playing
    SoundEngine.shared.play(.start)
    Haptics.soft()
    toast("DIE POWERED ON", subtitle: "\(ScoreFormat.clock(level: startLevel)) boost clock")
    startLink()
  }

  func resumeSavedRun() {
    guard let data = defaults.data(forKey: Keys.savedRun),
      let state = try? JSONDecoder().decode(GameState.self, from: data), !state.isOver
    else {
      hasSavedRun = false
      newGame()
      return
    }
    engine = GameEngine(resuming: state)
    clearEffects()
    pendingSubmit = false
    screen = .playing
    SoundEngine.shared.play(.start)
    toast("KERNEL RESUMED", subtitle: "context restored from checkpoint")
    startLink()
  }

  func pause() {
    guard screen == .playing else { return }
    screen = .paused
    softDropping = false
    stopLink()
    saveRun()
    SoundEngine.shared.play(.uiTap)
  }

  func resume() {
    guard screen == .paused else { return }
    screen = .playing
    SoundEngine.shared.play(.uiTap)
    startLink()
  }

  func quitToTitle() {
    stopLink()
    softDropping = false
    if screen == .paused || screen == .playing { saveRun() }
    screen = .title
    SoundEngine.shared.play(.uiTap)
  }

  func showLeaderboard() {
    screen = .leaderboard
    SoundEngine.shared.play(.uiTap)
  }

  func backToTitle() {
    screen = .title
    SoundEngine.shared.play(.uiTap)
  }

  func appDidEnterBackground() {
    if screen == .playing { pause() }
  }

  // MARK: - Input

  func moveLeft() { handle(engine.move(-1)) }
  func moveRight() { handle(engine.move(1)) }
  func rotate(clockwise: Bool = true) { handle(engine.rotate(clockwise: clockwise)) }
  func hardDrop() { handle(engine.hardDrop()) }
  func hold() { handle(engine.holdPiece()) }
  func softDropStep() { handle(engine.softDropStep()) }

  // MARK: - Frame loop

  private func startLink() {
    stopLink()
    let proxy = DisplayLinkProxy { [weak self] link in
      MainActor.assumeIsolated { self?.tick(link) }
    }
    let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire(_:)))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
    link.add(to: .main, forMode: .common)
    lastTimestamp = 0
    self.proxy = proxy
    displayLink = link
  }

  private func stopLink() {
    displayLink?.invalidate()
    displayLink = nil
    proxy = nil
  }

  private func tick(_ link: CADisplayLink) {
    let ts = link.timestamp
    if lastTimestamp == 0 { lastTimestamp = ts }
    let dt = min(0.05, ts - lastTimestamp)
    lastTimestamp = ts
    now += dt
    if screen == .playing {
      handle(engine.advance(by: dt, softDropping: softDropping))
    }
    decayEffects(dt: dt)
  }

  private func decayEffects(dt: TimeInterval) {
    if shake > 0 { shake = max(0, shake - dt * 3.5) }
    if flash > 0 { flash = max(0, flash - dt * 2.5) }
    shockwaves.removeAll { now - $0.born > 1.1 }
    sparks.removeAll { now - $0.born > $0.life }
    rowFlashes.removeAll { now - $0.born > 0.45 }
    toasts.removeAll { now - $0.born > ($0.tensor ? 1.8 : 1.3) }
  }

  // MARK: - Events

  private func handle(_ events: [GameEvent]) {
    for event in events {
      switch event {
      case .moved:
        SoundEngine.shared.play(.move)
        Haptics.tick()
      case .rotated(let kicked):
        SoundEngine.shared.play(.rotate)
        if kicked { Haptics.soft() } else { Haptics.tick() }
      case .blocked:
        SoundEngine.shared.play(.blocked)
      case .softDropped:
        SoundEngine.shared.play(.softDrop)
      case .hardDropped(let rows):
        if rows > 0 {
          SoundEngine.shared.play(.hardDrop)
          shake = min(1, 0.35 + Double(rows) * 0.02)
          if let p = engine.current ?? engine.ghost { emitDust(under: p) }
        }
        Haptics.drop()
      case .held:
        SoundEngine.shared.play(.hold)
        Haptics.soft()
      case .locked:
        SoundEngine.shared.play(.lock)
        Haptics.lock()
      case .warpsDispatched(let rows, let count, let tSpin, let points):
        lifetimeWarps += count
        defaults.set(lifetimeWarps, forKey: Keys.warps)
        for r in rows { rowFlashes.append(RowFlash(row: r, born: now)) }
        emitSparks(rows: rows, tensor: count == 4)
        Haptics.clear(count: count)
        if let tSpin {
          SoundEngine.shared.play(.tSpin)
          let kind = tSpin == .full ? "T-SPIN" : "T-SPIN MINI"
          toast("\(kind) \(warpWord(count))", subtitle: "+\(ScoreFormat.compact(points))")
        } else if count < 4 {
          SoundEngine.shared.play(.warp(count: count))
          toast(warpWord(count).uppercased(), subtitle: "+\(ScoreFormat.compact(points))")
        } else {
          SoundEngine.shared.play(.warp(count: 4))
        }
        if count == 4 {
          let center = Double(rows.reduce(0, +)) / Double(rows.count)
          shockwaves.append(Shockwave(centerRow: center, born: now, tensor: true))
          flash = 1
          shake = 1
        } else if rows.count >= 2 {
          let center = Double(rows.reduce(0, +)) / Double(rows.count)
          shockwaves.append(Shockwave(centerRow: center, born: now, tensor: false))
        }
      case .tensorCore(let multiplier):
        lifetimeTensorCores += 1
        defaults.set(lifetimeTensorCores, forKey: Keys.tensors)
        SoundEngine.shared.play(.tensorCore)
        Haptics.tensor()
        toast("TENSOR CORE", subtitle: "multiplier x\(multiplier)", tensor: true)
      case .perfectClear:
        toast("WAFER CLEAN", subtitle: "perfect clear bonus", tensor: true)
        flash = 1
      case .levelUp(let level):
        SoundEngine.shared.play(.levelUp)
        Haptics.soft()
        toast("OVERCLOCK", subtitle: "level \(level) · \(ScoreFormat.clock(level: level))")
      case .gameOver:
        finishRun()
      }
    }
  }

  private func warpWord(_ count: Int) -> String {
    switch count {
    case 1: return "Warp dispatched"
    case 2: return "Dual warp"
    case 3: return "Triple warp"
    default: return "Tensor Core"
    }
  }

  private func finishRun() {
    stopLink()
    softDropping = false
    SoundEngine.shared.play(.gameOver)
    Haptics.failure()
    shake = 0.8
    defaults.removeObject(forKey: Keys.savedRun)
    hasSavedRun = false
    pendingSubmit = leaderboard.qualifies(score: engine.state.score)
    lastRank = nil
    // Keep the display link alive briefly so the final effects animate out.
    screen = .gameOver
    startLink()
  }

  /// Called from the game over sheet once the pilot confirms a name.
  func submitScore() {
    guard pendingSubmit else { return }
    pendingSubmit = false
    let name = playerName.trimmingCharacters(in: .whitespaces).isEmpty ? "SM" : playerName
    defaults.set(name, forKey: Keys.name)
    let s = engine.state
    let entry = LeaderboardEntry(
      name: String(name.prefix(12)), score: s.score, lines: s.lines, level: s.level,
      tensorCores: s.tensorCores)
    lastRank = leaderboard.submit(entry)
    if let data = try? leaderboard.encoded() { defaults.set(data, forKey: Keys.leaderboard) }
    SoundEngine.shared.play(.levelUp)
  }

  var runQualifies: Bool { pendingSubmit }

  // MARK: - Effects helpers

  private func toast(_ title: String, subtitle: String? = nil, tensor: Bool = false) {
    toasts.append(Toast(title: title, subtitle: subtitle, born: now, tensor: tensor))
    if toasts.count > 3 { toasts.removeFirst(toasts.count - 3) }
  }

  private func emitSparks(rows: [Int], tensor: Bool) {
    let perRow = tensor ? 22 : 10
    for r in rows {
      for _ in 0..<perRow {
        let x = Double.random(in: 0..<Double(Board.width))
        let speed = Double.random(in: 2...(tensor ? 9 : 5))
        let angle = Double.random(in: 0..<(2 * .pi))
        sparks.append(
          Spark(
            x: x, y: Double(r) + 0.5, vx: cos(angle) * speed, vy: sin(angle) * speed - 2,
            born: now, life: Double.random(in: 0.35...(tensor ? 1.0 : 0.6)),
            hue: Double.random(in: 0...1)))
      }
    }
    if sparks.count > 400 { sparks.removeFirst(sparks.count - 400) }
  }

  private func emitDust(under piece: Piece) {
    let bottom = piece.cells.max(by: { $0.row < $1.row })?.row ?? 0
    for c in piece.cells where c.row == bottom {
      for _ in 0..<3 {
        sparks.append(
          Spark(
            x: Double(c.col) + Double.random(in: 0.1...0.9), y: Double(c.row) + 1,
            vx: Double.random(in: -2...2), vy: Double.random(in: -3 ... -0.5),
            born: now, life: 0.3, hue: 0.4))
      }
    }
  }

  private func clearEffects() {
    shockwaves.removeAll()
    sparks.removeAll()
    rowFlashes.removeAll()
    toasts.removeAll()
    shake = 0
    flash = 0
  }

  // MARK: - Persistence

  private func saveRun() {
    guard !engine.isOver, let data = try? JSONEncoder().encode(engine.state) else { return }
    defaults.set(data, forKey: Keys.savedRun)
    hasSavedRun = true
  }

  private func persistSettings() {
    defaults.set(soundEnabled, forKey: Keys.sound)
    defaults.set(hapticsEnabled, forKey: Keys.haptics)
    SoundEngine.shared.isEnabled = soundEnabled
    Haptics.isEnabled = hapticsEnabled
  }

  func clearLeaderboard() {
    leaderboard = Leaderboard()
    defaults.removeObject(forKey: Keys.leaderboard)
    SoundEngine.shared.play(.blocked)
  }
}

/// CADisplayLink needs an Objective-C target; this keeps GameStore free of NSObject.
private final class DisplayLinkProxy: NSObject {
  let callback: (CADisplayLink) -> Void
  init(_ callback: @escaping (CADisplayLink) -> Void) { self.callback = callback }
  @objc func fire(_ link: CADisplayLink) { callback(link) }
}
