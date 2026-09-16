import AVFoundation
import Foundation

/// Tiny additive synthesizer on AVAudioEngine. Every cue is generated at runtime;
/// nothing is bundled.
final class Synth {
  enum Cue {
    case click
    case connect(pitch: Double)
    case short
    case deny
    case melt
    case powerUp
    case bootChime
    case fail
  }

  private struct Voice {
    enum Wave { case sine, square, saw, noise, triangle }
    var wave: Wave
    var frequency: Double
    var endFrequency: Double
    var amplitude: Double
    var attack: Double
    var decay: Double
    var delay: Double
    var phase: Double = 0
    var age: Double = 0
    var lowpass: Double = 0
    var lastNoise: Double = 0

    var finished: Bool { age > delay + attack + decay }

    mutating func sample(dt: Double, rng: inout UInt32) -> Double {
      age += dt
      let t = age - delay
      guard t >= 0 else { return 0 }
      let env: Double
      if t < attack {
        env = t / max(attack, 0.0001)
      } else {
        let d = (t - attack) / max(decay, 0.0001)
        env = max(0, 1 - d) * max(0, 1 - d)
      }
      let progress = min(1, t / max(attack + decay, 0.0001))
      let f = frequency + (endFrequency - frequency) * progress
      phase += f * dt
      if phase > 1 { phase -= floor(phase) }
      var v: Double
      switch wave {
      case .sine: v = sin(phase * 2 * .pi)
      case .square: v = phase < 0.5 ? 1 : -1
      case .saw: v = phase * 2 - 1
      case .triangle: v = abs(phase * 4 - 2) - 1
      case .noise:
        rng = rng &* 1_664_525 &+ 1_013_904_223
        let white = Double(rng >> 8) / Double(1 << 24) * 2 - 1
        // One-pole low-pass keeps hiss from being harsh.
        lastNoise += (white - lastNoise) * (lowpass > 0 ? lowpass : 1)
        v = lastNoise
      }
      return v * env * amplitude
    }
  }

  var enabled = true {
    didSet { if !enabled { lock.withLock { voices.removeAll() } } }
  }

  private let engine = AVAudioEngine()
  private var node: AVAudioSourceNode?
  private var voices: [Voice] = []
  private let lock = NSLock()
  private var noiseState: UInt32 = 0x1234_5678
  private var sizzleTarget: Double = 0
  private var sizzleLevel: Double = 0
  private var sizzleNoise: Double = 0
  private var sampleRate: Double = 44100
  private var started = false

  init() {
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    let format = engine.outputNode.inputFormat(forBus: 0)
    sampleRate = format.sampleRate > 0 ? format.sampleRate : 44100
    let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let node = AVAudioSourceNode(format: mono) {
      [weak self] _, _, frameCount, buffers -> OSStatus in
      guard let self else { return noErr }
      let abl = UnsafeMutableAudioBufferListPointer(buffers)
      guard let out = abl[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
      self.render(into: out, count: Int(frameCount))
      return noErr
    }
    self.node = node
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: mono)
    engine.mainMixerNode.outputVolume = 0.8
    start()
  }

  private func start() {
    guard !started else { return }
    do {
      try AVAudioSession.sharedInstance().setActive(true)
      try engine.start()
      started = true
    } catch {
      started = false
    }
  }

  private func render(into out: UnsafeMutablePointer<Float>, count: Int) {
    let dt = 1 / sampleRate
    lock.lock()
    defer { lock.unlock() }
    var rng = noiseState
    let target = sizzleTarget
    var level = sizzleLevel
    var sizz = sizzleNoise
    for i in 0..<count {
      var mix = 0.0
      for v in voices.indices { mix += voices[v].sample(dt: dt, rng: &rng) }
      level += (target - level) * 0.0005
      if level > 0.001 {
        rng = rng &* 1_664_525 &+ 1_013_904_223
        let white = Double(rng >> 8) / Double(1 << 24) * 2 - 1
        sizz += (white - sizz) * 0.35
        // Crackle: gate the noise randomly for a frying-pan texture.
        let gate = (rng >> 20) % 7 == 0 ? 1.0 : 0.25
        mix += sizz * gate * level * 0.22
      }
      out[i] = Float(max(-1, min(1, mix)))
    }
    sizzleLevel = level
    sizzleNoise = sizz
    voices.removeAll { $0.finished }
    noiseState = rng
  }

  /// Continuous frying hiss whose loudness follows the hottest cable on the board.
  func setSizzle(_ heat: Double) {
    lock.withLock { sizzleTarget = enabled ? max(0, min(1, heat)) : 0 }
  }

