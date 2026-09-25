import AVFoundation
import UIKit

enum FeedbackCue { case catchCargo, releaseCargo, land, miss, win }

@MainActor
final class Feedback {
  private var player: AVAudioPlayer?

  func play(_ cue: FeedbackCue, audio: Bool, haptics: Bool) {
    if haptics {
      if cue == .win {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      } else {
        UIImpactFeedbackGenerator(style: cue == .land ? .medium : .light).impactOccurred()
      }
    }
    guard audio else { return }
    let frequency: Double
    switch cue {
    case .catchCargo: frequency = 660
    case .releaseCargo: frequency = 330
    case .land: frequency = 880
    case .miss: frequency = 180
    case .win: frequency = 1046
    }
    let rate = 22050
    let samples = cue == .win ? 11025 : 3307
    var data = Data()
    func word(_ number: UInt32, bytes: Int) {
      for shift in 0..<bytes { data.append(UInt8((number >> (shift * 8)) & 255)) }
    }
    data.append(contentsOf: "RIFF".utf8)
    word(UInt32(36 + samples * 2), bytes: 4)
    data.append(contentsOf: "WAVEfmt ".utf8)
    word(16, bytes: 4)
    word(1, bytes: 2)
    word(1, bytes: 2)
    word(UInt32(rate), bytes: 4)
    word(UInt32(rate * 2), bytes: 4)
    word(2, bytes: 2)
    word(16, bytes: 2)
    data.append(contentsOf: "data".utf8)
    word(UInt32(samples * 2), bytes: 4)
    for index in 0..<samples {
      let t = Double(index) / Double(rate)
      let envelope = min(1, t * 100) * exp(-t * 11)
      let tone = sin(t * frequency * 2 * .pi) + 0.2 * sin(t * frequency * 4 * .pi)
      let value = Int16(tone * envelope * 7000)
      word(UInt32(UInt16(bitPattern: value)), bytes: 2)
    }
    try? AVAudioSession.sharedInstance().setCategory(.ambient)
    player = try? AVAudioPlayer(data: data)
    player?.play()
  }
}
