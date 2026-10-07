import SwiftUI

extension Color {
  static let ink = Color(red: 0.11, green: 0.21, blue: 0.17)
  static let pine = Color(red: 0.16, green: 0.30, blue: 0.24)
  static let cream = Color(red: 0.98, green: 0.95, blue: 0.86)
  static let parchment = Color(red: 0.95, green: 0.90, blue: 0.77)
  static let gold = Color(red: 0.96, green: 0.72, blue: 0.22)
  static let goldDeep = Color(red: 0.78, green: 0.52, blue: 0.10)
  static let moss = Color(red: 0.31, green: 0.43, blue: 0.29)
  static let terracotta = Color(red: 0.72, green: 0.38, blue: 0.27)
  static let soil = Color(red: 0.40, green: 0.28, blue: 0.19)
  static let sky = Color(red: 0.64, green: 0.81, blue: 0.90)
  static let peach = Color(red: 0.99, green: 0.84, blue: 0.66)
  static let copper = Color(red: 0.72, green: 0.44, blue: 0.26)
  static let brass = Color(red: 0.85, green: 0.66, blue: 0.32)
  static let steel = Color(red: 0.36, green: 0.42, blue: 0.42)
  static let night = Color(red: 0.06, green: 0.13, blue: 0.11)
}

extension Seed {
  var tint: Color {
    switch self {
    case .marigold: Color(red: 0.95, green: 0.62, blue: 0.20)
    case .peashooter: Color(red: 0.45, green: 0.64, blue: 0.30)
    case .bramble: Color(red: 0.58, green: 0.40, blue: 0.24)
    case .ember: Color(red: 0.84, green: 0.33, blue: 0.24)
    case .frost: Color(red: 0.42, green: 0.63, blue: 0.76)
    }
  }
}

