import Foundation

/// Deterministic SplitMix64 generator so runs and tests are reproducible.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

public struct FlapConfig: Sendable, Equatable {
    public var gravity = 1500.0
    public var flapVelocity = 455.0
    public var maxFallSpeed = 720.0
    public var scrollSpeed = 150.0
    public var gapHeight = 200.0
    public var minimumGapHeight = 160.0
    public var gapShrinkPerPoint = 1.0
    public var logWidth = 76.0
    public var logSpacing = 232.0
    public var maxGapShift = 250.0
    public var otterRadius = 17.0
    public var groundHeight = 112.0
    public var ceilingMargin = 70.0

    public init() {}
}

public struct Log: Sendable, Equatable {
    public var x: Double
    public var gapCenter: Double
    public var gapHeight: Double
    public var scored = false

    public var gapBottom: Double {
        gapCenter - gapHeight / 2
    }

    public var gapTop: Double {
        gapCenter + gapHeight / 2
    }
}

public enum FlapPhase: Sendable, Equatable {
    case ready, playing, falling, over
}

public enum FlapEvent: Sendable, Equatable {
    case flapped, scored(Int), crashed, landed
}

public enum Medal: String, Sendable, CaseIterable {
    case pebble = "Pebble"
    case shell = "Shell"
    case pearl = "Pearl"
    case golden = "Golden Clam"

    public static func award(for score: Int) -> Medal? {
        switch score {
        case 40...: .golden
        case 25 ..< 40: .pearl
        case 10 ..< 25: .shell
        case 5 ..< 10: .pebble
        default: nil
        }
    }
}

/// Pure Flappy-style simulation in scene points with y pointing up.
public struct FlapWorld: Sendable {
    public let width: Double
    public let height: Double
    public let config: FlapConfig
    public private(set) var phase: FlapPhase = .ready
    public private(set) var otterY: Double
    public private(set) var velocity = 0.0
    public private(set) var score = 0
    public private(set) var logs: [Log] = []
    public private(set) var distance = 0.0
    public private(set) var readyTime = 0.0
    private var generator: SeededGenerator

    public var otterX: Double {
        width * 0.3
    }

    public var restingY: Double {
        config.groundHeight + config.otterRadius
    }

    public init(width: Double, height: Double, config: FlapConfig = FlapConfig(), seed: UInt64 = UInt64.random(in: 1 ... .max)) {
        self.width = width
        self.height = height
        self.config = config
        generator = SeededGenerator(seed: seed)
        otterY = config.groundHeight + (height - config.groundHeight) * 0.55
    }

    public var currentGapHeight: Double {
        max(config.minimumGapHeight, config.gapHeight - Double(score) * config.gapShrinkPerPoint)
    }

    /// Tap input. Starts a ready world, flaps while playing, ignored otherwise.
    @discardableResult
    public mutating func flap() -> Bool {
        switch phase {
        case .ready:
            phase = .playing
            spawnInitialLogs()
        case .playing:
            break
        case .falling, .over:
            return false
        }
        velocity = config.flapVelocity
        return true
    }

    public mutating func step(_ dt: Double) -> [FlapEvent] {
        guard dt > 0 else { return [] }
        switch phase {
        case .ready:
            readyTime += dt
            return []
        case .over:
            return []
        case .playing, .falling:
            break
        }
        var events: [FlapEvent] = []
        velocity = max(-config.maxFallSpeed, velocity - config.gravity * dt)
        otterY += velocity * dt
        let ceiling = height - config.otterRadius
        if otterY > ceiling {
            otterY = ceiling
            velocity = min(velocity, 0)
        }

        if phase == .playing {
            scroll(dt, events: &events)
            if collides() {
                phase = .falling
                velocity = min(velocity, 0)
                events.append(.crashed)
            }
        }
        if otterY <= restingY {
            otterY = restingY
            velocity = 0
            if phase == .playing {
                events.append(.crashed)
            }
            phase = .over
            events.append(.landed)
        }
        return events
    }

    private mutating func scroll(_ dt: Double, events: inout [FlapEvent]) {
        let shift = config.scrollSpeed * dt
        distance += shift
        for index in logs.indices {
            logs[index].x -= shift
            if !logs[index].scored, logs[index].x + config.logWidth / 2 < otterX - config.otterRadius {
                logs[index].scored = true
                score += 1
                events.append(.scored(score))
            }
        }
        logs.removeAll { $0.x < -config.logWidth }
        while let last = logs.last, last.x < width + config.logWidth {
            appendLog(at: last.x + config.logSpacing)
        }
    }

    private mutating func spawnInitialLogs() {
        logs = []
        appendLog(at: width + config.logWidth + 60)
        while let last = logs.last, last.x < width + config.logWidth {
            appendLog(at: last.x + config.logSpacing)
        }
    }

    private mutating func appendLog(at x: Double) {
        let gap = currentGapHeight
        var low = config.groundHeight + gap / 2 + 40
        var high = height - config.ceilingMargin - gap / 2
        if let previous = logs.last?.gapCenter {
            low = max(low, previous - config.maxGapShift)
            high = min(high, previous + config.maxGapShift)
        }
        let center = high > low ? Double.random(in: low ... high, using: &generator) : (low + high) / 2
        logs.append(Log(x: x, gapCenter: center, gapHeight: gap))
    }

    /// Circle-versus-rectangle test against both halves of every nearby log.
    public func collides() -> Bool {
        let r = config.otterRadius
        for log in logs where abs(log.x - otterX) < config.logWidth / 2 + r {
            let left = log.x - config.logWidth / 2, right = log.x + config.logWidth / 2
            if Self.circle(otterX, otterY, r, hitsRectFromX: left, toX: right, fromY: config.groundHeight, toY: log.gapBottom) ||
                Self.circle(otterX, otterY, r, hitsRectFromX: left, toX: right, fromY: log.gapTop, toY: height + 400)
            {
                return true
            }
        }
        return false
    }

    public static func circle(_ cx: Double, _ cy: Double, _ r: Double, hitsRectFromX minX: Double, toX maxX: Double, fromY minY: Double, toY maxY: Double) -> Bool {
        let nx = min(max(cx, minX), maxX)
        let ny = min(max(cy, minY), maxY)
        let dx = cx - nx, dy = cy - ny
        return dx * dx + dy * dy < r * r
    }

    // MARK: Test hooks

    public mutating func place(otterY: Double, velocity: Double = 0) {
        self.otterY = otterY
        self.velocity = velocity
    }

    public mutating func replaceLogs(_ logs: [Log]) {
        self.logs = logs
    }
}
