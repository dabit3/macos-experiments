import AVFoundation
import SwiftUI
import UIKit

@MainActor
final class FlapStore: NSObject, ObservableObject {
  @Published var engine = FlapEngine()
  @Published var best = 0
  @Published var newBest = false
  @Published var soundEnabled = true
  private var width = 420.0
  private var displayLink: CADisplayLink?
  private var lastFrame = 0.0
  private var lastScore = 0
  private var lastShells = 0
  private var lastPhase = FlapPhase.ready
  private var players: [String: AVAudioPlayer] = [:]
  private let defaults: UserDefaults

  override convenience init() {
    self.init(defaults: .standard)
  }

  init(defaults: UserDefaults) {
    self.defaults = defaults
    super.init()
    best = defaults.integer(forKey: "otterflap.best")
    soundEnabled = defaults.object(forKey: "otterflap.sound") as? Bool ?? true
    try? AVAudioSession.sharedInstance().setCategory(.ambient)
    players = SoundBank.makePlayers()
    let link = CADisplayLink(target: self, selector: #selector(frame))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  func configure(size: CGSize) {
    guard size.height > 0 else { return }
    let target = FlapEngine.height * Double(size.width / size.height)
    guard abs(target - width) > 1 else { return }
    width = target
    if engine.phase == .ready {
      engine = FlapEngine(width: width, seed: .random(in: 1...UInt64.max))
    }
  }

  func tap() {
    switch engine.phase {
    case .ready, .flying:
      engine.flap()
      play("flap")
      UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
    case .falling, .over:
      break
    }
  }

  func restart() {
    engine = FlapEngine(width: width, seed: .random(in: 1...UInt64.max))
    lastScore = 0
    lastShells = 0
    lastPhase = .ready
    newBest = false
    lastFrame = 0
    play("score")
  }

  func toggleSound() {
    soundEnabled.toggle()
    defaults.set(soundEnabled, forKey: "otterflap.sound")
  }

  @objc private func frame(_ link: CADisplayLink) {
    let now = link.timestamp
    let delta = lastFrame == 0 ? 1.0 / 60.0 : now - lastFrame
    lastFrame = now
    engine.advance(delta)
    if engine.score != lastScore {
      lastScore = engine.score
      play("score")
    }
    if engine.shells != lastShells {
      lastShells = engine.shells
      play("shell")
      UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
    }
    if engine.phase != lastPhase {
      switch engine.phase {
      case .falling:
        play("bonk")
        UINotificationFeedbackGenerator().notificationOccurred(.error)
      case .over:
        play("splash")
        if engine.score > best {
          best = engine.score
          newBest = true
          defaults.set(best, forKey: "otterflap.best")
        }
      default:
        break
      }
      lastPhase = engine.phase
    }
  }

  private func play(_ name: String) {
    guard soundEnabled, let player = players[name] else { return }
    player.currentTime = 0
    player.play()
  }
}

enum SoundBank {
  static func makePlayers() -> [String: AVAudioPlayer] {
    let clips: [String: Data] = [
      "flap": wav(duration: 0.12) { t, p in sin(2 * .pi * (420 + 520 * p) * t) * (1 - p) * 0.5 },
      "score": wav(duration: 0.26) { t, p in
        let f = p < 0.4 ? 988.0 : 1318.5
        return sin(2 * .pi * f * t) * (1 - p) * 0.35
      },
      "shell": wav(duration: 0.42) { t, p in
        let f = [1568.0, 1976.0, 2349.0, 3136.0][min(3, Int(p * 4))]
        return sin(2 * .pi * f * t) * pow(1 - p, 1.5) * 0.3
      },
      "bonk": wav(duration: 0.22) { t, p in sin(2 * .pi * (220 - 140 * p) * t) * (1 - p) * 0.7 },
      "splash": wav(duration: 0.55) { _, p in
        Double.random(in: -1...1) * pow(1 - p, 2) * 0.45 * min(1, p * 20)
      },
    ]
    var players: [String: AVAudioPlayer] = [:]
    for (name, data) in clips {
      if let player = try? AVAudioPlayer(data: data) {
        player.prepareToPlay()
        players[name] = player
      }
    }
    return players
  }

  private static func wav(duration: Double, _ sample: (Double, Double) -> Double) -> Data {
    let rate = 44_100
    let count = Int(duration * Double(rate))
    var pcm = Data(capacity: count * 2)
    for index in 0..<count {
      let t = Double(index) / Double(rate)
      let value = max(-1, min(1, sample(t, t / duration)))
      var little = Int16(value * 32_000).littleEndian
      withUnsafeBytes(of: &little) { pcm.append(contentsOf: $0) }
    }
    var data = Data()
    func word(_ value: UInt16) {
      withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    func dword(_ value: UInt32) {
      withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    data.append(Data("RIFF".utf8))
    dword(UInt32(pcm.count + 36))
    data.append(Data("WAVEfmt ".utf8))
    dword(16)
    word(1)
    word(1)
    dword(UInt32(rate))
    dword(UInt32(rate * 2))
    word(2)
    word(16)
    data.append(Data("data".utf8))
    dword(UInt32(pcm.count))
    data.append(pcm)
    return data
  }
}
