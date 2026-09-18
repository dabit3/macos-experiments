import AVFoundation
import SwiftUI
import UIKit

struct TravelJournal: Codable {
    var best: [Int: Int] = [:]
    var chapter = 0
    var journey: PuzzleState?
    var sound = true
}

@MainActor
final class GameModel: ObservableObject {
    @Published var journal: TravelJournal
    @Published var state: PuzzleState
    @Published var page: Page = .cover
    @Published var paused = false
    @Published var walking = false
    @Published var turning = false
    @Published var movingTo: Int?
    @Published var showingHint = false
    @Published var rejectedTile: Int?
    @Published var feedbackTick = 0
    @Published var focusedMechanism: Int?
    @Published var message = "Tap a landing. Find a different way."
    private var walkTask: Task<Void, Never>?
    private var turnTask: Task<Void, Never>?
    private let tones = PostcardTones()
    private let storageKey = "impossiblePostcards.journal.v1"
    private let defaults: UserDefaults

    enum Page { case cover, collection, game, result }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.data(forKey: storageKey)
        let decoded = saved.flatMap { try? JSONDecoder().decode(TravelJournal.self, from: $0) }
        var journal = decoded ?? TravelJournal()
        if !Chapters.all.indices.contains(journal.chapter) {
            journal.chapter = 0
        }
        self.journal = journal
        let chapter = Chapters.all[journal.chapter]
        state = journal.journey.flatMap { chapter.isValid($0) ? $0 : nil } ?? chapter.initialState
    }

    var chapter: Chapter {
        Chapters.all[journal.chapter]
    }

    var optimum: Int {
        chapter.shortestSolution()?.count ?? 0
    }

    var collected: Int {
        journal.best.count
    }

    var seals: Int {
        state.switches.nonzeroBitCount
    }

    var totalSeals: Int {
        chapter.requiredSwitches.nonzeroBitCount
    }

    var canContinue: Bool {
        journal.journey != nil && !chapter.hasArrived(state)
    }

    func save() {
        journal.journey = state
        if let data = try? JSONEncoder().encode(journal) {
            defaults.set(data, forKey: storageKey)
        }
    }

    func start(_ index: Int, fresh: Bool = true) {
        cancelWalk()
        cancelTurn()
        journal.chapter = index
        if fresh {
            state = chapter.initialState
        }
        paused = false
        showingHint = false
        rejectedTile = nil
        focusedMechanism = nil
        message = "Tap a landing to walk. Turn a bridge to connect it."
        page = chapter.hasArrived(state) ? .result : .game
        save()
    }

    func walk(to tile: Int, reduceMotion: Bool = false) {
        guard page == .game, !paused, !walking, !turning else { return }
        guard let path = chapter.path(to: tile, state: state), !path.isEmpty else {
            if tile != state.tile {
                rejectedTile = tile
                feedbackTick += 1
                if tile == chapter.destination, seals != totalSeals {
                    message = "Wake every sun seal to open the arch."
                } else {
                    message = "This path is apart. Try turning a bridge."
                }
                feedback(.warning)
            }
            return
        }
        focusedMechanism = nil
        message = seals == totalSeals
            ? "The arch is open. Your postcard is waiting."
            : "One step closer. Follow the connected landings."
        walking = true
        walkTask = Task { [weak self] in
            guard let self else { return }
            for tile in path {
                guard !Task.isCancelled, !paused,
                      let next = chapter.applying(.walk(tile), to: state) else { break }
                movingTo = tile
                do {
                    try await Task.sleep(for: .milliseconds(reduceMotion ? 40 : 400))
                } catch {
                    return
                }
                guard !Task.isCancelled, !paused else { return }
                let previousSeals = state.switches
                state = next
                movingTo = nil
                if state.switches != previousSeals {
                    message = seals == totalSeals ? "The arch is open. Your postcard is waiting." : "A sun seal awakens."
                    feedback(.success)
                    tone(660)
                } else {
                    tone(330 + Double(tile % 4) * 55)
                }
                save()
            }
            walking = false
            if !Task.isCancelled, !paused, chapter.hasArrived(state) {
                finish()
            }
        }
    }

    func rotate(_ index: Int, reduceMotion: Bool = false) {
        guard page == .game, !paused, !walking, !turning else { return }
        guard let next = chapter.applying(.rotate(index), to: state) else {
            rejectedTile = chapter.mechanisms[index].center
            feedbackTick += 1
            message = "Find the first sun seal to wake this bridge."
            feedback(.warning)
            return
        }
        focusedMechanism = index
        turning = true
        state = next
        message = "A new alignment. Tap a connected landing."
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        tone(262)
        save()
        turnTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(reduceMotion ? 40 : 560))
            } catch {
                return
            }
            self?.turning = false
        }
    }

    func setPaused(_ value: Bool) {
        guard page == .game else { return }
        paused = value
        if value {
            cancelWalk()
            tones.stop()
            save()
        } else if chapter.hasArrived(state) {
            finish()
        }
    }

    func showCollection() {
        cancelWalk()
        cancelTurn()
        paused = false
        save()
        page = .collection
    }

    func toggleSound() {
        journal.sound.toggle()
        if !journal.sound {
            tones.stop()
        }
        save()
    }

    private func finish() {
        let best = journal.best[chapter.id] ?? Int.max
        journal.best[chapter.id] = min(best, state.moves)
        save()
        tone(784)
        feedback(.success)
        page = .result
    }

    private func cancelWalk() {
        walkTask?.cancel()
        walkTask = nil
        movingTo = nil
        walking = false
    }

    private func cancelTurn() {
        turnTask?.cancel()
        turnTask = nil
        turning = false
    }

    private func tone(_ frequency: Double) {
        if journal.sound {
            tones.play(frequency)
        }
    }

    private func feedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

@MainActor
final class PostcardTones {
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?

    func play(_ frequency: Double) {
        if engine == nil {
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else { return }
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
            self.engine = engine
            self.player = player
        }
        guard let engine, let player,
              let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 11025),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = 11025
        for frame in 0 ..< 11025 {
            let time = Double(frame) / 44100
            let envelope = min(time * 100, 1) * exp(-time * 20)
            channel[frame] = Float(sin(2 * .pi * frequency * time) * envelope * 0.09)
        }
        if !engine.isRunning {
            try? engine.start()
        }
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    func stop() {
        player?.stop()
        engine?.pause()
    }
}
