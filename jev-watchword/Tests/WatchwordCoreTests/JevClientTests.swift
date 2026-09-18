import Foundation
import XCTest

@testable import WatchwordCore

final class JevClientTests: XCTestCase {
  func response(type: String = "noul", value: String = "0.98") -> Data {
    Data(
      """
      {"model":"jev-test","answers":{
      "satisfied":{"type":"\(type)","noul":\(value)},
      "failed":{"type":"noul","noul":0.01},
      "insufficient":{"type":"noul","noul":0.02}}}
      """.utf8)
  }
  func testStrictNoulResponse() throws {
    XCTAssertTrue(try JevClient.decode(response()).signals.confirmed)
  }
  func testWrongPrimitiveRejected() {
    XCTAssertThrowsError(try JevClient.decode(response(type: "score")))
  }
  func testOutOfRangeRejected() {
    XCTAssertThrowsError(try JevClient.decode(response(value: "1.01")))
    XCTAssertThrowsError(try JevClient.decode(response(value: "-0.2")))
  }
  func testMissingSignalRejected() {
    XCTAssertThrowsError(try JevClient.decode(Data(#"{"model":"jev","answers":{}}"#.utf8)))
  }
  func testStringProbabilityRejected() {
    XCTAssertThrowsError(try JevClient.decode(response(value: "\"0.99\"")))
  }
  func testNonfiniteSignalsRejected() {
    XCTAssertThrowsError(try Signals(satisfied: .nan, failed: 0, insufficient: 0))
    XCTAssertThrowsError(try Signals(satisfied: .infinity, failed: 0, insufficient: 0))
  }
  func testKeyFallbackAndMissingKey() {
    XCTAssertNoThrow(
      try JevClient(environment: ["TYPESAFE_API_KEY": "", "JEV_API_KEY": "test-only"]))
    XCTAssertThrowsError(try JevClient(environment: [:]))
  }
  func testRetryAfterSecondsAndExponentialBackoff() {
    XCTAssertEqual(JevClient.retryDelay(header: "7", attempt: 0), 7)
    XCTAssertEqual(JevClient.retryDelay(header: nil, attempt: 2), 4)
    XCTAssertEqual(JevClient.retryDelay(header: "-1", attempt: 0), 0)
  }
  func testRetryAfterHTTPDate() {
    XCTAssertEqual(
      JevClient.retryDelay(
        header: "Thu, 01 Jan 1970 00:00:05 GMT", attempt: 0,
        now: Date(timeIntervalSince1970: 0)), 5)
  }
  func testNewLinesRetainChronologicalContext() {
    let state = EvaluationState(
      condition: "done", baseline: "Old success\nReady", current: "Old success\nNew failure")
    XCTAssertEqual(state.newlyVisible, "New failure")
    XCTAssertEqual(state.current, "Old success\nNew failure")
  }
  func testRequestHasThreeIndependentExplicitQuestions() throws {
    struct Question: Decodable {
      let type: String
      let instructions: String
    }
    struct Request: Decodable { let questions: [String: Question] }
    let data = try JevClient.requestBody(
      EvaluationState(condition: "done", baseline: "old", current: "new"))
    let request = try JSONDecoder().decode(Request.self, from: data)
    XCTAssertEqual(Set(request.questions.keys), ["satisfied", "failed", "insufficient"])
    for question in request.questions.values {
      XCTAssertEqual(question.type, "noul")
      XCTAssertTrue(question.instructions.contains("`current`"))
      XCTAssertTrue(question.instructions.contains("`baseline`"))
    }
  }
}
