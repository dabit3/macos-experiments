import AVFoundation
import AppKit
import CoreGraphics

enum SampleFactory {
  static let size = CGSize(width: 1280, height: 720)
  static let names = ["The blue coast", "A sea of dunes", "Where peaks sleep"]
  static let details = ["PORTUGAL / ATLANTIC", "MOROCCO / SAHARA", "ITALY / DOLOMITES"]

  static func makeLibrary(in directory: URL) async throws -> [Media] {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var media: [Media] = []
    for scene in 0..<3 {
      let url = directory.appendingPathComponent("cutline-scene-\(scene)-v1.mov")
      if !FileManager.default.fileExists(atPath: url.path) {
        try await writeMovie(scene: scene, to: url)
      }
      media.append(
        Media(
          id: "sample-\(scene)", name: names[scene], detail: details[scene],
          duration: 6, path: url.path))
    }
    return media
  }

  static func writeMovie(scene: Int, to url: URL) async throws {
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: 1280, AVVideoHeightKey: 720,
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 4_000_000],
      ])
    let adapter = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: 1280,
        kCVPixelBufferHeightKey as String: 720,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
      ])
    writer.add(input)
    guard writer.startWriting() else {
      throw EditorError.exportFailed(writer.error?.localizedDescription ?? "Cannot create sample.")
    }
    writer.startSession(atSourceTime: .zero)
    for frame in 0..<144 {
      while !input.isReadyForMoreMediaData {
        if writer.status == .failed { throw EditorError.exportFailed("Sample encoder failed.") }
        try await Task.sleep(nanoseconds: 2_000_000)
      }
      try autoreleasepool {
        var buffer: CVPixelBuffer?
        guard let pool = adapter.pixelBufferPool,
          CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
          let pixelBuffer = buffer
        else { throw EditorError.exportFailed("Cannot allocate sample frame.") }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard
          let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer), width: 1280, height: 720,
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        else { throw EditorError.exportFailed("Cannot draw sample frame.") }
        draw(scene: scene, time: Double(frame) / 24, in: context)
        guard
          adapter.append(
            pixelBuffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 24))
        else { throw EditorError.exportFailed("Cannot encode sample frame.") }
      }
    }
    input.markAsFinished()
    await writer.finishWriting()
    guard writer.status == .completed else {
      throw EditorError.exportFailed(
        writer.error?.localizedDescription ?? "Sample encoding failed.")
    }
  }

  static func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
      red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
      blue: CGFloat(hex & 255) / 255, alpha: alpha)
  }

  static func gradient(_ c: CGContext, top: UInt32, bottom: UInt32, from: CGFloat, to: CGFloat) {
    let g = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: [color(bottom), color(top)] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(
      g, start: CGPoint(x: 0, y: from), end: CGPoint(x: 0, y: to),
      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
  }

  static func polygon(_ c: CGContext, _ points: [CGPoint], _ hex: UInt32, alpha: CGFloat = 1) {
    c.beginPath()
    c.addLines(between: points)
    c.closePath()
    c.setFillColor(color(hex, alpha))
    c.fillPath()
  }

  static func draw(scene: Int, time: Double, in c: CGContext) {
    let motion = CGFloat(time * 8)
    c.saveGState()
    c.translateBy(x: -motion, y: 0)
    c.scaleBy(x: 1.06, y: 1.06)
    if scene == 0 {
      gradient(c, top: 0x376C80, bottom: 0xEFCDA0, from: 280, to: 720)
      c.setFillColor(color(0xFFE5AE))
      c.fillEllipse(in: CGRect(x: 945, y: 467, width: 72, height: 72))
      c.saveGState()
      c.clip(to: CGRect(x: 0, y: 0, width: 1400, height: 378))
      gradient(c, top: 0x4F9A9C, bottom: 0x113F52, from: 0, to: 378)
      for i in 0..<65 {
        let y = CGFloat(i) * 6
        c.setStrokeColor(color(i % 3 == 0 ? 0xE1D8AA : 0x88CBC2, 0.16))
        c.setLineWidth(i % 4 == 0 ? 2 : 1)
        c.move(to: CGPoint(x: -100, y: y))
        c.addCurve(
          to: CGPoint(x: 1400, y: y + 2),
          control1: CGPoint(x: 350 + sin(time + Double(i)) * 20, y: y + 7),
          control2: CGPoint(x: 900, y: y - 7))
        c.strokePath()
      }
      for i in 0..<28 {
        let y = CGFloat(i) * 11
        let width = 8 + CGFloat(i) * 3
        c.setFillColor(color(0xFFE4B1, 0.24 - CGFloat(i) * 0.005))
        c.fill(
          CGRect(
            x: 980 - width / 2 + sin(time * 1.5 + Double(i)) * 12,
            y: 363 - y, width: width, height: 2))
      }
      c.restoreGState()
      polygon(
        c,
        [
          CGPoint(x: 0, y: 365), CGPoint(x: 170, y: 360), CGPoint(x: 370, y: 320),
          CGPoint(x: 670, y: 200), CGPoint(x: 865, y: 80), CGPoint(x: 750, y: 0),
          CGPoint(x: 0, y: 0),
        ], 0xDEB68A)
      polygon(
        c,
        [
          CGPoint(x: 0, y: 399), CGPoint(x: 145, y: 418), CGPoint(x: 260, y: 386),
          CGPoint(x: 330, y: 337), CGPoint(x: 580, y: 247), CGPoint(x: 649, y: 172),
          CGPoint(x: 411, y: 186), CGPoint(x: 165, y: 124), CGPoint(x: 0, y: 180),
        ], 0xA5664D)
      polygon(
        c,
        [
          CGPoint(x: 0, y: 415), CGPoint(x: 145, y: 440), CGPoint(x: 249, y: 405),
          CGPoint(x: 318, y: 346), CGPoint(x: 570, y: 264), CGPoint(x: 627, y: 218),
          CGPoint(x: 353, y: 268), CGPoint(x: 106, y: 259), CGPoint(x: 0, y: 300),
        ], 0x586653)
      for i in 0..<24 {
        let x = CGFloat(i * 22)
        c.setStrokeColor(color(0xEDBE8A, 0.35))
        c.move(to: CGPoint(x: x, y: 285 - x * 0.12))
        c.addLine(to: CGPoint(x: x + 15, y: 165 - x * 0.04))
        c.strokePath()
      }
      polygon(
        c,
        [
          CGPoint(x: 0, y: 110), CGPoint(x: 177, y: 143), CGPoint(x: 310, y: 94),
          CGPoint(x: 413, y: 0), CGPoint(x: 0, y: 0),
        ], 0x293F3C)
    } else if scene == 1 {
      gradient(c, top: 0x554C64, bottom: 0xEDB084, from: 170, to: 720)
      c.setFillColor(color(0xFCD599))
      c.fillEllipse(in: CGRect(x: 780, y: 440, width: 116, height: 116))
      let hues: [UInt32] = [0xBC8171, 0xC88969, 0xDD9C70, 0xB4694D, 0xD18B5E, 0x884B3D]
      for i in 0..<6 {
        let base = CGFloat(300 - i * 60)
        let shift = CGFloat(i) * motion * 0.15
        c.beginPath()
        c.move(to: CGPoint(x: -100, y: base))
        c.addCurve(
          to: CGPoint(x: 1430, y: base + 40),
          control1: CGPoint(x: 300 + shift, y: base + 240 - CGFloat(i) * 12),
          control2: CGPoint(x: 540 + shift, y: base - 120))
        c.addLine(to: CGPoint(x: 1450, y: -30))
        c.addLine(to: CGPoint(x: -100, y: -30))
        c.closePath()
        c.setFillColor(color(hues[i]))
        c.fillPath()
        for j in 0..<8 {
          c.setStrokeColor(color(0xF1BB83, 0.12))
          c.move(to: CGPoint(x: -50, y: base - CGFloat(j * 7)))
          c.addCurve(
            to: CGPoint(x: 1400, y: base - CGFloat(j * 7) + 20),
            control1: CGPoint(x: 300 + shift, y: base + 200 - CGFloat(j * 9)),
            control2: CGPoint(x: 600 + shift, y: base - 180 - CGFloat(j * 9)))
          c.strokePath()
        }
      }
    } else {
      gradient(c, top: 0x223F55, bottom: 0xD1A9A1, from: 50, to: 720)
      c.setFillColor(color(0xF5DBBF))
      c.fillEllipse(in: CGRect(x: 1040, y: 527, width: 40, height: 40))
      let peaks: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
        (150, 437, 320, 0x68777D), (540, 480, 390, 0x798080),
        (1020, 430, 350, 0x5F737A), (325, 534, 390, 0x385664),
        (775, 562, 445, 0x3C5965),
      ]
      for (x, y, width, hue) in peaks {
        polygon(
          c,
          [
            CGPoint(x: x - width, y: 130), CGPoint(x: x - 80, y: y - 90),
            CGPoint(x: x, y: y), CGPoint(x: x + 55, y: y - 55),
            CGPoint(x: x + width, y: 130),
          ], hue)
        polygon(
          c,
          [
            CGPoint(x: x, y: y), CGPoint(x: x + 55, y: y - 55),
            CGPoint(x: x + width, y: 130), CGPoint(x: x + 30, y: 200),
          ], 0x233D50, alpha: 0.58)
        polygon(
          c,
          [
            CGPoint(x: x - 95, y: y - 110), CGPoint(x: x, y: y),
            CGPoint(x: x + 85, y: y - 91), CGPoint(x: x + 26, y: y - 59),
            CGPoint(x: x + 1, y: y - 80), CGPoint(x: x - 24, y: y - 55),
          ], 0xDAD4C7)
      }
      c.saveGState()
      c.clip(to: CGRect(x: 0, y: 0, width: 1400, height: 170))
      gradient(c, top: 0x5D9496, bottom: 0x1B424D, from: 0, to: 170)
      for i in 0..<28 {
        c.setStrokeColor(color(0x9EBDB3, 0.2))
        let y = CGFloat(i * 6)
        c.move(to: CGPoint(x: 0, y: y))
        c.addLine(to: CGPoint(x: 1400, y: y + sin(time + Double(i)) * 3))
        c.strokePath()
      }
      c.restoreGState()
      for i in 0..<23 {
        let x = CGFloat(i * 19)
        let h = CGFloat(65 + (i * 37) % 95)
        polygon(
          c,
          [
            CGPoint(x: x, y: 50), CGPoint(x: x + 22, y: 50 + h),
            CGPoint(x: x + 44, y: 50),
          ], 0x173B40)
      }
    }
    for i in 0..<3 where scene != 1 {
      let x = CGFloat(650 + i * 36) + CGFloat(time * 20)
      let y = CGFloat(455 + i * 9) + CGFloat(sin(time * 2 + Double(i)) * 5)
      c.setStrokeColor(color(0x243C43, 0.8))
      c.setLineWidth(2)
      c.move(to: CGPoint(x: x - 7, y: y + 2))
      c.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 3, y: y + 4))
      c.addQuadCurve(to: CGPoint(x: x + 7, y: y + 3), control: CGPoint(x: x + 4, y: y + 5))
      c.strokePath()
    }
    c.restoreGState()
  }
}
