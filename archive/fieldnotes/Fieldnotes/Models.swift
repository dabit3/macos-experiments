import Foundation
import Observation

enum SpecimenCategory: String, Codable, CaseIterable, Identifiable {
  case plants = "Plants"
  case birds = "Birds"
  case insects = "Insects"
  case fungi = "Fungi"
  case other = "Other"
  var id: String { rawValue }
  var symbol: String {
    switch self {
    case .plants: "leaf"
    case .birds: "bird"
    case .insects: "ant"
    case .fungi: "tree"
    case .other: "sparkle.magnifyingglass"
    }
  }
}

struct ObservationEntry: Identifiable, Codable, Equatable {
  var id = UUID()
  var title = ""
  var category: SpecimenCategory = .plants
  var guideID: String?
  var notes = ""
  var location = ""
  var tags: [String] = []
  var date = Date()
  var isFavorite = false
  var isSample = false
  var photo: Data?

  func validated() throws -> Self {
    var result = self
    result.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    result.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
    result.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !result.title.isEmpty else { throw JournalError.invalid("Give your observation a name.") }
    guard result.title.count <= 100 else {
      throw JournalError.invalid("Use 100 characters or fewer for the name.")
    }
    guard result.location.count <= 200 else {
      throw JournalError.invalid("Use 200 characters or fewer for the location.")
    }
    guard result.notes.count <= 6000 else {
      throw JournalError.invalid("Keep notes under 6,000 characters.")
    }
    result.tags = Self.normalizedTags(tags.joined(separator: ","))
    guard result.tags.count <= 8, result.tags.allSatisfy({ $0.count <= 30 }) else {
      throw JournalError.invalid("Add up to 8 tags, each 30 characters or fewer.")
    }
    return result
  }

  static func normalizedTags(_ text: String) -> [String] {
    var seen = Set<String>()
    return text.split(separator: ",").compactMap {
      let tag = $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      return !tag.isEmpty && seen.insert(tag).inserted ? tag : nil
    }
  }

  func matches(query: String, category: SpecimenCategory?, favoritesOnly: Bool) -> Bool {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return (category == nil || self.category == category)
      && (!favoritesOnly || isFavorite)
      && (needle.isEmpty
        || ([title, location, notes] + tags).joined(separator: " ")
          .localizedCaseInsensitiveContains(needle))
  }
}

enum JournalError: LocalizedError {
  case invalid(String)
  var errorDescription: String? {
    switch self {
    case .invalid(let message): message
    }
  }
}

@MainActor @Observable
final class JournalStore {
  private(set) var entries: [ObservationEntry] = []
  var storageError: String?
  private let fileURL: URL
  private var canWrite = true

  init(fileURL: URL? = nil, seed: Bool = true) {
    self.fileURL =
      fileURL
      ?? URL.applicationSupportDirectory
      .appending(path: "Fieldnotes/journal.json")
    do {
      if FileManager.default.fileExists(atPath: self.fileURL.path) {
        entries = try JSONDecoder().decode(
          [ObservationEntry].self, from: Data(contentsOf: self.fileURL))
      } else if seed {
        try commit(Self.samples)
      }
    } catch {
      canWrite = false
      storageError =
        "Your journal could not be opened. Your saved file has been kept intact. \(error.localizedDescription)"
    }
  }

  func save(_ entry: ObservationEntry) throws {
    let valid = try entry.validated()
    var updated = entries
    if let index = updated.firstIndex(where: { $0.id == valid.id }) {
      updated[index] = valid
    } else {
      updated.append(valid)
    }
    try commit(updated.sorted { $0.date > $1.date })
  }

  func delete(_ id: UUID) throws {
    try commit(entries.filter { $0.id != id })
  }

  func toggleFavorite(_ id: UUID) throws {
    guard var entry = entries.first(where: { $0.id == id }) else { return }
    entry.isFavorite.toggle()
    try save(entry)
  }

  func removeSamples() throws { try commit(entries.filter { !$0.isSample }) }

  private func commit(_ updated: [ObservationEntry]) throws {
    guard canWrite else {
      throw JournalError.invalid(
        "The journal is read-only because its saved file could not be opened.")
    }
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(updated).write(to: fileURL, options: .atomic)
    entries = updated
  }

  static var samples: [ObservationEntry] {
    [
      ObservationEntry(
        title: "A quiet unfurling", category: .plants, guideID: "fern",
        notes:
          "New fronds beside the shaded path, still curled at their tips. A reminder to look a little closer.",
        location: "Woodland path", tags: ["woodland", "morning"],
        date: Date().addingTimeInterval(-3600), isFavorite: true, isSample: true),
      ObservationEntry(
        title: "Visitor at the garden wall", category: .birds, guideID: "robin",
        notes: "An American robin paused on the low wall, listening between short bursts of song.",
        location: "Garden wall", tags: ["birdsong", "garden"],
        date: Date().addingTimeInterval(-86400), isSample: true),
      ObservationEntry(
        title: "Small worlds after rain", category: .other, guideID: "snail",
        notes:
          "A garden snail crossing a damp leaf. Its spiral shell caught the soft afternoon light.",
        location: "Back garden", tags: ["rain", "garden"],
        date: Date().addingTimeInterval(-172800), isSample: true),
    ]
  }
}
