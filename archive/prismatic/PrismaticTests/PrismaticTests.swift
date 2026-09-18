import UIKit
import XCTest

@testable import Prismatic

final class PrismaticTests: XCTestCase {
  func testQuarterTurnPreservesRadius() {
    let point = ArtPoint(x: 0.5, y: 0.2)
    let result = point.transformed(axis: 1, count: 4, mirrored: false)
    XCTAssertEqual(result.x, 0.8, accuracy: 0.000001)
    XCTAssertEqual(result.y, 0.5, accuracy: 0.000001)
    for count in 1...24 {
      for axis in 0..<count {
        let p = point.transformed(axis: axis, count: count, mirrored: false)
        XCTAssertEqual(hypot(p.x - 0.5, p.y - 0.5), 0.3, accuracy: 0.000001)
      }
    }
  }

  func testMirrorAndRotationComposition() {
    let point = ArtPoint(x: 0.7, y: 0.3)
    let mirrored = point.transformed(axis: 0, count: 8, mirrored: true)
    XCTAssertEqual(mirrored.x, 0.3, accuracy: 0.000001)
    XCTAssertEqual(mirrored.y, 0.3, accuracy: 0.000001)
    let rotated = point.transformed(axis: 1, count: 4, mirrored: true)
    XCTAssertEqual(rotated.x, 0.7, accuracy: 0.000001)
    XCTAssertEqual(rotated.y, 0.3, accuracy: 0.000001)
  }

  func testHistoryUndoRedoClearAndNewBranch() {
    let stroke = Samples.aurora.strokes[0]
    var history = StrokeHistory()
    history.record([])
    XCTAssertEqual(history.undo([stroke]), [])
    XCTAssertEqual(history.redo([]), [stroke])
    history.record([stroke])
    XCTAssertEqual(history.undo([]), [stroke])
    history.record([stroke])
    XCTAssertFalse(history.canRedo)
    XCTAssertNil(history.redo([stroke]))
  }

  func testSerializationRetainsAllStrokeProperties() throws {
    let archive = StudioArchive(
      current: Samples.aurora, gallery: Samples.all, settings: StudioSettings())
    let restored = try JSONDecoder().decode(StudioArchive.self, from: JSONEncoder().encode(archive))
    XCTAssertEqual(restored.current, archive.current)
    XCTAssertEqual(restored.gallery, archive.gallery)
    XCTAssertEqual(restored.settings.symmetry, 8)
    XCTAssertEqual(restored.settings.brush, .silk)
  }

  func testPersistenceSaveOverwriteAndDelete() throws {
    let directory = URL.documentsDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "test.json")
    let studio = Studio(storageURL: url)
    studio.newCanvas()
    studio.add(Samples.ember.strokes[0])
    studio.save(title: "  First light  ")
    studio.settings.symmetry = 24
    studio.persist()
    let restored = Studio(storageURL: url)
    XCTAssertEqual(restored.current.title, "First light")
    XCTAssertEqual(restored.current.strokes.count, 1)
    XCTAssertEqual(restored.gallery.count, 1)
    XCTAssertEqual(restored.settings.symmetry, 24)
    restored.save(title: "Renamed")
    XCTAssertEqual(restored.gallery.count, 1)
    restored.delete(restored.gallery[0])
    XCTAssertTrue(Studio(storageURL: url).gallery.isEmpty)
  }

  func testClearCanBeUndoneWithoutChangingGallery() throws {
    let url = URL.documentsDirectory.appending(path: "\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let studio = Studio(storageURL: url)
    studio.save(title: "Keep")
    let count = studio.current.strokes.count
    studio.clear()
    XCTAssertTrue(studio.current.strokes.isEmpty)
    XCTAssertEqual(studio.gallery[0].strokes.count, count)
    studio.undo()
    XCTAssertEqual(studio.current.strokes.count, count)
    studio.redo()
    XCTAssertTrue(studio.current.strokes.isEmpty)
  }

  func testPNGExportIsReal2048SquareImage() throws {
    let url = try ArtRenderer.export(Samples.aurora)
    defer { try? FileManager.default.removeItem(at: url) }
    let data = try Data(contentsOf: url)
    XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
    let image = try XCTUnwrap(UIImage(data: data))
    XCTAssertEqual(image.cgImage?.width, 2048)
    XCTAssertEqual(image.cgImage?.height, 2048)
    XCTAssertGreaterThan(data.count, 100_000)
  }

  func testExportPreservesReadableTitleWithoutCreatingNestedPaths() throws {
    var artwork = Artwork(title: "  Autumn / 光 : study  ")
    let url = try ArtRenderer.export(artwork)
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    XCTAssertEqual(url.lastPathComponent, "Autumn 光 study.png")
    XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, artwork.id.uuidString)
    artwork.title = "../"
    let fallback = try ArtRenderer.export(artwork)
    XCTAssertEqual(fallback.lastPathComponent, "Prismatic.png")
  }
}
