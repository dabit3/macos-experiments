import SwiftUI

enum Palette {
  static let ink = Color(red: 0.20, green: 0.22, blue: 0.20)
  static let muted = Color(red: 0.46, green: 0.46, blue: 0.41)
  static let paper = Color(red: 0.97, green: 0.96, blue: 0.92)
  static let oat = Color(red: 0.92, green: 0.89, blue: 0.82)
  static let clay = Color(red: 0.67, green: 0.32, blue: 0.23)
  static let line = Color(red: 0.83, green: 0.81, blue: 0.75)

  static func floor(_ material: FloorMaterial) -> Color {
    switch material {
    case .oak: Color(red: 0.77, green: 0.63, blue: 0.44)
    case .walnut: Color(red: 0.43, green: 0.29, blue: 0.19)
    case .limestone: Color(red: 0.77, green: 0.75, blue: 0.68)
    }
  }

  static func wall(_ material: WallMaterial) -> Color {
    switch material {
    case .chalk: Color(red: 0.91, green: 0.88, blue: 0.80)
    case .clay: Color(red: 0.73, green: 0.43, blue: 0.32)
    case .sage: Color(red: 0.55, green: 0.61, blue: 0.49)
    }
  }
}

struct PlanGeometry {
  let scale: Double
  let origin: CGPoint
  init(size: CGSize, room: Room) {
    scale = min((size.width - 94) / room.width, (size.height - 102) / room.depth)
    origin = CGPoint(
      x: (size.width - room.width * scale) / 2,
      y: (size.height - room.depth * scale) / 2 + 8)
  }
}

enum FurnitureDrawing {
  static func draw(_ kind: FurnitureKind, context: GraphicsContext, scale: Double) {
    var c = context
    c.scaleBy(x: scale, y: scale)
    let w = kind.width
    let d = kind.depth
    func box(
      _ x: Double, _ y: Double, _ width: Double, _ height: Double, _ color: Color,
      radius: Double = 0.04
    ) {
      let p = Path(
        roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: radius)
      c.fill(p, with: .color(color))
      c.stroke(p, with: .color(Palette.ink.opacity(0.65)), lineWidth: 0.012)
    }
    func ellipse(_ x: Double, _ y: Double, _ width: Double, _ height: Double, _ color: Color) {
      let p = Path(ellipseIn: CGRect(x: x, y: y, width: width, height: height))
      c.fill(p, with: .color(color))
      c.stroke(p, with: .color(Palette.ink.opacity(0.5)), lineWidth: 0.012)
    }
    let linen = Color(red: 0.84, green: 0.77, blue: 0.63)
    let wood = Color(red: 0.59, green: 0.39, blue: 0.24)
    c.translateBy(x: -w / 2, y: -d / 2)
    switch kind {
    case .sofa, .chair:
      box(0, 0, w, d, linen, radius: 0.12)
      box(0.1, 0.05, w - 0.2, 0.20, linen.opacity(0.9), radius: 0.07)
      let count = kind == .sofa ? 3 : 1
      let seatW = (w - 0.34) / Double(count)
      for i in 0..<count {
        box(0.17 + Double(i) * seatW, 0.29, seatW - 0.02, d - 0.39, Palette.paper, radius: 0.08)
      }
      box(0.025, 0.18, 0.12, d - 0.23, linen, radius: 0.05)
      box(w - 0.145, 0.18, 0.12, d - 0.23, linen, radius: 0.05)
      if kind == .sofa {
        box(0.3, 0.33, 0.3, 0.26, Palette.clay.opacity(0.75), radius: 0.07)
      }
    case .coffeeTable:
      box(0, 0, w, d, wood, radius: 0.25)
      box(0.25, 0.2, 0.25, 0.24, Palette.paper, radius: 0.01)
      ellipse(0.75, 0.2, 0.19, 0.19, Palette.oat)
    case .console:
      box(0, 0, w, d, wood)
      for i in 1..<18 {
        let x = Double(i) * 0.1
        var line = Path()
        line.move(to: CGPoint(x: x, y: 0.02))
        line.addLine(to: CGPoint(x: x, y: d - 0.02))
        c.stroke(line, with: .color(Palette.paper.opacity(0.35)), lineWidth: 0.01)
      }
    case .diningTable:
      box(0, 0, w, d, linen, radius: 0.22)
      for x in [0.3, 1.0] {
        ellipse(x, 0.18, 0.3, 0.3, Palette.paper)
      }
      ellipse(0.71, 0.55, 0.19, 0.19, Palette.clay)
    case .rug:
      box(0, 0, w, d, Color(red: 0.80, green: 0.68, blue: 0.57), radius: 0.03)
      box(0.1, 0.1, w - 0.2, d - 0.2, Palette.oat, radius: 0.01)
      for i in 0..<18 {
        let y = 0.2 + Double(i) * 0.1
        var line = Path()
        line.move(to: CGPoint(x: 0.15, y: y))
        line.addLine(to: CGPoint(x: w - 0.15, y: y))
        c.stroke(line, with: .color(Palette.muted.opacity(0.25)), lineWidth: 0.009)
      }
    case .plant:
      ellipse(0.1, 0.1, 0.4, 0.4, Palette.clay)
      for i in 0..<7 {
        let angle = Double(i) * .pi * 2 / 7
        ellipse(
          0.19 + cos(angle) * 0.13, 0.17 + sin(angle) * 0.14, 0.23, 0.27,
          Color(red: 0.33 + Double(i % 3) * 0.04, green: 0.44, blue: 0.28))
      }
    case .lamp:
      ellipse(0.03, 0.03, 0.44, 0.44, Palette.paper)
      ellipse(0.1, 0.1, 0.3, 0.3, Palette.oat)
      ellipse(0.22, 0.22, 0.06, 0.06, wood)
    }
  }
}

