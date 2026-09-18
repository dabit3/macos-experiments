import UIKit
import XCTest

@testable import Elsewhere

@MainActor
final class JournalTests: XCTestCase {
  private func folder() -> URL {
    URL.documentsDirectory.appending(
      path: "ElsewhereTests-\(UUID().uuidString)", directoryHint: .isDirectory)
  }

  func testTripAndStopCRUDPersistsAcrossReloads() throws {
    let directory = folder()
    defer { try? FileManager.default.removeItem(at: directory) }
    let journal = Journal(directory: directory, seed: false)
    var trip = Journey(title: "  Portugal  ", region: " Lisbon ", style: .city)
    XCTAssertTrue(journal.save(trip))
    XCTAssertEqual(journal.journeys.first?.title, "Portugal")
    var memory = Memory(place: "Tram 28", date: Samples.date(1), note: "Yellow and lovely")
    XCTAssertTrue(journal.saveMemory(memory, in: trip.id))
    memory.note = "An edited afternoon"
    XCTAssertTrue(journal.saveMemory(memory, in: trip.id))
    journal.toggleFavorite(memory.id, in: trip.id)
    let loaded = Journal(directory: directory)
    XCTAssertEqual(loaded.journey(trip.id)?.stops.count, 1)
    XCTAssertEqual(loaded.favorites.first?.memory.note, "An edited afternoon")
    trip = try XCTUnwrap(loaded.journey(trip.id))
    trip.title = "Lisbon, again"
    XCTAssertTrue(loaded.save(trip))
    XCTAssertTrue(loaded.deleteMemory(memory.id, in: trip.id))
    XCTAssertTrue(loaded.favorites.isEmpty)
    XCTAssertTrue(loaded.deleteJourney(trip.id))
    XCTAssertTrue(Journal(directory: directory).journeys.isEmpty)
  }

  func testOrderingClampsAndPersistsWithoutChangingDates() throws {
    let directory = folder()
    defer { try? FileManager.default.removeItem(at: directory) }
    let journal = Journal(directory: directory, seed: false)
    let stops = (1...3).map { Memory(place: "Stop \($0)", date: Samples.date($0), note: "") }
    let trip = Journey(title: "Road trip", region: "", style: .mountains, stops: stops)
    XCTAssertTrue(journal.save(trip))
    journal.moveMemory(stops[2].id, in: trip.id, by: -1)
    XCTAssertEqual(
      journal.journey(trip.id)?.stops.map(\.id), [stops[0].id, stops[2].id, stops[1].id])
    journal.moveMemory(stops[2].id, in: trip.id, by: -999)
    journal.moveMemory(stops[1].id, in: trip.id, by: 999)
    let loaded = Journal(directory: directory)
    XCTAssertEqual(
      loaded.journey(trip.id)?.stops.map(\.id), [stops[2].id, stops[0].id, stops[1].id])
    XCTAssertEqual(loaded.journey(trip.id)?.stops.first?.date, stops[2].date)
  }

  func testInvalidNamesAndMissingParentsDoNotMutateData() {
    let directory = folder()
    defer { try? FileManager.default.removeItem(at: directory) }
    let journal = Journal(directory: directory, seed: false)
    XCTAssertFalse(journal.save(Journey(title: " \n ", region: "", style: .coast)))
    let trip = Journey(title: "Valid", region: "", style: .coast)
    XCTAssertTrue(journal.save(trip))
    XCTAssertFalse(journal.saveMemory(Memory(place: " ", date: Date(), note: ""), in: trip.id))
    XCTAssertFalse(journal.saveMemory(Memory(place: "Valid", date: Date(), note: ""), in: UUID()))
    XCTAssertEqual(journal.journeys.count, 1)
    XCTAssertTrue(journal.journey(trip.id)?.stops.isEmpty == true)
  }

  func testRestoringSamplesPreservesPersonalJournal() {
    let directory = folder()
    defer { try? FileManager.default.removeItem(at: directory) }
    let journal = Journal(directory: directory)
    let personal = Journey(title: "My journey", region: "", style: .coast)
    journal.save(personal)
    journal.deleteJourney(journal.journeys.last!.id)
    journal.restoreSamples()
    journal.restoreSamples()
    XCTAssertEqual(journal.journeys.count, 4)
    XCTAssertNotNil(journal.journey(personal.id))
    XCTAssertEqual(journal.journeys.filter(\.isSample).count, 3)
  }

  func testCorruptedFileIsNeverOverwritten() throws {
    let directory = folder()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "journal.json")
    let original = Data("unreadable journal".utf8)
    try original.write(to: url)
    let journal = Journal(directory: directory)
    XCTAssertNotNil(journal.errorMessage)
    XCTAssertFalse(journal.save(Journey(title: "New", region: "", style: .city)))
    XCTAssertEqual(try Data(contentsOf: url), original)
  }

  func testPhotoDataRoundTripsWithMemory() {
    let directory = folder()
    defer { try? FileManager.default.removeItem(at: directory) }
    let journal = Journal(directory: directory, seed: false)
    let memory = Memory(place: "Photo", date: Samples.date(1), note: "", photo: Data([1, 2, 3]))
    let trip = Journey(title: "Photos", region: "", style: .coast, stops: [memory])
    journal.save(trip)
    XCTAssertEqual(
      Journal(directory: directory).journey(trip.id)?.stops.first?.photo, Data([1, 2, 3]))
  }

  func testPostcardRendersRealImageAtExportResolution() throws {
    let trip = try XCTUnwrap(Samples.journeys.first)
    let memory = try XCTUnwrap(trip.stops.first)
    let image = try XCTUnwrap(PostcardExporter.render(journey: trip, memory: memory))
    XCTAssertEqual(image.cgImage?.width, 1200)
    XCTAssertEqual(image.cgImage?.height, 1760)
    XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 10_000)
  }

  func testShareFilesContainPNGAndKeepExportsIsolated() throws {
    let directory = folder()
    defer { try? FileManager.default.removeItem(at: directory) }
    let trip = try XCTUnwrap(Samples.journeys.first)
    let memory = try XCTUnwrap(trip.stops.first)
    let image = try XCTUnwrap(PostcardExporter.render(journey: trip, memory: memory))
    let first = try PostcardExporter.write(
      image: image, place: "../Kyōto: Higashiyama", directory: directory)
    let second = try PostcardExporter.write(
      image: image, place: "../Kyōto: Higashiyama", directory: directory)
    XCTAssertNotEqual(first, second)
    XCTAssertEqual(first.lastPathComponent, "Greetings from Kyōto Higashiyama.png")
    XCTAssertEqual(first.deletingLastPathComponent().deletingLastPathComponent(), directory)
    let data = try Data(contentsOf: first)
    XCTAssertEqual(data, try XCTUnwrap(image.pngData()))
    XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
    let exported = try XCTUnwrap(UIImage(data: data))
    XCTAssertEqual(exported.cgImage?.width, 1200)
    XCTAssertEqual(exported.cgImage?.height, 1760)
    try FileManager.default.removeItem(at: first.deletingLastPathComponent())
    XCTAssertEqual(try Data(contentsOf: second), data)
  }
}
