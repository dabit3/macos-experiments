import AVFoundation
import Foundation

final class RenderControl: @unchecked Sendable {
  private let lock = NSLock()
  private var pattern = Pattern.presets[0]
  private var playing = false
  private var generation = 0
  private var step = -1
  private var peak: Float = 0

  func update(pattern: Pattern) {
    lock.lock()
    self.pattern = pattern
    lock.unlock()
  }

  func transport(playing: Bool) {
    lock.lock()
    self.playing = playing
    generation += 1
    step = -1
    peak = 0
    lock.unlock()
  }

  func snapshot() -> (Pattern, Bool, Int) {
    lock.lock()
    defer { lock.unlock() }
    return (pattern, playing, generation)
  }

  func publish(step: Int, peak: Float) {
    lock.lock()
    self.step = step
    self.peak = peak
    lock.unlock()
  }

  func meter() -> (Int, Float) {
    lock.lock()
    defer { lock.unlock() }
    return (step, peak)
  }
}

final class DrumRenderer {
  let control: RenderControl
  let sampleRate: Double
  let sounds: [[Float]]
  private var cursors = Array(repeating: Int.max, count: 4)
  private var generation = -1
  private var step = -1
  private var remaining = 0.0

  init(control: RenderControl, sampleRate: Double) {
    self.control = control
    self.sampleRate = sampleRate
    sounds = Drum.allCases.map { DrumSynth.sample(drum: $0, sampleRate: sampleRate) }
  }

  func render(frameCount: Int, buffers: UnsafeMutableAudioBufferListPointer) {
    let (pattern, playing, newGeneration) = control.snapshot()
    if newGeneration != generation {
      generation = newGeneration
      step = -1
      remaining = 0
      for index in 0..<4 { cursors[index] = Int.max }
    }
    let active = pattern.activeMask
    var peak: Float = 0
    for frame in 0..<frameCount {
      var signal: Float = 0
      if playing {
        if remaining <= 0 {
          step = (step + 1) % 16
          for track in 0..<4 where pattern.steps[track][step] && active & (1 << track) != 0 {
            cursors[track] = 0
          }
          remaining +=
            SequencerClock.duration(step: step, tempo: pattern.tempo, swing: pattern.swing)
            * sampleRate
        }
        for track in 0..<4 where cursors[track] < sounds[track].count {
          if active & (1 << track) != 0 { signal += sounds[track][cursors[track]] }
          cursors[track] += 1
        }
        signal = tanh(signal * 0.72)
        remaining -= 1
      }
      peak = max(peak, abs(signal))
      for buffer in buffers {
        buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = signal
      }
    }
    control.publish(step: playing ? step : -1, peak: peak)
  }
}

@MainActor
final class TapeAudio {
  private let engine = AVAudioEngine()
  let control = RenderControl()
  private var source: AVAudioSourceNode?

  func start(pattern: Pattern) throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default)
    try session.setPreferredIOBufferDuration(0.005)
    try session.setActive(true)
    let outputFormat = engine.outputNode.inputFormat(forBus: 0)
    guard outputFormat.sampleRate.isFinite, outputFormat.sampleRate > 0,
      outputFormat.channelCount > 0
    else {
      try? session.setActive(false)
      throw CocoaError(.featureUnsupported)
    }
    if source == nil {
      let sampleRate = outputFormat.sampleRate
      guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
      else { throw CocoaError(.featureUnsupported) }
      let renderer = DrumRenderer(control: control, sampleRate: sampleRate)
      let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
        renderer.render(
          frameCount: Int(frameCount),
          buffers: UnsafeMutableAudioBufferListPointer(audioBufferList))
        return noErr
      }
      engine.attach(node)
      engine.connect(node, to: engine.mainMixerNode, format: format)
      source = node
    }
    control.update(pattern: pattern)
    control.transport(playing: true)
    do {
      try engine.start()
    } catch {
      control.transport(playing: false)
      throw error
    }
  }

  func stop() {
    control.transport(playing: false)
    engine.pause()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}
