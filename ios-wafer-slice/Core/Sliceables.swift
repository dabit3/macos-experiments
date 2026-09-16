import Foundation

/// Everything that can be launched onto the fab floor.
public enum SliceableKind: String, CaseIterable, Codable, Hashable {
  /// A full 300mm silicon wafer covered in a die grid.
  case wafer
  /// A single packaged chiplet with a gold-pad interposer.
  case chiplet
  /// A finned vapor-chamber heatsink.
  case heatsink
  /// A red, failed die. Slicing it costs a life in Arcade mode.
  case defective
  /// The golden flagship die. Slicing it starts a slow-motion 2x combo window.
  case flagship

  public var displayName: String {
    switch self {
    case .wafer: return "Wafer"
    case .chiplet: return "Chiplet"
    case .heatsink: return "Heatsink"
    case .defective: return "Defective Die"
    case .flagship: return "Flagship Die"
    }
  }

  /// Base yield awarded for a clean slice before multipliers.
  public var basePoints: Int {
    switch self {
    case .wafer: return 10
    case .chiplet: return 15
    case .heatsink: return 20
    case .defective: return 0
    case .flagship: return 100
    }
  }

  /// Approximate collision radius in scene points.
  public var radius: Double {
    switch self {
    case .wafer: return 58
    case .chiplet: return 40
    case .heatsink: return 46
    case .defective: return 36
    case .flagship: return 42
    }
  }

  /// Number of polygon sides used for the procedural silhouette.
  public var sides: Int {
    switch self {
    case .wafer: return 24
    case .chiplet: return 4
    case .heatsink: return 4
    case .defective: return 4
    case .flagship: return 8
    }
  }

  public var isHazard: Bool { self == .defective }
  public var isFlagship: Bool { self == .flagship }

  /// Short fab-floor flavor text shown when sliced.
  public var quip: String {
    switch self {
    case .wafer: return "Diced"
    case .chiplet: return "Binned"
    case .heatsink: return "Delidded"
    case .defective: return "Yield loss"
    case .flagship: return "Flagship!"
    }
  }
}

/// A single object launch. Positions are fractions of the playfield width so
/// the Core module never needs to know the device size.
public struct LaunchSpec: Equatable {
  public var kind: SliceableKind
  /// Horizontal start position as a 0...1 fraction of the playfield width.
  public var xFraction: Double
  /// Horizontal velocity in points per second.
  public var velocityX: Double
  /// Vertical launch velocity in points per second.
  public var velocityY: Double
  /// Angular velocity in radians per second.
  public var spin: Double
  /// Seconds after the wave start to launch this item.
  public var delay: Double

  public init(
    kind: SliceableKind, xFraction: Double, velocityX: Double, velocityY: Double,
    spin: Double, delay: Double
  ) {
    self.kind = kind
    self.xFraction = xFraction
    self.velocityX = velocityX
    self.velocityY = velocityY
    self.spin = spin
    self.delay = delay
  }
}

/// Decides what to launch and when. Difficulty ramps with elapsed time; Zen
/// mode never launches defective dies.
public struct LaunchDirector {
  public private(set) var random: SeededRandom
  public let mode: GameMode
  public private(set) var nextWaveAt: Double = 0.9
  public private(set) var wavesLaunched = 0
  public private(set) var sinceFlagship: Double = 0
  public private(set) var flagshipsLaunched = 0

  public init(mode: GameMode, seed: UInt64) {
    self.mode = mode
    random = SeededRandom(seed: seed)
  }

  /// Returns a wave when it is time to launch one for the given session time.
  public mutating func wave(at elapsed: Double, playfieldHeight: Double) -> [LaunchSpec]? {
    guard elapsed >= nextWaveAt else { return nil }
    let difficulty = difficulty(at: elapsed)
    wavesLaunched += 1
    sinceFlagship += elapsed - (nextWaveAt - interval(for: difficulty))
    nextWaveAt = elapsed + interval(for: difficulty)
    let count = waveSize(difficulty: difficulty)
    var specs: [LaunchSpec] = []
    for index in 0..<count {
      let kind = pickKind(difficulty: difficulty, indexInWave: index, waveSize: count)
      if kind == .flagship {
        sinceFlagship = 0
        flagshipsLaunched += 1
      }
      specs.append(spec(for: kind, index: index, playfieldHeight: playfieldHeight))
    }
    return specs
  }

  public func difficulty(at elapsed: Double) -> Double {
    mode == .zen ? min(0.55, elapsed / 90) : min(1, elapsed / 45)
  }

  func interval(for difficulty: Double) -> Double {
    mode == .zen ? 1.9 - difficulty * 0.6 : 1.7 - difficulty * 0.85
  }

  mutating func waveSize(difficulty: Double) -> Int {
    let roll = random.next()
    if difficulty > 0.7 && roll > 0.55 { return 4 }
    if difficulty > 0.35 && roll > 0.45 { return 3 }
    if roll > 0.4 { return 2 }
    return 1
  }

  mutating func pickKind(difficulty: Double, indexInWave: Int, waveSize: Int) -> SliceableKind {
    if mode == .arcade && sinceFlagship > 11 && indexInWave == 0 && random.chance(0.6) {
      return .flagship
    }
    if mode == .zen && sinceFlagship > 14 && indexInWave == 0 && random.chance(0.5) {
      return .flagship
    }
    if mode == .arcade && wavesLaunched > 2 && random.chance(0.08 + difficulty * 0.16) {
      return .defective
    }
    let roll = random.next()
    if roll < 0.5 { return .wafer }
    if roll < 0.8 { return .chiplet }
    return .heatsink
  }

  mutating func spec(for kind: SliceableKind, index: Int, playfieldHeight: Double) -> LaunchSpec {
    let xFraction = random.next(in: 0.14...0.86)
    let toward = (0.5 - xFraction) * 260
    let velocityX = toward + random.next(in: -60...60)
    // Reach roughly 62-84% of the screen height under the scene's gravity.
    let apex = playfieldHeight * random.next(in: 0.62...0.84)
    let velocityY = (2 * GameRules.gravity * apex).squareRoot()
    let spin = random.next(in: -3.2...3.2)
    let delay = Double(index) * random.next(in: 0.12...0.3)
    return LaunchSpec(
      kind: kind, xFraction: xFraction, velocityX: velocityX, velocityY: velocityY, spin: spin,
      delay: delay)
  }
}