  func play(_ cue: Cue) {
    guard enabled else { return }
    start()
    var new: [Voice] = []
    switch cue {
    case .click:
      new.append(
        Voice(
          wave: .triangle, frequency: 1800, endFrequency: 900, amplitude: 0.22, attack: 0.002,
          decay: 0.045, delay: 0))
      new.append(
        Voice(
          wave: .noise, frequency: 0, endFrequency: 0, amplitude: 0.08, attack: 0.001, decay: 0.03,
          delay: 0, lowpass: 0.5))
    case .connect(let pitch):
      let base = 440.0 * pow(2, Double(Int(pitch) % 8) / 12)
      new.append(
        Voice(
          wave: .sine, frequency: base, endFrequency: base, amplitude: 0.25, attack: 0.005,
          decay: 0.18, delay: 0))
      new.append(
        Voice(
          wave: .triangle, frequency: base * 2, endFrequency: base * 2.01, amplitude: 0.12,
          attack: 0.005, decay: 0.12, delay: 0.01))
      new.append(
        Voice(
          wave: .noise, frequency: 0, endFrequency: 0, amplitude: 0.05, attack: 0.001, decay: 0.05,
          delay: 0, lowpass: 0.8))
    case .short:
      new.append(
        Voice(
          wave: .square, frequency: 160, endFrequency: 90, amplitude: 0.18, attack: 0.005,
          decay: 0.3, delay: 0))
      new.append(
        Voice(
          wave: .noise, frequency: 0, endFrequency: 0, amplitude: 0.14, attack: 0.001, decay: 0.2,
          delay: 0, lowpass: 0.9))
    case .deny:
      new.append(
        Voice(
          wave: .square, frequency: 220, endFrequency: 200, amplitude: 0.12, attack: 0.005,
          decay: 0.09, delay: 0))
    case .melt:
      new.append(
        Voice(
          wave: .noise, frequency: 0, endFrequency: 0, amplitude: 0.35, attack: 0.01, decay: 0.5,
          delay: 0, lowpass: 0.6))
      new.append(
        Voice(
          wave: .saw, frequency: 300, endFrequency: 40, amplitude: 0.18, attack: 0.01, decay: 0.45,
          delay: 0))
    case .powerUp:
      new.append(
        Voice(
          wave: .sine, frequency: 110, endFrequency: 220, amplitude: 0.2, attack: 0.05, decay: 0.5,
          delay: 0))
      new.append(
        Voice(
          wave: .noise, frequency: 0, endFrequency: 0, amplitude: 0.05, attack: 0.2, decay: 0.5,
          delay: 0, lowpass: 0.15))
    case .bootChime:
      // Boot arpeggio, then the fans spin up underneath.
      let notes: [Double] = [523.25, 659.25, 783.99, 1046.5, 1318.5]
      for (i, f) in notes.enumerated() {
        let d = Double(i) * 0.11
        new.append(
          Voice(
            wave: .sine, frequency: f, endFrequency: f, amplitude: 0.22, attack: 0.01, decay: 0.55,
            delay: d))
        new.append(
          Voice(
            wave: .triangle, frequency: f * 2, endFrequency: f * 2, amplitude: 0.06, attack: 0.01,
            decay: 0.3, delay: d))
      }
      new.append(
        Voice(
          wave: .sine, frequency: 261.6, endFrequency: 261.6, amplitude: 0.16, attack: 0.02,
          decay: 1.4, delay: 0.44))
      new.append(
        Voice(
          wave: .noise, frequency: 0, endFrequency: 0, amplitude: 0.12, attack: 0.9, decay: 1.6,
          delay: 0.3, lowpass: 0.08))
      new.append(
        Voice(
          wave: .sine, frequency: 60, endFrequency: 140, amplitude: 0.12, attack: 0.8, decay: 1.5,
          delay: 0.3))
    case .fail:
      new.append(
        Voice(
          wave: .square, frequency: 220, endFrequency: 110, amplitude: 0.16, attack: 0.01,
          decay: 0.6, delay: 0))
      new.append(
        Voice(
          wave: .square, frequency: 233, endFrequency: 116, amplitude: 0.12, attack: 0.01,
          decay: 0.6, delay: 0.05))
      new.append(
        Voice(
          wave: .sine, frequency: 80, endFrequency: 30, amplitude: 0.2, attack: 0.05, decay: 0.9,
          delay: 0.1))
    }
    lock.withLock {
      voices.append(contentsOf: new)
      if voices.count > 48 { voices.removeFirst(voices.count - 48) }
    }
  }
}
