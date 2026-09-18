import XCTest

@testable import Sprout

final class SproutTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return calendar
  }
  private func date(_ month: Int, _ day: Int, year: Int = 2026, hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }
  private func plant(start: Date, interval: Int = 7) -> Plant {
    Plant(name: "Test plant", kind: .monstera, room: "Studio", interval: interval, startedAt: start)
  }
  func testDueDateUsesCalendarDaysAcrossSpringDST() {
    let plant = plant(start: date(3, 7), interval: 2)
    XCTAssertEqual(plant.dueDate(calendar: calendar), date(3, 9, hour: 0))
    XCTAssertEqual(plant.daysUntilDue(now: date(3, 9, hour: 23), calendar: calendar), 0)
    XCTAssertEqual(plant.daysUntilDue(now: date(3, 10), calendar: calendar), -1)
  }
  func testLatestHistoryWinsAndIntervalChangesRecompute() {
    var plant = plant(start: date(1, 1))
    plant.history = [Watering(date: date(1, 12)), Watering(date: date(1, 9))]
    XCTAssertEqual(plant.dueDate(calendar: calendar), date(1, 19, hour: 0))
    plant.interval = 3
    XCTAssertEqual(plant.dueDate(calendar: calendar), date(1, 15, hour: 0))
    plant.history.removeFirst()
    XCTAssertEqual(plant.dueDate(calendar: calendar), date(1, 12, hour: 0))
  }
  func testYearBoundaryAndFallDST() {
    XCTAssertEqual(
      plant(start: date(12, 30), interval: 5).dueDate(calendar: calendar),
      date(1, 4, year: 2027, hour: 0)
    )
    XCTAssertEqual(
      plant(start: date(10, 31), interval: 2).dueDate(calendar: calendar), date(11, 2, hour: 0))
  }
  @MainActor
  func testPersistenceWateringEditingUndoAndDeletion() throws {
    let dir = URL.applicationSupportDirectory.appending(path: "SproutTests-\(UUID())")
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appending(path: "plants.json")
    let store = PlantStore(fileURL: url, now: date(4, 10))
    store.removeSamples()
    var plant = plant(start: date(4, 1))
    plant.notes = "A new leaf"
    plant.photo = Data([1, 2, 3])
    store.save(plant)
    let logID = try XCTUnwrap(store.water(plant.id, now: date(4, 10)))
    XCTAssertNil(store.water(plant.id, now: date(4, 10, hour: 18)))
    store.updateWatering(plantID: plant.id, logID: logID, date: date(4, 8), now: date(4, 10))
    store.updateWatering(plantID: plant.id, logID: logID, date: date(4, 11), now: date(4, 10))
    let loaded = PlantStore(fileURL: url)
    XCTAssertEqual(loaded.plants.count, 1)
    XCTAssertEqual(loaded.plants[0].lastWatered, date(4, 8))
    XCTAssertEqual(loaded.plants[0].notes, "A new leaf")
    XCTAssertEqual(loaded.plants[0].photo, Data([1, 2, 3]))
    loaded.removeWatering(plantID: plant.id, logID: logID)
    XCTAssertEqual(loaded.plants[0].lastWatered, date(4, 1))
    loaded.delete(plant.id)
    XCTAssertTrue(PlantStore(fileURL: url).plants.isEmpty)
  }
  @MainActor
  func testSamplesAreExplicitAndRemovalPreservesPersonalPlants() {
    let dir = URL.applicationSupportDirectory.appending(path: "SproutTests-\(UUID())")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = PlantStore(fileURL: dir.appending(path: "plants.json"), now: date(4, 10))
    XCTAssertEqual(store.plants.filter(\.isSample).count, 4)
    let own = plant(start: date(4, 10))
    store.save(own)
    store.removeSamples()
    XCTAssertEqual(store.plants.map(\.id), [own.id])
  }
  @MainActor
  func testUnreadableShelfIsNeverOverwritten() throws {
    let dir = URL.applicationSupportDirectory.appending(path: "SproutTests-\(UUID())")
    defer { try? FileManager.default.removeItem(at: dir) }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appending(path: "plants.json")
    let original = Data("unreadable shelf".utf8)
    try original.write(to: url)
    let store = PlantStore(fileURL: url)
    XCTAssertNotNil(store.errorMessage)
    XCTAssertFalse(store.save(plant(start: date(4, 10))))
    store.removeSamples()
    XCTAssertTrue(store.plants.isEmpty)
    XCTAssertEqual(try Data(contentsOf: url), original)
  }

  @MainActor
  func testInvalidIntervalsAndBlankNamesAreRejected() {
    let dir = URL.applicationSupportDirectory.appending(path: "SproutTests-\(UUID())")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = PlantStore(fileURL: dir.appending(path: "plants.json"))
    store.removeSamples()
    store.save(plant(start: date(4, 10), interval: 0))
    store.save(plant(start: date(4, 10), interval: 91))
    var blank = plant(start: date(4, 10))
    blank.name = " \n "
    store.save(blank)
    XCTAssertTrue(store.plants.isEmpty)
    blank.name = "  Moss  "
    blank.room = " "
    store.save(blank)
    XCTAssertEqual(store.plants.first?.name, "Moss")
    XCTAssertEqual(store.plants.first?.room, "My room")
  }
}