/// Small helpers shared by every piece of vector artwork.
struct Brush {
  var context: GraphicsContext
  func oval(_ rect: CGRect, _ color: Color) {
    context.fill(Path(ellipseIn: rect), with: .color(color))
  }
  func oval(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color) {
    oval(CGRect(x: x, y: y, width: w, height: h), color)
  }
  func orb(_ rect: CGRect, _ light: Color, _ dark: Color, focus: CGPoint? = nil) {
    let center =
      focus ?? CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.35)
    context.fill(
      Path(ellipseIn: rect),
      with: .radialGradient(
        Gradient(colors: [light, dark]), center: center, startRadius: 0,
        endRadius: max(rect.width, rect.height) * 0.72))
  }
  func outline(_ rect: CGRect, _ color: Color, _ width: Double) {
    context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: width)
  }
  func line(_ points: [CGPoint], _ color: Color, _ width: Double) {
    var path = Path()
    path.addLines(points)
    context.stroke(
      path, with: .color(color),
      style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
  }
  func curve(_ from: CGPoint, _ to: CGPoint, _ control: CGPoint, _ color: Color, _ width: Double) {
    var path = Path()
    path.move(to: from)
    path.addQuadCurve(to: to, control: control)
    context.stroke(
      path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
  }
  func leaf(_ base: CGPoint, _ tip: CGPoint, _ width: Double, _ light: Color, _ dark: Color) {
    let mid = CGPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
    let dx = tip.x - base.x
    let dy = tip.y - base.y
    let length = max(1, sqrt(dx * dx + dy * dy))
    let nx = -dy / length * width
    let ny = dx / length * width
    var path = Path()
    path.move(to: base)
    path.addQuadCurve(to: tip, control: CGPoint(x: mid.x + nx, y: mid.y + ny))
    path.addQuadCurve(to: base, control: CGPoint(x: mid.x - nx, y: mid.y - ny))
    context.fill(
      path,
      with: .linearGradient(Gradient(colors: [light, dark]), startPoint: base, endPoint: tip))
    context.stroke(path, with: .color(dark.opacity(0.7)), lineWidth: 1)
    line([base, mid], dark.opacity(0.6), 0.8)
  }
  func eye(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
    oval(x, y, w, h, .ink)
    oval(x + w * 0.5, y + h * 0.15, w * 0.32, h * 0.3, .white.opacity(0.9))
  }
  func gear(center: CGPoint, radius: Double, teeth: Int, angle: Double, _ color: Color) {
    var path = Path()
    for index in 0..<(teeth * 2) {
      let step = Double(index) * .pi / Double(teeth) + angle
      let r = index % 2 == 0 ? radius : radius * 0.72
      let point = CGPoint(x: center.x + cos(step) * r, y: center.y + sin(step) * r)
      if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    path.closeSubpath()
    context.fill(path, with: .color(color))
    oval(
      CGRect(
        x: center.x - radius * 0.3, y: center.y - radius * 0.3, width: radius * 0.6,
        height: radius * 0.6), .ink.opacity(0.8))
  }
}

struct GardenArt: View {
  var seed: Seed
  var phase = 0.0
  var body: some View {
    Canvas { context, size in
      let scale = min(size.width, size.height) / 100
      context.translateBy(
        x: (size.width - 100 * scale) / 2, y: (size.height - 100 * scale) / 2)
      context.scaleBy(x: scale, y: scale)
      let sway = sin(phase) * 2
      let brush = Brush(context: context)
      context.fill(
        Path(ellipseIn: CGRect(x: 18, y: 84, width: 64, height: 11)),
        with: .radialGradient(
          Gradient(colors: [.ink.opacity(0.22), .ink.opacity(0)]), center: CGPoint(x: 50, y: 89),
          startRadius: 0, endRadius: 34))
      let stemTop = CGPoint(x: 50 + sway, y: 48)
      brush.curve(
        CGPoint(x: 50, y: 84), stemTop, CGPoint(x: 50 - sway, y: 66),
        Color(red: 0.24, green: 0.44, blue: 0.22), 7)
      brush.leaf(
        CGPoint(x: 50, y: 78), CGPoint(x: 24, y: 70 - sway), 7,
        Color(red: 0.52, green: 0.70, blue: 0.34), Color(red: 0.24, green: 0.42, blue: 0.22))
      brush.leaf(
        CGPoint(x: 50, y: 80), CGPoint(x: 78, y: 74 + sway), 6,
        Color(red: 0.46, green: 0.65, blue: 0.30), Color(red: 0.22, green: 0.40, blue: 0.20))
      context.translateBy(x: sway, y: 0)
      switch seed {
      case .marigold:
        for index in 0..<12 {
          let angle = Double(index) * .pi / 6 + phase * 0.05
          let rect = CGRect(x: 41 + cos(angle) * 24, y: 30 + sin(angle) * 24, width: 20, height: 26)
          brush.orb(
            rect, index % 2 == 0 ? Color(red: 1, green: 0.85, blue: 0.35) : .gold,
            index % 2 == 0 ? Color(red: 0.93, green: 0.55, blue: 0.14) : .goldDeep)
          brush.outline(rect, Color(red: 0.72, green: 0.42, blue: 0.08).opacity(0.5), 0.8)
        }
        brush.orb(
          CGRect(x: 30, y: 24, width: 42, height: 42), Color(red: 0.72, green: 0.46, blue: 0.24),
          Color(red: 0.40, green: 0.22, blue: 0.12))
        brush.outline(CGRect(x: 30, y: 24, width: 42, height: 42), .ink.opacity(0.35), 1.2)
        brush.eye(39, 37, 5, 7)
        brush.eye(57, 37, 5, 7)
        brush.oval(35, 46, 7, 4, Color(red: 0.95, green: 0.45, blue: 0.35).opacity(0.5))
        brush.oval(59, 46, 7, 4, Color(red: 0.95, green: 0.45, blue: 0.35).opacity(0.5))
        brush.curve(
          CGPoint(x: 45, y: 50), CGPoint(x: 56, y: 50), CGPoint(x: 50.5, y: 56), .cream, 2)
      case .peashooter:
        brush.orb(
          CGRect(x: 21, y: 20, width: 58, height: 50), Color(red: 0.70, green: 0.84, blue: 0.46),
          Color(red: 0.35, green: 0.55, blue: 0.26))
        brush.outline(CGRect(x: 21, y: 20, width: 58, height: 50), .ink.opacity(0.35), 1.2)
        brush.orb(
          CGRect(x: 60, y: 34, width: 32, height: 26), Color(red: 0.55, green: 0.72, blue: 0.36),
          Color(red: 0.28, green: 0.46, blue: 0.22), focus: CGPoint(x: 70, y: 40))
        brush.outline(CGRect(x: 60, y: 34, width: 32, height: 26), .ink.opacity(0.35), 1.2)
        brush.oval(78, 39, 11, 17, Color(red: 0.14, green: 0.26, blue: 0.14))
        brush.oval(81, 42, 4, 6, Color(red: 0.55, green: 0.72, blue: 0.36).opacity(0.5))
        brush.leaf(
          CGPoint(x: 34, y: 24), CGPoint(x: 26, y: 8), 5, Color(red: 0.55, green: 0.72, blue: 0.36),
          Color(red: 0.25, green: 0.42, blue: 0.21))
        brush.leaf(
          CGPoint(x: 36, y: 24), CGPoint(x: 46, y: 9), 5, Color(red: 0.55, green: 0.72, blue: 0.36),
          Color(red: 0.25, green: 0.42, blue: 0.21))
        brush.eye(39, 33, 8, 11)
        brush.oval(30, 48, 10, 5, Color(red: 0.95, green: 0.55, blue: 0.45).opacity(0.45))
        brush.curve(CGPoint(x: 44, y: 54), CGPoint(x: 52, y: 55), CGPoint(x: 48, y: 58), .ink, 1.6)
      case .bramble:
        var shield = Path()
        shield.move(to: CGPoint(x: 50, y: 12))
        shield.addQuadCurve(to: CGPoint(x: 82, y: 42), control: CGPoint(x: 85, y: 12))
        shield.addQuadCurve(to: CGPoint(x: 51, y: 86), control: CGPoint(x: 83, y: 78))
        shield.addQuadCurve(to: CGPoint(x: 18, y: 42), control: CGPoint(x: 14, y: 76))
        shield.addQuadCurve(to: CGPoint(x: 50, y: 12), control: CGPoint(x: 13, y: 13))
        context.fill(
          shield,
          with: .linearGradient(
            Gradient(colors: [
              Color(red: 0.74, green: 0.52, blue: 0.31), Color(red: 0.46, green: 0.30, blue: 0.17),
            ]), startPoint: CGPoint(x: 30, y: 15), endPoint: CGPoint(x: 70, y: 85)))
        context.stroke(
          shield, with: .color(Color(red: 0.32, green: 0.20, blue: 0.11)), lineWidth: 2.5)
        for x in [28.0, 38.0, 62.0, 72.0] {
          brush.curve(
            CGPoint(x: x, y: 24), CGPoint(x: x + 3, y: 72), CGPoint(x: x - 4, y: 48),
            (x < 50 ? Color.cream : Color.ink).opacity(0.16), 2.5)
        }
        brush.oval(44, 66, 12, 7, Color(red: 0.36, green: 0.22, blue: 0.12).opacity(0.7))
        brush.oval(47, 68, 6, 3, Color(red: 0.74, green: 0.52, blue: 0.31).opacity(0.7))
        brush.eye(33, 38, 7, 9)
        brush.eye(60, 38, 7, 9)
        brush.line([CGPoint(x: 31, y: 33), CGPoint(x: 41, y: 35)], .ink, 2)
        brush.line([CGPoint(x: 69, y: 33), CGPoint(x: 59, y: 35)], .ink, 2)
        brush.line([CGPoint(x: 43, y: 58), CGPoint(x: 57, y: 58)], .ink, 2.5)
        brush.leaf(
          CGPoint(x: 48, y: 14), CGPoint(x: 28, y: 4), 6, Color(red: 0.55, green: 0.70, blue: 0.36),
          Color(red: 0.26, green: 0.42, blue: 0.22))
        brush.leaf(
          CGPoint(x: 52, y: 14), CGPoint(x: 72, y: 2), 6, Color(red: 0.50, green: 0.66, blue: 0.33),
          Color(red: 0.24, green: 0.40, blue: 0.20))
      case .ember:
        let glow = 0.5 + sin(phase * 3) * 0.5
        brush.oval(58, 4, 20, 20, .gold.opacity(0.18 + glow * 0.25))
        brush.orb(
          CGRect(x: 22, y: 28, width: 58, height: 50), Color(red: 1, green: 0.55, blue: 0.32),
          Color(red: 0.64, green: 0.16, blue: 0.13))
        brush.outline(CGRect(x: 22, y: 28, width: 58, height: 50), .ink.opacity(0.35), 1.2)
        brush.oval(38, 32, 22, 9, .white.opacity(0.22))
        brush.curve(CGPoint(x: 51, y: 31), CGPoint(x: 68, y: 14), CGPoint(x: 52, y: 14), .ink, 3.5)
        brush.orb(
          CGRect(x: 62, y: 7, width: 12, height: 13), Color(red: 1, green: 0.95, blue: 0.6), .gold,
          focus: CGPoint(x: 68, y: 12))
        brush.eye(35, 42, 7, 10)
        brush.eye(58, 42, 7, 10)
        for spot in [(30.0, 56.0), (36.0, 60.0), (66.0, 57.0)] {
          brush.oval(spot.0, spot.1, 3, 3, Color(red: 0.55, green: 0.12, blue: 0.10).opacity(0.5))
        }
        brush.curve(
          CGPoint(x: 45, y: 60), CGPoint(x: 56, y: 60), CGPoint(x: 50.5, y: 66), .cream, 2)
      case .frost:
        for index in 0..<6 {
          let angle = Double(index) * .pi / 3 + phase * 0.03
          let rect = CGRect(x: 37 + cos(angle) * 19, y: 27 + sin(angle) * 19, width: 26, height: 30)
          brush.orb(
            rect, .white, Color(red: 0.55, green: 0.76, blue: 0.86),
            focus: CGPoint(x: rect.midX, y: rect.midY))
          brush.outline(rect, Color(red: 0.36, green: 0.58, blue: 0.72).opacity(0.7), 0.9)
        }
        brush.orb(
          CGRect(x: 30, y: 27, width: 40, height: 40), Color(red: 0.62, green: 0.82, blue: 0.92),
          Color(red: 0.24, green: 0.44, blue: 0.60))
        brush.outline(CGRect(x: 30, y: 27, width: 40, height: 40), .ink.opacity(0.3), 1.2)
        brush.eye(36, 36, 6, 9)
        brush.eye(57, 36, 6, 9)
        brush.oval(43, 51, 13, 7, Color(red: 0.16, green: 0.34, blue: 0.48))
        brush.line([CGPoint(x: 50, y: 12), CGPoint(x: 50, y: 0)], .white, 2.5)
        brush.line([CGPoint(x: 44, y: 6), CGPoint(x: 56, y: 6)], .white, 2)
        brush.line([CGPoint(x: 46, y: 2), CGPoint(x: 54, y: 10)], .white.opacity(0.7), 1.2)
        brush.line([CGPoint(x: 54, y: 2), CGPoint(x: 46, y: 10)], .white.opacity(0.7), 1.2)
      }
    }
    .accessibilityHidden(true)
  }
}

struct PestArt: View {
  var kind: PestKind
  var slowed = false
  var phase = 0.0
  var body: some View {
    Canvas { context, size in
      context.scaleBy(x: size.width / 100, y: size.height / 100)
      let brush = Brush(context: context)
      let bob = sin(phase * 2) * 1.5
      let metal = slowed ? Color(red: 0.55, green: 0.78, blue: 0.86) : Color.steel
      let metalDark =
        slowed
        ? Color(red: 0.30, green: 0.50, blue: 0.62) : Color(red: 0.20, green: 0.25, blue: 0.26)
      let shell = kind == .beetle ? Color.copper : metal
      let shellDark = kind == .beetle ? Color(red: 0.42, green: 0.22, blue: 0.12) : metalDark
      context.fill(
        Path(ellipseIn: CGRect(x: 8, y: 80, width: 80, height: 12)),
        with: .radialGradient(
          Gradient(colors: [.ink.opacity(0.28), .ink.opacity(0)]), center: CGPoint(x: 48, y: 86),
          startRadius: 0, endRadius: 42))
      for index in 0..<3 {
        let x = Double(index * 18 + 32)
        let step = sin(phase * 2 + Double(index) * 2.1) * 5
        brush.line(
          [
            CGPoint(x: x, y: 62), CGPoint(x: x + 4 + step, y: 74), CGPoint(x: x + 10 + step, y: 84),
          ],
          metalDark, 4.5)
        brush.line([CGPoint(x: x + 6 + step, y: 84), CGPoint(x: x + 16 + step, y: 84)], .ink, 4)
      }
      context.translateBy(x: 0, y: bob)
      let body = CGRect(
        x: 28, y: kind == .kettle ? 14 : 30, width: 60, height: kind == .kettle ? 60 : 42)
      brush.orb(
        body, shell, shellDark, focus: CGPoint(x: body.minX + 22, y: body.minY + body.height * 0.3))
      brush.outline(body, .ink.opacity(0.55), 1.4)
      brush.line(
        [CGPoint(x: 58, y: body.minY + 4), CGPoint(x: 58, y: body.maxY - 4)], .ink.opacity(0.35),
        1.5)
      for rivet in [
        (38.0, body.minY + 9), (76.0, body.minY + 10), (44.0, body.maxY - 12),
        (72.0, body.maxY - 11),
      ] {
        brush.oval(rivet.0, rivet.1, 4, 4, .brass)
        brush.oval(rivet.0 + 1, rivet.1 + 1, 1.5, 1.5, .white.opacity(0.7))
      }
      brush.gear(
        center: CGPoint(x: 72, y: body.midY + 2), radius: kind == .kettle ? 11 : 8, teeth: 8,
        angle: phase * 1.5, .brass)
      brush.orb(
        CGRect(x: 6, y: 40, width: 36, height: 32), shell, shellDark, focus: CGPoint(x: 18, y: 50))
      brush.outline(CGRect(x: 6, y: 40, width: 36, height: 32), .ink.opacity(0.55), 1.4)
      brush.oval(10, 46, 15, 15, Color(red: 0.16, green: 0.20, blue: 0.20))
      brush.orb(
        CGRect(x: 11.5, y: 47.5, width: 12, height: 12),
        slowed ? Color(red: 0.7, green: 0.95, blue: 1) : Color(red: 1, green: 0.93, blue: 0.55),
        slowed ? Color(red: 0.2, green: 0.6, blue: 0.8) : Color(red: 0.85, green: 0.45, blue: 0.1))
      brush.oval(14, 51, 5, 5, .ink)
      brush.oval(21, 49, 2.5, 2.5, .white.opacity(0.85))
      brush.line([CGPoint(x: 8, y: 64), CGPoint(x: 26, y: 66)], .ink.opacity(0.6), 1.6)
      brush.curve(CGPoint(x: 22, y: 42), CGPoint(x: 12, y: 24), CGPoint(x: 22, y: 28), .copper, 2.8)
      brush.orb(
        CGRect(x: 6, y: 18, width: 10, height: 10), Color(red: 1, green: 0.9, blue: 0.5), .goldDeep)
      switch kind {
      case .kettle:
        context.fill(
          Path(roundedRect: CGRect(x: 38, y: 9, width: 40, height: 9), cornerRadius: 4),
          with: .color(.copper))
        brush.oval(53, 2, 12, 11, Color(red: 0.30, green: 0.18, blue: 0.10))
        brush.line([CGPoint(x: 84, y: 36), CGPoint(x: 97, y: 22)], .copper, 8)
        brush.line([CGPoint(x: 84, y: 36), CGPoint(x: 97, y: 22)], .brass.opacity(0.5), 3)
        for puff in 0..<3 {
          let t = (phase * 0.4 + Double(puff) / 3).truncatingRemainder(dividingBy: 1)
          brush.oval(94 - t * 8, 20 - t * 26, 6 + t * 8, 6 + t * 8, .cream.opacity(0.35 * (1 - t)))
        }
      case .skitter:
        brush.curve(
          CGPoint(x: 52, y: 31), CGPoint(x: 78, y: 10), CGPoint(x: 60, y: 12), .copper, 2.5)
        brush.curve(
          CGPoint(x: 60, y: 31), CGPoint(x: 90, y: 16), CGPoint(x: 72, y: 14), .copper, 2.5)
        brush.oval(76, 6, 5, 5, .brass)
        brush.oval(88, 12, 5, 5, .brass)
        brush.oval(40, 24, 34, 12, .white.opacity(0.35))
        brush.outline(CGRect(x: 40, y: 24, width: 34, height: 12), .ink.opacity(0.4), 1)
      case .beetle:
        brush.line([CGPoint(x: 44, y: 32), CGPoint(x: 52, y: 44)], .ink.opacity(0.35), 1.5)
        brush.line([CGPoint(x: 70, y: 32), CGPoint(x: 64, y: 44)], .ink.opacity(0.35), 1.5)
      }
    }
    .accessibilityHidden(true)
  }
}

struct Cottage: View {
  var night = false
  var body: some View {
    Canvas { context, size in
      context.scaleBy(x: size.width / 300, y: size.height / 200)
      let brush = Brush(context: context)
      func rect(
        _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color, radius: Double = 0
      ) {
        context.fill(
          Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius),
          with: .color(color))
      }
      for index in 0..<14 {
        let x = Double(index) * 24
        brush.orb(
          CGRect(x: x - 12, y: 80 + Double(index % 3) * 9, width: 53, height: 76),
          index % 2 == 0
            ? Color(red: 0.45, green: 0.60, blue: 0.36) : Color(red: 0.36, green: 0.52, blue: 0.31),
          Color(red: 0.18, green: 0.32, blue: 0.20))
      }
      for puff in 0..<3 {
        let y = 18 - Double(puff) * 14
        brush.oval(
          206 + Double(puff) * 5, y, 12 + Double(puff) * 6, 10 + Double(puff) * 4,
          .cream.opacity(0.35 - Double(puff) * 0.1))
      }
      context.fill(
        Path(roundedRect: CGRect(x: 66, y: 66, width: 173, height: 109), cornerRadius: 4),
        with: .linearGradient(
          Gradient(colors: [.cream, .parchment]), startPoint: CGPoint(x: 66, y: 66),
          endPoint: CGPoint(x: 66, y: 175)))
      rect(62, 160, 181, 15, Color(red: 0.62, green: 0.58, blue: 0.50), radius: 2)
      for index in 0..<9 {
        rect(
          66 + Double(index) * 20, 163 + Double(index % 2) * 5, 14, 6, .cream.opacity(0.35),
          radius: 3)
      }
      rect(204, 22, 19, 52, Color(red: 0.55, green: 0.32, blue: 0.22))
      rect(201, 20, 25, 6, Color(red: 0.42, green: 0.24, blue: 0.16), radius: 1)
      var roof = Path()
      roof.addLines([CGPoint(x: 44, y: 76), CGPoint(x: 149, y: 6), CGPoint(x: 259, y: 76)])
      roof.closeSubpath()
      context.fill(
        roof,
        with: .linearGradient(
          Gradient(colors: [
            Color(red: 0.80, green: 0.44, blue: 0.31), Color(red: 0.55, green: 0.28, blue: 0.20),
          ]),
          startPoint: CGPoint(x: 149, y: 6), endPoint: CGPoint(x: 149, y: 76)))
      context.stroke(roof, with: .color(Color(red: 0.40, green: 0.20, blue: 0.14)), lineWidth: 2)
      for row in 0..<4 {
        let y = 24 + Double(row) * 13
        let half = (y - 6) * 1.5
        brush.line(
          [CGPoint(x: 149 - half, y: y), CGPoint(x: 149 + half, y: y)], .ink.opacity(0.14), 1.5)
      }
      rect(38, 74, 224, 6, Color(red: 0.42, green: 0.22, blue: 0.15), radius: 3)
      context.fill(
        Path(roundedRect: CGRect(x: 131, y: 104, width: 43, height: 72), cornerRadius: 21),
        with: .color(Color(red: 0.30, green: 0.18, blue: 0.11)))
      context.fill(
        Path(roundedRect: CGRect(x: 137, y: 110, width: 31, height: 66), cornerRadius: 15),
        with: .linearGradient(
          Gradient(colors: [Color(red: 0.36, green: 0.50, blue: 0.32), .moss]),
          startPoint: CGPoint(x: 137, y: 110), endPoint: CGPoint(x: 168, y: 176)))
      brush.line([CGPoint(x: 152.5, y: 112), CGPoint(x: 152.5, y: 174)], .ink.opacity(0.25), 1)
      brush.oval(158, 143, 5, 5, .gold)
      for x in [83.0, 192.0] {
        rect(x - 2, 94, 32, 34, Color(red: 0.40, green: 0.24, blue: 0.16), radius: 3)
        context.fill(
          Path(roundedRect: CGRect(x: x, y: 96, width: 28, height: 30), cornerRadius: 2),
          with: .linearGradient(
            Gradient(colors: [
              night
                ? Color(red: 1, green: 0.85, blue: 0.5) : Color(red: 0.78, green: 0.88, blue: 0.86),
              night ? .gold : Color(red: 0.55, green: 0.72, blue: 0.74),
            ]), startPoint: CGPoint(x: x, y: 96), endPoint: CGPoint(x: x + 28, y: 126)))
        rect(x + 12.5, 96, 3, 30, .cream)
        rect(x, 109, 28, 3, .cream)
        rect(x - 4, 128, 36, 9, Color(red: 0.55, green: 0.32, blue: 0.22), radius: 2)
        for flower in 0..<4 {
          brush.oval(
            x + Double(flower) * 8, 122, 6, 6,
            flower % 2 == 0 ? .gold : Color(red: 0.92, green: 0.45, blue: 0.45))
        }
      }
      for index in 0..<26 {
        let x = Double((index * 43) % 280 + 10)
        let y = Double(160 + (index * 7) % 32)
        brush.oval(
          x, y, 5, 8,
          index % 3 == 0 ? .gold : index % 3 == 1 ? .cream : Color(red: 0.92, green: 0.5, blue: 0.5)
        )
      }
    }
    .accessibilityHidden(true)
  }
}

/// Dawn sky, hills and hedgerows for the title and journal scenes.
struct DawnScene: View {
  var phase = 0.0
  var body: some View {
    Canvas { context, size in
      let w = size.width
      let h = size.height
      context.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .linearGradient(
          Gradient(colors: [
            Color(red: 0.55, green: 0.74, blue: 0.86), Color(red: 0.86, green: 0.86, blue: 0.80),
            Color(red: 0.99, green: 0.85, blue: 0.68),
          ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.7)))
      let sun = CGPoint(x: w * 0.60, y: h * 0.20)
      context.fill(
        Path(
          ellipseIn: CGRect(
            x: sun.x - w * 0.34, y: sun.y - w * 0.34, width: w * 0.68, height: w * 0.68)),
        with: .radialGradient(
          Gradient(colors: [.gold.opacity(0.45), .gold.opacity(0)]), center: sun, startRadius: 0,
          endRadius: w * 0.34))
      context.fill(
        Path(ellipseIn: CGRect(x: sun.x - 38, y: sun.y - 38, width: 76, height: 76)),
        with: .radialGradient(
          Gradient(colors: [Color(red: 1, green: 0.97, blue: 0.85), .gold]), center: sun,
          startRadius: 0, endRadius: 40))
      let hills: [(Double, Double, Color)] = [
        (0.62, 1.4, Color(red: 0.60, green: 0.72, blue: 0.52)),
        (0.72, 1.0, Color(red: 0.46, green: 0.62, blue: 0.40)),
        (0.84, 0.8, Color(red: 0.33, green: 0.50, blue: 0.32)),
      ]
      for (index, hill) in hills.enumerated() {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h))
        let steps = 5
        var previous = CGPoint(x: 0, y: h * hill.0)
        path.addLine(to: previous)
        for step in 1...steps {
          let x = w * Double(step) / Double(steps)
          let y = h * hill.0 - sin(Double(step) * hill.1 + Double(index) * 1.7) * h * 0.05
          let point = CGPoint(x: x, y: y)
          let span = (x - previous.x) * 0.5
          path.addCurve(
            to: point,
            control1: CGPoint(x: previous.x + span, y: previous.y),
            control2: CGPoint(x: x - span, y: y))
          previous = point
        }
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        context.fill(
          path,
          with: .linearGradient(
            Gradient(colors: [hill.2, hill.2.opacity(0.75)]),
            startPoint: CGPoint(x: 0, y: h * hill.0),
            endPoint: CGPoint(x: 0, y: h)))
      }
      for index in 0..<18 {
        let x = Double((index * 97) % 1000) / 1000 * w
        let y = h * 0.86 + Double((index * 31) % 100) / 100 * h * 0.12
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: y, width: 4, height: 6)),
          with: .color(
            index % 3 == 0
              ? .gold : index % 3 == 1 ? .cream : Color(red: 0.93, green: 0.55, blue: 0.55)))
      }
      for index in 0..<8 {
        let t = (phase * 0.03 + Double(index) / 8).truncatingRemainder(dividingBy: 1)
        let x =
          w * 0.5
          + (Double((index * 137) % 100) / 100 + t * 0.15).truncatingRemainder(dividingBy: 1) * w
          * 0.5
        let y = (1 - t) * h * 0.9
        let petal = Path(ellipseIn: CGRect(x: x, y: y, width: 6, height: 9))
        context.fill(petal, with: .color(Color(red: 0.98, green: 0.72, blue: 0.70).opacity(0.7)))
      }
    }
    .accessibilityHidden(true)
  }
}

