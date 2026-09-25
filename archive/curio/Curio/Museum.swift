import Foundation
import SwiftUI
import UIKit

enum Artifact: String, Codable, CaseIterable, Identifiable {
  case camera, vase, record, chair, bottle, book, unpictured
  var id: String { rawValue }
  var title: String { self == .unpictured ? "No illustration" : rawValue.capitalized }
}

struct MuseumCollection: Identifiable, Codable, Equatable {
  var id = UUID()
  var title: String
  var subtitle: String
  var isSample = false
}

struct MuseumObject: Identifiable, Codable, Equatable {
  var id = UUID()
  var collectionID: UUID
  var title: String
  var maker: String
  var story: String
  var acquired: Date
  var tags: [String]
  var artifact: Artifact
  var photo: Data?
  var isFavorite = false
  var isSample = false
  var catalogNumber: Int

  static func tags(from text: String) -> [String] {
    var seen = Set<String>()
    return text.split(separator: ",").compactMap {
      let tag = $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      return !tag.isEmpty && seen.insert(tag).inserted ? tag : nil
    }
  }
}

struct MuseumArchive: Codable, Equatable {
  var collections: [MuseumCollection]
  var objects: [MuseumObject]
  var nextNumber: Int

  static var sample: MuseumArchive {
    let collection = MuseumCollection(
      title: "Everyday icons", subtitle: "Extraordinary stories in ordinary things.", isSample: true
    )
    let titles = [
      "The quiet observer", "Earth, held", "Sunday, on repeat", "A place to pause", "Blue hour",
      "Ways of seeing",
    ]
    let makers = [
      "35 mm rangefinder · 1978", "Studio stoneware · 1964", "12-inch vinyl · 1959",
      "Bentwood chair · 1950", "Blown glass · 1972", "Artist’s book · 1988",
    ]
    let stories = [
      "A camera that asks you to slow down. The satisfying weight, the soft click of the shutter, the way a whole afternoon becomes a single frame. Some objects change how we notice the world.",
      "A small vessel with a generous silhouette. Its warm clay and uneven glaze still carry the hand of its maker. A reminder that useful things can be quietly extraordinary.",
      "A record for long, unhurried mornings. The sleeve is softened at the corners, the grooves still bright. An object that holds both music and the memory of listening.",
      "A familiar curve, a thoughtful joint. This chair makes a small argument for less: just enough wood, just enough shape, and a comfortable place to stay awhile.",
      "Cobalt glass catches the last light of the day. Found on a dusty shelf, this simple bottle turns an ordinary windowsill into a changing exhibition.",
      "Notes, images, and the occasional folded page. A book is a collection inside a collection: a portable place for ideas to meet.",
    ]
    let tags = [
      ["photography", "vintage"], ["ceramics", "handmade"], ["music", "vintage"],
      ["design", "wood"], ["glass", "design"], ["books", "design"],
    ]
    let objects = Artifact.allCases.filter { $0 != .unpictured }.enumerated().map {
      index, artifact in
      MuseumObject(
        collectionID: collection.id, title: titles[index], maker: makers[index],
        story: stories[index],
        acquired: Date(timeIntervalSince1970: 1_704_067_200 + Double(index) * 86_400 * 30),
        tags: tags[index], artifact: artifact, isFavorite: index == 1, isSample: true,
        catalogNumber: index + 1)
    }
    return MuseumArchive(collections: [collection], objects: objects, nextNumber: 7)
  }
}

enum MuseumFailure: LocalizedError {
  case emptyTitle, missingCollection
  var errorDescription: String? {
    switch self {
    case .emptyTitle: "Give your exhibit a title before saving."
    case .missingCollection: "Choose a collection for this object."
    }
  }
}

@MainActor
final class MuseumStore: ObservableObject {
  @Published private(set) var archive: MuseumArchive
  @Published var errorMessage: String?
  private let fileURL: URL
  private var readFailed = false

  init(directory: URL? = nil) {
    let folder =
      directory
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Curio", isDirectory: true)
    fileURL = folder.appendingPathComponent("museum.json")
    archive = MuseumArchive(collections: [], objects: [], nextNumber: 1)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: fileURL.path) {
        archive = try JSONDecoder().decode(MuseumArchive.self, from: Data(contentsOf: fileURL))
      } else {
        let sample = MuseumArchive.sample
        try persist(sample)
        archive = sample
      }
    } catch {
      readFailed = true
      errorMessage =
        "Your museum could not be opened. Existing data has been preserved. \(error.localizedDescription)"
    }
  }

  var collections: [MuseumCollection] { archive.collections }
  var objects: [MuseumObject] { archive.objects }

  func collection(_ id: UUID) -> MuseumCollection? { collections.first { $0.id == id } }
  func object(_ id: UUID) -> MuseumObject? { objects.first { $0.id == id } }
  func number(_ object: MuseumObject) -> String { String(format: "%03d", object.catalogNumber) }

  func query(
    collectionID: UUID? = nil, text: String = "", tag: String? = nil, favorites: Bool = false
  ) -> [MuseumObject] {
    let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return objects.filter { item in
      (collectionID == nil || item.collectionID == collectionID)
        && (!favorites || item.isFavorite)
        && (tag.map { item.tags.contains($0) } ?? true)
        && (words.isEmpty
          || ([item.title, item.maker, item.story] + item.tags).joined(separator: " ")
            .localizedStandardContains(words))
    }
  }

  @discardableResult
  func saveCollection(_ collection: MuseumCollection) -> Bool {
    mutate { draft in
      var cleaned = collection
      cleaned.title = cleaned.title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !cleaned.title.isEmpty else { throw MuseumFailure.emptyTitle }
      if let index = draft.collections.firstIndex(where: { $0.id == cleaned.id }) {
        draft.collections[index] = cleaned
      } else {
        draft.collections.append(cleaned)
      }
    }
  }

  @discardableResult
  func saveObject(_ object: MuseumObject) -> Bool {
    mutate { draft in
      var cleaned = object
      cleaned.title = cleaned.title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !cleaned.title.isEmpty else { throw MuseumFailure.emptyTitle }
      guard draft.collections.contains(where: { $0.id == cleaned.collectionID }) else {
        throw MuseumFailure.missingCollection
      }
      if let index = draft.objects.firstIndex(where: { $0.id == cleaned.id }) {
        draft.objects[index] = cleaned
      } else {
        cleaned.catalogNumber = draft.nextNumber
        draft.nextNumber += 1
        draft.objects.append(cleaned)
      }
    }
  }

  func toggleFavorite(_ id: UUID) {
    mutate { draft in
      if let index = draft.objects.firstIndex(where: { $0.id == id }) {
        draft.objects[index].isFavorite.toggle()
      }
    }
  }

  @discardableResult
  func deleteObject(_ id: UUID) -> Bool {
    mutate { $0.objects.removeAll { $0.id == id } }
  }

  @discardableResult
  func deleteCollection(_ id: UUID) -> Bool {
    mutate {
      $0.objects.removeAll { $0.collectionID == id }
      $0.collections.removeAll { $0.id == id }
    }
  }

  @discardableResult
  private func mutate(_ change: (inout MuseumArchive) throws -> Void) -> Bool {
    guard !readFailed else {
      errorMessage =
        "Changes are disabled because the saved museum could not be read. Your original file is preserved."
      return false
    }
    do {
      var draft = archive
      try change(&draft)
      try persist(draft)
      archive = draft
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  private func persist(_ archive: MuseumArchive) throws {
    try JSONEncoder().encode(archive).write(to: fileURL, options: .atomic)
  }
}
