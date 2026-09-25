import SwiftUI

struct OceanCanvas: View {
  let game: Game
  let selectedIsland: Int
  let selectedRoute: Int?

  static func position(_ island: Island, _ size: CGSize) -> CGPoint {
    CGPoint(x: island.x * size.width, y: 35 + island.y * (size.height - 90))
  }

  var body: some View {
    Canvas { context, size in
      context.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .linearGradient(
          Gradient(colors: [Color(hex: 0xADE0D7), Color(hex: 0x64BCBB)]),
          startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
      for index in 0..<150 {
        let x = CGFloat((index * 83 + 37) % 997) / 997 * size.width
        let y = CGFloat((index * 137 + 19) % 983) / 983 * size.height
        var wave = Path()
        wave.move(to: CGPoint(x: x, y: y))
        wave.addQuadCurve(to: CGPoint(x: x + 14, y: y), control: CGPoint(x: x + 7, y: y + 3))
        context.stroke(
          wave, with: .color(.white.opacity(index.isMultiple(of: 3) ? 0.23 : 0.12)), lineWidth: 1)
      }
      for island in game.islands {
        let p = Self.position(island, size)
        for ring in 0..<3 {
          let expansion = CGFloat(ring) * 20
          let rect = CGRect(
            x: p.x - 101 - expansion, y: p.y - 29 - expansion * 0.42,
            width: 202 + expansion * 2, height: 82 + expansion * 0.85)
          context.stroke(
            Path(ellipseIn: rect), with: .color(.white.opacity(0.20 - Double(ring) * 0.05)),
            lineWidth: ring == 0 ? 6 : 1)
        }
      }
      for route in game.routes {
        let a = dock(game.islands[route.source], size)
        let b = dock(game.islands[route.destination], size)
        let control = controlPoint(a, b)
        var path = Path()
        path.move(to: a)
        path.addQuadCurve(to: b, control: control)
        context.stroke(
          path, with: .color(.white.opacity(0.6)), lineWidth: selectedRoute == route.id ? 7 : 5)
        context.stroke(
          path, with: .color(Palette.resource(route.resource)),
          style: StrokeStyle(
            lineWidth: selectedRoute == route.id ? 3 : 2, lineCap: .round,
            dash: route.ferryID == nil ? [4, 6] : []))
        let center = interpolate(a, control, b, 0.5)
        context.fill(
          Path(ellipseIn: CGRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20)),
          with: .color(Palette.cream))
        context.draw(
          Text("\(route.id + 1)").font(.system(size: 9, weight: .bold)).foregroundColor(
            Palette.ink), at: center)
      }
      for island in game.islands.sorted(by: { $0.y < $1.y }) {
        drawIsland(
          context: &context, island: island, point: Self.position(island, size),
          selected: selectedRoute == nil && selectedIsland == island.id)
      }
      for route in game.routes where route.ferryID != nil {
        let a = dock(game.islands[route.source], size)
        let b = dock(game.islands[route.destination], size)
        let control = controlPoint(a, b)
        let t = route.returning ? 1 - route.progress : route.progress
        let position = interpolate(a, control, b, t)
        let tangent = CGPoint(
          x: 2 * (1 - t) * (control.x - a.x) + 2 * t * (b.x - control.x),
          y: 2 * (1 - t) * (control.y - a.y) + 2 * t * (b.y - control.y))
        let angle = atan2(tangent.y, tangent.x) + (route.returning ? .pi : 0)
        drawBoat(
          context: &context, point: position, angle: angle, color: Palette.resource(route.resource),
          loaded: route.cargo > 0)
      }
      // Small uninhabited islets give the chart a sense of scale.
      for (x, y) in [(0.08, 0.48), (0.56, 0.15), (0.58, 0.86), (0.93, 0.47)] {
        let p = CGPoint(x: x * size.width, y: y * size.height)
        context.fill(
          Path(ellipseIn: CGRect(x: p.x - 15, y: p.y - 5, width: 36, height: 15)),
          with: .color(Color(hex: 0xD9D9AF)))
        tree(&context, x: p.x, y: p.y - 4, scale: 0.65)
      }
    }.accessibilityHidden(true)
  }

