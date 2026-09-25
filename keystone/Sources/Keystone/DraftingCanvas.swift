import KeystoneCore
import SwiftUI

struct DraftingTransform {
  let scale: Double
  let origin: CGPoint
  init(size: CGSize, design: Design) {
    let minX = min(0, design.nodes.map(\.x).min() ?? 0)
    let maxX = max(12, design.nodes.map(\.x).max() ?? 12)
    let minY = min(0, design.nodes.map(\.y).min() ?? 0)
    let maxY = max(4, design.nodes.map(\.y).max() ?? 4)
    scale = max(1, min((size.width - 100) / (maxX - minX), (size.height - 250) / (maxY - minY)))
    origin = CGPoint(
      x: (size.width - (maxX - minX) * scale) / 2 - minX * scale,
      y: (size.height + (maxY - minY) * scale) / 2 + minY * scale + 15)
  }
  func screen(_ x: Double, _ y: Double) -> CGPoint {
    CGPoint(x: origin.x + x * scale, y: origin.y - y * scale)
  }
  func screen(_ node: Node) -> CGPoint { screen(node.x, node.y) }
  func world(_ point: CGPoint) -> SIMD2<Double> {
    SIMD2(
      min(24, max(-6, ((point.x - origin.x) / scale * 2).rounded() / 2)),
      min(12, max(-3, ((origin.y - point.y) / scale * 2).rounded() / 2)))
  }
}

struct DraftingCanvas: View {
  @EnvironmentObject var studio: Studio
  @State private var dragging: Int?
  @State private var dragPosition: SIMD2<Double>?
  @State private var didMove = false

