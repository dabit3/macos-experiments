import AVFoundation
import Foundation

/// Tiny polyphonic synthesizer rendered through an AVAudioSourceNode. Every
/// sound in the game is described as a handful of parameters; nothing is
/// bundled or licensed.
final class Synth {
  enum Sound {
    case slice(pitch: Int)
    case defective
    case flagship
    case binning
    case launch
    case tick
    case click
    case gameOver
    case lifeBack
  }

  private struct Voice {
    enum Wave { case sine, saw, square, noise }
    var wave: Wave
    var startFrequency: Double
    var endFrequency: Double
    var duration: Double
    var attack: Double
    var amplitude: Double
    var delay: Double
    var phase: Double = 0
    var time: Double = 0
    var noiseState: UInt32 = 0x1234_5678
    var lowpass: Double = 0

    var finished: Bool { time >= delay + duration }

    mutating func sample(sampleRate: Double) -> Double {
      defer { time += 1 / sampleRate }
      guard time >= delay else { return 0 }
      let local = time - delay
      let progress = min(1, local / duration)
      let frequency = startFrequency + (endFrequency - startFrequency) * progress
      phase += frequency / sampleRate
      if phase >= 1 { phase -= floor(phase) }
      let envelope: Double
      if local < attack {
        envelope = local / attack
      } else {
        envelope = pow(1 - progress, 2.2)
      }
      var value: Double
      switch wave {
      case .sine: value = sin(phase * 2 * .pi)
      case .saw: value = phase * 2 - 1
      case .square: value = phase < 0.5 ? 1 : -1
      case .noise:
        noiseState ^= noiseState << 13
        noiseState ^= noiseState >> 17
        noiseState ^= noiseState << 5
        let white = Double(noiseState) / Double(UInt32.max) * 2 - 1
        // Simple one-pole lowpass whose cutoff follows the frequency sweep.
        let coefficient = min(0.98, max(0.02, 1 - exp(-2 * .pi * frequency / sampleRate)))
        lowpass += coefficient * (white - lowpass)
        value = lowpass * 2.5
      }
      return value * envelope * amplitude
    }
  }

  private let engine = AVAudioEngine()
  private var sourceNode: AVAudioSourceNode?
  private var voices: [Voice] = []
  private let lock = NSLock()
  private var sampleRate: Double = 44_100
  private(set) var isRunning = false
  var enabled = true

  init() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    try? session.setActive(true)
    let hardware = engine.outputNode.outputFormat(forBus: 0)
    sampleRate = hardware.sampleRate > 0 ? hardware.sampleRate : 44_100
    guard
      let format = AVAudioFormat(
        standardFormatWithSampleRate: sampleRate, channels: max(1, min(2, hardware.channelCount)))
    else { return }
    let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList in
      guard let self else { return noErr }
      let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
      self.lock.lock()
      defer { self.lock.unlock() }
      let sampleRate = self.sampleRate
      for frame in 0..<Int(frameCount) {
        var mix = 0.0
        for index in self.voices.indices {
          mix += self.voices[index].sample(sampleRate: sampleRate)
        }
        let sample = Float(tanh(mix))
        for buffer in buffers {
          guard let data = buffer.mData else { continue }
          data.assumingMemoryBound(to: Float.self)[frame] = sample
        }
      }
      self.voices.removeAll { $0.finished }
      return noErr
    }
    sourceNode = node
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: format)
    engine.mainMixerNode.outputVolume = 0.8
    start()
  }

  func start() {
    guard !isRunning else { return }
    do {
      try engine.start()
      isRunning = true
    } catch {
      isRunning = false
    }
  }

  func stop() {
    engine.pause()
    isRunning = false
  }

  private func queue(_ newVoices: [Voice]) {
    guard enabled else { return }
    if !isRunning { start() }
    lock.lock()
    voices.append(contentsOf: newVoices)
    if voices.count > 48 { voices.removeFirst(voices.count - 48) }
    lock.unlock()
  }

  func play(_ sound: Sound) {
    switch sound {
    case .slice(let pitch):
      let base = 520.0 * pow(1.12, Double(min(pitch, 8)))
      queue([
        Voice(
          wave: .noise, startFrequency: 6000, endFrequency: 900, duration: 0.12, attack: 0.002,
          amplitude: 0.5, delay: 0),
        Voice(
          wave: .sine, startFrequency: base * 1.8, endFrequency: base, duration: 0.14,
          attack: 0.003, amplitude: 0.35, delay: 0),
      ])
    case .defective:
      queue([
        Voice(
          wave: .saw, startFrequency: 140, endFrequency: 55, duration: 0.45, attack: 0.005,
          amplitude: 0.5, delay: 0),
        Voice(
          wave: .square, startFrequency: 70, endFrequency: 40, duration: 0.45, attack: 0.005,
          amplitude: 0.25, delay: 0),
        Voice(
          wave: .noise, startFrequency: 1200, endFrequency: 200, duration: 0.35, attack: 0.002,
          amplitude: 0.45, delay: 0),
      ])
    case .flagship:
      let notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
      queue(
        notes.enumerated().map { index, frequency in
          Voice(
            wave: .sine, startFrequency: frequency, endFrequency: frequency * 1.002,
            duration: 0.55, attack: 0.01, amplitude: 0.28, delay: Double(index) * 0.07)
        }
          + [
            Voice(
              wave: .noise, startFrequency: 9000, endFrequency: 3000, duration: 0.6, attack: 0.05,
              amplitude: 0.12, delay: 0)
          ])
    case .binning:
      queue([
        Voice(
          wave: .square, startFrequency: 660, endFrequency: 660, duration: 0.12, attack: 0.005,
          amplitude: 0.18, delay: 0),
        Voice(
          wave: .square, startFrequency: 880, endFrequency: 880, duration: 0.12, attack: 0.005,
          amplitude: 0.18, delay: 0.09),
        Voice(
          wave: .sine, startFrequency: 1320, endFrequency: 1320, duration: 0.3, attack: 0.005,
          amplitude: 0.3, delay: 0.18),
      ])
    case .launch:
      queue([
        Voice(
          wave: .noise, startFrequency: 300, endFrequency: 1800, duration: 0.25, attack: 0.08,
          amplitude: 0.09, delay: 0)
      ])
    case .tick:
      queue([
        Voice(
          wave: .square, startFrequency: 1200, endFrequency: 1200, duration: 0.05, attack: 0.002,
          amplitude: 0.15, delay: 0)
      ])
    case .click:
      queue([
        Voice(
          wave: .sine, startFrequency: 900, endFrequency: 600, duration: 0.07, attack: 0.002,
          amplitude: 0.25, delay: 0)
      ])
    case .gameOver:
      let notes = [659.25, 523.25, 392.0, 261.63]
      queue(
        notes.enumerated().map { index, frequency in
          Voice(
            wave: .saw, startFrequency: frequency, endFrequency: frequency * 0.99, duration: 0.4,
            attack: 0.01, amplitude: 0.16, delay: Double(index) * 0.16)
        })
    case .lifeBack:
      queue([
        Voice(
          wave: .sine, startFrequency: 440, endFrequency: 880, duration: 0.25, attack: 0.01,
          amplitude: 0.25, delay: 0)
      ])
    }
  }
}
