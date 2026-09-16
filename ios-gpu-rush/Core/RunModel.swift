import Foundation

public struct SeededRandom: Equatable {
  public var state: UInt64
  public init(state: UInt64) { self.state = state }
  public mutating func next() -> Double {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Double(state >> 11) / Double(UInt64.max >> 11)
  }
  public mutating func nextInt(_ bound: Int) -> Int {
    bound <= 1 ? 0 : min(bound - 1, Int(next() * Double(bound)))
  }
}

public enum Lane: Int, CaseIterable, Equatable {
  case left = 0
  case center = 1
  case right = 2
}

public enum ObstacleKind: Equatable { case heatWave, capacitorBar }

public enum PickupKind: Equatable { case cudaCoin, dlssOrb }

public enum Stance: Equatable { case running, jumping, sliding }

public enum EntityKind: Equatable {
  case obstacle(ObstacleKind)
  case pickup(PickupKind)
}

public struct Entity: Equatable, Identifiable {
  public let id: Int
  public var lane: Lane
  public var distance: Double
  public var kind: EntityKind
  public init(id: Int, lane: Lane, distance: Double, kind: EntityKind) {
    self.id = id
    self.lane = lane
    self.distance = distance
    self.kind = kind
  }
}

public enum RunEvent: Equatable {
  case coin(total: Int)
  case dlssActivated
  case dlssEnded
  case crashed(ObstacleKind)
  case laneChanged(Lane)
  case jumped
  case slid
  case milestone(Int)
}

public struct RunConfig: Equatable {
  public var baseSpeed = 9.0
  public var maxBaseSpeed = 26.0
  public var accelPerSecond = 0.22
  public var dlssMultiplier = 3.0
  public var dlssDuration = 5.0
  public var jumpDuration = 0.62
  public var slideDuration = 0.7
  public var spawnGap = 18.0
  public var hitWindow = 1.2
  public init() {}
}

public struct RunState: Equatable {
  public enum Phase: Equatable { case ready, running, crashed }
  public var phase: Phase = .ready
  public var lane: Lane = .center
  public var stance: Stance = .running
  public var stanceTimeRemaining: Double = 0
  public var runDistance: Double = 0
  public var elapsed: Double = 0
  public var speed: Double = 0
  public var baseSpeed: Double = 0
  public var dlssTimeRemaining: Double = 0
  public var coins: Int = 0
  public var entities: [Entity] = []
  public var nextSpawnDistance: Double = 40
  public var nextMilestone: Double = 500
  public var dlssActive: Bool { dlssTimeRemaining > 0 }
  public var score: Int { (Int(runDistance) + coins * 10) * (dlssActive ? 2 : 1) }
  public var fps: Int { Int(speed * 10) }
  public init() {}
}

public struct RunSimulation {
  public var config: RunConfig
  public private(set) var state = RunState()
  private var rng: SeededRandom
  private var nextEntityID = 1
  private var pending: [RunEvent] = []

  public var fps: Int { state.fps }

  public init(config: RunConfig = .init(), seed: UInt64) {
    self.config = config
    rng = SeededRandom(state: seed == 0 ? 1 : seed)
  }

  public mutating func start() {
    guard state.phase == .ready else { return }
    state.phase = .running
    state.baseSpeed = config.baseSpeed
    state.speed = config.baseSpeed
  }

  @discardableResult
  public mutating func moveLeft() -> Bool { move(by: -1) }

  @discardableResult
  public mutating func moveRight() -> Bool { move(by: 1) }

  private mutating func move(by delta: Int) -> Bool {
    guard state.phase != .crashed else { return false }
    guard let raw = Lane(rawValue: state.lane.rawValue + delta) else { return false }
    state.lane = raw
    pending.append(.laneChanged(raw))
    return true
  }

  public mutating func jump() {
    guard state.phase == .running, state.stance == .running else { return }
    state.stance = .jumping
    state.stanceTimeRemaining = config.jumpDuration
    pending.append(.jumped)
  }

  public mutating func slide() {
    guard state.phase == .running, state.stance == .running else { return }
    state.stance = .sliding
    state.stanceTimeRemaining = config.slideDuration
    pending.append(.slid)
  }

