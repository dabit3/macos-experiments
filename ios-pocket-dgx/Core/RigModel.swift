import Foundation

/// The two toys you can drop into a room.
public enum RigKind: String, CaseIterable, Codable, Sendable {
  case rack
  case card

  public var title: String {
    switch self {
    case .rack: return "Pocket DGX"
    case .card: return "Mega Card"
    }
  }
  public var subtitle: String {
    switch self {
    case .rack: return "Rack-mount AI supercomputer"
    case .card: return "Comically oversized graphics card"
    }
  }
  /// Peak synthetic throughput once fully warmed up, in tokens per second.
  public var peakTokensPerSecond: Double {
    switch self {
    case .rack: return 1_800_000
    case .card: return 142_000
    }
  }
  /// Peak synthetic power draw in watts.
  public var peakWatts: Double {
    switch self {
    case .rack: return 120_000
    case .card: return 600
    }
  }
  /// Real-world footprint of the life-size model in meters (width, height, depth).
  public var lifeSize: (width: Double, height: Double, depth: Double) {
    switch self {
    case .rack: return (0.6, 2.0, 1.0)
    case .card: return (1.2, 0.5, 0.25)
    }
  }
}

/// Discrete size presets. Multiplier is applied to the life-size footprint.
public enum ScalePreset: String, CaseIterable, Codable, Sendable {
  case desk
  case life
  case room
  case house

  public var multiplier: Double {
    switch self {
    case .desk: return 0.18
    case .life: return 1
    case .room: return 2.6
    case .house: return 7
    }
  }
  public var label: String {
    switch self {
    case .desk: return "Desk"
    case .life: return "1:1"
    case .room: return "Room"
    case .house: return "House"
    }
  }
  /// Nearest preset to a free-form multiplier (pinch gestures snap to this).
  public static func nearest(to multiplier: Double) -> ScalePreset {
    allCases.min {
      abs(log($0.multiplier) - log(multiplier)) < abs(log($1.multiplier) - log(multiplier))
    }!
  }
  public static let minimum = 0.08
  public static let maximum = 12.0
  public static func clamp(_ value: Double) -> Double { min(maximum, max(minimum, value)) }
}

public enum PowerPhase: String, Codable, Sendable {
  case off
  case booting
  case running
  case shuttingDown
}

/// Deterministic, frame-driven simulation of one rig: power state, fan speed,
/// LED pulse and the holographic throughput readout. Pure Swift; no rendering.
public struct RigSimulation: Equatable, Sendable {
  public var kind: RigKind
  public var phase: PowerPhase = .off
  /// 0...1 progress through boot or shutdown.
  public var transition: Double = 0
  /// 0...1 fan speed fraction.
  public var fan: Double = 0
  /// Accumulated fan rotation in radians.
  public var fanAngle: Double = 0
  /// Seconds the rig has been running this session.
  public var uptime: Double = 0
  /// 0...1 brightness of the LED pulse this frame.
  public var ledPulse: Double = 0
  /// Displayed tokens/sec (eases toward the target).
  public var tokensPerSecond: Double = 0
  /// Tokens generated since power on.
  public var totalTokens: Double = 0
  public var scale: Double = 1
  private var clock: Double = 0

  public static let bootDuration = 2.4
  public static let shutdownDuration = 1.2

  public init(kind: RigKind, scale: Double = 1) {
    self.kind = kind
    self.scale = scale
  }

  public var isOn: Bool { phase == .running || phase == .booting }

  /// Toggle power. Returns the phase entered.
  @discardableResult
  public mutating func togglePower() -> PowerPhase {
    switch phase {
    case .off, .shuttingDown:
      phase = .booting
      transition = 0
    case .running, .booting:
      phase = .shuttingDown
      transition = 0
    }
    return phase
  }

  public var watts: Double {
    switch phase {
    case .off: return 0
    case .booting: return kind.peakWatts * (0.15 + 0.85 * transition * transition)
    case .running: return kind.peakWatts * (0.96 + 0.04 * sin(clock * 0.7))
    case .shuttingDown: return kind.peakWatts * (1 - transition) * 0.6
    }
  }

  /// Target fan fraction for the current phase.
  var fanTarget: Double {
    switch phase {
    case .off: return 0
    case .booting: return 0.35 + 0.65 * transition
    case .running: return 1
    case .shuttingDown: return 0
    }
  }

  var tokensTarget: Double {
    switch phase {
    case .running: return kind.peakTokensPerSecond * (0.97 + 0.03 * sin(clock * 1.9))
    case .booting: return kind.peakTokensPerSecond * max(0, transition - 0.6) / 0.4 * 0.5
    default: return 0
    }
  }

  /// Advance the simulation. Deltas are capped at 50ms so a hitch never teleports state.
  public mutating func tick(_ rawDelta: Double) {
    let delta = min(0.05, max(0, rawDelta))
    guard delta > 0 else { return }
    clock += delta
    switch phase {
    case .booting:
      transition = min(1, transition + delta / Self.bootDuration)
      if transition >= 1 {
        phase = .running
        transition = 0
      }
    case .shuttingDown:
      transition = min(1, transition + delta / Self.shutdownDuration)
      if transition >= 1 {
        phase = .off
        transition = 0
      }
    case .running:
      uptime += delta
    case .off:
      break
    }
    let fanRate = phase == .shuttingDown || phase == .off ? 0.7 : 1.4
    fan += (fanTarget - fan) * min(1, delta * fanRate)
    if fan < 0.002 && fanTarget == 0 { fan = 0 }
    fanAngle += fan * 42 * delta
    if fanAngle > .pi * 2 * 1000 { fanAngle -= .pi * 2 * 1000 }
    tokensPerSecond += (tokensTarget - tokensPerSecond) * min(1, delta * 2.2)
    if phase == .off && tokensPerSecond < 1 { tokensPerSecond = 0 }
    totalTokens += tokensPerSecond * delta
    ledPulse = Self.pulse(phase: phase, transition: transition, clock: clock)
  }

