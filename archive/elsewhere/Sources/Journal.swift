import Foundation
import SwiftUI

enum JourneyStyle: String, Codable, CaseIterable, Identifiable {
  case coast, mountains, city
  var id: String { rawValue }
  var name: String {
    switch self {
    case .coast: "Sunlit coast"
    case .mountains: "Wild horizons"
    case .city: "Quiet streets"
    }
  }
}

struct Memory: Identifiable, Codable, Equatable {
  var id = UUID()
  var place: String
  var date: Date
  var note: String
  var isFavorite = false
  var photo: Data?
}

struct Journey: Identifiable, Codable, Equatable {
  var id = UUID()
  var title: String
  var region: String
  var style: JourneyStyle
  var isSample = false
  var stops: [Memory] = []

  var stopCountLabel: String { "\(stops.count) \(stops.count == 1 ? "stop" : "stops")" }

  var dateLabel: String {
    guard let first = stops.map(\.date).min(), let last = stops.map(\.date).max() else {
      return "A story waiting to happen"
    }
    let format = Date.FormatStyle.dateTime.month(.abbreviated).day()
    if Calendar.current.isDate(first, inSameDayAs: last) {
      return first.formatted(format) + " · " + first.formatted(.dateTime.year())
    }
    return first.formatted(format) + " — " + last.formatted(format)
  }
}

enum JournalError: LocalizedError {
  case emptyName, missingJourney, missingMemory, unreadable
  var errorDescription: String? {
    switch self {
    case .emptyName: "Give this memory a name before saving."
    case .missingJourney: "This journey is no longer in your journal."
    case .missingMemory: "This stop is no longer in your journal."
    case .unreadable: "Your journal could not be read. Your original data has been left untouched."
    }
  }
}

@MainActor
final class Journal: ObservableObject {
  @Published private(set) var journeys: [Journey] = []
  @Published var errorMessage: String?
  private let fileURL: URL
  private var canWrite = true

  init(directory: URL? = nil, seed: Bool = true) {
    let folder =
      directory ?? URL.documentsDirectory.appending(path: "Elsewhere", directoryHint: .isDirectory)
    fileURL = folder.appending(path: "journal.json")
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: fileURL.path) {
        journeys = try JSONDecoder().decode([Journey].self, from: Data(contentsOf: fileURL))
      } else if seed {
        journeys = Samples.journeys
        try persist(journeys)
      }
    } catch {
      canWrite = false
      errorMessage = JournalError.unreadable.localizedDescription
    }
  }

  var favorites: [(journey: Journey, memory: Memory)] {
    journeys.flatMap { trip in
      trip.stops.filter(\.isFavorite).map { (trip, $0) }
    }
  }

  func journey(_ id: UUID) -> Journey? { journeys.first { $0.id == id } }

  @discardableResult
  func save(_ journey: Journey) -> Bool {
    transact { trips in
      var cleaned = journey
      cleaned.title = journey.title.trimmingCharacters(in: .whitespacesAndNewlines)
      cleaned.region = journey.region.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !cleaned.title.isEmpty else { throw JournalError.emptyName }
      if let index = trips.firstIndex(where: { $0.id == cleaned.id }) {
        trips[index] = cleaned
      } else {
        trips.insert(cleaned, at: 0)
      }
    }
  }

  @discardableResult
  func deleteJourney(_ id: UUID) -> Bool {
    transact { $0.removeAll { $0.id == id } }
  }

  @discardableResult
  func saveMemory(_ memory: Memory, in journeyID: UUID) -> Bool {
    transact { trips in
      guard let index = trips.firstIndex(where: { $0.id == journeyID }) else {
        throw JournalError.missingJourney
      }
      var cleaned = memory
      cleaned.place = memory.place.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !cleaned.place.isEmpty else { throw JournalError.emptyName }
      if let stopIndex = trips[index].stops.firstIndex(where: { $0.id == cleaned.id }) {
        trips[index].stops[stopIndex] = cleaned
      } else {
        trips[index].stops.append(cleaned)
      }
    }
  }

  @discardableResult
  func deleteMemory(_ id: UUID, in journeyID: UUID) -> Bool {
    transact { trips in
      guard let index = trips.firstIndex(where: { $0.id == journeyID }) else {
        throw JournalError.missingJourney
      }
      trips[index].stops.removeAll { $0.id == id }
    }
  }

  func toggleFavorite(_ id: UUID, in journeyID: UUID) {
    transact { trips in
      guard let index = trips.firstIndex(where: { $0.id == journeyID }),
        let stop = trips[index].stops.firstIndex(where: { $0.id == id })
      else { throw JournalError.missingMemory }
      trips[index].stops[stop].isFavorite.toggle()
    }
  }

  func moveMemory(_ id: UUID, in journeyID: UUID, by distance: Int) {
    transact { trips in
      guard let index = trips.firstIndex(where: { $0.id == journeyID }),
        let stop = trips[index].stops.firstIndex(where: { $0.id == id })
      else { throw JournalError.missingMemory }
      let target = min(max(0, stop + distance), trips[index].stops.count - 1)
      let item = trips[index].stops.remove(at: stop)
      trips[index].stops.insert(item, at: target)
    }
  }

  func restoreSamples() {
    transact { trips in
      trips.removeAll(where: \.isSample)
      trips.append(contentsOf: Samples.journeys)
    }
  }

  private func persist(_ trips: [Journey]) throws {
    guard canWrite else { throw JournalError.unreadable }
    try JSONEncoder().encode(trips).write(to: fileURL, options: [.atomic])
  }

  @discardableResult
  private func transact(_ change: (inout [Journey]) throws -> Void) -> Bool {
    do {
      var next = journeys
      try change(&next)
      try persist(next)
      journeys = next
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }
}

enum Samples {
  static func date(_ day: Int, month: Int = 6) -> Date {
    Calendar(identifier: .gregorian).date(
      from: DateComponents(year: 2026, month: month, day: day, hour: 12)
    ) ?? Date(timeIntervalSince1970: 0)
  }
  static let journeys: [Journey] = [
    Journey(
      title: "Italy, slowly.", region: "LIGURIA · ITALY", style: .coast, isSample: true,
      stops: [
        Memory(
          place: "Manarola", date: date(12),
          note:
            "Salt on our skin, peach juice on our hands. We watched the little boats come home until the whole harbor turned gold.",
          isFavorite: true),
        Memory(
          place: "Vernazza", date: date(13),
          note:
            "A table for two, a paper map, and absolutely nowhere we needed to be. The best kind of afternoon."
        ),
        Memory(
          place: "Monterosso", date: date(15),
          note:
            "One last swim before the train. I tucked the blue ticket into my book to keep a little of this day."
        ),
      ]),
    Journey(
      title: "A quieter Kyoto", region: "KYOTO · JAPAN", style: .city, isSample: true,
      stops: [
        Memory(
          place: "Higashiyama", date: date(3, month: 4),
          note:
            "Before the city woke, the stone streets belonged to us. A bicycle, a soft bell, the smell of tea."
        ),
        Memory(
          place: "Arashiyama", date: date(5, month: 4),
          note: "The bamboo made its own weather. We stood still long enough to hear it.",
          isFavorite: true),
      ]),
    Journey(
      title: "Into the wild", region: "SOUTH COAST · ICELAND", style: .mountains, isSample: true,
      stops: [
        Memory(
          place: "Vík", date: date(18, month: 2),
          note:
            "Black sand and a sky that changed its mind every five minutes. Some places make you feel wonderfully small."
        )
      ]),
  ]
}
