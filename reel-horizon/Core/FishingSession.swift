import Foundation

/// The fish currently hooked (or nibbling).
public struct HookedFish: Codable, Equatable {
  public var speciesID: String
  public var weightLb: Double
  /// 1 = fresh, 0 = exhausted.
  public var stamina: Double
  /// 0 = calm, 1 = full run.
  public var surge: Double
  public var surgeTimer: Double
  /// -1 = pulling left, 1 = pulling right.
  public var direction: Double
  public var directionTimer: Double

  public var species: Species { SpeciesCatalog.find(speciesID) }
}

public enum FishingEvent: Equatable {
  case cast(distanceFt: Double)
  case bite
  case hooked(speciesID: String)
  case strikeMissed
  case baitStolen
  case surge
  case landed(speciesID: String, weightLb: Double, grade: CatchGrade)
  case lineSnapped
  case fishEscaped
  case retrieved
  case dayOver
}

public enum FishingPhase: Equatable {
  case ready
  case charging
  case flying
  case soaking
  case bite
  case fighting
  case landed
  case lineSnapped
  case fishEscaped
  case dayOver

  public var lureIsInWater: Bool {
    switch self {
    case .soaking, .bite, .fighting: return true
    default: return false
    }
  }
}

/// Pure, deterministic simulation of one trip to the water. The UI drives it with `update(dt:)`.
public struct FishingSession: Equatable {
  public static let dayStartMinute = 5 * 60
  public static let dayEndMinute = 23 * 60
  public static let strikeWindow = 1.35
  public static let slackLimit = 3.0
  public static let redLineLimit = 1.1

  public private(set) var phase: FishingPhase = .ready
  public private(set) var phaseTime: Double = 0
  public private(set) var events: [FishingEvent] = []

  public var rig: RigSetup
  public let waterway: Waterway
  public var weather: WeatherKind
  /// Game clock, minutes since midnight. Advances `minutesPerSecond` per real second.
  public private(set) var clockMinutes: Double
  public var minutesPerSecond: Double = 1.0
  /// Multiplier on the bite rate; >1 speeds up automated tests and demos.
  public var biteBoost: Double = 1.0
  public private(set) var rng: SeededRandom

  /// 0...1 while charging.
  public private(set) var castPower: Double = 0
  private var powerRising = true
  public private(set) var castTargetFt: Double = 0
  public private(set) var flightDuration: Double = 0
  public private(set) var lureDistanceFt: Double = 0
  public private(set) var lineTension: Double = 0
  public private(set) var redLineTime: Double = 0
  public private(set) var slackTime: Double = 0
  public private(set) var fish: HookedFish?
  public private(set) var biteTimeLeft: Double = 0
  public private(set) var soakTime: Double = 0
  public private(set) var fightTime: Double = 0
  public private(set) var isReeling = false
  public private(set) var reelSpeed = 2
  public private(set) var rodRaised = false
  public private(set) var landedCatch: CatchRecord?
  public private(set) var lastBiteWasStolen = false

  public private(set) var rodDurability: Double
  public private(set) var reelDurability: Double
  public private(set) var lineDurability: Double
  public private(set) var casts = 0

  public init(
    rig: RigSetup, waterway: Waterway, seed: UInt64, startMinute: Int = dayStartMinute,
    rodDurability: Double = 1, reelDurability: Double = 1, lineDurability: Double = 1
  ) {
    self.rig = rig
    self.waterway = waterway
    self.weather = waterway.forecast.kind
    self.clockMinutes = Double(startMinute)
    self.rng = SeededRandom(seed: seed)
    self.rodDurability = rodDurability
    self.reelDurability = reelDurability
    self.lineDurability = lineDurability
  }

  // MARK: Derived

