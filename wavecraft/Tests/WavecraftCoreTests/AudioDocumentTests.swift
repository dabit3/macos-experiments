import Foundation
import Testing

@testable import WavecraftCore

@Test func trimPreservesExactFrames() throws {
  var audio = try AudioDocument(
    name: "Test", sampleRate: 8000, channels: [[0, 0.2, 0.4, 0.6, 0.8]])
  try audio.trim(to: 1..<4)
  #expect(audio.channels[0] == [0.2, 0.4, 0.6])
  #expect(audio.duration == 3.0 / 8000)
}

@Test func fadesHaveExactEndpointsAndPreserveOutsideRange() throws {
  var audio = try AudioDocument(name: "Test", sampleRate: 8000, channels: [[1, 1, 1, 1, 1]])
  try audio.fade(1..<4, fadeIn: true)
  #expect(audio.channels[0] == [1, 0, 0.5, 1, 1])
  try audio.fade(1..<4, fadeIn: false)
  #expect(audio.channels[0] == [1, 0, 0.25, 0, 1])
}

@Test func gainMeasuresClippingBeforeExportAndExportSaturates() throws {
  var audio = try AudioDocument(name: "Test", sampleRate: 8000, channels: [[0.8, -0.8]])
  try audio.gain(0..<2, decibels: 6)
  #expect(audio.clippedCount == 2)
  #expect(abs(audio.peak - 1.59621) < 0.0001)
  let wav = try audio.wavData()
  #expect(Array(wav.suffix(4)) == [255, 127, 1, 128])
}

@Test func wavHeaderAndStereoInterleaving() throws {
  let audio = try AudioDocument(name: "Test", sampleRate: 44100, channels: [[0, 1], [-1, 0]])
  let wav = try audio.wavData()
  #expect(wav.count == 52)
  #expect(String(data: wav[0..<4], encoding: .ascii) == "RIFF")
  #expect(String(data: wav[8..<12], encoding: .ascii) == "WAVE")
  #expect(Array(wav[22..<24]) == [2, 0])
  #expect(Array(wav[24..<28]) == [68, 172, 0, 0])
  #expect(Array(wav.suffix(8)) == [0, 0, 1, 128, 255, 127, 0, 0])
}

@Test func projectRoundTripsEditedAudioAndSelection() throws {
  var audio = SampleKind.glass.generate()
  try audio.trim(to: 0..<44100)
  try audio.fade(0..<4410, fadeIn: true)
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  try Project(audio: audio, selectionStart: 0.2, selectionEnd: 0.8).save(to: url)
  let loaded = try Project.load(from: url)
  #expect(loaded.audio == audio)
  #expect(loaded.selectionStart == 0.2)
  #expect(loaded.selectionEnd == 0.8)
}

@Test func samplesAreDeterministicDistinctAndWithinHeadroom() {
  let samples = SampleKind.allCases.map { $0.generate() }
  #expect(samples.map(\.duration) == [5, 4, 6])
  for audio in samples {
    #expect(audio.peak > 0.3 && audio.peak < 1)
    #expect(audio.rms > 0.03)
    #expect(audio.channels.count == 2)
  }
  #expect(SampleKind.tide.generate() == samples[0])
}

@Test func invalidInputsAreRejected() throws {
  #expect(throws: AudioError.self) {
    try AudioDocument(name: "Bad", sampleRate: 44100, channels: [[]])
  }
  #expect(throws: AudioError.self) {
    try AudioDocument(name: "Bad", sampleRate: 44100, channels: [[.nan]])
  }
  let audio = SampleKind.glass.generate()
  #expect(throws: AudioError.self) { try audio.frameRange(start: .nan, end: 1) }
  #expect(throws: AudioError.self) { try audio.frameRange(start: 2, end: 1) }
}
