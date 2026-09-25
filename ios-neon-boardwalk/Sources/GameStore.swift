import AVFoundation
import Combine
import UIKit

struct Banner: Equatable {
  let title: String
  let detail: String
  let isRecord: Bool
}

@MainActor
final class GameStore: NSObject, ObservableObject {
  let world = BoardwalkScene()
  private(set) var engine = RunnerEngine()
  private(set) var record: RunSnapshot
  private(set) var newBest = false
  private(set) var previousBest = 0
  private(set) var shieldBreakTime = 0.0
  private(set) var countdown = 0.0
  private(set) var banner: Banner?
  private var bannerTime = 0.0
  private var announcedBest = false
  private var districtIndex = 0
  @Published var showGuide: Bool {
    didSet { if !showGuide { defaults.set(true, forKey: "boardwalk.guideSeen") } }
  }
  @Published var showControls: Bool {
    didSet { defaults.set(showControls, forKey: "boardwalk.controls") }
  }
  @Published var sound: Bool {
    didSet { defaults.set(sound, forKey: "boardwalk.sound") }
  }
  var reducedMotion = false
  private let defaults: UserDefaults
  private var displayLink: CADisplayLink?
  private var previousTime = 0.0
  private var publishTime = 0.0
  private var animationTime = 0.0
  private var players: [AVAudioPlayer] = []

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: "boardwalk.record"),
      let stored = try? JSONDecoder().decode(RunSnapshot.self, from: data)
    {
      record = stored
    } else {
      record = RunSnapshot()
    }
    sound = defaults.object(forKey: "boardwalk.sound") as? Bool ?? true
    showControls = defaults.object(forKey: "boardwalk.controls") as? Bool ?? true
    showGuide = record.runs == 0 && !defaults.bool(forKey: "boardwalk.guideSeen")
    super.init()
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    displayLink = CADisplayLink(target: self, selector: #selector(frame(_:)))
    displayLink?.preferredFramesPerSecond = 60
    displayLink?.add(to: .main, forMode: .common)
  }

  func start() {
    engine = RunnerEngine()
    engine.start()
    newBest = false
    shieldBreakTime = 0
    countdown = 0
    banner = nil
    announcedBest = false
    districtIndex = 0
    showGuide = false
    previousTime = 0
    objectWillChange.send()
    tone(440, duration: 0.13)
  }

  func home() {
    engine = RunnerEngine()
    countdown = 0
    banner = nil
    objectWillChange.send()
  }

  func pause() {
    engine.pause()
    countdown = 0
    objectWillChange.send()
  }

  /// Resumes after a short 3-2-1 count so the rider is never hit the instant play restarts.
  func resume() {
    guard engine.phase == .paused, countdown == 0 else { return }
    countdown = Self.countdownLength
    previousTime = 0
    tone(520, duration: 0.06)
    objectWillChange.send()
  }

  static let countdownLength = 2.4

  static func district(for distance: Double) -> (index: Int, name: String) {
    let names = [
      "SUNSET STRIP", "ELECTRIC MILE", "AFTER HOURS", "MIDNIGHT PIER", "STARLIGHT COAST",
    ]
    let limits = [500.0, 1_500, 4_000, 8_000]
    let index = limits.firstIndex { distance < $0 } ?? limits.count
    return (index, names[index])
  }

  private func show(_ next: Banner) {
    banner = next
    bannerTime = 2.6
  }

  private func tickCountdown(_ delta: Double) {
    guard countdown > 0 else { return }
    let step = Self.countdownLength / 3
    let before = ceil(countdown / step)
    countdown = max(0, countdown - delta)
    if countdown == 0 {
      engine.resume()
      tone(780, duration: 0.1)
    } else if ceil(countdown / step) < before {
      tone(520, duration: 0.06)
    }
  }

  private func trackMilestones(_ delta: Double) {
    guard engine.phase == .running else { return }
    let district = Self.district(for: engine.distance)
    if district.index != districtIndex {
      districtIndex = district.index
      show(
        Banner(
          title: district.name, detail: "District 0\(district.index + 1) · the pace picks up",
          isRecord: false))
      tone(600, duration: 0.12)
    }
    if !announcedBest, record.bestDistance > 0, Int(engine.distance) > record.bestDistance {
      announcedBest = true
      show(
        Banner(
          title: "NEW PERSONAL BEST", detail: "Every metre from here is a record", isRecord: true))
      tone(990, duration: 0.22)
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    bannerTime = max(0, bannerTime - delta)
    if bannerTime == 0 { banner = nil }
  }

  func move(_ move: Move) {
    guard engine.phase == .running else { return }
    engine.move(move)
    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
    if move == .jump { tone(340, duration: 0.07) }
    if move == .slide { tone(170, duration: 0.06) }
    objectWillChange.send()
  }

  @objc private func frame(_ link: CADisplayLink) {
    let delta = previousTime == 0 ? 0 : min(0.05, link.timestamp - previousTime)
    previousTime = link.timestamp
    let oldCoins = engine.coins
    let oldShield = engine.shieldsCollected
    let oldGrace = engine.graceTime
    let oldPhase = engine.phase
    tickCountdown(delta)
    engine.advance(delta)
    trackMilestones(delta)
    if engine.phase == .running { shieldBreakTime = max(0, shieldBreakTime - delta) }
    if engine.graceTime > oldGrace {
      shieldBreakTime = 2
      tone(230, duration: 0.18)
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    if engine.phase != .paused && engine.phase != .finished { animationTime += delta }
    world.update(engine, time: animationTime, reducedMotion: reducedMotion)
    if engine.coins > oldCoins { tone(880, duration: 0.045) }
    if engine.shieldsCollected > oldShield {
      tone(660, duration: 0.2)
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    if oldPhase == .running && engine.phase == .finished {
      previousBest = record.bestDistance
      newBest = Int(engine.distance) > record.bestDistance
      record.bestDistance = max(record.bestDistance, Int(engine.distance))
      record.totalCoins += engine.coins
      record.runs += 1
      if let data = try? JSONEncoder().encode(record) {
        defaults.set(data, forKey: "boardwalk.record")
      }
      tone(120, duration: 0.3)
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    if link.timestamp - publishTime > 0.08 || oldPhase != engine.phase {
      publishTime = link.timestamp
      objectWillChange.send()
    }
  }

  private func tone(_ frequency: Double, duration: Double) {
    guard sound else { return }
    let sampleRate = 22_050.0
    let count = Int(sampleRate * duration)
    var data = Data()
    func append<T: FixedWidthInteger>(_ value: T) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
    data.append(contentsOf: "RIFF".utf8)
    append(UInt32(36 + count * 2))
    data.append(contentsOf: "WAVEfmt ".utf8)
    append(UInt32(16))
    append(UInt16(1))
    append(UInt16(1))
    append(UInt32(sampleRate))
    append(UInt32(sampleRate * 2))
    append(UInt16(2))
    append(UInt16(16))
    data.append(contentsOf: "data".utf8)
    append(UInt32(count * 2))
    for index in 0..<count {
      let position = Double(index) / Double(count)
      let envelope = min(1, position * 30) * pow(1 - position, 2)
      let wave = sin(Double(index) / sampleRate * frequency * .pi * 2)
      append(Int16(wave * envelope * 4_000))
    }
    players.removeAll { !$0.isPlaying }
    if let player = try? AVAudioPlayer(data: data) {
      players.append(player)
      player.play()
    }
  }
}