  public var hour: Int { Int(clockMinutes / 60) % 24 }
  public var minute: Int { Int(clockMinutes) % 60 }
  public var clockLabel: String {
    let h12 = hour % 12 == 0 ? 12 : hour % 12
    return String(format: "%d:%02d %@", h12, minute, hour < 12 ? "AM" : "PM")
  }
  /// 0 at sunrise-ish start, 1 at day end.
  public var dayProgress: Double {
    ((clockMinutes - Double(Self.dayStartMinute))
      / Double(Self.dayEndMinute - Self.dayStartMinute)).clamped(0, 1)
  }
  public var isNight: Bool { hour >= 21 || hour < 6 }
  public var lineLengthFt: Double { rig.lineLengthFt }

  public var tensionZone: TensionZone {
    if lineTension < 0.12 { return .slack }
    if lineTension < 0.62 { return .green }
    if lineTension < 0.85 { return .yellow }
    return .red
  }

  public enum TensionZone: Equatable { case slack, green, yellow, red }

  public mutating func drainEvents() -> [FishingEvent] {
    let out = events
    events.removeAll()
    return out
  }

  // MARK: Player input

  public mutating func beginCast() {
    guard phase == .ready else { return }
    setPhase(.charging)
    castPower = 0
    powerRising = true
  }

  public mutating func releaseCast() {
    guard phase == .charging else { return }
    let power = 0.12 + 0.88 * castPower
    castTargetFt = (rig.maxCastFt * power).clamped(8, lineLengthFt - 6)
    flightDuration = 0.35 + castTargetFt / 200
    lureDistanceFt = 0
    casts += 1
    isReeling = false
    setPhase(.flying)
    events.append(.cast(distanceFt: castTargetFt))
  }

  /// Sets the hook when a fish bites. Outside the bite window it just twitches the lure.
  public mutating func strike() {
    switch phase {
    case .bite:
      guard let fish else { return }
      let hookChance = 0.82 + 0.1 * fish.species.lureAffinity(rig.tackleKind)
      if rng.chance(hookChance) {
        setPhase(.fighting)
        fightTime = 0
        lineTension = 0.45
        events.append(.hooked(speciesID: fish.speciesID))
      } else {
        self.fish = nil
        events.append(.strikeMissed)
        lastBiteWasStolen = rig.lure.isConsumable
        setPhase(.soaking)
      }
    case .soaking:
      soakTime += 0.4
    default: break
    }
  }

  public mutating func setReeling(_ reeling: Bool) {
    isReeling = reeling
  }

  public mutating func setRodRaised(_ raised: Bool) {
    rodRaised = raised
  }

  public mutating func changeReelSpeed(_ delta: Int) {
    reelSpeed = (reelSpeed + delta).clamped(1, 3)
  }

  /// Forwards the clock by an hour; the fish stay where they are.
  public mutating func skipHour() {
    guard phase == .ready || phase == .soaking else { return }
    clockMinutes = min(Double(Self.dayEndMinute), clockMinutes + 60)
    checkDayOver()
  }

  /// After a landed fish has been kept or released, return to the shore.
  public mutating func acknowledgeOutcome() {
    switch phase {
    case .landed, .lineSnapped, .fishEscaped:
      fish = nil
      landedCatch = nil
      lureDistanceFt = 0
      lineTension = 0
      setPhase(.ready)
    default: break
    }
  }

  /// Puts a specific fish on the line so fights can be simulated deterministically.
  public mutating func hookForTesting(speciesID: String, weightLb: Double, distanceFt: Double) {
    fish = HookedFish(
      speciesID: speciesID, weightLb: weightLb, stamina: 1, surge: 0, surgeTimer: 2,
      direction: 1, directionTimer: 3)
    lureDistanceFt = distanceFt
    lineTension = 0.45
    fightTime = 0
    setPhase(.fighting)
  }

  // MARK: Simulation

