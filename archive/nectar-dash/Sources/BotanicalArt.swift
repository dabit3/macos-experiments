import SwiftUI

enum NectarPalette {
  static let ink = Color(red: 0.035, green: 0.105, blue: 0.091)
  static let forest = Color(red: 0.09, green: 0.23, blue: 0.18)
  static let cream = Color(red: 0.98, green: 0.94, blue: 0.81)
  static let sage = Color(red: 0.58, green: 0.69, blue: 0.53)
  static let honey = Color(red: 0.96, green: 0.73, blue: 0.31)

  static func petal(_ color: BloomColor) -> Color {
    switch color {
    case .gold: return Color(red: 1, green: 0.79, blue: 0.37)
    case .rose: return Color(red: 0.97, green: 0.49, blue: 0.43)
    case .iris: return Color(red: 0.72, green: 0.66, blue: 0.92)
    }
  }

  static func lightPetal(_ color: BloomColor) -> Color {
    switch color {
    case .gold: return Color(red: 1, green: 0.94, blue: 0.67)
    case .rose: return Color(red: 1, green: 0.79, blue: 0.66)
    case .iris: return Color(red: 0.94, green: 0.86, blue: 1)
    }
  }
}

struct BotanicalBackdrop: View {
  var time = 0.0
  var lush = false

  var body: some View {
    Canvas { context, size in
      context.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .linearGradient(
          Gradient(colors: [NectarPalette.forest, NectarPalette.ink]),
          startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
      context.fill(
        Path(
          ellipseIn: CGRect(
            x: -size.width * 0.2, y: -120, width: size.width * 1.7, height: size.height)),
        with: .radialGradient(
          Gradient(colors: [NectarPalette.sage.opacity(0.18), .clear]),
          center: CGPoint(x: size.width * 0.85, y: size.height * 0.15),
          startRadius: 0, endRadius: size.height * 0.7))
      let branches: [(Double, Double, Double, Double)] = [
        (-0.06, 0.08, -21, 85), (1.09, 0.35, 165, 130),
        (-0.04, 0.57, -56, 165), (1.05, 0.72, 137, 115),
        (-0.07, 0.89, -18, 125), (1.08, 1.00, 213, 165),
      ]
      for (index, location) in branches.enumerated() {
        var branch = context
        branch.translateBy(x: location.0 * size.width, y: location.1 * size.height)
        branch.rotate(by: .degrees(location.2))
        BotanicalDrawing.sprig(
          in: branch, length: location.3 * (lush ? 1 : 0.8),
          color: NectarPalette.sage.opacity(index % 2 == 0 ? 0.13 : 0.08))
      }
      for index in 0..<42 {
        let x =
          Double((index * 137 + 23) % 997) / 997 * size.width
          + sin(time * 0.25 + Double(index)) * 5
        let y =
          Double((index * 229 + 89) % 991) / 991 * size.height
          + cos(time * 0.17 + Double(index)) * 7
        let radius = index % 5 == 0 ? 2.0 : 0.9
        let alpha = 0.15 + 0.2 * (sin(Double(index) + time * 0.7) + 1) / 2
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
          with: .color(NectarPalette.honey.opacity(alpha)))
      }
    }
    .accessibilityHidden(true)
  }
}

enum BotanicalDrawing {
  static func sprig(in context: GraphicsContext, length: Double, color: Color) {
    var stem = Path()
    stem.move(to: .zero)
    stem.addQuadCurve(to: CGPoint(x: length, y: 0), control: CGPoint(x: length * 0.45, y: -20))
    context.stroke(stem, with: .color(color), lineWidth: 1.3)
    for index in 1...5 {
      for side in [-1.0, 1.0] {
        let x = Double(index) * length / 6
        var leaf = Path()
        leaf.move(to: CGPoint(x: x, y: -8))
        leaf.addQuadCurve(
          to: CGPoint(x: x + length * 0.22, y: side * 35),
          control: CGPoint(x: x - 10, y: side * 43))
        leaf.addQuadCurve(
          to: CGPoint(x: x, y: -8), control: CGPoint(x: x + 36, y: side * 7))
        context.fill(leaf, with: .color(color))
      }
    }
  }