  public mutating func insertEntity(_ entity: Entity) {
    state.entities.append(entity)
    nextEntityID = max(nextEntityID, entity.id + 1)
  }

  @discardableResult
  public mutating func advance(by delta: Double) -> [RunEvent] {
    var events = pending
    pending = []
    guard state.phase == .running else { return events }
    let dt = min(0.05, max(0, delta))
    state.elapsed += dt
    if state.stanceTimeRemaining > 0 {
      state.stanceTimeRemaining = max(0, state.stanceTimeRemaining - dt)
      if state.stanceTimeRemaining == 0 { state.stance = .running }
    }
    if state.dlssTimeRemaining > 0 {
      state.dlssTimeRemaining = max(0, state.dlssTimeRemaining - dt)
      if state.dlssTimeRemaining == 0 { events.append(.dlssEnded) }
    }
    state.baseSpeed = min(
      config.maxBaseSpeed, config.baseSpeed + config.accelPerSecond * state.elapsed)
    state.speed =
      state.baseSpeed * (state.dlssActive ? config.dlssMultiplier : 1)
    let previousDistance = state.runDistance
    state.runDistance += state.speed * dt
    while state.runDistance + 120 >= state.nextSpawnDistance {
      spawnRow(at: state.nextSpawnDistance)
      state.nextSpawnDistance += max(11, config.spawnGap - state.runDistance * 0.002)
    }
    checkCollisions(&events, from: previousDistance)
    state.entities.removeAll { $0.distance < state.runDistance - 10 }
    while state.runDistance >= state.nextMilestone {
      events.append(.milestone(Int(state.nextMilestone)))
      state.nextMilestone += 500
    }
    return events
  }

  private mutating func checkCollisions(_ events: inout [RunEvent], from previousDistance: Double) {
    var consumed: Set<Int> = []
    for entity in state.entities {
      guard entity.lane == state.lane,
        entity.distance >= previousDistance - config.hitWindow,
        entity.distance <= state.runDistance + config.hitWindow
      else { continue }
      switch entity.kind {
      case .pickup(.cudaCoin):
        consumed.insert(entity.id)
        state.coins += 1
        events.append(.coin(total: state.coins))
      case .pickup(.dlssOrb):
        consumed.insert(entity.id)
        state.dlssTimeRemaining = config.dlssDuration
        events.append(.dlssActivated)
      case .obstacle(let kind):
        let avoided =
          (kind == .heatWave && state.stance == .jumping)
          || (kind == .capacitorBar && state.stance == .sliding)
        consumed.insert(entity.id)
        if !avoided {
          state.phase = .crashed
          events.append(.crashed(kind))
          state.entities.removeAll { consumed.contains($0.id) }
          return
        }
      }
    }
    state.entities.removeAll { consumed.contains($0.id) }
  }

  private mutating func spawnRow(at distance: Double) {
    var lanes = Lane.allCases
    for index in lanes.indices {
      let swap = index + rng.nextInt(lanes.count - index)
      lanes.swapAt(index, swap)
    }
    let obstacleCount = rng.next() < 0.6 ? 1 : 2
    for lane in lanes.prefix(obstacleCount) {
      let kind: ObstacleKind = rng.next() < 0.5 ? .heatWave : .capacitorBar
      appendEntity(lane: lane, distance: distance, kind: .obstacle(kind))
    }
    for lane in lanes.dropFirst(obstacleCount) {
      let roll = rng.next()
      if !state.dlssActive && roll < 0.08 {
        appendEntity(lane: lane, distance: distance, kind: .pickup(.dlssOrb))
      } else if roll < 0.65 {
        for offset in stride(from: 0.0, through: 6.0, by: 3.0) {
          appendEntity(lane: lane, distance: distance + offset, kind: .pickup(.cudaCoin))
        }
      }
    }
  }

  private mutating func appendEntity(lane: Lane, distance: Double, kind: EntityKind) {
    state.entities.append(Entity(id: nextEntityID, lane: lane, distance: distance, kind: kind))
    nextEntityID += 1
  }
}
