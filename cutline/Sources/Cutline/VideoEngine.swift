import AVFoundation
import AppKit
import CoreImage
import CoreText

struct Sequence {
  let composition: AVMutableComposition
  let videoComposition: AVVideoComposition
}

enum VideoEngine {
  static let canvas = CGSize(width: 1280, height: 720)

  static func sequence(_ project: Project) async throws -> Sequence {
    let composition = AVMutableComposition()
    guard
      let track = composition.addMutableTrack(
        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    else { throw EditorError.noVideo }
    var cursor = CMTime.zero
    for clip in project.clips {
      guard let media = project.media.first(where: { $0.id == clip.mediaID }),
        FileManager.default.fileExists(atPath: media.path)
      else { throw EditorError.missingMedia }
      let asset = AVURLAsset(url: URL(fileURLWithPath: media.path))
      guard let source = try await asset.loadTracks(withMediaType: .video).first else {
        throw EditorError.noVideo
      }
      let range = CMTimeRange(
        start: CMTime(seconds: clip.inPoint, preferredTimescale: 600),
        duration: CMTime(seconds: clip.duration, preferredTimescale: 600))
      try track.insertTimeRange(range, of: source, at: cursor)
      cursor = cursor + range.duration
    }
    let title = titleImage(project)
    let duration = min(4, project.clips.first?.duration ?? 4)
    let video = AVVideoComposition(asset: composition) { request in
      let source = request.sourceImage
      let seconds = request.compositionTime.seconds
      if project.titleEnabled, seconds < duration, let title {
        let opacity = min(1, seconds / 0.35, (duration - seconds) / 0.45)
        let faded = title.applyingFilter(
          "CIColorMatrix",
          parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: max(0, opacity))])
        request.finish(with: faded.composited(over: source), context: nil)
      } else {
        request.finish(with: source, context: nil)
      }
    }
    return Sequence(composition: composition, videoComposition: video)
  }

  static func titleImage(_ project: Project) -> CIImage? {
    guard
      let c = CGContext(
        data: nil, width: 1280, height: 720, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    let g = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: [CGColor(gray: 0, alpha: 0.36), CGColor(gray: 0, alpha: 0)] as CFArray,
      locations: [0, 1])!
    c.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 650), options: [])
    let centered = project.titleStyle == .postcard
    let minimal = project.titleStyle == .minimal
    let fontName = project.titleStyle == .editorial ? "Baskerville" : "AvenirNext-DemiBold"
    let fontSize: CGFloat = minimal ? 44 : 83
    let lines = project.title.components(separatedBy: "\n").prefix(3)
    let baseY: CGFloat = minimal ? 126 : (centered ? 350 : 272)
    for (index, text) in lines.enumerated() {
      drawText(
        text, font: fontName, size: fontSize, tracking: minimal ? 0 : -1,
        x: 82, y: baseY - CGFloat(index) * fontSize * 0.98,
        centered: centered, in: c)
    }
    let subY = baseY - CGFloat(max(0, lines.count - 1)) * fontSize * 0.98 - 45
    drawText(
      project.subtitle, font: "AvenirNext-Medium", size: 15, tracking: 3,
      x: 85, y: subY, centered: centered, in: c)
    if !minimal {
      c.setFillColor(SampleFactory.color(0xA3E2DA))
      c.fill(CGRect(x: centered ? 615 : 85, y: subY - 25, width: 50, height: 3))
    }
    return c.makeImage().map { CIImage(cgImage: $0) }
  }

  static func drawText(
    _ text: String, font: String, size: CGFloat, tracking: CGFloat,
    x: CGFloat, y: CGFloat, centered: Bool, in c: CGContext
  ) {
    let string = NSAttributedString(
      string: text,
      attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName(
          font as CFString, size, nil),
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(
          gray: 0.98, alpha: 1),
        NSAttributedString.Key(kCTKernAttributeName as String): tracking,
      ])
    let line = CTLineCreateWithAttributedString(string)
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    let scale = min(1, 1110 / max(1, width))
    c.saveGState()
    c.translateBy(x: centered ? (1280 - width * scale) / 2 : x, y: y)
    c.scaleBy(x: scale, y: scale)
    c.textPosition = .zero
    c.setShadow(offset: CGSize(width: 0, height: -2), blur: 9, color: CGColor(gray: 0, alpha: 0.22))
    CTLineDraw(line, c)
    c.restoreGState()
  }

  static func export(_ project: Project, to url: URL) async throws {
    guard !project.clips.isEmpty else { throw EditorError.noVideo }
    let sequence = try await sequence(project)
    guard
      let exporter = AVAssetExportSession(
        asset: sequence.composition, presetName: AVAssetExportPresetHighestQuality)
    else { throw EditorError.exportFailed("Cannot create exporter.") }
    exporter.videoComposition = sequence.videoComposition
    exporter.shouldOptimizeForNetworkUse = true
    try await exporter.export(to: url, as: .mp4)
  }

  static func importMovie(_ url: URL, to output: URL) async throws -> Media {
    let asset = AVURLAsset(url: url)
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
      throw EditorError.noVideo
    }
    let duration = try await asset.load(.duration)
    guard duration.seconds.isFinite, duration.seconds >= 0.25, duration.seconds <= 600 else {
      throw EditorError.exportFailed("Import a video between 0.25 seconds and 10 minutes.")
    }
    let naturalSize = try await track.load(.naturalSize)
    let preferred = try await track.load(.preferredTransform)
    let rect = CGRect(origin: .zero, size: naturalSize).applying(preferred)
    let scale = min(canvas.width / rect.width, canvas.height / rect.height)
    let transform =
      preferred
      .concatenating(CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
      .concatenating(CGAffineTransform(scaleX: scale, y: scale))
      .concatenating(
        CGAffineTransform(
          translationX: (canvas.width - rect.width * scale) / 2,
          y: (canvas.height - rect.height * scale) / 2))
    let composition = AVMutableComposition()
    guard
      let outputTrack = composition.addMutableTrack(
        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    else { throw EditorError.noVideo }
    try outputTrack.insertTimeRange(
      CMTimeRange(start: .zero, duration: duration), of: track, at: .zero)
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
    instruction.backgroundColor = CGColor(gray: 0, alpha: 1)
    let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: outputTrack)
    layer.setTransform(transform, at: .zero)
    instruction.layerInstructions = [layer]
    let video = AVMutableVideoComposition()
    video.renderSize = canvas
    video.frameDuration = CMTime(value: 1, timescale: 24)
    video.instructions = [instruction]
    guard
      let exporter = AVAssetExportSession(
        asset: composition, presetName: AVAssetExportPresetHighestQuality)
    else { throw EditorError.exportFailed("Cannot import this video.") }
    exporter.videoComposition = video
    try await exporter.export(to: output, as: .mov)
    return Media(
      id: UUID().uuidString, name: url.deletingPathExtension().lastPathComponent,
      detail: "LOCAL IMPORT / 720P", duration: duration.seconds, path: output.path)
  }

  static func thumbnail(_ url: URL, at time: Double = 1) async throws -> NSImage {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 640, height: 360)
    let result = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600))
    return NSImage(cgImage: result.image, size: NSSize(width: 640, height: 360))
  }
}
