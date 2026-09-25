import Foundation
import Testing

@testable import VerdantCore

private let now = Date(timeIntervalSince1970: 1_789_084_800)

@Test func sampleHasSixDistinctSpecimensAndTwoDuePlants() {
  let garden = Garden.sample(now: now)
  #expect(Set(garden.plants.map(\.specimen)).count == 6)
  #expect(garden.plants.filter { $0.daysUntilDue(at: now) <= 0 }.count == 2)
  #expect(garden.plants.allSatisfy { !$0.specimen.advice.isEmpty })
}

@Test func wateringUndoRestoresExactDueStateAndTimeline() throws {
  var garden = Garden.sample(now: now)
  let before = garden
  let plant = try #require(garden.plants.first)
  #expect(plant.daysUntilDue(at: now) == -1)
  try garden.water(plant.id, at: now)
  #expect(garden.plants[0].daysUntilDue(at: now) == plant.interval)
  #expect(garden.entries.count == before.entries.count + 1)
  #expect(throws: GardenError.self) { try garden.water(plant.id, at: now) }
  garden.undoLastChange()
  #expect(garden == before)
  try garden.water(plant.id, at: now)
  #expect(garden.entries.last?.kind == .watering)
}

@Test func editIntervalRecalculatesDueDateWithoutInventingWatering() throws {
  var garden = Garden.sample(now: now)
  var plant = garden.plants[1]
  let lastWatered = plant.lastWatered
  plant.interval = 2
  plant.light = .gentle
  plant.location = "East window"
  try garden.edit(plant, at: now)
  #expect(garden.plants[1].lastWatered == lastWatered)
  #expect(garden.plants[1].daysUntilDue(at: now) == -2)
  #expect(garden.entries.last?.kind == .schedule)
}

@Test func blankNotesAndInvalidPlantsAreRejectedWithoutMutation() throws {
  var garden = Garden.sample(now: now)
  let before = garden
  #expect(throws: GardenError.self) { try garden.note(" \n ", for: garden.plants[0].id, at: now) }
  #expect(garden == before)
  #expect(throws: GardenError.self) {
    try garden.note(String(repeating: "x", count: 1001), for: garden.plants[0].id, at: now)
  }
  var plant = garden.plants[0]
  plant.interval = 0
  #expect(throws: GardenError.self) { try garden.edit(plant, at: now) }
  #expect(garden == before)
  #expect(throws: GardenError.self) { try garden.water(UUID(), at: now) }
}

@Test func fullDemoPersistsAndExportsIncludingUndo() throws {
  let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: folder) }
  let url = folder.appending(path: "garden.json")
  var garden = Garden.sample(now: now)
  let newPlant = Plant(
    specimen: .pothos, nickname: "Golden hour", location: "East window",
    light: .bright, interval: 7, lastWatered: now, added: now
  )
  try garden.add(newPlant, at: now)
  try garden.note("A new leaf unfurled 🌿", for: newPlant.id, at: now)
  try garden.save(to: url)
  var restored = try Garden.load(from: url)
  #expect(restored == garden)
  #expect(restored.markdown().contains("Golden hour"))
  #expect(restored.markdown().contains("A new leaf unfurled 🌿"))
  restored.undoLastChange()
  #expect(!restored.entries.contains { $0.text == "A new leaf unfurled 🌿" })
  #expect(restored.plants.contains { $0.id == newPlant.id })
}

@Test func daylightSavingUsesCalendarDaysRatherThan24HourDurations() throws {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
  let watered = try #require(
    calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23)))
  let next = try #require(
    calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1)))
  let plant = Plant(
    specimen: .calathea, nickname: "Prayer plant", location: "Studio",
    light: .gentle, interval: 1, lastWatered: watered, added: watered
  )
  #expect(plant.daysUntilDue(at: next, calendar: calendar) == 0)
  #expect(calendar.component(.hour, from: plant.dueDate(calendar: calendar)) == 0)
}

@Test func corruptFileDoesNotGetOverwrittenByLoad() throws {
  let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: folder) }
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let url = folder.appending(path: "garden.json")
  let invalid = Data("not a garden".utf8)
  try invalid.write(to: url)
  #expect(throws: (any Error).self) { try Garden.load(from: url) }
  #expect(try Data(contentsOf: url) == invalid)
}
