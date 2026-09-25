import AVFoundation
import SwiftUI
import UIKit

@MainActor
final class PondSound {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private var buffers: [AVAudioPCMBuffer] = []

  init() {
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: format)
    for frequency in [261.63, 329.63, 392.0] {
      let count = 22050
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
      buffer.frameLength = AVAudioFrameCount(count)
      if let samples = buffer.floatChannelData?[0] {
        for index in 0..<count {
          let time = Double(index) / 44100
          let envelope = min(1, time * 150) * exp(-time * 9)
          let wave =
            sin(time * frequency * 2 * .pi)
            + 0.25 * sin(time * frequency * 4 * .pi)
          samples[index] = Float(wave * envelope * 0.23)
        }
      }
      buffers.append(buffer)
    }
  }

  func play(_ lane: Int) {
    do {
      if !engine.isRunning {
        try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try engine.start()
      }
      if !player.isPlaying { player.play() }
      player.scheduleBuffer(buffers[lane], at: nil, options: .interrupts)
    } catch {
      // Visual timing remains available when the audio route is unavailable.
    }
  }
}

@MainActor
final class GameModel: ObservableObject {
  enum Screen { case home, playing, results, tutorial }
  @Published var screen: Screen = .home
  @Published var engine = RhythmEngine(
    composition: Composition.all[0], rules: TimingRules(forgiving: true))
  @Published var elapsed = 0.0
  @Published var paused = false
  @Published var feedback = ""
  @Published var feedbackLane = 0
  @Published var feedbackTime = -10.0
  @Published var bloomTime = -10.0
  @Published var result: Performance?
  @Published var best: [String: Performance] = [:]
  @Published var tutorialStep = 0
  @Published var audio: Bool { didSet { defaults.set(audio, forKey: "audio") } }
  @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
  @Published var forgiving: Bool { didSet { defaults.set(forgiving, forKey: "forgiving") } }
  private var startedAt = 0.0
  private let defaults: UserDefaults
  private let sound = PondSound()

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    audio = defaults.object(forKey: "audio") as? Bool ?? true
    haptics = defaults.object(forKey: "haptics") as? Bool ?? true
    forgiving = defaults.object(forKey: "forgiving") as? Bool ?? true
    if let data = defaults.data(forKey: "performances"),
      let stored = try? JSONDecoder().decode([String: Performance].self, from: data)
    {
      best = stored
    }
  }

  func start(_ composition: Composition) {
    engine = RhythmEngine(composition: composition, rules: TimingRules(forgiving: forgiving))
    elapsed = 0
    startedAt = ProcessInfo.processInfo.systemUptime
    paused = false
    feedback = ""
    feedbackTime = -10
    bloomTime = -10
    screen = .playing
  }

  func tutorial() {
    tutorialStep = 0
    elapsed = 0
    paused = false
    feedback = ""
    screen = .tutorial
    startedAt = ProcessInfo.processInfo.systemUptime
  }

  func tick() {
    guard screen == .playing || screen == .tutorial, !paused else { return }
    elapsed = ProcessInfo.processInfo.systemUptime - startedAt
    guard screen == .playing else { return }
    let expiringLane = engine.composition.notes.last {
      engine.judgements[$0.id] == nil && elapsed > $0.time + engine.rules.hitWindow
    }?.lane
    if engine.expire(at: elapsed) > 0 {
      feedback = "Let it go"
      feedbackLane = expiringLane ?? 0
      feedbackTime = elapsed
    }
    if elapsed >= engine.composition.duration {
      result = engine.performance
      if let result {
        let key = "\(result.compositionID)-\(result.forgiving)"
        if best[key].map({
          result.accuracy > $0.accuracy
            || (result.accuracy == $0.accuracy && result.maxCombo > $0.maxCombo)
        }) ?? true {
          best[key] = result
          if let data = try? JSONEncoder().encode(best) {
            defaults.set(data, forKey: "performances")
          }
        }
      }
      screen = .results
    }
  }

  func tap(_ lane: Int) {
    guard !paused else { return }
    if screen == .tutorial {
      guard lane == tutorialStep % 3 else { return }
      tutorialStep += 1
      startedAt = ProcessInfo.processInfo.systemUptime
      elapsed = 0
      feedback = tutorialStep >= 3 ? "You’re ready" : "Beautiful"
      if audio { sound.play(lane) }
      if haptics { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
      return
    }
    guard screen == .playing else { return }
    tick()
    guard screen == .playing else { return }
    let phrases = engine.perfectPhrases
    if let judgement = engine.tap(lane: lane, at: elapsed) {
      feedback = judgement.rawValue
      feedbackLane = lane
      feedbackTime = elapsed
      if audio { sound.play(lane) }
      if haptics { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
      if engine.perfectPhrases > phrases { bloomTime = elapsed }
    } else {
      feedback = "Wait for the ring"
      feedbackLane = lane
      feedbackTime = elapsed
    }
  }

  func pause() {
    guard screen == .playing || screen == .tutorial else { return }
    if !paused { tick() }
    paused = true
  }

  func resume() {
    startedAt = ProcessInfo.processInfo.systemUptime - elapsed
    paused = false
  }

  func bestFor(_ id: Int) -> Performance? { best["\(id)-\(forgiving)"] }
  var clearedCount: Int { Composition.all.filter { bestFor($0.id)?.cleared == true }.count }
}
