import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension UIColor {
  convenience init(hex: String) {
    let value = UInt32(hex, radix: 16) ?? 0
    self.init(
      red: CGFloat((value >> 16) & 255) / 255,
      green: CGFloat((value >> 8) & 255) / 255,
      blue: CGFloat(value & 255) / 255, alpha: 1)
  }
}

extension Color {
  init(hex: String) { self.init(uiColor: UIColor(hex: hex)) }
}

enum ArtworkRenderer {
  static let size = CGSize(width: 800, height: 520)
  static let paper = UIColor(hex: "F7F0E3")

  static func draw(_ strokes: [InkStroke], in context: CGContext) {
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    for stroke in strokes {
      guard let first = stroke.points.first else { continue }
      context.saveGState()
      context.setBlendMode(stroke.eraser ? .clear : .normal)
      context.setStrokeColor(UIColor(hex: stroke.color).cgColor)
      context.setFillColor(UIColor(hex: stroke.color).cgColor)
      context.setLineWidth(stroke.width)
      context.setLineCap(.round)
      context.setLineJoin(.round)
      if stroke.points.count == 1 {
        context.fillEllipse(
          in: CGRect(
            x: first.x - stroke.width / 2,
            y: first.y - stroke.width / 2,
            width: stroke.width, height: stroke.width))
      } else {
        context.beginPath()
        context.move(to: CGPoint(x: first.x, y: first.y))
        for point in stroke.points.dropFirst() {
          context.addLine(to: CGPoint(x: point.x, y: point.y))
        }
        if stroke.filled {
          context.closePath()
          context.fillPath()
        } else {
          context.strokePath()
        }
      }
      context.restoreGState()
    }
    context.endTransparencyLayer()
  }

  static func image(_ frame: AnimationFrame, width: CGFloat = 800) -> UIImage {
    let target = CGSize(width: width, height: width * size.height / size.width)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: target, format: format).image { renderer in
      let context = renderer.cgContext
      context.setFillColor(paper.cgColor)
      context.fill(CGRect(origin: .zero, size: target))
      context.scaleBy(x: width / 800, y: width / 800)
      draw(frame.strokes, in: context)
    }
  }
}

struct DrawingStage: UIViewRepresentable {
  @ObservedObject var store: StudioStore
  func makeUIView(context: Context) -> DrawingSurface { DrawingSurface() }
  func updateUIView(_ view: DrawingSurface, context: Context) {
    view.frameData = store.currentFrame
    view.previous = store.onionSkin && !store.playing ? store.previousFrame : nil
    view.inkColor = store.color
    view.inkWidth = store.eraser ? store.brushSize * 4 : store.brushSize
    view.eraser = store.eraser
    view.isUserInteractionEnabled = !store.playing
    view.commit = { store.addStroke($0) }
    view.setNeedsDisplay()
  }
}

final class DrawingSurface: UIView {
  var frameData = AnimationFrame()
  var previous: AnimationFrame?
  var inkColor = "493446"
  var inkWidth = 7.0
  var eraser = false
  var commit: ((InkStroke) -> Void)?
  private var pending: InkStroke?

  init() {
    super.init(frame: .zero)
    backgroundColor = ArtworkRenderer.paper
    isMultipleTouchEnabled = false
    accessibilityLabel = "Drawing stage"
    accessibilityIdentifier = "drawing-stage"
    accessibilityHint = "Drag with your finger or Pencil to draw on the current frame."
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    context.scaleBy(x: bounds.width / 800, y: bounds.height / 520)
    if let previous {
      context.saveGState()
      context.setAlpha(0.18)
      ArtworkRenderer.draw(previous.strokes, in: context)
      context.restoreGState()
    }
    ArtworkRenderer.draw(frameData.strokes + (pending.map { [$0] } ?? []), in: context)
  }

  private func point(_ touch: UITouch) -> InkPoint {
    let location = touch.location(in: self)
    return InkPoint(
      x: min(800, max(0, location.x / bounds.width * 800)),
      y: min(520, max(0, location.y / bounds.height * 520)))
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    pending = InkStroke(
      points: [point(touch)], color: inkColor,
      width: inkWidth, eraser: eraser)
    setNeedsDisplay()
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    for sample in event?.coalescedTouches(for: touch) ?? [touch] {
      pending?.points.append(point(sample))
    }
    setNeedsDisplay()
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    if let touch = touches.first { pending?.points.append(point(touch)) }
    if let pending { commit?(pending) }
    pending = nil
    setNeedsDisplay()
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    pending = nil
    setNeedsDisplay()
  }
}

enum GIFExporter {
  enum ExportError: LocalizedError {
    case failed
    var errorDescription: String? { "The animated GIF could not be written." }
  }
  static func export(_ project: AnimationProject, to url: URL) throws {
    _ = try project.validated()
    let temporary = url.deletingPathExtension().appendingPathExtension("writing.gif")
    guard
      let destination = CGImageDestinationCreateWithURL(
        temporary as CFURL, UTType.gif.identifier as CFString, project.frames.count, nil)
    else { throw ExportError.failed }
    CGImageDestinationSetProperties(
      destination,
      [
        kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
      ] as CFDictionary)
    for frame in project.frames {
      guard let image = ArtworkRenderer.image(frame).cgImage else { throw ExportError.failed }
      CGImageDestinationAddImage(
        destination, image,
        [
          kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: 1.0 / Double(project.fps),
            kCGImagePropertyGIFUnclampedDelayTime: 1.0 / Double(project.fps),
          ]
        ] as CFDictionary)
    }
    guard CGImageDestinationFinalize(destination) else { throw ExportError.failed }
    if FileManager.default.fileExists(atPath: url.path) {
      _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
    } else {
      try FileManager.default.moveItem(at: temporary, to: url)
    }
  }
}
