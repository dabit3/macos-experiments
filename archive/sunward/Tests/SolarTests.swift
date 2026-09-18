import XCTest

@testable import Sunward

final class SolarTests: XCTestCase {
  func date(_ year: Int, _ month: Int, _ day: Int, place: Place, hour: Int = 12) -> Date {
    place.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }
  func minute(_ date: Date?, place: Place) -> Int {
    guard let date else { return -9999 }
    let c = place.calendar.dateComponents([.hour, .minute], from: date)
    return c.hour! * 60 + c.minute!
  }
  func testSanFranciscoSummerSolstice() {
    let place = Place.presets[0]
    let day = Solar.day(on: date(2026, 6, 21, place: place), place: place)
    XCTAssertEqual(Double(minute(day.sunrise, place: place)), 5 * 60 + 48, accuracy: 5)
    XCTAssertEqual(Double(minute(day.sunset, place: place)), 20 * 60 + 35, accuracy: 5)
    XCTAssertEqual(day.golden.count, 2)
    XCTAssertNil(day.condition)
    for window in day.golden {
      XCTAssertGreaterThan(window.minutes, 40)
      XCTAssertLessThan(window.minutes, 100)
      let middle = window.start.addingTimeInterval(window.end.timeIntervalSince(window.start) / 2)
      XCTAssertTrue((-4...6).contains(Solar.position(at: middle, place: place).altitude))
    }
  }
  func testLondonWinterSolstice() {
    let place = Place.presets[3]
    let day = Solar.day(on: date(2026, 12, 21, place: place), place: place)
    XCTAssertEqual(Double(minute(day.sunrise, place: place)), 8 * 60 + 4, accuracy: 5)
    XCTAssertEqual(Double(minute(day.sunset, place: place)), 15 * 60 + 54, accuracy: 5)
  }
  func testSouthernHemisphereAndDateLine() {
    let sydney = Place.presets[5]
    let day = Solar.day(on: date(2026, 12, 21, place: sydney), place: sydney)
    XCTAssertEqual(Double(minute(day.sunrise, place: sydney)), 5 * 60 + 41, accuracy: 6)
    XCTAssertEqual(Double(minute(day.sunset, place: sydney)), 20 * 60 + 5, accuracy: 6)
    let tokyo = Place.presets[4]
    let tokyoDay = Solar.day(on: date(2026, 6, 21, place: tokyo), place: tokyo)
    XCTAssertEqual(Double(minute(tokyoDay.sunrise, place: tokyo)), 4 * 60 + 25, accuracy: 6)
    XCTAssertTrue(tokyoDay.sunrise! >= tokyoDay.start)
  }
  func testPolarConditionsAndNoFabricatedEvents() {
    let place = Place.presets[8]
    let summer = Solar.day(on: date(2026, 6, 21, place: place), place: place)
    XCTAssertEqual(summer.condition, "Midnight sun")
    XCTAssertNil(summer.sunrise)
    XCTAssertNil(summer.sunset)
    XCTAssertTrue(summer.golden.isEmpty)
    let winter = Solar.day(on: date(2026, 12, 21, place: place), place: place)
    XCTAssertEqual(winter.condition, "Polar night")
    XCTAssertNil(winter.sunrise)
    XCTAssertNil(winter.sunset)
    XCTAssertTrue(winter.golden.isEmpty)
  }
  func testTromsoGoldenWindowsCanTouchMidnight() {
    let place = Place.presets[7]
    let day = Solar.day(on: date(2026, 6, 21, place: place), place: place)
    XCTAssertEqual(day.condition, "Midnight sun")
    XCTAssertEqual(day.golden.first?.start, day.start)
    XCTAssertEqual(day.golden.last?.end, day.end)
  }
  func testDSTUsesCivilDayNotFixed24Hours() {
    let place = Place.presets[1]
    let spring = Solar.day(on: date(2026, 3, 8, place: place), place: place)
    let fall = Solar.day(on: date(2026, 11, 1, place: place), place: place)
    XCTAssertEqual(spring.duration, 23 * 3600)
    XCTAssertEqual(fall.duration, 25 * 3600)
    XCTAssertEqual(spring.samples.last?.date, spring.end)
    XCTAssertEqual(fall.samples.last?.date, fall.end)
  }
  func testCoordinateBoundsAndFinitePoles() {
    XCTAssertTrue(Place.valid(latitude: -90, longitude: 180))
    XCTAssertTrue(Place.valid(latitude: 90, longitude: -180))
    XCTAssertFalse(Place.valid(latitude: 90.001, longitude: 0))
    XCTAssertFalse(Place.valid(latitude: 0, longitude: -181))
    XCTAssertFalse(Place.valid(latitude: .nan, longitude: 0))
    XCTAssertFalse(Place.valid(latitude: 0, longitude: .infinity))
    for lat in [-90.0, 0, 90] {
      let place = Place(name: "Pole", latitude: lat, longitude: 0, zoneID: "Etc/UTC")
      let position = Solar.position(at: date(2026, 3, 20, place: place), place: place)
      XCTAssertTrue(position.altitude.isFinite)
      XCTAssertTrue(position.azimuth.isFinite)
      XCTAssertTrue((0..<360).contains(position.azimuth))
    }
  }
  @MainActor
  func testPersistenceEditingDeletionAndLocationDateRetention() throws {
    let suite = "sunward.tests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let planner = Planner(defaults: defaults)
    planner.date = date(2026, 6, 21, place: planner.place, hour: 18)
    planner.refresh()
    planner.select(Place.presets[4])
    XCTAssertEqual(planner.place.calendar.component(.day, from: planner.date), 21)
    XCTAssertEqual(planner.place.calendar.component(.hour, from: planner.date), 18)
    planner.save(title: " Rooftop ", notes: "85 mm")
    let restored = Planner(defaults: defaults)
    XCTAssertEqual(restored.shoots.first?.title, "Rooftop")
    XCTAssertEqual(restored.place, planner.place)
    XCTAssertEqual(restored.date, planner.date)
    var shoot = try XCTUnwrap(restored.shoots.first)
    shoot.title = "Harbour"
    restored.update(shoot)
    XCTAssertEqual(Planner(defaults: defaults).shoots.first?.title, "Harbour")
    restored.delete(shoot.id)
    XCTAssertTrue(Planner(defaults: defaults).shoots.isEmpty)
  }
}
