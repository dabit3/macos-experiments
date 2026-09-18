import AudioToolbox
import Combine
import Foundation
import UIKit

struct MatchRecord: Codable {
    var played = 0
    var wins = 0
    var bestDifference: Int?
    var lastBlue = 0
    var lastOrange = 0
    mutating func record(blue: Int, orange: Int) {
        played += 1
        if blue > orange {
            wins += 1
        }
        bestDifference = max(bestDifference ?? (blue - orange), blue - orange)
        lastBlue = blue
        lastOrange = orange
    }
}

final class GameStore: ObservableObject {
    @Published var engine = MatchEngine()
    @Published var screen = Screen.title
    @Published var showHelp = false
    @Published var sound = UserDefaults.standard.object(forKey: "derby.sound") as? Bool ?? true
    @Published var record: MatchRecord
    @Published var reducedMotion = false
    private let defaults: UserDefaults
    private var previousPhase = MatchPhase.ready
    private var previousImpact = 0
    enum Screen { case title, match, results }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "derby.record"),
           let saved = try? JSONDecoder().decode(MatchRecord.self, from: data)
        {
            record = saved
        } else {
            record = MatchRecord()
        }
        if CommandLine.arguments.contains("-autostart") {
            start()
        }
        if let index = CommandLine.arguments.firstIndex(of: "-preview"),
           index + 1 < CommandLine.arguments.count
        {
            preview(CommandLine.arguments[index + 1])
        }
    }

    /// UI-only preview hooks for screenshots; match rules are untouched.
    private func preview(_ name: String) {
        switch name {
        case "help": showHelp = true
        case "pause": start(); pause()
        case "results": screen = .results
        default: break
        }
    }

    func start() {
        engine.start()
        previousPhase = .kickoff
        previousImpact = 0
        screen = .match
    }

    func tick(_ dt: Double) {
        guard screen == .match else { return }
        engine.step(dt)
        if engine.impactSerial != previousImpact {
            previousImpact = engine.impactSerial
            if sound {
                AudioServicesPlaySystemSound(1104)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        }
        if engine.phase != previousPhase {
            previousPhase = engine.phase
            if engine.phase == .goal {
                if sound {
                    AudioServicesPlaySystemSound(1025)
                }
                UINotificationFeedbackGenerator().notificationOccurred(engine.lastScorerIsPlayer ? .success : .warning)
            }
            if engine.phase == .finished {
                record.record(blue: engine.playerGoals, orange: engine.opponentGoals)
                if let data = try? JSONEncoder().encode(record) {
                    defaults.set(data, forKey: "derby.record")
                }
                screen = .results
            }
        }
    }

    func pause() {
        guard screen == .match else { return }
        engine.paused = true
        engine.clearInput()
    }

    func resume() {
        engine.paused = false
    }

    func home() {
        engine.clearInput()
        screen = .title
    }

    func toggleSound() {
        sound.toggle()
        defaults.set(sound, forKey: "derby.sound")
    }
}
