import SwiftUI
import UIKit

extension UIColor {
  convenience init(hex: String) {
    let value = UInt64(hex, radix: 16) ?? 0xEFE8D8
    self.init(
      red: CGFloat((value >> 16) & 255) / 255,
      green: CGFloat((value >> 8) & 255) / 255,
      blue: CGFloat(value & 255) / 255, alpha: 1)
  }
}

enum ArtRenderer {
  static let background = UIColor(hex: "0C1114")

  static func image(strokes: [ArtStroke], size: CGFloat) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image {
      render(strokes, in: $0.cgContext, side: size)
    }
  }

  static func render(
    _ strokes: [ArtStroke], in context: CGContext, side: CGFloat, fill: Bool = true
  ) {
    if fill {
      context.setFillColor(background.cgColor)
      context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    }
    for stroke in strokes {
      for axis in 0..<max(1, stroke.symmetry) {
        draw(stroke, axis: axis, mirrored: false, in: context, side: side)
        if stroke.mirror {
          draw(stroke, axis: axis, mirrored: true, in: context, side: side)
        }
      }
    }
  }

  private static func draw(
    _ stroke: ArtStroke, axis: Int, mirrored: Bool, in context: CGContext, side: CGFloat
  ) {
    guard !stroke.points.isEmpty else { return }
    let points = stroke.points.map {
      let p = $0.transformed(axis: axis, count: stroke.symmetry, mirrored: mirrored)
      return CGPoint(x: p.x * side, y: p.y * side)
    }
    let color = UIColor(hex: stroke.pigment)
    let width = CGFloat(stroke.width) * side / 390
    context.saveGState()
    defer { context.restoreGState() }
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(color.cgColor)
    context.setFillColor(color.cgColor)
    if stroke.brush == .silk {
      context.setShadow(
        offset: .zero, blur: width * 2.8, color: color.withAlphaComponent(0.65).cgColor)
    }
    if stroke.brush == .stardust {
      var distance: CGFloat = .infinity
      var previous = points[0]
      for point in points {
        distance += hypot(point.x - previous.x, point.y - previous.y)
        if distance >= max(width * 3.2, side / 95) {
          context.fillEllipse(
            in: CGRect(x: point.x - width, y: point.y - width, width: width * 2, height: width * 2))
          distance = 0
        }
        previous = point
      }
    } else if points.count == 1 {
      context.fillEllipse(
        in: CGRect(
          x: points[0].x - width / 2, y: points[0].y - width / 2, width: width, height: width))
    } else {
      context.setLineWidth(width)
      context.beginPath()
      context.move(to: points[0])
      for point in points.dropFirst() { context.addLine(to: point) }
      context.strokePath()
    }
  }

  static func export(_ artwork: Artwork) throws -> URL {
    let image = image(strokes: artwork.strokes, size: 2048)
    guard let png = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
    let directory = URL.cachesDirectory.appending(path: "Exports").appending(
      path: artwork.id.uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let allowed = CharacterSet.alphanumerics.union(.whitespaces).union(
      CharacterSet(charactersIn: "-_"))
    let name = artwork.title.components(separatedBy: allowed.inverted)
      .joined(separator: " ").split(whereSeparator: \.isWhitespace).joined(separator: " ")
    let filename = name.isEmpty ? "Prismatic" : String(name.prefix(60))
    let url = directory.appending(path: "\(filename).png")
    try png.write(to: url, options: .atomic)
    return url
  }
}

struct DrawingSurface: UIViewRepresentable {
  var strokes: [ArtStroke]
  var settings: StudioSettings
  var onStroke: (ArtStroke) -> Void

  func makeUIView(context: Context) -> StrokeView {
    let view = StrokeView()
    view.backgroundColor = ArtRenderer.background
    view.isAccessibilityElement = true
    view.accessibilityLabel = "Symmetry canvas"
    view.accessibilityHint = "Draw with one finger. Your strokes repeat around the center."
    return view
  }

  func updateUIView(_ view: StrokeView, context: Context) {
    view.settings = settings
    view.onStroke = onStroke
    if view.strokes != strokes {
      view.strokes = strokes
      view.cachedImage = nil
    }
    view.accessibilityValue = "\(strokes.count) strokes, \(settings.symmetry) axes"
    view.setNeedsDisplay()
  }
}

final class StrokeView: UIView {
  var strokes: [ArtStroke] = []
  var settings = StudioSettings()
  var onStroke: ((ArtStroke) -> Void)?
  var cachedImage: UIImage?
  private var active: ArtStroke?
  private var previousSize = CGSize.zero

  override func layoutSubviews() {
    super.layoutSubviews()
    if previousSize != bounds.size {
      cachedImage = nil
      previousSize = bounds.size
    }
  }

  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    let side = bounds.width
    if cachedImage == nil {
      cachedImage = ArtRenderer.image(strokes: strokes, size: side * contentScaleFactor)
    }
    cachedImage?.draw(in: bounds)
    if settings.guides {
      context.saveGState()
      context.setStrokeColor(UIColor.white.withAlphaComponent(0.075).cgColor)
      context.setLineWidth(0.5)
      context.setLineDash(phase: 0, lengths: [2, 7])
      for axis in 0..<settings.symmetry {
        let angle = Double(axis) * 2 * .pi / Double(settings.symmetry)
        context.move(to: CGPoint(x: side / 2, y: side / 2))
        context.addLine(
          to: CGPoint(x: side / 2 + sin(angle) * side, y: side / 2 + cos(angle) * side))
      }
      context.strokePath()
      context.strokeEllipse(in: bounds.insetBy(dx: side * 0.1, dy: side * 0.1))
      context.restoreGState()
    }
    if let active { ArtRenderer.render([active], in: context, side: side, fill: false) }
  }

  private func append(_ touch: UITouch) {
    let location = touch.location(in: self)
    let point = ArtPoint(
      x: min(1, max(0, location.x / bounds.width)),
      y: min(1, max(0, location.y / bounds.height)))
    if let last = active?.points.last,
      hypot(last.x - point.x, last.y - point.y) < 0.001
    {
      return
    }
    active?.points.append(point)
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    active = ArtStroke(
      points: [], pigment: settings.pigment, brush: settings.brush, width: settings.width,
      symmetry: settings.symmetry, mirror: settings.mirror)
    append(touch)
    setNeedsDisplay()
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    for sample in event?.coalescedTouches(for: touch) ?? [touch] { append(sample) }
    setNeedsDisplay()
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    if let touch = touches.first { append(touch) }
    if let active { onStroke?(active) }
    active = nil
    setNeedsDisplay()
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    active = nil
    setNeedsDisplay()
  }
}

struct ArtThumbnail: View {
  var artwork: Artwork
  var body: some View {
    Image(uiImage: ArtRenderer.image(strokes: artwork.strokes, size: 600))
      .resizable().aspectRatio(contentMode: .fit)
      .accessibilityLabel("\(artwork.title), \(artwork.strokes.count) strokes")
  }
}
