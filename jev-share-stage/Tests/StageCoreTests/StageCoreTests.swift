import Foundation
import StageCore
import XCTest

final class StageCoreTests: XCTestCase {
  let valid = """
    {"model":"jev-test","answers":{"relevance":{"type":"score","score":1.9,"confidence":0.9,"probabilities":{"0":0.01,"1":0.08,"2":0.91}},"mismatch":{"type":"noul","noul":0.02},"policyConflict":{"type":"noul","noul":0.01}}}
    """
  func evidence(_ text: String = "Public roadmap", identity: String = "pid:window") -> Evidence {
    Evidence(identity: identity, title: "Roadmap", text: text, complete: true)
  }
  func judgment(_ json: String? = nil) throws -> Judgment {
    Judgment(
      response: try JevResponse.decode(Data((json ?? valid).utf8)), milliseconds: 12,
      requests: 1, fingerprint: evidence().fingerprint, audience: "Customer")
  }
  func testFreshnessPinsAudienceContentAndIdentity() throws {
    let j = try judgment()
    XCTAssertEqual(j.verdict(for: evidence(), audience: "Customer"), .keep)
    XCTAssertFalse(j.isFresh(evidence(), audience: "Public"))
    XCTAssertFalse(j.isFresh(evidence("Internal draft"), audience: "Customer"))
    XCTAssertFalse(j.isFresh(evidence(identity: "reused-pid:new-window"), audience: "Customer"))
    XCTAssertEqual(j.verdict(for: evidence("Changed"), audience: "Customer"), .review)
  }
  func testIncompleteAndEmptyNeverKeep() throws {
    let j = try judgment()
    XCTAssertFalse(
      j.isFresh(
        Evidence(
          identity: "pid:window", title: "Roadmap",
          text: "Public roadmap", complete: false), audience: "Customer"))
    XCTAssertEqual(j.verdict(for: evidence(""), audience: "Customer"), .review)
  }
  func testNoulAmbiguityAndConflictAreIndependentOfRelevance() throws {
    let uncertain = try judgment(
      valid.replacingOccurrences(of: "\"noul\":0.02", with: "\"noul\":0.5"))
    XCTAssertEqual(uncertain.verdict(for: evidence(), audience: "Customer"), .review)
    let conflict = try judgment(
      valid.replacingOccurrences(of: "\"noul\":0.01", with: "\"noul\":0.98"))
    XCTAssertEqual(conflict.verdict(for: evidence(), audience: "Customer"), .cover)
  }
  func testRejectsWrongTypesMissingAndOutOfRangeAnswers() {
    for bad in [
      valid.replacingOccurrences(of: "\"noul\":0.02", with: "\"noul\":1.2"),
      valid.replacingOccurrences(of: "\"score\":1.9", with: "\"score\":3"),
      valid.replacingOccurrences(of: "\"type\":\"score\"", with: "\"type\":\"choice\""),
      valid.replacingOccurrences(of: "\"2\":0.91", with: "\"2\":0.1"),
      "{\"model\":\"jev-test\",\"answers\":{}}",
    ] {
      XCTAssertThrowsError(try JevResponse.decode(Data(bad.utf8)))
    }
  }
  func testConfidentNoMatchCanBeCoveredWithoutInventingAuthorization() throws {
    let unrelated =
      valid
      .replacingOccurrences(of: "\"score\":1.9", with: "\"score\":0.1")
      .replacingOccurrences(of: "\"noul\":0.02", with: "\"noul\":0.5")
    let result = try judgment(unrelated)
    XCTAssertEqual(result.verdict(for: evidence(), audience: "Customer"), .cover)
    XCTAssertEqual(result.verdict(for: evidence("Changed"), audience: "Customer"), .review)
    let uncertain = try judgment(
      unrelated.replacingOccurrences(of: "\"confidence\":0.9", with: "\"confidence\":0.4"))
    XCTAssertEqual(uncertain.verdict(for: evidence(), audience: "Customer"), .review)
  }
  func testRequestReferencesStateAndDoesNotSerializeCredentials() throws {
    let body = String(
      decoding: try JevClient.requestBody(evidence: evidence(), audience: "Customer"), as: UTF8.self
    )
    XCTAssertTrue(body.contains("state.window.text"))
    XCTAssertTrue(body.contains("state.audienceAndPurpose"))
    XCTAssertFalse(body.contains("Authorization"))
  }
  func testRetryAfterSecondsDateAndFallback() {
    XCTAssertEqual(JevClient.retryDelay("8", attempt: 0), 8)
    XCTAssertEqual(JevClient.retryDelay(nil, attempt: 1), 1)
    XCTAssertEqual(JevClient.retryDelay("-1", attempt: 0), 0)
    XCTAssertEqual(
      JevClient.retryDelay(
        "Thu, 01 Jan 1970 00:00:10 GMT", attempt: 0,
        now: Date(timeIntervalSince1970: 0)), 10)
  }
}
