import Foundation

struct Vector: Equatable {
  var x: Double
  var y: Double
  static let zero = Vector(x: 0, y: 0)
  static func + (a: Self, b: Self) -> Self { Self(x: a.x + b.x, y: a.y + b.y) }
  static func - (a: Self, b: Self) -> Self { Self(x: a.x - b.x, y: a.y - b.y) }
  static func * (a: Self, b: Double) -> Self { Self(x: a.x * b, y: a.y * b) }
  var length: Double { hypot(x, y) }
  var unit: Self { length > 0.0001 ? self * (1 / length) : Self(x: 0, y: 1) }
  func dot(_ other: Self) -> Double { x * other.x + y * other.y }
}

struct Rail {
  let a: Vector
  let b: Vector
  func closest(to p: Vector) -> Vector {
    let ab = b - a
    let t = max(0, min(1, (p - a).dot(ab) / max(0.001, ab.dot(ab))))
    return a + ab * t
  }
}

struct ScoreCard: Codable, Equatable {
  var points = 0
  var circuits = 0
  var nextDistrict = 0
  var multiplier = 1
  var districtHits = 0

  mutating func hit(_ district: Int) -> Bool {
    points += 100 * multiplier
    guard district == nextDistrict else { return false }
    points += 250 * multiplier
    districtHits += 1
    nextDistrict += 1
    if nextDistrict == 3 {
      circuits += 1
      points += 1500 * multiplier
      multiplier = min(5, multiplier + 1)
      nextDistrict = 0
      return true
    }
    return false
  }
}

enum TableEvent {
  case bumper(Int, Bool)
  case rail
  case flipper
  case drain
}

final class PinballEngine {
  static let districts = [
    Vector(x: 98, y: 410), Vector(x: 195, y: 488), Vector(x: 292, y: 410),
  ]
  static let rails: [Rail] = [
    Rail(a: Vector(x: 29, y: 170), b: Vector(x: 24, y: 470)),
    Rail(a: Vector(x: 24, y: 470), b: Vector(x: 47, y: 542)),
    Rail(a: Vector(x: 47, y: 542), b: Vector(x: 100, y: 584)),
    Rail(a: Vector(x: 100, y: 584), b: Vector(x: 290, y: 584)),
    Rail(a: Vector(x: 290, y: 584), b: Vector(x: 343, y: 542)),
    Rail(a: Vector(x: 343, y: 542), b: Vector(x: 366, y: 470)),
    Rail(a: Vector(x: 366, y: 470), b: Vector(x: 361, y: 170)),
    Rail(a: Vector(x: 29, y: 170), b: Vector(x: 78, y: 84)),
    Rail(a: Vector(x: 361, y: 170), b: Vector(x: 312, y: 84)),
    Rail(a: Vector(x: 69, y: 255), b: Vector(x: 82, y: 175)),
    Rail(a: Vector(x: 82, y: 175), b: Vector(x: 137, y: 139)),
    Rail(a: Vector(x: 137, y: 139), b: Vector(x: 69, y: 255)),
    Rail(a: Vector(x: 321, y: 255), b: Vector(x: 308, y: 175)),
    Rail(a: Vector(x: 308, y: 175), b: Vector(x: 253, y: 139)),
    Rail(a: Vector(x: 253, y: 139), b: Vector(x: 321, y: 255)),
  ]
  private(set) var ball = Vector(x: 343, y: 220)
  private(set) var velocity = Vector.zero
  private(set) var score = ScoreCard()
  private(set) var ballsUsed = 0
  private(set) var inFlight = false
  private(set) var finished = false
  private(set) var leftLift = 0.0
  private(set) var rightLift = 0.0
  private var clock = 0.0
  private var lastHits = [-10.0, -10.0, -10.0]
  private var lastFlipper = -10.0
  var leftPressed = false
  var rightPressed = false
  var ballsRemaining: Int { max(0, 3 - ballsUsed) }

  static let launchSpeeds = 760.0...920.0

  func launch(power: Double = 1) {
    guard !inFlight, !finished else { return }
    ballsUsed += 1
    ball = Vector(x: 343, y: 220)
    let range = Self.launchSpeeds
    let speed = range.lowerBound + (range.upperBound - range.lowerBound) * min(1, max(0, power))
    velocity = Vector(x: 0, y: speed)
    inFlight = true
  }

  func flipper(left: Bool) -> Rail {
    let lift = left ? leftLift : rightLift
    let pivot = Vector(x: left ? 114 : 276, y: 101)
    let angle = (-24 + lift * 51) * .pi / 180
    let tip = pivot + Vector(x: cos(angle) * (left ? 68 : -68), y: sin(angle) * 68)
    return Rail(a: pivot, b: tip)
  }

  func advance(_ dt: Double) -> [TableEvent] {
    let step = min(max(dt, 0), 1.0 / 30)
    var events: [TableEvent] = []
    for _ in 0..<4 {
      events += substep(step / 4)
    }
    return events
  }

  private func substep(_ dt: Double) -> [TableEvent] {
    clock += dt
    leftLift += (leftPressed ? 1 - leftLift : -leftLift) * min(1, dt * 25)
    rightLift += (rightPressed ? 1 - rightLift : -rightLift) * min(1, dt * 25)
    guard inFlight else { return [] }
    var events: [TableEvent] = []
    velocity.y -= 430 * dt
    velocity = velocity * (1 - 0.045 * dt)
    ball = ball + velocity * dt
    for rail in Self.rails {
      if collide(rail, radius: 9, bounce: 0.83) { events.append(.rail) }
    }
    for (index, center) in Self.districts.enumerated() {
      let delta = ball - center
      if delta.length < 37 {
        let normal = delta.unit
        ball = center + normal * 37
        let speed = velocity.dot(normal)
        if speed < 0 { velocity = velocity - normal * (speed * 1.85) }
        velocity = velocity + normal * 160
        if clock - lastHits[index] > 0.22 {
          lastHits[index] = clock
          events.append(.bumper(index, score.hit(index)))
        }
      }
    }
    for left in [true, false] {
      let rail = flipper(left: left)
      let held = left ? leftPressed : rightPressed
      let lift = left ? leftLift : rightLift
      if collide(rail, radius: 17, bounce: 0.55),
        held, clock - lastFlipper > 0.12
      {
        let distance = min(1, max(0, (ball - rail.a).length / 68))
        let impulse = 580 + 220 * distance + 100 * (1 - lift)
        velocity = Vector(x: (left ? 1 : -1) * (180 + distance * 155), y: impulse)
        lastFlipper = clock
        events.append(.flipper)
      }
    }
    if velocity.length > 1100 { velocity = velocity.unit * 1100 }
    if ball.y < -18 {
      inFlight = false
      finished = ballsUsed == 3
      ball = Vector(x: 343, y: 220)
      velocity = .zero
      leftPressed = false
      rightPressed = false
      events.append(.drain)
    }
    return events
  }

  @discardableResult
  private func collide(_ rail: Rail, radius: Double, bounce: Double) -> Bool {
    let closest = rail.closest(to: ball)
    let delta = ball - closest
    guard delta.length < radius else { return false }
    let normal = delta.unit
    ball = closest + normal * radius
    let speed = velocity.dot(normal)
    guard speed < 0 else { return false }
    velocity = velocity - normal * ((1 + bounce) * speed)
    return true
  }
}
