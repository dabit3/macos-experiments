import AudioToolbox
import SwiftUI
import UIKit

enum GameScreen {
    case home, playing, holeResult, courseResult
}

@MainActor
final class GameStore: ObservableObject {
    @Published var screen = GameScreen.home
    @Published var simulation = GolfSimulation(hole: Hole.course[0])
    @Published var aim = Vector.zero
    @Published var practice = false
    @Published var paused = false
    @Published var showSettings = false
    @Published var showPractice = false
    @Published var showTutorial = false
    @Published var message = ""
    @Published var completed: [Bool] = []
    @Published var scores: [Int] = []
    @Published var holeIndex = 0
    @Published var bloom = 0.0
    @Published var best: Int?
    @Published var rounds = 0
    @Published var sound: Bool { didSet { defaults.set(sound, forKey: "moss.sound") } }
    @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "moss.haptics") } }
    @Published var gentle: Bool { didSet { defaults.set(gentle, forKey: "moss.gentle") } }
    @Published var practiceAngle = -90.0
    @Published var practicePower = 83.0
    private let defaults: UserDefaults
    private var messageUntil = 0.0
    private var resultDelay = 0.0
    private var lastFeedback = -1.0
    var hole: Hole { Hole.course[holeIndex] }
    var total: Int { scores.reduce(0, +) }
    var strokeNoun: String { simulation.strokes == 1 ? "stroke" : "strokes" }
    var record: CourseRecord { CourseRecord(strokes: scores, completed: completed) }
    var canShoot: Bool {
        screen == .playing && !paused && !showTutorial && !simulation.moving && !simulation.sunk
            && resultDelay == 0
    }
    var practicePull: Vector {
        let radians = practiceAngle * .pi / 180
        return Vector(x: cos(radians), y: sin(radians)) * practicePower
    }
    var resultTitle: String {
        if !simulation.sunk { return "A wild little detour." }
        let difference = simulation.strokes - hole.par
        if simulation.strokes == 1 { return "A little miracle." }
        if difference < 0 { return "Beautifully played." }
        if difference == 0 { return "Right on par." }
        return "Every stroke grows."
    }
    var resultLabel: String {
        if !simulation.sunk { return "STROKE LIMIT · 8" }
        if simulation.strokes == 1 { return "HOLE IN ONE" }
        let difference = simulation.strokes - hole.par
        return difference == 0 ? "PAR" : difference < 0 ? "BIRDIE" : "+\(difference) OVER PAR"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sound = defaults.object(forKey: "moss.sound") as? Bool ?? false
        haptics = defaults.object(forKey: "moss.haptics") as? Bool ?? true
        gentle = defaults.object(forKey: "moss.gentle") as? Bool ?? true
        best = defaults.object(forKey: "moss.best") as? Int
        rounds = defaults.integer(forKey: "moss.rounds")
    }

    func start(practice index: Int? = nil) {
        practice = index != nil
        scores = []
        completed = []
        holeIndex = index ?? 0
        loadHole()
        showPractice = false
        showTutorial = !defaults.bool(forKey: "moss.tutorial")
    }

    func loadHole() {
        simulation = GolfSimulation(hole: hole, gentle: practice && gentle)
        aim = .zero
        paused = false
        message = ""
        resultDelay = 0
        bloom = 0
        screen = .playing
        resetPracticeAim()
    }

    func resetPracticeAim() {
        let direction = hole.cup - simulation.position
        practiceAngle = atan2(direction.y, direction.x) * 180 / .pi
        practicePower = min(135, direction.length / 3)
    }

    func dismissTutorial() {
        defaults.set(true, forKey: "moss.tutorial")
        showTutorial = false
    }

    func shoot(_ pull: Vector) {
        guard canShoot else { return }
        simulation.shoot(pull: pull)
        aim = .zero
        if simulation.moving { feedback(1104) }
    }

    func tick() {
        guard screen == .playing, !paused, !showTutorial, !showSettings else { return }
        if resultDelay > 0 {
            resultDelay -= 1.0 / 60
            bloom = min(1, bloom + 0.025)
            if resultDelay <= 0 {
                resultDelay = 0
                screen = .holeResult
            }
            return
        }
        let event = simulation.tick(1.0 / 60)
        if simulation.time > messageUntil { message = "" }
        switch event {
        case .splash:
            message = "Pond dip · +1 penalty. Back to your last lie."
            messageUntil = simulation.time + 4
            feedback(1053)
            resetPracticeAim()
        case .sunk:
            feedback(1025)
            resultDelay = 1.2
        case .bounce:
            if simulation.time - lastFeedback > 0.12 {
                feedback(1104)
                lastFeedback = simulation.time
            }
        case .stopped:
            resetPracticeAim()
        case .none:
            break
        }
        if !practice && !simulation.moving && !simulation.sunk && simulation.strokes >= 8 {
            simulation.strokes = 8
            resultDelay = 0.8
        }
    }

    func nextHole() {
        if practice {
            loadHole()
            return
        }
        scores.append(simulation.strokes)
        completed.append(simulation.sunk)
        if holeIndex < 8 {
            holeIndex += 1
            loadHole()
        } else {
            rounds += 1
            defaults.set(rounds, forKey: "moss.rounds")
            if record.finished && (best == nil || total < (best ?? Int.max)) {
                best = total
                defaults.set(total, forKey: "moss.best")
            }
            screen = .courseResult
        }
    }

    func goHome() {
        screen = .home
        paused = false
        aim = .zero
    }

    func feedback(_ soundID: SystemSoundID) {
        if sound { AudioServicesPlaySystemSound(soundID) }
        if haptics {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
}
