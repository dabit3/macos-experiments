import XCTest

@testable import CadenceCoach

final class CadenceCoachTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_000)
  private var routine: Routine { Routine.examples[2] }

  func testExactBoundaryAndRoundTransitions() {
    var session = Session(routine: routine, now: start)
    session.synchronize(at: start.addingTimeInterval(10))
    XCTAssertEqual(session.phase.kind, .rest)
    XCTAssertEqual(session.remaining(at: start.addingTimeInterval(10)), 5)
    session.synchronize(at: start.addingTimeInterval(15))
    XCTAssertEqual(session.round, 2)
    XCTAssertEqual(session.phase.kind, .work)
    session.synchronize(at: start.addingTimeInterval(30))
    XCTAssertTrue(session.finished)
    XCTAssertEqual(session.record.completedPhases, 4)
    XCTAssertEqual(session.record.activeSeconds, 30)
    XCTAssertEqual(session.record.workSeconds, 20)
  }

  func testBackgroundRecoveryWithoutDrift() {
    var session = Session(routine: routine, now: start)
    session.synchronize(at: start.addingTimeInterval(23.4))
    XCTAssertEqual(session.index, 2)
    XCTAssertEqual(session.remaining(at: start.addingTimeInterval(23.4)), 2)
    session.synchronize(at: start.addingTimeInterval(500))
    XCTAssertEqual(session.record.activeSeconds, 30)
    XCTAssertEqual(session.endedAt, start.addingTimeInterval(30))
  }

  func testPauseExcludesTimeAndSurvivesSerialization() throws {
    var session = Session(routine: routine, now: start)
    session.pause(at: start.addingTimeInterval(4))
    let data = try JSONEncoder().encode(session)
    session = try JSONDecoder().decode(Session.self, from: data)
    session.synchronize(at: start.addingTimeInterval(100))
    XCTAssertEqual(session.remaining(at: start.addingTimeInterval(100)), 6)
    session.resume(at: start.addingTimeInterval(100))
    session.synchronize(at: start.addingTimeInterval(106))
    XCTAssertEqual(session.index, 1)
    XCTAssertEqual(session.activeSeconds, 10)
  }

  func testSkipCountsOnlyPerformedTime() {
    var session = Session(routine: routine, now: start)
    session.skip(at: start.addingTimeInterval(3))
    XCTAssertEqual(session.activeSeconds, 3)
    XCTAssertEqual(session.skippedPhases, 1)
    XCTAssertEqual(session.completedPhases, 0)
    session.synchronize(at: start.addingTimeInterval(23))
    XCTAssertTrue(session.finished)
    XCTAssertEqual(session.record.activeSeconds, 23)
    XCTAssertEqual(session.record.workSeconds, 13)
    XCTAssertEqual(session.completedPhases, 3)
  }

  func testSkipWhilePausedKeepsNextIntervalPaused() {
    var session = Session(routine: routine, now: start)
    session.pause(at: start.addingTimeInterval(3))
    session.skip(at: start.addingTimeInterval(100))
    XCTAssertTrue(session.paused)
    XCTAssertEqual(session.remaining(at: start.addingTimeInterval(100)), 5)
    XCTAssertEqual(session.activeSeconds, 3)
  }

  func testSkippedProgressSurvivesSerializationAcrossRounds() throws {
    var session = Session(routine: routine, now: start)
    let original = try JSONEncoder().encode(session)
    XCTAssertNil(try JSONDecoder().decode(Session.self, from: original).skippedIndices)
    session.skip(at: start.addingTimeInterval(3))
    session.synchronize(at: start.addingTimeInterval(8))
    session.skip(at: start.addingTimeInterval(10))
    session = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(session))
    XCTAssertEqual(session.skippedIndices, [0, 2])
    XCTAssertEqual(session.completedPhases, 1)
    XCTAssertEqual(session.skippedPhases, 2)
    XCTAssertEqual(session.round, 2)
    session.synchronize(at: start.addingTimeInterval(15))
    XCTAssertEqual(session.completedPhases + session.skippedPhases, session.phaseCount)
    XCTAssertEqual(session.activeSeconds, 15)
  }

  func testEndAndRepeatedSynchronizeAreIdempotent() {
    var session = Session(routine: routine, now: start)
    session.end(at: start.addingTimeInterval(12))
    session.end(at: start.addingTimeInterval(20))
    session.synchronize(at: start.addingTimeInterval(40))
    XCTAssertFalse(session.record.completed)
    XCTAssertEqual(session.record.activeSeconds, 12)
    XCTAssertEqual(session.record.workSeconds, 10)
    XCTAssertEqual(session.record.completedPhases, 1)
  }

  func testValidationRejectsInvalidSequences() {
    var draft = Routine.blank
    XCTAssertFalse(draft.isValid)
    draft.name = "Custom"
    XCTAssertTrue(draft.isValid)
    draft.intervals[0].seconds = 0
    XCTAssertFalse(draft.isValid)
    draft.intervals.removeAll()
    XCTAssertFalse(draft.isValid)
    draft = routine
    draft.intervals = [Interval(name: "Rest", kind: .rest, seconds: 10)]
    XCTAssertFalse(draft.isValid)
  }

  @MainActor
  func testPersistenceEditsHistoryAndMute() throws {
    let suite = "CadenceTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = CoachStore(defaults: defaults, ticking: false)
    var edited = routine
    edited.name = "My rhythm"
    store.upsert(edited)
    store.toggleMute()
    store.start(edited)
    store.end()
    let loaded = CoachStore(defaults: defaults, ticking: false)
    XCTAssertTrue(loaded.muted)
    XCTAssertEqual(loaded.routines.last?.name, "My rhythm")
    XCTAssertEqual(loaded.history.count, 1)
    XCTAssertFalse(loaded.history[0].completed)
    XCTAssertEqual(loaded.session?.routine.name, "My rhythm")
  }
}
