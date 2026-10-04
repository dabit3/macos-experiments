import Foundation

public enum FlapPhase: Equatable, Sendable {
  case ready
  case flying
  case falling
  case over
}

public struct Gate: Equatable, Sendable, Identifiable {
  public let id: Int
  public var x: Double
  public let gapCenter: Double
  public var scored = false
  public let hasShell: Bool
  public var shellTaken = false
}

public struct SplitMix: Sendable {
  private var state: UInt64
  public init(seed: UInt64) { state = seed }
  public mutating func next() -> Double {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    z ^= z >> 31
    return Double(z >> 11) / Double(1 << 53)
  }
}

/// Fixed-step Flappy-style simulation in world units (height is always 800).
public struct FlapEngine: Sendable {
  public static let height = 800.0
  public static let waterLine = 690.0
  public static let ceiling = 0.0
  public static let gravity = 2050.0
  public static let flapVelocity = -600.0
  public static let maxFall = 950.0
  public static let radius = 28.0
  public static let gateWidth = 84.0
  public static let gateSpacing = 250.0
  public static let baseSpeed = 175.0
  public static let step = 1.0 / 120.0

  public let width: Double
  public private(set) var phase = FlapPhase.ready
  public private(set) var y = 360.0
  public private(set) var velocity = 0.0
  public private(set) var gates: [Gate] = []
  public private(set) var score = 0
  public private(set) var shells = 0
  public private(set) var time = 0.0
  public private(set) var distance = 0.0
  public private(set) var flaps = 0
  public private(set) var lastFlapTime = -10.0
  public private(set) var lastScoreTime = -10.0
  public private(set) var lastShellTime = -10.0
  public private(set) var crashTime = -10.0
  private var rng: SplitMix
  private var nextID = 0
  private var accumulator = 0.0

  public init(width: Double = 420, seed: UInt64 = 7) {
    self.width = max(320, width)
    rng = SplitMix(seed: seed)
  }

  public var otterX: Double { width * 0.3 }

  public var gap: Double { max(172, 218 - Double(score) * 1.6) }

  public var speed: Double { Self.baseSpeed + min(70, Double(score) * 2.2) }

  /// Tilt in radians: nose up after a flap, diving as it falls.
  public var tilt: Double {
    if phase == .ready { return sin(time * 3) * 0.08 }
    let t = (velocity - Self.flapVelocity) / (Self.maxFall - Self.flapVelocity)
    return -0.42 + max(0, min(1, t)) * 1.9
  }

  public mutating func flap() {
    switch phase {
    case .ready:
      phase = .flying
      spawnInitialGates()
      fallthrough
    case .flying:
      velocity = Self.flapVelocity
      flaps += 1
      lastFlapTime = time
    case .falling, .over:
      break
    }
  }

  public mutating func advance(_ delta: Double) {
    accumulator += min(delta, 0.1)
    while accumulator >= Self.step {
      accumulator -= Self.step
      tick(Self.step)
    }
  }

  private mutating func tick(_ dt: Double) {
    time += dt
    switch phase {
    case .ready:
      y = 360 + sin(time * 3) * 12
      distance += Self.baseSpeed * 0.6 * dt
    case .flying:
      integrate(dt)
      scroll(dt)
      collide()
    case .falling:
      integrate(dt)
      if y >= Self.waterLine - Self.radius * 0.6 {
        y = Self.waterLine - Self.radius * 0.6
        velocity = 0
        phase = .over
      }
    case .over:
      break
    }
  }

  private mutating func integrate(_ dt: Double) {
    velocity = min(Self.maxFall, velocity + Self.gravity * dt)
    y += velocity * dt
    if y < Self.ceiling + Self.radius {
      y = Self.ceiling + Self.radius
      velocity = max(0, velocity)
    }
  }

  private mutating func scroll(_ dt: Double) {
    let move = speed * dt
    distance += move
    for index in gates.indices {
      gates[index].x -= move
      if !gates[index].scored && gates[index].x + Self.gateWidth / 2 < otterX - Self.radius {
        gates[index].scored = true
        score += 1
        lastScoreTime = time
      }
      if gates[index].hasShell && !gates[index].shellTaken {
        let dx = gates[index].x - otterX
        let dy = gates[index].gapCenter - y
        if dx * dx + dy * dy < pow(Self.radius + 14, 2) {
          gates[index].shellTaken = true
          shells += 1
          lastShellTime = time
        }
      }
    }
    gates.removeAll { $0.x < -Self.gateWidth }
    if let last = gates.last, last.x < width + Self.gateWidth {
      spawn(at: last.x + Self.gateSpacing)
    }
  }

  private mutating func collide() {
    if y + Self.radius * 0.8 >= Self.waterLine {
      crash()
      return
    }
    for gate in gates where hits(gate) {
      crash()
      return
    }
  }

  func hits(_ gate: Gate) -> Bool {
    let half = Self.gateWidth / 2
    let r = Self.radius * 0.82
    let top = gate.gapCenter - gap / 2
    let bottom = gate.gapCenter + gap / 2
    let rects = [
      (gate.x - half, -200.0, gate.x + half, top),
      (gate.x - half, bottom, gate.x + half, Self.height),
    ]
    for (minX, minY, maxX, maxY) in rects {
      let cx = max(minX, min(otterX, maxX))
      let cy = max(minY, min(y, maxY))
      let dx = otterX - cx
      let dy = y - cy
      if dx * dx + dy * dy < r * r { return true }
    }
    return false
  }

  private mutating func crash() {
    phase = .falling
    crashTime = time
    velocity = min(velocity, -180)
  }

  private mutating func spawnInitialGates() {
    gates.removeAll()
    spawn(at: width + 140)
  }

  private mutating func spawn(at x: Double) {
    let previous = gates.last?.gapCenter ?? 360
    let low = 150.0 + gap / 2 - 60
    let high = Self.waterLine - 70 - gap / 2
    let reach = nextID == 0 ? 60.0 : 170.0
    let target = low + rng.next() * (high - low)
    let center = max(low, min(high, previous + max(-reach, min(reach, target - previous))))
    let shell = nextID > 0 && rng.next() < 0.28
    gates.append(Gate(id: nextID, x: x, gapCenter: center, hasShell: shell))
    nextID += 1
  }

  /// Bronze at 10, silver at 25, gold at 50, pearl at 100.
  public static func medal(for score: Int) -> String? {
    switch score {
    case 100...: "Pearl"
    case 50...: "Gold"
    case 25...: "Silver"
    case 10...: "Bronze"
    default: nil
    }
  }
}
