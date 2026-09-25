import AVFoundation
import Foundation

final class PulseAudio {
  private let engine = AVAudioEngine()
  private let music = AVAudioPlayerNode()
  private let cue = AVAudioPlayerNode()
  private var configured = false
  private var buffer: AVAudioPCMBuffer?
  private let rate = 22_050.0

  func prepare(stage: Stage) {
    stop()
    if !configured {
      let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
      engine.attach(music)
      engine.attach(cue)
      engine.connect(music, to: engine.mainMixerNode, format: format)
      engine.connect(cue, to: engine.mainMixerNode, format: format)
      configured = true
    }
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    try? engine.start()
    let beat = 60 / stage.bpm
    let seconds = beat * 16
    buffer = makeBuffer(seconds: seconds) { time in
      let beatIndex = Int(time / beat)
      let phase = time.truncatingRemainder(dividingBy: beat)
      let kickFrequency = 48 + 110 * exp(-phase * 35)
      let kick = sin(2 * .pi * kickFrequency * phase) * exp(-phase * 18) * 0.42
      let notes = [130.81, 155.56, 174.61, 116.54]
      let note = notes[(beatIndex / 4 + stage.id) % notes.count]
      let bass =
        (sin(2 * .pi * note * time) + 0.25 * sin(4 * .pi * note * time))
        * exp(-phase * 7) * 0.16
      let eighth = time.truncatingRemainder(dividingBy: beat / 2)
      let hat = sin(time * 19_739) * sin(time * 23_117) * exp(-eighth * 95) * 0.08
      let melodyNotes = [2.0, 3.0, 4.0, 3.0, 2.0, 4.0, 3.0, 6.0]
      let melody =
        sin(2 * .pi * note * melodyNotes[beatIndex % 8] * time)
        * exp(-phase * 10) * 0.065
      return Float(kick + bass + hat + melody)
    }
  }

  func play(from worldX: Double, stage: Stage, enabled: Bool) {
    guard enabled, let buffer, let source = buffer.floatChannelData?[0] else { return }
    music.stop()
    let offset = Int(worldX / stage.speed * rate) % Int(buffer.frameLength)
    let remaining = Int(buffer.frameLength) - offset
    if offset > 0,
      let tail = AVAudioPCMBuffer(
        pcmFormat: buffer.format, frameCapacity: AVAudioFrameCount(remaining)),
      let output = tail.floatChannelData?[0]
    {
      tail.frameLength = AVAudioFrameCount(remaining)
      output.update(from: source.advanced(by: offset), count: remaining)
      music.scheduleBuffer(tail)
    }
    music.scheduleBuffer(buffer, at: nil, options: .loops)
    if !engine.isRunning { try? engine.start() }
    music.play()
  }

  func stop() {
    music.stop()
    cue.stop()
  }

  func effect(success: Bool, enabled: Bool) {
    guard enabled else { return }
    let sound = makeBuffer(seconds: success ? 0.65 : 0.24) { time in
      let frequency = success ? 523.25 * (1 + floor(time * 6) / 4) : 170 - time * 480
      return Float(sin(2 * .pi * frequency * time) * exp(-time * 7) * 0.24)
    }
    cue.stop()
    cue.scheduleBuffer(sound)
    cue.play()
  }

  private func makeBuffer(seconds: Double, sample: (Double) -> Float) -> AVAudioPCMBuffer {
    let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
    let count = AVAudioFrameCount(seconds * rate)
    let result = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
    result.frameLength = count
    let samples = result.floatChannelData![0]
    for frame in 0..<Int(count) { samples[frame] = sample(Double(frame) / rate) }
    return result
  }
}
