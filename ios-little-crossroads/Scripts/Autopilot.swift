// Autopilot: plays the visible Little Crossroads app in the iOS Simulator with
// real mouse clicks on the on-screen D-pad / A button. It reads run state from
// the app's debug telemetry (`-telemetryPort`) and plans hops with the same lane
// maths the game uses. It never modifies the app, its save or its rules.
//
//   swiftc -O Scripts/Autopilot.swift -o /tmp/autopilot
//   /tmp/autopilot --port 47400 --target 100 --minutes 10
//
// Requires the Simulator window to be visible on screen (the driver locates it).

import CoreGraphics
import Darwin
import Foundation

// MARK: - Options

var port: UInt16 = 47400
var target = 100
var minutes = 10.0
var stopAt = Int.max
var dryRun = false
var arguments = Array(CommandLine.arguments.dropFirst())
while !arguments.isEmpty {
    let flag = arguments.removeFirst()
    switch flag {
    case "--port": port = UInt16(arguments.removeFirst()) ?? port
    case "--target": target = Int(arguments.removeFirst()) ?? target
    case "--minutes": minutes = Double(arguments.removeFirst()) ?? minutes
    case "--stop-at": stopAt = Int(arguments.removeFirst()) ?? stopAt
    case "--dry-run": dryRun = true
    default: break
    }
}

func log(_ message: String) {
    let stamp = String(format: "%.1f", Date().timeIntervalSince(launchDate))
    print("[\(stamp)s] \(message)")
    fflush(stdout)
}

let launchDate = Date()

// MARK: - Simulator window and controls

struct Controls {
    let bounds: CGRect

    // Normalised device-screen positions of the HUD controls (portrait iPhone,
    // Simulator window without device bezels). The window title bar is whatever
    // height remains above a screen with the iPhone's 1206x2622 aspect ratio.
    private static let aspect: CGFloat = 2622.0 / 1206.0
    private static let points: [String: CGPoint] = [
        "start": CGPoint(x: 0.496, y: 0.789),
        "retry": CGPoint(x: 0.496, y: 0.569),
        "forward": CGPoint(x: 0.818, y: 0.850),
        "left": CGPoint(x: 0.127, y: 0.850),
        "right": CGPoint(x: 0.397, y: 0.850),
        "backward": CGPoint(x: 0.257, y: 0.917),
        "pause": CGPoint(x: 0.900, y: 0.106),
        "quit": CGPoint(x: 0.702, y: 0.648),
    ]

    static func locate() -> Controls? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        let windows = list.filter {
            ($0[kCGWindowOwnerName as String] as? String) == "Simulator" && ($0[kCGWindowLayer as String] as? Int) == 0
        }
        let rects = windows.compactMap { window -> CGRect? in
            guard let dictionary = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: dictionary) else { return nil }
            return rect
        }
        guard let best = rects.max(by: { $0.width * $0.height < $1.width * $1.height }),
              best.height > 400 else { return nil }
        return Controls(bounds: best)
    }

    func point(_ name: String) -> CGPoint {
        let normalized = Self.points[name]!
        let screenHeight = bounds.width * Self.aspect
        let screen = CGRect(
            x: bounds.minX, y: bounds.maxY - screenHeight,
            width: bounds.width, height: screenHeight
        )
        return CGPoint(x: screen.minX + normalized.x * screen.width, y: screen.minY + normalized.y * screen.height)
    }

    func click(_ name: String) {
        let location = point(name)
        guard !dryRun else { return }
        let down = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: location,
            mouseButton: .left
        )
        let up = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: location,
            mouseButton: .left
        )
        down?.post(tap: .cghidEventTap)
        usleep(12000)
        up?.post(tap: .cghidEventTap)
    }
}

// MARK: - Telemetry

struct LaneInfo {
    let row: Int
    let kind: Character // m = meadow, r = road, w = river
    let speed: Double
    let phase: Double

    var spacing: Double {
        kind == "w" ? 4.2 : 6.4
    }

    var objectLength: Double {
        kind == "w" ? 3.1 : 1.35
    }

    func centers(at time: Double) -> [Double] {
        let offset = (phase + time * speed).truncatingRemainder(dividingBy: spacing)
        return (-3 ... 3).map { Double($0) * spacing + offset }
    }

    /// Slightly stricter than the game so timing jitter never turns into a hit.
    func supports(_ x: Double, at time: Double) -> Bool {
        centers(at: time).contains { abs($0 - x) < objectLength / 2 - 0.12 - 0.14 }
    }

    func collides(_ x: Double, at time: Double) -> Bool {
        centers(at: time).contains { abs($0 - x) < objectLength / 2 + 0.19 + 0.14 }
    }
}

struct Snapshot {
    let time: Double
    let x: Double
    let row: Int
    let furthest: Int
    let hopping: Bool
    let state: Int
    let coins: Int
    let lanes: [Int: LaneInfo]

