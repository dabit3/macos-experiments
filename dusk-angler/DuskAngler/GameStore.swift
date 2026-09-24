import AVFoundation
import SwiftUI
import UIKit

enum GamePhase {
  case home, aiming, waiting, bite, duel, landing, caught, failed
}

@MainActor
final class GameStore: ObservableObject {
  static let biteWindow = 2.5
  @Published var phase = GamePhase.home
  @Published var progress: Progress
  @Published var lake = Lake.amber
  @Published var selected = 0
  @Published var aim = CGPoint(x: 0.24, y: 0.29)
  @Published var duel = Duel(species: .emberPerch)
  @Published var holding = false
  @Published var paused = false
  @Published var useBait = false
  @Published var phaseTime = 0.0
  @Published var failure = ""
  @Published var latest: CatchRecord?
  @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
  @Published var sound: Bool { didSet { defaults.set(sound, forKey: "sound") } }
  let defaults: UserDefaults
  private var player: AVAudioPlayer?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    progress =
      defaults.data(forKey: "progress").flatMap {
        try? JSONDecoder().decode(Progress.self, from: $0)
      } ?? Progress()
    haptics = defaults.object(forKey: "haptics") as? Bool ?? true
    sound = defaults.object(forKey: "sound") as? Bool ?? true
  }

  var activeSpecies: Species {
    useBait ? (lake == .amber ? .moonKoi : .glassChar) : lake.species[selected]
  }

  func save() {
    if let data = try? JSONEncoder().encode(progress) { defaults.set(data, forKey: "progress") }
  }

  func begin() {
    holding = false
    paused = false
    phaseTime = 0
    selected = 0
    aim = CGPoint(x: 0.24, y: 0.29)
    phase = .aiming
  }

  func target(_ index: Int) {
    selected = index
    aim = CGPoint(x: Casting.positions[index].0, y: Casting.positions[index].1)
    feedback()
  }

  func cast() {
    guard phase == .aiming else { return }
    guard let target = Casting.target(x: aim.x, y: aim.y) else {
      fail("Empty water", detail: "Aim closer to a fish silhouette, then cast again.")
      return
    }
    selected = target
    let fish = activeSpecies
    if useBait {
      guard progress.bait >= 2 else {
        useBait = false
        return
      }
      progress.bait -= 2
      save()
    }
    duel = Duel(species: fish)
    useBait = false
    phaseTime = 0
    phase = .waiting
    feedback()
  }

  func hook() {
    guard phase == .bite || phase == .waiting else { return }
    guard phase == .bite else {
      fail("Too soon", detail: "Let the float dip. Tap HOOK when the golden ring appears.")
      return
    }
    phase = .duel
    phaseTime = 0
    holding = false
    feedback(strong: true)
  }

  func tick(_ seconds: Double) {
    guard !paused else { return }
    let dt = min(seconds, 0.1)
    phaseTime += dt
    switch phase {
    case .waiting:
      if phaseTime >= 1.5 {
        phase = .bite
        phaseTime = 0
        feedback(strong: true)
      }
    case .bite:
      if phaseTime > Self.biteWindow {
        fail(
          "A missed moment", detail: "The fish slipped away. Tap HOOK as soon as the float dips.")
      }
    case .duel:
      duel.step(seconds: dt, reeling: holding)
      switch duel.outcome {
      case .caught:
        let record = CatchRecord(
          id: UUID(), species: duel.species, lake: lake,
          length: duel.species.baseLength + Int(max(0, 40 - duel.elapsed)) / 3,
          score: duel.score, date: Date())
        latest = record
        progress.add(record)
        save()
        phase = .landing
        phaseTime = 0
        holding = false
        feedback(strong: true)
      case .snapped:
        fail(
          "The line broke",
          detail: "Release before a surge. Reel while the line is in the mint zone.")
      case .escaped:
        fail(
          "A little too gentle",
          detail: "Keep some tension on the line. Reel before the slack timer runs out.")
      case .timeout:
        fail(
          "Back to the deep", detail: "This fish outlasted you. Reel more often between its surges."
        )
      case .active: break
      }
    case .landing:
      if phaseTime >= 1.3 {
        phase = .caught
        phaseTime = 0
      }
    default: break
    }
  }

  func fail(_ title: String, detail: String) {
    failure = title + "|" + detail
    phase = .failed
    holding = false
    feedback()
  }

  func pause() {
    if [.aiming, .waiting, .bite, .duel].contains(phase) {
      holding = false
      paused = true
    }
  }

  func feedback(strong: Bool = false) {
    if haptics {
      UIImpactFeedbackGenerator(style: strong ? .medium : .light).impactOccurred()
    }
    guard sound else { return }
    let sampleRate = 22050
    let count = 3300
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
    for sample in 0..<count {
      let t = Double(sample) / Double(sampleRate)
      let envelope = exp(-t * 30) * min(1, t * 200)
      let tone = sin(t * .pi * 2 * (strong ? 660 : 440))
      append(Int16(tone * envelope * 6500))
    }
    try? AVAudioSession.sharedInstance().setCategory(.ambient)
    player = try? AVAudioPlayer(data: data)
    player?.play()
  }
}
