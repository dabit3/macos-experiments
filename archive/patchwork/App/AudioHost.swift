import AVFoundation
import Foundation

struct AudioTelemetry {
  var samples: [Float] = Array(repeating: 0, count: 256)
  var rms = 0.0
  var frames: UInt64 = 0
}

final class RenderBridge: @unchecked Sendable {
  private let lock = NSLock()
  private var control = SynthControl(patch: .warm)
  private var telemetry = AudioTelemetry()

  func update(_ control: SynthControl) {
    lock.lock()
    self.control = control
    lock.unlock()
  }

  func snapshot() -> SynthControl {
    lock.lock()
    defer { lock.unlock() }
    return control
  }

  func publish(_ samples: [Float], rms: Double, frames: UInt64) {
    if lock.try() {
      telemetry.samples = samples
      telemetry.rms = rms
      telemetry.frames += frames
      lock.unlock()
    }
  }

  func read() -> AudioTelemetry {
    lock.lock()
    defer { lock.unlock() }
    return telemetry
  }
}

final class AudioHost {
  let engine = AVAudioEngine()
  let bridge = RenderBridge()
  private var source: AVAudioSourceNode?

  func start() throws {
    if engine.isRunning { return }
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    try session.setActive(true)
    if source == nil {
      let rate = session.sampleRate
      guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else {
        throw CocoaError(.coderInvalidValue)
      }
      var kernel = SynthKernel(sampleRate: rate)
      let bridge = bridge
      let node = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList in
        let control = bridge.snapshot()
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        var preview: [Float] = []
        preview.reserveCapacity(Int(frameCount))
        var sum = 0.0
        kernel.render(control: control, frames: Int(frameCount)) { index, sample in
          for buffer in buffers {
            buffer.mData?.assumingMemoryBound(to: Float.self)[index] = sample
          }
          if index < 512 { preview.append(sample) }
          sum += Double(sample * sample)
        }
        bridge.publish(preview, rms: sqrt(sum / Double(frameCount)), frames: UInt64(frameCount))
        return noErr
      }
      engine.attach(node)
      engine.connect(node, to: engine.mainMixerNode, format: format)
      source = node
    }
    try engine.start()
  }

  func pause() { engine.pause() }

  func export(_ patch: Patch, to url: URL) throws {
    let rate = 48000.0
    guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 144000),
      let channel = buffer.floatChannelData?[0]
    else { throw CocoaError(.coderInvalidValue) }
    buffer.frameLength = buffer.frameCapacity
    var kernel = SynthKernel(sampleRate: rate)
    kernel.render(control: SynthControl(patch: patch, hold: true), frames: 144000) { index, value in
      let fade = min(1, Double(index) / 480, Double(143999 - index) / 480)
      channel[index] = value * Float(fade)
    }
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    try file.write(from: buffer)
  }
}
