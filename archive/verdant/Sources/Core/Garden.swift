import Foundation

public enum Specimen: String, CaseIterable, Codable, Identifiable, Sendable {
  case monstera, fiddle, snake, calathea, pothos, rubber

  public var id: String { rawValue }
  public var name: String {
    switch self {
    case .monstera: "Monstera"
    case .fiddle: "Fiddle-leaf fig"
    case .snake: "Snake plant"
    case .calathea: "Prayer plant"
    case .pothos: "Golden pothos"
    case .rubber: "Rubber plant"
    }
  }
  public var latin: String {
    switch self {
    case .monstera: "Monstera deliciosa"
    case .fiddle: "Ficus lyrata"
    case .snake: "Dracaena trifasciata"
    case .calathea: "Goeppertia orbifolia"
    case .pothos: "Epipremnum aureum"
    case .rubber: "Ficus elastica"
    }
  }
  public var interval: Int {
    switch self {
    case .monstera, .pothos: 7
    case .fiddle, .rubber: 10
    case .snake: 21
    case .calathea: 5
    }
  }
  public var advice: String {
    switch self {
    case .monstera:
      "Let the top 2–3 inches of soil dry. Rotate gently toward the light for balanced growth."
    case .fiddle:
      "Keep in a steady, bright spot. Water when the top 2 inches feel dry; avoid cold drafts."
    case .snake: "Let soil dry completely between waterings. Less is more, especially in winter."
    case .calathea:
      "Keep soil lightly moist, never soggy. Filtered water and gentle humidity suit these leaves."
    case .pothos:
      "Let the top inch dry. Trim long vines just above a node to encourage fuller growth."
    case .rubber: "Let the top 2 inches dry. Wipe the glossy leaves with a soft damp cloth."
    }
  }
  public var light: Light { self == .snake ? .low : (self == .calathea ? .gentle : .bright) }
}

public enum Light: String, CaseIterable, Codable, Sendable {
  case bright = "Bright indirect"
  case gentle = "Gentle filtered"
  case low = "Low light"
}

public struct Plant: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var specimen: Specimen
  public var nickname: String
  public var location: String
  public var light: Light
  public var interval: Int
  public var lastWatered: Date
  public var added: Date

  public init(
    id: UUID = UUID(), specimen: Specimen, nickname: String, location: String,
    light: Light, interval: Int, lastWatered: Date, added: Date
  ) {
    self.id = id
    self.specimen = specimen
    self.nickname = nickname
    self.location = location
    self.light = light
    self.interval = interval
    self.lastWatered = lastWatered
    self.added = added
  }

  public func dueDate(calendar: Calendar = .current) -> Date {
    calendar.date(byAdding: .day, value: interval, to: calendar.startOfDay(for: lastWatered))
      ?? lastWatered
  }
  public func daysUntilDue(at date: Date, calendar: Calendar = .current) -> Int {
    calendar.dateComponents(
      [.day], from: calendar.startOfDay(for: date), to: dueDate(calendar: calendar)
    ).day ?? 0
  }
  public func careLabel(at date: Date) -> String {
    let days = daysUntilDue(at: date)
    if days < 0 { return "\(abs(days))d overdue" }
    if days == 0 { return "Water today" }
    return "In \(days) days"
  }
}

public enum EntryKind: String, Codable, Sendable { case watering, note, added, schedule }

public struct Entry: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID = UUID()
  public var plantID: UUID
  public var kind: EntryKind
  public var date: Date
  public var text: String
}

public struct GardenSnapshot: Codable, Equatable, Sendable {
  public var plants: [Plant]
  public var entries: [Entry]
  public var label: String
}

public enum GardenError: LocalizedError {
  case invalidInput, missingPlant, alreadyWatered, invalidFile
  public var errorDescription: String? {
    switch self {
    case .invalidInput: "Use a name and location of 1–40 characters and an interval of 1–60 days."
    case .missingPlant: "This plant is no longer in your collection."
    case .alreadyWatered: "Watering is already logged for today."
    case .invalidFile: "The saved garden could not be read. Your existing file has been preserved."
    }
  }
}

public struct Garden: Codable, Equatable, Sendable {
  public var version = 1
  public var plants: [Plant]
  public var entries: [Entry]
  public var undo: GardenSnapshot?