  var body: some View {
    GeometryReader { geometry in
      let transform = DraftingTransform(size: geometry.size, design: studio.design)
      Canvas { context, size in
        drawBackground(&context, size: size, transform: transform)
        drawBridge(&context, transform: transform)
        drawDimensions(&context, transform: transform)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            guard studio.tool == .select else { return }
            if dragging == nil, !didMove {
              dragging = nearestNode(value.startLocation, transform: transform)
            }
            if let dragging, hypot(value.translation.width, value.translation.height) > 4 {
              didMove = true
              dragPosition = transform.world(value.location)
              studio.selection = .node(dragging)
            }
          }
          .onEnded { value in
            if didMove, let dragging, let position = dragPosition {
              let occupied = studio.design.nodes.contains {
                $0.id != dragging && hypot($0.x - position.x, $0.y - position.y) < 0.1
              }
              if occupied {
                studio.notice = "Nodes cannot overlap · move cancelled"
              } else {
                studio.setNode(dragging) {
                  $0.x = position.x
                  $0.y = position.y
                }
                studio.notice = "Node moved · snapped to 0.5 m grid"
              }
            } else {
              studio.canvasClick(
                node: nearestNode(value.location, transform: transform),
                member: nearestMember(value.location, transform: transform),
                position: transform.world(value.location))
            }
            dragging = nil
            dragPosition = nil
            didMove = false
          }
      )
      .accessibilityLabel("Bridge drafting canvas")
      .accessibilityHint(
        "Use Select to move nodes or inspect members. Coordinates snap to half meters.")
    }
  }

  private func point(_ node: Node, transform: DraftingTransform, deform: Bool = true) -> CGPoint {
    if node.id == dragging, let dragPosition {
      return transform.screen(dragPosition.x, dragPosition.y)
    }
    if deform, studio.mode == .deflection, let d = studio.result?.displacement[node.id] {
      return transform.screen(node.x + d.x * 100, node.y + d.y * 100)
    }
    return transform.screen(node)
  }

  private func nearestNode(_ point: CGPoint, transform: DraftingTransform) -> Int? {
    studio.design.nodes.first {
      let p = self.point($0, transform: transform)
      return hypot(p.x - point.x, p.y - point.y) < 15
    }?.id
  }

  private func nearestMember(_ p: CGPoint, transform: DraftingTransform) -> Int? {
    studio.design.members.min {
      distance($0, p: p, transform: transform) < distance($1, p: p, transform: transform)
    }
    .flatMap { distance($0, p: p, transform: transform) < 12 ? $0.id : nil }
  }

  private func distance(_ member: Member, p: CGPoint, transform: DraftingTransform) -> Double {
    guard let na = studio.design.node(member.a), let nb = studio.design.node(member.b) else {
      return .infinity
    }
    let a = point(na, transform: transform)
    let b = point(nb, transform: transform)
    let dx = b.x - a.x
    let dy = b.y - a.y
    let lengthSquared = dx * dx + dy * dy
    guard lengthSquared > 0 else { return .infinity }
    let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
    return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
  }

  private func line(
    _ context: inout GraphicsContext, _ a: CGPoint, _ b: CGPoint, color: Color, width: Double = 1,
    dash: [CGFloat] = []
  ) {
    var path = Path()
    path.move(to: a)
    path.addLine(to: b)
    context.stroke(
      path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash))
  }

  private func text(
    _ context: inout GraphicsContext, _ string: String, at: CGPoint, size: Double = 10,
    color: Color = Ink.muted, anchor: UnitPoint = .center
  ) {
    context.draw(
      Text(string).font(.system(size: size, weight: .medium, design: .monospaced)).foregroundColor(
        color), at: at, anchor: anchor)
  }

  private func drawBackground(
    _ context: inout GraphicsContext, size: CGSize, transform: DraftingTransform
  ) {
    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Ink.paper))
    if studio.showGrid {
      let step = transform.scale * 0.5
      let xStart = transform.origin.x.truncatingRemainder(dividingBy: step)
      let yStart = transform.origin.y.truncatingRemainder(dividingBy: step)
      for x in stride(from: xStart, through: size.width, by: step) {
        for y in stride(from: yStart, through: size.height, by: step) {
          context.fill(
            Path(ellipseIn: CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1)),
            with: .color(Ink.muted.opacity(0.23)))
        }
      }
    }
    let left = transform.screen(0, 0)
    let right = transform.screen(12, 0)
    let water = CGRect(
      x: left.x + 24, y: left.y + 27, width: max(1, right.x - left.x - 48), height: 34)
    context.fill(Path(water), with: .color(Ink.blue.opacity(0.04)))
    for i in 0..<3 {
      var wave = Path()
      let y = water.minY + Double(i) * 12 + 5
      wave.move(to: CGPoint(x: water.minX, y: y))
      wave.addCurve(
        to: CGPoint(x: water.maxX, y: y - 2),
        control1: CGPoint(x: water.minX + water.width / 3, y: y + 8),
        control2: CGPoint(x: water.minX + water.width * 2 / 3, y: y - 8))
      context.stroke(wave, with: .color(Ink.blue.opacity(0.12)), lineWidth: 0.6)
    }
  }

  private func drawBridge(_ context: inout GraphicsContext, transform: DraftingTransform) {
    for member in studio.design.members {
      guard let a = studio.design.node(member.a), let b = studio.design.node(member.b) else {
        continue
      }
      let pa = point(a, transform: transform)
      let pb = point(b, transform: transform)
      let selected = studio.selection == .member(member.id)
      var color = selected ? Ink.copper : Ink.navy
      let result = studio.result?.members[member.id]
      if studio.mode != .geometry, let result {
        color =
          abs(result.forceKN) < 0.001
          ? Ink.muted.opacity(0.4) : (result.forceKN < 0 ? Ink.blue : Ink.copper)
        color = color.opacity(0.45 + min(1, result.utilization * 2) * 0.55)
      }
      if studio.mode == .deflection, studio.result != nil {
        line(
          &context, transform.screen(a), transform.screen(b), color: Ink.muted.opacity(0.5),
          dash: [4, 4])
      }
      let width = 3 + sqrt(member.areaCM2) * 0.35
      if selected {
        line(&context, pa, pb, color: Ink.copper.opacity(0.16), width: width + 11)
      }
      line(&context, pa, pb, color: color, width: width)
      if studio.showLabels {
        var labelContext = context
        let mid = CGPoint(x: (pa.x + pb.x) / 2, y: (pa.y + pb.y) / 2)
        var angle = atan2(pb.y - pa.y, pb.x - pa.x)
        if angle > .pi / 2 { angle -= .pi }
        if angle < -.pi / 2 { angle += .pi }
        labelContext.translateBy(x: mid.x, y: mid.y)
        labelContext.rotate(by: .radians(angle))
        let label: String
        if studio.mode != .geometry, let result {
          label = String(format: "%+.1f", result.stressMPa)
        } else {
          label = "M\(member.id + 1)"
        }
        text(
          &labelContext, label, at: CGPoint(x: 0, y: -12), size: 9,
          color: selected ? Ink.copper : Ink.muted)
      }
    }
    for node in studio.design.nodes {
      let p = point(node, transform: transform)
      let selected = studio.selection == .node(node.id) || studio.startNode == node.id
      if node.support != .free {
        let supportP = transform.screen(node)
        var triangle = Path()
        triangle.move(to: CGPoint(x: supportP.x, y: supportP.y + 8))
        triangle.addLine(to: CGPoint(x: supportP.x - 12, y: supportP.y + 28))
        triangle.addLine(to: CGPoint(x: supportP.x + 12, y: supportP.y + 28))
        triangle.closeSubpath()
        context.fill(triangle, with: .color(Ink.navy))
        let baseY = supportP.y + (node.support == .roller ? 37 : 32)
        if node.support == .roller {
          for dx in [-7.0, 7.0] {
            context.stroke(
              Path(
                ellipseIn: CGRect(x: supportP.x + dx - 2, y: supportP.y + 30, width: 4, height: 4)),
              with: .color(Ink.navy), lineWidth: 1)
          }
        }
        line(
          &context, CGPoint(x: supportP.x - 20, y: baseY), CGPoint(x: supportP.x + 20, y: baseY),
          color: Ink.navy)
        for dx in stride(from: -18.0, through: 18, by: 6) {
          line(
            &context, CGPoint(x: supportP.x + dx, y: baseY + 1),
            CGPoint(x: supportP.x + dx - 4, y: baseY + 6), color: Ink.muted, width: 0.7)
        }
      }
      if selected {
        context.fill(
          Path(ellipseIn: CGRect(x: p.x - 15, y: p.y - 15, width: 30, height: 30)),
          with: .color(Ink.copper.opacity(0.15)))
      }
      let circle = Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
      context.fill(circle, with: .color(selected ? Ink.copper : Ink.paper))
      context.stroke(circle, with: .color(selected ? Ink.copper : Ink.navy), lineWidth: 1.8)
      if studio.showLabels {
        let upper = node.y > 0.5
        text(
          &context, "N\(node.id + 1)", at: CGPoint(x: p.x, y: p.y + (upper ? -20 : 17)), size: 9,
          color: selected ? Ink.copper : Ink.navy)
      }
      if node.loadKN != 0 {
        let sign = node.loadKN >= 0 ? 1.0 : -1.0
        let endY = p.y - 13 * sign
        let startY = endY - 68 * sign
        line(
          &context, CGPoint(x: p.x, y: startY), CGPoint(x: p.x, y: endY), color: Ink.copper,
          width: 2)
        line(
          &context, CGPoint(x: p.x - 5, y: endY - 9 * sign), CGPoint(x: p.x, y: endY),
          color: Ink.copper, width: 2)
        line(
          &context, CGPoint(x: p.x + 5, y: endY - 9 * sign), CGPoint(x: p.x, y: endY),
          color: Ink.copper, width: 2)
        text(
          &context, String(format: "%.0f kN", abs(node.loadKN)),
          at: CGPoint(x: p.x + 11, y: startY + 4), size: 11, color: Ink.copper, anchor: .leading)
      }
    }
    if studio.result != nil, studio.mode != .geometry {
      text(
        &context, "MEMBER LABELS: MPa", at: CGPoint(x: 26, y: 127), size: 9, color: Ink.muted,
        anchor: .leading)
    }
  }

  private func drawDimensions(_ context: inout GraphicsContext, transform: DraftingTransform) {
    let nodes = studio.design.nodes
    guard let minX = nodes.map(\.x).min(), let maxX = nodes.map(\.x).max(),
      let minY = nodes.map(\.y).min(), let maxY = nodes.map(\.y).max()
    else { return }
    let a = transform.screen(minX, minY)
    let b = transform.screen(maxX, minY)
    let y = a.y + 76
    line(
      &context, CGPoint(x: a.x, y: y), CGPoint(x: b.x, y: y), color: Ink.muted.opacity(0.6),
      width: 0.6)
    for x in [a.x, b.x] {
      line(
        &context, CGPoint(x: x, y: a.y + 49), CGPoint(x: x, y: y + 6),
        color: Ink.muted.opacity(0.4), width: 0.6)
      line(&context, CGPoint(x: x - 3, y: y + 3), CGPoint(x: x + 3, y: y - 3), color: Ink.navy)
    }
    let rect = CGRect(x: (a.x + b.x) / 2 - 42, y: y - 8, width: 84, height: 16)
    context.fill(Path(rect), with: .color(Ink.paper))
    text(
      &context, String(format: "%.2f m", maxX - minX), at: CGPoint(x: rect.midX, y: y), size: 11,
      color: Ink.navy)
    let top = transform.screen(maxX, maxY)
    let x = b.x + 28
    line(
      &context, CGPoint(x: x, y: top.y), CGPoint(x: x, y: b.y), color: Ink.muted.opacity(0.6),
      width: 0.6)
    for y in [top.y, b.y] {
      line(&context, CGPoint(x: x - 4, y: y), CGPoint(x: x + 4, y: y), color: Ink.navy, width: 0.7)
    }
    var label = context
    label.translateBy(x: x + 11, y: (top.y + b.y) / 2)
    label.rotate(by: .degrees(-90))
    text(&label, String(format: "%.2f m", maxY - minY), at: .zero, size: 9)
  }
}
