import Foundation

enum RunPhase: Equatable {
  case ready, running, paused, crashed, cleared
}

struct Engine {
  static let cubeSize = 38.0
  static let gravity = 1_800.0
  static let jumpVelocity = 680.0
  static let fixedStep = 1.0 / 120

  let stage: Stage
  let practice: Bool
  private(set) var phase: RunPhase = .ready
  private(set) var x = 0.0
  private(set) var y = 0.0
  private(set) var velocity = 0.0
  private(set) var checkpoint = 0.0
  private(set) var jumps = 0
  private(set) var grounded = true
  private var accumulator = 0.0
  private var jumpBuffer = 0.0

  init(stage: Stage, practice: Bool) {
    self.stage = stage
    self.practice = practice
  }

  var progress: Double { min(100, x / stage.length * 100) }
  var nextHazardDistance: Double? {
    stage.obstacles.first { $0.x + $0.width > x - Self.cubeSize / 2 }.map {
      $0.x - x - Self.cubeSize / 2
    }
  }

  mutating func start() {
    guard phase == .ready else { return }
    phase = .running
  }

  mutating func jump() {
    guard phase == .running else { return }
    jumpBuffer = 0.12
    consumeJump()
  }

  mutating func pause() {
    guard phase == .running else { return }
    phase = .paused
    accumulator = 0
    jumpBuffer = 0
  }

  mutating func resume() {
    guard phase == .paused else { return }
    phase = .running
  }

  mutating func retry() {
    x = practice ? checkpoint : 0
    y = 0
    velocity = 0
    grounded = true
    jumps = 0
    accumulator = 0
    jumpBuffer = 0
    phase = .ready
  }

  mutating func advance(_ elapsed: Double) {
    guard phase == .running else { return }
    accumulator += min(max(elapsed, 0), 0.1)
    while accumulator >= Self.fixedStep && phase == .running {
      step()
      accumulator -= Self.fixedStep
    }
  }

  private mutating func consumeJump() {
    if grounded && jumpBuffer > 0 {
      velocity = Self.jumpVelocity
      grounded = false
      jumpBuffer = 0
      jumps += 1
    }
  }

  private mutating func step() {
    let dt = Self.fixedStep
    jumpBuffer = max(0, jumpBuffer - dt)
    consumeJump()
    let previousY = y
    x += stage.speed * dt
    velocity -= Self.gravity * dt
    y += velocity * dt
    grounded = false
    if y <= 0 {
      y = 0
      velocity = 0
      grounded = true
    }

    let half = Self.cubeSize / 2 - 4
    for obstacle in stage.obstacles
    where obstacle.x < x + half && obstacle.x + obstacle.width > x - half {
      if obstacle.kind == .block && previousY >= obstacle.height && y <= obstacle.height
        && velocity <= 0
      {
        y = obstacle.height
        velocity = 0
        grounded = true
      } else if Self.intersects(
        x: x, bottom: y + 3, halfWidth: half,
        height: Self.cubeSize - 6, obstacle: obstacle)
      {
        phase = .crashed
        return
      }
    }
    if practice && grounded {
      for marker in stage.checkpoints where marker <= x && marker > checkpoint {
        checkpoint = marker
      }
    }
    if x >= stage.length {
      x = stage.length
      phase = .cleared
    }
  }

  static func intersects(
    x: Double, bottom: Double, halfWidth: Double, height: Double, obstacle: Obstacle
  ) -> Bool {
    guard bottom < obstacle.height && bottom + height > 0 else { return false }
    if obstacle.kind == .block {
      return x + halfWidth > obstacle.x && x - halfWidth < obstacle.x + obstacle.width
    }
    let left = max(x - halfWidth, obstacle.x)
    let right = min(x + halfWidth, obstacle.x + obstacle.width)
    guard left < right else { return false }
    let apex = obstacle.x + obstacle.width / 2
    let closest = max(left, min(apex, right))
    let roof = obstacle.height * (1 - abs(closest - apex) / (obstacle.width / 2))
    return bottom < roof
  }
}
