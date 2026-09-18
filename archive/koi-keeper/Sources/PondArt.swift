import SwiftUI

enum PondPalette {
  static let paper = Color(hex: 0xF6F0DE)
  static let ink = Color(hex: 0x193F37)
  static let muted = Color(hex: 0x65776A)
  static let gold = Color(hex: 0xBA7134)
  static let jade = Color(hex: 0x347D72)
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
  }
}

struct PondCanvas: View {
  @ObservedObject var model: PondModel
  @ObservedObject var engine: PondEngine
  var reduceMotion: Bool
  var editing: Bool
  var editingMaxY: Double = 0.78
  var previewKind: GardenKind?
  var previewPoint: PondPoint?
  var previewValid = false

  var body: some View {
    Canvas { context, size in
      let time = reduceMotion ? 0 : engine.time
      let rect = CGRect(origin: .zero, size: size)
      context.fill(
        Path(rect),
        with: .linearGradient(
          Gradient(colors: [
            Color(hex: 0x879B68), Color(hex: 0x55A68C), Color(hex: 0x1C756A), Color(hex: 0x174D46),
          ]),
          startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
      let sun = CGPoint(x: size.width * 0.12, y: size.height * 0.27)
      context.fill(
        Path(rect),
        with: .radialGradient(
          Gradient(colors: [Color(hex: 0xFCE8A5).opacity(0.40), .clear]),
          center: sun, startRadius: 0, endRadius: size.height * 0.65))
      drawWaterLight(context: context, size: size, time: time)
      for index in 0..<35 {
        let x = (sin(Double(index) * 73.13) + 1) / 2 * size.width
        let y = (cos(Double(index) * 31.73) + 1) / 2 * size.height
        let r = Double(index % 3 + 1) * 0.6
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
          with: .color(.white.opacity(0.16)))
      }
      drawShore(context: context, size: size)
      for swimmer in engine.swimmers {
        var shadow = context
        shadow.translateBy(
          x: swimmer.point.x * size.width + 9, y: swimmer.point.y * size.height + 15)
        shadow.rotate(by: .radians(swimmer.heading))
        shadow.addFilter(.blur(radius: 6))
        shadow.opacity = 0.25
        KoiArt.draw(
          context: shadow, kind: swimmer.kind, time: time + swimmer.phase, scale: size.width / 410,
          shadow: true)
      }
      for swimmer in engine.swimmers {
        var fish = context
        fish.translateBy(x: swimmer.point.x * size.width, y: swimmer.point.y * size.height)
        fish.rotate(by: .radians(swimmer.heading))
        KoiArt.draw(
          context: fish, kind: swimmer.kind, time: time + swimmer.phase, scale: size.width / 410)
      }
      for item in model.save.garden {
        var gardenContext = context
        gardenContext.translateBy(x: item.point.x * size.width, y: item.point.y * size.height)
        GardenArt.draw(context: gardenContext, kind: item.kind, scale: size.width / 410)
      }
      for food in model.food {
        let point = CGPoint(x: food.point.x * size.width, y: food.point.y * size.height)
        let ripple = 8 + food.age.truncatingRemainder(dividingBy: 3) * 5
        context.stroke(
          Path(
            ellipseIn: CGRect(
              x: point.x - ripple, y: point.y - ripple * 0.5, width: ripple * 2, height: ripple)),
          with: .color(PondPalette.paper.opacity(0.18)), lineWidth: 1)
        context.fill(
          Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
          with: .color(Color(hex: 0xF4C97A)))
        context.fill(
          Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 2, height: 2)),
          with: .color(.white.opacity(0.75)))
      }
      if editing {
        let area = CGRect(
          x: size.width * 0.10, y: size.height * 0.20, width: size.width * 0.80,
          height: size.height * (editingMaxY - 0.20))
        context.stroke(
          Path(roundedRect: area, cornerRadius: 25), with: .color(PondPalette.paper.opacity(0.6)),
          style: StrokeStyle(lineWidth: 1, dash: [3, 8]))
        var guides = context
        guides.clip(to: Path(roundedRect: area, cornerRadius: 25))
        for item in model.save.garden {
          let exclusion = CGRect(
            x: (item.point.x - 0.12) * size.width, y: (item.point.y - 0.12) * size.height,
            width: size.width * 0.24, height: size.height * 0.24)
          guides.stroke(
            Path(ellipseIn: exclusion), with: .color(PondPalette.paper.opacity(0.25)),
            style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
        }
      }
      if let previewKind, let previewPoint {
        var ghost = context
        ghost.translateBy(x: previewPoint.x * size.width, y: previewPoint.y * size.height)
        let ring = Path(ellipseIn: CGRect(x: -42, y: -42, width: 84, height: 84))
        let color = previewValid ? PondPalette.paper : Color(hex: 0xFFD0AB)
        ghost.fill(ring, with: .color(PondPalette.ink.opacity(0.20)))
        ghost.stroke(ring, with: .color(color), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
        ghost.opacity = 0.8
        GardenArt.draw(context: ghost, kind: previewKind, scale: 0.8)
      }
    }
    .accessibilityHidden(true)
    .drawingGroup()
  }

  private func drawWaterLight(context: GraphicsContext, size: CGSize, time: Double) {
    var light = context
    light.addFilter(.blur(radius: 14))
    for ray in 0..<5 {
      let start = Double(ray) * 66 - 90
      var shaft = Path()
      shaft.move(to: CGPoint(x: start, y: -30))
      shaft.addLine(to: CGPoint(x: start + 55, y: -30))
      shaft.addLine(to: CGPoint(x: start + 350, y: size.height * 0.79))
      shaft.addLine(to: CGPoint(x: start + 220, y: size.height * 0.79))
      shaft.closeSubpath()
      light.fill(
        shaft,
        with: .linearGradient(
          Gradient(colors: [Color(hex: 0xFFF1B7).opacity(0.07), .clear]),
          startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.8)))
    }
    for index in 0..<18 {
      let center = CGPoint(
        x: (sin(Double(index) * 23.4) + 1) * 0.5 * size.width,
        y: (cos(Double(index) * 43.9) + 1) * 0.5 * size.height)
      let radius = Double(28 + index % 5 * 14)
      var caustic = Path()
      for step in 0...60 {
        let angle = Double(step) / 60 * .pi * 2
        let wobble = 1 + sin(angle * 3 + Double(index) + time * 0.2) * 0.18
        let point = CGPoint(
          x: center.x + cos(angle) * radius * wobble,
          y: center.y + sin(angle) * radius * wobble * 0.65)
        if step == 0 { caustic.move(to: point) } else { caustic.addLine(to: point) }
      }
      var refracted = context
      refracted.addFilter(.blur(radius: 0.7))
      refracted.stroke(caustic, with: .color(Color(hex: 0xC5EBC6).opacity(0.075)), lineWidth: 1.1)
    }
  }