  public static func sample(now: Date = Date(), calendar: Calendar = .current) -> Garden {
    let locations = ["Living room", "Reading nook", "Bedroom", "Studio", "Kitchen", "Sunroom"]
    let elapsed = [8, 4, 12, 5, 2, 3]
    let plants = Specimen.allCases.enumerated().map { index, specimen in
      Plant(
        specimen: specimen, nickname: specimen.name, location: locations[index],
        light: specimen.light, interval: specimen.interval,
        lastWatered: calendar.date(byAdding: .day, value: -elapsed[index], to: now) ?? now,
        added: calendar.date(byAdding: .day, value: -30, to: now) ?? now
      )
    }
    var entries = plants.map {
      Entry(plantID: $0.id, kind: .watering, date: $0.lastWatered, text: "A slow, thorough drink.")
    }
    entries.append(
      Entry(
        plantID: plants[0].id, kind: .note,
        date: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
        text: "A new leaf is unfurling. Moved a little closer to the morning light."
      )
    )
    return Garden(plants: plants, entries: entries)
  }

  private mutating func checkpoint(_ label: String) {
    undo = GardenSnapshot(plants: plants, entries: entries, label: label)
  }

  public mutating func add(_ plant: Plant, at now: Date) throws {
    try Self.validate(plant)
    guard !plants.contains(where: { $0.id == plant.id }) else { throw GardenError.invalidInput }
    checkpoint("Plant added")
    plants.append(plant)
    entries.append(
      Entry(plantID: plant.id, kind: .added, date: now, text: "Welcome to the garden."))
  }

  public mutating func edit(_ plant: Plant, at now: Date) throws {
    try Self.validate(plant)
    guard let index = plants.firstIndex(where: { $0.id == plant.id }) else {
      throw GardenError.missingPlant
    }
    checkpoint("Care plan updated")
    plants[index] = plant
    entries.append(
      Entry(
        plantID: plant.id, kind: .schedule, date: now,
        text: "\(plant.location) · \(plant.light.rawValue) · every \(plant.interval) days"
      )
    )
  }

  public mutating func water(_ id: UUID, at now: Date, calendar: Calendar = .current) throws {
    guard let index = plants.firstIndex(where: { $0.id == id }) else {
      throw GardenError.missingPlant
    }
    guard !calendar.isDate(plants[index].lastWatered, inSameDayAs: now) else {
      throw GardenError.alreadyWatered
    }
    checkpoint("Watering saved")
    plants[index].lastWatered = now
    entries.append(Entry(plantID: id, kind: .watering, date: now, text: "Watered with care."))
  }

  public mutating func note(_ text: String, for id: UUID, at now: Date) throws {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= 1000 else { throw GardenError.invalidInput }
    guard plants.contains(where: { $0.id == id }) else { throw GardenError.missingPlant }
    checkpoint("Note saved")
    entries.append(Entry(plantID: id, kind: .note, date: now, text: trimmed))
  }

  public mutating func undoLastChange() {
    guard let snapshot = undo else { return }
    plants = snapshot.plants
    entries = snapshot.entries
    undo = nil
  }

  public func sortedEntries(for id: UUID? = nil) -> [Entry] {
    entries.filter { id == nil || $0.plantID == id }.sorted { $0.date > $1.date }
  }

  private static func validate(_ plant: Plant) throws {
    guard (1...60).contains(plant.interval),
      (1...40).contains(plant.nickname.trimmingCharacters(in: .whitespacesAndNewlines).count),
      (1...40).contains(plant.location.trimmingCharacters(in: .whitespacesAndNewlines).count)
    else { throw GardenError.invalidInput }
  }

  public static func load(from url: URL) throws -> Garden {
    let garden = try JSONDecoder().decode(Garden.self, from: Data(contentsOf: url))
    guard garden.version == 1, Set(garden.plants.map(\.id)).count == garden.plants.count else {
      throw GardenError.invalidFile
    }
    for plant in garden.plants { try validate(plant) }
    guard garden.entries.allSatisfy({ entry in garden.plants.contains { $0.id == entry.plantID } })
    else { throw GardenError.invalidFile }
    return garden
  }

  public func save(to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(self).write(to: url, options: .atomic)
  }

  public func markdown() -> String {
    var lines = ["# Verdant · Garden journal", "", "A little care. A lot of growth.", ""]
    for plant in plants {
      lines += [
        "## \(plant.nickname)", "*\(plant.specimen.latin)*", "",
        "\(plant.location) · \(plant.light.rawValue) · Water every \(plant.interval) days", "",
      ]
      for entry in sortedEntries(for: plant.id) {
        lines.append(
          "- \(entry.date.formatted(date: .abbreviated, time: .shortened)) · \(entry.kind.rawValue): \(entry.text)"
        )
      }
      lines.append("")
    }
    return lines.joined(separator: "\n")
  }
}
