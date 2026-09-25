import UIKit
import XCTest

@testable import Curio

@MainActor
final class MuseumTests: XCTestCase {
  private var directory: URL!

  override func setUp() {
    super.setUp()
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: directory)
    super.tearDown()
  }

  func testSampleAndFullCRUDPersistAcrossRelaunch() throws {
    let store = MuseumStore(directory: directory)
    XCTAssertEqual(store.objects.count, 6)
    XCTAssertTrue(store.objects.allSatisfy(\.isSample))
    let collection = MuseumCollection(title: "My finds", subtitle: "From the market")
    XCTAssertTrue(store.saveCollection(collection))
    var object = MuseumObject(
      collectionID: collection.id, title: "  Tiny cup  ", maker: "Clay",
      story: "A gift", acquired: Date(), tags: ["ceramics"], artifact: .vase,
      photo: Data([1, 2, 3]), catalogNumber: 0)
    XCTAssertTrue(store.saveObject(object))
    XCTAssertEqual(store.object(object.id)?.catalogNumber, 7)
    XCTAssertEqual(store.object(object.id)?.title, "Tiny cup")
    object = try XCTUnwrap(store.object(object.id))
    object.story = "A gift from my sister"
    XCTAssertTrue(store.saveObject(object))
    store.toggleFavorite(object.id)
    let restored = MuseumStore(directory: directory)
    XCTAssertEqual(restored.object(object.id)?.story, "A gift from my sister")
    XCTAssertEqual(restored.object(object.id)?.photo, Data([1, 2, 3]))
    XCTAssertEqual(restored.object(object.id)?.isFavorite, true)
    XCTAssertTrue(restored.deleteObject(object.id))
    XCTAssertNil(MuseumStore(directory: directory).object(object.id))
    XCTAssertTrue(restored.deleteCollection(collection.id))
    XCTAssertNil(MuseumStore(directory: directory).collection(collection.id))
  }

  func testSearchTagsFavoritesAndCollectionAreCombined() throws {
    let store = MuseumStore(directory: directory)
    XCTAssertEqual(store.query(text: "PHOTOGRAPHY").count, 1)
    XCTAssertEqual(store.query(text: "  slow down  ").first?.artifact, .camera)
    XCTAssertEqual(store.query(tag: "design").count, 3)
    XCTAssertEqual(store.query(tag: "design", favorites: true).count, 0)
    XCTAssertEqual(store.query(tag: "ceramics", favorites: true).count, 1)
    XCTAssertEqual(store.query(collectionID: UUID(), text: "camera").count, 0)
    XCTAssertEqual(MuseumObject.tags(from: " Clay, clay, , blue  ,BLUE"), ["clay", "blue"])
  }

  func testValidationAndCascadeDeletion() throws {
    let store = MuseumStore(directory: directory)
    XCTAssertFalse(store.saveCollection(MuseumCollection(title: " \n ", subtitle: "")))
    var object = try XCTUnwrap(store.objects.first)
    object.collectionID = UUID()
    XCTAssertFalse(store.saveObject(object))
    XCTAssertEqual(store.objects.count, 6)
    let id = try XCTUnwrap(store.collections.first?.id)
    XCTAssertTrue(store.deleteCollection(id))
    XCTAssertTrue(store.objects.isEmpty)
    XCTAssertTrue(MuseumStore(directory: directory).collections.isEmpty)
    XCTAssertEqual(store.archive.nextNumber, 7)
  }

  func testCorruptDataIsNeverOverwritten() throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("museum.json")
    let original = Data("not a valid archive".utf8)
    try original.write(to: file)
    let store = MuseumStore(directory: directory)
    XCTAssertNotNil(store.errorMessage)
    XCTAssertFalse(store.saveCollection(MuseumCollection(title: "New", subtitle: "")))
    XCTAssertEqual(try Data(contentsOf: file), original)
  }

  func testExportProducesActualDecodablePNG() throws {
    let object = try XCTUnwrap(MuseumArchive.sample.objects.first)
    let file = try PosterRenderer.export(object: object, collection: "Everyday icons")
    let data = try Data(contentsOf: file)
    XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
    let image = try XCTUnwrap(UIImage(data: data))
    XCTAssertEqual(image.size.width, 960)
    XCTAssertGreaterThan(image.size.height, 1000)
    XCTAssertGreaterThan(data.count, 10_000)
  }

  func testMovePreservesIdentityAndNextCatalogNumber() throws {
    let store = MuseumStore(directory: directory)
    let collection = MuseumCollection(title: "New room", subtitle: "")
    XCTAssertTrue(store.saveCollection(collection))
    var object = try XCTUnwrap(store.objects.first)
    let catalogNumber = object.catalogNumber
    object.collectionID = collection.id
    object.artifact = .unpictured
    XCTAssertTrue(store.saveObject(object))
    let restored = MuseumStore(directory: directory)
    XCTAssertEqual(restored.query(collectionID: collection.id).map(\.id), [object.id])
    XCTAssertEqual(restored.object(object.id)?.catalogNumber, catalogNumber)
    XCTAssertEqual(restored.object(object.id)?.artifact, .unpictured)
    XCTAssertEqual(restored.archive.nextNumber, 7)
  }

  func testLabelFilenameIsReadableAndCannotEscapeExportDirectory() throws {
    var object = try XCTUnwrap(MuseumArchive.sample.objects.first)
    object.title = "../../A keepsake: / summer"
    let file = try PosterRenderer.export(object: object, collection: "Archive")
    XCTAssertEqual(file.lastPathComponent, "Curio-001-A-keepsake-summer.png")
    XCTAssertEqual(file.deletingLastPathComponent().lastPathComponent, "MuseumLabels")
  }
}