    init?(_ text: String) {
        let parts = text.split(separator: " ")
        guard parts.count >= 7,
              let time = Double(parts[0]), let x = Double(parts[1]), let row = Int(parts[2]),
              let furthest = Int(parts[3]), let state = Int(parts[5]), let coins = Int(parts[6]) else { return nil }
        self.time = time
        self.x = x
        self.row = row
        self.furthest = furthest
        hopping = parts[4] == "1"
        self.state = state
        self.coins = coins
        var lanes: [Int: LaneInfo] = [:]
        for part in parts.dropFirst(7) {
            let fields = part.split(separator: ":")
            guard fields.count == 4, let row = Int(fields[0]), let kind = fields[1].first,
                  let speed = Double(fields[2]), let phase = Double(fields[3]) else { continue }
            lanes[row] = LaneInfo(row: row, kind: kind, speed: speed, phase: phase)
        }
        self.lanes = lanes
    }
}

final class Receiver {
    private let descriptor: Int32
    private var buffer = [UInt8](repeating: 0, count: 4096)

    init(port: UInt16) {
        descriptor = socket(AF_INET, SOCK_DGRAM, 0)
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        precondition(bound == 0, "could not bind UDP port \(port)")
        let flags = fcntl(descriptor, F_GETFL)
        _ = fcntl(descriptor, F_SETFL, flags | O_NONBLOCK)
    }

    /// Drains the socket and returns the newest datagram, if any.
    func latest() -> Snapshot? {
        var newest: Snapshot?
        while true {
            let count = recv(descriptor, &buffer, buffer.count, 0)
            guard count > 0 else { break }
            if let text = String(bytes: buffer[0 ..< Int(count)], encoding: .utf8), let snapshot = Snapshot(text) {
                newest = snapshot
            }
        }
        return newest
    }
}

// MARK: - Planner (mirrors GameRules.step / move)

enum Move: CaseIterable {
    case forward, left, right, backward, wait

    var control: String? {
        switch self {
        case .forward: "forward"
        case .left: "left"
        case .right: "right"
        case .backward: "backward"
        case .wait: nil
        }
    }
}

struct Sim {
    var time: Double
    var x: Double
    var row: Int
    var furthest: Int
    var hop: (fromX: Double, fromRow: Int, toX: Double, toRow: Int, elapsed: Double)?
    var alive = true
    let lanes: [Int: LaneInfo]

    static let hopDuration = 0.19

    init(_ snapshot: Snapshot) {
        time = snapshot.time
        x = snapshot.x
        row = snapshot.row
        furthest = snapshot.furthest
        lanes = snapshot.lanes
    }

    func lane(_ row: Int) -> LaneInfo {
        lanes[row] ?? LaneInfo(row: row, kind: "m", speed: 0, phase: 0)
    }

    var visibleX: Double {
        guard let hop else { return x }
        return hop.fromX + (hop.toX - hop.fromX) * min(hop.elapsed / Self.hopDuration, 1)
    }

    var visibleRow: Double {
        guard let hop else { return Double(row) }
        return Double(hop.fromRow) + Double(hop.toRow - hop.fromRow) * min(hop.elapsed / Self.hopDuration, 1)
    }

    @discardableResult
    mutating func move(_ move: Move) -> Bool {
        guard alive, hop == nil, move != .wait else { return move == .wait }
        var nextX = x
        var nextRow = row
        switch move {
        case .forward: nextRow += 1
        case .backward: nextRow -= 1
        case .left: nextX -= 1
        case .right: nextX += 1
        case .wait: break
        }
        guard abs(nextX) <= 3.3, nextRow >= max(0, furthest - 5) else { return false }
        hop = (x, row, nextX, nextRow, 0)
        return true
    }

    mutating func advance(_ duration: Double) {
        var remaining = duration
        while remaining > 0, alive {
            let dt = min(remaining, 1.0 / 120)
            remaining -= dt
            step(dt)
        }
    }

    private mutating func step(_ dt: Double) {
        time += dt
        if var current = hop {
            current.elapsed += dt
            hop = current
            if current.elapsed >= Self.hopDuration {
                x = current.toX
                row = current.toRow
                hop = nil
            }
        } else if lane(row).kind == "w" {
            x += lane(row).speed * dt
        }
        let collisionRow = Int(visibleRow.rounded())
        let current = lane(collisionRow)
        if current.kind == "r", abs(visibleRow - Double(collisionRow)) < 0.38, current.collides(visibleX, at: time) {
            alive = false
            return
        }
        if hop == nil {
            if abs(x) > 3.2 {
                alive = false
            } else if current.kind == "w", !current.supports(x, at: time) {
                alive = false
            } else {
                furthest = max(furthest, row)
            }
        }
    }
}

struct Planner {
    /// Input latency: click issued -> game registers the hop.
    var latency = 0.10
    /// Time the driver needs after a hop lands before its next click registers.
    var reaction = 0.16
    /// How long the duck must remain safe after the final planned hop.
    var horizon = 0.55

