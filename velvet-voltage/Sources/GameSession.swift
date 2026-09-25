import AVFoundation
import Combine
import SwiftUI
import UIKit

enum AppScreen {
  case home, tutorial, playing, results
}

@MainActor
final class GameSession: ObservableObject {
  @Published var screen = AppScreen.home
  @Published var paused = false
  @Published var score = ScoreCard()
  @Published var inFlight = false
  @Published var ballNumber = 1
  @Published var banner = "THE CITY IS WAITING"
  @Published var best: Int
  @Published var lifetimeCircuits: Int
  @Published var gamesPlayed: Int
  @Published var newRecord = false
  @Published var leftHeld = false
  @Published var rightHeld = false
  @Published var plungerPull = 0.0
  @Published var coaching = false
  @Published var sound: Bool { didSet { defaults.set(sound, forKey: "sound") } }
  @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
  var reducedMotion = false
  var engine = PinballEngine()
  private let defaults: UserDefaults
  private var player: AVAudioPlayer?
  private var lastSound = 0.0
  private var recordedResult = false
  private var startingBest = 0

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    best = defaults.integer(forKey: "best")
    lifetimeCircuits = defaults.integer(forKey: "circuits")
    gamesPlayed = defaults.integer(forKey: "games")
    sound = defaults.object(forKey: "sound") as? Bool ?? true
    haptics = defaults.object(forKey: "haptics") as? Bool ?? true
  }

  func start() {
    if !defaults.bool(forKey: "learned") {
      screen = .tutorial
    } else {
      newGame()
    }
  }

  func showTutorial() {
    screen = .tutorial
  }

  func newGame() {
    coaching = !defaults.bool(forKey: "learned")
    defaults.set(true, forKey: "learned")
    engine = PinballEngine()
    score = ScoreCard()
    ballNumber = 1
    inFlight = false
    paused = false
    recordedResult = false
    startingBest = best
    newRecord = false
    leftHeld = false
    rightHeld = false
    plungerPull = 0
    banner = "PULL DOWN OR TAP TO LAUNCH"
    screen = .playing
  }

  func launch(power: Double = 1) {
    guard screen == .playing, !paused, !engine.inFlight else { return }
    engine.launch(power: power)
    plungerPull = 0
    inFlight = engine.inFlight
    ballNumber = engine.ballsUsed
    banner = coaching ? "TOUCH EITHER SIDE TO FLIP" : targetBanner
    feedback(frequency: 240)
  }

  func pullPlunger(_ pull: Double) {
    guard screen == .playing, !paused, !engine.inFlight else { return }
    plungerPull = min(1, max(0, pull))
  }

  func setFlipper(left: Bool, pressed: Bool) {
    guard screen == .playing, !paused else { return }
    if left {
      engine.leftPressed = pressed
      leftHeld = pressed
    } else {
      engine.rightPressed = pressed
      rightHeld = pressed
    }
    if pressed, coaching, engine.inFlight {
      coaching = false
      banner = targetBanner
    }
  }

  func pause() {
    guard screen == .playing else { return }
    paused = true
    engine.leftPressed = false
    engine.rightPressed = false
    leftHeld = false
    rightHeld = false
    plungerPull = 0
  }

  private var targetBanner: String {
    "NEXT · \(Self.districtNames[score.nextDistrict])"
  }

  func consume(_ events: [TableEvent]) {
    for event in events {
      switch event {
      case .bumper(let index, let completed):
        score = engine.score
        best = max(best, score.points)
        defaults.set(best, forKey: "best")
        if completed {
          banner = "CIRCUIT COMPLETE · \(score.multiplier)× POWER"
        } else {
          banner = targetBanner
        }
        feedback(frequency: completed ? 880 : Double(400 + index * 160))
      case .flipper:
        feedback(frequency: 150)
      case .drain:
        inFlight = false
        leftHeld = false
        rightHeld = false
        coaching = false
        if engine.finished {
          finish()
        } else {
          ballNumber = engine.ballsUsed + 1
          banner =
            engine.ballsRemaining == 1
            ? "LAST BALL · MAKE IT COUNT" : "BALL LOST · PULL TO RELAUNCH"
          feedback(frequency: 100)
        }
      case .rail:
        break
      }
    }
  }

  private func finish() {
    guard !recordedResult else { return }
    recordedResult = true
    newRecord = score.points > startingBest
    gamesPlayed += 1
    lifetimeCircuits += score.circuits
    defaults.set(gamesPlayed, forKey: "games")
    defaults.set(lifetimeCircuits, forKey: "circuits")
    screen = .results
  }

  func feedback(frequency: Double) {
    if haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    guard sound, ProcessInfo.processInfo.systemUptime - lastSound > 0.07 else { return }
    lastSound = ProcessInfo.processInfo.systemUptime
    let rate = 22050
    let count = 2205
    var data = Data()
    func bytes(_ value: UInt32, count: Int) {
      for index in 0..<count { data.append(UInt8((value >> (8 * index)) & 255)) }
    }
    data.append(contentsOf: "RIFF".utf8)
    bytes(UInt32(36 + count * 2), count: 4)
    data.append(contentsOf: "WAVEfmt ".utf8)
    bytes(16, count: 4)
    bytes(1, count: 2)
    bytes(1, count: 2)
    bytes(UInt32(rate), count: 4)
    bytes(UInt32(rate * 2), count: 4)
    bytes(2, count: 2)
    bytes(16, count: 2)
    data.append(contentsOf: "data".utf8)
    bytes(UInt32(count * 2), count: 4)
    for sample in 0..<count {
      let t = Double(sample) / Double(rate)
      let envelope = exp(-t * 45) * min(1, t * 500)
      let value = Int16(sin(t * frequency * 2 * .pi) * envelope * 10000)
      bytes(UInt32(UInt16(bitPattern: value)), count: 2)
    }
    player = try? AVAudioPlayer(data: data)
    player?.play()
  }

  static let districtNames = ["THE ARCADE", "THE SPIRE", "THE RIVIERA"]
}
