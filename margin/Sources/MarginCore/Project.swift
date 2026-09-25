import Foundation

public struct PassageRect: Codable, Equatable, Sendable {
  public var page: Int
  public var x: Double
  public var y: Double
  public var width: Double
  public var height: Double

  public init(page: Int, x: Double, y: Double, width: Double, height: Double) {
    self.page = page
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }
}

public struct Excerpt: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var text: String
  public var spans: [PassageRect]

  public init(id: UUID = UUID(), text: String, spans: [PassageRect]) {
    self.id = id
    self.text = text
    self.spans = spans
  }

  public var pages: [Int] { Array(Set(spans.map { $0.page + 1 })).sorted() }
  public var pageLabel: String { pages.map(String.init).joined(separator: ", ") }
  public var citation: String {
    "[Margin Field Notes, 2026, \(pages.count == 1 ? "p." : "pp.") \(pageLabel)]"
  }
  public var citedText: String { "“\(text)” \(citation)" }
}

public enum ProjectError: LocalizedError {
  case unsupportedVersion
  case invalidContent

  public var errorDescription: String? {
    switch self {
    case .unsupportedVersion: "This project uses a newer version of Margin."
    case .invalidContent: "This file is not a valid Margin project. Your current work is unchanged."
    }
  }
}

public struct Project: Codable, Equatable, Sendable {
  public var version = 1
  public var title: String
  public var draft: String
  public var excerpts: [Excerpt]

  public init(title: String, draft: String, excerpts: [Excerpt] = []) {
    self.title = title
    self.draft = draft
    self.excerpts = excerpts
  }

  public static let sample = Project(
    title: "A case for slower streets",
    draft: """
      Cities reveal their priorities in the space they give us to pause. A bench, a \
      shaded corner, a generous crossing: each is a small invitation to stay.

      This brief asks a simple question: what changes when we design a street for \
      attention, rather than throughput?

      THE ARGUMENT

      Slower streets can make everyday encounters possible. The source at left offers \
      a useful starting point: observe what people actually do, then design for the \
      moments that traffic counts miss.

      EVIDENCE & IMPLICATIONS

      Collect a passage from the source and bring it into the argument here.
      """
  )

  public var wordCount: Int { draft.split(whereSeparator: { $0.isWhitespace }).count }

  public func filteredExcerpts(_ query: String) -> [Excerpt] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return excerpts }
    return excerpts.filter {
      $0.text.localizedCaseInsensitiveContains(query)
        || $0.citation.localizedCaseInsensitiveContains(query)
    }
  }

  public func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }

  public static func decode(_ data: Data) throws -> Project {
    guard data.count <= 20_000_000,
      let project = try? JSONDecoder().decode(Project.self, from: data)
    else { throw ProjectError.invalidContent }
    guard project.version == 1 else { throw ProjectError.unsupportedVersion }
    guard project.title.count <= 10_000, project.draft.count <= 2_000_000,
      project.excerpts.count <= 10_000,
      Set(project.excerpts.map(\.id)).count == project.excerpts.count,
      project.excerpts.allSatisfy({
        !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          && !$0.spans.isEmpty
          && $0.spans.allSatisfy {
            (0..<SourceMaterial.pages.count).contains($0.page)
              && [$0.x, $0.y, $0.width, $0.height].allSatisfy(\.isFinite)
              && $0.x >= 0 && $0.y >= 0 && $0.width > 0 && $0.height > 0
              && $0.x + $0.width <= 613 && $0.y + $0.height <= 793
          }
      })
    else { throw ProjectError.invalidContent }
    return project
  }

  public var markdown: String {
    let bibliography =
      excerpts.isEmpty
      ? ""
      : "\n\n---\n\n## Source\n\nMargin Field Notes. (2026). *The attentive city: Notes on streets, stillness & public life*. Original illustrative essay bundled with Margin.\n"
    return "# \(title)\n\n\(draft)\(bibliography)\n"
  }
}
