import XCTest

@testable import Fieldnotes

final class FieldnotesTests: XCTestCase {
  func testValidationTrimsAndRejectsBlankOrLongNames() throws {
    XCTAssertThrowsError(try ObservationEntry(title: " \n ").validated())
    XCTAssertThrowsError(
      try ObservationEntry(title: String(repeating: "x", count: 101)).validated())
    XCTAssertEqual(try ObservationEntry(title: "  Oak  ").validated().title, "Oak")
  }

  func testTagsNormalizeDeduplicateAndValidateLimits() throws {
    XCTAssertEqual(
      ObservationEntry.normalizedTags(" Rain, garden, rain, , WOODLAND "),
      ["rain", "garden", "woodland"])
    XCTAssertThrowsError(
      try ObservationEntry(title: "Oak", tags: (0...8).map { "tag\($0)" }).validated())
    XCTAssertThrowsError(
      try ObservationEntry(title: "Oak", tags: [String(repeating: "a", count: 31)]).validated())
  }

  func testCombinedFilteringSearchesTagsNotesAndLocation() {
    let entry = ObservationEntry(
      title: "Oak", category: .plants, notes: "Deep lobes", location: "East park",
      tags: ["woodland"], isFavorite: true)
    for query in ["oak", "LOBES", "park", "WOODLAND", "   "] {
      XCTAssertTrue(entry.matches(query: query, category: .plants, favoritesOnly: true))
    }
    XCTAssertFalse(entry.matches(query: "oak", category: .birds, favoritesOnly: false))
    XCTAssertFalse(entry.matches(query: "robin", category: nil, favoritesOnly: true))
    XCTAssertFalse(
      ObservationEntry(title: "Oak").matches(query: "", category: nil, favoritesOnly: true))
  }

  @MainActor
  func testCreateEditFavoriteRelaunchAndDeletePersist() throws {
    let directory = URL.applicationSupportDirectory.appending(path: "FieldnotesTests-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "journal.json")
    let store = JournalStore(fileURL: url, seed: false)
    var entry = ObservationEntry(title: "Robin", category: .birds, photo: Data([1, 2, 3]))
    try store.save(entry)
    entry.notes = "Singing at dusk"
    try store.save(entry)
    try store.toggleFavorite(entry.id)
    let reopened = JournalStore(fileURL: url)
    XCTAssertEqual(reopened.entries.count, 1)
    XCTAssertEqual(reopened.entries[0].notes, "Singing at dusk")
    XCTAssertEqual(reopened.entries[0].photo, Data([1, 2, 3]))
    XCTAssertTrue(reopened.entries[0].isFavorite)
    try reopened.delete(entry.id)
    XCTAssertTrue(JournalStore(fileURL: url).entries.isEmpty)
  }

  @MainActor
  func testSamplesOnlySeedOnceAndRemovalKeepsOwnEntries() throws {
    let directory = URL.applicationSupportDirectory.appending(path: "FieldnotesTests-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "journal.json")
    let store = JournalStore(fileURL: url)
    XCTAssertEqual(store.entries.filter(\.isSample).count, 3)
    try store.save(ObservationEntry(title: "My own leaf"))
    try store.removeSamples()
    XCTAssertEqual(JournalStore(fileURL: url).entries.map(\.title), ["My own leaf"])
  }

  @MainActor
  func testCorruptStorageIsPreservedAndWritesAreRejected() throws {
    let directory = URL.applicationSupportDirectory.appending(path: "FieldnotesTests-\(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "journal.json")
    let original = Data("corrupt".utf8)
    try original.write(to: url)
    let store = JournalStore(fileURL: url)
    XCTAssertNotNil(store.storageError)
    XCTAssertThrowsError(try store.save(ObservationEntry(title: "Leaf")))
    XCTAssertEqual(try Data(contentsOf: url), original)
  }

  func testGuideHasTwelveUniqueSubjectsAndAllSampleLinksResolve() {
    XCTAssertEqual(GuideSubject.all.count, 12)
    XCTAssertEqual(Set(GuideSubject.all.map(\.id)).count, 12)
    XCTAssertTrue(
      GuideSubject.all.allSatisfy { !$0.marks.isEmpty && !$0.habitat.isEmpty && !$0.range.isEmpty })
  }

  func testNoteAndLocationLimits() {
    XCTAssertThrowsError(
      try ObservationEntry(title: "Leaf", notes: String(repeating: "n", count: 6001)).validated())
    XCTAssertThrowsError(
      try ObservationEntry(title: "Leaf", location: String(repeating: "l", count: 201)).validated())
  }
}
