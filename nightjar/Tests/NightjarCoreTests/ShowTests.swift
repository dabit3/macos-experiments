import Foundation
import Testing

@testable import NightjarCore

@Test func sampleRoundTripPreservesEveryFixtureAndCue() throws {
  let sample = Show.sample
  let restored = try Show.decode(sample.encoded())
  #expect(restored == sample)
  #expect(restored.cues.count == 3)
  #expect(restored.live.count == 6)
}

@Test func crossfadeHasExactEndpointsAndSmoothMidpoint() {
  let show = Show.sample
  let a = show.cues[0].fixtures
  let b = show.cues[1].fixtures
  #expect(Fixture.crossfade(from: a, to: b, progress: 0) == a)
  #expect(Fixture.crossfade(from: a, to: b, progress: 1) == b)
  let midpoint = Fixture.crossfade(from: a, to: b, progress: 0.5)
  #expect(abs(midpoint[0].color.g - (a[0].color.g + b[0].color.g) / 2) < 0.000_001)
  #expect(abs(midpoint[0].beam - (a[0].beam + b[0].beam) / 2) < 0.000_001)
  #expect(Fixture.crossfade(from: a, to: b, progress: -1) == a)
  #expect(Fixture.crossfade(from: a, to: b, progress: 2) == b)
}

@Test func crossfadeMatchesFixturesByIdentityRatherThanArrayOrder() {
  let a = Show.sample.live
  var b = a.reversed().map { $0 }
  for index in b.indices { b[index].intensity = 0 }
  let midpoint = Fixture.crossfade(from: a, to: b, progress: 0.5)
  for fixture in midpoint {
    let source = a.first { $0.id == fixture.id }!
    #expect(abs(fixture.intensity - source.intensity / 2) < 0.000_001)
  }
}

@Test func rejectsUnsafeOrInvalidShowFiles() throws {
  var show = Show.sample
  show.live[0].intensity = -0.1
  #expect(throws: ShowError.self) { try show.validated() }
  show = .sample
  show.cues[0].fade = 0
  #expect(throws: ShowError.self) { try show.validated() }
  show = .sample
  show.live[1].id = 0
  #expect(throws: ShowError.self) { try show.validated() }
  show = .sample
  show.live[0].position.x = .nan
  #expect(throws: ShowError.self) { try show.validated() }
  show = .sample
  show.version = 2
  #expect(throws: ShowError.self) { try show.validated() }
  #expect(throws: (any Error).self) { try Show.decode(Data("not a show".utf8)) }
}

@Test func csvIncludesEveryFixtureWithEscapedLabelsAndStableNumbers() {
  var show = Show.sample
  show.name = "The \"night\", room"
  show.cues[0].name = "=HYPERLINK(\"example\")"
  let csv = show.cueSheet
  #expect(csv.components(separatedBy: "\r\n").count == 20)
  #expect(csv.contains("\"The \"\"night\"\", room\""))
  #expect(csv.contains("\"'=HYPERLINK(\"\"example\"\")\""))
  #expect(csv.contains("\"85.00\""))
  #expect(csv.contains("\"#FF8730\""))
  #expect(csv.contains("\"Aim Z\""))
}

@Test func cueClockTracksFadeHoldAndCompletion() {
  var clock = CueClock(fade: 3, hold: 2)
  #expect(clock.phase == .fade)
  clock.advance(1.5)
  #expect(clock.progress == 0.5)
  clock.advance(-100)
  clock.advance(.nan)
  #expect(clock.progress == 0.5)
  clock.advance(1.5)
  #expect(clock.phase == .hold)
  #expect(clock.progress == 1)
  clock.advance(2)
  #expect(clock.phase == .finished)
  #expect(clock.totalProgress == 1)
}

@Test func zeroHoldFinishesAtFadeBoundary() {
  var clock = CueClock(fade: 0.5, hold: 0)
  clock.advance(0.5)
  #expect(clock.phase == .finished)
}

@Test func serializedShowActuallyPersistsOnDisk() throws {
  let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
    "Library/Caches/NightjarTests/\(UUID().uuidString)"
  )
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("test.nightjar")
  var show = Show.sample
  show.live[4].beam = 18
  show.cues.swapAt(0, 2)
  try show.encoded().write(to: file, options: .atomic)
  #expect(try Show.decode(Data(contentsOf: file)) == show)
}