struct FurnitureGlyph: View {
  let kind: FurnitureKind
  var body: some View {
    Canvas { context, size in
      var c = context
      c.translateBy(x: size.width / 2, y: size.height / 2)
      FurnitureDrawing.draw(kind, context: c, scale: min(68 / kind.width, 48 / kind.depth))
    }
    .frame(width: 78, height: 56)
    .accessibilityHidden(true)
  }
}

struct PlanArtwork: View {
  let room: Room
  var selection: UUID?
  var grid = true
  var body: some View {
    Canvas { context, size in
      let geometry = PlanGeometry(size: size, room: room)
      let s = geometry.scale
      let o = geometry.origin
      if grid {
        for x in stride(from: 12.0, to: size.width, by: 18) {
          for y in stride(from: 12.0, to: size.height, by: 18) {
            context.fill(
              Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
              with: .color(Palette.line.opacity(0.55)))
          }
        }
      }
      let rect = CGRect(x: o.x, y: o.y, width: room.width * s, height: room.depth * s)
      context.fill(Path(rect), with: .color(Palette.floor(room.floor).opacity(0.12)))
      for x in stride(from: 0.0, to: room.width, by: room.floor == .limestone ? 0.6 : 0.22) {
        var p = Path()
        p.move(to: CGPoint(x: o.x + x * s, y: o.y))
        p.addLine(to: CGPoint(x: o.x + x * s, y: o.y + room.depth * s))
        context.stroke(p, with: .color(Palette.floor(room.floor).opacity(0.18)), lineWidth: 0.5)
      }
      context.stroke(Path(rect), with: .color(Palette.ink), lineWidth: 5)
      context.stroke(Path(rect.insetBy(dx: -5, dy: -5)), with: .color(Palette.line), lineWidth: 1)
      // A threshold and a window keep the room's orientation legible.
      let doorX = o.x + 0.65 * s
      context.stroke(
        Path(CGRect(x: doorX, y: rect.maxY - 2, width: 0.9 * s, height: 4)),
        with: .color(Palette.paper), lineWidth: 5)
      var door = Path()
      door.move(to: CGPoint(x: doorX, y: rect.maxY))
      door.addLine(to: CGPoint(x: doorX, y: rect.maxY - 0.9 * s))
      door.addArc(
        center: CGPoint(x: doorX, y: rect.maxY), radius: 0.9 * s,
        startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
      context.stroke(
        door, with: .color(Palette.muted), style: StrokeStyle(lineWidth: 0.8, dash: [3, 2]))
      context.stroke(
        Path(
          CGRect(
            x: o.x + room.width * s * 0.27, y: o.y - 2, width: room.width * s * 0.38, height: 4)),
        with: .color(Palette.paper), lineWidth: 2)
      for item in room.furniture.sorted(by: { $0.kind == .rug && $1.kind != .rug }) {
        var c = context
        c.translateBy(x: o.x + item.x * s, y: o.y + item.z * s)
        c.rotate(by: .degrees(Double(item.rotation)))
        FurnitureDrawing.draw(item.kind, context: c, scale: s)
        if selection == item.id {
          let bounds = CGRect(
            x: -item.kind.width * s / 2 - 5, y: -item.kind.depth * s / 2 - 5,
            width: item.kind.width * s + 10, height: item.kind.depth * s + 10)
          c.stroke(
            Path(roundedRect: bounds, cornerRadius: 5), with: .color(Palette.clay),
            style: StrokeStyle(lineWidth: 1.8, dash: [5, 3]))
          for point in [
            CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.maxY),
          ] {
            c.fill(
              Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
              with: .color(Palette.clay))
          }
        }
      }
      dimension(
        context, from: CGPoint(x: o.x, y: o.y - 25),
        to: CGPoint(x: rect.maxX, y: o.y - 25), label: String(format: "%.2f m", room.width))
      var vertical = context
      vertical.translateBy(x: o.x - 25, y: rect.maxY)
      vertical.rotate(by: .degrees(-90))
      dimension(
        vertical, from: .zero, to: CGPoint(x: room.depth * s, y: 0),
        label: String(format: "%.2f m", room.depth))
      context.draw(
        Text("N").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted),
        at: CGPoint(x: size.width - 20, y: size.height - 25))
      var north = Path()
      north.move(to: CGPoint(x: size.width - 20, y: size.height - 38))
      north.addLine(to: CGPoint(x: size.width - 20, y: size.height - 58))
      north.addLine(to: CGPoint(x: size.width - 24, y: size.height - 50))
      context.stroke(north, with: .color(Palette.muted), lineWidth: 1)
    }
    .background(Palette.paper)
  }

  private func dimension(_ c: GraphicsContext, from: CGPoint, to: CGPoint, label: String) {
    var p = Path()
    p.move(to: from)
    p.addLine(to: to)
    for point in [from, to] {
      p.move(to: CGPoint(x: point.x, y: point.y - 4))
      p.addLine(to: CGPoint(x: point.x, y: point.y + 4))
    }
    c.stroke(p, with: .color(Palette.muted.opacity(0.65)), lineWidth: 0.7)
    c.draw(
      Text(label).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(
        Palette.muted),
      at: CGPoint(x: (from.x + to.x) / 2, y: from.y - 10))
  }
}

