import Foundation
import XCTest

@testable import WatchwordCore

final class WatchEngineTests: XCTestCase {
  let epoch = Date(timeIntervalSince1970: 1000)
  let baseline = "Yesterday: Build succeeded."
  let done = "Today: archive delivered and verified."

  func time(_ seconds: Double) -> Date { epoch.addingTimeInterval(seconds) }
  func snap(_ text: String, _ sequence: Int, _ seconds: Double, target: String = "window-A")
    -> Snapshot
  {
    Snapshot(target: target, text: text, capturedAt: time(seconds), sequence: sequence)
  }
  func engine(timeout: Double = 60, maxRequests: Int = 120) -> WatchEngine {
    WatchEngine(baseline: snap(baseline, 0, 0), timeout: timeout, maxRequests: maxRequests)
  }
  func yes() throws -> Signals { try Signals(satisfied: 0.99, failed: 0.01, insufficient: 0.01) }
  func no() throws -> Signals { try Signals(satisfied: 0.01, failed: 0.01, insufficient: 0.01) }
  func candidate(_ engine: inout WatchEngine) throws {
    let ticket = try XCTUnwrap(engine.observe(snap(done, 1, 1), now: time(1)))
    XCTAssertFalse(
      engine.resolve(ticket, signals: try yes(), current: snap(done, 2, 1.2), now: time(1.2)))
    XCTAssertEqual(engine.phase, .candidate)
  }

  func testHistoricalSuccessCannotTrigger() {
    var e = engine()
    for sequence in 1...15 {
      XCTAssertNil(
        e.observe(snap(baseline, sequence, Double(sequence)), now: time(Double(sequence))))
    }
    XCTAssertEqual(e.confirmations, 0)
  }

  func testOneConfirmationCannotFire() throws {
    var e = engine()
    try candidate(&e)
    XCTAssertEqual(e.confirmations, 1)
  }

  func testIdenticalFreshSnapshotConfirmsWithoutDeadlock() throws {
    var e = engine()
    try candidate(&e)
    let ticket = try XCTUnwrap(e.observe(snap(done, 3, 4), now: time(4)))
    XCTAssertTrue(
      e.resolve(ticket, signals: try yes(), current: snap(done, 4, 4.1), now: time(4.1)))
    XCTAssertEqual(e.phase, .fired)
  }

  func testConfirmationMustWaitTwoSeconds() throws {
    var e = engine()
    try candidate(&e)
    XCTAssertNil(e.observe(snap(done, 3, 2), now: time(2)))
    XCTAssertNotNil(e.observe(snap(done, 4, 4), now: time(4)))
  }

  func testFollowUpFiresExactlyOnce() throws {
    var e = engine()
    try candidate(&e)
    let ticket = try XCTUnwrap(e.observe(snap(done, 3, 4), now: time(4)))
    XCTAssertTrue(
      e.resolve(ticket, signals: try yes(), current: snap(done, 4, 4.1), now: time(4.1)))
    XCTAssertFalse(e.resolve(ticket, signals: try yes(), current: snap(done, 5, 5), now: time(5)))
    XCTAssertNil(e.observe(snap(done, 6, 6), now: time(6)))
  }

  func testChangedEvidenceResetsConfirmation() throws {
    var e = engine()
    try candidate(&e)
    let changed = done + "\nActually, verification still pending."
    let ticket = try XCTUnwrap(e.observe(snap(changed, 3, 4), now: time(4)))
    XCTAssertFalse(
      e.resolve(ticket, signals: try yes(), current: snap(changed, 4, 4.1), now: time(4.1)))
    XCTAssertEqual(e.confirmations, 1)
  }

  func testDelayedAnswerCannotActOnNewText() throws {
    var e = engine()
    let ticket = try XCTUnwrap(e.observe(snap(done, 1, 1), now: time(1)))
    XCTAssertFalse(
      e.resolve(ticket, signals: try yes(), current: snap("Export failed.", 2, 2), now: time(2)))
    XCTAssertEqual(e.confirmations, 0)
    XCTAssertEqual(e.phase, .observing)
  }

  func testTooOldAnswerDiscardedEvenIfTextMatches() throws {
    var e = engine()
    let ticket = try XCTUnwrap(e.observe(snap(done, 1, 1), now: time(1)))
    XCTAssertFalse(e.resolve(ticket, signals: try yes(), current: snap(done, 2, 15), now: time(15)))
    XCTAssertEqual(e.confirmations, 0)
  }

  func testOldReadbackCannotValidateAction() throws {
    var e = engine()
    let ticket = try XCTUnwrap(e.observe(snap(done, 1, 1), now: time(1)))
    XCTAssertFalse(e.resolve(ticket, signals: try yes(), current: snap(done, 2, 2), now: time(5)))
    XCTAssertEqual(e.confirmations, 0)
  }

  func testTargetChangeStopsObservation() {
    var e = engine()
    XCTAssertNil(e.observe(snap(done, 1, 1, target: "window-B"), now: time(1)))
    XCTAssertEqual(e.phase, .needsAttention)
  }

  func testTargetChangeAtActionTimeStops() throws {
    var e = engine()
    let ticket = try XCTUnwrap(e.observe(snap(done, 1, 1), now: time(1)))
    XCTAssertFalse(
      e.resolve(
        ticket, signals: try yes(), current: snap(done, 2, 2, target: "window-B"), now: time(2)))
    XCTAssertEqual(e.phase, .needsAttention)
  }