  /// LED brightness curve: dark when off, a fast breathing ramp while booting,
  /// a slow heartbeat when running, and a fade while shutting down.
  public static func pulse(phase: PowerPhase, transition: Double, clock: Double) -> Double {
    switch phase {
    case .off: return 0
    case .booting: return 0.25 + 0.75 * abs(sin(clock * 9)) * transition
    case .running: return 0.7 + 0.3 * (0.5 + 0.5 * sin(clock * 2.4))
    case .shuttingDown: return (1 - transition) * 0.6
    }
  }
}

/// Boot-log lines shown during power on, indexed by progress.
public enum BootSequence {
  public static func lines(for kind: RigKind) -> [String] {
    switch kind {
    case .rack:
      return [
        "POST: 8x tensor blades detected",
        "Linking NVSwitch fabric… 900 GB/s",
        "Loading CUDA kernels",
        "Warming KV cache",
        "Calibrating fans for maximum whoosh",
        "Model weights mapped. Inference online.",
      ]
    case .card:
      return [
        "PCIe Gen5 x16 link trained",
        "Detecting 24 GB of very fast memory",
        "Shader cores: all of them",
        "DLSS: hallucinating extra pixels",
        "Checking power connector is fully seated",
        "Ray tracing: ON. Ego: ON.",
      ]
    }
  }
  public static func line(for kind: RigKind, progress: Double) -> String {
    let all = lines(for: kind)
    let index = min(all.count - 1, max(0, Int(progress * Double(all.count))))
    return all[index]
  }
}

/// Fortune-cookie captions for photos and the title screen.
public enum Lore {
  public static let captions: [String] = [
    "The more you buy, the more you save.",
    "It just works. In FP8.",
    "Warning: may attract data scientists.",
    "One rack. Zero gaming.",
    "Every tensor deserves a home.",
    "Yes, it fits. No, you can't lift it.",
    "Hand-built on a 4nm wafer of pure vibes.",
    "Rendered with 100% real fake ray tracing.",
    "Ask your landlord about three-phase power.",
    "It runs Crysis. Also everything else.",
  ]
  public static func caption(seed: Int) -> String {
    captions[abs(seed) % captions.count]
  }
}

/// Human formatting helpers for the HUD.
public enum Format {
  public static func tokens(_ value: Double) -> String {
    if value >= 1_000_000 { return String(format: "%.2fM", value / 1_000_000) }
    if value >= 1_000 { return String(format: "%.1fK", value / 1_000) }
    return String(format: "%.0f", value)
  }
  public static func watts(_ value: Double) -> String {
    if value >= 1_000 { return String(format: "%.1f kW", value / 1_000) }
    return String(format: "%.0f W", value)
  }
  public static func scale(_ multiplier: Double, kind: RigKind) -> String {
    let height = kind.lifeSize.height * multiplier
    if height >= 1 { return String(format: "%.1f m tall", height) }
    return String(format: "%.0f cm tall", height * 100)
  }
  public static func uptime(_ seconds: Double) -> String {
    let total = Int(seconds)
    return String(format: "%02d:%02d", total / 60, total % 60)
  }
}

/// Lifetime stats persisted between launches.
public struct RigStats: Codable, Equatable, Sendable {
  public var powerOns = 0
  public var photos = 0
  public var totalTokens: Double = 0
  public var longestUptime: Double = 0
  public var largestScale: Double = 1
  public var sound = true
  public var lastKind: RigKind = .rack

  public init() {}

  public mutating func record(_ simulation: RigSimulation) {
    longestUptime = max(longestUptime, simulation.uptime)
    largestScale = max(largestScale, simulation.scale)
  }

  /// Playful rank derived from lifetime tokens.
  public var rank: String {
    switch totalTokens {
    case ..<1: return "Intern"
    case ..<5_000_000: return "Kernel Tinkerer"
    case ..<50_000_000: return "CUDA Whisperer"
    case ..<500_000_000: return "Tensor Wrangler"
    default: return "Wafer Baron"
    }
  }
}

/// Layout math for the rack model so geometry and tests agree.
public struct RackLayout: Sendable {
  public static let bladeCount = 8
  public static let width = 0.6
  public static let height = 2.0
  public static let depth = 1.0
  public static let bladeHeight = 0.13
  public static let bladeGap = 0.03
  public static let fansPerBlade = 3

  /// Center Y of each blade (meters from floor).
  public static func bladeCenters() -> [Double] {
    let stackHeight = Double(bladeCount) * bladeHeight + Double(bladeCount - 1) * bladeGap
    let start = height * 0.5 - stackHeight * 0.5 + bladeHeight * 0.5
    return (0..<bladeCount).map { start + Double($0) * (bladeHeight + bladeGap) }
  }
  /// Center X of each fan on a blade.
  public static func fanCenters() -> [Double] {
    let usable = width * 0.78
    let spacing = usable / Double(fansPerBlade)
    return (0..<fansPerBlade).map { -usable / 2 + spacing * (Double($0) + 0.5) }
  }
}