  public mutating func update(dt rawDt: Double) {
    let dt = min(rawDt, 0.1)
    guard dt > 0, phase != .dayOver else { return }
    phaseTime += dt
    clockMinutes += dt * minutesPerSecond

    switch phase {
    case .ready, .landed, .lineSnapped, .fishEscaped, .dayOver:
      lineTension = max(0, lineTension - dt * 2)
    case .charging:
      let speed = 1.0 / 1.1
      if powerRising {
        castPower += dt * speed
        if castPower >= 1 {
          castPower = 1
          powerRising = false
        }
      } else {
        castPower -= dt * speed
        if castPower <= 0 {
          castPower = 0
          powerRising = true
        }
      }
    case .flying:
      let t = (phaseTime / flightDuration).clamped(0, 1)
      lureDistanceFt = castTargetFt * (1 - pow(1 - t, 2))
      if t >= 1 {
        lureDistanceFt = castTargetFt
        soakTime = 0
        setPhase(.soaking)
      }
    case .soaking:
      updateSoaking(dt: dt)
    case .bite:
      biteTimeLeft -= dt
      lineTension = 0.2 + 0.1 * sin(phaseTime * 18)
      if biteTimeLeft <= 0 {
        fish = nil
        if rig.lure.isConsumable {
          lastBiteWasStolen = true
          events.append(.baitStolen)
        } else {
          events.append(.strikeMissed)
        }
        setPhase(.soaking)
      }
    case .fighting:
      updateFight(dt: dt)
    }

    checkDayOver()
  }

  private mutating func checkDayOver() {
    if clockMinutes >= Double(Self.dayEndMinute) && phase != .fighting && phase != .landed {
      setPhase(.dayOver)
      events.append(.dayOver)
    }
  }

  private mutating func setPhase(_ next: FishingPhase) {
    phase = next
    phaseTime = 0
  }

  private mutating func updateSoaking(dt: Double) {
    soakTime += dt
    let isBait = rig.tackleKind.isBait
    if isReeling {
      let speed = rig.retrieveFtPerSec * (0.5 + 0.25 * Double(reelSpeed))
      lureDistanceFt -= speed * dt
      lineTension = 0.18 + 0.05 * Double(reelSpeed)
      if lureDistanceFt <= 3 {
        lureDistanceFt = 0
        lineTension = 0
        events.append(.retrieved)
        setPhase(.ready)
        return
      }
    } else {
      lineTension = max(0.04, lineTension - dt)
    }

    guard soakTime > 1.5 else { return }
    var presentation = 1.0
    if isBait { presentation = isReeling ? 0.25 : 1.0 } else { presentation = isReeling ? 1.35 : 0.12 }
    let baseRate = 0.07
    let candidates = biteCandidates()
    let interest = (candidates.reduce(0.0) { $0 + $1.1 } / 2.5).clamped(0.25, 1.4)
    let rate = baseRate * presentation * weather.biteFactor * interest * (isNight ? 0.6 : 1.0) * biteBoost
    if rng.chance(1 - exp(-rate * dt)) {
      guard let species = rng.weighted(candidates) else { return }
      let roll = rng.unit()
      let curve = pow(roll, 3.4)
      let weight = species.minWeightLb + (species.maxWeightLb - species.minWeightLb) * curve
      fish = HookedFish(
        speciesID: species.id, weightLb: weight, stamina: 1, surge: 0,
        surgeTimer: rng.range(1.5, 3.5), direction: rng.chance(0.5) ? -1 : 1,
        directionTimer: rng.range(2, 5))
      biteTimeLeft = Self.strikeWindow
      lastBiteWasStolen = false
      setPhase(.bite)
      events.append(.bite)
    }
  }

  /// Species weighted by abundance, time-of-day activity and how much they like the lure.
  public func biteCandidates() -> [(Species, Double)] {
    let kind = rig.tackleKind
    return waterway.species.map { species in
      (species, species.abundance * species.activity(atHour: hour) * species.lureAffinity(kind))
    }
  }

