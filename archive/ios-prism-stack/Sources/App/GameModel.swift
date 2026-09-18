import AVFoundation
import SwiftUI
import UIKit

enum GameScreen { case title, playing, paused, ending, result }
enum GameAction { case left, right, rotate, softDrop, hardDrop, hold }

@MainActor @Observable
final class GameModel {
  var engine = PrismEngine()
  var screen = GameScreen.title
  var best = UserDefaults.standard.integer(forKey: "prism.best")
  var sound = UserDefaults.standard.object(forKey: "prism.sound") as? Bool ?? true
  var gestures = UserDefaults.standard.object(forKey: "prism.gestures") as? Bool ?? false
  var hasSavedGame = false
  var showingGuide = false
  var clearText = ""
  var clearDate = Date.distantPast
  var dropDate = Date.distantPast
  var sessionBest = 0
  private var lastTick = Date()
  private var resultDate = Date.distantFuture
  private let audio = PrismAudio()
  private let impact = UIImpactFeedbackGenerator(style: .light)

  init() {
    if let data = UserDefaults.standard.data(forKey: "prism.run"),
      let saved = try? JSONDecoder().decode(PrismEngine.self, from: data),
      !saved.isOver, saved.board.count == 22,
      saved.board.allSatisfy({ $0.count == 10 })
    {
      engine = saved
      hasSavedGame = true
    }
  }

  func start() {
    if !hasSavedGame { engine = PrismEngine() }
    sessionBest = best
    screen = .playing
    lastTick = Date()
    save()
  }

  func replay() {
    engine = PrismEngine()
    hasSavedGame = false
    clearText = ""
    start()
  }

  func pause() {
    guard screen == .playing else { return }
    screen = .paused
    save()
  }

  func resume() {
    lastTick = Date()
    screen = .playing
  }

  func home() {
    save()
    screen = .title
  }

  func tick(_ date: Date) {
    let elapsed = date.timeIntervalSince(lastTick)
    lastTick = date
    if screen == .ending, date >= resultDate {
      screen = .result
      return
    }
    guard screen == .playing else { return }
    let oldLock = engine.lockSerial
    engine.tick(elapsed)
    afterChange(oldLock: oldLock)
  }

  func act(_ action: GameAction) {
    guard screen == .playing else { return }
    let oldLock = engine.lockSerial
    switch action {
    case .left: engine.move(-1)
    case .right: engine.move(1)
    case .rotate:
      if engine.rotate() {
        feedback()
        if sound { audio.play(.turn) }
      }
    case .softDrop: engine.softDrop()
    case .hardDrop:
      dropDate = Date()
      engine.hardDrop()
    case .hold:
      if engine.canHold {
        engine.hold()
        feedback()
        if sound { audio.play(.turn) }
      }
    }
    afterChange(oldLock: oldLock)
  }

  private func afterChange(oldLock: Int) {
    if engine.score > best {
      best = engine.score
      UserDefaults.standard.set(best, forKey: "prism.best")
    }
    if engine.lockSerial != oldLock {
      feedback()
      if engine.lastClear > 0 {
        clearDate = Date()
        clearText = ["", "SINGLE", "DOUBLE", "TRIPLE", "PRISM CLEAR"][engine.lastClear]
        if sound { audio.play(.clear) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      } else if sound {
        audio.play(.drop)
      }
      save()
    }
    if engine.isOver {
      screen = .ending
      resultDate = Date().addingTimeInterval(0.85)
      hasSavedGame = false
      UserDefaults.standard.removeObject(forKey: "prism.run")
      if sound { audio.play(.finish) }
    }
  }

  func feedback() { impact.impactOccurred(intensity: 0.65) }

  func toggleSound() {
    sound.toggle()
    UserDefaults.standard.set(sound, forKey: "prism.sound")
    if sound { audio.play(.turn) }
  }

  func toggleGestures() {
    gestures.toggle()
    UserDefaults.standard.set(gestures, forKey: "prism.gestures")
  }

  func save() {
    guard !engine.isOver, screen != .title || hasSavedGame else { return }
    if let data = try? JSONEncoder().encode(engine) {
      UserDefaults.standard.set(data, forKey: "prism.run")
      hasSavedGame = true
    }
  }
}

@MainActor
final class PrismAudio {
  enum Tone: CaseIterable { case turn, drop, clear, finish }
  private var players: [Tone: AVAudioPlayer] = [:]

  init() {
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    for tone in Tone.allCases {
      let frequencies: [Double]
      switch tone {
      case .turn: frequencies = [660]
      case .drop: frequencies = [164, 110]
      case .clear: frequencies = [523.25, 659.25, 783.99, 1046.5]
      case .finish: frequencies = [392, 329.63, 261.63]
      }
      if let player = try? AVAudioPlayer(data: Self.wave(frequencies)) {
        player.volume = 0.22
        player.prepareToPlay()
        players[tone] = player
      }
    }
  }

  func play(_ tone: Tone) {
    players[tone]?.currentTime = 0
    players[tone]?.play()
  }

  private static func wave(_ notes: [Double]) -> Data {
    let sampleRate = 22050
    let samplesPerNote = 1900
    var samples = Data()
    for frequency in notes {
      for index in 0..<samplesPerNote {
        let t = Double(index) / Double(sampleRate)
        let envelope = sin(.pi * Double(index) / Double(samplesPerNote))
        let wave = sin(2 * .pi * frequency * t) + 0.2 * sin(4 * .pi * frequency * t)
        var value = Int16(wave * envelope * 13000).littleEndian
        withUnsafeBytes(of: &value) { samples.append(contentsOf: $0) }
      }
    }
    var data = Data()
    func text(_ value: String) { data.append(contentsOf: value.utf8) }
    func integer<T: FixedWidthInteger>(_ value: T) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
    text("RIFF")
    integer(UInt32(36 + samples.count))
    text("WAVEfmt ")
    integer(UInt32(16))
    integer(UInt16(1))
    integer(UInt16(1))
    integer(UInt32(sampleRate))
    integer(UInt32(sampleRate * 2))
    integer(UInt16(2))
    integer(UInt16(16))
    text("data")
    integer(UInt32(samples.count))
    data.append(samples)
    return data
  }
}
