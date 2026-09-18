import SwiftUI

enum Ink {
  static let background = Color(red: 0.025, green: 0.070, blue: 0.070)
  static let deep = Color(red: 0.055, green: 0.15, blue: 0.14)
  static let jade = Color(red: 0.39, green: 0.64, blue: 0.53)
  static let gold = Color(red: 0.76, green: 0.68, blue: 0.48)
  static let pearl = Color(red: 0.94, green: 0.92, blue: 0.85)
  static let peach = Color(red: 0.85, green: 0.47, blue: 0.32)
  static let muted = Color(red: 0.65, green: 0.73, blue: 0.67)
  static func display(_ size: CGFloat) -> Font { .custom("Baskerville", fixedSize: size) }
  static func italic(_ size: CGFloat) -> Font { .custom("Baskerville-Italic", fixedSize: size) }
}

struct PondArt: View {
  var time: Double = 0
  var hero = false
  var celebration = false
  var reducedMotion = false
  var atmosphereOnly = false
  var transparent = false

  var body: some View {
    Canvas { context, size in
      let t = reducedMotion ? 0 : time
      if !transparent { water(context, size: size, time: t) }
      guard !atmosphereOnly else { return }
      if hero {
        let radius = min(size.width / 2.7, max(0, size.height - 24) / 2.5)
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5 - radius * 0.12)
        moon(context, center: center, radius: radius)
        koi(
          context, at: CGPoint(x: center.x - radius * 0.25, y: center.y + radius * 0.22),
          length: radius * 1.18, angle: -68 + sin(t * 0.22) * 5,
          warm: true, phase: t * 0.8)
        koi(
          context, at: CGPoint(x: center.x + radius * 0.39, y: center.y - radius * 0.14),
          length: radius * 0.91, angle: 114 + sin(t * 0.22 + 2) * 6,
          warm: false, phase: t * 0.8 + 2)
        leaf(
          context, at: CGPoint(x: center.x - radius * 1.04, y: center.y + radius * 0.36),
          radius: radius * 0.23, angle: -35, opacity: 0.65)
        blossom(
          context, at: CGPoint(x: center.x + radius * 0.93, y: center.y + radius * 0.61),
          radius: radius * 0.11)
      } else {
        for index in 0..<(celebration ? 7 : 2) {
          let angle = t * 0.075 + Double(index) * 2.4
          let point = CGPoint(
            x: size.width * (0.5 + 0.36 * cos(angle)), y: size.height * (0.51 + 0.22 * sin(angle)))
          var submerged = context
          submerged.opacity = celebration ? 0.6 : 0.22
          koi(
            submerged, at: point, length: size.width * (celebration ? 0.21 : 0.18),
            angle: angle * 180 / .pi + 90, warm: index.isMultiple(of: 2), phase: t + Double(index))
        }
      }
    }
    .accessibilityHidden(true)
  }

  private func water(_ context: GraphicsContext, size: CGSize, time: Double) {
    let bounds = Path(CGRect(origin: .zero, size: size))
    context.fill(bounds, with: .color(Ink.background))
    context.fill(
      bounds,
      with: .radialGradient(
        Gradient(colors: [Ink.deep.opacity(0.8), Ink.background.opacity(0)]),
        center: CGPoint(x: size.width * 0.35, y: size.height * 0.40),
        startRadius: 0, endRadius: size.height * 0.7))
    for index in 0..<38 {
      let y = size.height * CGFloat(index) / 37
      var current = Path()
      current.move(to: CGPoint(x: -30, y: y))
      current.addCurve(
        to: CGPoint(x: size.width + 30, y: y - 35),
        control1: CGPoint(x: size.width * 0.35, y: y - 32 + sin(time * 0.13) * 7),
        control2: CGPoint(x: size.width * 0.6, y: y + 45))
      context.stroke(
        current, with: .color(Ink.jade.opacity(index % 3 == 0 ? 0.025 : 0.012)), lineWidth: 0.5)
    }
    for index in 0..<90 {
      let x = CGFloat((index * 137 + 19) % 997) / 997 * size.width
      let y = CGFloat((index * 271 + 23) % 991) / 991 * size.height
      let alpha = 0.035 + 0.055 * (sin(time * 0.4 + Double(index)) + 1) / 2
      context.fill(
        Path(ellipseIn: CGRect(x: x, y: y, width: 0.7, height: 0.7)),
        with: .color(Ink.pearl.opacity(alpha)))
    }
    leaf(
      context, at: CGPoint(x: size.width * 1.02, y: size.height * 0.2), radius: size.width * 0.18,
      angle: 140, opacity: 0.25)
    leaf(
      context, at: CGPoint(x: -size.width * 0.03, y: size.height * 0.72), radius: size.width * 0.2,
      angle: -30, opacity: 0.2)
  }

  private func moon(_ source: GraphicsContext, center: CGPoint, radius: Double) {
    var context = source
    context.translateBy(x: center.x, y: center.y)
    context.fill(
      Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
      with: .radialGradient(
        Gradient(colors: [Ink.jade.opacity(0.07), Ink.pearl.opacity(0.015), .clear]),
        center: CGPoint(x: -radius * 0.3, y: -radius * 0.3), startRadius: 0, endRadius: radius * 1.2
      ))
    for index in 0..<3 {
      var arc = Path()
      arc.addArc(
        center: .zero, radius: radius + Double(index) * 5,
        startAngle: .degrees(-113 + Double(index) * 16),
        endAngle: .degrees(196 - Double(index) * 24), clockwise: false)
      context.stroke(
        arc, with: .color(Ink.gold.opacity(index == 0 ? 0.60 : 0.14)),
        style: StrokeStyle(lineWidth: index == 0 ? 0.7 : 0.45, lineCap: .round))
    }
    for index in 0..<35 {
      let angle = Double(index) * 0.032 - 1.85
      let outer = radius + (index.isMultiple(of: 5) ? 6.0 : 3.0)
      var tick = Path()
      tick.move(to: CGPoint(x: cos(angle) * radius, y: sin(angle) * radius))
      tick.addLine(to: CGPoint(x: cos(angle) * outer, y: sin(angle) * outer))
      context.stroke(tick, with: .color(Ink.gold.opacity(0.35)), lineWidth: 0.45)
    }
  }

  private func koi(
    _ source: GraphicsContext, at point: CGPoint, length: Double, angle: Double, warm: Bool,
    phase: Double
  ) {
    var context = source
    context.translateBy(x: point.x, y: point.y)
    context.rotate(by: .degrees(angle))
    context.scaleBy(x: length, y: length)
    let sway = sin(phase) * 0.035
    let pigment = warm ? Ink.peach : Ink.jade
    var tail = Path()
    tail.move(to: CGPoint(x: -0.42, y: 0.022))
    tail.addCurve(
      to: CGPoint(x: -0.92, y: -0.24 + sway), control1: CGPoint(x: -0.60, y: 0.08),
      control2: CGPoint(x: -0.75, y: -0.29))
    tail.addCurve(
      to: CGPoint(x: -0.73, y: 0.06 + sway), control1: CGPoint(x: -0.92, y: -0.07),
      control2: CGPoint(x: -0.76, y: -0.02))
    tail.addCurve(
      to: CGPoint(x: -0.83, y: 0.38 + sway), control1: CGPoint(x: -0.69, y: 0.17),
      control2: CGPoint(x: -0.80, y: 0.25))
    tail.addCurve(
      to: CGPoint(x: -0.42, y: 0.067), control1: CGPoint(x: -0.61, y: 0.29),
      control2: CGPoint(x: -0.61, y: 0.08))
    context.fill(
      tail,
      with: .linearGradient(
        Gradient(colors: [
          Ink.pearl.opacity(0.10), pigment.opacity(0.65),
          (warm ? pigment : Ink.pearl).opacity(0.85),
        ]),
        startPoint: CGPoint(x: -0.9, y: 0), endPoint: CGPoint(x: -0.4, y: 0)))
    context.stroke(tail, with: .color(Ink.pearl.opacity(0.38)), lineWidth: 0.003)
    for side in [-1.0, 1.0] {
      var fin = Path()
      fin.move(to: CGPoint(x: 0.20, y: side * 0.08))
      fin.addCurve(
        to: CGPoint(x: -0.17, y: side * 0.32), control1: CGPoint(x: 0.06, y: side * 0.14),
        control2: CGPoint(x: 0.02, y: side * 0.33))
      fin.addCurve(
        to: CGPoint(x: -0.02, y: side * 0.08), control1: CGPoint(x: -0.16, y: side * 0.18),
        control2: CGPoint(x: -0.09, y: side * 0.16))
      fin.closeSubpath()
      context.fill(fin, with: .color(Ink.pearl.opacity(0.30)))
      context.stroke(fin, with: .color(Ink.pearl.opacity(0.35)), lineWidth: 0.003)
      var finDetail = context
      finDetail.clip(to: fin)
      for index in 0..<5 {
        var ray = Path()
        ray.move(to: CGPoint(x: 0.14, y: side * 0.09))
        ray.addQuadCurve(
          to: CGPoint(x: -0.13 + Double(index) * 0.045, y: side * (0.27 - Double(index) * 0.017)),
          control: CGPoint(x: -0.02, y: side * 0.16))
        finDetail.stroke(ray, with: .color(Ink.pearl.opacity(0.24)), lineWidth: 0.002)
      }
    }
    var body = Path()
    body.move(to: CGPoint(x: 0.46, y: -0.015))
    body.addCurve(
      to: CGPoint(x: 0.32, y: -0.118), control1: CGPoint(x: 0.455, y: -0.073),
      control2: CGPoint(x: 0.405, y: -0.118))
    body.addCurve(
      to: CGPoint(x: -0.44, y: 0.023), control1: CGPoint(x: 0.02, y: -0.17),
      control2: CGPoint(x: -0.22, y: 0.06))
    body.addLine(to: CGPoint(x: -0.44, y: 0.067))
    body.addCurve(
      to: CGPoint(x: 0.32, y: 0.101), control1: CGPoint(x: -0.10, y: 0.04),
      control2: CGPoint(x: 0.11, y: 0.15))
    body.addCurve(
      to: CGPoint(x: 0.46, y: -0.015), control1: CGPoint(x: 0.41, y: 0.097),
      control2: CGPoint(x: 0.462, y: 0.035))
    context.fill(
      body,
      with: .linearGradient(
        Gradient(colors: [Ink.pearl, Ink.pearl.opacity(0.88), pigment.opacity(0.8)]),
        startPoint: CGPoint(x: 0.1, y: -0.15), endPoint: CGPoint(x: 0.1, y: 0.16)))
    var markings = context
    markings.clip(to: body)
    for x in [0.29, 0.08, -0.12, -0.34] {
      var patch = Path()
      patch.move(to: CGPoint(x: x, y: -0.17))
      patch.addCurve(
        to: CGPoint(x: x - 0.08, y: 0.11), control1: CGPoint(x: x + 0.13, y: -0.02),
        control2: CGPoint(x: x - 0.03, y: -0.015))
      patch.addCurve(
        to: CGPoint(x: x - 0.14, y: -0.13), control1: CGPoint(x: x - 0.19, y: 0.06),
        control2: CGPoint(x: x - 0.15, y: -0.01))
      patch.closeSubpath()
      markings.fill(patch, with: .color(pigment.opacity(warm ? 0.83 : 0.22)))
    }
    for row in 0..<3 {
      for column in 0..<8 {
        let x = -0.27 + Double(column) * 0.069 + Double(row % 2) * 0.03
        let y = -0.07 + Double(row) * 0.048
        var scale = Path()
        scale.move(to: CGPoint(x: x, y: y))
        scale.addQuadCurve(
          to: CGPoint(x: x, y: y + 0.043), control: CGPoint(x: x - 0.043, y: y + 0.022))
        markings.stroke(scale, with: .color(Ink.background.opacity(0.12)), lineWidth: 0.0025)
      }
    }
    var spine = Path()
    spine.move(to: CGPoint(x: 0.34, y: -0.06))
    spine.addCurve(
      to: CGPoint(x: -0.41, y: 0.039), control1: CGPoint(x: 0.13, y: -0.03),
      control2: CGPoint(x: -0.16, y: -0.02))
    context.stroke(spine, with: .color(Ink.pearl.opacity(0.48)), lineWidth: 0.006)
    var eyes = source
    eyes.translateBy(x: point.x, y: point.y)
    eyes.rotate(by: .degrees(angle))
    for side in [-1.0, 1.0] {
      eyes.fill(
        Path(
          ellipseIn: CGRect(
            x: 0.367 * length, y: (side * 0.055 - 0.0065) * length,
            width: 0.013 * length, height: 0.013 * length)),
        with: .color(Ink.background))
    }
    var tailDetail = context
    tailDetail.clip(to: tail)
    for index in 0..<7 {
      var ray = Path()
      ray.move(to: CGPoint(x: -0.44, y: 0.04))
      ray.addQuadCurve(
        to: CGPoint(x: -0.83 + Double(index) * 0.017, y: -0.17 + Double(index) * 0.077 + sway),
        control: CGPoint(x: -0.65, y: 0.01 + Double(index) * 0.017))
      tailDetail.stroke(ray, with: .color(Ink.pearl.opacity(0.24)), lineWidth: 0.002)
    }
  }

  private func leaf(
    _ source: GraphicsContext, at point: CGPoint, radius: Double, angle: Double, opacity: Double
  ) {
    var context = source
    context.translateBy(x: point.x, y: point.y)
    context.rotate(by: .degrees(angle))
    context.opacity = opacity
    let rect = CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
    let path = LilyShape().path(in: rect)
    context.fill(
      path,
      with: .linearGradient(
        Gradient(colors: [Ink.jade.opacity(0.32), Ink.deep]),
        startPoint: CGPoint(x: -radius, y: -radius), endPoint: CGPoint(x: radius, y: radius)))
    context.stroke(path, with: .color(Ink.jade.opacity(0.5)), lineWidth: 0.5)
    context.stroke(
      LilyVeins().path(in: rect), with: .color(Ink.jade.opacity(0.22)), lineWidth: 0.45)
  }

  private func blossom(_ source: GraphicsContext, at point: CGPoint, radius: Double) {
    var context = source
    context.translateBy(x: point.x, y: point.y)
    for index in 0..<9 {
      var petal = context
      petal.rotate(by: .degrees(Double(index) * 137.5))
      var shape = Path()
      shape.move(to: .zero)
      shape.addCurve(
        to: CGPoint(x: 0, y: -radius), control1: CGPoint(x: -radius * 0.6, y: -radius * 0.4),
        control2: CGPoint(x: -radius * 0.3, y: -radius * 0.8))
      shape.addCurve(
        to: .zero, control1: CGPoint(x: radius * 0.35, y: -radius * 0.8),
        control2: CGPoint(x: radius * 0.6, y: -radius * 0.3))
      petal.fill(shape, with: .color(Ink.pearl.opacity(0.22 + Double(index) * 0.07)))
      petal.stroke(shape, with: .color(Ink.pearl.opacity(0.25)), lineWidth: 0.4)
    }
    context.fill(
      Path(ellipseIn: CGRect(x: -1.5, y: -1.5, width: 3, height: 3)), with: .color(Ink.gold))
  }
}

