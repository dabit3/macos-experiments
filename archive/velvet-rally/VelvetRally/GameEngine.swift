import Foundation

enum Difficulty: String, Codable, CaseIterable, Identifiable {
  case easy, club, pro
  var id: String { rawValue }
  var title: String {
    switch self {
    case .easy: "Leisure"
    case .club: "Club"
    case .pro: "Pro"
    }
  }
  var subtitle: String {
    switch self {
    case .easy: "Find your rhythm"
    case .club: "A worthy opponent"
    case .pro: "Earn every point"
    }
  }
  var ballSpeed: Double {
    switch self {
    case .easy: 0.48
    case .club: 0.62
    case .pro: 0.76
    }
  }
  var aiSpeed: Double {
    switch self {
    case .easy: 0.24
    case .club: 0.39
    case .pro: 0.53
    }
  }
  var paddleWidth: Double {
    switch self {
    case .easy: 0.25
    case .club: 0.22
    case .pro: 0.19
    }
  }
}

enum Court: String, Codable, CaseIterable, Identifiable {
  case aubergine, clay
  var id: String { rawValue }
  var title: String { rawValue.capitalized }
  var caption: String {
    self == .aubergine ? "After hours. Under the lights." : "Warm earth. Golden hour."
  }
}

struct MatchSettings: Codable, Equatable {
  var court: Court = .aubergine
  var difficulty: Difficulty = .easy
  var target = 7
  var haptics = true
}

struct MatchRecord: Codable, Identifiable {
  let id: UUID
  let date: Date
  let playerScore: Int
  let opponentScore: Int
  let bestRally: Int
  let returns: Int
  let difficulty: Difficulty
  let court: Court
  let target: Int
  var won: Bool { playerScore > opponentScore }
}

struct BallPoint: Equatable {
  var x: Double
  var y: Double
}

struct GameEngine {
  enum Phase: Equatable {
    case ready, playing, paused, point, finished
  }
  enum Event: Equatable {
    case none, paddle, wall, playerPoint, opponentPoint
  }

  let settings: MatchSettings
  private(set) var phase: Phase = .ready
  var ball = BallPoint(x: 0.5, y: 0.62)
  var velocity = BallPoint(x: 0, y: 0)
  private(set) var playerX = 0.5
  private(set) var opponentX = 0.5
  private(set) var playerScore = 0
  private(set) var opponentScore = 0
  private(set) var rally = 0
  private(set) var bestRally = 0
  private(set) var returns = 0
  private(set) var lastPointWasPlayer = false
  private(set) var trail: [BallPoint] = []
  private var previousPhase: Phase = .ready
  private var elapsed = 0.0
  private var aiTarget = 0.5
  private var reaction = 0.0
  static let radius = 0.019
  static let nearY = 0.88
  static let farY = 0.12
  var target: Int { settings.target == 3 ? 3 : 7 }
  var paddleWidth: Double { settings.difficulty.paddleWidth }

  init(settings: MatchSettings) {
    self.settings = settings
  }

  mutating func movePlayer(to x: Double) {
    guard phase != .paused, phase != .finished, x.isFinite else { return }
    playerX = min(1 - paddleWidth / 2, max(paddleWidth / 2, x))
    if phase == .ready || phase == .point {
      ball.x = playerX
    }
  }

  mutating func serve() {
    guard phase == .ready || phase == .point else { return }
    ball = BallPoint(x: playerX, y: Self.nearY - 0.06)
    let direction = (playerScore + opponentScore) % 2 == 0 ? 1.0 : -1.0
    velocity = BallPoint(x: direction * 0.12, y: -settings.difficulty.ballSpeed)
    rally = 0
    trail = []
    phase = .playing
    reaction = 0
  }

  mutating func pause() {
    guard phase != .paused, phase != .finished else { return }
    previousPhase = phase
    phase = .paused
  }

  mutating func resume() {
    guard phase == .paused else { return }
    phase = previousPhase
  }

  mutating func tick(delta: Double) -> Event {
    guard phase == .playing, delta > 0, delta.isFinite else { return .none }
    let dt = min(delta, 1.0 / 30)
    elapsed += dt
    reaction -= dt
    if reaction <= 0 {
      // The opponent reacts to the current ball, never its future landing point.
      aiTarget = velocity.y < 0 ? ball.x + sin(elapsed * 2.3) * 0.065 : 0.5
      reaction = settings.difficulty == .easy ? 0.22 : 0.13
    }
    let step = settings.difficulty.aiSpeed * dt
    opponentX += min(step, max(-step, aiTarget - opponentX))
    opponentX = min(0.91, max(0.09, opponentX))
    let old = ball
    ball.x += velocity.x * dt
    ball.y += velocity.y * dt
    trail.append(ball)
    if trail.count > 9 { trail.removeFirst() }
    var event: Event = .none
    if ball.x < Self.radius {
      ball.x = 2 * Self.radius - ball.x
      velocity.x = abs(velocity.x)
      event = .wall
    } else if ball.x > 1 - Self.radius {
      ball.x = 2 * (1 - Self.radius) - ball.x
      velocity.x = -abs(velocity.x)
      event = .wall
    }
    let near = Self.nearY - Self.radius
    let far = Self.farY + Self.radius
    if velocity.y > 0 && old.y <= near && ball.y >= near {
      let fraction = (near - old.y) / (ball.y - old.y)
      let hitX = old.x + (ball.x - old.x) * fraction
      if abs(hitX - playerX) <= paddleWidth / 2 + Self.radius {
        ball.y = near
        bounce(offset: (hitX - playerX) / (paddleWidth / 2), towardPlayer: false)
        returns += 1
        event = .paddle
      }
    } else if velocity.y < 0 && old.y >= far && ball.y <= far {
      let fraction = (far - old.y) / (ball.y - old.y)
      let hitX = old.x + (ball.x - old.x) * fraction
      if abs(hitX - opponentX) <= 0.09 + Self.radius {
        ball.y = far
        bounce(offset: (hitX - opponentX) / 0.09, towardPlayer: true)
        event = .paddle
      }
    }
    if ball.y < -0.045 {
      awardPoint(player: true)
      return .playerPoint
    }
    if ball.y > 1.045 {
      awardPoint(player: false)
      return .opponentPoint
    }
    return event
  }

  private mutating func bounce(offset: Double, towardPlayer: Bool) {
    rally += 1
    bestRally = max(bestRally, rally)
    let speed = min(settings.difficulty.ballSpeed + Double(rally) * 0.018, 1.12)
    let angle = min(1, max(-1, offset)) * 0.9
    velocity.x = sin(angle) * speed
    velocity.y = cos(angle) * speed * (towardPlayer ? 1 : -1)
  }

  private mutating func awardPoint(player: Bool) {
    lastPointWasPlayer = player
    if player { playerScore += 1 } else { opponentScore += 1 }
    velocity = BallPoint(x: 0, y: 0)
    trail = []
    phase = max(playerScore, opponentScore) >= target ? .finished : .point
    ball = BallPoint(x: playerX, y: Self.nearY - 0.06)
  }

  func record() -> MatchRecord {
    MatchRecord(
      id: UUID(), date: Date(), playerScore: playerScore, opponentScore: opponentScore,
      bestRally: bestRally, returns: returns, difficulty: settings.difficulty,
      court: settings.court, target: target
    )
  }
}