  private func drawShore(context: GraphicsContext, size: CGSize) {
    for index in 0..<9 {
      var stone = context
      let top = index < 5
      stone.translateBy(
        x: top ? size.width + 4 - Double(index) * 19 : Double(index - 5) * 20 - 8,
        y: top
          ? size.height * 0.20 + Double(index) * 13 : size.height * 0.83 + Double(index - 5) * 9)
      stone.rotate(by: .radians(Double(index) * 0.7))
      GardenArt.draw(context: stone, kind: .stone, scale: 0.65)
    }
    for side in 0..<2 {
      var reeds = context
      reeds.translateBy(
        x: side == 0 ? -7 : size.width + 7, y: side == 0 ? size.height * 0.38 : size.height * 0.70)
      reeds.rotate(by: .degrees(side == 0 ? 65 : -80))
      GardenArt.draw(context: reeds, kind: .iris, scale: 1.1)
    }
  }
}

enum KoiArt {
  static func draw(
    context: GraphicsContext, kind: KoiKind, time: Double, scale: Double = 1, shadow: Bool = false
  ) {
    var context = context
    context.scaleBy(x: scale, y: scale)
    let swing = sin(time * 3.8) * 7
    var body = Path()
    body.move(to: CGPoint(x: 39, y: 0))
    body.addCurve(
      to: CGPoint(x: -37, y: swing * 0.4), control1: CGPoint(x: 35, y: -24),
      control2: CGPoint(x: -11, y: -19))
    body.addCurve(
      to: CGPoint(x: 39, y: 0), control1: CGPoint(x: -10, y: 21), control2: CGPoint(x: 35, y: 22))
    var tail = Path()
    tail.move(to: CGPoint(x: -28, y: swing * 0.3))
    tail.addQuadCurve(to: CGPoint(x: -65, y: swing - 19), control: CGPoint(x: -54, y: swing - 8))
    tail.addQuadCurve(to: CGPoint(x: -56, y: swing), control: CGPoint(x: -64, y: swing - 2))
    tail.addQuadCurve(to: CGPoint(x: -65, y: swing + 19), control: CGPoint(x: -66, y: swing + 6))
    tail.addQuadCurve(to: CGPoint(x: -28, y: swing * 0.3), control: CGPoint(x: -47, y: swing + 11))
    let base: Color
    let patch: Color
    switch kind {
    case .kohaku:
      base = Color(hex: 0xFFF7DC)
      patch = Color(hex: 0xD54D2B)
    case .yamabuki:
      base = Color(hex: 0xF0BF58)
      patch = Color(hex: 0xCC862D)
    case .showa:
      base = Color(hex: 0xF1E9D4)
      patch = Color(hex: 0xD35B38)
    case .asagi:
      base = Color(hex: 0x9BBDB8)
      patch = Color(hex: 0x416C7C)
    }
    if shadow {
      context.fill(body, with: .color(.black))
      context.fill(tail, with: .color(.black))
      return
    }
    let finColor = kind == .asagi ? Color(hex: 0xD98C68) : base
    context.fill(tail, with: .color(finColor.opacity(0.88)))
    for side in [-1.0, 1.0] {
      var fin = Path()
      fin.move(to: CGPoint(x: 14, y: side * 10))
      fin.addQuadCurve(
        to: CGPoint(x: -8, y: side * (30 + sin(time * 4) * 2)),
        control: CGPoint(x: 11, y: side * 29))
      fin.addQuadCurve(to: CGPoint(x: -2, y: side * 12), control: CGPoint(x: -17, y: side * 27))
      context.fill(fin, with: .color(finColor.opacity(0.80)))
      context.stroke(fin, with: .color(.white.opacity(0.18)), lineWidth: 0.7)
      for ray in 0..<4 {
        var line = Path()
        line.move(to: CGPoint(x: 10, y: side * 12))
        line.addLine(to: CGPoint(x: -6 + Double(ray) * 4, y: side * (28 - Double(ray) * 3)))
        context.stroke(line, with: .color(patch.opacity(0.20)), lineWidth: 0.7)
      }
    }
    context.fill(
      body,
      with: .linearGradient(
        Gradient(colors: [base, base, patch.opacity(0.95)]), startPoint: CGPoint(x: 0, y: -16),
        endPoint: CGPoint(x: 0, y: 25)))
    var markings = context
    markings.clip(to: body)
    for index in 0..<4 {
      let x = 23.0 - Double(index) * 18
      let y = index % 2 == 0 ? -11.0 : -4.0
      let color = kind == .showa && index % 2 == 1 ? Color(hex: 0x293B38) : patch
      if kind != .yamabuki {
        var spot = Path()
        spot.move(to: CGPoint(x: x - 8, y: y))
        spot.addCurve(
          to: CGPoint(x: x + 10, y: y + 5), control1: CGPoint(x: x - 9, y: y - 12),
          control2: CGPoint(x: x + 12, y: y - 7))
        spot.addCurve(
          to: CGPoint(x: x - 8, y: y), control1: CGPoint(x: x + 7, y: y + 23),
          control2: CGPoint(x: x - 16, y: y + 12))
        markings.fill(spot, with: .color(color))
      }
    }
    for row in 0..<5 {
      for col in 0..<8 {
        let x = -28.0 + Double(col) * 7 + Double(row % 2) * 3
        let y = -13.0 + Double(row) * 6
        var scaleLine = Path()
        scaleLine.move(to: CGPoint(x: x, y: y))
        scaleLine.addQuadCurve(to: CGPoint(x: x, y: y + 6), control: CGPoint(x: x - 4, y: y + 3))
        markings.stroke(
          scaleLine, with: .color(Color.white.opacity(kind == .asagi ? 0.36 : 0.15)), lineWidth: 0.6
        )
      }
    }
    var spine = Path()
    spine.move(to: CGPoint(x: 24, y: -3))
    spine.addQuadCurve(to: CGPoint(x: -26, y: swing * 0.25), control: CGPoint(x: 0, y: -4))
    context.stroke(spine, with: .color(.white.opacity(0.30)), lineWidth: 1.5)
    for side in [-1.0, 1.0] {
      context.fill(
        Path(ellipseIn: CGRect(x: 27, y: side * 8 - 2, width: 4.5, height: 4.5)),
        with: .color(Color(hex: 0x23362F)))
      context.fill(
        Path(ellipseIn: CGRect(x: 28.5, y: side * 8 - 1.4, width: 1.2, height: 1.2)),
        with: .color(.white))
      var barbel = Path()
      barbel.move(to: CGPoint(x: 36, y: side * 3))
      barbel.addQuadCurve(to: CGPoint(x: 40, y: side * 8), control: CGPoint(x: 43, y: side * 3))
      context.stroke(barbel, with: .color(base.opacity(0.65)), lineWidth: 0.8)
    }
  }
}

