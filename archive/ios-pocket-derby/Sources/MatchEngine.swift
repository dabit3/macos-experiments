import Foundation

struct Vector: Equatable {
    var x: Double
    var y: Double
    static let zero = Vector(x: 0, y: 0)
    var length: Double {
        hypot(x, y)
    }

    var unit: Vector {
        length > 0.001 ? self / length : .zero
    }

    var angle: Double {
        atan2(y, x)
    }

    static func + (lhs: Vector, rhs: Vector) -> Vector {
        Vector(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: Vector, rhs: Vector) -> Vector {
        Vector(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: Vector, rhs: Double) -> Vector {
        Vector(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    static func / (lhs: Vector, rhs: Double) -> Vector {
        lhs * (1 / rhs)
    }

    func dot(_ other: Vector) -> Double {
        x * other.x + y * other.y
    }
}

struct Car {
    var position: Vector
    var velocity = Vector.zero
    var heading: Double
    var boost = 1.0
}

enum MatchPhase: Equatable {
    case ready, kickoff, playing, goal, finished
}

struct MatchEngine {
    static let halfWidth = 440.0
    static let halfHeight = 175.0
    static let goalHalfHeight = 76.0
    static let ballRadius = 18.0
    static let carRadius = 22.0
    static let cornerRadius = 70.0
    var player = Car(position: Vector(x: -225, y: 0), heading: 0)
    var opponent = Car(position: Vector(x: 225, y: 0), heading: .pi)
    var ball = Vector.zero
    var ballVelocity = Vector.zero
    var playerGoals = 0
    var opponentGoals = 0
    var remaining = 90.0
    var phase = MatchPhase.ready
    var phaseTime = 0.0
    var lastScorerIsPlayer = false
    var paused = false
    var steering = Vector.zero
    var driveTarget: Vector?
    var boostRequested = false
    var impactSerial = 0
    private(set) var brakeRemaining = 0.0
    private var aiClock = 0.0
    private var aiTarget = Vector.zero
    private var burstRemaining = 0.0
    private var aiStuckTime = 0.0
    private var aiRecoveryTime = 0.0
    private var aiRecoveryTarget = Vector.zero

    mutating func start() {
        self = MatchEngine()
        phase = .kickoff
        phaseTime = 2.2
    }

    mutating func burst() {
        if phase == .playing, !paused, player.boost > 0.12 {
            burstRemaining = 0.85
        }
    }

    mutating func clearInput() {
        steering = .zero
        driveTarget = nil
        boostRequested = false
        burstRemaining = 0
    }

    mutating func brake() {
        clearInput()
        brakeRemaining = 0.65
    }

    mutating func step(_ delta: Double) {
        guard !paused, delta > 0, phase != .ready, phase != .finished else { return }
        let dt = min(delta, 1.0 / 60)
        if phase == .kickoff || phase == .goal {
            phaseTime -= dt
            if phaseTime <= 0 {
                if phase == .goal {
                    resetKickoff()
                    phase = .kickoff
                    phaseTime = 1.5
                } else {
                    phase = .playing
                }
            }
            return
        }
        remaining = max(0, remaining - dt)
        if remaining <= 0 {
            phase = .finished
            clearInput()
            return
        }
        burstRemaining = max(0, burstRemaining - dt)
        brakeRemaining = max(0, brakeRemaining - dt)
        var input = steering
        if let target = driveTarget {
            let offset = target - player.position
            input = offset.unit * min(1, offset.length / 65)
            if offset.length < 14 {
                brake()
                input = .zero
            }
        }
        if input.length > 0.1 {
            brakeRemaining = 0
        }
        if brakeRemaining > 0 {
            player.velocity = player.velocity * exp(-9 * dt)
        }
        let boosting = (boostRequested || burstRemaining > 0) && player.boost > 0
        drive(&player, input: input, boosting: boosting, speed: 218, dt: dt)
        aiRecoveryTime = max(0, aiRecoveryTime - dt)
        let pinned = ballVelocity.length < 35 && (ball - opponent.position).length < 85
            && (abs(ball.x) > 355 || abs(ball.y) > 125)
        aiStuckTime = pinned ? aiStuckTime + dt : 0
        if aiStuckTime > 1.1, aiRecoveryTime == 0 {
            aiRecoveryTime = 1.0
            aiStuckTime = 0
            aiRecoveryTarget = opponent.position + (opponent.position - ball).unit * 100
            aiRecoveryTarget.x = min(380, max(-380, aiRecoveryTarget.x))
            aiRecoveryTarget.y = min(110, max(-110, aiRecoveryTarget.y))
        }
        aiClock -= dt
        if aiClock <= 0 {
            aiClock = 0.18
            let predicted = ball + ballVelocity * 0.16
            let shot = (Vector(x: -470, y: 0) - predicted).unit
            aiTarget = predicted - shot * 65
            if opponent.position.x > ball.x + 28,
               abs(opponent.position.y - ball.y) < 62
            {
                aiTarget = predicted + shot * 90
            }
            if opponent.position.x < ball.x - 20 {
                aiTarget.y += opponent.position.y > ball.y ? 85 : -85
            }
            if abs(ball.y) > 120 {
                let inwardY = ball.y > 0 ? -1.0 : 1.0
                aiTarget = predicted + Vector(x: 58, y: inwardY * 45)
                if opponent.position.x > ball.x + 8 {
                    aiTarget = predicted + Vector(x: -80, y: inwardY * 20)
                }
            }
            aiTarget.x = min(410, max(-400, aiTarget.x))
            aiTarget.y = min(145, max(-145, aiTarget.y))
        }
        let aiInput = ((aiRecoveryTime > 0 ? aiRecoveryTarget : aiTarget) - opponent.position).unit
        let aiBoost = opponent.position.x > ball.x + 75 && ball.x < 120
            && abs(opponent.position.y - ball.y) < 35 && opponent.boost > 0.4
        drive(&opponent, input: aiInput, boosting: aiBoost, speed: 184, dt: dt)
        collideCars()
        player = collideBall(with: player)
        opponent = collideBall(with: opponent)
        ball = ball + ballVelocity * dt
        ballVelocity = ballVelocity * pow(0.76, dt)
        if ballVelocity.length > 530 {
            ballVelocity = ballVelocity.unit * 530
        }
        resolveBallWalls()
        if abs(ball.x) > Self.halfWidth + 34,
           abs(ball.y) < Self.goalHalfHeight - Self.ballRadius
        {
            lastScorerIsPlayer = ball.x > 0
            if lastScorerIsPlayer {
                playerGoals += 1
            } else {
                opponentGoals += 1
            }
            phase = .goal
            phaseTime = 2.4
            clearInput()
        }
    }

    private mutating func resetKickoff() {
        let offset = playerGoals + opponentGoals
        player = Car(position: Vector(x: -225, y: offset.isMultiple(of: 2) ? 0 : -48), heading: 0)
        opponent = Car(position: Vector(x: 225, y: offset.isMultiple(of: 2) ? 0 : 48), heading: .pi)
        ball = .zero
        ballVelocity = .zero
        aiClock = 0
        clearInput()
    }

    private func drive(_ car: inout Car, input: Vector, boosting: Bool, speed: Double, dt: Double) {
        if input.length > 0.1 {
            var difference = input.angle - car.heading
            while difference > .pi {
                difference -= 2 * .pi
            }
            while difference < -.pi {
                difference += 2 * .pi
            }
            car.heading += min(4.6 * dt, max(-4.6 * dt, difference))
            let forward = Vector(x: cos(car.heading), y: sin(car.heading))
            let alignment = max(0.22, 1 - abs(difference) / .pi)
            let target = forward * speed * (boosting ? 1.6 : 1) * min(1, input.length) * alignment
            car.velocity = car.velocity + (target - car.velocity) * min(1, dt * 5.8)
        } else {
            car.velocity = car.velocity * pow(0.08, dt)
        }
        car.boost = min(1, max(0, car.boost + (boosting && input.length > 0.1 ? -0.48 : 0.19) * dt))
        car.position = car.position + car.velocity * dt
        let xLimit = Self.halfWidth - Self.carRadius
        let yLimit = Self.halfHeight - Self.carRadius
        if abs(car.position.x) > xLimit {
            car.position.x = car.position.x > 0 ? xLimit : -xLimit
            car.velocity.x *= -0.25
        }
        if abs(car.position.y) > yLimit {
            car.position.y = car.position.y > 0 ? yLimit : -yLimit
            car.velocity.y *= -0.25
        }
        Self.resolveCorner(position: &car.position, velocity: &car.velocity, radius: Self.carRadius, bounce: 0.3)
    }

    private mutating func collideCars() {
        let offset = opponent.position - player.position
        guard offset.length < 44 else { return }
        let normal = offset.length > 0.001 ? offset.unit : Vector(x: 1, y: 0)
        let overlap = (44 - offset.length) / 2
        player.position = player.position - normal * overlap
        opponent.position = opponent.position + normal * overlap
        let speed = (player.velocity - opponent.velocity).dot(normal)
        if speed > 0 {
            player.velocity = player.velocity - normal * speed * 0.72
            opponent.velocity = opponent.velocity + normal * speed * 0.72
        }
    }

    private mutating func collideBall(with car: Car) -> Car {
        var car = car
        let offset = ball - car.position
        let separation = Self.carRadius + Self.ballRadius
        guard offset.length < separation else { return car }
        let normal = offset.length > 0.001 ? offset.unit : Vector(x: cos(car.heading), y: sin(car.heading))
        ball = car.position + normal * separation
        let closingSpeed = (car.velocity - ballVelocity).dot(normal)
        if closingSpeed > 0 {
            ballVelocity = ballVelocity + normal * (closingSpeed * 1.5 + 26)
            car.velocity = car.velocity - normal * closingSpeed * 0.12
            if closingSpeed > 35 {
                impactSerial += 1
            }
        }
        return car
    }

    private mutating func resolveBallWalls() {
        let yLimit = Self.halfHeight - Self.ballRadius
        if abs(ball.y) > yLimit {
            ball.y = ball.y > 0 ? yLimit : -yLimit
            ballVelocity.y *= -0.82
        }
        for side in [-1.0, 1.0] {
            for y in [-Self.goalHalfHeight, Self.goalHalfHeight] {
                let post = Vector(x: side * Self.halfWidth, y: y)
                let offset = ball - post
                if offset.length < Self.ballRadius + 7 {
                    let normal = offset.length > 0.001 ? offset.unit : Vector(x: -side, y: 0)
                    ball = post + normal * (Self.ballRadius + 7)
                    let projection = ballVelocity.dot(normal)
                    if projection < 0 {
                        ballVelocity = ballVelocity - normal * projection * 1.85
                    }
                }
            }
        }
        if abs(ball.x) > Self.halfWidth - Self.ballRadius,
           abs(ball.y) >= Self.goalHalfHeight - Self.ballRadius
        {
            ball.x = ball.x > 0 ? Self.halfWidth - Self.ballRadius : -Self.halfWidth + Self.ballRadius
            ballVelocity.x *= -0.84
        }
        Self.resolveCorner(position: &ball, velocity: &ballVelocity, radius: Self.ballRadius, bounce: 0.88)
    }

    private static func resolveCorner(position: inout Vector, velocity: inout Vector, radius: Double, bounce: Double) {
        let cx = halfWidth - cornerRadius
        let cy = halfHeight - cornerRadius
        guard abs(position.x) > cx, abs(position.y) > cy else { return }
        let center = Vector(x: position.x > 0 ? cx : -cx, y: position.y > 0 ? cy : -cy)
        let offset = position - center
        let limit = cornerRadius - radius
        guard offset.length > limit else { return }
        let normal = offset.unit
        position = center + normal * limit
        let outwardSpeed = velocity.dot(normal)
        if outwardSpeed > 0 {
            velocity = velocity - normal * outwardSpeed * (1 + bounce)
        }
    }
}