  private mutating func updateFight(dt: Double) {
    guard var hooked = fish else { return }
    fightTime += dt
    let species = hooked.species

    hooked.surgeTimer -= dt
    if hooked.surgeTimer <= 0 {
      if hooked.surge > 0.5 {
        hooked.surge = 0
        hooked.surgeTimer = rng.range(2.5, 6.0) * (0.6 + hooked.stamina)
      } else {
        hooked.surge = 1
        hooked.surgeTimer = rng.range(0.9, 2.2)
        events.append(.surge)
      }
    }
    hooked.directionTimer -= dt
    if hooked.directionTimer <= 0 {
      hooked.direction = -hooked.direction
      hooked.directionTimer = rng.range(2, 5)
    }

    let vigor = 0.35 + 0.65 * hooked.stamina
    let fishForceLb =
      hooked.weightLb * species.fightStrength * vigor * (1 + hooked.surge * 0.9)
      * (rodRaised ? 1.15 : 1.0)
    let dragLb = rig.reel.maxDragLb * (isReeling ? 0.55 + 0.15 * Double(reelSpeed) : 0.35)
    let breaking = rig.breakingStrainLb

    var targetTension: Double
    if isReeling {
      let load = fishForceLb + dragLb * 0.35 + 0.4
      targetTension = load / breaking
      let retrieve = rig.retrieveFtPerSec * (0.4 + 0.2 * Double(reelSpeed))
      let resistance = (fishForceLb / max(1, dragLb)).clamped(0, 1.6)
      let gain = retrieve * max(-0.6, 1 - resistance) * dt
      lureDistanceFt -= gain
    } else {
      let load = min(fishForceLb, dragLb) + 0.25
      targetTension = load / breaking
      let run = max(0, fishForceLb - dragLb) * 1.6 * dt
      lureDistanceFt += run
      if hooked.surge < 0.5 && !rodRaised {
        lureDistanceFt += 0.4 * dt * hooked.stamina
      }
    }
    lineTension += (targetTension - lineTension) * min(1, dt * 4.5)

    let inWorkZone = lineTension > 0.3 && lineTension < 0.92
    let tireRate = 0.13 / pow(max(0.5, hooked.weightLb), 0.42) * (inWorkZone ? 1.0 : 0.25)
    hooked.stamina = max(0, hooked.stamina - tireRate * dt * (rodRaised ? 1.35 : 1.0))

    if lineTension >= 0.85 {
      redLineTime += dt
      let wear = dt * 0.02
      rodDurability = max(0, rodDurability - wear)
      reelDurability = max(0, reelDurability - wear * 0.6)
      lineDurability = max(0, lineDurability - wear * 1.4)
    } else {
      redLineTime = max(0, redLineTime - dt * 0.5)
    }
    if lineTension < 0.12 {
      slackTime += dt
    } else {
      slackTime = max(0, slackTime - dt * 1.5)
    }

    fish = hooked

    if lineTension >= 1.0 && redLineTime >= Self.redLineLimit || lineTension >= 1.35
      || lureDistanceFt >= lineLengthFt
    {
      lineDurability = max(0, lineDurability - 0.25)
      fish = nil
      events.append(.lineSnapped)
      setPhase(.lineSnapped)
      return
    }
    if slackTime >= Self.slackLimit {
      fish = nil
      events.append(.fishEscaped)
      setPhase(.fishEscaped)
      return
    }
    if lureDistanceFt <= 5 {
      lureDistanceFt = 4
      let weight = hooked.weightLb
      let record = CatchRecord(
        speciesID: species.id, waterwayID: waterway.id, weightLb: weight,
        lengthIn: species.lengthFor(weightLb: weight), grade: species.grade(weightLb: weight),
        gameDay: 0, gameMinute: Int(clockMinutes), date: Date(), kept: false)
      landedCatch = record
      events.append(.landed(speciesID: species.id, weightLb: weight, grade: record.grade))
      setPhase(.landed)
    }
  }
}
