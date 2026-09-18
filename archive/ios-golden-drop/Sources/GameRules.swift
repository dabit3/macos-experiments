import Foundation

struct Vector: Equatable {
  var x: Double
  var y: Double
  static func + (lhs: Self, rhs: Self) -> Self { .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
  static func * (lhs: Self, rhs: Double) -> Self { .init(x: lhs.x * rhs, y: lhs.y * rhs) }
}

enum PegKind: String {
  case gold, blue, green
  var points: Int {
    switch self {
    case .gold: 100
    case .blue: 20
    case .green: 150
    }
  }
}

struct Peg: Identifiable {
  let id: Int
  var position: Vector
  var kind: PegKind
  var hit = false
  let radius: Double = 10
}

struct Board: Identifiable {
  let id: Int
  let name: String
  let subtitle: String
  let symbol: String
  let pegs: [Peg]
  let balls: Int

  static let all: [Board] = (0..<6).map { index in
    var points: [Vector] = []
    switch index {
    case 0:
      for row in 0..<4 {
        for col in 0..<7 {
          points.append(
            .init(
              x: 63 + Double(col) * 44, y: 180 + Double(row) * 62 + sin(Double(col) * .pi / 3) * 17)
          )
        }
      }
    case 1:
      for ring in 0..<2 {
        for i in 0..<14 {
          let angle = Double(i) / 14 * .pi * 2
          points.append(
            .init(
              x: 195 + cos(angle) * Double(78 + ring * 65),
              y: 290 + sin(angle) * Double(78 + ring * 65)))
        }
      }
    case 2:
      for row in 0..<6 {
        for side in [-1.0, 1.0] {
          points.append(.init(x: 195 + side * Double(28 + row * 20), y: Double(150 + row * 45)))
          points.append(.init(x: 195 + side * Double(28 + row * 20), y: Double(177 + row * 45)))
        }
      }
    case 3:
      for i in 0..<28 {
        let angle = Double(i) * 0.47
        let radius = 44 + Double(i) * 3.5
        points.append(.init(x: 195 + cos(angle) * radius, y: 285 + sin(angle) * radius))
      }
    case 4:
      for row in 0..<5 {
        for col in 0..<6 {
          points.append(
            .init(x: 75 + Double(col) * 48, y: 155 + Double(row) * 56 + (col % 2 == 0 ? 0 : 27)))
        }
      }
    default:
      for row in 0..<6 {
        let count = row < 3 ? row + 3 : 8 - row
        for col in 0..<count {
          points.append(
            .init(x: 195 + (Double(col) - Double(count - 1) / 2) * 48, y: 135 + Double(row) * 53))
        }
      }
    }
    let pegs = points.enumerated().map { offset, position in
      Peg(
        id: offset, position: position,
        kind: offset % 9 == 4 ? .green : (offset % 3 == 0 || offset % 7 == 1 ? .gold : .blue))
    }
    return Board(
      id: index,
      name: [
        "Cloud Nine", "Moon Garden", "Wishbone", "Stardust Spiral", "Hanging Gardens",
        "Crown of Dawn",
      ][index],
      subtitle: [
        "A little luck. A lovely beginning.", "Follow the orbit of a falling star.",
        "Two paths, one golden wish.", "A constellation in full bloom.",
        "Find your way through the canopy.", "One last dance above the clouds.",
      ][index],
      symbol: ["cloud.sun", "moon.stars", "sparkles", "hurricane", "leaf", "crown"][index],
      pegs: pegs,
      balls: 14
    )
  }
}

enum PlayPhase: Equatable {
  case aiming, flying, won, lost
}

struct GameEvent {
  enum Kind { case peg, catchBall, multiplier, settled, finale, finished }
  var kind: Kind
  var position: Vector
  var text: String
}

struct GameRules {
  static let width = 390.0
  static let height = 560.0
  static let origin = Vector(x: 195, y: 58)
  let board: Board
  var pegs: [Peg]
  var balls: Int
  var score = 0
  var phase = PlayPhase.aiming
  var ball = origin
  var velocity = Vector(x: 0, y: 0)
  var angle = 0.0
  var time = 0.0
  var shotTime = 0.0
  var shotHits = 0
  var shotScore = 0
  var caught = 0
  var finaleRemaining: Double?
  var trail: [Vector] = []
  var events: [GameEvent] = []
  var remainingGold: Int { pegs.filter { $0.kind == .gold && !$0.hit }.count }
  var goldTotal: Int { board.pegs.filter { $0.kind == .gold }.count }
  var multiplier: Int {
    let progress = Double(goldTotal - remainingGold) / Double(max(1, goldTotal))
    return progress >= 0.8 ? 5 : (progress >= 0.5 ? 3 : 1)
  }
  var bucketX: Double { 195 + sin(time * 0.9) * 133 }
  var stars: Int { phase == .won ? (balls >= 7 ? 3 : (balls >= 3 ? 2 : 1)) : 0 }

  init(board: Board) {
    self.board = board
    pegs = board.pegs
    balls = board.balls
  }

