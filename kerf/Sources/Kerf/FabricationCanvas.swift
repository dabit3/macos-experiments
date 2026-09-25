import AppKit
import KerfCore
import SwiftUI

struct FabricationCanvas: NSViewRepresentable {
  @ObservedObject var editor: Editor
  func makeNSView(context: Context) -> SheetView { SheetView(editor: editor) }
  func updateNSView(_ view: SheetView, context: Context) {
    if view.lastTool != editor.tool {
      view.polyline.removeAll()
      view.lastTool = editor.tool
    }
    if editor.zoom == 1 && view.lastZoom != 1 { view.pan = .zero }
    view.lastZoom = editor.zoom
    view.needsDisplay = true
  }
}

@MainActor final class SheetView: NSView {
  let editor: Editor
  var lastTool: EditorTool = .select
  var lastZoom: Double = 1
  var pan = CGPoint.zero
  var start: Point?
  var original: Part?
  var resizing = false
  var draft: Part?
  var polyline: [Point] = []
  var pointer: Point?
  let blue = NSColor(red: 0.18, green: 0.40, blue: 0.56, alpha: 1)
  let amber = NSColor(red: 0.81, green: 0.43, blue: 0.10, alpha: 1)
  let ink = NSColor(red: 0.22, green: 0.30, blue: 0.32, alpha: 1)
  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { true }
  var scale: Double {
    min(
      (bounds.width - 112) / editor.design.sheetWidth,
      (bounds.height - 132) / editor.design.sheetHeight) * editor.zoom
  }
  var origin: CGPoint {
    CGPoint(
      x: (bounds.width - editor.design.sheetWidth * scale) / 2 + pan.x,
      y: (bounds.height - editor.design.sheetHeight * scale) / 2 + pan.y - 3)
  }
  var sheet: CGRect {
    CGRect(
      x: origin.x, y: origin.y, width: editor.design.sheetWidth * scale,
      height: editor.design.sheetHeight * scale)
  }