struct LilyTarget: View {
  let lane: Int
  let progress: Double?
  let active: Bool
  let flash: Bool
  let label: String
  let action: () -> Void
  private var ready: Bool { (progress ?? 0) >= 0.82 }

  var body: some View {
    Button(action: action) {
      ZStack {
        Circle().fill(Ink.background).frame(width: 106, height: 106)
        Circle().stroke(Ink.gold.opacity(active ? 0.9 : 0.42), lineWidth: active ? 1.8 : 0.8).frame(
          width: 100, height: 100)
        ForEach(0..<4) { index in
          Rectangle().fill(Ink.gold.opacity(active ? 0.8 : 0.35)).frame(width: 1, height: 4)
            .offset(y: -53).rotationEffect(.degrees(Double(index) * 90))
        }
        LilyShape()
          .fill(
            LinearGradient(
              colors: [Ink.jade.opacity(active ? 0.6 : 0.3), Ink.deep], startPoint: .topLeading,
              endPoint: .bottomTrailing)
          )
          .overlay(LilyShape().stroke(Ink.jade.opacity(0.5), lineWidth: 0.6))
          .overlay(LilyVeins().stroke(Ink.pearl.opacity(0.09), lineWidth: 0.5))
          .frame(width: 73, height: 73)
          .rotationEffect(.degrees(Double(lane) * 120 - 25))
        if let progress {
          Circle().stroke(ready ? Ink.pearl : Ink.gold, lineWidth: ready ? 3 : 2)
            .frame(
              width: 12 + 88 * min(1.12, max(0, progress)),
              height: 12 + 88 * min(1.12, max(0, progress))
            )
            .shadow(color: Ink.gold.opacity(0.6), radius: ready ? 12 : 4)
        }
        VStack(spacing: 3) {
          Text(["I", "II", "III"][lane]).font(Ink.display(20))
          if ready { Text("TAP").font(.system(size: 8, weight: .bold)).tracking(2) }
        }
        .foregroundStyle(active ? Ink.pearl : Ink.muted)
        if flash {
          Circle().stroke(Ink.gold.opacity(0.65), lineWidth: 0.8).frame(width: 120, height: 120)
          Circle().stroke(Ink.jade.opacity(0.3), lineWidth: 0.5).frame(width: 133, height: 133)
        }
      }
      .frame(width: 124, height: 124).contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Lily \(lane + 1), \(label)")
    .accessibilityIdentifier("lily-\(lane)")
  }
}

struct LilyShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: 0.51, y: 0.55))
    path.addLine(to: CGPoint(x: 0.80, y: 0.13))
    path.addCurve(
      to: CGPoint(x: 0.98, y: 0.48), control1: CGPoint(x: 0.92, y: 0.20),
      control2: CGPoint(x: 0.96, y: 0.31))
    path.addCurve(
      to: CGPoint(x: 0.58, y: 0.98), control1: CGPoint(x: 1.02, y: 0.79),
      control2: CGPoint(x: 0.82, y: 0.92))
    path.addCurve(
      to: CGPoint(x: 0.03, y: 0.62), control1: CGPoint(x: 0.28, y: 1.01),
      control2: CGPoint(x: 0.06, y: 0.90))
    path.addCurve(
      to: CGPoint(x: 0.34, y: 0.04), control1: CGPoint(x: -0.02, y: 0.36),
      control2: CGPoint(x: 0.10, y: 0.07))
    path.addCurve(
      to: CGPoint(x: 0.75, y: 0.10), control1: CGPoint(x: 0.46, y: 0.00),
      control2: CGPoint(x: 0.66, y: 0.01))
    path.closeSubpath()
    return path.applying(
      CGAffineTransform(a: rect.width, b: 0, c: 0, d: rect.height, tx: rect.minX, ty: rect.minY))
  }
}

