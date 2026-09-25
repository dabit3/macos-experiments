import Foundation

struct Vector: Equatable, Codable {
    var x: Double
    var y: Double
    static let zero = Vector(x: 0, y: 0)
    var length: Double { hypot(x, y) }
    var unit: Vector { length > 0 ? self / length : .zero }
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
        Vector(x: lhs.x / rhs, y: lhs.y / rhs)
    }
    func dot(_ other: Vector) -> Double { x * other.x + y * other.y }
}

struct Stone {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    func contains(_ point: Vector) -> Bool {
        point.x > x && point.x < x + width && point.y > y && point.y < y + height
    }
}

struct Mushroom {
    let center: Vector
    let radius: Double
}

struct Hole {
    let number: Int
    let name: String
    let subtitle: String
    let par: Int
    let tee: Vector
    let cup: Vector
    var walls: [Stone] = []
    var water: [Stone] = []
    var mushrooms: [Mushroom] = []
    var lily = false
    var gate = false

    func lilyCenter(at time: Double) -> Vector {
        Vector(x: 180 + sin(time * 0.65) * 76, y: 274)
    }

    func gateStone(at time: Double) -> Stone {
        Stone(x: 112 + sin(time * 0.8) * 67, y: number == 9 ? 191 : 268, width: 116, height: 14)
    }

    static let course: [Hole] = [
        Hole(
            number: 1, name: "Dewdrop", subtitle: "A small beginning.", par: 2,
            tee: Vector(x: 180, y: 423), cup: Vector(x: 180, y: 174)),
        Hole(
            number: 2, name: "Fern bend", subtitle: "Let the old stones guide you.", par: 3,
            tee: Vector(x: 246, y: 430), cup: Vector(x: 255, y: 129),
            walls: [Stone(x: 136, y: 267, width: 179, height: 24)]),
        Hole(
            number: 3, name: "Spore song", subtitle: "A little bounce goes a long way.", par: 3,
            tee: Vector(x: 91, y: 423), cup: Vector(x: 270, y: 141),
            mushrooms: [Mushroom(center: Vector(x: 176, y: 279), radius: 31)]),
        Hole(
            number: 4, name: "Lily ferry", subtitle: "Wait for the garden to meet you.", par: 3,
            tee: Vector(x: 180, y: 421), cup: Vector(x: 180, y: 132),
            water: [Stone(x: 45, y: 240, width: 270, height: 68)], lily: true),
        Hole(
            number: 5, name: "Quiet clock", subtitle: "Every opening has its moment.", par: 3,
            tee: Vector(x: 106, y: 421), cup: Vector(x: 259, y: 133), gate: true),
        Hole(
            number: 6, name: "Mirror pools", subtitle: "Find the ribbon between reflections.", par: 3,
            tee: Vector(x: 260, y: 430), cup: Vector(x: 93, y: 128),
            water: [
                Stone(x: 45, y: 242, width: 98, height: 121),
                Stone(x: 217, y: 151, width: 98, height: 117),
            ]),
        Hole(
            number: 7, name: "The cloister", subtitle: "Patience is a kind of precision.", par: 4,
            tee: Vector(x: 243, y: 429), cup: Vector(x: 95, y: 130),
            walls: [
                Stone(x: 133, y: 310, width: 20, height: 150),
                Stone(x: 211, y: 112, width: 20, height: 150),
            ]),
        Hole(
            number: 8, name: "Velvet bank", subtitle: "Trust the softest-looking obstacle.", par: 3,
            tee: Vector(x: 177, y: 433), cup: Vector(x: 179, y: 121),
            water: [Stone(x: 145, y: 228, width: 71, height: 88)],
            mushrooms: [
                Mushroom(center: Vector(x: 92, y: 269), radius: 26),
                Mushroom(center: Vector(x: 269, y: 213), radius: 29),
            ]),
        Hole(
            number: 9, name: "Bloom court", subtitle: "One last breath. The garden is yours.", par: 4,
            tee: Vector(x: 180, y: 430), cup: Vector(x: 180, y: 123),
            water: [Stone(x: 45, y: 240, width: 270, height: 68)],
            mushrooms: [
                Mushroom(center: Vector(x: 86, y: 165), radius: 21),
                Mushroom(center: Vector(x: 276, y: 365), radius: 22),
            ], lily: true, gate: true),
    ]
    static let totalPar = course.reduce(0) { $0 + $1.par }
}

enum GolfEvent: Equatable {
    case none, bounce, splash, sunk, stopped
}

struct ShotPrediction {
    let points: [Vector]
    let waterHazard: Bool
    let sinks: Bool
}

struct GolfSimulation {
    static let friction = 190.0
    static let ballRadius = 6.0
    let hole: Hole
    var position: Vector
    var velocity = Vector.zero
    var lastLie: Vector
    var time = 0.0
    var strokes = 0
    var sunk = false
    var gentle = false
    var moving: Bool { velocity.length > 0 }

