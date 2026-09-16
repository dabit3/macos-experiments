import AVFoundation

final class SoundEngine {
  static let shared = SoundEngine()
  private let engine = AVAudioEngine()
  private var source: AVAudioSourceNode?
  private var phase = 0.0

  private init() {}

  private func play(frequencies: [Double], duration: Double = 0.08) {
    guard source == nil else { return }
    let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    var elapsed = 0.0
    let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
      guard let self, let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList).first
      else { return noErr }
      let sampleRate = 44_100.0
      let count = Int(frameCount)
      let buffer = buffers.mData?.assumingMemoryBound(to: Float.self)
      for index in 0..<count {
        let t = elapsed
        let frequency = frequencies[
          min(Int(t / duration * Double(frequencies.count)), frequencies.count - 1)]
        let envelope = max(0, 1 - t / duration)
        buffer?[index] = Float(sin(self.phase) * envelope * 0.16)
        self.phase += 2 * .pi * frequency / sampleRate
        elapsed += 1 / sampleRate
      }
      if elapsed >= duration { self.stop() }
      return noErr
    }
    source = node
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: format)
    do {
      try engine.start()
    } catch {
      stop()
    }
  }

  private func stop() {
    engine.stop()
    if let source {
      engine.detach(source)
      self.source = nil
    }
  }

  func playTick(marked: Bool) { play(frequencies: [marked ? 880 : 440], duration: 0.04) }
  func playOneAway() { play(frequencies: [660, 990], duration: 0.12) }
  func playFanfare() { play(frequencies: [523, 659, 784, 1047], duration: 0.4) }
}
