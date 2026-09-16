import AVFoundation
import Foundation

/// Software synth built on AVAudioSourceNode. No bundled audio files.
/// All failures are non-fatal: if the engine cannot start, playback is a no-op.
final class Synth {
  enum Tone { case coin, laneShift, jump, slide, dlss, crash, milestone }

  private struct Voice {
    var samples: [Float]
    var index = 0
  }

  private static let rate: Double = 44100
  private let engine = AVAudioEngine()
  private let lock = NSLock()
  private var voices: [Voice] = []
  private var bassSamples: [Float]
  private var bassTempo: Double = 0
  private var bassClock: Double = 0
  private var running = false

  init() {
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    try? AVAudioSession.sharedInstance().setActive(true)
    bassSamples = Synth.render(0.09) { t in
      let square: Float = sin(2 * .pi * 55 * t) > 0 ? 0.5 : -0.5
      return square * Float(1 - t / 0.09) * 0.35
    }
    guard
      let format = AVAudioFormat(
        standardFormatWithSampleRate: Synth.rate, channels: 1)
    else { return }
    let source = AVAudioSourceNode(format: format) {
      [weak self] _, _, frameCount, list -> OSStatus in
      self?.mix(frameCount: frameCount, list: list) ?? noErr
    }
    engine.attach(source)
    engine.connect(source, to: engine.mainMixerNode, format: format)
    engine.mainMixerNode.outputVolume = 0.5
    do {
      try engine.start()
      running = true
    } catch {
      running = false
    }
  }

  /// Pulses-per-second of the bass loop; 0 silences it.
  func setBass(_ tempo: Double) {
    lock.lock()
    bassTempo = tempo
    lock.unlock()
  }

  func play(_ tone: Tone) {
    guard running else { return }
    lock.lock()
    voices.append(Voice(samples: Synth.tone(tone)))
    lock.unlock()
  }

  private func mix(frameCount: AVAudioFrameCount, list: UnsafeMutablePointer<AudioBufferList>)
    -> OSStatus
  {
    let buffers = UnsafeMutableAudioBufferListPointer(list)
    guard let data = buffers.first?.mData?.assumingMemoryBound(to: Float.self)
    else { return noErr }
    lock.lock()
    defer { lock.unlock() }
    for frame in 0..<Int(frameCount) {
      if bassTempo > 0 {
        bassClock += 1 / Synth.rate
        if bassClock >= 1 / bassTempo {
          bassClock = 0
          voices.append(Voice(samples: bassSamples))
        }
      }
      var sample: Float = 0
      for index in voices.indices where voices[index].index < voices[index].samples.count {
        sample += voices[index].samples[voices[index].index]
        voices[index].index += 1
      }
      data[frame] = max(-1, min(1, sample))
    }
    voices.removeAll { $0.index >= $0.samples.count }
    return noErr
  }

  private static func render(_ duration: Double, _ body: (Double) -> Float) -> [Float] {
    let count = Int(duration * rate)
    return (0..<count).map { body(Double($0) / rate) }
  }

  private static func tone(_ tone: Tone) -> [Float] {
    switch tone {
    case .coin:
      return render(0.12) { t in
        let f: Double = t < 0.05 ? 880 : 1320
        return (sin(2 * .pi * f * t) > 0 ? Float(0.35) : -0.35) * Float(1 - t / 0.12)
      }
    case .laneShift:
      return render(0.09) { t in
        Float(sin(2 * .pi * (300 + 3000 * t) * t)) * Float(1 - t / 0.09) * 0.4
      }
    case .jump:
      return render(0.18) { t in
        Float(sin(2 * .pi * (400 + 2600 * t) * t)) * Float(1 - t / 0.18) * 0.5
      }
    case .slide:
      return render(0.22) { t in
        Float(sin(2 * .pi * max(80, 300 - 1100 * t) * t)) * Float(1 - t / 0.22) * 0.45
      }
    case .dlss:
      return render(0.55) { t in
        var value: Float = 0
        for (index, frequency) in [440.0, 554.37, 659.25, 880.0].enumerated() {
          let start = Double(index) * 0.09
          if t >= start {
            value += Float(sin(2 * .pi * frequency * (t - start))) * 0.22
          }
        }
        return value * Float(1 - t / 0.55)
      }
    case .crash:
      return render(0.6) { t in
        let noise = Float.random(in: -0.5...0.5) * Float(max(0, 1 - t / 0.25))
        let phase = (300 - 380 * t) * t
        let saw = Float(phase - floor(phase)) * 0.8 - 0.4
        return (noise + saw) * Float(max(0, 1 - t / 0.6))
      }
    case .milestone:
      return render(0.3) { t in
        let f: Double = t < 0.13 ? 660 : 990
        return Float(sin(2 * .pi * f * t)) * Float(1 - t / 0.3) * 0.4
      }
    }
  }
}
