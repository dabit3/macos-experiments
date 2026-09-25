import AppKit
import LoomCore
import SwiftUI

extension Theme {
  var ink: NSColor {
    switch self {
    case .coral: return NSColor(srgbRed: 0.84, green: 0.24, blue: 0.15, alpha: 1)
    case .blue: return NSColor(srgbRed: 0.12, green: 0.32, blue: 0.76, alpha: 1)
    case .green: return NSColor(srgbRed: 0.08, green: 0.43, blue: 0.31, alpha: 1)
    }
  }
  var color: Color { Color(nsColor: ink) }
}

enum Graphic {
  static let size = NSSize(width: 1040, height: 740)
  static let paper = NSColor(srgbRed: 0.99, green: 0.981, blue: 0.955, alpha: 1)
  static let ink = NSColor(srgbRed: 0.10, green: 0.12, blue: 0.12, alpha: 1)
  static let muted = NSColor(srgbRed: 0.40, green: 0.43, blue: 0.42, alpha: 1)
  static let rule = NSColor(srgbRed: 0.84, green: 0.85, blue: 0.81, alpha: 1)

  static func number(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)).grouping(.automatic))
  }

  static func text(
    _ value: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat,
    weight: NSFont.Weight = .regular, color: NSColor = ink,
    align: NSTextAlignment = .left, height: CGFloat = 60, mono: Bool = false
  ) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    paragraph.lineBreakMode = .byTruncatingTail
    paragraph.lineSpacing = 2
    let font =
      mono
      ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
      : NSFont.systemFont(ofSize: size, weight: weight)
    (value as NSString).draw(
      in: NSRect(x: x, y: y, width: width, height: height),
      withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    )
  }

  static func line(_ start: NSPoint, _ end: NSPoint, color: NSColor = rule, width: CGFloat = 1) {
    color.setStroke()
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    path.lineWidth = width
    path.stroke()
  }

  static func rect(_ rect: NSRect, color: NSColor, radius: CGFloat = 0) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
  }

  @discardableResult
  static func draw(_ project: Project, selection: Int? = nil) -> [(NSRect, Datum)] {
    let result = DataEngine.compute(project)
    rect(NSRect(origin: .zero, size: size), color: paper)
    rect(NSRect(x: 44, y: 39, width: 24, height: 4), color: project.theme.ink)
    text(
      "LOOM   /   FIELD NOTES", x: 80, y: 32, width: 430, size: 11, weight: .semibold, mono: true)
    text(
      "DATA STORY    01", x: 770, y: 32, width: 226, size: 11, color: muted, align: .right,
      mono: true)
    text(
      project.title.isEmpty ? "Untitled story" : project.title, x: 44, y: 72, width: 710,
      size: 43, weight: .bold, height: 112)
    text(project.subtitle, x: 46, y: 187, width: 930, size: 15, color: muted, height: 40)
    line(NSPoint(x: 44, y: 240), NSPoint(x: 996, y: 240), color: ink)
    let mode =
      project.kind == .scatter ? "INDIVIDUAL ROWS" : project.aggregation.rawValue.uppercased()
    text(
      "\(mode)  /  \(project.dataset.columns[project.measure].uppercased())",
      x: 44, y: 253, width: 720, size: 10, weight: .medium, color: muted, mono: true)
    text(
      "\(result.matchedRows.count) OF \(project.dataset.rows.count) ROWS",
      x: 770, y: 253, width: 226, size: 10, color: muted, align: .right, mono: true)
    var hits: [(NSRect, Datum)] = []
    if let message = result.message {
      text(
        "A little room to explore.", x: 80, y: 365, width: 880, size: 27, weight: .semibold,
        align: .center)
      text(message, x: 100, y: 411, width: 840, size: 16, color: muted, align: .center)
    } else {
      switch project.kind {
      case .bar: hits = bars(project, result.points, selection)
      case .line, .scatter: hits = cartesian(project, result.points, selection)
      }
    }
    line(NSPoint(x: 44, y: 649), NSPoint(x: 996, y: 649))
    let filter =
      project.filterValue.isEmpty
      ? "ALL RECORDS"
      : "\(project.dataset.columns[project.filterColumn]) \(project.filterOperation.rawValue) \(project.filterValue)"
    text(filter.uppercased(), x: 44, y: 665, width: 600, size: 10, color: muted, mono: true)
    let limit = project.kind == .bar ? 16 : project.kind == .line ? 60 : 500
    let detail =
      result.points.count > limit
      ? "FIRST \(limit) OF \(result.points.count) MARKS"
      : "Σ \(number(result.total))   /   \(result.points.count) MARKS"
    text(detail, x: 665, y: 665, width: 330, size: 10, weight: .semibold, align: .right, mono: true)
    text(project.source, x: 44, y: 707, width: 880, size: 9, color: muted, mono: true)
    text("L / 01", x: 919, y: 703, width: 77, size: 13, weight: .bold, align: .right, mono: true)
    if result.excludedRows > 0 {
      text(
        "\(result.excludedRows) nonnumeric rows omitted", x: 44, y: 685, width: 700, size: 10,
        color: project.theme.ink)
    }
    return hits
  }

  private static func bars(_ project: Project, _ values: [Datum], _ selected: Int?) -> [(
    NSRect, Datum
  )] {
    let points = Array(values.prefix(16))
    let minValue = min(values.map(\.value).min() ?? 0, 0)
    let maxValue = max(values.map(\.value).max() ?? 1, 0)
    let span = max(maxValue - minValue, 1)
    let left: CGFloat = 216
    let width: CGFloat = 710
    let zero = left + CGFloat(-minValue / span) * width
    let rowHeight = min(42, 336 / CGFloat(max(points.count, 1)))
    let barHeight = rowHeight * 0.64
    var hits: [(NSRect, Datum)] = []
    for tick in 0...4 {
      let x = left + width * CGFloat(tick) / 4
      line(NSPoint(x: x, y: 290), NSPoint(x: x, y: 617))
      text(
        number(minValue + span * Double(tick) / 4), x: x - 35, y: 622, width: 70,
        size: 9, color: muted, align: .center, mono: true)
    }
    for (index, point) in points.enumerated() {
      let y = 290 + CGFloat(index) * rowHeight
      let endpoint = left + CGFloat((point.value - minValue) / span) * width
      let rect = NSRect(
        x: min(zero, endpoint), y: y + 3, width: max(abs(endpoint - zero), 2), height: barHeight)
      let color = project.theme.ink.withAlphaComponent(
        selected == nil || selected == point.id ? 1 : 0.25)
      Self.rect(rect, color: color, radius: 2)
      text(
        point.label.replacingOccurrences(of: "\n", with: " "), x: 44, y: y + 5, width: 156,
        size: min(14, rowHeight * 0.51), weight: selected == point.id ? .bold : .medium,
        height: rowHeight)
      if project.showValues {
        text(
          number(point.value), x: 939, y: y + 5, width: 58, size: min(14, rowHeight * 0.51),
          weight: .semibold, align: .right, height: rowHeight, mono: true)
      }
      hits.append((NSRect(x: 40, y: y, width: 962, height: rowHeight), point))
    }
    return hits
  }

  private static func cartesian(_ project: Project, _ values: [Datum], _ selected: Int?) -> [(
    NSRect, Datum
  )] {
    let scatter = project.kind == .scatter
    let points = Array(values.prefix(scatter ? 500 : 60))
    let plot = NSRect(x: 101, y: 297, width: 852, height: 281)
    let minY = min(0, points.map(\.value).min() ?? 0)
    let maxY = max(1, points.map(\.value).max() ?? 1)
    let minX = scatter ? min(0, points.map(\.x).min() ?? 0) : 0
    let maxX = scatter ? max(1, points.map(\.x).max() ?? 1) : Double(max(points.count - 1, 1))
    var positions: [NSPoint] = []
    for tick in 0...4 {
      let y = plot.maxY - plot.height * CGFloat(tick) / 4
      line(NSPoint(x: plot.minX, y: y), NSPoint(x: plot.maxX, y: y))
      text(
        number(minY + (maxY - minY) * Double(tick) / 4), x: 39, y: y - 7, width: 48,
        size: 10, color: muted, align: .right, mono: true)
    }
    for (index, point) in points.enumerated() {
      let xValue = scatter ? point.x : Double(index)
      let x = plot.minX + CGFloat((xValue - minX) / (maxX - minX)) * plot.width
      let y = plot.maxY - CGFloat((point.value - minY) / (maxY - minY)) * plot.height
      positions.append(NSPoint(x: x, y: y))
      if !scatter && (points.count <= 12 || index % max(1, points.count / 8) == 0) {
        text(
          point.label, x: x - 47, y: 590, width: 94, size: 10, color: muted, align: .center,
          height: 32)
      }
    }
    if scatter {
      for tick in 0...4 {
        let x = plot.minX + plot.width * CGFloat(tick) / 4
        text(
          number(minX + (maxX - minX) * Double(tick) / 4), x: x - 40, y: 590, width: 80,
          size: 10, color: muted, align: .center, mono: true)
      }
      text(
        project.dataset.columns[project.scatterX], x: 300, y: 619, width: 450, size: 10,
        color: muted, align: .center)
    } else if let first = positions.first, let last = positions.last {
      let fill = NSBezierPath()
      fill.move(to: NSPoint(x: first.x, y: plot.maxY))
      for position in positions { fill.line(to: position) }
      fill.line(to: NSPoint(x: last.x, y: plot.maxY))
      fill.close()
      project.theme.ink.withAlphaComponent(0.08).setFill()
      fill.fill()
      let path = NSBezierPath()
      path.move(to: first)
      for position in positions.dropFirst() { path.line(to: position) }
      path.lineWidth = 3
      path.lineJoinStyle = .round
      project.theme.ink.setStroke()
      path.stroke()
    }
    var hits: [(NSRect, Datum)] = []
    var labels: [NSRect] = []
    let markBounds = positions.map {
      NSRect(x: $0.x - 9, y: $0.y - 9, width: 18, height: 18)
    }
    for (point, position) in zip(points, positions) {
      let diameter: CGFloat = selected == point.id ? 15 : scatter ? 12 : 9
      let circle = NSRect(
        x: position.x - diameter / 2, y: position.y - diameter / 2, width: diameter,
        height: diameter)
      project.theme.ink.withAlphaComponent(selected == nil || selected == point.id ? 1 : 0.28)
        .setFill()
      NSBezierPath(ovalIn: circle).fill()
      paper.setStroke()
      let outline = NSBezierPath(ovalIn: circle)
      outline.lineWidth = 2
      outline.stroke()
      if (project.showValues && points.count <= 12) || selected == point.id {
        let candidates = [
          NSRect(x: position.x - 30, y: position.y - 25, width: 60, height: 16),
          NSRect(x: position.x - 30, y: position.y + 11, width: 60, height: 16),
          NSRect(x: position.x + 13, y: position.y - 8, width: 60, height: 16),
          NSRect(x: position.x - 73, y: position.y - 8, width: 60, height: 16),
        ]
        if let label = candidates.first(where: { candidate in
          candidate.minX >= 44 && candidate.maxX <= 996
            && candidate.minY >= 272 && candidate.maxY <= 584
            && !markBounds.contains(where: { $0.intersects(candidate) })
            && !labels.contains(where: { $0.intersects(candidate.insetBy(dx: -2, dy: -2)) })
        }) {
          labels.append(label)
          text(
            number(point.value), x: label.minX, y: label.minY, width: label.width,
            size: 11, weight: .semibold, align: .center, height: label.height, mono: true)
        }
      }
      hits.append((circle.insetBy(dx: -10, dy: -10), point))
    }
    return hits
  }
}

