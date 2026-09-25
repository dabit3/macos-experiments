import AVFoundation
import SwiftUI
import UIKit

@MainActor
final class GameModel: ObservableObject {
    @Published var screen = "home"
    @Published var selectedLane = 0
    @Published var practice = false
    @Published var game = BowlingGame()
    @Published var physics = BowlingPhysics()
    @Published var phase = "ready"
    @Published var paused = false
    @Published var curve = 0.0
    @Published var aim = 0.0
    @Published var power = 0.65
    @Published var dragging = false
    @Published var time = 0.0
    @Published var message = "Find your line"
    @Published var best: [Int]
    @Published var sound: Bool { didSet { defaults.set(sound, forKey: "sound") } }
    @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
    @Published var tutorial: Bool
    private let defaults: UserDefaults
    private var standingBefore = 10
    private var settleTime = 0.0
    private var lastTick: Date?
    private var tonePlayer: AVAudioPlayer?
    var lane: Lane { Lane.all[selectedLane] }
    var unlocked: Int {
        min(7, (0..<8).first(where: { best[$0] < Lane.all[$0].bronze }) ?? 7)
    }
    var medal: String { lane.medal(score: game.score) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.array(forKey: "lane-best") as? [Int] ?? []
        best = (0..<8).map { $0 < stored.count ? stored[$0] : 0 }
        sound = defaults.object(forKey: "sound") as? Bool ?? true
        haptics = defaults.object(forKey: "haptics") as? Bool ?? true
        tutorial = !defaults.bool(forKey: "learned")
    }

    func start(lane: Int, practice: Bool = false) {
        selectedLane = lane
        self.practice = practice
        game = BowlingGame()
        physics = BowlingPhysics()
        phase = "ready"
        paused = false
        curve = 0
        aim = 0
        power = 0.65
        dragging = false
        time = 0
        lastTick = nil
        message = practice ? "Try a little curve" : "Find your line"
        screen = "play"
    }

    func dismissTutorial() {
        tutorial = false
        defaults.set(true, forKey: "learned")
    }

    func launch() {
        guard screen == "play", phase == "ready", !paused, !tutorial else { return }
        standingBefore = physics.pins.filter { !$0.down }.count
        physics.launch(aim: aim, power: power, curve: curve)
        phase = "rolling"
        dragging = false
        message = "Stay in the dream"
        feedback(success: false)
    }

    func tick(_ date: Date, reduceMotion: Bool) {
        let dt = min(1.0 / 30, date.timeIntervalSince(lastTick ?? date))
        lastTick = date
        guard !paused, !tutorial else { return }
        if screen == "home" {
            if !reduceMotion { time += dt }
            return
        }
        guard screen == "play" else { return }
        time += dt
        if phase == "rolling" {
            let before = physics.pins.filter(\.down).count
            let cascadeSpeed = physics.ball.y > 6.8 && !reduceMotion ? 0.62 : 1.0
            for _ in 0..<3 { physics.step(dt: dt / 3 * cascadeSpeed, lane: lane, time: time) }
            if physics.pins.filter(\.down).count > before { feedback(success: true) }
            if !physics.ball.active {
                phase = "settling"
                settleTime = 0
                let count = standingBefore - physics.pins.filter { !$0.down }.count
                message = count == 10 ? "STRIKE" : (count == standingBefore ? "SPARE" : "\(count) PINS")
                if count == 0 { message = physics.hitGate ? "ARCH CLOSED" : "A WAKING MOMENT" }
            }
        } else if phase == "settling" {
            settleTime += dt
            if settleTime > (reduceMotion ? 0.7 : 1.5) { finishRoll() }
        }
    }

    func finishRoll() {
        let count = standingBefore - physics.pins.filter { !$0.down }.count
        game.roll(count)
        if game.isComplete {
            if !practice {
                best[selectedLane] = max(best[selectedLane], game.score)
                defaults.set(best, forKey: "lane-best")
            }
            screen = "result"
            phase = "ready"
            feedback(success: true)
            return
        }
        if game.frames.last?.isEmpty == true || game.needsFreshRack {
            physics = BowlingPhysics()
        } else {
            physics.pins.removeAll { $0.down }
            physics.ball = Ball()
            physics.trail = []
        }
        phase = "ready"
        aim = 0
        message = game.nextRollCaption
    }

    func feedback(success: Bool) {
        if haptics { UIImpactFeedbackGenerator(style: success ? .light : .soft).impactOccurred() }
        guard sound else { return }
        let sampleRate = 22050
        let samples = Int(Double(sampleRate) * (success ? 0.14 : 0.1))
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + samples * 2))
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: "data".utf8)
        append(UInt32(samples * 2))
        for i in 0..<samples {
            let t = Double(i) / Double(sampleRate)
            let envelope = pow(1 - Double(i) / Double(samples), 2)
            let wave = sin(t * .pi * 2 * (success ? 660 : 220))
            append(Int16(wave * envelope * 4200))
        }
        tonePlayer = try? AVAudioPlayer(data: data)
        tonePlayer?.play()
    }
}
