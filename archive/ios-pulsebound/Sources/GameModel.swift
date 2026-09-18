import Combine
import SwiftUI
import UIKit

final class GameModel: ObservableObject {
  @Published var selection = 0
  @Published var practice = false
  @Published var screenIsGame = false
  @Published var engine = Engine(stage: Stage.all[0], practice: false)
  @Published var attempts = 0
  @Published var checkpointNotice = false
  @Published var resultReady = false
  @Published var resumeCount = 0
  @Published var sound: Bool {
    didSet {
      defaults.set(sound, forKey: "sound")
      if !sound { audio.stop() } else if engine.phase == .running { playAudio() }
    }
  }
  @Published var bests: [Double]
  @Published var practiceBests: [Double]
  @Published var clears: [Bool]
  let audio = PulseAudio()
  private let defaults: UserDefaults
  private var noticeTimer = 0.0
  private var resultDelay = 0.0
  private var resumeDelay = 0.0
  private let haptic = UINotificationFeedbackGenerator()
  private let impact = UIImpactFeedbackGenerator(style: .light)

  var stage: Stage { Stage.all[selection] }
  var best: Double { practice ? practiceBests[selection] : bests[selection] }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    sound = defaults.object(forKey: "sound") as? Bool ?? true
    bests = (0..<3).map { defaults.double(forKey: "best.\($0)") }
    practiceBests = (0..<3).map { defaults.double(forKey: "practice.\($0)") }
    clears = (0..<3).map { defaults.bool(forKey: "clear.\($0)") }
  }

  func enter() {
    engine = Engine(stage: stage, practice: practice)
    attempts = defaults.integer(forKey: "attempts.\(selection)")
    checkpointNotice = false
    resultReady = false
    resultDelay = 0
    resumeDelay = 0
    resumeCount = 0
    audio.prepare(stage: stage)
    screenIsGame = true
  }

  func tap() {
    switch engine.phase {
    case .ready:
      attempts += 1
      defaults.set(attempts, forKey: "attempts.\(selection)")
      engine.start()
      playAudio()
    case .running:
      let grounded = engine.grounded
      engine.jump()
      if grounded { impact.impactOccurred(intensity: 0.7) }
    default: break
    }
  }

  func tick(_ dt: Double) {
    if resumeDelay > 0 {
      resumeDelay = max(0, resumeDelay - dt)
      resumeCount = Int(ceil(resumeDelay / (60 / stage.bpm)))
      if resumeDelay == 0 {
        engine.resume()
        playAudio()
      }
      return
    }
    if resultDelay > 0 {
      resultDelay -= dt
      if resultDelay <= 0 { resultReady = true }
    }
    let previousPhase = engine.phase
    let previousCheckpoint = engine.checkpoint
    engine.advance(dt)
    if engine.checkpoint > previousCheckpoint {
      checkpointNotice = true
      noticeTimer = 2
      haptic.notificationOccurred(.success)
    }
    if engine.phase == .running && noticeTimer > 0 {
      noticeTimer -= dt
      if noticeTimer <= 0 { checkpointNotice = false }
    }
    if previousPhase == .running && engine.phase != .running {
      saveResult()
      audio.stop()
      audio.effect(success: engine.phase == .cleared, enabled: sound)
      haptic.notificationOccurred(engine.phase == .cleared ? .success : .error)
      resultDelay = engine.phase == .cleared ? 0.2 : 0.45
    }
  }

  func pause() {
    resumeDelay = 0
    resumeCount = 0
    engine.pause()
    audio.stop()
  }

  func resume() {
    guard engine.phase == .paused else { return }
    resumeDelay = 3 * 60 / stage.bpm
    resumeCount = 3
  }

  func retry() {
    engine.retry()
    checkpointNotice = false
    resultReady = false
    resultDelay = 0
    resumeDelay = 0
    resumeCount = 0
    tap()
  }

  func home() {
    if engine.phase == .running || engine.phase == .paused { saveResult() }
    audio.stop()
    resumeDelay = 0
    resumeCount = 0
    screenIsGame = false
  }

  private func playAudio() {
    audio.play(from: engine.x, stage: stage, enabled: sound)
  }

  private func saveResult() {
    let value = engine.progress
    if practice {
      practiceBests[selection] = max(practiceBests[selection], value)
      defaults.set(practiceBests[selection], forKey: "practice.\(selection)")
    } else {
      bests[selection] = max(bests[selection], value)
      defaults.set(bests[selection], forKey: "best.\(selection)")
      if engine.phase == .cleared {
        clears[selection] = true
        defaults.set(true, forKey: "clear.\(selection)")
      }
    }
  }
}
