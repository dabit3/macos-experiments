import AVFoundation
import Observation
import SwiftUI
import UIKit

@MainActor @Observable
final class GameStore {
  var progress: Progress
  var selected = 0
  var mission: Mission?
  var paused = false
  var showTutorial = false
  var showSettings = false
  var tutorialPage = 0
  var snackPulse = 0
  private let defaults: UserDefaults
  private var player: AVAudioPlayer?
  private static let saveKey = "rooftop-raccoon.progress.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: Self.saveKey),
      let saved = try? JSONDecoder().decode(Progress.self, from: data)
    {
      progress = saved
    } else {
      progress = Progress()
    }
  }

  func save() {
    if let data = try? JSONEncoder().encode(progress) { defaults.set(data, forKey: Self.saveKey) }
  }

  func start() {
    mission = Mission(district: District.all[selected])
    paused = false
    tutorialPage = 0
    showTutorial = !progress.tutorialSeen
  }

  func finishTutorial() {
    progress.tutorialSeen = true
    save()
    showTutorial = false
  }

  func home() {
    mission = nil
    paused = false
  }

  func act(_ target: Int?) {
    guard !paused, !showTutorial, mission?.phase == .playing else { return }
    let previousLoot = mission?.loot ?? 0
    let previousAlarm = mission?.alarm ?? 0
    if let target { mission?.move(to: target) } else { mission?.wait() }
    guard let mission else { return }
    if mission.alarm > previousAlarm {
      feedback(.warning)
      tone(frequency: 165)
    } else if mission.loot > previousLoot {
      snackPulse += 1
      feedback(.success)
      tone(frequency: 660 + Double(mission.loot) * 55)
    } else {
      if progress.haptics { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    }
    if mission.phase == .escaped {
      progress.record(mission)
      save()
      tone(frequency: 1046)
    }
  }

  func move(_ direction: Direction) {
    guard let target = mission?.neighbor(direction) else { return }
    act(target)
  }

  private func feedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    if progress.haptics { UINotificationFeedbackGenerator().notificationOccurred(type) }
  }

  private func tone(frequency: Double) {
    guard progress.sound else { return }
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    let rate = 22_050
    let count = rate / 5
    var samples = [Int16]()
    samples.reserveCapacity(count)
    for index in 0..<count {
      let time = Double(index) / Double(rate)
      let envelope = exp(-time * 22) * min(1, time * 500)
      let wave = sin(2 * .pi * frequency * time) + 0.25 * sin(4 * .pi * frequency * time)
      samples.append(Int16(wave * envelope * 8_000))
    }
    var data = Data()
    func text(_ value: String) { data.append(contentsOf: value.utf8) }
    func number<T: FixedWidthInteger>(_ value: T) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
    text("RIFF")
    number(UInt32(36 + count * 2))
    text("WAVEfmt ")
    number(UInt32(16))
    number(UInt16(1))
    number(UInt16(1))
    number(UInt32(rate))
    number(UInt32(rate * 2))
    number(UInt16(2))
    number(UInt16(16))
    text("data")
    number(UInt32(count * 2))
    samples.withUnsafeBytes { data.append(contentsOf: $0) }
    player = try? AVAudioPlayer(data: data)
    player?.play()
  }
}
