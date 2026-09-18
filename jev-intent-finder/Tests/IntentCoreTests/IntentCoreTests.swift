import AppKit
import Foundation
import Testing

@testable import IntentCore

struct IntentCoreTests {
  private let response = """
    {"model":"jev-test","answers":{
    "relevance":{"type":"score","score":2.9,"confidence":0.9,"probabilities":{"0":0,"1":0,"2":0.1,"3":0.9}},
    "requirements":{"type":"noul","noul":0.98},"contradiction":{"type":"noul","noul":0.01}}}
    """

  @Test func typedDecodingAndThresholds() throws {
    let result = try Judgment.decode(Data(response.utf8), milliseconds: 45, requests: 1)
    #expect(result.accepted)
    #expect(result.model == "jev-test")
    #expect(result.rank > 0.9)
    let contradiction = response.replacingOccurrences(of: "\"noul\":0.01", with: "\"noul\":0.99")
    #expect(try !Judgment.decode(Data(contradiction.utf8), milliseconds: 1, requests: 1).accepted)
    let uncertain = response.replacingOccurrences(of: "\"noul\":0.98", with: "\"noul\":0.5")
    #expect(try !Judgment.decode(Data(uncertain.utf8), milliseconds: 1, requests: 1).accepted)
  }

  @Test func rejectsMalformedTypedResponses() {
    for invalid in [
      response.replacingOccurrences(of: "\"score\":2.9", with: "\"score\":4.2"),
      response.replacingOccurrences(of: "\"confidence\":0.9", with: "\"confidence\":-1"),
      response.replacingOccurrences(of: "\"noul\":0.98", with: "\"noul\":1.2"),
      response.replacingOccurrences(of: "\"type\":\"score\"", with: "\"type\":\"choice\""),
      response.replacingOccurrences(of: "\"3\":0.9", with: "\"3\":0.1"),
      response.replacingOccurrences(of: "\"requirements\"", with: "\"missing\""),
    ] {
      #expect(throws: (any Error).self) {
        try Judgment.decode(Data(invalid.utf8), milliseconds: 0, requests: 1)
      }
    }
  }

  @Test func obsoleteIntentAndGenerationCannotAct() throws {
    let generation = UUID()
    let old = SearchIdentity(generation: generation, query: "signed not draft")
    try old.validate(current: old)
    #expect(throws: FinderError.self) {
      try old.validate(current: SearchIdentity(generation: generation, query: "draft not signed"))
    }
    #expect(throws: FinderError.self) {
      try old.validate(current: SearchIdentity(generation: UUID(), query: old.query))
    }
  }

  @Test func retryAfterHonorsSecondsAndHTTPDate() {
    #expect(JevClient.retryDelay("9", attempt: 0) == 9)
    #expect(JevClient.retryDelay(nil, attempt: 1) == 2.25)
    let now = Date(timeIntervalSince1970: 0)
    #expect(JevClient.retryDelay("Thu, 01 Jan 1970 00:00:12 GMT", attempt: 0, now: now) == 12)
    #expect(JevClient.retryDelay("NaN", attempt: 0) == 1.25)
  }

  @Test @MainActor func nativeExtractionAndFreshness() throws {
    let folder = try scratch()
    defer { try? FileManager.default.removeItem(at: folder) }
    try Fixtures.write(to: folder)
    let scan = try Documents.scan(folder)
    #expect(scan.documents.count == 30)
    #expect(scan.notices.isEmpty)
    #expect(scan.documents.allSatisfy { $0.complete })
    let pdf = try Documents.extract(folder.appendingPathComponent("scan_0042.pdf"))
    #expect(pdf.text.contains("without cause"))
    #expect(pdf.text.contains("COMPLETED"))
    let rtf = try Documents.extract(folder.appendingPathComponent("untitled_06.rtf"))
    #expect(rtf.text.contains("ten tabs"))
    try pdf.verify()
    let identity = SearchIdentity(generation: UUID(), query: "signed")
    try FinderActions.validate([pdf, rtf], identity: identity, current: identity)
    try "A replaced document".write(to: rtf.url, atomically: true, encoding: .utf8)
    #expect(throws: FinderError.self) {
      try FinderActions.validate([pdf, rtf], identity: identity, current: identity)
    }
    try FileManager.default.removeItem(at: pdf.url)
    #expect(throws: (any Error).self) { try pdf.verify() }
    #expect(throws: FinderError.self) {
      try FinderActions.validate([], identity: identity, current: identity)
    }
  }

  @Test func sameSizeSameTimeRewriteCannotAct() throws {
    let folder = try scratch()
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("item.txt")
    try "signed".write(to: url, atomically: false, encoding: .utf8)
    let doc = try Documents.extract(url)
    try "draft!".write(to: url, atomically: false, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.modificationDate: doc.stamp.modified], ofItemAtPath: url.path)
    #expect(throws: FinderError.self) { try doc.verify() }
  }

  @Test func scopeCapsSymlinksAndPartialTextAreVisible() throws {
    let folder = try scratch()
    defer { try? FileManager.default.removeItem(at: folder) }
    let original = folder.appendingPathComponent("000.txt")
    try String(repeating: "a", count: 14_001).write(to: original, atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: folder.appendingPathComponent("link.txt"), withDestinationURL: original)
    let partial = try Documents.extract(original)
    #expect(!partial.complete)
    #expect(partial.text.count == 14_000)
    for index in 1...122 {
      try "Synthetic entry".write(
        to: folder.appendingPathComponent(String(format: "%03d.md", index)),
        atomically: true, encoding: .utf8)
    }
    let scan = try Documents.scan(folder)
    #expect(scan.documents.count == 120)
    #expect(scan.documents.allSatisfy { $0.name != "link.txt" })
    #expect(scan.notices.contains { $0.contains("first 120") })
  }

  @Test func missingKeyIsExplicit() async {
    let client = JevClient(key: "")
    await #expect(throws: FinderError.self) {
      try await client.evaluate(query: "find agreement", text: "sample")
    }
  }

  private func scratch() throws -> URL {
    let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent(".build/test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
  }
}
