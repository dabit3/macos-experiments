import Foundation
import PDFKit
import Testing

@testable import MarginCore

struct MarginCoreTests {
  func excerpt(page: Int = 1, text: String = "A pause is not a failure of movement.") -> Excerpt {
    Excerpt(
      text: text,
      spans: [
        PassageRect(page: page, x: 58, y: 320, width: 250, height: 15)
      ])
  }

  @Test func projectRoundTripPreservesUnicodeAndCitations() throws {
    let original = Project(
      title: "A city’s café", draft: "Pause — notice — belong.", excerpts: [excerpt()])
    let restored = try Project.decode(original.encoded())
    #expect(original == restored)
    #expect(restored.excerpts[0].citation == "[Margin Field Notes, 2026, p. 2]")
    #expect(restored.markdown.contains("## Source"))
    #expect(restored.wordCount == 5)
  }

  @Test func citationsDeduplicateAndSortPages() {
    var passage = excerpt(page: 3)
    passage.spans += [
      PassageRect(page: 1, x: 30, y: 30, width: 100, height: 20),
      PassageRect(page: 3, x: 30, y: 50, width: 100, height: 20),
    ]
    #expect(passage.pages == [2, 4])
    #expect(passage.citation == "[Margin Field Notes, 2026, pp. 2, 4]")
    #expect(passage.citedText.contains(passage.text))
  }

  @Test func invalidProjectsAreRejected() throws {
    #expect(throws: ProjectError.self) { try Project.decode(Data("broken".utf8)) }
    var invalid = Project.sample
    invalid.version = 99
    #expect(throws: ProjectError.self) { try Project.decode(invalid.encoded()) }
    invalid.version = 1
    invalid.excerpts = [excerpt(page: 999)]
    #expect(throws: ProjectError.self) { try Project.decode(invalid.encoded()) }
    invalid.excerpts = [excerpt(), excerpt()]
    invalid.excerpts[1].id = invalid.excerpts[0].id
    #expect(throws: ProjectError.self) { try Project.decode(invalid.encoded()) }
    invalid.excerpts = [excerpt()]
    invalid.excerpts[0].spans[0].width = -1
    #expect(throws: ProjectError.self) { try Project.decode(invalid.encoded()) }
  }

  @Test func collectionSearchAndEmptyWordCount() {
    let project = Project(
      title: "", draft: " \n\t ",
      excerpts: [excerpt(), excerpt(page: 2, text: "Public life begins at the edges.")])
    #expect(project.wordCount == 0)
    #expect(project.filteredExcerpts("PAUSE").count == 1)
    #expect(project.filteredExcerpts("p. 3").count == 1)
    #expect(project.filteredExcerpts("unknown").isEmpty)
    #expect(project.filteredExcerpts("  ").count == 2)
  }

  @MainActor @Test func sourceIsFiveSearchablePagesWithCompleteParagraphs() throws {
    let directory = try artifactDirectory()
    let url = directory.appendingPathComponent("Source.pdf")
    defer { try? FileManager.default.removeItem(at: directory) }
    try PDFRenderer.generateSource(to: url)
    let document = try #require(PDFDocument(url: url))
    #expect(document.pageCount == 5)
    #expect(
      document.findString("A pause is not a failure of movement", withOptions: .caseInsensitive)
        .count == 1)
    for (index, sourcePage) in SourceMaterial.pages.enumerated() {
      let pageText = try #require(document.page(at: index)?.string)
      let normalized = pageText.split(whereSeparator: \.isWhitespace).joined(separator: " ")
      for paragraph in sourcePage.paragraphs {
        #expect(normalized.contains(paragraph))
      }
      #expect(normalized.contains(sourcePage.pullQuote.replacingOccurrences(of: "\n", with: " ")))
    }
  }

  @MainActor @Test func pdfExportPaginatesWithoutTruncatingText() throws {
    let directory = try artifactDirectory()
    let url = directory.appendingPathComponent("Brief.pdf")
    defer { try? FileManager.default.removeItem(at: directory) }
    let passage = excerpt()
    let body = (1...90).map {
      "Paragraph \($0): A street can make room for belonging and attention."
    }
    .joined(separator: "\n\n")
    let project = Project(
      title: "Export verification", draft: body + "\n\n" + passage.citedText + "\nFINAL SENTINEL",
      excerpts: [passage])
    try PDFRenderer.export(project, to: url)
    let document = try #require(PDFDocument(url: url))
    let text = try #require(document.string)
    #expect(document.pageCount > 1)
    #expect(text.contains("Export verification"))
    #expect(text.contains("Paragraph 1:"))
    #expect(text.contains("Paragraph 90:"))
    #expect(text.contains("FINAL SENTINEL"))
    #expect(text.contains(passage.citation))
    #expect(text.contains("Original illustrative essay"))
  }

  func artifactDirectory() throws -> URL {
    let directory = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Caches/MarginTests/\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}
