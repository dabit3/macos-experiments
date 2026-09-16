import Foundation

public enum GameMode: String, CaseIterable, Codable, Hashable, Identifiable {
  /// 60 second production run with three lives.
  case arcade
  /// Calm, endless cleanroom with no defective dies and no clock.
  case zen

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .arcade: return "Arcade"
    case .zen: return "Zen"
    }
  }

  public var tagline: String {
    switch self {
    case .arcade: return "60-second production run. Three lives. Defective dies are live."
    case .zen: return "Quiet cleanroom. No clock, no defects. Slice until you feel binned."
    }
  }

  public var duration: Double? { self == .arcade ? GameRules.arcadeDuration : nil }
  public var startingLives: Int { self == .arcade ? GameRules.arcadeLives : 0 }
}

public enum GameRules {
  public static let arcadeDuration: Double = 60
  public static let arcadeLives = 3
  /// Scene gravity magnitude in points per second squared.
  public static let gravity: Double = 620
  /// Slices in one swipe needed to trigger the binning bonus.
  public static let binningThreshold = 3
  /// Bonus yield per sliced item once the binning threshold is reached.
  public static let binningBonusPerItem = 20
  /// Duration of the flagship slow-motion combo window, in real seconds.
  public static let flagshipSlowMoDuration: Double = 3.2
  public static let flagshipTimeScale: Double = 0.38
  public static let flagshipMultiplier = 2
  public static let flagshipLifeRefund = 1
}

public enum EndReason: String, Codable, Equatable {
  case timeUp
  case outOfLives
  case finished
}

/// Outcome of slicing a single object.
public struct HitResult: Equatable {
  public var kind: SliceableKind
  public var points: Int
  public var multiplier: Int
  public var lostLife: Bool
  public var startedSlowMo: Bool
  public var refundedLife: Bool
  public var swipeCount: Int
}

/// Outcome of lifting the finger after a swipe.
public struct SwipeSummary: Equatable {
  public var slicedCount: Int
  public var binningBonus: Int
  public var isBinningBonus: Bool { binningBonus > 0 }
}

/// Pure game state. Everything visual (physics, particles, audio) lives in the
/// app; this struct owns score, lives, timers and the combo rules so they can be
/// tested deterministically.
public struct GameSession: Equatable {
  public let mode: GameMode
  public private(set) var score = 0
  public private(set) var lives: Int
  public private(set) var elapsed: Double = 0
  public private(set) var slowMoRemaining: Double = 0
  public private(set) var swipeHits: [SliceableKind] = []
  public private(set) var isSwiping = false
  public private(set) var slicedCount = 0
  public private(set) var missedCount = 0
  public private(set) var defectiveHits = 0
  public private(set) var flagshipHits = 0
  public private(set) var binningBonuses = 0
  public private(set) var bestSwipe = 0
  public private(set) var endReason: EndReason?
  public private(set) var isPaused = false

  public init(mode: GameMode) {
    self.mode = mode
    lives = mode.startingLives
  }

  public var isOver: Bool { endReason != nil }
  public var isSlowMo: Bool { slowMoRemaining > 0 }
  public var multiplier: Int { isSlowMo ? GameRules.flagshipMultiplier : 1 }
  /// Simulation speed factor for physics and object motion.
  public var timeScale: Double { isSlowMo ? GameRules.flagshipTimeScale : 1 }
  public var timeRemaining: Double? {
    mode.duration.map { max(0, $0 - elapsed) }
  }
  public var isRunning: Bool { !isOver && !isPaused }

  /// Advances the real-time clocks. The round timer keeps ticking during slow
  /// motion, so flagship windows trade time for doubled yield.
  public mutating func advance(_ dt: Double) {
    guard isRunning, dt > 0 else { return }
    elapsed += dt
    slowMoRemaining = max(0, slowMoRemaining - dt)
    if let duration = mode.duration, elapsed >= duration - 0.000001 {
      elapsed = duration
      finish(.timeUp)
    }
  }

