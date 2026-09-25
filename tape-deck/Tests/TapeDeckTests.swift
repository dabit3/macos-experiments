import AVFoundation
import Combine
import XCTest

@testable import TapeDeck

final class TapeDeckTests: XCTestCase {
  @MainActor
  func testParameterResetPublishesAndPersistsOneCompleteState() throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = TapeRepository(url: directory.appendingPathComponent("tapes.json"))
    let store = TapeStore(repository: repository)
    store.edit {
      $0.tempo = 180
      $0.swing = 0.6
    }
    var snapshots: [Pattern] = []
    let observation = store.$archive.dropFirst().sink { snapshots.append($0.current) }
    store.edit {
      $0.tempo = 96
      $0.swing = 0
    }
    XCTAssertEqual(snapshots.count, 1)
    XCTAssertTrue(snapshots.allSatisfy { $0.tempo == 96 && $0.swing == 0 })
    XCTAssertEqual(try repository.load().current, store.pattern)
    withExtendedLifetime(observation) {}
  }

  func testSwingPreservesBarDurationAndAlternatesSteps() {
    for tempo in [60.0, 96, 120, 180] {
      for swing in [0.0, 0.16, 0.42, 0.6] {
        let durations = (0..<16).map {
          SequencerClock.duration(step: $0, tempo: tempo, swing: swing)
        }
        XCTAssertEqual(durations.reduce(0, +), 240 / tempo, accuracy: 0.000_001)
        XCTAssertGreaterThanOrEqual(durations[0], durations[1])
        XCTAssertGreaterThan(durations[1], 0)
      }
    }
  }

  func testBoundsAndMalformedPatternNormalization() {
    var pattern = Pattern(tempo: 300, swing: -2)
    pattern.steps = [[true]]
    pattern.muted = []
    pattern.soloed = [true]
    pattern.name = "   "
    let clean = pattern.normalized()
    XCTAssertEqual(clean.tempo, 180)
    XCTAssertEqual(clean.swing, 0)
    XCTAssertEqual(clean.steps.count, 4)
    XCTAssertTrue(clean.steps.allSatisfy { $0.count == 16 })
    XCTAssertTrue(clean.steps[0][0])
    XCTAssertEqual(clean.name, "Untitled tape")
    pattern.tempo = .nan
    pattern.swing = .infinity
    XCTAssertEqual(pattern.normalized().tempo, 96)
    XCTAssertEqual(pattern.normalized().swing, 0)
    XCTAssertEqual(SequencerClock.duration(step: 0, tempo: .nan, swing: .nan), 0.15625)
  }

  func testMuteSoloPrecedence() {
    var pattern = Pattern()
    XCTAssertEqual(pattern.activeMask, 15)
    pattern.soloed[1] = true
    XCTAssertEqual(pattern.activeMask, 2)
    pattern.soloed[2] = true
    XCTAssertEqual(pattern.activeMask, 6)
    pattern.muted[1] = true
    XCTAssertEqual(pattern.activeMask, 4)
    pattern.muted[2] = true
    XCTAssertEqual(pattern.activeMask, 0)
  }

  func testArchiveRoundTripKeepsIndependentSnapshots() throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = TapeRepository(url: directory.appendingPathComponent("tapes.json"))
    XCTAssertEqual(try repository.load(), TapeArchive())
    var archive = TapeArchive()
    archive.current.name = "Kitchen / take 2"
    archive.current.tempo = 131
    archive.current.swing = 0.43
    archive.current.muted[2] = true
    archive.current.soloed[0] = true
    archive.tapes = [SavedTape(pattern: archive.current)]
    archive.current.steps[0][1].toggle()
    try repository.save(archive)
    let restored = try repository.load()
    XCTAssertEqual(restored, archive)
    XCTAssertNotEqual(restored.current.steps, restored.tapes[0].pattern.steps)
    archive.tapes.removeAll()
    try repository.save(archive)
    XCTAssertTrue(try repository.load().tapes.isEmpty)
  }

  func testCorruptArchiveIsNotSilentlyOverwrittenByLoad() throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("tapes.json")
    let original = Data("invalid".utf8)
    try original.write(to: url)
    XCTAssertThrowsError(try TapeRepository(url: url).load())
    XCTAssertEqual(try Data(contentsOf: url), original)
  }

  func testSynthesizedVoicesAreDeterministicFiniteAndAudible() {
    for drum in Drum.allCases {
      let sample = DrumSynth.sample(drum: drum, sampleRate: 48_000)
      XCTAssertEqual(sample, DrumSynth.sample(drum: drum, sampleRate: 48_000))
      XCTAssertTrue(sample.allSatisfy { $0.isFinite && abs($0) <= 1.5 })
      XCTAssertGreaterThan(sample.map { abs($0) }.max() ?? 0, 0.05)
      XCTAssertEqual(sample.first, 0)
      XCTAssertLessThan(abs(sample.last ?? 1), 0.03)
    }
  }

  func testRenderedAudioTransportAndStepTiming() throws {
    let control = RenderControl()
    var pattern = Pattern(tempo: 120, swing: 0.4)
    pattern.steps[0][0] = true
    control.update(pattern: pattern)
    let renderer = DrumRenderer(control: control, sampleRate: 48_000)
    let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000))
    let channels = try XCTUnwrap(buffer.floatChannelData)
    control.transport(playing: true)
    renderer.render(
      frameCount: 8_400, buffers: UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
    )
    XCTAssertEqual(control.meter().0, 0)
    XCTAssertGreaterThan((0..<8_400).map { abs(channels[0][$0]) }.max() ?? 0, 0.05)
    renderer.render(
      frameCount: 1, buffers: UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList))
    XCTAssertEqual(control.meter().0, 1)
    control.transport(playing: false)
    renderer.render(
      frameCount: 256, buffers: UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList))
    XCTAssertTrue((0..<256).allSatisfy { channels[0][$0] == 0 && channels[1][$0] == 0 })
    XCTAssertEqual(control.meter().0, -1)
    control.transport(playing: true)
    renderer.render(
      frameCount: 1, buffers: UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList))
    XCTAssertEqual(control.meter().0, 0)
  }
}