  mutating func aim(at point: Vector) {
    guard phase == .aiming else { return }
    angle = min(1.20, max(-1.20, atan2(point.x - Self.origin.x, max(25, point.y - Self.origin.y))))
  }

  mutating func launch() {
    guard phase == .aiming, balls > 0 else { return }
    balls -= 1
    ball = Self.origin
    velocity = .init(x: sin(angle) * 340, y: cos(angle) * 340)
    shotTime = 0
    shotHits = 0
    shotScore = 0
    trail = []
    phase = .flying
  }

  mutating func step(_ dt: Double) {
    guard phase == .aiming || phase == .flying else { return }
    time += dt
    guard phase == .flying else { return }
    var delta = dt
    if let remaining = finaleRemaining {
      finaleRemaining = remaining - dt
      delta *= 0.2
      if remaining <= 0 {
        score += shotScore * max(0, shotHits - 1) + 2500 + balls * 1000
        phase = .won
        events.append(.init(kind: .finished, position: ball, text: "GOLDEN HOUR"))
        return
      }
    }
    shotTime += dt
    velocity.y += 290 * delta
    ball = ball + velocity * delta
    if ball.x < 20 {
      ball.x = 20
      velocity.x = abs(velocity.x) * 0.88
    }
    if ball.x > 370 {
      ball.x = 370
      velocity.x = -abs(velocity.x) * 0.88
    }
    if ball.y < 74 {
      ball.y = 74
      velocity.y = abs(velocity.y)
    }
    for index in pegs.indices {
      let dx = ball.x - pegs[index].position.x
      let dy = ball.y - pegs[index].position.y
      let distance = sqrt(dx * dx + dy * dy)
      let radius = pegs[index].radius + 6
      guard distance < radius else { continue }
      let nx = distance > 0.001 ? dx / distance : 0
      let ny = distance > 0.001 ? dy / distance : -1
      ball = .init(
        x: pegs[index].position.x + nx * (radius + 0.3),
        y: pegs[index].position.y + ny * (radius + 0.3))
      let dot = velocity.x * nx + velocity.y * ny
      if dot < 0 {
        velocity.x -= 1.65 * dot * nx
        velocity.y -= 1.65 * dot * ny
        if abs(velocity.x) < 18 { velocity.x += dx >= 0 ? 24 : -24 }
      }
      if !pegs[index].hit {
        let previousMultiplier = multiplier
        pegs[index].hit = true
        shotHits += 1
        let points = pegs[index].kind.points * multiplier
        score += points
        shotScore += points
        if pegs[index].kind == .green { balls += 1 }
        events.append(
          .init(
            kind: .peg, position: pegs[index].position,
            text: pegs[index].kind == .green ? "+1 BALL" : "+\(points)"))
        if multiplier > previousMultiplier {
          events.append(
            .init(kind: .multiplier, position: ball, text: "GOLDEN BOOST  ×\(multiplier)"))
        }
        if remainingGold == 0 && finaleRemaining == nil {
          finaleRemaining = 1.8
          events.append(.init(kind: .finale, position: ball, text: "EVERY WISH, GRANTED"))
        }
      }
    }
    let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
    if speed > 650 { velocity = velocity * (650 / speed) }
    trail.append(ball)
    if trail.count > 28 { trail.removeFirst() }
    if ball.y >= 514 && finaleRemaining == nil {
      let isCatch = abs(ball.x - bucketX) < 43
      finishShot(catchBall: isCatch)
    } else if shotTime > 16 && finaleRemaining == nil {
      finishShot(catchBall: false)
    }
  }

  mutating func finishShot(catchBall: Bool) {
    if catchBall {
      balls += 1
      caught += 1
      score += 500
      events.append(
        .init(kind: .catchBall, position: .init(x: bucketX, y: 490), text: "LOVELY CATCH! +1"))
    }
    score += shotScore * max(0, shotHits - 1)
    events.append(
      .init(
        kind: .settled, position: ball,
        text: (shotHits == 0
          ? "A quiet drop · no pegs this time"
          : "\(shotScore.formatted()) pts ×\(shotHits) combo = \((shotScore * shotHits).formatted())")
          + (catchBall ? " · +500 catch" : "")))
    pegs.removeAll { $0.hit }
    phase = balls > 0 ? .aiming : .lost
    if phase == .lost {
      events.append(.init(kind: .finished, position: ball, text: "ANOTHER LITTLE WISH?"))
    }
    trail = []
  }

  func preview() -> [Vector] {
    var point = Self.origin
    var speed = Vector(x: sin(angle) * 340, y: cos(angle) * 340)
    var points: [Vector] = []
    for _ in 0..<44 {
      speed.y += 290 * 0.027
      point = point + speed * 0.027
      if point.x < 20 {
        point.x = 20
        speed.x = abs(speed.x) * 0.88
      }
      if point.x > 370 {
        point.x = 370
        speed.x = -abs(speed.x) * 0.88
      }
      if pegs.contains(where: { hypot($0.position.x - point.x, $0.position.y - point.y) < 17 }) {
        break
      }
      points.append(point)
    }
    return points
  }
}
