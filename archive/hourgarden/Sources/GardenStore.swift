import Foundation
import SwiftUI

struct Ritual: Codable, Identifiable, Equatable {
  var id = UUID()
  var intention: String
  var duration: TimeInterval
  var isPreview: Bool
  var species: Int
  var startedAt: Date
  var deadline: Date?
  var pausedRemaining: TimeInterval?

  func remaining(at date: Date) -> TimeInterval {
    max(0, min(duration, pausedRemaining ?? deadline?.timeIntervalSince(date) ?? 0))
  }

  var isPaused: Bool { pausedRemaining != nil }
}

struct Specimen: Codable, Identifiable, Equatable {
  var id: UUID
  var intention: String
  var duration: TimeInterval
  var isPreview: Bool
  var species: Int
  var startedAt: Date
  var completedAt: Date
  var note = ""
}

struct GardenData: Codable {
  var active: Ritual?
  var specimens: [Specimen] = []
  var pendingCelebration: UUID?
  var preferredMinutes = 25
  var dailyGoal = 60
  var intention = "Make something"
}

@MainActor
final class GardenStore: ObservableObject {
  @Published private(set) var data: GardenData
  @Published var storageMessage: String?
  private let defaults: UserDefaults
  private let key: String

  init(defaults: UserDefaults = .standard, key: String = "hourgarden.v1") {
    self.defaults = defaults
    self.key = key
    if let saved = defaults.data(forKey: key) {
      do {
        data = try JSONDecoder().decode(GardenData.self, from: saved)
      } catch {
        data = GardenData()
        storageMessage =
          "Your saved garden couldn’t be read. Please restart before beginning a new ritual."
      }
    } else {
      data = GardenData()
    }
  }

  var celebration: Specimen? {
    data.specimens.first { $0.id == data.pendingCelebration }
  }

  func save() {
    do {
      defaults.set(try JSONEncoder().encode(data), forKey: key)
    } catch {
      storageMessage = "Your garden couldn’t be saved. Please try again."
    }
  }

  @discardableResult
  func start(intention: String, minutes: Int, preview: Bool, at date: Date = Date()) -> Bool {
    guard data.active == nil, (1...90).contains(minutes), storageMessage == nil else {
      return false
    }
    let duration: TimeInterval = preview ? 20 : Double(minutes * 60)
    let clean = String(intention.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
    let tag = clean.isEmpty ? "A little space" : clean
    data.preferredMinutes = minutes
    data.intention = tag
    data.active = Ritual(
      intention: tag, duration: duration, isPreview: preview,
      species: data.specimens.count % 3, startedAt: date,
      deadline: date.addingTimeInterval(duration))
    save()
    return true
  }

  func synchronize(at date: Date = Date()) {
    guard let ritual = data.active, !ritual.isPaused, ritual.remaining(at: date) <= 0 else {
      return
    }
    if !data.specimens.contains(where: { $0.id == ritual.id }) {
      data.specimens.insert(
        Specimen(
          id: ritual.id, intention: ritual.intention, duration: ritual.duration,
          isPreview: ritual.isPreview, species: ritual.species,
          startedAt: ritual.startedAt, completedAt: ritual.deadline ?? date),
        at: 0)
    }
    data.pendingCelebration = ritual.id
    data.active = nil
    save()
  }

  func pause(at date: Date = Date()) {
    synchronize(at: date)
    guard var ritual = data.active, !ritual.isPaused else { return }
    ritual.pausedRemaining = ritual.remaining(at: date)
    ritual.deadline = nil
    data.active = ritual
    save()
  }

  func resume(at date: Date = Date()) {
    guard var ritual = data.active, let remaining = ritual.pausedRemaining else { return }
    ritual.deadline = date.addingTimeInterval(remaining)
    ritual.pausedRemaining = nil
    data.active = ritual
    save()
  }

  func cancel(at date: Date = Date()) {
    synchronize(at: date)
    data.active = nil
    save()
  }

  func dismissCelebration() {
    data.pendingCelebration = nil
    save()
  }

  func edit(_ specimen: Specimen, intention: String, note: String) {
    guard let index = data.specimens.firstIndex(where: { $0.id == specimen.id }) else { return }
    let tag = intention.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !tag.isEmpty else { return }
    data.specimens[index].intention = String(tag.prefix(60))
    data.specimens[index].note = String(note.prefix(500))
    save()
  }

  func delete(_ id: UUID) {
    data.specimens.removeAll { $0.id == id }
    if data.pendingCelebration == id { data.pendingCelebration = nil }
    save()
  }

  func setGoal(_ minutes: Int) {
    data.dailyGoal = min(240, max(15, minutes))
    save()
  }

  func reset() {
    data = GardenData()
    storageMessage = nil
    save()
  }

  func focusedSeconds(on date: Date, calendar: Calendar = .current) -> TimeInterval {
    data.specimens.filter { !$0.isPreview && calendar.isDate($0.completedAt, inSameDayAs: date) }
      .reduce(0) { $0 + $1.duration }
  }

  func sessions(on date: Date, calendar: Calendar = .current) -> [Specimen] {
    data.specimens.filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
  }
}

enum Botany {
  static let names = ["Olive", "Eucalyptus", "Wild cosmos"]
  static let latin = ["Olea europaea", "Eucalyptus cinerea", "Cosmos bipinnatus"]
  static let meanings = [
    "A little peace, cultivated.", "Room for a clearer mind.", "Good things take their time.",
  ]
}
