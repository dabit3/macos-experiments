import AVFoundation
import Foundation

/// Tiny additive synth on an AVAudioSourceNode. Every sound is generated at runtime;
/// nothing is bundled. Voices are short envelopes with optional pitch sweeps.
final class SoundEngine {
  static let shared = SoundEngine()

  enum Cue {
    case move, rotate, softDrop, hardDrop, lock, hold, blocked
    case warp(count: Int)
    case tensorCore
    case tSpin
    case levelUp
    case gameOver
    case uiTap
    case start
  }

  private struct Voice {
    var freqStart: Float
    var freqEnd: Float
    var duration: Float
    var amplitude: Float
    var wave: Int  // 0 sine, 1 square-ish, 2 saw
    var age: Float = 0
    var phase: Float = 0
    var delay: Float = 0
  }

  private let engine = AVAudioEngine()
  private var sourceNode: AVAudioSourceNode?
  private let lock = NSLock()
  private var voices: [Voice] = []
  private var sampleRate: Float = 44_100
  private var running = false

  var isEnabled = true {
    didSet { if isEnabled { start() } }
  }

  private init() {}

  func start() {
    guard !running, isEnabled else { return }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      // Simulator without an audio route: keep going silently.
    }
    let hardware = engine.outputNode.outputFormat(forBus: 0)
    // Simulators without an audio device report a 0 Hz / 0 channel format; stay silent then.
    guard hardware.sampleRate > 0, hardware.channelCount > 0,
      let format = AVAudioFormat(standardFormatWithSampleRate: hardware.sampleRate, channels: 1)
    else { return }
    sampleRate = Float(format.sampleRate)
    let node = AVAudioSourceNode(format: format) {
      [weak self] _, _, frameCount, audioBufferList -> OSStatus in
      guard let self else { return noErr }
      let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
      self.render(frames: Int(frameCount), into: ablPointer)
      return noErr
    }
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: format)
    engine.mainMixerNode.outputVolume = 0.7
    sourceNode = node
    do {
      try engine.start()
      running = true
    } catch {
      running = false
    }
  }

  private func render(frames: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
    lock.lock()
    var active = voices
    lock.unlock()
    let dt = 1 / sampleRate
    for frame in 0..<frames {
      var sample: Float = 0
      for i in active.indices {
        if active[i].delay > 0 {
          active[i].delay -= dt
          continue
        }
        let v = active[i]
        guard v.age < v.duration else { continue }
        let t = v.age / v.duration
        let freq = v.freqStart + (v.freqEnd - v.freqStart) * t
        active[i].phase += freq * dt
        if active[i].phase > 1 { active[i].phase -= 1 }
        let p = active[i].phase
        let raw: Float
        switch v.wave {
        case 1: raw = tanh(sin(p * 2 * .pi) * 3) * 0.7
        case 2: raw = (p * 2 - 1) * 0.6
        default: raw = sin(p * 2 * .pi)
        }
        let attack = min(1, v.age / 0.006)
        let release = 1 - t
        sample += raw * v.amplitude * attack * release * release
        active[i].age += dt
      }
      sample = max(-1, min(1, sample))
      for buffer in buffers {
        let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
        ptr[frame] = sample
      }
    }
    lock.lock()
    // Merge state back: keep newly enqueued voices that arrived during render.
    let newlyAdded =
      voices.count > active.count ? Array(voices.suffix(voices.count - active.count)) : []
    voices = active.filter { $0.age < $0.duration } + newlyAdded
    lock.unlock()
  }

  private func enqueue(_ v: Voice) {
    guard isEnabled, running else { return }
    lock.lock()
    if voices.count < 24 { voices.append(v) }
    lock.unlock()
  }

  func play(_ cue: Cue) {
    switch cue {
    case .move:
      enqueue(Voice(freqStart: 620, freqEnd: 560, duration: 0.035, amplitude: 0.12, wave: 1))
    case .rotate:
      enqueue(Voice(freqStart: 740, freqEnd: 980, duration: 0.06, amplitude: 0.14, wave: 0))
    case .softDrop:
      enqueue(Voice(freqStart: 300, freqEnd: 280, duration: 0.025, amplitude: 0.06, wave: 1))
    case .hardDrop:
      enqueue(Voice(freqStart: 900, freqEnd: 120, duration: 0.11, amplitude: 0.25, wave: 2))
    case .lock:
      enqueue(Voice(freqStart: 180, freqEnd: 90, duration: 0.09, amplitude: 0.22, wave: 1))
    case .hold:
      enqueue(Voice(freqStart: 520, freqEnd: 780, duration: 0.08, amplitude: 0.12, wave: 0))
      enqueue(
        Voice(freqStart: 780, freqEnd: 1040, duration: 0.08, amplitude: 0.1, wave: 0, delay: 0.05))
    case .blocked:
      enqueue(Voice(freqStart: 160, freqEnd: 140, duration: 0.05, amplitude: 0.1, wave: 1))
    case .warp(let count):
      let base: Float = 440
      for i in 0..<max(1, min(count, 3)) {
        let f = base * pow(1.5, Float(i))
        enqueue(
          Voice(
            freqStart: f, freqEnd: f * 1.01, duration: 0.18, amplitude: 0.18, wave: 0,
            delay: Float(i) * 0.06))
      }
      enqueue(Voice(freqStart: 2200, freqEnd: 400, duration: 0.15, amplitude: 0.08, wave: 2))
    case .tensorCore:
      // Ascending major chord "power-up" with a sub thump.
      let notes: [Float] = [523.25, 659.25, 783.99, 1046.5, 1318.5]
      for (i, f) in notes.enumerated() {
        enqueue(
          Voice(
            freqStart: f, freqEnd: f, duration: 0.45, amplitude: 0.16, wave: 0,
            delay: Float(i) * 0.055))
      }
      enqueue(Voice(freqStart: 80, freqEnd: 40, duration: 0.5, amplitude: 0.35, wave: 0))
      enqueue(
        Voice(freqStart: 3000, freqEnd: 6000, duration: 0.5, amplitude: 0.05, wave: 2, delay: 0.1))
    case .tSpin:
      enqueue(Voice(freqStart: 880, freqEnd: 1320, duration: 0.14, amplitude: 0.16, wave: 0))
      enqueue(
        Voice(freqStart: 1320, freqEnd: 1760, duration: 0.2, amplitude: 0.14, wave: 0, delay: 0.1))
    case .levelUp:
      let notes: [Float] = [392, 523.25, 659.25, 783.99]
      for (i, f) in notes.enumerated() {
        enqueue(
          Voice(
            freqStart: f, freqEnd: f, duration: 0.22, amplitude: 0.15, wave: 1,
            delay: Float(i) * 0.09))
      }
    case .gameOver:
      let notes: [Float] = [440, 349.23, 293.66, 220]
      for (i, f) in notes.enumerated() {
        enqueue(
          Voice(
            freqStart: f, freqEnd: f * 0.97, duration: 0.5, amplitude: 0.2, wave: 2,
            delay: Float(i) * 0.22))
      }
    case .uiTap:
      enqueue(Voice(freqStart: 1000, freqEnd: 1200, duration: 0.04, amplitude: 0.1, wave: 0))
    case .start:
      let notes: [Float] = [261.63, 329.63, 392, 523.25]
      for (i, f) in notes.enumerated() {
        enqueue(
          Voice(
            freqStart: f, freqEnd: f, duration: 0.3, amplitude: 0.14, wave: 0,
            delay: Float(i) * 0.07))
      }
    }
  }
}
