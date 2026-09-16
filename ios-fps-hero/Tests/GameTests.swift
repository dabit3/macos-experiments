import XCTest

@testable import FPSHeroCore

final class ChartTests: XCTestCase {
  func testDeterministicChart() {
    let a = ChartGenerator.notes(for: .rasterRush, seed: 42)
    let b = ChartGenerator.notes(for: .rasterRush, seed: 42)
    XCTAssertEqual(a, b)
    XCTAssertGreaterThan(a.count, 50)
  }

  func testDifferentSeedsDiffer() {
    let a = ChartGenerator.notes(for: .rasterRush, seed: 1)
    let b = ChartGenerator.notes(for: .rasterRush, seed: 2)
    XCTAssertNotEqual(a, b)
  }

  func testChartValidity() {
    for track in Track.all {
      let notes = ChartGenerator.notes(for: track, seed: 7)
      XCTAssertFalse(notes.isEmpty)
      var lastInLane = [Double](repeating: -.infinity, count: 4)
      var atSameTime = 0
      var prevTime = -Double.infinity
      for note in notes {
        XCTAssert((0..<4).contains(note.lane))
        XCTAssertGreaterThanOrEqual(note.time, ChartGenerator.leadIn - 0.001)
        XCTAssertLessThanOrEqual(note.time, track.duration - ChartGenerator.tail + 0.001)
        XCTAssertGreaterThanOrEqual(
          note.time - lastInLane[note.lane], ChartGenerator.minLaneSpacing - 0.0001,
          "lane spacing violated in \(track.id)")
        lastInLane[note.lane] = note.time
        if note.time == prevTime {
          atSameTime += 1
        } else {
          atSameTime = 1
        }
        XCTAssertLessThanOrEqual(atSameTime, 2, "chord exceeds 2 lanes")
        prevTime = note.time
      }
    }
  }

  func testDensityScalesWithDifficulty() {
    let chill = ChartGenerator.notes(for: .tensorDrift, seed: 3)
    let hard = ChartGenerator.notes(for: .overclockOverdrive, seed: 3)
    let chillRate = Double(chill.count) / Track.tensorDrift.duration
    let hardRate = Double(hard.count) / Track.overclockOverdrive.duration
    XCTAssertGreaterThan(hardRate, chillRate)
  }
}

final class JudgmentTests: XCTestCase {
  func testWindows() {
    XCTAssertEqual(Judgment.forDelta(0.01), .perfect)
    XCTAssertEqual(Judgment.forDelta(-0.045), .perfect)
    XCTAssertEqual(Judgment.forDelta(0.06), .great)
    XCTAssertEqual(Judgment.forDelta(-0.09), .great)
    XCTAssertEqual(Judgment.forDelta(0.12), .good)
    XCTAssertEqual(Judgment.forDelta(0.14), .good)
    XCTAssertEqual(Judgment.forDelta(0.2), .miss)
  }
}

final class GameStateTests: XCTestCase {
  private func makeState(_ track: Track = .tensorDrift, seed: UInt64 = 5) -> GameState {
    GameState(track: track, notes: ChartGenerator.notes(for: track, seed: seed))
  }

  private func tapAllPerfect(_ state: inout GameState, upTo limit: Int = .max) -> Int {
    var hit = 0
    for note in state.notes.prefix(limit) {
      state.advance(to: note.time)
      if state.tap(lane: note.lane, at: note.time) != nil { hit += 1 }
    }
    return hit
  }

  func testComboMultiplier() {
    var state = makeState()
    // Force combo to 50 via perfect taps.
    _ = tapAllPerfect(&state, upTo: 50)
    XCTAssertEqual(state.combo, 50)
    let scoreBefore = state.score
    let note = state.notes.first { !state.hit.contains($0.id) }!
    _ = state.tap(lane: note.lane, at: note.time)
    // At combo >= 50 the multiplier is 2x a perfect's 1000.
    XCTAssertEqual(state.score - scoreBefore, 2000)
  }

