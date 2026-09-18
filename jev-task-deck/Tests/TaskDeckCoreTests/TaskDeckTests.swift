import Foundation
import XCTest

@testable import TaskDeckCore

final class TaskDeckTests: XCTestCase {
  private func window(
    pid: Int32 = 12, launch: Double = 100, title: String = "Draft",
    document: String = "file:///a.txt", text: String = "Body",
    date: Date = Date()
  ) -> WindowEvidence {
    WindowEvidence(
      app: "TextEdit", bundleID: "com.apple.TextEdit", pid: pid,
      launchTime: launch, title: title, document: document, text: text, capturedAt: date)
  }

  func testFreshEvidenceAllowsDifferentObservationID() {
    XCTAssertTrue(window().isFresh(comparedTo: window()))
  }
  func testRejectsPIDReuseAfterRelaunch() {
    XCTAssertFalse(window().isFresh(comparedTo: window(launch: 200)))
    XCTAssertFalse(window().isFresh(comparedTo: window(pid: 13)))
  }
  func testRejectsSameTitleWithChangedDocumentOrBody() {
    XCTAssertFalse(window().isFresh(comparedTo: window(document: "file:///b.txt")))
    XCTAssertFalse(window().isFresh(comparedTo: window(text: "Changed body")))
    XCTAssertFalse(window().isFresh(comparedTo: window(title: "Other")))
  }
  func testExpiresAfterFiveMinutes() {
    XCTAssertFalse(window(date: Date().addingTimeInterval(-301)).isFresh(comparedTo: window()))
  }
  func testLayoutRespectsNegativeDisplayOriginAndBounds() {
    let bounds = Frame(x: -1920, y: -500, width: 1900, height: 1000)
    for count in 1...4 {
      let frames = DeckLayout.frames(count: count, in: bounds)
      XCTAssertEqual(frames.count, count)
      for frame in frames {
        XCTAssertGreaterThanOrEqual(frame.x, bounds.x)
        XCTAssertGreaterThanOrEqual(frame.y, bounds.y)
        XCTAssertLessThanOrEqual(frame.x + frame.width, bounds.x + bounds.width + 0.01)
        XCTAssertLessThanOrEqual(frame.y + frame.height, bounds.y + bounds.height + 0.01)
      }
    }
    XCTAssertTrue(DeckLayout.frames(count: 5, in: bounds).isEmpty)
    XCTAssertTrue(DeckLayout.frames(count: 0, in: bounds).isEmpty)
  }
  func testSmallScreenIsUnsupported() {
    XCTAssertTrue(
      DeckLayout.frames(count: 3, in: Frame(x: 0, y: 0, width: 400, height: 300)).isEmpty)
  }

  private func response(
    score: String = "2.8", concentration: String = "0.9",
    conflict: String = "0.01", type: String = "score",
    probabilities: String = "\"0\":0,\"1\":0,\"2\":0.2,\"3\":0.8"
  ) -> Data {
    Data(
      """
      {"model":"jev-test","answers":{"relevance":{"type":"\(type)","score":\(score),"confidence":\(concentration),"probabilities":{\(probabilities)},"legend":{"0":"a","1":"b","2":"c","3":"d"}},"contradiction":{"type":"noul","noul":\(conflict)}}}
      """.utf8)
  }
  func testValidTypedMixedResponseSelectsDirectEvidence() throws {
    let result = try JevResponse.validated(response(), milliseconds: 100, requests: 1)
    XCTAssertTrue(result.selected)
    XCTAssertEqual(result.model, "jev-test")
    XCTAssertEqual(result.requests, 1)
  }
  func testContradictionVetoAndUncertainOutcome() throws {
    let veto = try JevResponse.validated(response(conflict: "0.95"), milliseconds: 0, requests: 1)
    XCTAssertFalse(veto.selected)
    XCTAssertEqual(veto.label, "Conflicting evidence")
    let uncertain = try JevResponse.validated(
      response(concentration: "0.2", conflict: "0.5"), milliseconds: 0, requests: 1)
    XCTAssertFalse(uncertain.selected)
    XCTAssertEqual(uncertain.label, "Needs review")
  }
  func testDiffuseScoreDistributionDoesNotVetoUsefulEvidence() throws {
    let result = try JevResponse.validated(
      response(score: "2.4", concentration: "0.37", conflict: "0.11"),
      milliseconds: 100, requests: 1)
    XCTAssertTrue(result.selected)
  }
  func testMinimizedDocumentDialogsRemainDiscoverable() {
    XCTAssertTrue(
      WindowCapturePolicy.supports(
        subrole: "AXDialog", minimized: true, document: "file:///fixture/Notes.txt"))
    XCTAssertTrue(
      WindowCapturePolicy.supports(
        subrole: "AXStandardWindow", minimized: false, document: ""))
    XCTAssertFalse(
      WindowCapturePolicy.supports(
        subrole: "AXDialog", minimized: false, document: "file:///fixture/Notes.txt"))
    XCTAssertFalse(
      WindowCapturePolicy.supports(
        subrole: "AXDialog", minimized: true, document: ""))
    XCTAssertFalse(
      WindowCapturePolicy.supports(
        subrole: "AXSheet", minimized: true, document: "file:///fixture/Notes.txt"))
  }
  func testRejectsOutOfRangeAndWrongTypes() {
    for data in [
      response(score: "3.01"), response(score: "-1"), response(conflict: "1.1"),
      response(concentration: "-0.1"), response(type: "choice"),
      response(probabilities: "\"0\":1,\"1\":1,\"2\":1,\"3\":1"),
      response(probabilities: "\"0\":0.2,\"1\":0.3,\"2\":0.5"),
    ] {
      XCTAssertThrowsError(try JevResponse.validated(data, milliseconds: 0, requests: 1))
    }
  }
  func testMissingAnswerFailsClosed() {
    XCTAssertThrowsError(
      try JevResponse.validated(
        Data("{\"model\":\"jev\",\"answers\":{}}".utf8),
        milliseconds: 0, requests: 1))
  }
  func testRetryAfterSecondsAndHTTPDate() {
    XCTAssertEqual(JevClient.retryDelay("12", attempt: 0), 12)
    XCTAssertEqual(JevClient.retryDelay(nil, attempt: 1), 2)
    XCTAssertEqual(JevClient.retryDelay("-1", attempt: 0), 0)
    let date = Date(timeIntervalSince1970: 0)
    XCTAssertEqual(JevClient.retryDelay("Thu, 01 Jan 1970 00:00:10 GMT", attempt: 0, now: date), 10)
  }
  func testFrameReadbackTolerance() {
    let original = Frame(x: 12, y: 30, width: 600, height: 500)
    XCTAssertTrue(original.approximatelyEquals(Frame(x: 13, y: 30, width: 600, height: 501)))
    XCTAssertFalse(original.approximatelyEquals(Frame(x: 40, y: 30, width: 600, height: 500)))
  }
}