    func choose(_ snapshot: Snapshot) -> Move? {
        var bestMove: Move?
        var bestScore = -Double.infinity
        for first in Move.allCases {
            var sim = Sim(snapshot)
            sim.advance(latency)
            if first == .wait {
                sim.advance(reaction)
            } else {
                guard sim.move(first) else { continue }
                sim.advance(Sim.hopDuration + reaction)
            }
            guard sim.alive else { continue }
            var followUp = -Double.infinity
            for second in Move.allCases {
                var next = sim
                if second == .wait {
                    next.advance(horizon)
                } else {
                    guard next.move(second) else { continue }
                    next.advance(Sim.hopDuration + horizon)
                }
                guard next.alive else { continue }
                var third = -Double.infinity
                for last in Move.allCases {
                    var tail = next
                    if last == .wait {
                        tail.advance(horizon)
                    } else {
                        guard tail.move(last) else { continue }
                        tail.advance(Sim.hopDuration + horizon * 0.6)
                    }
                    guard tail.alive else { continue }
                    third = max(third, value(tail, from: snapshot))
                }
                guard third > -Double.infinity else { continue }
                followUp = max(followUp, value(next, from: snapshot) * 0.5 + third)
            }
            guard followUp > -Double.infinity else { continue }
            let score = value(sim, from: snapshot) + followUp + (first == .forward ? 0.5 : 0) -
                (first == .backward ? 1.5 : 0)
            if score > bestScore {
                bestScore = score
                bestMove = first
            }
        }
        return bestMove
    }

    private func value(_ sim: Sim, from snapshot: Snapshot) -> Double {
        var score = Double(sim.row - snapshot.row) * 10
        score -= abs(sim.x) * 0.6
        if sim.lane(sim.row).kind == "r" {
            score -= 2
        }
        if sim.lane(sim.row).kind == "w" {
            score -= 1 + abs(sim.x) * 0.8
        }
        return score
    }
}

// MARK: - Main loop

guard let controls = Controls.locate() else {
    log("Simulator window not found; make sure the device window is visible.")
    exit(1)
}

log("Simulator window: \(controls.bounds)")
let receiver = Receiver(port: port)
let planner = Planner()
var lastClick = Date.distantPast
var lastReport = 0
var runs = 0
var bestRun = 0
var previousState = -1
var lastMoveTime = Date()
let deadline = launchDate.addingTimeInterval(minutes * 60)

log("Waiting for telemetry on udp/\(port); target \(target) hops, budget \(Int(minutes)) min.")
while Date() < deadline {
    guard let snapshot = receiver.latest() else {
        usleep(3000)
        continue
    }
    let now = Date()
    if snapshot.state != previousState {
        if snapshot.state == 1 {
            runs += 1
            lastReport = 0
            log("Run \(runs) started")
        }
        if snapshot.state == 3 {
            bestRun = max(bestRun, snapshot.furthest)
            log("Run \(runs) ended at \(snapshot.furthest) hops, coins \(snapshot.coins); best this session \(bestRun)")
        }
        previousState = snapshot.state
    }
    switch snapshot.state {
    case 0: // title
        if now.timeIntervalSince(lastClick) > 1.2 {
            log("Pressing START")
            controls.click("start")
            lastClick = now
        }
    case 3: // results
        if snapshot.furthest >= target {
            log("Target reached: \(snapshot.furthest) hops. Leaving the results screen up.")
            exit(0)
        }
        if now.timeIntervalSince(lastClick) > 1.6 {
            log("Pressing RETRY")
            controls.click("retry")
            lastClick = now
        }
    case 1: // playing
        if snapshot.furthest >= target, lastReport < target {
            log("Target reached mid-run: \(snapshot.furthest) hops")
        }
        if snapshot.furthest / 10 > lastReport / 10 {
            log("Progress: \(snapshot.furthest) hops, x \(String(format: "%.2f", snapshot.x))")
        }
        lastReport = max(lastReport, snapshot.furthest)
        if snapshot.furthest >= stopAt {
            if now.timeIntervalSince(lastClick) > 0.8 {
                log("Stop line \(stopAt) reached at \(snapshot.furthest); pausing to end the run")
                controls.click("pause")
                lastClick = now
            }
            break
        }
        guard !snapshot.hopping, now.timeIntervalSince(lastClick) > 0.05 else { break }
        if let move = planner.choose(snapshot), let control = move.control {
            controls.click(control)
            lastClick = now
            lastMoveTime = now
        } else if planner.choose(snapshot) == nil, now.timeIntervalSince(lastClick) > 0.3 {
            // No survivable plan found; forward is the best gamble.
            log("No safe plan at row \(snapshot.row); hopping forward anyway")
            controls.click("forward")
            lastClick = now
        }
    case 2: // paused at the stop line
        if snapshot.furthest >= stopAt, now.timeIntervalSince(lastClick) > 0.8 {
            log("Pressing QUIT to bank the score")
            controls.click("quit")
            lastClick = now
        }
    default:
        break
    }
    usleep(4000)
}

log("Time budget elapsed. Best run this session: \(bestRun) hops.")
