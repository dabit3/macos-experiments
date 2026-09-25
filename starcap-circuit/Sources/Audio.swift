import AVFoundation
import Foundation

@MainActor
final class RaceAudio {
  private var music: AVAudioPlayer?
  private var sounds: [AVAudioPlayer] = []
  private var muted = false

  func start() {
    guard music == nil else { return }
    try? AVAudioSession.sharedInstance().setCategory(
      .playback, mode: .default, options: [.mixWithOthers])
    try? AVAudioSession.sharedInstance().setActive(true)
    let notes: [Double] = [
      523.25, 659.25, 783.99, 659.25, 880, 783.99, 659.25, 587.33,
      523.25, 659.25, 783.99, 1046.5, 880, 783.99, 587.33, 659.25,
    ]
    let data = wave(seconds: 8) { t in
      let beat = t / 0.25
      let i = Int(beat) % notes.count
      let envelope = exp(-((beat - floor(beat)) * 5))
      let melody = sin(t * notes[i] * 2 * .pi) * envelope * 0.17
      let bassNote = [130.81, 164.81, 174.61, 196.0][Int(t / 2) % 4]
      let bass = sin(t * bassNote * 2 * .pi) * 0.12
      let beatPhase = t.truncatingRemainder(dividingBy: 0.5)
      let kick =
        sin(2 * .pi * (70 * beatPhase - 30 * beatPhase * beatPhase)) * exp(-beatPhase * 24) * 0.22
      let hatPhase = t.truncatingRemainder(dividingBy: 0.25)
      let hat = sin(t * 12091) * sin(t * 17317) * exp(-hatPhase * 60) * 0.06
      return melody + bass + kick + hat
    }
    music = try? AVAudioPlayer(data: data)
    music?.numberOfLoops = -1
    music?.volume = muted ? 0 : 0.35
    music?.play()
  }

  func setMuted(_ value: Bool) {
    muted = value
    music?.volume = value ? 0 : 0.35
  }

  func effect(_ name: String) {
    guard !muted else { return }
    let base: Double
    switch name {
    case "zap": base = 170
    case "boost": base = 340
    case "win": base = 660
    case "go": base = 523
    case "dash": base = 440
    default: base = 880
    }
    let data = wave(seconds: name == "win" ? 1.1 : 0.32) { t in
      let frequency = name == "zap" ? base + sin(t * 70) * 100 : base + floor(t * 12) * 110
      return sin(2 * .pi * frequency * t) * exp(-t * 4) * 0.28
    }
    sounds.removeAll { !$0.isPlaying }
    if let sound = try? AVAudioPlayer(data: data) {
      sounds.append(sound)
      sound.play()
    }
  }

  private func wave(seconds: Double, sample: (Double) -> Double) -> Data {
    let rate = 22050
    let count = Int(seconds * Double(rate))
    var data = Data()
    func text(_ value: String) { data.append(contentsOf: value.utf8) }
    func word<T: FixedWidthInteger>(_ value: T) {
      var value = value.littleEndian
      withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }
    text("RIFF")
    word(UInt32(36 + count * 2))
    text("WAVEfmt ")
    word(UInt32(16))
    word(UInt16(1))
    word(UInt16(1))
    word(UInt32(rate))
    word(UInt32(rate * 2))
    word(UInt16(2))
    word(UInt16(16))
    text("data")
    word(UInt32(count * 2))
    for i in 0..<count {
      word(Int16(max(-1, min(1, sample(Double(i) / Double(rate)))) * 32700))
    }
    return data
  }
}
