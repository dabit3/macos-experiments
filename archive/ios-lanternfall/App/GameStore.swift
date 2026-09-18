import AVFoundation
import Combine
import SwiftUI
import UIKit

final class GameStore: ObservableObject {
  @Published var game = GameModel()
  @Published var screen = "title"
  @Published var sound = UserDefaults.standard.object(forKey: "sound") as? Bool ?? true
  @Published var bestSeconds = UserDefaults.standard.double(forKey: "bestSeconds")
  @Published var bestKills = UserDefaults.standard.integer(forKey: "bestKills")
  @Published var victories = UserDefaults.standard.integer(forKey: "victories")
  let scene = GardenScene()
  private var saved = false
  private let audio = GardenAudio()
  init() {
    scene.scaleMode = .resizeFill
    scene.onFrame = { [weak self] delta in self?.frame(delta) }
  }
  func start() {
    scene.resetRun()
    game = GameModel()
    saved = false
    screen = "game"
    scene.model = game
    cue(.start)
  }
  func frame(_ delta: Double) {
    guard screen == "game" else { return }
    let phase = game.phase
    let shots = game.shotsFired
    let health = game.health
    game.tick(delta)
    scene.model = game
    if game.shotsFired > shots { cue(.bolt) }
    if game.health < health {
      cue(.hurt)
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    if phase != game.phase {
      if game.phase == .choosing { cue(.level) }
      if game.phase == .victory || game.phase == .defeat { finish() }
    }
  }
  func choose(_ upgrade: Upgrade) {
    game.choose(upgrade)
    cue(.level)
    UISelectionFeedbackGenerator().selectionChanged()
  }
  func finish() {
    guard !saved else { return }
    saved = true
    bestSeconds = max(bestSeconds, game.elapsed)
    bestKills = max(bestKills, game.kills)
    if game.phase == .victory { victories += 1 }
    UserDefaults.standard.set(bestSeconds, forKey: "bestSeconds")
    UserDefaults.standard.set(bestKills, forKey: "bestKills")
    UserDefaults.standard.set(victories, forKey: "victories")
    cue(game.phase == .victory ? .level : .hurt)
  }
  func toggleSound() {
    sound.toggle()
    UserDefaults.standard.set(sound, forKey: "sound")
    if sound { cue(.level) }
  }
  func cue(_ tone: GardenAudio.Tone) { if sound { audio.play(tone) } }
}

final class GardenAudio {
  enum Tone { case bolt, level, hurt, start }
  private var players: [Tone: AVAudioPlayer] = [:]
  init() {
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    for tone in [Tone.bolt, .level, .hurt, .start] {
      let frequency: Double = tone == .bolt ? 740 : tone == .hurt ? 110 : tone == .level ? 880 : 440
      let duration: Double = tone == .bolt ? 0.06 : 0.25
      let count = Int(22050 * duration)
      var data = Data()
      func word(_ value: UInt32, bytes: Int) {
        for offset in 0..<bytes { data.append(UInt8((value >> (offset * 8)) & 255)) }
      }
      data.append(contentsOf: "RIFF".utf8)
      word(UInt32(36 + count * 2), bytes: 4)
      data.append(contentsOf: "WAVEfmt ".utf8)
      word(16, bytes: 4)
      word(1, bytes: 2)
      word(1, bytes: 2)
      word(22050, bytes: 4)
      word(44100, bytes: 4)
      word(2, bytes: 2)
      word(16, bytes: 2)
      data.append(contentsOf: "data".utf8)
      word(UInt32(count * 2), bytes: 4)
      for sample in 0..<count {
        let t = Double(sample) / 22050
        let envelope = sin(.pi * Double(sample) / Double(count)) * exp(-t * 12)
        let signal = sin(2 * .pi * frequency * t) + 0.25 * sin(2 * .pi * frequency * 1.5 * t)
        let value = Int16(signal * envelope * (tone == .bolt ? 1800 : 4500))
        word(UInt32(UInt16(bitPattern: value)), bytes: 2)
      }
      players[tone] = try? AVAudioPlayer(data: data)
      players[tone]?.prepareToPlay()
    }
  }
  func play(_ tone: Tone) {
    guard let player = players[tone] else { return }
    player.currentTime = 0
    player.play()
  }
}