struct KoiPortrait: View {
  let kind: KoiKind
  var body: some View {
    Canvas { context, size in
      var context = context
      context.translateBy(x: size.width * 0.55, y: size.height * 0.5)
      context.rotate(by: .degrees(-25))
      KoiArt.draw(
        context: context, kind: kind, time: 0, scale: min(size.width / 130, size.height / 75))
    }
    .accessibilityLabel("\(kind.name) koi, \(kind.subtitle)")
  }
}

enum GardenArt {
  static func draw(context: GraphicsContext, kind: GardenKind, scale: Double = 1) {
    var context = context
    context.scaleBy(x: scale, y: scale)
    switch kind {
    case .lily:
      for index in 0..<3 {
        var leaf = context
        leaf.translateBy(x: Double(index - 1) * 22, y: index == 1 ? -9 : 11)
        leaf.rotate(by: .degrees(Double(index) * 103))
        let r = index == 1 ? 27.0 : 20.0
        var shape = Path()
        shape.move(to: .zero)
        shape.addArc(
          center: .zero, radius: r, startAngle: .degrees(25), endAngle: .degrees(345),
          clockwise: false)
        shape.closeSubpath()
        var shadow = leaf
        shadow.translateBy(x: 6, y: 9)
        shadow.addFilter(.blur(radius: 4))
        shadow.fill(shape, with: .color(Color(hex: 0x133D32).opacity(0.45)))
        leaf.fill(
          shape,
          with: .linearGradient(
            Gradient(colors: [Color(hex: 0xA1B669), Color(hex: 0x3D7751)]),
            startPoint: CGPoint(x: -r, y: -r), endPoint: CGPoint(x: r, y: r)))
        leaf.stroke(shape, with: .color(Color(hex: 0xC0C987).opacity(0.6)), lineWidth: 0.7)
        for vein in 0..<9 {
          let angle = Double(vein) * 0.6 + 0.5
          var line = Path()
          line.move(to: .zero)
          line.addQuadCurve(
            to: CGPoint(x: cos(angle) * r * 0.92, y: sin(angle) * r * 0.92),
            control: CGPoint(x: cos(angle + 0.3) * r * 0.5, y: sin(angle + 0.3) * r * 0.5))
          leaf.stroke(line, with: .color(Color(hex: 0xD6D89D).opacity(0.25)), lineWidth: 0.65)
        }
      }
      for ring in 0..<2 {
        for petal in 0..<8 {
          var flower = context
          flower.translateBy(x: 8, y: -13)
          flower.rotate(by: .degrees(Double(petal) * 45 + Double(ring) * 22))
          let length = ring == 0 ? 17.0 : 12.0
          var shape = Path()
          shape.move(to: CGPoint(x: 0, y: 3))
          shape.addQuadCurve(to: CGPoint(x: 0, y: -length), control: CGPoint(x: -9, y: -8))
          shape.addQuadCurve(to: CGPoint(x: 0, y: 3), control: CGPoint(x: 9, y: -8))
          flower.fill(
            shape,
            with: .linearGradient(
              Gradient(colors: [Color(hex: 0xFFF0DC), Color(hex: 0xCE8A8C)]),
              startPoint: CGPoint(x: 0, y: -length), endPoint: .zero))
        }
      }
      context.fill(
        Path(ellipseIn: CGRect(x: 4, y: -17, width: 8, height: 8)),
        with: .color(Color(hex: 0xE2B955)))
    case .stone:
      var shape = Path()
      shape.move(to: CGPoint(x: -29, y: -10))
      shape.addQuadCurve(to: CGPoint(x: -3, y: -24), control: CGPoint(x: -25, y: -27))
      shape.addQuadCurve(to: CGPoint(x: 28, y: -6), control: CGPoint(x: 24, y: -24))
      shape.addQuadCurve(to: CGPoint(x: 13, y: 22), control: CGPoint(x: 39, y: 17))
      shape.addQuadCurve(to: CGPoint(x: -29, y: -10), control: CGPoint(x: -35, y: 27))
      var shadow = context
      shadow.translateBy(x: 6, y: 9)
      shadow.addFilter(.blur(radius: 5))
      shadow.fill(shape, with: .color(.black.opacity(0.24)))
      context.fill(
        shape,
        with: .linearGradient(
          Gradient(colors: [Color(hex: 0xB4B39A), Color(hex: 0x6C7E6C), Color(hex: 0x435F54)]),
          startPoint: CGPoint(x: -20, y: -25), endPoint: CGPoint(x: 24, y: 25)))
      context.stroke(shape, with: .color(Color(hex: 0xC8C6A6).opacity(0.6)), lineWidth: 1)
      for index in 0..<5 {
        context.fill(
          Path(
            ellipseIn: CGRect(
              x: -18 + Double(index) * 7, y: -11 + sin(Double(index) * 4) * 6, width: 5, height: 2)),
          with: .color(.white.opacity(0.1)))
      }
    case .iris:
      for index in 0..<9 {
        let x = sin(Double(index) * 2.4) * 32
        let y = -35 - Double(index % 3) * 14
        var blade = Path()
        blade.move(to: CGPoint(x: 0, y: 18))
        blade.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x * 0.2 - 7, y: -21))
        blade.addQuadCurve(to: CGPoint(x: 4, y: 18), control: CGPoint(x: x * 0.5 + 9, y: -10))
        context.fill(
          blade, with: .color(index % 2 == 0 ? Color(hex: 0x365E3D) : Color(hex: 0x81A160)))
      }
      for index in 0..<3 {
        var flower = context
        flower.translateBy(x: Double(index - 1) * 18, y: -31 - Double(index % 2) * 14)
        for petal in 0..<3 {
          var rotated = flower
          rotated.rotate(by: .degrees(Double(petal) * 120))
          rotated.fill(
            Path(ellipseIn: CGRect(x: -5, y: -13, width: 10, height: 17)),
            with: .color(Color(hex: 0xC1A6CD)))
        }
        flower.fill(
          Path(ellipseIn: CGRect(x: -2, y: -2, width: 4, height: 4)),
          with: .color(Color(hex: 0xEDC868)))
      }
    }
  }
}

struct GardenPortrait: View {
  let kind: GardenKind
  var body: some View {
    Canvas { context, size in
      var context = context
      context.translateBy(x: size.width / 2, y: size.height * 0.6)
      GardenArt.draw(context: context, kind: kind, scale: min(size.width / 110, size.height / 95))
    }
    .accessibilityHidden(true)
  }
}
