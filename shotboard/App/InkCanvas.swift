import SwiftUI
import UIKit

enum Palette {
  static let background = Color(red: 0.075, green: 0.084, blue: 0.087)
  static let panel = Color(red: 0.105, green: 0.117, blue: 0.121)
  static let elevated = Color(red: 0.15, green: 0.163, blue: 0.163)
  static let yellow = Color(red: 0.93, green: 0.96, blue: 0.24)
  static let ivory = Color(red: 0.94, green: 0.92, blue: 0.85)
  static let muted = Color(red: 0.62, green: 0.66, blue: 0.65)
}

extension InkColor {
  var uiColor: UIColor {
    switch self {
    case .graphite: UIColor(red: 0.15, green: 0.20, blue: 0.20, alpha: 1)
    case .shadow: UIColor(red: 0.31, green: 0.38, blue: 0.37, alpha: 1)
    case .mist: UIColor(red: 0.72, green: 0.76, blue: 0.70, alpha: 1)
    case .yellow: UIColor(red: 0.83, green: 0.85, blue: 0.27, alpha: 1)
    case .ivory: UIColor(red: 0.94, green: 0.92, blue: 0.85, alpha: 1)
    }
  }
}

enum CompositionGuide: String, CaseIterable {
  case none = "No guides"
  case thirds = "Rule of thirds"
  case center = "Center cross"
}

enum InkRenderer {
  static func draw(_ strokes: [InkStroke], in rect: CGRect, context: CGContext) {
    context.saveGState()
    context.clip(to: rect)
    context.setFillColor(InkColor.ivory.uiColor.cgColor)
    context.fill(rect)
    for stroke in strokes {
      guard let first = stroke.points.first else { continue }
      context.beginPath()
      context.move(
        to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
      if stroke.points.count == 1 {
        let diameter = max(1, stroke.width * rect.width)
        context.setFillColor(stroke.color.uiColor.cgColor)
        context.fillEllipse(
          in: CGRect(
            x: rect.minX + first.x * rect.width - diameter / 2,
            y: rect.minY + first.y * rect.height - diameter / 2,
            width: diameter, height: diameter))
      } else {
        for point in stroke.points.dropFirst() {
          context.addLine(
            to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        context.setStrokeColor(stroke.color.uiColor.cgColor)
        context.setFillColor(stroke.color.uiColor.cgColor)
        context.setLineWidth(stroke.width * rect.width)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        if stroke.filled {
          context.closePath()
          context.fillPath()
        } else {
          context.strokePath()
        }
      }
    }
    context.restoreGState()
  }
}

final class DrawingSurface: UIView {
  var strokes: [InkStroke] = [] { didSet { setNeedsDisplay() } }
  var guide = CompositionGuide.none { didSet { setNeedsDisplay() } }
  var ink = InkColor.graphite
  var inkWidth = 0.004
  var onStroke: ((InkStroke) -> Void)?
  var current: InkStroke?
  var shotID: UUID?

  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    InkRenderer.draw(strokes + (current.map { [$0] } ?? []), in: bounds, context: context)
    if guide != .none {
      context.setStrokeColor(UIColor(red: 0.38, green: 0.46, blue: 0.2, alpha: 0.65).cgColor)
      context.setLineWidth(1)
      context.setLineDash(phase: 0, lengths: [6, 5])
      let positions: [CGFloat] = guide == .thirds ? [1 / 3, 2 / 3] : [0.5]
      for position in positions {
        context.move(to: CGPoint(x: bounds.width * position, y: 0))
        context.addLine(to: CGPoint(x: bounds.width * position, y: bounds.height))
        context.move(to: CGPoint(x: 0, y: bounds.height * position))
        context.addLine(to: CGPoint(x: bounds.width, y: bounds.height * position))
      }
      context.strokePath()
    }
  }

  func point(_ touch: UITouch) -> InkPoint {
    let location = touch.location(in: self)
    return InkPoint(
      x: min(max(location.x / bounds.width, 0), 1), y: min(max(location.y / bounds.height, 0), 1))
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    current = InkStroke(points: [point(touch)], color: ink, width: inkWidth)
    setNeedsDisplay()
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    for sample in event?.coalescedTouches(for: touch) ?? [touch] {
      current?.points.append(point(sample))
    }
    setNeedsDisplay()
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    if let touch = touches.first { current?.points.append(point(touch)) }
    if let current { onStroke?(current) }
    current = nil
    setNeedsDisplay()
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    current = nil
    setNeedsDisplay()
  }
}

struct InkCanvas: UIViewRepresentable {
  let shot: Shot
  var guide = CompositionGuide.none
  var ink = InkColor.graphite
  var width = 0.004
  var onStroke: ((InkStroke) -> Void)?

  func makeUIView(context: Context) -> DrawingSurface {
    let view = DrawingSurface()
    view.isOpaque = true
    view.accessibilityLabel = "Sketch frame"
    view.accessibilityIdentifier = "sketchCanvas"
    return view
  }

  func updateUIView(_ view: DrawingSurface, context: Context) {
    if view.shotID != shot.id { view.current = nil }
    view.shotID = shot.id
    view.strokes = shot.strokes
    view.guide = guide
    view.ink = ink
    view.inkWidth = width
    view.onStroke = onStroke
    view.isUserInteractionEnabled = onStroke != nil
  }
}

struct InkThumbnail: View {
  let shot: Shot

  var body: some View {
    let size = CGSize(width: 340, height: 170)
    let image = UIGraphicsImageRenderer(size: size).image { renderer in
      InkRenderer.draw(
        shot.strokes, in: CGRect(origin: .zero, size: size), context: renderer.cgContext)
    }
    Image(uiImage: image).resizable()
  }
}
