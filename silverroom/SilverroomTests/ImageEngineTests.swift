import CoreImage
import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest

@testable import Silverroom

final class ImageEngineTests: XCTestCase {
  private func fixture(width: Int = 120, height: Int = 80, orientation: Int = 1) throws -> Data {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
      .image { context in
        UIColor(red: 0.6, green: 0.3, blue: 0.15, alpha: 1).setFill()
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        UIColor(red: 0.12, green: 0.5, blue: 0.75, alpha: 1).setFill()
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
      }
    let output = NSMutableData()
    let destination = try XCTUnwrap(
      CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(
      destination, try XCTUnwrap(image.cgImage),
      [kCGImagePropertyOrientation: orientation] as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return output as Data
  }

  private func pixel(_ image: UIImage, x: Int = 10, y: Int = 10) throws -> [UInt8] {
    let cgImage = try XCTUnwrap(image.cgImage)
    var bytes = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
    let context = try XCTUnwrap(
      CGContext(
        data: &bytes, width: cgImage.width, height: cgImage.height,
        bitsPerComponent: 8, bytesPerRow: cgImage.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    let offset = (y * cgImage.width + x) * 4
    return Array(bytes[offset..<(offset + 3)])
  }

  func testClampingAndNonFiniteValues() {
    let edit = EditSettings(exposure: 8, contrast: -5, warmth: .infinity, quarterTurns: -1)
      .normalized
    XCTAssertEqual(edit.exposure, 2)
    XCTAssertEqual(edit.contrast, 0.5)
    XCTAssertEqual(edit.warmth, 0)
    XCTAssertEqual(edit.quarterTurns, 3)
    XCTAssertEqual(EditSettings(exposure: .nan, contrast: .nan).normalized, EditSettings())
  }

  func testAllPresetsProduceDistinctPixelsAndMonochromeIsNeutral() throws {
    let data = try fixture()
    let engine = ImageEngine()
    var pixels: Set<[UInt8]> = []
    for film in Film.allCases {
      let image = try engine.render(data, settings: EditSettings(film: film))
      let rgb = try pixel(image)
      pixels.insert(rgb)
      if film == .silver || film == .noir {
        XCTAssertLessThanOrEqual(abs(Int(rgb[0]) - Int(rgb[1])), 1)
        XCTAssertLessThanOrEqual(abs(Int(rgb[1]) - Int(rgb[2])), 1)
      }
    }
    XCTAssertEqual(pixels.count, Film.allCases.count)
  }

  func testExposureComposesWithPresetRatherThanReplacingIt() throws {
    let data = try fixture()
    let engine = ImageEngine()
    let dark = try pixel(engine.render(data, settings: EditSettings(film: .silver, exposure: -0.5)))
    let light = try pixel(engine.render(data, settings: EditSettings(film: .silver, exposure: 0.5)))
    XCTAssertGreaterThan(light[0], dark[0])
    XCTAssertLessThanOrEqual(abs(Int(light[0]) - Int(light[2])), 1)
  }

  func testWarmthAndContrastActuallyChangePixels() throws {
    let data = try fixture()
    let engine = ImageEngine()
    let original = try pixel(engine.render(data, settings: EditSettings()))
    XCTAssertNotEqual(
      try pixel(engine.render(data, settings: EditSettings(contrast: 1.4))), original)
    XCTAssertNotEqual(try pixel(engine.render(data, settings: EditSettings(warmth: 1))), original)
  }

  func testRotationCropAndFullResolutionJPEGDimensions() throws {
    let data = try fixture(width: 601, height: 403)
    let engine = ImageEngine()
    let rotated = try engine.export(data, settings: EditSettings(quarterTurns: 1))
    let decoded = try XCTUnwrap(UIImage(data: rotated))
    XCTAssertEqual(decoded.size, CGSize(width: 403, height: 601))
    let square = try engine.export(data, settings: EditSettings(quarterTurns: 3, squareCrop: true))
    XCTAssertEqual(UIImage(data: square)?.size, CGSize(width: 403, height: 403))
    XCTAssertEqual(
      try engine.dimensions(data, settings: EditSettings(quarterTurns: 1)), decoded.size)
  }

  func testEXIFOrientationAppliedExactlyOnceToPreviewAndExport() throws {
    let engine = ImageEngine()
    for orientation in 1...8 {
      let data = try fixture(orientation: orientation)
      let expected =
        orientation >= 5 ? CGSize(width: 80, height: 120) : CGSize(width: 120, height: 80)
      let preview = try engine.render(data, settings: EditSettings(), maxPixel: 120)
      let full = try engine.render(data, settings: EditSettings())
      XCTAssertEqual(preview.size, expected, "EXIF \(orientation)")
      XCTAssertEqual(full.size, expected, "EXIF \(orientation)")
      let previewPixel = try pixel(preview)
      let fullPixel = try pixel(full)
      for channel in 0..<3 {
        XCTAssertLessThanOrEqual(abs(Int(previewPixel[channel]) - Int(fullPixel[channel])), 5)
      }
    }
  }

  func testFourRotationsRestorePixelsAndDimensions() throws {
    let data = try fixture()
    let engine = ImageEngine()
    let original = try engine.render(data, settings: EditSettings())
    let rotated = try engine.render(data, settings: EditSettings(quarterTurns: 4))
    XCTAssertEqual(rotated.size, original.size)
    XCTAssertEqual(try pixel(rotated), try pixel(original))
  }

  func testPreviewIsDownsampledButExportRemainsFullSize() throws {
    let data = try fixture(width: 600, height: 400)
    let engine = ImageEngine()
    let small = try engine.render(data, settings: EditSettings(), maxPixel: 150)
    XCTAssertEqual(small.size, CGSize(width: 150, height: 100))
    let export = try engine.export(data, settings: EditSettings())
    XCTAssertEqual(UIImage(data: export)?.size, CGSize(width: 600, height: 400))
  }

  func testInvalidDataFailsGracefully() {
    XCTAssertThrowsError(
      try ImageEngine().render(Data("not a photo".utf8), settings: EditSettings()))
    XCTAssertThrowsError(try ImageEngine().render(Data(), settings: EditSettings(), maxPixel: 100))
  }

  func testDiskRoundTripPersistsEditsAndRecipes() throws {
    let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let disk = LibraryDisk(directory: directory)
    var state = try disk.load()
    let settings = EditSettings(
      film: .dune, exposure: 0.5, warmth: 0.3, quarterTurns: 1, squareCrop: true)
    state.negatives[0].settings = settings
    state.recipes.append(Recipe(name: "Summer", settings: settings.recipe))
    try disk.save(state)
    let restored = try disk.load()
    XCTAssertEqual(restored.negatives[0].settings, settings)
    XCTAssertEqual(restored.recipes[0].settings.quarterTurns, 0)
    XCTAssertFalse(restored.recipes[0].settings.squareCrop)
    XCTAssertEqual(restored.recipes[0].settings.film, .dune)
    XCTAssertEqual(restored.recipes[0].name, "Summer")
  }
}
