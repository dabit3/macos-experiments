import Foundation

enum GameMode: String, Codable {
    case match, challenge
}

enum BallGroup: String, Codable {
    case solids = "Solids"
    case stripes = "Stripes"
    var opposite: BallGroup { self == .solids ? .stripes : .solids }
    func contains(_ id: Int) -> Bool {
        self == .solids ? (1...7).contains(id) : (9...15).contains(id)
    }
    static func of(_ id: Int) -> BallGroup? {
        if (1...7).contains(id) { return .solids }
        if (9...15).contains(id) { return .stripes }
        return nil
    }
}

struct ShotPlan {
    var angle: Double
    var power: Double
    var pocket: Int
    var target: Int
    var quality: Double
}

struct GameEngine {
    var table = Table()
    let mode: GameMode
    var turn = 0
    var humanGroup: BallGroup?
    var isBreak = true
    var ballInHand = false
    var kitchen = false
    var shooting = false
    var finished = false
    var humanWon = false
    var resultTitle = ""
    var resultDetail = ""
    var status = "Your break"
    var detail = "Aim at the rack, then pull the cue back hard."
    var score = 0
    var pots = 0
    var shots = 0
    var streak = 0
    var longestStreak = 0
    var secondsRemaining = 180.0
    var calledPocket: Int?
    var legalAtStart: Set<Int> = []
    var shotClock = 0.0
    var rackNumber = 1
    var lastPots: [Int] = []

    init(mode: GameMode) {
        self.mode = mode
        if mode == .challenge {
            status = "3:00 on the clock"
            detail = "Pot in a row to build a streak multiplier."
        }
    }

    func group(for player: Int) -> BallGroup? {
        guard let humanGroup else { return nil }
        return player == 0 ? humanGroup : humanGroup.opposite
    }

    func remaining(for player: Int) -> [Int] {
        guard let group = group(for: player) else { return [] }
        return table.balls.filter { !$0.pocketed && group.contains($0.id) }.map(\.id).sorted()
    }

    var legalTargets: Set<Int> {
        if mode == .challenge { return Set(table.balls.filter { !$0.pocketed && $0.id != 0 }.map(\.id)) }
        guard let group = group(for: turn) else {
            return Set(table.balls.filter { !$0.pocketed && $0.id != 0 && $0.id != 8 }.map(\.id))
        }
        let targets = table.balls.filter { !$0.pocketed && group.contains($0.id) }.map(\.id)
        return targets.isEmpty ? [8] : Set(targets)
    }

    var requiresCall: Bool { mode == .match && legalTargets == [8] }
    var canShoot: Bool {
        !finished && !shooting && !ballInHand && (!requiresCall || calledPocket != nil)
    }

    mutating func shoot(angle: Double, power: Double, spin: Double = 0) {
        guard canShoot else { return }
        legalAtStart = legalTargets
        shooting = true
        shotClock = 0
        shots += 1
        lastPots = []
        status = turn == 0 ? "Rolling" : "Avery shoots"
        detail = "Wait for the balls to stop."
        table.shoot(angle: angle, power: power, spin: spin)
    }

    mutating func tick(_ dt: Double) {
        guard !finished else { return }
        if mode == .challenge {
            secondsRemaining = max(0, secondsRemaining - dt)
        }
        if shooting {
            shotClock += dt
            let steps = max(1, Int(ceil(dt / (1.0 / 240.0))))
            for _ in 0..<steps { table.step(dt / Double(steps)) }
            if !table.moving {
                resolveShot()
            }
        }
        if mode == .challenge && secondsRemaining <= 0 && !shooting {
            finished = true
            resultTitle = "Time’s up"
            resultDetail = "\(pots) balls potted · \(shots) shots · best streak \(longestStreak)"
        }
    }

