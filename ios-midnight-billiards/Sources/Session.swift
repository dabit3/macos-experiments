import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class GameSession: ObservableObject {
    @Published var game: GameEngine?
    @Published var angle = 0.0
    @Published var power = 0.72
    @Published var spin = 0.0
    @Published var paused = false
    @Published var showRules = false
    @Published var showSpin = false
    @Published var pull: Double?
    @Published var lastPower = 0.0
    @Published var soundOn = UserDefaults.standard.object(forKey: "sound") as? Bool ?? true
    @Published var best = UserDefaults.standard.integer(forKey: "bestScore")
    @Published var wins = UserDefaults.standard.integer(forKey: "matchWins")
    @Published var totalPots = UserDefaults.standard.integer(forKey: "totalPots")
    @Published var newBest = false
    private var aiDelay = 0.0
    private var lastTime: Date?
    private var savedResult = false
    private var previousPots = 0
    private var audioCooldown = 0.0
    private let audio = TableAudio()
    let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    func start(_ mode: GameMode) {
        game = GameEngine(mode: mode)
        angle = 0
        power = 0.82
        spin = 0
        pull = nil
        lastPower = 0
        showSpin = false
        paused = false
        aiDelay = 0
        previousPots = 0
        savedResult = false
        newBest = false
        lastTime = nil
    }

    func tick(_ time: Date) {
        defer { lastTime = time }
        guard var engine = game, !paused, !showRules, !engine.finished else { return }
        let dt = min(1.0 / 20.0, max(0, time.timeIntervalSince(lastTime ?? time)))
        audioCooldown = max(0, audioCooldown - dt)
        let wasShooting = engine.shooting
        engine.tick(dt)
        if soundOn && engine.table.collisionEnergy > 45 && audioCooldown <= 0 {
            audio.play(.collision)
            audioCooldown = 0.09
        }
        let newPots = engine.table.events.pots.count
        if newPots > previousPots {
            if soundOn { audio.play(.pot) }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        previousPots = newPots
        if wasShooting && !engine.shooting {
            totalPots += engine.lastPots.count
            UserDefaults.standard.set(totalPots, forKey: "totalPots")
            if engine.turn == 0 {
                angle = engine.bestShot().angle
                if !engine.ballInHand && !engine.requiresCall && !engine.finished && engine.mode == .match {
                    engine.detail = "Suggested line set. Adjust or shoot."
                }
            }
        }
        if engine.mode == .match && engine.turn == 1 && !engine.shooting && !engine.finished {
            aiDelay += dt
            if aiDelay > 0.5 && engine.ballInHand { engine.placeAI() }
            let plan = engine.bestShot()
            angle = plan.angle
            power = plan.power
            if engine.requiresCall { engine.calledPocket = plan.pocket }
            if aiDelay > 1.65 {
                engine.shoot(angle: plan.angle, power: plan.power)
                previousPots = 0
                aiDelay = 0
                if soundOn { audio.play(.cue) }
            }
        } else {
            aiDelay = 0
        }
        if engine.finished && !savedResult {
            savedResult = true
            if engine.mode == .challenge && engine.score > best {
                best = engine.score
                newBest = true
                UserDefaults.standard.set(best, forKey: "bestScore")
            }
            if engine.mode == .match && engine.humanWon {
                wins += 1
                UserDefaults.standard.set(wins, forKey: "matchWins")
            }
        }
        game = engine
    }

    var canAim: Bool {
        guard let engine = game else { return false }
        return engine.turn == 0 && !engine.shooting && !engine.finished && !paused
    }

    var canPull: Bool {
        guard let engine = game, canAim else { return false }
        return !engine.requiresCall || engine.calledPocket != nil
    }

    func strike(_ shotPower: Double) {
        guard canPull, var engine = game else { return }
        if engine.mode == .challenge && engine.secondsRemaining <= 0 { return }
        engine.ballInHand = false
        game = engine
        guard engine.canShoot else { return }
        power = shotPower
        lastPower = shotPower
        showSpin = false
        game?.shoot(angle: angle, power: shotPower, spin: spin)
        previousPots = 0
        if soundOn { audio.play(.cue) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private var placementStart: Vector?

    func touchTable(_ point: Vector, start: Vector) {
        guard var engine = game, canAim else { return }
        showSpin = false
        let placing = placementStart.map { ($0 - start).length < 0.5 } ?? false
        if engine.ballInHand && (placing || (start - engine.table.cue.position).length < 30) {
            placementStart = start
            if engine.table.canPlace(point, kitchen: engine.kitchen) {
                engine.table.placeCue(point)
                game = engine
            }
        } else if engine.requiresCall,
            let pocket = Table.pockets.firstIndex(where: { ($0 - start).length < 35 })
        {
            engine.calledPocket = pocket
            game = engine
        } else {
            angle = (point - engine.table.cue.position).angle
        }
    }

    func toggleSound() {
        soundOn.toggle()
        UserDefaults.standard.set(soundOn, forKey: "sound")
    }

    func setPaused(_ value: Bool) {
        paused = value
        lastTime = nil
    }
}

@MainActor
final class TableAudio {
    enum Tone { case collision, cue, pot }
    private var players: [AVAudioPlayer] = []

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        for frequency in [720.0, 190.0, 390.0] {
            let sampleRate = 22_050.0
            let count = 2_646
            var samples = [Int16]()
            for index in 0..<count {
                let time = Double(index) / sampleRate
                let envelope = exp(-time * (frequency == 390 ? 24 : 65))
                let signal =
                    sin(time * frequency * 2 * .pi)
                    + 0.35 * sin(time * frequency * 4.73 * .pi)
                samples.append(Int16(max(-32767, min(32767, signal * envelope * 11_000))))
            }
            var data = Data()
            func text(_ string: String) { data.append(contentsOf: string.utf8) }
            func word(_ value: UInt32, bytes: Int = 4) {
                for index in 0..<bytes { data.append(UInt8((value >> (index * 8)) & 255)) }
            }
            text("RIFF"); word(UInt32(36 + count * 2)); text("WAVEfmt ")
            word(16); word(1, bytes: 2); word(1, bytes: 2); word(UInt32(sampleRate))
            word(UInt32(sampleRate * 2)); word(2, bytes: 2); word(16, bytes: 2)
            text("data"); word(UInt32(count * 2))
            for sample in samples { word(UInt32(UInt16(bitPattern: sample)), bytes: 2) }
            if let player = try? AVAudioPlayer(data: data) {
                player.prepareToPlay()
                players.append(player)
            }
        }
    }

    func play(_ tone: Tone) {
        let index = tone == .collision ? 0 : tone == .cue ? 1 : 2
        guard players.indices.contains(index) else { return }
        players[index].currentTime = 0
        players[index].volume = 0.5
        players[index].play()
    }
}
