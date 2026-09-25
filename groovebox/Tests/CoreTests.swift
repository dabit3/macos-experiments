import Foundation
import XCTest

@testable import GrooveboxCore

final class CoreTests: XCTestCase {
  func testFactoryPatternsValidate() {
    XCTAssertEqual(Pattern.presets.count, 3)
    XCTAssertTrue(Pattern.presets.allSatisfy(\.isValid))
  }

  func testRejectsMalformedPatternAndUnsafeParameters() {
    var pattern = Pattern.presets[0]
    pattern.steps[0].removeLast()
    XCTAssertFalse(pattern.isValid)
    pattern = Pattern.presets[0]
    pattern.bpm = .nan
    XCTAssertFalse(pattern.isValid)
    pattern.bpm = 0
    XCTAssertFalse(pattern.isValid)
    pattern.bpm = 112
    pattern.solo = 4
    XCTAssertFalse(pattern.isValid)
  }

  func testVoicesAreAudibleDistinctDeterministicAndFinite() {
    var previous: [Float] = []
    for drum in Drum.allCases {
      let samples = DrumSynth.voice(drum)
      let rms = sqrt(samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count))
      XCTAssertGreaterThan(rms, 0.025, drum.name)
      XCTAssertTrue(samples.allSatisfy(\.isFinite))
      XCTAssertEqual(samples, DrumSynth.voice(drum))
      XCTAssertNotEqual(Array(samples.prefix(1000)), Array(previous.prefix(1000)))
      XCTAssertEqual(samples.first, 0)
      XCTAssertLessThan(abs(samples.last!), 0.001)
      previous = samples
    }
  }

  func testSwingConservesEveryPairAndBarDuration() {
    var pattern = Pattern.presets[0]
    for swing in [0.0, 0.12, 0.5] {
      pattern.swing = swing
      let pair =
        pattern.stepDuration(0, sampleRate: 48_000)
        + pattern.stepDuration(1, sampleRate: 48_000)
      XCTAssertEqual(pair, 48_000 * 60 / pattern.bpm / 2, accuracy: 0.000001)
      XCTAssertGreaterThanOrEqual(
        pattern.stepDuration(0, sampleRate: 48_000), pattern.stepDuration(1, sampleRate: 48_000))
    }
  }

  func testSampleClockAdvancesAndLoopsExactly() {
    var pattern = Pattern.presets[0]
    pattern.bpm = 120
    pattern.swing = 0
    let renderer = RenderMachine(pattern: pattern)
    renderer.start()
    XCTAssertEqual(renderer.step, -1)
    for _ in 0..<6000 { _ = renderer.nextSample() }
    XCTAssertEqual(renderer.step, 0)
    _ = renderer.nextSample()
    XCTAssertEqual(renderer.step, 1)
    for _ in 0..<89_999 { _ = renderer.nextSample() }
    XCTAssertEqual(renderer.step, 15)
    _ = renderer.nextSample()
    XCTAssertEqual(renderer.step, 0)
  }

  func testTempoUpdateKeepsCurrentStepPhase() {
    var pattern = Pattern.presets[0]
    pattern.bpm = 120
    pattern.swing = 0
    let renderer = RenderMachine(pattern: pattern)
    renderer.start()
    for _ in 0..<3000 { _ = renderer.nextSample() }
    pattern.bpm = 60
    renderer.update(pattern)
    for _ in 0..<6000 { _ = renderer.nextSample() }
    XCTAssertEqual(renderer.step, 0)
    _ = renderer.nextSample()
    XCTAssertEqual(renderer.step, 1)
  }

  func testMutedAndSoloedTracksDoNotTrigger() {
    var pattern = Pattern.presets[0]
    pattern.muted = Array(repeating: true, count: 4)
    XCTAssertTrue(WaveExport.samples(pattern: pattern).allSatisfy { $0 == 0 })
    pattern.muted = Array(repeating: false, count: 4)
    pattern.solo = 0
    var onlyKick = pattern
    onlyKick.solo = nil
    for track in 1..<4 { onlyKick.steps[track] = Array(repeating: false, count: 16) }
    XCTAssertEqual(WaveExport.samples(pattern: pattern), WaveExport.samples(pattern: onlyKick))
  }

  func testLivePadWorksWhileStoppedAndStopClearsSound() {
    let renderer = RenderMachine(pattern: Pattern.presets[0])
    renderer.hit(.kick)
    XCTAssertGreaterThan(
      (0..<1000).reduce(Float(0)) { sum, _ in sum + abs(renderer.nextSample()) }, 1)
    renderer.stop()
    XCTAssertFalse(renderer.playing)
    XCTAssertEqual(renderer.step, -1)
    XCTAssertTrue((0..<1000).allSatisfy { _ in renderer.nextSample() == 0 })
  }

  func testEmptyPatternRendersSilenceAndMasterZeroIsSilent() {
    XCTAssertTrue(WaveExport.samples(pattern: Pattern(name: "Empty")).allSatisfy { $0 == 0 })
    var pattern = Pattern.presets[0]
    pattern.volume = 0
    XCTAssertTrue(WaveExport.samples(pattern: pattern).allSatisfy { $0 == 0 })
  }

  func testTwoBarExportDurationHeaderAndNonzeroPCM() {
    let pattern = Pattern.presets[0]
    let samples = WaveExport.samples(pattern: pattern)
    let expected = Int((8 * 60 / pattern.bpm * 48_000).rounded()) + 26_400
    XCTAssertEqual(samples.count, expected)
    XCTAssertTrue(samples.contains { abs($0) > 0.1 })
    XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 1 })
    let wav = WaveExport.wav(samples)
    XCTAssertEqual(wav.count, 44 + expected * 2)
    XCTAssertEqual(String(data: wav.prefix(4), encoding: .ascii), "RIFF")
    XCTAssertEqual(String(data: wav.subdata(in: 8..<12), encoding: .ascii), "WAVE")
    XCTAssertEqual(Array(wav[22..<24]), [1, 0])
    XCTAssertEqual(Array(wav[24..<28]), [128, 187, 0, 0])
    XCTAssertEqual(Array(wav[34..<36]), [16, 0])
  }

  func testFullDensityMixStaysWithinHeadroom() {
    var pattern = Pattern.presets[0]
    pattern.steps = Array(repeating: Array(repeating: true, count: 16), count: 4)
    pattern.volume = 1
    let samples = WaveExport.samples(pattern: pattern)
    XCTAssertLessThan(samples.map(abs).max()!, 1)
  }

  func testLibraryRoundTripAndCorruptionRecoverySignal() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("library.json")
    let initial = LibraryState(current: Pattern.presets[1], saved: Pattern.presets)
    try initial.write(to: url)
    let decoded = try LibraryState.read(from: url)
    XCTAssertEqual(decoded.current, initial.current)
    XCTAssertEqual(decoded.saved, initial.saved)
    var invalid = initial
    invalid.current.muted = []
    try invalid.write(to: url)
    XCTAssertThrowsError(try LibraryState.read(from: url))
    try Data("not json".utf8).write(to: url)
    XCTAssertThrowsError(try LibraryState.read(from: url))
  }
}
