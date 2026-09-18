import Foundation
import SwiftUI

enum PlantKind: String, Codable, CaseIterable, Identifiable {
  case monstera = "Monstera"
  case rubber = "Rubber plant"
  case snake = "Snake plant"
  case fern = "Fern"

  var id: String { rawValue }
  var scientific: String {
    switch self {
    case .monstera: "Monstera deliciosa"
    case .rubber: "Ficus elastica"
    case .snake: "Dracaena trifasciata"
    case .fern: "Nephrolepis exaltata"
    }
  }
  var light: String {
    switch self {
    case .monstera, .rubber: "Bright, indirect light"
    case .snake: "Indirect light; tolerates shade"
    case .fern: "Gentle, filtered light"
    }
  }
  var water: String {
    switch self {
    case .monstera:
      "Feel the top 2–5 cm of soil. Water only when that layer is dry. Let excess water drain away."
    case .rubber:
      "Allow the upper few centimetres of soil to dry between waterings. Empty the saucer after watering."
    case .snake:
      "Let the soil dry thoroughly before watering. A dry plant is usually safer than one sitting in wet soil."
    case .fern:
      "Check the soil often. Keep it lightly moist, never soggy, and use a pot that drains freely."
    }
  }
  var note: String {
    switch self {
    case .monstera:
      "Give climbing stems a support. Rotate occasionally for even growth. Keep out of reach of pets and children."
    case .rubber:
      "Wipe broad leaves with a damp cloth. Avoid cold drafts. Its sap may irritate skin; keep away from pets and children."
    case .snake:
      "A well-draining mix matters more than a strict schedule. Keep out of reach of pets and children."
    case .fern:
      "Avoid hot radiators and very dry air. Confirm the species before assuming a fern is safe around pets."
    }
  }
}

struct Watering: Codable, Identifiable, Equatable {
  var id = UUID()
  var date: Date
}

struct Plant: Codable, Identifiable, Equatable {
  var id = UUID()
  var name: String
  var kind: PlantKind
  var room: String
  var interval: Int
  var startedAt: Date
  var history: [Watering] = []
  var notes = ""
  var photo: Data?
  var isSample = false

  var lastWatered: Date { history.map(\.date).max() ?? startedAt }

  func dueDate(calendar: Calendar = .current) -> Date {
    calendar.date(byAdding: .day, value: interval, to: calendar.startOfDay(for: lastWatered))!
  }

  func daysUntilDue(now: Date = .now, calendar: Calendar = .current) -> Int {
    calendar.dateComponents(
      [.day], from: calendar.startOfDay(for: now), to: dueDate(calendar: calendar)
    ).day ?? 0
  }

  func status(now: Date = .now) -> String {
    let days = daysUntilDue(now: now)
    if days < 0 { return "\(abs(days))d overdue" }
    if days == 0 { return "Check today" }
    return "In \(days) \(days == 1 ? "day" : "days")"
  }

  func wateredToday(now: Date = .now, calendar: Calendar = .current) -> Bool {
    history.contains { calendar.isDate($0.date, inSameDayAs: now) }
  }
}

@MainActor
final class PlantStore: ObservableObject {
  @Published private(set) var plants: [Plant] = []
  @Published var errorMessage: String?
  private let fileURL: URL
  private var canWrite = true

  init(fileURL: URL? = nil, now: Date = .now) {
    self.fileURL =
      fileURL
      ?? URL.applicationSupportDirectory
      .appending(path: "Sprout", directoryHint: .isDirectory)
      .appending(path: "plants.json")
    if FileManager.default.fileExists(atPath: self.fileURL.path) {
      do {
        plants = try JSONDecoder().decode([Plant].self, from: Data(contentsOf: self.fileURL))
      } catch {
        canWrite = false
        errorMessage =
          "Your shelf couldn’t be read. Your saved file has been kept safe. Please close and reopen Sprout."
      }
    } else {
      plants = Self.starters(now: now)
      persist()
    }
  }

  var rooms: [String] { Array(Set(plants.map(\.room))).sorted() }
  var due: [Plant] {
    plants.filter { $0.daysUntilDue() <= 0 }.sorted { $0.dueDate() < $1.dueDate() }
  }
  var upcoming: [Plant] {
    plants.filter { $0.daysUntilDue() > 0 }.sorted { $0.dueDate() < $1.dueDate() }
  }

  @discardableResult
  func save(_ plant: Plant) -> Bool {
    guard canWrite else {
      errorMessage =
        "Your saved shelf is unreadable and has been kept safe. Changes cannot be saved."
      return false
    }
    guard (1...90).contains(plant.interval),
      !plant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return false }
    var updated = plant
    updated.name = String(plant.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
    updated.room = String(plant.room.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
    if updated.room.isEmpty { updated.room = "My room" }
    if let index = plants.firstIndex(where: { $0.id == plant.id }) {
      plants[index] = updated
    } else {
      plants.append(updated)
    }
    return persist()
  }

  @discardableResult
  func water(_ id: UUID, now: Date = .now) -> UUID? {
    guard let index = plants.firstIndex(where: { $0.id == id }),
      !plants[index].wateredToday(now: now)
    else { return nil }
    let log = Watering(date: now)
    plants[index].history.append(log)
    persist()
    return log.id
  }

  func updateWatering(plantID: UUID, logID: UUID, date: Date, now: Date = .now) {
    guard date <= now, let index = plants.firstIndex(where: { $0.id == plantID }),
      let logIndex = plants[index].history.firstIndex(where: { $0.id == logID })
    else { return }
    plants[index].history[logIndex].date = date
    persist()
  }

  func removeWatering(plantID: UUID, logID: UUID) {
    guard let index = plants.firstIndex(where: { $0.id == plantID }) else { return }
    plants[index].history.removeAll { $0.id == logID }
    persist()
  }

  func delete(_ id: UUID) {
    plants.removeAll { $0.id == id }
    persist()
  }

  func removeSamples() {
    plants.removeAll(where: \.isSample)
    persist()
  }

  @discardableResult
  private func persist() -> Bool {
    guard canWrite else { return false }
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(plants).write(to: fileURL, options: .atomic)
      return true
    } catch {
      errorMessage =
        "Your changes couldn’t be saved. Please check available storage before closing Sprout."
      return false
    }
  }

  static func starters(now: Date) -> [Plant] {
    let calendar = Calendar.current
    return [
      Plant(
        name: "Sunday", kind: .monstera, room: "Living room", interval: 7,
        startedAt: calendar.date(byAdding: .day, value: -8, to: now)!,
        notes: "A little inspiration for your own shelf. This is a sample plant.", isSample: true),
      Plant(
        name: "Olive", kind: .rubber, room: "Living room", interval: 10,
        startedAt: calendar.date(byAdding: .day, value: -10, to: now)!,
        notes: "A sample plant. The bright corner by the window is its happy place.", isSample: true
      ),
      Plant(
        name: "Cleo", kind: .snake, room: "Bedroom", interval: 21,
        startedAt: calendar.date(byAdding: .day, value: -9, to: now)!, isSample: true),
      Plant(
        name: "Frida", kind: .fern, room: "Bathroom", interval: 5,
        startedAt: calendar.date(byAdding: .day, value: -2, to: now)!, isSample: true),
    ]
  }
}
