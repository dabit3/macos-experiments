import AVFoundation
import XCTest

@testable import PatchworkCore

final class PatchworkCoreTests: XCTestCase {
  func testGraphRejectsCyclesAndOccupiedInputs() throws {
    var patch = Patch.blank
    try patch.connect(.filter, to: .envelope)
    XCTAssertThrowsError(try patch.connect(.envelope, to: .filter)) {
      XCTAssertEqual($0 as? PatchError, .cycle)
    }
    try patch.connect(.oscillator, to: .filter)
    XCTAssertThrowsError(try patch.connect(.oscillator, to: .envelope)) {
      XCTAssertEqual($0 as? PatchError, .occupiedInput)
    }
    XCTAssertThrowsError(try patch.connect(.output, to: .oscillator))
    XCTAssertThrowsError(try patch.connect(.filter, to: .filter))
    try patch.connect(.envelope, to: .output)
    XCTAssertEqual(patch.signalPath, [.oscillator, .filter, .envelope, .output])
    patch.cables.removeAll { $0.destination == .filter }
    XCTAssertTrue(patch.signalPath.isEmpty)
  }

  func testLibraryRoundTripAndInvalidValues() throws {
    let library = PatchLibrary(current: .warm, saved: [.glass, .velvet])
    let decoded = try JSONDecoder().decode(
      PatchLibrary.self, from: JSONEncoder().encode(library)
    ).validated()
    XCTAssertEqual(decoded.current, library.current)
    XCTAssertEqual(decoded.saved, library.saved)
    var malformed = Patch.warm
    malformed.cutoff = -20
    XCTAssertThrowsError(try malformed.validated())
    malformed = .warm
    malformed.frequency = .nan
    XCTAssertThrowsError(try malformed.validated())
    malformed = .warm
    malformed.cables.append(Cable(source: .envelope, destination: .filter))
    XCTAssertThrowsError(try malformed.validated())
  }

  func testEveryPresetAndWaveformProducesFiniteBoundedAudio() throws {
    for preset in Patch.presets {
      _ = try preset.validated()
      for shape in WaveShape.allCases {
        var patch = preset
        patch.shape = shape
        let samples = render(patch, seconds: 0.5)
        XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 1 })
        if patch.signalPath.isEmpty {
          XCTAssertEqual(rms(samples), 0)
        } else {
          XCTAssertGreaterThan(rms(samples), 0.015)
        }
      }
    }
  }

  func testPitchAndFilterAttenuation() {
    var patch = Patch.glass
    patch.frequency = 440
    let samples = render(patch, seconds: 1)
    let tail = Array(samples.suffix(24000))
    let crossings = zip(tail, tail.dropFirst()).filter { $0 < 0 && $1 >= 0 }.count
    XCTAssertEqual(Double(crossings) * 2, 440, accuracy: 3)
    patch.cables = [
      Cable(source: .oscillator, destination: .filter),
      Cable(source: .filter, destination: .output),
    ]
    patch.frequency = 900
    patch.cutoff = 100
    let dark = rms(Array(render(patch, seconds: 1).suffix(24000)))
    patch.cutoff = 10000
    let bright = rms(Array(render(patch, seconds: 1).suffix(24000)))
    XCTAssertLessThan(dark, bright * 0.05)
  }

  func testDisconnectAndZeroVolumeRenderSilence() {
    var patch = Patch.warm
    patch.cables.removeAll { $0.destination == .output }
    XCTAssertEqual(rms(render(patch, seconds: 0.2)), 0)
    patch = .warm
    patch.volume = 0
    XCTAssertEqual(rms(render(patch, seconds: 0.2)), 0)
  }

  func testEnvelopeDecayAndHoldBypass() {
    var patch = Patch.glass
    patch.decay = 0.15
    let pluck = render(patch, seconds: 1, hold: false)
    XCTAssertGreaterThan(rms(Array(pluck.prefix(4800))), 0.05)
    XCTAssertLessThan(rms(Array(pluck.suffix(4800))), 0.0001)
    XCTAssertGreaterThan(rms(Array(render(patch, seconds: 1).suffix(4800))), 0.1)
  }

  func testAVAudioEngineOfflineRenderingIsNonzeroThenSilent() throws {
    let engine = AVAudioEngine()
    let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 1024)
    var kernel = SynthKernel(sampleRate: 48000)
    var control = SynthControl(patch: .warm, hold: true)
    let source = AVAudioSourceNode(format: format) { _, _, count, list in
      let buffers = UnsafeMutableAudioBufferListPointer(list)
      kernel.render(control: control, frames: Int(count)) { index, sample in
        for buffer in buffers {
          buffer.mData?.assumingMemoryBound(to: Float.self)[index] = sample
        }
      }
      return noErr
    }
    engine.attach(source)
    engine.connect(source, to: engine.mainMixerNode, format: format)
    try engine.start()
    defer { engine.stop() }
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024))
    var maximumRMS = 0.0
    for _ in 0..<12 {
      XCTAssertEqual(try engine.renderOffline(1024, to: buffer), .success)
      let channel = try XCTUnwrap(buffer.floatChannelData?[0])
      maximumRMS = max(maximumRMS, rms(Array(UnsafeBufferPointer(start: channel, count: 1024))))
    }
    XCTAssertGreaterThan(maximumRMS, 0.05)
    control.patch.cables = []
    for _ in 0..<3 {
      XCTAssertEqual(try engine.renderOffline(1024, to: buffer), .success)
    }
    let channel = try XCTUnwrap(buffer.floatChannelData?[0])
    XCTAssertEqual(rms(Array(UnsafeBufferPointer(start: channel, count: 1024))), 0)
    print("AVAudioEngine manual render verified: peak buffer RMS \(maximumRMS); disconnected RMS 0")
  }

  private func render(_ patch: Patch, seconds: Double, hold: Bool = true) -> [Float] {
    var kernel = SynthKernel(sampleRate: 48000)
    var samples = [Float](repeating: 0, count: Int(seconds * 48000))
    kernel.render(
      control: SynthControl(patch: patch, hold: hold, trigger: 1), frames: samples.count
    ) {
      samples[$0] = $1
    }
    return samples
  }

  private func rms(_ values: [Float]) -> Double {
    sqrt(values.reduce(0) { $0 + Double($1 * $1) } / Double(values.count))
  }
}
