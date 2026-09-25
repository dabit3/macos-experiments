import Foundation
import Testing

@testable import PocketPressCore

@Test func templateHasFourUniqueValidLayouts() {
    let magazine = Magazine.coastal()
    #expect(magazine.isValid)
    #expect(magazine.pages.map(\.kind) == [.cover, .photograph, .story, .fieldNotes])
    #expect(Set(magazine.pages.map(\.id)).count == 4)
}

@Test func editsAndThemeSurviveLibraryRoundTrip() throws {
    var issue = Magazine.coastal()
    var cover = issue.pages[0]
    cover.title = "Along the coast"
    cover.caption = "A café, a path, and the sea."
    try issue.replace(cover)
    issue.theme = .nocturne
    let library = PressLibrary(issues: [issue])
    let restored = try PressLibrary.decode(library.encoded())
    #expect(restored == library)
    #expect(restored.issues[0].pages[0].caption == cover.caption)
    #expect(restored.issues[0].theme == .nocturne)
}

@Test func reorderPreservesIdentityAndPinsCover() {
    var issue = Magazine.coastal()
    let original = issue.pages.map(\.id)
    issue.move(original[2], by: -1)
    #expect(issue.pages.map(\.id) == [original[0], original[2], original[1], original[3]])
    issue.move(original[0], by: 1)
    issue.move(original[2], by: -1)
    issue.move(original[3], by: 1)
    #expect(issue.pages.map(\.id) == [original[0], original[2], original[1], original[3]])
    #expect(issue.isValid)
}

@Test func addRemoveAndSnapshotRecovery() throws {
    var issue = Magazine.coastal()
    let snapshot = issue
    let newID = try issue.add(.story)
    #expect(issue.pages.last?.id == newID)
    issue.remove(issue.pages[0].id)
    #expect(issue.pages.first?.kind == .cover)
    issue.remove(newID)
    #expect(issue.pages == snapshot.pages)
    issue = snapshot
    #expect(issue == snapshot)
}

@Test func pageLimitCannotCreateExtraCover() throws {
    var issue = Magazine.coastal()
    #expect(throws: MagazineError.self) { try issue.add(.cover) }
    for _ in 0..<20 { _ = try issue.add(.photograph) }
    #expect(issue.pages.count == 24)
    #expect(throws: MagazineError.self) { try issue.add(.story) }
}

@Test func invalidTextIsRejectedWithoutMutatingPage() {
    var issue = Magazine.coastal()
    let original = issue
    var page = issue.pages[0]
    page.title = " \n "
    #expect(throws: MagazineError.self) { try issue.replace(page) }
    #expect(issue == original)
    page.title = String(repeating: "x", count: 49)
    #expect(page.validationMessage != nil)
    page.title = "A real title"
    page.caption = String(repeating: "é", count: 151)
    #expect(page.validationMessage != nil)
}

@Test func fieldNotesStayWithinPrintableBounds() {
    var page = MagazinePage.sample(.fieldNotes)
    page.body = Array(repeating: "A small observation.", count: 7).joined(separator: "\n")
    #expect(page.validationMessage != nil)
    page.body = String(repeating: "a", count: 151)
    #expect(page.validationMessage != nil)
    page.body = Array(repeating: "An observation.", count: 6).joined(separator: "\n")
    #expect(page.validationMessage == nil)
}

@Test func malformedAndIncompatibleLibrariesFail() throws {
    #expect(throws: Error.self) { try PressLibrary.decode(Data("broken".utf8)) }
    var library = PressLibrary(issues: [.coastal()])
    library.version = 2
    #expect(throws: MagazineError.self) { try PressLibrary.decode(library.encoded()) }
    library.version = 1
    library.issues[0].pages.removeFirst()
    #expect(throws: MagazineError.self) { try PressLibrary.decode(library.encoded()) }
}

@Test func duplicateIdentifiersAreRejected() throws {
    var library = PressLibrary(issues: [.coastal()])
    library.issues[0].pages[1].id = library.issues[0].pages[2].id
    #expect(throws: MagazineError.self) { try PressLibrary.decode(library.encoded()) }
    let issue = Magazine.coastal()
    #expect(throws: MagazineError.self) {
        try PressLibrary.decode(PressLibrary(issues: [issue, issue]).encoded())
    }
}

@Test func exportNameCannotEscapeExportDirectory() {
    var issue = Magazine.coastal()
    issue.pages[0].title = "../../Café / Italy?"
    #expect(!issue.exportFilename.contains("/"))
    #expect(!issue.exportFilename.contains(".."))
    #expect(issue.exportFilename.hasPrefix("Café-Italy-"))
    #expect(issue.exportFilename.hasSuffix(".pdf"))
}