/// Deep evergreen backdrop behind the playing field.
struct Backdrop: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.13, green: 0.26, blue: 0.21), .night], startPoint: .top,
        endPoint: .bottom)
      RadialGradient(
        colors: [.clear, .black.opacity(0.3)], center: .center, startRadius: 220,
        endRadius: 720)
    }.ignoresSafeArea()
  }
}

struct ShovelArt: View {
  var body: some View {
    Canvas { context, size in
      context.scaleBy(x: size.width / 30, y: size.height / 30)
      var handle = Path()
      handle.move(to: CGPoint(x: 15, y: 4))
      handle.addLine(to: CGPoint(x: 15, y: 19))
      context.stroke(
        handle, with: .color(.init(red: 0.62, green: 0.40, blue: 0.22)),
        style: StrokeStyle(lineWidth: 4, lineCap: .round))
      context.stroke(
        Path(roundedRect: CGRect(x: 10, y: 1, width: 10, height: 7), cornerRadius: 2),
        with: .color(.gold), lineWidth: 3)
      var blade = Path()
      blade.move(to: CGPoint(x: 8, y: 16))
      blade.addLine(to: CGPoint(x: 22, y: 16))
      blade.addQuadCurve(to: CGPoint(x: 15, y: 29), control: CGPoint(x: 25, y: 26))
      blade.addQuadCurve(to: CGPoint(x: 8, y: 16), control: CGPoint(x: 5, y: 26))
      context.fill(
        blade,
        with: .linearGradient(
          Gradient(colors: [
            Color(red: 0.85, green: 0.90, blue: 0.88), Color(red: 0.55, green: 0.64, blue: 0.62),
          ]),
          startPoint: CGPoint(x: 8, y: 16), endPoint: CGPoint(x: 22, y: 29)))
      context.stroke(blade, with: .color(.ink.opacity(0.5)), lineWidth: 1)
      var seam = Path()
      seam.move(to: CGPoint(x: 15, y: 18))
      seam.addLine(to: CGPoint(x: 15, y: 25))
      context.stroke(seam, with: .color(.ink.opacity(0.3)), lineWidth: 1)
    }.rotationEffect(.degrees(30)).accessibilityHidden(true)
  }
}