struct InteractivePlan: View {
  @Bindable var store: StudioStore
  @State private var dragging: UUID?
  @State private var offset = CGSize.zero

  var body: some View {
    GeometryReader { proxy in
      PlanArtwork(room: store.room, selection: store.selection)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              let g = PlanGeometry(size: proxy.size, room: store.room)
              let x = (value.startLocation.x - g.origin.x) / g.scale
              let z = (value.startLocation.y - g.origin.y) / g.scale
              if dragging == nil {
                let items = store.room.furniture.sorted { $0.kind == .rug && $1.kind != .rug }
                if let item = items.reversed().first(where: {
                  abs($0.x - x) <= $0.footprintWidth / 2 + 0.05
                    && abs($0.z - z) <= $0.footprintDepth / 2 + 0.05
                }) {
                  dragging = item.id
                  store.selection = item.id
                  offset = CGSize(width: item.x - x, height: item.z - z)
                } else {
                  store.selection = nil
                }
              }
              if let dragging, value.translation != .zero {
                store.move(
                  dragging, x: (value.location.x - g.origin.x) / g.scale + offset.width,
                  z: (value.location.y - g.origin.y) / g.scale + offset.height, ended: false)
              }
            }
            .onEnded { value in
              if let dragging, value.translation != .zero {
                let g = PlanGeometry(size: proxy.size, room: store.room)
                store.move(
                  dragging, x: (value.location.x - g.origin.x) / g.scale + offset.width,
                  z: (value.location.y - g.origin.y) / g.scale + offset.height, ended: true)
              }
              dragging = nil
            }
        )
        .accessibilityLabel("Floor plan. Select or drag furniture to reposition it.")
        .accessibilityIdentifier("floorPlan")
    }
  }
}
