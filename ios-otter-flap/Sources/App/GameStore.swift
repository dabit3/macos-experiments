import Combine
import SwiftUI

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var phase: FlapPhase = .ready
    @Published private(set) var score = 0
    @Published private(set) var best = 0
    @Published private(set) var newBest = false
    @Published private(set) var paused = false
    @Published private(set) var showResults = false
    @Published private(set) var soundOn = true
    let sound = SoundEngine()
    lazy var scene = FlapScene(store: self)
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        best = defaults.integer(forKey: "bestScore")
        soundOn = defaults.object(forKey: "soundOn") as? Bool ?? true
        sound.enabled = soundOn
    }

    var medal: Medal? {
        Medal.award(for: score)
    }

    func tap() {
        if paused {
            resume()
            return
        }
        scene.flap()
    }

    func restart() {
        score = 0
        newBest = false
        showResults = false
        paused = false
        scene.reset()
    }

    func toggleSound() {
        soundOn.toggle()
        sound.enabled = soundOn
        defaults.set(soundOn, forKey: "soundOn")
    }

    func pause() {
        guard phase == .playing else { return }
        paused = true
        scene.isPaused = true
    }

    func resume() {
        paused = false
        scene.isPaused = false
    }

    func sync(phase: FlapPhase, score: Int) {
        if self.phase != phase {
            self.phase = phase
        }
        if self.score != score {
            self.score = score
        }
    }

    func handle(_ event: FlapEvent) {
        switch event {
        case .flapped: sound.play(.flap)
        case .scored: sound.play(.score)
        case .crashed: sound.play(.crash)
        case .landed: finish()
        }
    }

    private func finish() {
        sound.play(.splash)
        newBest = score > best
        if newBest {
            best = score
            defaults.set(best, forKey: "bestScore")
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            if phase == .over {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { showResults = true }
            }
        }
    }
}