    init(hole: Hole, gentle: Bool = false) {
        self.hole = hole
        self.position = hole.tee
        self.lastLie = hole.tee
        self.gentle = gentle
    }

    mutating func shoot(pull: Vector) {
        guard !moving, !sunk, pull.length >= 5 else { return }
        lastLie = position
        let distance = min(pull.length, 135) * 3
        velocity = pull.unit * sqrt(2 * Self.friction * distance)
        strokes += 1
    }

    mutating func tick(_ delta: Double) -> GolfEvent {
        let bounded = min(max(delta, 0), 0.05)
        let count = max(1, Int(ceil(bounded / (1.0 / 120))))
        var event = GolfEvent.none
        for _ in 0..<count {
            let result = step(bounded / Double(count))
            if result != .none { event = result }
            if result == .splash || result == .sunk { break }
        }
        return event
    }

    private mutating func step(_ dt: Double) -> GolfEvent {
        time += dt
        guard moving, !sunk else { return .none }
        position = position + velocity * dt
        var event = GolfEvent.none
        let radius = Self.ballRadius
        let bounds = (left: 45.0 + radius, right: 315.0 - radius, top: 83.0 + radius, bottom: 475.0 - radius)
        if position.x < bounds.left {
            position.x = bounds.left
            velocity.x = abs(velocity.x) * 0.82
            event = .bounce
        }
        if position.x > bounds.right {
            position.x = bounds.right
            velocity.x = -abs(velocity.x) * 0.82
            event = .bounce
        }
        if position.y < bounds.top {
            position.y = bounds.top
            velocity.y = abs(velocity.y) * 0.82
            event = .bounce
        }
        if position.y > bounds.bottom {
            position.y = bounds.bottom
            velocity.y = -abs(velocity.y) * 0.82
            event = .bounce
        }
        var walls = hole.walls
        if hole.gate { walls.append(hole.gateStone(at: time)) }
        for wall in walls {
            let nearest = Vector(
                x: min(max(position.x, wall.x), wall.x + wall.width),
                y: min(max(position.y, wall.y), wall.y + wall.height))
            let difference = position - nearest
            if difference.length < radius {
                let normal: Vector
                if difference.length > 0.001 {
                    normal = difference.unit
                    position = nearest + normal * radius
                } else {
                    normal = velocity.unit * -1
                    position = position + normal * radius
                }
                if velocity.dot(normal) < 0 {
                    velocity = (velocity - normal * (2 * velocity.dot(normal))) * 0.82
                }
                event = .bounce
            }
        }
        for mushroom in hole.mushrooms {
            let difference = position - mushroom.center
            if difference.length < mushroom.radius + radius {
                let normal = difference.length > 0.001 ? difference.unit : Vector(x: 0, y: 1)
                position = mushroom.center + normal * (mushroom.radius + radius)
                if velocity.dot(normal) < 0 {
                    velocity = (velocity - normal * (2 * velocity.dot(normal))) * 0.94
                }
                event = .bounce
            }
        }
        if hole.water.contains(where: { $0.contains(position) }) {
            let onLily = hole.lily && (position - hole.lilyCenter(at: time)).length <= 48
            if !onLily {
                position = lastLie
                velocity = .zero
                strokes += 1
                return .splash
            }
        }
        let captureRadius = gentle ? 23.0 : 13.0
        if (position - hole.cup).length < captureRadius && velocity.length < 310 {
            position = hole.cup
            velocity = .zero
            sunk = true
            return .sunk
        }
        velocity = velocity.unit * max(0, velocity.length - Self.friction * dt)
        if velocity.length < 7 {
            velocity = .zero
            return .stopped
        }
        return event
    }

    func prediction(pull: Vector) -> ShotPrediction {
        var preview = self
        preview.shoot(pull: pull)
        var points = [position]
        for index in 0..<250 {
            let before = preview.position
            let event = preview.tick(1.0 / 60)
            if event == .splash {
                points.append(before)
                return ShotPrediction(points: points, waterHazard: true, sinks: false)
            }
            if index.isMultiple(of: 5) { points.append(preview.position) }
            if !preview.moving {
                points.append(preview.position)
                break
            }
        }
        return ShotPrediction(points: points, waterHazard: false, sinks: preview.sunk)
    }

    func trajectory(pull: Vector) -> [Vector] {
        prediction(pull: pull).points
    }
}

struct CourseRecord: Codable, Equatable {
    let strokes: [Int]
    let completed: [Bool]
    var total: Int { strokes.reduce(0, +) }
    var finished: Bool { strokes.count == 9 && completed.allSatisfy { $0 } }
    var relative: Int { total - Hole.totalPar }
    var caption: String {
        relative == 0 ? "Even par" : relative < 0 ? "\(abs(relative)) under par" : "\(relative) over par"
    }
}