struct LilyVeins: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let center = CGPoint(x: rect.minX + rect.width * 0.51, y: rect.minY + rect.height * 0.55)
    for index in 0..<9 {
      let angle = Double(index) * 0.58 - 0.5
      let edge = CGPoint(
        x: rect.midX + cos(angle) * rect.width * 0.42,
        y: rect.midY + sin(angle) * rect.height * 0.42)
      path.move(to: center)
      path.addQuadCurve(
        to: edge, control: CGPoint(x: (center.x + edge.x) / 2 - 3, y: (center.y + edge.y) / 2 + 4))
    }
    return path
  }
}

struct RippleSeal: View {
  var body: some View {
    ZStack {
      Circle().trim(from: 0.10, to: 0.86).stroke(Ink.gold.opacity(0.8), lineWidth: 0.8)
        .rotationEffect(.degrees(-75))
      Circle().trim(from: 0.15, to: 0.93).stroke(Ink.gold.opacity(0.45), lineWidth: 0.6).padding(4)
        .rotationEffect(.degrees(70))
      Capsule().fill(Ink.pearl).frame(width: 3, height: 9).rotationEffect(.degrees(32))
    }
    .frame(width: 28, height: 28).accessibilityHidden(true)
  }
}

struct RhythmSignature: View {
  let composition: Composition
  var body: some View {
    Canvas { context, size in
      let notes = Array(composition.notes.prefix(7))
      var path = Path()
      for (index, note) in notes.enumerated() {
        let point = CGPoint(
          x: Double(index) / Double(max(1, notes.count - 1)) * size.width,
          y: size.height * (0.2 + Double(note.lane) * 0.3))
        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        context.fill(
          Path(ellipseIn: CGRect(x: point.x - 1.4, y: point.y - 1.4, width: 2.8, height: 2.8)),
          with: .color(Ink.gold))
      }
      context.stroke(path, with: .color(Ink.gold.opacity(0.25)), lineWidth: 0.5)
    }
    .accessibilityHidden(true)
  }
}