final class ChartNSView: NSView {
  var project: Project
  var hovered: Int?
  var hits: [(NSRect, Datum)] = []
  var onHover: ((Datum?) -> Void)?
  var exportMode = false
  override var isFlipped: Bool { true }

  init(project: Project) {
    self.project = project
    super.init(frame: NSRect(origin: .zero, size: Graphic.size))
    setAccessibilityElement(true)
    setAccessibilityLabel("Editorial chart. Hover a mark to inspect its computed value.")
    setAccessibilityRole(.image)
  }

  required init?(coder: NSCoder) { nil }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    for area in trackingAreas { removeTrackingArea(area) }
    if !exportMode {
      addTrackingArea(
        NSTrackingArea(
          rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow],
          owner: self))
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    context.saveGState()
    context.scaleBy(x: bounds.width / Graphic.size.width, y: bounds.height / Graphic.size.height)
    hits = Graphic.draw(project, selection: exportMode ? nil : hovered)
    context.restoreGState()
  }

  override func mouseMoved(with event: NSEvent) {
    let raw = convert(event.locationInWindow, from: nil)
    let point = NSPoint(
      x: raw.x * Graphic.size.width / bounds.width, y: raw.y * Graphic.size.height / bounds.height)
    let hit = hits.last(where: { $0.0.contains(point) })?.1
    if hovered != hit?.id {
      hovered = hit?.id
      toolTip = hit.map { "\($0.label): \(Graphic.number($0.value)) • \($0.rowCount) source rows" }
      onHover?(hit)
      needsDisplay = true
    }
  }

  override func mouseExited(with event: NSEvent) {
    hovered = nil
    onHover?(nil)
    needsDisplay = true
  }
}

struct ChartCanvas: NSViewRepresentable {
  var project: Project
  var onHover: (Datum?) -> Void

  func makeNSView(context: Context) -> ChartNSView {
    let view = ChartNSView(project: project)
    view.onHover = onHover
    return view
  }
  func updateNSView(_ view: ChartNSView, context: Context) {
    if view.project != project { view.hovered = nil }
    view.project = project
    view.onHover = onHover
    view.needsDisplay = true
  }
}

enum Exporter {
  static func pdf(_ project: Project) -> Data {
    let view = ChartNSView(project: project)
    view.exportMode = true
    return view.dataWithPDF(inside: view.bounds)
  }

  static func png(_ project: Project) throws -> Data {
    let width = Int(Graphic.size.width * 2)
    let height = Int(Graphic.size.height * 2)
    guard
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
      ), let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else {
      throw LoomError.invalid("Could not allocate the export image.")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context.cgContext, flipped: true)
    context.cgContext.translateBy(x: 0, y: CGFloat(height))
    context.cgContext.scaleBy(x: 2, y: -2)
    Graphic.draw(project)
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
      throw LoomError.invalid("Could not encode the export image.")
    }
    return data
  }
}