  func testCancelledPendingRequestCannotFire() throws {
    var e = engine()
    let ticket = try XCTUnwrap(e.observe(snap(done, 1, 1), now: time(1)))
    e.cancel()
    XCTAssertFalse(e.resolve(ticket, signals: try yes(), current: snap(done, 2, 2), now: time(2)))
    XCTAssertEqual(e.phase, .cancelled)
  }

  func testOldRunTicketRejectedAfterRearm() throws {
    var old = engine()
    let ticket = try XCTUnwrap(old.observe(snap(done, 1, 1), now: time(1)))
    var new = engine()
    _ = new.observe(snap(done, 1, 1), now: time(1))
    XCTAssertFalse(new.resolve(ticket, signals: try yes(), current: snap(done, 2, 2), now: time(2)))
    XCTAssertEqual(new.confirmations, 0)
  }

  func testFailureOverridesSuccessSignal() throws {
    var e = engine()
    let ticket = try XCTUnwrap(e.observe(snap("Old success. New failure.", 1, 1), now: time(1)))
    let mixed = try Signals(satisfied: 0.99, failed: 0.99, insufficient: 0.01)
    XCTAssertFalse(
      e.resolve(
        ticket, signals: mixed, current: snap("Old success. New failure.", 2, 2), now: time(2)))
    XCTAssertEqual(e.phase, .needsAttention)
  }

  func testAmbiguousSignalWaitsWithoutRepeatedRequests() throws {
    var e = engine()
    let ticket = try XCTUnwrap(e.observe(snap("Maybe ready.", 1, 1), now: time(1)))
    XCTAssertFalse(
      e.resolve(
        ticket, signals: try Signals(satisfied: 0.5, failed: 0.1, insufficient: 0.5),
        current: snap("Maybe ready.", 2, 2), now: time(2)))
    XCTAssertNil(e.observe(snap("Maybe ready.", 3, 20), now: time(20)))
    XCTAssertEqual(e.phase, .observing)
  }

  func testNoMatchExpires() throws {
    var e = engine(timeout: 5)
    let ticket = try XCTUnwrap(e.observe(snap("Queued.", 1, 1), now: time(1)))
    XCTAssertFalse(
      e.resolve(ticket, signals: try no(), current: snap("Queued.", 2, 2), now: time(2)))
    XCTAssertNil(e.observe(snap("Queued.", 3, 6), now: time(6)))
    XCTAssertEqual(e.phase, .expired)
  }

  func testDeadlineAppliesDuringInference() throws {
    var e = engine(timeout: 2)
    let ticket = try XCTUnwrap(e.observe(snap(done, 1, 1), now: time(1)))
    XCTAssertFalse(e.resolve(ticket, signals: try yes(), current: snap(done, 2, 3), now: time(3)))
    XCTAssertEqual(e.phase, .expired)
  }

  func testNetworkOutageStopsWithoutAction() throws {
    var e = engine()
    try candidate(&e)
    e.fail("Network unavailable.")
    XCTAssertNil(e.observe(snap(done, 3, 4), now: time(4)))
    XCTAssertEqual(e.phase, .needsAttention)
  }

  func testClosedAppStopsWithoutAction() {
    var e = engine()
    e.fail("Selected window disappeared.")
    XCTAssertNil(e.observe(snap(done, 1, 1), now: time(1)))
    XCTAssertEqual(e.phase, .needsAttention)
  }

  func testRequestBudgetIncludesConfirmation() throws {
    var e = engine(maxRequests: 1)
    try candidate(&e)
    XCTAssertNil(e.observe(snap(done, 3, 4), now: time(4)))
    XCTAssertEqual(e.phase, .expired)
  }

  func testEmptySnapshotStops() {
    var e = engine()
    XCTAssertNil(e.observe(snap(" \n ", 1, 1), now: time(1)))
    XCTAssertEqual(e.phase, .needsAttention)
  }

  func testDuplicateSequenceIgnored() {
    var e = engine()
    XCTAssertNil(e.observe(snap(done, 0, 1), now: time(1)))
  }

  func testOnlyOneRequestInFlight() throws {
    var e = engine()
    XCTAssertNotNil(e.observe(snap(done, 1, 1), now: time(1)))
    XCTAssertNil(e.observe(snap(done, 2, 2), now: time(2)))
  }

  func testBaselineReappearingClearsCandidate() throws {
    var e = engine()
    try candidate(&e)
    XCTAssertNil(e.observe(snap(baseline, 3, 4), now: time(4)))
    XCTAssertEqual(e.confirmations, 0)
    XCTAssertEqual(e.phase, .observing)
  }

  func testFailedActionNeverRetries() throws {
    var e = engine()
    try candidate(&e)
    let ticket = try XCTUnwrap(e.observe(snap(done, 3, 4), now: time(4)))
    XCTAssertTrue(
      e.resolve(ticket, signals: try yes(), current: snap(done, 4, 4.1), now: time(4.1)))
    e.actionFailed("Folder replaced.")
    XCTAssertEqual(e.phase, .needsAttention)
    XCTAssertNil(e.observe(snap(done, 5, 5), now: time(5)))
  }
}
