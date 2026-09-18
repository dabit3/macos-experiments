import Foundation
import XCTest

@testable import PasteCore

final class PasteCoreTests: XCTestCase {
  func testUnicodeSpansRoundTripThroughUTF16() throws {
    let document = try SourceDocument(
      "Company: Café Étoile 株式会社\nBilling contact: Zoë 🪴 Müller\nEmail: zoe@example.test")
    for candidate in document.candidates {
      XCTAssertEqual(try document.exactText(candidate), candidate.text)
    }
    XCTAssertTrue(document.candidates.contains { $0.text == "Zoë 🪴 Müller" })
    XCTAssertTrue(document.candidates.contains { $0.text == "Café Étoile 株式会社" })
  }

  func testFullAddressesRemainSeparate() throws {
    let document = try SourceDocument(
      "Billing address:\n8 Oak Lane\nBath BA1\n\nShipping address:\n4 Dock Road\nBristol BS1")
    let addresses = document.candidates.filter { $0.kind == "address block" }.map(\.text)
    XCTAssertEqual(addresses, ["8 Oak Lane\nBath BA1", "4 Dock Road\nBristol BS1"])
  }

  func testSourceLimitsFailWithoutSilentTruncation() throws {
    XCTAssertThrowsError(try SourceDocument(String(repeating: "a", count: 12_001)))
    XCTAssertThrowsError(
      try SourceDocument((1...70).map { "Name \($0): Person \($0)" }.joined(separator: "\n")))
    XCTAssertThrowsError(try SourceDocument(" \n "))
  }

  func testCandidatesFromAnotherSourceAreRejected() throws {
    let first = try SourceDocument("Email: one@example.test")
    let second = try SourceDocument("Email: two@example.test")
    XCTAssertThrowsError(try first.exactText(XCTUnwrap(second.candidates.first)))
  }

  func testNonLabelRegexFindsEmailPhoneAndAmount() throws {
    let document = try SourceDocument(
      "Contact me at alex@example.test; call +1 (415) 555-0182. The refund is €48.20.")
    for value in ["alex@example.test", "+1 (415) 555-0182", "€48.20"] {
      XCTAssertTrue(document.candidates.contains { $0.text == value }, value)
    }
  }

  private func response(
    choice: String = "span_1", confidence: Double = 0.9,
    role: Double = 0.95, type: String = "noul"
  ) -> Data {
    Data(
      """
      {"model":"jev-test","answers":{
        "pick":{"type":"choice","choice":"\(choice)","confidence":\(confidence),
                "probabilities":{"span_1":0.95,"none":0.05}},
        "role_span_1":{"type":"\(type)","noul":\(role)}}}
      """.utf8)
  }

  func testTypedDecisionAndGate() throws {
    let result = try Jev.decode(response(), candidateIDs: ["span_1"], milliseconds: 45, requests: 1)
    XCTAssertTrue(result.approved)
    XCTAssertEqual(result.milliseconds, 45)
    XCTAssertEqual(result.model, "jev-test")
    let mismatch = try Jev.decode(
      response(role: 0.2), candidateIDs: ["span_1"], milliseconds: 0, requests: 1)
    XCTAssertFalse(mismatch.approved)
    let uncertain = try Jev.decode(
      response(confidence: 0.4), candidateIDs: ["span_1"], milliseconds: 0, requests: 1)
    XCTAssertFalse(uncertain.approved)
  }

  func testStrictDecodingRejectsInventedChoicesAndInvalidNumbers() {
    XCTAssertThrowsError(
      try Jev.decode(
        response(choice: "invented"), candidateIDs: ["span_1"], milliseconds: 0, requests: 1))
    XCTAssertThrowsError(
      try Jev.decode(response(role: 1.01), candidateIDs: ["span_1"], milliseconds: 0, requests: 1))
    XCTAssertThrowsError(
      try Jev.decode(
        response(confidence: -0.1), candidateIDs: ["span_1"], milliseconds: 0, requests: 1))
    XCTAssertThrowsError(
      try Jev.decode(
        response(type: "score"), candidateIDs: ["span_1"], milliseconds: 0, requests: 1))
    XCTAssertThrowsError(
      try Jev.decode(response(), candidateIDs: ["span_1", "span_2"], milliseconds: 0, requests: 1))
  }

  func testNoneIsNeverApproved() throws {
    let result = try Jev.decode(
      response(choice: "none"), candidateIDs: ["span_1"], milliseconds: 0, requests: 1)
    XCTAssertFalse(result.approved)
  }

  func testEachRoleQuestionNamesItsOwnCandidate() throws {
    struct Question: Decodable { let instructions: String }
    struct Request: Decodable { let questions: [String: Question] }
    let source = try SourceDocument("Billing email: a@example.test\nSales email: b@example.test")
    let data = try Jev.request(
      source: source, target: FieldContext(app: "Fixture", title: "Billing email"))
    let request = try JSONDecoder().decode(Request.self, from: data)
    for candidate in source.candidates {
      XCTAssertTrue(
        try XCTUnwrap(request.questions["role_\(candidate.id)"]).instructions.contains(
          "`\(candidate.id)`"))
    }
  }

  func testRetriesAreBoundedAndRespectRetryAfter() {
    XCTAssertEqual(Jev.retryDelay(status: 429, retryAfter: "3", attempt: 0), 3)
    XCTAssertNil(Jev.retryDelay(status: 429, retryAfter: "60", attempt: 0))
    XCTAssertNil(Jev.retryDelay(status: 401, retryAfter: nil, attempt: 0))
    XCTAssertNil(Jev.retryDelay(status: 503, retryAfter: nil, attempt: 2))
    XCTAssertNotNil(Jev.retryDelay(status: 529, retryAfter: nil, attempt: 1))
  }

  func testStaleAndSecureTargetsCannotAct() throws {
    let original = FieldVersion(
      identity: "100:fixture", role: "AXTextField", label: "Billing",
      value: "old", selection: NSRange(location: 0, length: 3))
    try original.validate(
      against: original, sameElement: true, sameWindow: true, focused: true, secure: false)
    for changed in [
      FieldVersion(
        identity: "200:fixture", role: "AXTextField", label: "Billing", value: "old",
        selection: original.selection),
      FieldVersion(
        identity: original.identity, role: "AXTextArea", label: "Billing", value: "old",
        selection: original.selection),
      FieldVersion(
        identity: original.identity, role: original.role, label: "Sales", value: "old",
        selection: original.selection),
      FieldVersion(
        identity: original.identity, role: original.role, label: original.label, value: "new",
        selection: original.selection),
      FieldVersion(
        identity: original.identity, role: original.role, label: original.label, value: "old",
        selection: NSRange(location: 2, length: 0)),
    ] {
      XCTAssertThrowsError(
        try original.validate(
          against: changed, sameElement: true, sameWindow: true, focused: true, secure: false))
    }
    XCTAssertThrowsError(
      try original.validate(
        against: original, sameElement: false, sameWindow: true, focused: true, secure: false))
    XCTAssertThrowsError(
      try original.validate(
        against: original, sameElement: true, sameWindow: false, focused: true, secure: false))
    XCTAssertThrowsError(
      try original.validate(
        against: original, sameElement: true, sameWindow: true, focused: false, secure: false))
    XCTAssertThrowsError(
      try original.validate(
        against: original, sameElement: true, sameWindow: true, focused: true, secure: true))
  }
}