    mutating func resolveShot() {
        shooting = false
        let events = table.events
        lastPots = events.pots.map(\.ball).filter { $0 != 0 }
        if mode == .challenge {
            if events.scratch {
                score = max(0, score - 50)
                streak = 0
                ballInHand = true
                kitchen = false
                status = "Scratch · −50"
                detail = "Drag the cue ball anywhere, then shoot."
                restoreCue()
            } else if !lastPots.isEmpty {
                streak += 1
                longestStreak = max(longestStreak, streak)
                let earned = lastPots.count * 100 * min(streak, 5)
                score += earned
                status = "+\(earned) · \(streak > 1 ? "\(min(streak, 5))× streak" : "Nice pot")"
                detail = "Pot again to build your streak."
            } else {
                streak = 0
                status = "Missed · streak reset"
                detail = "Drag on the table to aim."
            }
            pots += lastPots.count
            isBreak = false
            if table.balls.filter({ !$0.pocketed && $0.id != 0 }).isEmpty && secondsRemaining > 0 {
                rackNumber += 1
                table.rack()
                score += 500
                status = "Rack cleared · +500"
                detail = "Fresh rack. Keep going."
                ballInHand = false
                isBreak = true
            }
            return
        }

        let correctFirst = events.firstContact.map { legalAtStart.contains($0) } ?? false
        let objectPotted = !lastPots.isEmpty
        let legalBreak = objectPotted || events.railBalls.filter { $0 != 0 }.count >= 4
        let foul =
            events.scratch || !correctFirst
            || (!objectPotted && !events.railAfterContact) || (isBreak && !legalBreak)

        if lastPots.contains(8) && !isBreak {
            let eightPocket = events.pots.first { $0.ball == 8 }?.pocket
            let legalWin = legalAtStart == [8] && !foul && eightPocket == calledPocket
            finished = true
            humanWon = legalWin ? turn == 0 : turn != 0
            resultTitle = humanWon ? "You win" : "Avery wins"
            resultDetail =
                legalWin
                ? "\(turn == 0 ? "You" : "Avery") cleared the group and called the eight."
                : "The eight fell \(events.scratch ? "with a scratch" : "before a legal called finish")."
            return
        }
        if isBreak && lastPots.contains(8) { table.respot(8) }
        if foul {
            turn = 1 - turn
            ballInHand = true
            kitchen = isBreak
            restoreCue()
            status = events.scratch ? "Scratch · ball in hand" : "Foul · ball in hand"
            if events.scratch {
                detail =
                    "\(turn == 0 ? "Drag the cue ball to place it" : "Avery places the cue ball")\(kitchen ? " behind the head string" : "")."
            } else if !correctFirst {
                detail = "Hit your own group first. \(turn == 0 ? "Your" : "Avery’s") turn."
            } else {
                detail =
                    isBreak
                    ? "A break needs a pot or four object balls to a rail."
                    : "After contact, a ball must reach a rail or pocket."
            }
        } else {
            if !isBreak && humanGroup == nil,
                let assigned = lastPots.compactMap(BallGroup.of).first
            {
                humanGroup = turn == 0 ? assigned : assigned.opposite
            }
            let keepTurn =
                isBreak
                ? objectPotted
                : lastPots.contains { group(for: turn)?.contains($0) ?? false }
            if !keepTurn { turn = 1 - turn }
            status = turn == 0 ? "Your shot" : "Avery’s shot"
            detail =
                group(for: turn).map { "\($0.rawValue) · \(remaining(for: turn).count) remaining" }
                ?? "Open table · pot any ball to claim a group"
        }
        isBreak = false
        calledPocket = nil
        if requiresCall {
            detail =
                turn == 0 ? "Tap a pocket to call the 8-ball." : "Avery is calling a pocket."
        }
    }

    mutating func restoreCue() {
        for x in stride(from: 130.0, through: 25.0, by: -20) {
            for y in stride(from: 150.0, through: 270.0, by: 20) {
                let point = Vector(x: x, y: y)
                if table.canPlace(point, kitchen: kitchen) {
                    table.placeCue(point)
                    return
                }
            }
        }
        for x in stride(from: 22.0, through: 578.0, by: 19) {
            for y in stride(from: 22.0, through: 278.0, by: 19) {
                let point = Vector(x: x, y: y)
                if table.canPlace(point, kitchen: kitchen) {
                    table.placeCue(point)
                    return
                }
            }
        }
    }

    func bestShot() -> ShotPlan {
        if isBreak {
            return ShotPlan(
                angle: (Vector(x: 427, y: 150) - table.cue.position).angle,
                power: 0.96, pocket: 0, target: 1, quality: 1)
        }
        var plans: [ShotPlan] = []
        for ball in table.balls where legalTargets.contains(ball.id) && !ball.pocketed {
            for (pocketIndex, pocket) in Table.pockets.enumerated() {
                let travel = pocket - ball.position
                let ghost = ball.position - travel.unit * (Table.radius * 2 + 0.15)
                guard ghost.x > 9 && ghost.x < 591 && ghost.y > 9 && ghost.y < 291 else { continue }
                let approach = ghost - table.cue.position
                let cut = approach.unit.dot(travel.unit)
                guard cut > 0.22 else { continue }
                let cueClear = table.pathClear(
                    from: table.cue.position, to: ghost, ignoring: [0, ball.id], clearance: 17.2)
                let targetClear = table.pathClear(
                    from: ball.position, to: pocket, ignoring: [0, ball.id], clearance: 17.5)
                guard cueClear && targetClear else { continue }
                let speed = sqrt(2 * 48 * (travel.length + approach.length)) / max(0.5, cut) + 65
                plans.append(
                    ShotPlan(
                        angle: approach.angle, power: min(0.8, max(0.15, (speed - 150) / 880)),
                        pocket: pocketIndex, target: ball.id,
                        quality: cut * 1000 - approach.length * 0.5 - travel.length * 0.6))
            }
        }
        if let plan = plans.max(by: { $0.quality < $1.quality }) { return plan }
        let ball = table.balls.filter { legalTargets.contains($0.id) && !$0.pocketed }.min {
            ($0.position - table.cue.position).length < ($1.position - table.cue.position).length
        }
        return ShotPlan(
            angle: ((ball?.position ?? Vector(x: 450, y: 150)) - table.cue.position).angle,
            power: 0.48, pocket: 2, target: ball?.id ?? 1, quality: -1000)
    }

    mutating func placeAI() {
        var best: (Vector, Double)?
        for x in stride(from: 45.0, through: kitchen ? 145.0 : 550.0, by: 55) {
            for y in stride(from: 40.0, through: 260.0, by: 55) {
                let point = Vector(x: x, y: y)
                guard table.canPlace(point, kitchen: kitchen) else { continue }
                table.placeCue(point)
                let quality = bestShot().quality
                if quality > (best?.1 ?? -Double.infinity) { best = (point, quality) }
            }
        }
        table.placeCue(best?.0 ?? Vector(x: 100, y: 150))
        ballInHand = false
    }
}
