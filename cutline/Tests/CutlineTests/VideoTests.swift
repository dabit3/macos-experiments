import AVFoundation
import CoreGraphics
import Foundation
import XCTest

@testable import Cutline

final class VideoTests: XCTestCase {
  func testRealSamplesAndTitledExport() async throws {
    let root = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("CutlineVerification-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let media = try await SampleFactory.makeLibrary(in: root)
    XCTAssertEqual(media.count, 3)
    for item in media {
      let asset = AVURLAsset(url: URL(fileURLWithPath: item.path))
      let duration = try await asset.load(.duration).seconds
      XCTAssertEqual(duration, 6, accuracy: 0.05)
      let tracks = try await asset.loadTracks(withMediaType: .video)
      XCTAssertEqual(tracks.count, 1)
    }
    var project = Project(
      media: media,
      clips: [
        Clip(mediaID: media[2].id, inPoint: 1, outPoint: 3),
        Clip(mediaID: media[0].id, inPoint: 0.5, outPoint: 3),
        Clip(mediaID: media[1].id, inPoint: 2, outPoint: 4),
      ])
    project.title = "THE LONG WAY"
    project.subtitle = "A CUTLINE TEST FILM"
    let output = root.appendingPathComponent("test-export.mp4")
    try await VideoEngine.export(project, to: output)
    let exported = AVURLAsset(url: output)
    let duration = try await exported.load(.duration).seconds
    XCTAssertEqual(duration, 6.5, accuracy: 0.05)
    let tracks = try await exported.loadTracks(withMediaType: .video)
    XCTAssertEqual(tracks.count, 1)
    let size = try await tracks[0].load(.naturalSize)
    XCTAssertEqual(size, CGSize(width: 1280, height: 720))
    let audio = try await exported.loadTracks(withMediaType: .audio)
    XCTAssertEqual(audio.count, 0)

    let titled = try await image(output, seconds: 1)
    let source = try await image(URL(fileURLWithPath: media[2].path), seconds: 2)
    XCTAssertGreaterThan(
      pixelDifference(titled, source), 2.0, "Title must be burned into exported pixels.")
    let acrossCut = try await image(output, seconds: 3)
    XCTAssertGreaterThan(pixelDifference(titled, acrossCut), 15, "Export must contain a real cut.")
    let motionA = try await image(URL(fileURLWithPath: media[0].path), seconds: 0.5)
    let motionB = try await image(URL(fileURLWithPath: media[0].path), seconds: 4.5)
    XCTAssertGreaterThan(
      pixelDifference(motionA, motionB), 1, "Sample must contain real changing frames.")

    let imported = try await VideoEngine.importMovie(
      output, to: root.appendingPathComponent("imported.mov"))
    XCTAssertEqual(imported.duration, 6.5, accuracy: 0.05)
    XCTAssertTrue(FileManager.default.fileExists(atPath: imported.path))
  }

  private func image(_ url: URL, seconds: Double) async throws -> CGImage {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    return try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
  }

  private func pixelDifference(_ left: CGImage, _ right: CGImage) -> Double {
    func pixels(_ image: CGImage) -> [UInt8] {
      var data = [UInt8](repeating: 0, count: 128 * 72 * 4)
      data.withUnsafeMutableBytes { bytes in
        let c = CGContext(
          data: bytes.baseAddress, width: 128, height: 72, bitsPerComponent: 8,
          bytesPerRow: 128 * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.draw(image, in: CGRect(x: 0, y: 0, width: 128, height: 72))
      }
      return data
    }
    let a = pixels(left)
    let b = pixels(right)
    return zip(a, b).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(a.count)
  }
}
