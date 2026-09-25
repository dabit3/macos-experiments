import AVFoundation
import Foundation

final class InstrumentAudio: @unchecked Sendable {
  private let engine = AVAudioEngine()
  private let lock = NSLock()
  private let renderer: RenderMachine
  private var source: AVAudioSourceNode?

  init(pattern: Pattern) { renderer = RenderMachine(pattern: pattern) }

  func prepare() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    try session.setPreferredSampleRate(DrumSynth.sampleRate)
    try session.setPreferredIOBufferDuration(0.005)
    try session.setActive(true)
    if source == nil {
      let format = AVAudioFormat(
        standardFormatWithSampleRate: DrumSynth.sampleRate, channels: 2)!
      let node = AVAudioSourceNode(format: format) { [weak self] _, _, frames, buffers in
        guard let self else { return noErr }
        let list = UnsafeMutableAudioBufferListPointer(buffers)
        self.lock.lock()
        for frame in 0..<Int(frames) {
          let value = self.renderer.nextSample()
          for buffer in list {
            buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = value
          }
        }
        self.lock.unlock()
        return noErr
      }
      engine.attach(node)
      engine.connect(node, to: engine.mainMixerNode, format: format)
      source = node
    }
    if !engine.isRunning {
      engine.prepare()
      try engine.start()
    }
  }

  func update(_ pattern: Pattern) {
    lock.lock()
    renderer.update(pattern)
    lock.unlock()
  }

  func start() throws {
    try prepare()
    lock.lock()
    renderer.start()
    lock.unlock()
  }

  func stop() {
    lock.lock()
    renderer.stop()
    lock.unlock()
  }

  func hit(_ drum: Drum) throws {
    try prepare()
    lock.lock()
    renderer.hit(drum)
    lock.unlock()
  }

  var step: Int {
    lock.lock()
    defer { lock.unlock() }
    return renderer.step
  }
}