  static func flower(
    in context: GraphicsContext, at point: CGPoint, radius: Double, color: BloomColor,
    rotation: Double = 0, openness: Double = 1, active: Bool = false, number: Bool = true
  ) {
    var local = context
    local.translateBy(x: point.x, y: point.y)
    local.rotate(by: .degrees(rotation))
    if active {
      let halo = CGRect(x: -radius * 1.5, y: -radius * 1.5, width: radius * 3, height: radius * 3)
      local.fill(
        Path(ellipseIn: halo),
        with: .radialGradient(
          Gradient(colors: [NectarPalette.petal(color).opacity(0.22), .clear]),
          center: .zero, startRadius: 0, endRadius: radius * 1.5))
      local.stroke(
        Path(
          ellipseIn: CGRect(
            x: -radius * 1.17, y: -radius * 1.17, width: radius * 2.34, height: radius * 2.34)),
        with: .color(NectarPalette.cream.opacity(0.42)),
        style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
    }
    for layer in 0..<2 {
      let petalCount = color == .iris ? 6 : 9
      for index in 0..<petalCount {
        var petalContext = local
        petalContext.rotate(
          by: .degrees(Double(index) * 360 / Double(petalCount) + Double(layer) * 22))
        let r = radius * (layer == 0 ? 1 : 0.71) * (0.5 + openness * 0.5)
        let width = r * (color == .iris ? 0.49 : 0.35)
        var petal = Path()
        petal.move(to: CGPoint(x: 0, y: 7))
        petal.addCurve(
          to: CGPoint(x: 0, y: -r),
          control1: CGPoint(x: -width * 1.5, y: -r * 0.3),
          control2: CGPoint(x: -width, y: -r * 1.1))
        petal.addCurve(
          to: CGPoint(x: 0, y: 7),
          control1: CGPoint(x: width * 1.2, y: -r * 1.07),
          control2: CGPoint(x: width, y: -r * 0.3))
        petalContext.fill(
          petal,
          with: .linearGradient(
            Gradient(colors: [
              NectarPalette.lightPetal(color), NectarPalette.petal(color),
              NectarPalette.petal(color).opacity(0.45),
            ]),
            startPoint: CGPoint(x: -width, y: -r),
            endPoint: CGPoint(x: width * 0.5, y: r * 0.3)))
        petalContext.stroke(petal, with: .color(NectarPalette.cream.opacity(0.13)), lineWidth: 0.7)
        for vein in -1...1 {
          var line = Path()
          line.move(to: CGPoint(x: 0, y: 0))
          line.addQuadCurve(
            to: CGPoint(x: Double(vein) * width * 0.25, y: -r * 0.87),
            control: CGPoint(x: Double(vein) * width * 0.6, y: -r * 0.5))
          petalContext.stroke(line, with: .color(NectarPalette.cream.opacity(0.18)), lineWidth: 0.7)
        }
      }
    }
    let core = radius * 0.25
    local.fill(
      Path(ellipseIn: CGRect(x: -core, y: -core, width: core * 2, height: core * 2)),
      with: .radialGradient(
        Gradient(colors: [NectarPalette.honey, Color(red: 0.40, green: 0.26, blue: 0.12)]),
        center: .zero, startRadius: 0, endRadius: core))
    for index in 0..<23 {
      let angle = Double(index) * 2.4
      let distance = core * sqrt(Double(index) / 23)
      local.fill(
        Path(
          ellipseIn: CGRect(
            x: cos(angle) * distance - 1, y: sin(angle) * distance - 1, width: 2, height: 2)),
        with: .color(NectarPalette.lightPetal(color).opacity(0.7)))
    }
    if number {
      local.rotate(by: .degrees(-rotation))
      local.fill(
        Path(ellipseIn: CGRect(x: -10, y: -10, width: 20, height: 20)),
        with: .color(NectarPalette.ink.opacity(0.92)))
      local.draw(
        Text(color.mark).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(
          NectarPalette.cream),
        at: .zero)
    }
  }

  static func bee(
    in context: GraphicsContext, at point: CGPoint, size: Double, time: Double, angle: Double = -16
  ) {
    var local = context
    local.translateBy(x: point.x, y: point.y)
    local.rotate(by: .degrees(angle))
    let flutter = 0.88 + sin(time * 24) * 0.12
    for side in [-1.0, 1.0] {
      var wings = local
      wings.rotate(by: .degrees(side * (24 + flutter * 15)))
      let wing = Path(
        ellipseIn: CGRect(
          x: side < 0 ? -size * 1.1 : 0, y: -size * 0.9, width: size * 1.1, height: size * 0.75))
      wings.fill(
        wing,
        with: .linearGradient(
          Gradient(colors: [Color.white.opacity(0.85), NectarPalette.sage.opacity(0.25)]),
          startPoint: CGPoint(x: 0, y: -size), endPoint: .zero))
      wings.stroke(wing, with: .color(.white.opacity(0.55)), lineWidth: 1)
    }
    let body = Path(
      ellipseIn: CGRect(x: -size * 0.44, y: -size * 0.52, width: size * 0.88, height: size * 1.35))
    local.fill(
      body,
      with: .linearGradient(
        Gradient(colors: [
          NectarPalette.cream, NectarPalette.honey, Color(red: 0.72, green: 0.40, blue: 0.08),
        ]),
        startPoint: CGPoint(x: -size * 0.3, y: 0), endPoint: CGPoint(x: size * 0.6, y: 0)))
    var stripes = local
    stripes.clip(to: body)
    for stripe in 0..<3 {
      stripes.fill(
        Path(
          CGRect(
            x: -size, y: Double(stripe) * size * 0.32 - size * 0.13, width: size * 2,
            height: size * 0.14)),
        with: .color(NectarPalette.ink))
    }
    local.fill(
      Path(
        ellipseIn: CGRect(x: -size * 0.33, y: -size * 0.76, width: size * 0.66, height: size * 0.56)
      ),
      with: .color(NectarPalette.ink))
    for side in [-1.0, 1.0] {
      var antenna = Path()
      antenna.move(to: CGPoint(x: side * size * 0.16, y: -size * 0.58))
      antenna.addQuadCurve(
        to: CGPoint(x: side * size * 0.38, y: -size * 1.04),
        control: CGPoint(x: side * size * 0.07, y: -size * 1.05))
      local.stroke(
        antenna, with: .color(NectarPalette.honey),
        style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }
    local.fill(
      Path(
        ellipseIn: CGRect(x: -size * 0.18, y: -size * 0.64, width: size * 0.13, height: size * 0.09)
      ),
      with: .color(.white.opacity(0.8)))
  }

  static func hive(in context: GraphicsContext, at point: CGPoint, size: Double, ready: Bool) {
    var local = context
    local.translateBy(x: point.x, y: point.y)
    if ready {
      local.fill(
        Path(ellipseIn: CGRect(x: -size, y: -size, width: size * 2, height: size * 2)),
        with: .radialGradient(
          Gradient(colors: [NectarPalette.honey.opacity(0.25), .clear]),
          center: .zero, startRadius: 0, endRadius: size))
    }
    for index in 0..<5 {
      let width = size * (0.72 + sin(Double(index) / 4 * .pi) * 0.63)
      let y = Double(index) * size * 0.17 - size * 0.4
      let layer = Path(
        roundedRect: CGRect(x: -width / 2, y: y, width: width, height: size * 0.25),
        cornerRadius: size * 0.13)
      local.fill(
        layer,
        with: .linearGradient(
          Gradient(colors: [
            NectarPalette.cream, NectarPalette.honey, Color(red: 0.54, green: 0.31, blue: 0.1),
          ]),
          startPoint: CGPoint(x: -width / 2, y: y), endPoint: CGPoint(x: width / 2, y: y + 10)))
      local.stroke(layer, with: .color(NectarPalette.ink.opacity(0.2)), lineWidth: 1)
    }
    local.fill(
      Path(ellipseIn: CGRect(x: -size * 0.18, y: 0, width: size * 0.36, height: size * 0.43)),
      with: .color(NectarPalette.ink))
  }

  static func web(in context: GraphicsContext, at point: CGPoint, radius: Double) {
    for ring in 1...4 {
      var polygon = Path()
      for spoke in 0...8 {
        let angle = Double(spoke) * .pi / 4
        let p = CGPoint(
          x: point.x + cos(angle) * radius * Double(ring) / 4,
          y: point.y + sin(angle) * radius * Double(ring) / 4)
        if spoke == 0 { polygon.move(to: p) } else { polygon.addLine(to: p) }
      }
      context.stroke(polygon, with: .color(NectarPalette.cream.opacity(0.32)), lineWidth: 0.8)
    }
    for spoke in 0..<8 {
      let angle = Double(spoke) * .pi / 4
      var spokePath = Path()
      spokePath.move(to: point)
      spokePath.addLine(
        to: CGPoint(x: point.x + cos(angle) * radius * 1.1, y: point.y + sin(angle) * radius * 1.1))
      context.stroke(spokePath, with: .color(NectarPalette.cream.opacity(0.4)), lineWidth: 0.8)
    }
    context.fill(
      Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
      with: .color(NectarPalette.cream.opacity(0.7)))
  }
}

struct HeroGarden: View {
  var time: Double

  var body: some View {
    Canvas { context, size in
      let width = size.width
      BotanicalDrawing.flower(
        in: context, at: CGPoint(x: width * 0.14, y: size.height * 0.57),
        radius: min(width * 0.25, size.height * 0.32),
        color: .rose, rotation: -24, number: false)
      BotanicalDrawing.flower(
        in: context, at: CGPoint(x: width * 0.83, y: size.height * 0.38),
        radius: min(width * 0.24, size.height * 0.31),
        color: .gold, rotation: 16, number: false)
      BotanicalDrawing.flower(
        in: context, at: CGPoint(x: width * 0.52, y: size.height * 0.77),
        radius: min(width * 0.14, size.height * 0.20),
        color: .iris, rotation: 4, number: false)
      var route = Path()
      route.move(to: CGPoint(x: width * 0.16, y: size.height * 0.50))
      route.addCurve(
        to: CGPoint(x: width * 0.57, y: size.height * 0.30),
        control1: CGPoint(x: width * 0.60, y: size.height * 0.96),
        control2: CGPoint(x: width * 0.14, y: -size.height * 0.3))
      context.stroke(
        route, with: .color(NectarPalette.honey.opacity(0.7)),
        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 7]))
      BotanicalDrawing.bee(
        in: context,
        at: CGPoint(x: width * 0.52 + sin(time) * 3, y: size.height * 0.27 + cos(time) * 4),
        size: 26, time: time, angle: 28)
    }
    .accessibilityHidden(true)
  }
}
