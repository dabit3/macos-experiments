import Foundation

struct Lane: Identifiable {
    let id: Int
    let name: String
    let subtitle: String
    let advice: String
    let gates: [Gate]
    let bumper: Bool
    let bronze: Int
    let silver: Int
    let gold: Int

    func medal(score: Int) -> String {
        if score >= gold { return "GOLD" }
        if score >= silver { return "SILVER" }
        if score >= bronze { return "BRONZE" }
        return "NO MEDAL"
    }

    static let all: [Lane] = [
        Lane(
            id: 0, name: "The Arrival", subtitle: "A room for possibility",
            advice: "Aim just beside the front pin. A little curve goes a long way.",
            gates: [], bumper: true, bronze: 12, silver: 28, gold: 45),
        Lane(
            id: 1, name: "Peach Passage", subtitle: "Through the looking glass",
            advice: "Thread the peach arch. The opening is wider than it looks.",
            gates: [Gate(y: 4.2, center: 0, width: 1.25)], bumper: true, bronze: 12, silver: 26, gold: 42),
        Lane(
            id: 2, name: "Velvet Hour", subtitle: "Nothing stays still",
            advice: "The arch drifts. Release when its opening approaches the center.",
            gates: [Gate(y: 4.6, center: 0, width: 1.02, amplitude: 0.5, speed: 0.8)],
            bumper: true, bronze: 10, silver: 24, gold: 40),
        Lane(
            id: 3, name: "Chrome Reverie", subtitle: "Take the scenic route",
            advice: "Bank off the chrome rails, then let the curve bring you home.",
            gates: [Gate(y: 3.2, center: -0.43, width: 0.9)], bumper: true, bronze: 10, silver: 24, gold: 40),
        Lane(
            id: 4, name: "Double Dream", subtitle: "Two doors. One line.",
            advice: "Aim left with a right curve to connect the two offset archways.",
            gates: [
                Gate(y: 3, center: -0.32, width: 0.82),
                Gate(y: 5.5, center: 0.32, width: 0.82),
            ],
            bumper: true, bronze: 10, silver: 22, gold: 38),
        Lane(
            id: 5, name: "Night Swimming", subtitle: "Beyond the silver edge",
            advice: "No bumpers tonight. Keep your line inside the luminous edges.",
            gates: [Gate(y: 4, center: 0, width: 1.05, amplitude: 0.45, speed: 0.7)],
            bumper: false, bronze: 8, silver: 22, gold: 36),
        Lane(
            id: 6, name: "The Pendulum", subtitle: "Find a moment of stillness",
            advice: "Two moving doors. Watch a cycle, then commit to your line.",
            gates: [
                Gate(y: 3.2, center: 0, width: 1.05, amplitude: 0.45, speed: 0.7),
                Gate(y: 5.4, center: 0, width: 1.05, amplitude: -0.45, speed: 0.9),
            ],
            bumper: true, bronze: 8, silver: 22, gold: 36),
        Lane(
            id: 7, name: "Lucid Suite", subtitle: "The corridor at the end of sleep",
            advice: "Begin left, curl right through both arches. Make the dream yours.",
            gates: [
                Gate(y: 3.1, center: -0.32, width: 0.95, amplitude: 0.12, speed: 0.6),
                Gate(y: 5.6, center: 0.32, width: 0.95, amplitude: 0.12, speed: 0.6),
            ],
            bumper: false, bronze: 8, silver: 20, gold: 34),
    ]
}

struct Gate {
    var y: Double
    var center: Double
    var width: Double
    var amplitude = 0.0
    var speed = 0.0

    func opening(at time: Double) -> ClosedRange<Double> {
        let x = center + sin(time * speed) * amplitude
        return (x - width / 2)...(x + width / 2)
    }
}

struct BowlingGame {
    var frames: [[Int]] = [[]]
    let frameCount = 3

    var isComplete: Bool {
        guard frames.count == frameCount else { return false }
        let last = frames[frameCount - 1]
        if last.count < 2 { return false }
        return last[0] == 10 || last[0] + last[1] == 10 ? last.count == 3 : true
    }

    var needsFreshRack: Bool {
        guard let current = frames.last, let pins = current.last else { return true }
        if current.isEmpty { return true }
        if frames.count < frameCount { return false }
        return pins == 10 || (current.count == 2 && current[0] != 10 && current.reduce(0, +) == 10)
    }

    var nextRollCaption: String {
        let current = frames.last ?? []
        if frames.count == frameCount && !current.isEmpty {
            if current[0] == 10 { return "Bonus roll \(current.count) of 2" }
            if current.count == 2 && current.reduce(0, +) == 10 { return "One bonus dream" }
        }
        return current.isEmpty ? "A fresh possibility" : "Make it a spare"
    }

    var score: Int {
        var total = 0
        for (index, frame) in frames.enumerated() {
            if index == frameCount - 1 {
                total += frame.reduce(0, +)
            } else {
                let later = frames.dropFirst(index + 1).flatMap { $0 }
                if frame.first == 10 {
                    total += 10 + later.prefix(2).reduce(0, +)
                } else if frame.count == 2 && frame.reduce(0, +) == 10 {
                    total += 10 + (later.first ?? 0)
                } else {
                    total += frame.reduce(0, +)
                }
            }
        }
        return total
    }

