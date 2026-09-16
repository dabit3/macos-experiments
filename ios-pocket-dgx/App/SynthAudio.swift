import AVFoundation
import Foundation

/// All sound is synthesized live: a fan hum whose pitch follows fan speed,
/// plus short one-shot cues (boot chime, power-down, shutter click, tick).
final class SynthAudio {
  private let engine = AVAudioEngine()
  private var source: AVAudioSourceNode?
  private let sampleRate: Double = 44_100
  private let lock = NSLock()

  private var fanLevel: Float = 0
  private var fanTarget: Float = 0
  private var humPhase: Float = 0
  private var whinePhase: Float = 0
  private var noise: UInt32 = 0x1234_5678
  private var lowpass: Float = 0

  private struct Voice {
    var frequency: Float
    var phase: Float = 0
    var remaining: Int
    var total: Int
    var amplitude: Float
    var shape: Int  // 0 sine, 1 square-ish click, 2 saw
  }
  private var voices: [Voice] = []
  var enabled = true {
    didSet {
      if !enabled {
        lock.lock()
        voices.removeAll()
        lock.unlock()
      }
    }
  }

  init() {
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, buffers in
      guard let self else { return noErr }
      let list = UnsafeMutableAudioBufferListPointer(buffers)
      guard let pointer = list[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
      self.render(into: pointer, count: Int(frameCount))
      return noErr
    }
    source = node
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: format)
    engine.mainMixerNode.outputVolume = 0.8
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    try? AVAudioSession.sharedInstance().setActive(true)
    try? engine.start()
  }

  func setFan(_ level: Double) {
    lock.lock()
    fanTarget = Float(min(1, max(0, level)))
    lock.unlock()
  }

  func bootChime() {
    guard enabled else { return }
    var offset = 0
    for note in [392.0, 523.25, 659.25, 783.99] {
      add(frequency: Float(note), duration: 0.32, amplitude: 0.18, shape: 0, delay: offset)
      offset += Int(sampleRate * 0.11)
    }
    add(
      frequency: 1567.98, duration: 0.6, amplitude: 0.1, shape: 0,
      delay: offset + Int(sampleRate * 0.05))
  }

  func powerDown() {
    guard enabled else { return }
    var offset = 0
    for note in [659.25, 523.25, 392.0] {
      add(frequency: Float(note), duration: 0.26, amplitude: 0.16, shape: 2, delay: offset)
      offset += Int(sampleRate * 0.13)
    }
  }

  func shutter() {
    guard enabled else { return }
    add(frequency: 2400, duration: 0.03, amplitude: 0.35, shape: 1, delay: 0)
    add(frequency: 1200, duration: 0.05, amplitude: 0.25, shape: 1, delay: Int(sampleRate * 0.06))
  }

  func tick() {
    guard enabled else { return }
    add(frequency: 1800, duration: 0.025, amplitude: 0.16, shape: 0, delay: 0)
  }

  func scaleWhoosh(up: Bool) {
    guard enabled else { return }
    add(frequency: up ? 220 : 440, duration: 0.18, amplitude: 0.12, shape: 2, delay: 0)
    add(
      frequency: up ? 440 : 220, duration: 0.18, amplitude: 0.12, shape: 2,
      delay: Int(sampleRate * 0.08))
  }

  private func add(frequency: Float, duration: Double, amplitude: Float, shape: Int, delay: Int) {
    let samples = Int(duration * sampleRate)
    lock.lock()
    voices.append(
      Voice(
        frequency: frequency, phase: 0, remaining: samples + delay, total: samples,
        amplitude: amplitude, shape: shape))
    lock.unlock()
  }

  private func render(into pointer: UnsafeMutablePointer<Float>, count: Int) {
    lock.lock()
    defer { lock.unlock() }
    let fanOn = enabled ? fanTarget : 0
    for index in 0..<count {
      fanLevel += (fanOn - fanLevel) * 0.00008
      // Fan: filtered noise plus a low hum and a faint blade whine that rise with speed.
      noise = noise &* 1_664_525 &+ 1_013_904_223
      let white = Float(Int32(bitPattern: noise)) / Float(Int32.max)
      lowpass += (white - lowpass) * (0.02 + fanLevel * 0.06)
      let humFrequency = 48 + fanLevel * 40
      humPhase += humFrequency / Float(sampleRate)
      if humPhase > 1 { humPhase -= 1 }
      whinePhase += (humFrequency * 7) / Float(sampleRate)
      if whinePhase > 1 { whinePhase -= 1 }
      var sample =
        fanLevel
        * (lowpass * 0.22 + sinf(humPhase * 2 * .pi) * 0.05 + sinf(whinePhase * 2 * .pi) * 0.012
          * fanLevel)
      var voiceIndex = 0
      while voiceIndex < voices.count {
        var voice = voices[voiceIndex]
        if voice.remaining > voice.total {
          voice.remaining -= 1
          voices[voiceIndex] = voice
          voiceIndex += 1
          continue
        }
        let progress = 1 - Float(voice.remaining) / Float(max(1, voice.total))
        let envelope = min(1, progress * 12) * (1 - progress) * (1 - progress)
        voice.phase += voice.frequency / Float(sampleRate)
        if voice.phase > 1 { voice.phase -= 1 }
        let wave: Float
        switch voice.shape {
        case 1: wave = voice.phase < 0.5 ? 1 : -1
        case 2: wave = (voice.phase * 2 - 1) * 0.7 + sinf(voice.phase * 2 * .pi) * 0.3
        default: wave = sinf(voice.phase * 2 * .pi)
        }
        sample += wave * envelope * voice.amplitude
        voice.remaining -= 1
        if voice.remaining <= 0 {
          voices.remove(at: voiceIndex)
        } else {
          voices[voiceIndex] = voice
          voiceIndex += 1
        }
      }
      pointer[index] = max(-1, min(1, sample))
    }
  }
}