  init(editor: Editor) {
    self.editor = editor
    super.init(frame: .zero)
    setAccessibilityElement(true)
    setAccessibilityRole(.group)
    setAccessibilityLabel("Fabrication canvas. Select and drag parts. Arrow keys nudge selection.")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    trackingAreas.forEach(removeTrackingArea)
    addTrackingArea(
      NSTrackingArea(
        rect: bounds, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self))
  }
  func screen(_ p: Point) -> CGPoint {
    CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale)
  }
  func world(_ p: CGPoint) -> Point { Point((p.x - origin.x) / scale, (p.y - origin.y) / scale) }
  func snap(_ p: Point) -> Point { Point(editor.snapped(p.x), editor.snapped(p.y)) }
  func rect(_ part: Part) -> CGRect {
    CGRect(
      x: origin.x + part.x * scale, y: origin.y + part.y * scale, width: part.width * scale,
      height: part.height * scale)
  }
  func shapePath(_ part: Part) -> NSBezierPath {
    switch part.kind {
    case .rectangle: return NSBezierPath(rect: rect(part))
    case .circle: return NSBezierPath(ovalIn: rect(part))
    case .polyline:
      let path = NSBezierPath()
      for (i, p) in part.vertices.enumerated() {
        if i == 0 { path.move(to: screen(p)) } else { path.line(to: screen(p)) }
      }
      return path
    }
  }
  func line(_ a: CGPoint, _ b: CGPoint, color: NSColor, width: CGFloat = 1, dash: [CGFloat] = []) {
    let path = NSBezierPath()
    path.move(to: a)
    path.line(to: b)
    path.lineWidth = width
    if !dash.isEmpty { path.setLineDash(dash, count: dash.count, phase: 0) }
    color.setStroke()
    path.stroke()
  }
  func text(
    _ string: String, at point: CGPoint, size: CGFloat = 10, color: NSColor? = nil,
    mono: Bool = false, weight: NSFont.Weight = .regular
  ) {
    let font =
      mono
      ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
      : NSFont.systemFont(ofSize: size, weight: weight)
    (string as NSString).draw(
      at: point, withAttributes: [.font: font, .foregroundColor: color ?? ink])
  }

  override func draw(_ dirtyRect: NSRect) {
    NSColor(red: 0.91, green: 0.91, blue: 0.87, alpha: 1).setFill()
    bounds.fill()
    guard scale > 0 else { return }
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.10)
    shadow.shadowBlurRadius = 22
    shadow.shadowOffset = NSSize(width: 0, height: -5)
    shadow.set()
    NSColor(red: 0.978, green: 0.969, blue: 0.937, alpha: 1).setFill()
    sheet.fill()
    NSGraphicsContext.restoreGraphicsState()

    if editor.preview {
      drawMaterial()
    } else {
      let path = NSBezierPath()
      for x in stride(from: 0.0, through: editor.design.sheetWidth, by: 5) {
        for y in stride(from: 0.0, through: editor.design.sheetHeight, by: 5) {
          let p = screen(Point(x, y))
          path.appendOval(in: CGRect(x: p.x - 0.6, y: p.y - 0.6, width: 1.2, height: 1.2))
        }
      }
      blue.withAlphaComponent(0.18).setFill()
      path.fill()
    }
    NSColor(red: 0.67, green: 0.70, blue: 0.65, alpha: 0.6).setStroke()
    let border = NSBezierPath(rect: sheet)
    border.lineWidth = 0.8
    border.stroke()
    drawRulers()
    text(
      "SHEET 01", at: CGPoint(x: sheet.minX, y: sheet.minY - 45), size: 9, mono: true,
      weight: .semibold)
    text(
      "\(editor.design.material.uppercased())  /  3 MM",
      at: CGPoint(x: sheet.maxX - 174, y: sheet.minY - 45), size: 8,
      color: ink.withAlphaComponent(0.7), mono: true)

    let issues = editor.overlaps.union(editor.design.outOfBounds)
    for p in editor.design.parts.sorted(by: { $0.operation == .cut && $1.operation == .engrave }) {
      drawPart(p, issue: issues.contains(p.id))
    }
    if let draft { drawPart(draft, issue: false) }
    if !polyline.isEmpty {
      let path = NSBezierPath()
      for (i, p) in polyline.enumerated() {
        let point = screen(p)
        if i == 0 { path.move(to: point) } else { path.line(to: point) }
        NSBezierPath(ovalIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)).fill()
      }
      if let pointer { path.line(to: screen(pointer)) }
      blue.setStroke()
      path.lineWidth = 1.5
      path.stroke()
    }
    if let part = editor.part { drawSelection(part) }
    text("0,0", at: CGPoint(x: sheet.minX - 25, y: sheet.minY - 18), size: 8, mono: true)
    let bottomY = sheet.maxY + 17
    text("CUT  ━", at: CGPoint(x: sheet.minX, y: bottomY), size: 8, color: blue, mono: true)
    text(
      "ENGRAVE  ┄", at: CGPoint(x: sheet.minX + 73, y: bottomY), size: 8,
      color: blue.withAlphaComponent(0.65), mono: true)
    text(
      "\(Int(editor.design.sheetWidth)) × \(Int(editor.design.sheetHeight)) MM",
      at: CGPoint(x: sheet.maxX - 110, y: bottomY), size: 8, mono: true)
  }

  func drawMaterial() {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(rect: sheet).addClip()
    let acrylic = editor.design.material == "Frosted acrylic"
    let base =
      acrylic
      ? NSColor(red: 0.81, green: 0.89, blue: 0.88, alpha: 1)
      : NSColor(red: 0.87, green: 0.75, blue: 0.55, alpha: 1)
    base.setFill()
    sheet.fill()
    for i in 0..<190 {
      let path = NSBezierPath()
      let y = sheet.minY + Double(i) * sheet.height / 190
      path.move(to: CGPoint(x: sheet.minX, y: y))
      path.curve(
        to: CGPoint(x: sheet.maxX, y: y + sin(Double(i) * 0.35) * 12),
        controlPoint1: CGPoint(x: sheet.minX + sheet.width * 0.3, y: y - 9),
        controlPoint2: CGPoint(
          x: sheet.minX + sheet.width * 0.72, y: y + sin(Double(i) * 0.22) * 18))
      (acrylic
        ? NSColor.white.withAlphaComponent(0.06)
        : NSColor.brown.withAlphaComponent(i.isMultiple(of: 3) ? 0.11 : 0.045)).setStroke()
      path.lineWidth = i.isMultiple(of: 4) ? 1 : 0.5
      path.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
  }

  func drawRulers() {
    let tickColor = ink.withAlphaComponent(0.3)
    for x in stride(from: 0.0, through: editor.design.sheetWidth, by: 10) {
      let p = screen(Point(x, 0))
      let major = Int(x).isMultiple(of: 50)
      line(
        CGPoint(x: p.x, y: sheet.minY - 2), CGPoint(x: p.x, y: sheet.minY - (major ? 9 : 5)),
        color: tickColor)
      if major && x > 0 {
        text(
          "\(Int(x))", at: CGPoint(x: p.x - 8, y: sheet.minY - 22), size: 8,
          color: ink.withAlphaComponent(0.7), mono: true)
      }
    }
    for y in stride(from: 0.0, through: editor.design.sheetHeight, by: 10) {
      let p = screen(Point(0, y))
      let major = Int(y).isMultiple(of: 50)
      line(
        CGPoint(x: sheet.minX - 2, y: p.y), CGPoint(x: sheet.minX - (major ? 9 : 5), y: p.y),
        color: tickColor)
      if major && y > 0 {
        text(
          "\(Int(y))", at: CGPoint(x: sheet.minX - 32, y: p.y - 5), size: 8,
          color: ink.withAlphaComponent(0.7), mono: true)
      }
    }
  }

  func drawPart(_ p: Part, issue: Bool) {
    let path = shapePath(p)
    let selected = p.id == editor.selected
    let cut = p.operation == .cut
    let color =
      issue ? NSColor(red: 0.8, green: 0.28, blue: 0.16, alpha: 1) : selected ? amber : blue
    if cut && p.kind != .polyline {
      if !editor.preview {
        color.withAlphaComponent(selected ? 0.055 : 0.023).setFill()
        path.fill()
      }
      if editor.preview {
        NSColor.white.withAlphaComponent(0.13).setFill()
        path.fill()
      }
    }
    (editor.preview
      ? (selected ? amber : NSColor(red: 0.31, green: 0.28, blue: 0.21, alpha: cut ? 0.9 : 0.65))
      : color.withAlphaComponent(cut ? 1 : 0.68)).setStroke()
    path.lineWidth = selected ? 1.8 : cut ? 1.25 : 1
    if !cut && !editor.preview { path.setLineDash([3, 2], count: 2, phase: 0) }
    path.stroke()
    if cut {
      let r = rect(p)
      let name = p.name.components(separatedBy: " / ").last ?? p.name
      if r.width > 65 {
        text(
          name.uppercased(), at: CGPoint(x: r.minX + 4, y: r.maxY + 8), size: 7,
          color: color.withAlphaComponent(0.75), mono: true)
      }
      if issue {
        text("!", at: CGPoint(x: r.maxX + 5, y: r.minY), size: 13, color: .systemRed, weight: .bold)
      }
    }
  }

  func drawSelection(_ p: Part) {
    let r = rect(p)
    let box = NSBezierPath(rect: r.insetBy(dx: -5, dy: -5))
    amber.withAlphaComponent(0.5).setStroke()
    box.lineWidth = 0.7
    box.setLineDash([3, 3], count: 2, phase: 0)
    box.stroke()
    for corner in [
      CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.minX, y: r.maxY),
      CGPoint(x: r.maxX, y: r.maxY),
    ] {
      let handle = NSBezierPath(rect: CGRect(x: corner.x - 3, y: corner.y - 3, width: 6, height: 6))
      NSColor.white.setFill()
      handle.fill()
      amber.setStroke()
      handle.lineWidth = 1
      handle.stroke()
    }
    let resize = NSBezierPath(
      roundedRect: CGRect(x: r.maxX - 5, y: r.maxY - 5, width: 10, height: 10), xRadius: 2,
      yRadius: 2)
    amber.setFill()
    resize.fill()
    let y = r.minY - 16
    line(CGPoint(x: r.minX, y: y), CGPoint(x: r.maxX, y: y), color: amber, width: 0.75)
    for x in [r.minX, r.maxX] {
      line(CGPoint(x: x - 3, y: y + 3), CGPoint(x: x + 3, y: y - 3), color: amber)
    }
    let label =
      "\(p.kind == .circle ? "Ø " : "")\(p.width.formatted(.number.precision(.fractionLength(0...1)))) mm"
    let width = Double(label.count) * 6.3 + 12
    let pill = CGRect(x: r.midX - width / 2, y: y - 8, width: width, height: 17)
    NSColor(red: 0.98, green: 0.95, blue: 0.87, alpha: 1).setFill()
    NSBezierPath(roundedRect: pill, xRadius: 4, yRadius: 4).fill()
    text(
      label, at: CGPoint(x: pill.minX + 6, y: pill.minY + 3), size: 9, color: amber, mono: true,
      weight: .medium)
    if p.kind == .rectangle {
      let x = r.maxX + 15
      line(CGPoint(x: x, y: r.minY), CGPoint(x: x, y: r.maxY), color: amber, width: 0.75)
      text(
        "\(p.height.formatted(.number.precision(.fractionLength(0...1))))",
        at: CGPoint(x: x + 4, y: r.midY - 5), size: 9, color: amber, mono: true)
    }
  }

  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    let local = convert(event.locationInWindow, from: nil)
    let point = world(local)
    if editor.tool == .polyline {
      if event.clickCount == 2 {
        finishPolyline()
        return
      }
      polyline.append(snap(point))
      needsDisplay = true
      return
    }
    if editor.tool != .select {
      start = snap(point)
      return
    }
    if let p = editor.part {
      let r = rect(p)
      if hypot(local.x - r.maxX, local.y - r.maxY) < 12 {
        resizing = true
        original = p
        start = point
        editor.beginDrag()
        return
      }
    }
    let selected = editor.design.parts.reversed().first { part in
      guard part.contains(point, tolerance: 3 / scale) else { return false }
      if part.operation == .engrave && part.kind != .polyline {
        if part.kind == .circle {
          return abs(
            hypot(point.x - part.x - part.width / 2, point.y - part.y - part.height / 2) - part
              .width / 2) < 4 / scale
        }
        return min(
          abs(point.x - part.x), abs(point.x - part.x - part.width), abs(point.y - part.y),
          abs(point.y - part.y - part.height)) < 4 / scale
      }
      return true
    }
    editor.selected = selected?.id
    if let selected {
      start = point
      original = selected
      editor.beginDrag()
    }
    needsDisplay = true
  }

  override func mouseDragged(with event: NSEvent) {
    guard let start else { return }
    let point = world(convert(event.locationInWindow, from: nil))
    if editor.tool != .select {
      let end = snap(point)
      let dx = end.x - start.x
      let dy = end.y - start.y
      let circle = editor.tool == .circle
      let width = max(0.1, abs(dx))
      let height = circle ? width : max(0.1, abs(dy))
      draft = Part(
        name: circle ? "Drawn coaster" : "Drawn panel", kind: circle ? .circle : .rectangle,
        x: dx < 0 ? start.x - width : start.x, y: dy < 0 ? start.y - height : start.y, width: width,
        height: height)
    } else if let original, let i = editor.design.parts.firstIndex(where: { $0.id == original.id })
    {
      if resizing {
        let width = max(0.1, editor.snapped(original.width + point.x - start.x))
        let height =
          original.kind == .circle
          ? width : max(0.1, editor.snapped(original.height + point.y - start.y))
        editor.design.parts[i].width = min(2000, width)
        editor.design.parts[i].height = min(2000, height)
      } else {
        editor.design.parts[i].x = editor.snapped(original.x + point.x - start.x)
        editor.design.parts[i].y = editor.snapped(original.y + point.y - start.y)
      }
    }
    needsDisplay = true
  }

  override func mouseUp(with event: NSEvent) {
    if let draft, draft.width >= 1, draft.height >= 1 {
      editor.commit(
        { $0.parts.append(draft) },
        message: "Created \(draft.kind.rawValue) · \(Int(draft.width)) mm")
      editor.selected = draft.id
      editor.tool = .select
    }
    editor.endDrag()
    start = nil
    original = nil
    resizing = false
    draft = nil
    needsDisplay = true
  }

  override func mouseMoved(with event: NSEvent) {
    if editor.tool == .polyline {
      pointer = snap(world(convert(event.locationInWindow, from: nil)))
      needsDisplay = true
    }
  }

  func finishPolyline() {
    guard polyline.count >= 2 else { return }
    let minX = polyline.map(\.x).min() ?? 0
    let minY = polyline.map(\.y).min() ?? 0
    let width = max(0.1, (polyline.map(\.x).max() ?? 0) - minX)
    let height = max(0.1, (polyline.map(\.y).max() ?? 0) - minY)
    let p = Part(
      name: "Drawn path", kind: .polyline, operation: .engrave, x: minX, y: minY, width: width,
      height: height,
      points: polyline.map { Point(($0.x - minX) / width, ($0.y - minY) / height) })
    editor.commit({ $0.parts.append(p) }, message: "Polyline created · \(polyline.count) vertices")
    editor.selected = p.id
    editor.tool = .select
    polyline.removeAll()
    needsDisplay = true
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      polyline.removeAll()
      draft = nil
      if let original = editor.dragOriginal {
        editor.design = original
        editor.dragOriginal = nil
      }
      start = nil
      editor.tool = .select
      needsDisplay = true
      return
    }
    if event.keyCode == 36 && editor.tool == .polyline {
      finishPolyline()
      return
    }
    let step = event.modifierFlags.contains(.shift) ? 10.0 : editor.snap ? 5.0 : 1.0
    switch event.keyCode {
    case 123: editor.moveSelected(dx: -step, dy: 0)
    case 124: editor.moveSelected(dx: step, dy: 0)
    case 125: editor.moveSelected(dx: 0, dy: step)
    case 126: editor.moveSelected(dx: 0, dy: -step)
    case 51, 117: editor.delete()
    default: super.keyDown(with: event)
    }
  }

  override func scrollWheel(with event: NSEvent) {
    pan.x -= event.scrollingDeltaX
    pan.y -= event.scrollingDeltaY
    needsDisplay = true
  }
}