  private func dock(_ island: Island, _ size: CGSize) -> CGPoint {
    let point = Self.position(island, size)
    return CGPoint(x: point.x + 33, y: point.y + 41)
  }

  private func controlPoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
    CGPoint(
      x: (a.x + b.x) / 2 - (b.y - a.y) * 0.15,
      y: (a.y + b.y) / 2 + (b.x - a.x) * 0.15)
  }

  private func interpolate(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
    CGPoint(
      x: (1 - t) * (1 - t) * a.x + 2 * (1 - t) * t * c.x + t * t * b.x,
      y: (1 - t) * (1 - t) * a.y + 2 * (1 - t) * t * c.y + t * t * b.y)
  }

  private func polygon(_ context: inout GraphicsContext, _ points: [CGPoint], _ color: Color) {
    var path = Path()
    path.addLines(points)
    path.closeSubpath()
    context.fill(path, with: .color(color))
  }

  private func drawIsland(
    context: inout GraphicsContext, island: Island, point: CGPoint, selected: Bool
  ) {
    var c = context
    c.translateBy(x: point.x, y: point.y)
    let outline: [CGPoint] = [
      CGPoint(x: -87, y: -5), CGPoint(x: -63, y: -31), CGPoint(x: -13, y: -45),
      CGPoint(x: 46, y: -32), CGPoint(x: 83, y: -10), CGPoint(x: 88, y: 13),
      CGPoint(x: 49, y: 36), CGPoint(x: -11, y: 43), CGPoint(x: -68, y: 22),
    ]
    context.fill(
      Path(ellipseIn: CGRect(x: point.x - 80, y: point.y + 9, width: 183, height: 46)),
      with: .color(Color(hex: 0x368F8B).opacity(0.18)))
    polygon(&c, outline.map { CGPoint(x: $0.x, y: $0.y + 12) }, Color(hex: 0xBAAF83))
    polygon(&c, outline, Color(hex: 0xE9DDB1))
    polygon(
      &c, outline.map { CGPoint(x: $0.x * 0.83, y: $0.y * 0.8 - 3) },
      island.id == 3 ? Color(hex: 0xBDCAA6) : Color(hex: 0xACCA99))
    if selected {
      var rim = Path()
      rim.addLines(outline.map { CGPoint(x: $0.x * 1.05, y: $0.y * 1.05 + 4) })
      rim.closeSubpath()
      c.stroke(
        rim, with: .color(Palette.cream.opacity(0.95)),
        style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
    }
    polygon(
      &c,
      [CGPoint(x: 6, y: 3), CGPoint(x: 15, y: -1), CGPoint(x: 43, y: 29), CGPoint(x: 32, y: 34)],
      Color(hex: 0xEFE3BF))
    polygon(
      &c,
      [CGPoint(x: 19, y: 28), CGPoint(x: 35, y: 24), CGPoint(x: 57, y: 47), CGPoint(x: 40, y: 53)],
      Color(hex: 0xF7EBC9))
    for i in 0..<5 {
      var plank = Path()
      let y = CGFloat(i) * 4
      plank.move(to: CGPoint(x: 23 + y * 0.7, y: 31 + y))
      plank.addLine(to: CGPoint(x: 38 + y * 0.7, y: 27 + y))
      c.stroke(plank, with: .color(Color(hex: 0xC4B88E)), lineWidth: 1)
    }
    for p in [CGPoint(x: 39, y: 50), CGPoint(x: 55, y: 45)] {
      c.fill(
        Path(roundedRect: CGRect(x: p.x, y: p.y - 6, width: 3, height: 10), cornerRadius: 1),
        with: .color(Color(hex: 0x90896D)))
    }
    switch island.id {
    case 0:
      for i in 0..<4 {
        let x = CGFloat(i) * 13 - 55
        polygon(
          &c,
          [
            CGPoint(x: x, y: -6), CGPoint(x: x + 13, y: -13),
            CGPoint(x: x + 34, y: -1), CGPoint(x: x + 21, y: 6),
          ], Color(hex: i.isMultiple(of: 2) ? 0xDEBA65 : 0xE9CB7D))
      }
      building(&c, x: 15, y: -9, scale: 1.15)
      building(&c, x: 43, y: 7, scale: 0.65)
      windmill(&c, x: -25, y: -21)
      tree(&c, x: -59, y: 10, scale: 0.7)
    case 1:
      building(&c, x: -20, y: -7, scale: 1.2)
      building(&c, x: 13, y: -19, scale: 1)
      building(&c, x: 45, y: 1, scale: 0.8)
      building(&c, x: -44, y: 10, scale: 0.75)
      tree(&c, x: -61, y: -7, scale: 0.8)
      tree(&c, x: 4, y: 20, scale: 0.65)
    case 2:
      for (x, y, s) in [
        (-45.0, -5.0, 1.0), (-22, -21, 1.2), (5, -26, 0.85), (-50, 15, 0.8), (24, -10, 1.1),
      ] {
        tree(&c, x: x, y: y, scale: s)
      }
      building(&c, x: 10, y: 15, scale: 0.9)
      for i in 0..<3 {
        c.fill(
          Path(roundedRect: CGRect(x: -22, y: 11 + i * 5, width: 21, height: 4), cornerRadius: 2),
          with: .color(Color(hex: 0xA77955)))
      }
    case 3:
      for (x, y, s) in [(-34.0, -7.0, 1.0), (-9, -17, 1.15), (-43, 11, 0.65)] {
        polygon(
          &c,
          [
            CGPoint(x: x - 16 * s, y: y), CGPoint(x: x - 3 * s, y: y - 25 * s),
            CGPoint(x: x + 16 * s, y: y - 7 * s), CGPoint(x: x + 15 * s, y: y + 7 * s),
          ],
          Color(hex: 0xAFACA2))
        polygon(
          &c,
          [
            CGPoint(x: x - 3 * s, y: y - 25 * s), CGPoint(x: x + 16 * s, y: y - 7 * s),
            CGPoint(x: x + 15 * s, y: y + 7 * s), CGPoint(x: x + 2 * s, y: y),
          ],
          Color(hex: 0xCBC9BD))
      }
      building(&c, x: 33, y: 9, scale: 1)
      tree(&c, x: 54, y: -11, scale: 0.65)
    default:
      building(&c, x: -31, y: 6, scale: 0.85)
      tree(&c, x: -51, y: -12, scale: 0.9)
      tree(&c, x: 46, y: 8, scale: 0.6)
      lighthouse(&c, lit: !island.underserved)
    }
  }

  private func building(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat) {
    var c = context
    c.translateBy(x: x, y: y)
    c.scaleBy(x: scale, y: scale)
    polygon(
      &c,
      [
        CGPoint(x: -17, y: -21), CGPoint(x: 3, y: -13), CGPoint(x: 3, y: 10), CGPoint(x: -17, y: 1),
      ],
      Color(hex: 0xF5E7C9))
    polygon(
      &c,
      [CGPoint(x: 3, y: -13), CGPoint(x: 21, y: -24), CGPoint(x: 21, y: -1), CGPoint(x: 3, y: 10)],
      Color(hex: 0xD5C7A9))
    polygon(
      &c,
      [
        CGPoint(x: -22, y: -22), CGPoint(x: -8, y: -39), CGPoint(x: 13, y: -30),
        CGPoint(x: 3, y: -11),
      ],
      Color(hex: 0xD78869))
    polygon(
      &c,
      [
        CGPoint(x: -8, y: -39), CGPoint(x: 13, y: -30), CGPoint(x: 26, y: -24),
        CGPoint(x: 3, y: -11),
      ],
      Color(hex: 0xB7654E))
    polygon(
      &c,
      [
        CGPoint(x: -12, y: -14), CGPoint(x: -6, y: -11), CGPoint(x: -6, y: -5),
        CGPoint(x: -12, y: -8),
      ],
      Color(hex: 0x57817D))
    polygon(
      &c,
      [CGPoint(x: 8, y: -7), CGPoint(x: 14, y: -11), CGPoint(x: 14, y: 3), CGPoint(x: 8, y: 6)],
      Color(hex: 0x786D5B))
    c.fill(Path(CGRect(x: 11, y: -38, width: 4, height: 9)), with: .color(Color(hex: 0xEAD5B9)))
  }

  private func tree(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat) {
    var c = context
    c.translateBy(x: x, y: y)
    c.scaleBy(x: scale, y: scale)
    c.fill(Path(CGRect(x: -2, y: -9, width: 4, height: 14)), with: .color(Color(hex: 0x917F58)))
    for i in 0..<3 {
      let y = CGFloat(i) * -8
      let width = CGFloat(14 - i * 3)
      polygon(
        &c, [CGPoint(x: -width, y: y), CGPoint(x: 0, y: y - 21), CGPoint(x: width, y: y)],
        Color(hex: i == 1 ? 0x4E9277 : 0x3E7C67))
    }
  }

  private func windmill(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat) {
    polygon(
      &context,
      [
        CGPoint(x: x - 7, y: y), CGPoint(x: x - 4, y: y - 33),
        CGPoint(x: x + 5, y: y - 33), CGPoint(x: x + 8, y: y),
      ], Color(hex: 0xF5ECD7))
    let center = CGPoint(x: x, y: y - 30)
    var blades = Path()
    blades.move(to: CGPoint(x: center.x - 18, y: center.y - 16))
    blades.addLine(to: CGPoint(x: center.x + 18, y: center.y + 16))
    blades.move(to: CGPoint(x: center.x + 16, y: center.y - 18))
    blades.addLine(to: CGPoint(x: center.x - 16, y: center.y + 18))
    context.stroke(
      blades, with: .color(Color(hex: 0xFDF8E9)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
    context.fill(
      Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)),
      with: .color(Palette.coral))
  }

  private func lighthouse(_ c: inout GraphicsContext, lit: Bool) {
    polygon(
      &c,
      [CGPoint(x: 1, y: 8), CGPoint(x: 7, y: -50), CGPoint(x: 20, y: -50), CGPoint(x: 27, y: 8)],
      Color(hex: 0xFBF1D9))
    polygon(
      &c,
      [
        CGPoint(x: 4, y: -12), CGPoint(x: 6, y: -27), CGPoint(x: 23, y: -27),
        CGPoint(x: 25, y: -12),
      ],
      Palette.coral)
    c.fill(
      Path(CGRect(x: 6, y: -60, width: 16, height: 12)),
      with: .color(lit ? Color(hex: 0xF8DD81) : Palette.teal))
    polygon(
      &c, [CGPoint(x: 2, y: -61), CGPoint(x: 14, y: -71), CGPoint(x: 27, y: -61)], Palette.coral)
    if lit {
      polygon(
        &c, [CGPoint(x: 19, y: -56), CGPoint(x: 90, y: -80), CGPoint(x: 90, y: -39)],
        Color(hex: 0xFFF4B7).opacity(0.35))
    }
  }

  private func drawBoat(
    context: inout GraphicsContext, point: CGPoint, angle: Double, color: Color, loaded: Bool
  ) {
    var c = context
    c.translateBy(x: point.x, y: point.y)
    c.rotate(by: .radians(angle))
    for i in 0..<3 {
      c.stroke(
        Path(ellipseIn: CGRect(x: -25 - i * 7, y: -4 - i * 2, width: 10, height: 8 + i * 4)),
        with: .color(.white.opacity(0.3 - Double(i) * 0.07)), lineWidth: 2)
    }
    c.fill(
      Path(ellipseIn: CGRect(x: -19, y: -6, width: 40, height: 18)),
      with: .color(Palette.teal.opacity(0.25)))
    polygon(
      &c,
      [
        CGPoint(x: -18, y: -8), CGPoint(x: 10, y: -8), CGPoint(x: 22, y: 0),
        CGPoint(x: 10, y: 8), CGPoint(x: -18, y: 8),
      ], Palette.cream)
    c.fill(
      Path(roundedRect: CGRect(x: -9, y: -5, width: 16, height: 10), cornerRadius: 2),
      with: .color(color))
    c.fill(Path(CGRect(x: 8, y: -4, width: 3, height: 8)), with: .color(Palette.teal))
    if loaded {
      c.fill(Path(CGRect(x: -15, y: -3, width: 4, height: 6)), with: .color(Palette.gold))
    }
  }
}
