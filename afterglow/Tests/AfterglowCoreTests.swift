import CoreGraphics
import Foundation
import ImageIO
import XCTest

@testable import AfterglowCore

final class AfterglowCoreTests: XCTestCase {
  private var sampleURL: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("Assets/dunes.jpg")
  }

  func testHistoryBranchAndResetCanBeUndone() {
    var history = EditHistory()
    var edit = Edit()
    edit.look = .ember
    history.apply(edit)
    edit.exposure = 0.75
    history.apply(edit)
    history.undo()
    XCTAssertEqual(history.current.exposure, 0)
    XCTAssertEqual(history.current.look, .ember)
    history.redo()
    XCTAssertEqual(history.current, edit)
    history.apply(Edit())
    XCTAssertEqual(history.current, Edit())
    history.undo()
    XCTAssertEqual(history.current, edit)
    history.undo()
    edit.look = .coast
    history.apply(edit)
    XCTAssertFalse(history.canRedo)
  }

  func testHistoryBoundedAndNoOpDoesNotCreateEntry() {
    var history = EditHistory()
    history.apply(Edit())
    XCTAssertFalse(history.canUndo)
    for index in 0..<100 {
      var edit = Edit()
      edit.exposure = Double(index) / 100
      history.apply(edit)
    }
    XCTAssertEqual(history.undoStack.count, 60)
  }

  func testInvalidValuesAreSanitized() {
    var edit = Edit()
    edit.exposure = .infinity
    edit.zoom = -20
    edit.rotation = -1
    edit.panX = 30
    edit.contrast = .nan
    let result = edit.sanitized()
    XCTAssertEqual(result.exposure, 0)
    XCTAssertEqual(result.zoom, 1)
    XCTAssertEqual(result.rotation, 3)
    XCTAssertEqual(result.panX, 1)
    XCTAssertEqual(result.contrast, 1)
  }

  func testCropRatiosBoundsZoomAndPan() {
    for format in CropFormat.allCases {
      for pan in [-1.0, 0, 1] {
        var edit = Edit()
        edit.crop = format
        edit.zoom = 1.3
        edit.panX = pan
        edit.panY = -pan
        let size = CGSize(width: 1024, height: 1536)
        let rect = PhotoRenderer.cropRect(size: size, edit: edit)
        XCTAssertTrue(CGRect(origin: .zero, size: size).contains(rect))
        let expected = format.ratio ?? 1024.0 / 1536
        XCTAssertEqual(rect.width / rect.height, expected, accuracy: 0.003)
      }
    }
  }

  func testProjectRoundTripPreservesSelectionAndHistory() throws {
    let folder = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Caches/AfterglowTests/\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("project.json")
    var project = Project()
    project.selectedID = "coast"
    var history = EditHistory()
    var edit = Edit()
    edit.look = .silver
    edit.crop = .square
    history.apply(edit)
    history.undo()
    project.photos["coast"] = history
    try ProjectFile.save(project, to: url)
    XCTAssertEqual(try ProjectFile.load(from: url), project)
    try Data("not a project".utf8).write(to: url)
    XCTAssertThrowsError(try ProjectFile.load(from: url))
  }

  func testRenderedExposureAndEachLookChangeActualPixels() throws {
    let original = try PhotoRenderer.render(url: sampleURL, edit: Edit(), maxDimension: 100)
    let baseline = pixels(original)
    for look in FilmLook.allCases where look != .original {
      var edit = Edit()
      edit.look = look
      let image = try PhotoRenderer.render(url: sampleURL, edit: edit, maxDimension: 100)
      XCTAssertNotEqual(pixels(image), baseline, look.rawValue)
    }
    var bright = Edit()
    bright.exposure = 1
    let result = try PhotoRenderer.render(url: sampleURL, edit: bright, maxDimension: 100)
    XCTAssertGreaterThan(mean(pixels(result)), mean(baseline))
    for key in [\Edit.contrast, \Edit.saturation, \Edit.warmth] {
      var edit = Edit()
      edit[keyPath: key] = 0.5
      let image = try PhotoRenderer.render(url: sampleURL, edit: edit, maxDimension: 100)
      XCTAssertNotEqual(pixels(image), baseline)
    }
  }

  func testRotationAndExportedJPEGDimensionsAndPixels() throws {
    let original = try PhotoRenderer.render(url: sampleURL, edit: Edit())
    var edit = Edit()
    edit.rotation = 1
    let rotated = try PhotoRenderer.render(url: sampleURL, edit: edit)
    XCTAssertEqual(rotated.width, original.height)
    XCTAssertEqual(rotated.height, original.width)
    edit.crop = .square
    edit.look = .silver
    edit.exposure = 0.5
    let image = try PhotoRenderer.render(url: sampleURL, edit: edit)
    XCTAssertEqual(image.width, image.height)
    let url = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Caches/AfterglowTests/\(UUID().uuidString).jpg")
    defer { try? FileManager.default.removeItem(at: url) }
    try PhotoRenderer.exportJPEG(image: image, to: url)
    let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
    let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    XCTAssertEqual(decoded.width, image.width)
    XCTAssertEqual(decoded.height, image.height)
    XCTAssertGreaterThan(try Data(contentsOf: url).count, 10000)
    let rgb = pixels(decoded)
    let colorDifference =
      stride(from: 0, to: rgb.count, by: 4).reduce(0.0) {
        $0 + abs(Double(rgb[$1]) - Double(rgb[$1 + 1]))
      } / Double(rgb.count / 4)
    XCTAssertLessThan(colorDifference, 3)
  }

  private func pixels(_ image: CGImage) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { buffer in
      let context = CGContext(
        data: buffer.baseAddress, width: image.width, height: image.height,
        bitsPerComponent: 8, bytesPerRow: image.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return bytes
  }

  private func mean(_ pixels: [UInt8]) -> Double {
    var sum = 0.0
    for index in stride(from: 0, to: pixels.count, by: 4) {
      sum += Double(pixels[index])
      sum += Double(pixels[index + 1])
      sum += Double(pixels[index + 2])
    }
    return sum / Double(pixels.count / 4 * 3)
  }
}
