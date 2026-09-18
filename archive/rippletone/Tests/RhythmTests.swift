import XCTest

@testable import Rippletone

final class RhythmTests: XCTestCase {
  func testTimingWindowsAreSymmetricAndInclusive() {
    for gentle in [true, false] {
      let rules = TimingRules(forgiving: gentle)
      XCTAssertEqual(rules.judge(offset: -rules.perfectWindow), .perfect)
      XCTAssertEqual(rules.judge(offset: rules.perfectWindow), .perfect)
      XCTAssertEqual(rules.judge(offset: rules.hitWindow), .good)
      XCTAssertEqual(rules.judge(offset: -rules.hitWindow), .good)
      XCTAssertEqual(rules.judge(offset: rules.hitWindow + 0.001), .miss)
    }
  }

  func testWrongLaneAndDoubleTapsCannotScore() {
    var engine = RhythmEngine(composition: Composition.all[0], rules: TimingRules(forgiving: true))
    XCTAssertNil(engine.tap(lane: 1, at: 3))
    XCTAssertEqual(engine.tap(lane: 0, at: 3), .perfect)
    XCTAssertNil(engine.tap(lane: 0, at: 3))
    XCTAssertEqual(engine.performance.perfect, 1)
    XCTAssertEqual(engine.combo, 1)
  }

  func testExpirationBreaksComboButKeepsBest() {
    var engine = RhythmEngine(composition: Composition.all[0], rules: TimingRules(forgiving: false))
    for note in engine.composition.notes.prefix(2) {
      _ = engine.tap(lane: note.lane, at: note.time)
    }
    XCTAssertEqual(engine.expire(at: 9), 1)
    XCTAssertEqual(engine.combo, 0)
    XCTAssertEqual(engine.maxCombo, 2)
    XCTAssertEqual(engine.expire(at: 9), 0)
    XCTAssertNil(engine.tap(lane: 2, at: 9))
  }

  func testFourPerfectNotesReleaseOneSchool() {
    var engine = RhythmEngine(composition: Composition.all[0], rules: TimingRules(forgiving: true))
    for note in engine.composition.notes.prefix(8) {
      _ = engine.tap(lane: note.lane, at: note.time)
    }
    XCTAssertEqual(engine.perfectPhrases, 2)
    XCTAssertEqual(engine.maxCombo, 8)
  }

  func testLovelyBreaksPerfectPhraseButNotCombo() {
    var engine = RhythmEngine(composition: Composition.all[0], rules: TimingRules(forgiving: true))
    for note in engine.composition.notes.prefix(4) {
      _ = engine.tap(lane: note.lane, at: note.time + (note.id == 2 ? 0.5 : 0))
    }
    XCTAssertEqual(engine.perfectPhrases, 0)
    XCTAssertEqual(engine.combo, 4)
    XCTAssertEqual(engine.performance.accuracy, 93)
  }

  func testClearRequiresAccuracyAndCoverage() {
    XCTAssertFalse(
      Performance(compositionID: 0, perfect: 6, good: 0, missed: 4, maxCombo: 6, forgiving: true)
        .cleared)
    XCTAssertFalse(
      Performance(compositionID: 0, perfect: 0, good: 7, missed: 3, maxCombo: 7, forgiving: true)
        .cleared)
    XCTAssertTrue(
      Performance(compositionID: 0, perfect: 6, good: 1, missed: 3, maxCombo: 7, forgiving: true)
        .cleared)
    XCTAssertFalse(
      Performance(compositionID: 0, perfect: 0, good: 0, missed: 0, maxCombo: 0, forgiving: true)
        .cleared)
  }

  func testAllPatternsArePlayableAndEscalate() {
    let songs = Composition.all
    XCTAssertEqual(Set(songs.map(\.name)).count, 3)
    XCTAssertEqual(songs.map { $0.notes.count }, [12, 16, 20])
    for song in songs {
      XCTAssertTrue((30...45).contains(song.duration))
      XCTAssertEqual(Set(song.notes.map(\.id)).count, song.notes.count)
      XCTAssertEqual(Set(song.notes.map(\.lane)), [0, 1, 2])
      for pair in zip(song.notes, song.notes.dropFirst()) {
        XCTAssertGreaterThanOrEqual(pair.1.time - pair.0.time, 1.49)
      }
      var engine = RhythmEngine(composition: song, rules: TimingRules(forgiving: false))
      for note in song.notes {
        XCTAssertEqual(engine.tap(lane: note.lane, at: note.time), .perfect)
      }
      XCTAssertEqual(engine.performance.accuracy, 100)
      XCTAssertTrue(engine.performance.cleared)
    }
  }

  func testUntouchedCompositionFailsWithEveryNoteAccountedFor() {
    var engine = RhythmEngine(composition: Composition.all[2], rules: TimingRules(forgiving: true))
    engine.expire(at: engine.composition.duration)
    XCTAssertEqual(engine.performance.missed, 20)
    XCTAssertFalse(engine.performance.cleared)
    XCTAssertEqual(engine.performance.accuracy, 0)
  }

  func testPerformanceRoundTripKeepsModeAndScoring() throws {
    let original = Performance(
      compositionID: 1, perfect: 10, good: 3, missed: 3, maxCombo: 7, forgiving: false)
    let data = try JSONEncoder().encode(original)
    XCTAssertEqual(try JSONDecoder().decode(Performance.self, from: data), original)
  }

  @MainActor
  func testSettingsPersistWithIsolatedDefaults() {
    let name = "RippletoneTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let model = GameModel(defaults: defaults)
    model.forgiving = false
    model.audio = false
    model.haptics = false
    let restored = GameModel(defaults: defaults)
    XCTAssertFalse(restored.forgiving)
    XCTAssertFalse(restored.audio)
    XCTAssertFalse(restored.haptics)
  }
}