    mutating func roll(_ pins: Int) {
        guard !isComplete else { return }
        let index = frames.count - 1
        let current = frames[index]
        let available: Int
        if current.isEmpty || needsFreshRack { available = 10 } else { available = 10 - (current.last ?? 0) }
        frames[index].append(max(0, min(available, pins)))
        if index < frameCount - 1 && (frames[index][0] == 10 || frames[index].count == 2) {
            frames.append([])
        }
    }

    func symbols(for index: Int) -> String {
        guard index < frames.count, !frames[index].isEmpty else { return "—" }
        let rolls = frames[index]
        return rolls.enumerated().map { i, value in
            let secondRollOnRack = i == 1 || (i == 2 && rolls[0] == 10)
            if secondRollOnRack && rolls[i - 1] != 10 && value + rolls[i - 1] == 10 { return "/" }
            if value == 10 { return "X" }
            return value == 0 ? "–" : String(value)
        }.joined(separator: "  ")
    }
}

struct Pin: Identifiable {
    let id: Int
    var x: Double
    var y: Double
    var vx = 0.0
    var vy = 0.0
    var down = false
    var fall = 0.0
}

struct Ball {
    var x = 0.0
    var y = 0.35
    var vx = 0.0
    var vy = 0.0
    var active = false
}

struct BowlingPhysics {
    static let curveAcceleration = 1.25
    var ball = Ball()
    var pins = rack()
    var curve = 0.0
    var elapsed = 0.0
    var hitGate = false
    var gutter = false
    var trail: [(Double, Double)] = []

    static func rack() -> [Pin] {
        var pins: [Pin] = []
        for row in 0..<4 {
            for column in 0...row {
                pins.append(
                    Pin(
                        id: pins.count, x: (Double(column) - Double(row) / 2) * 0.34,
                        y: 7.25 + Double(row) * 0.30))
            }
        }
        return pins
    }

    mutating func launch(aim: Double, power: Double, curve: Double) {
        ball = Ball(vx: max(-1, min(1, aim)) * 1.7, vy: 3.5 + max(0, min(1, power)) * 3, active: true)
        self.curve = curve
        elapsed = 0
        hitGate = false
        gutter = false
        trail = []
    }

    mutating func step(dt: Double, lane: Lane, time: Double) {
        guard ball.active else { return }
        elapsed += dt
        let oldY = ball.y
        ball.vx += curve * Self.curveAcceleration * dt
        ball.x += ball.vx * dt
        ball.y += ball.vy * dt
        ball.vy *= pow(0.98, dt)
        if abs(ball.x) > 0.86 && !gutter {
            if lane.bumper {
                ball.x = max(-0.86, min(0.86, ball.x))
                ball.vx *= -0.8
            } else {
                gutter = true
            }
        }
        if gutter {
            ball.x = ball.x < 0 ? -1.02 : 1.02
            ball.vx = 0
        }
        for gate in lane.gates where oldY < gate.y && ball.y >= gate.y {
            let opening = gate.opening(at: time)
            if ball.x - 0.13 < opening.lowerBound || ball.x + 0.13 > opening.upperBound {
                hitGate = true
                ball.vy *= -0.3
                ball.vx += ball.x < 0 ? -0.5 : 0.5
            }
        }
        for i in pins.indices {
            let dx = pins[i].x - ball.x
            let dy = pins[i].y - ball.y
            let distance = hypot(dx, dy)
            if !pins[i].down && !gutter && distance < 0.27 && ball.vy > 0 {
                let nx = dx / max(distance, 0.01)
                pins[i].down = true
                pins[i].vx = ball.vx * 0.6 + nx * 2.1
                pins[i].vy = max(1.7, ball.vy * 0.6)
                ball.vx -= nx * 0.22
                ball.vy *= 0.93
            }
        }
        for i in pins.indices {
            for j in pins.indices where j != i && pins[i].down && !pins[j].down {
                let dx = pins[j].x - pins[i].x
                let dy = pins[j].y - pins[i].y
                if hypot(dx, dy) < 0.39 && hypot(pins[i].vx, pins[i].vy) > 0.35 {
                    pins[j].down = true
                    pins[j].vx = pins[i].vx * 0.5 + dx * 3.5
                    pins[j].vy = max(0.65, pins[i].vy * 0.65) + dy * 1.8
                }
            }
        }
        for i in pins.indices where pins[i].down {
            pins[i].x += pins[i].vx * dt
            pins[i].y += pins[i].vy * dt
            pins[i].vx *= pow(0.07, dt)
            pins[i].vy *= pow(0.07, dt)
            pins[i].fall = min(1, pins[i].fall + dt * 2.5)
        }
        trail.append((ball.x, ball.y))
        if trail.count > 22 { trail.removeFirst() }
        if elapsed > 4.2 || ball.y > 10.5 || ball.y < -0.5 { ball.active = false }
    }
}