  public mutating func pause() {
    guard !isOver else { return }
    isPaused = true
    if isSwiping { _ = endSwipe() }
  }

  public mutating func resume() { isPaused = false }

  public mutating func finish(_ reason: EndReason = .finished) {
    guard !isOver else { return }
    endReason = reason
    isPaused = false
    if isSwiping { _ = endSwipe() }
    slowMoRemaining = 0
  }

  public mutating func beginSwipe() {
    guard isRunning else { return }
    isSwiping = true
    swipeHits = []
  }

  /// Registers a sliced object. Returns nil when the session is not accepting input.
  @discardableResult
  public mutating func registerHit(_ kind: SliceableKind) -> HitResult? {
    guard isRunning else { return nil }
    if !isSwiping { beginSwipe() }
    swipeHits.append(kind)
    slicedCount += 1
    var result = HitResult(
      kind: kind, points: 0, multiplier: multiplier, lostLife: false, startedSlowMo: false,
      refundedLife: false, swipeCount: swipeHits.count)
    switch kind {
    case .defective:
      defectiveHits += 1
      if mode == .arcade {
        lives -= 1
        result.lostLife = true
        if lives <= 0 { finish(.outOfLives) }
      }
    case .flagship:
      flagshipHits += 1
      result.points = kind.basePoints * multiplier
      score += result.points
      slowMoRemaining = GameRules.flagshipSlowMoDuration
      result.startedSlowMo = true
      if mode == .arcade && lives < mode.startingLives {
        lives += GameRules.flagshipLifeRefund
        result.refundedLife = true
      }
    default:
      result.points = kind.basePoints * multiplier
      score += result.points
    }
    return result
  }

  /// Ends the current swipe and awards the binning bonus for three or more
  /// clean slices in a single gesture. Defective dies never count toward it.
  @discardableResult
  public mutating func endSwipe() -> SwipeSummary {
    let clean = swipeHits.filter { !$0.isHazard }.count
    isSwiping = false
    swipeHits = []
    bestSwipe = max(bestSwipe, clean)
    guard clean >= GameRules.binningThreshold, endReason != .outOfLives else {
      return SwipeSummary(slicedCount: clean, binningBonus: 0)
    }
    let bonus = clean * GameRules.binningBonusPerItem * multiplier
    score += bonus
    binningBonuses += 1
    return SwipeSummary(slicedCount: clean, binningBonus: bonus)
  }

  /// An object fell off the bottom of the screen unsliced. Missing never
  /// costs a life; it only feeds the end-of-run stats.
  public mutating func registerMiss(_ kind: SliceableKind) {
    guard !kind.isHazard else { return }
    missedCount += 1
  }

  public var summary: RunSummary {
    RunSummary(
      mode: mode, score: score, sliced: slicedCount, missed: missedCount,
      defectiveHits: defectiveHits, flagshipHits: flagshipHits,
      binningBonuses: binningBonuses, bestSwipe: bestSwipe, duration: elapsed,
      endReason: endReason ?? .finished)
  }
}

public struct RunSummary: Codable, Equatable {
  public var mode: GameMode
  public var score: Int
  public var sliced: Int
  public var missed: Int
  public var defectiveHits: Int
  public var flagshipHits: Int
  public var binningBonuses: Int
  public var bestSwipe: Int
  public var duration: Double
  public var endReason: EndReason

  /// Percentage of launched, non-hazard objects that were sliced.
  public var yieldPercent: Int {
    let total = sliced - defectiveHits + missed
    guard total > 0 else { return 0 }
    return Int((Double(sliced - defectiveHits) / Double(total) * 100).rounded())
  }

  /// Fab-floor "bin" grade awarded for the run.
  public var bin: String {
    switch score {
    case ..<150: return "Engineering Sample"
    case ..<500: return "Consumer Bin"
    case ..<1000: return "Founders Edition"
    case ..<2000: return "Datacenter Grade"
    default: return "Tensor Core Legend"
    }
  }
}
