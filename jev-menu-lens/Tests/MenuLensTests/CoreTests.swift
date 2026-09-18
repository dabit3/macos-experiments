import Foundation
import XCTest

@testable import MenuLensCore

final class CoreTests: XCTestCase {
  let original = MenuCandidate(id: "m_1", path: ["Edit", "Transformations", "Make Upper Case"])

  func testUnchangedTargetCanExecute() throws {
    try GuardPolicy.validate(
      original: original, current: original, originalState: "same", currentState: "same", age: 1
    )
  }

  func testSelectionOrDocumentMutationBlocksAction() {
    XCTAssertThrowsError(
      try GuardPolicy.validate(
        original: original, current: original, originalState: "selected phrase A",
        currentState: "selected phrase B", age: 1
      ))
  }

  func testMenuAddressReusedForDifferentCommandBlocksAction() {
    let replacement = MenuCandidate(id: "m_1", path: ["Edit", "Delete"])
    XCTAssertThrowsError(
      try GuardPolicy.validate(
        original: original, current: replacement, originalState: "same", currentState: "same",
        age: 1
      ))
  }

  func testDisabledAndExpiredCommandsCannotRun() {
    let disabled = MenuCandidate(id: "m_1", path: original.path, enabled: false)
    XCTAssertThrowsError(
      try GuardPolicy.validate(
        original: disabled, current: disabled, originalState: "same", currentState: "same", age: 1
      ))
    XCTAssertThrowsError(
      try GuardPolicy.validate(
        original: original, current: original, originalState: "same", currentState: "same", age: 121
      ))
  }

  func testCheckedStateChangeInvalidatesTogglePreview() {
    let checked = MenuCandidate(id: original.id, path: original.path, checked: true)
    XCTAssertThrowsError(
      try GuardPolicy.validate(
        original: original, current: checked, originalState: "same", currentState: "same", age: 1
      ))
  }

  func testUnknownAppAndDestructiveCommandsArePreviewOnly() {
    XCTAssertFalse(
      GuardPolicy.permits(bundleID: "com.apple.finder", path: ["File", "Move to Trash"]))
    XCTAssertFalse(GuardPolicy.permits(bundleID: "com.apple.TextEdit", path: ["File", "Save"]))
    XCTAssertFalse(GuardPolicy.permits(bundleID: "com.example.fake", path: original.path))
    XCTAssertFalse(
      GuardPolicy.permits(
        bundleID: "com.apple.TextEdit", path: ["Edit", "Services", "Make Upper Case"]))
    XCTAssertTrue(GuardPolicy.permits(bundleID: "com.apple.TextEdit", path: original.path))
    XCTAssertTrue(
      GuardPolicy.permits(bundleID: "com.apple.finder", path: ["View", "Sort By", "Date Modified"]))
  }

  func testNotPermittedBlocksEvenIfModelHasHighConfidence() {
    let unsupported = MenuCandidate(id: "unsafe", path: ["File", "Delete"], permitted: false)
    XCTAssertThrowsError(
      try GuardPolicy.validate(
        original: unsupported, current: unsupported, originalState: "same", currentState: "same",
        age: 1
      ))
  }

  func decode(_ json: String) throws -> Answer {
    try JSONDecoder().decode(Answer.self, from: Data(json.utf8))
  }

  func testRealScoreContractAcceptsFloat() throws {
    let answer = try decode(
      """
      {"type":"score","score":2.75,"confidence":0.8,
      "probabilities":{"0":0,"1":0,"2":0.25,"3":0.75},
      "legend":{"0":"none","1":"topic","2":"partial","3":"direct"}}
      """)
    guard case .score(let value, let confidence) = answer else { return XCTFail("Wrong type") }
    XCTAssertEqual(value, 2.75)
    XCTAssertEqual(confidence, 0.8)
  }

  func testMalformedResponsesFailClosed() {
    let cases = [
      #"{"type":"score","score":4,"confidence":0.8,"probabilities":{"0":0,"1":0,"2":0,"3":1},"legend":{"0":"","1":"","2":"","3":""}}"#,
      #"{"type":"choice","choice":"invented","confidence":0.8,"probabilities":{"known":1}}"#,
      #"{"type":"choice","choice":"known","confidence":1.1,"probabilities":{"known":1}}"#,
      #"{"type":"choice","choice":"known","confidence":0.8,"probabilities":{"known":0.2}}"#,
      #"{"type":"noul","noul":-0.1}"#,
      #"{"type":"score","score":2,"confidence":0.8,"probabilities":{"0":0,"1":0,"2":1},"legend":{"0":"","1":"","2":""}}"#,
      #"{"type":"generated","text":"Click Delete"}"#,
    ]
    for json in cases { XCTAssertThrowsError(try decode(json), json) }
  }

  func testNoulHasNoConfidenceRequirement() throws {
    guard case .noul(let value) = try decode(#"{"type":"noul","noul":0.5}"#) else {
      return XCTFail("Wrong type")
    }
    XCTAssertEqual(value, 0.5)
  }

  func testRetryDelayIsBoundedAndHonorsSeconds() {
    XCTAssertEqual(JevClient.retryDelay("3", attempt: 0), 3)
    XCTAssertEqual(JevClient.retryDelay("900", attempt: 0), 10)
    XCTAssertEqual(JevClient.retryDelay(nil, attempt: 1), 1.2)
  }

  func testLocallyHashedContentDetectsMutationWithoutStoringText() {
    XCTAssertNotEqual(digest("original"), digest("changed"))
    XCTAssertEqual(digest("original").count, 64)
    XCTAssertFalse(digest("original").contains("original"))
  }
}