  func testFPSClampsAndMissPenalty() {
    var state = makeState()
    _ = tapAllPerfect(&state, upTo: 10)
    XCTAssertEqual(state.fps, 240)  // clamped at 240
    // Walk time forward past a note without tapping: miss drops fps by 45.
    let missed = state.notes.first { !state.hit.contains($0.id) }!
    let events = state.advance(to: missed.time + 0.2)
    XCTAssertTrue(events.contains(.missed(missed)))
    XCTAssertLessThanOrEqual(state.fps, 195)  // -45 per miss, chords may miss together
    XCTAssertEqual(state.combo, 0)
  }

  func testFPSFloorAt30() {
    var state = makeState(.overclockOverdrive)
    state.advance(to: 30)  // tons of misses
    XCTAssertEqual(state.fps, 30)
    XCTAssertEqual(state.phase, .playing)
  }

  func testTapPicksNearestNote() {
    var state = makeState()
    // Two notes in same lane far apart; tap slightly late on the first.
    let laneNotes = state.notes.filter { $0.lane == 0 }
    XCTAssertGreaterThanOrEqual(laneNotes.count, 2)
    let first = laneNotes[0]
    let j = state.tap(lane: 0, at: first.time + 0.1)
    XCTAssertEqual(j, .good)
    XCTAssertTrue(state.hit.contains(first.id))
    // The second note must still be unhit.
    XCTAssertFalse(state.hit.contains(laneNotes[1].id))
  }

  func testWhiffReturnsNil() {
    var state = makeState()
    XCTAssertNil(state.tap(lane: 0, at: 30.0))
  }

  func testFinishedEvent() {
    var state = makeState()
    let events = state.advance(to: state.track.duration + 0.01)
    XCTAssertTrue(events.contains(.finished))
    XCTAssertEqual(state.phase, .finished)
  }

  func testDLSSChargeAndAutoHits() {
    var state = makeState()
    // Fill charge: 25 perfects.
    _ = tapAllPerfect(&state, upTo: 25)
    XCTAssertTrue(state.dlss.isFull)
    XCTAssertTrue(state.activateDLSS())
    XCTAssertEqual(state.dlss.charge, 0)
    // Advance ~2s: every note reaching the hit line auto-judges perfect.
    let before = state.counts[.perfect, default: 0]
    let events = state.advance(to: state.time + 2.0)
    let autoHits = events.filter {
      if case .autoHit = $0 { return true }
      return false
    }
    XCTAssertFalse(autoHits.isEmpty)
    XCTAssertGreaterThan(state.counts[.perfect, default: 0], before)
    // Perfects during DLSS refill the charge.
    XCTAssertGreaterThan(state.dlss.charge, 0)
    // After expiry, auto-hits stop: remaining far-future notes miss normally.
    let late = state.notes.last!
    let tailEvents = state.advance(to: late.time + 0.2)
    XCTAssertTrue(tailEvents.contains(.missed(late)))
  }

  func testGradeThresholds() {
    XCTAssertEqual(Grade.forAccuracy(0.96), .s)
    XCTAssertEqual(Grade.forAccuracy(0.95), .s)
    XCTAssertEqual(Grade.forAccuracy(0.91), .a)
    XCTAssertEqual(Grade.forAccuracy(0.85), .b)
    XCTAssertEqual(Grade.forAccuracy(0.7), .c)
    XCTAssertEqual(Grade.forAccuracy(0.4), .d)
  }

  func testAccuracyAndAverageFPS() {
    var state = makeState()
    let note = state.notes[0]
    state.advance(to: note.time)
    _ = state.tap(lane: note.lane, at: note.time)
    XCTAssertGreaterThan(state.accuracy, 0)
    state.advance(to: state.track.duration)
    XCTAssertEqual(state.averageFPS, 240, accuracy: 0.001)
  }
}
