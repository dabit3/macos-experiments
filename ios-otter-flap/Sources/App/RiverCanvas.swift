import SwiftUI

struct RiverCanvas: View {
  let engine: FlapEngine

  var body: some View {
    Canvas { context, size in
      let scale = size.height / FlapEngine.height
      context.scaleBy(x: scale, y: scale)
      let world = CGSize(width: engine.width, height: FlapEngine.height)
      drawSky(&context, world)
      drawHills(&context, world)
      for gate in engine.gates { drawGate(&context, gate) }
      drawWater(&context, world)
      drawOtter(&context)
    }
    .ignoresSafeArea()
  }

  private var scroll: Double { engine.distance }

  private func drawSky(_ context: inout GraphicsContext, _ world: CGSize) {
    let rect = CGRect(origin: .zero, size: world)
    context.fill(
      Path(rect),
      with: .linearGradient(
        Gradient(colors: [Palette.skyTop, Palette.skyMid, Palette.skyLow]),
        startPoint: .zero, endPoint: CGPoint(x: 0, y: FlapEngine.waterLine)))
    let sun = CGPoint(x: world.width * 0.76, y: 250)
    context.fill(
      Path(ellipseIn: CGRect(x: sun.x - 90, y: sun.y - 90, width: 180, height: 180)),
      with: .color(Palette.sun.opacity(0.35)))
    context.fill(
      Path(ellipseIn: CGRect(x: sun.x - 52, y: sun.y - 52, width: 104, height: 104)),
      with: .color(Palette.sun))
    let clouds: [(Double, Double, Double)] = [
      (40, 110, 1), (260, 70, 0.8), (480, 150, 1.2), (700, 90, 0.9),
    ]
    let span = world.width + 360
    for (x, y, s) in clouds {
      let cx = (x - scroll * 0.08).truncatingRemainder(dividingBy: span)
      let px = cx < -180 ? cx + span : cx
      drawCloud(&context, CGPoint(x: px, y: y), s)
    }
  }

  private func drawCloud(_ context: inout GraphicsContext, _ at: CGPoint, _ s: Double) {
    var path = Path()
    for (dx, dy, r) in [(0.0, 0.0, 26.0), (30, -12, 32), (64, 0, 24), (32, 8, 26)] {
      path.addEllipse(
        in: CGRect(
          x: at.x + dx * s - r * s, y: at.y + dy * s - r * s, width: r * 2 * s, height: r * 2 * s))
    }
    context.fill(path, with: .color(.white.opacity(0.85)))
  }

  private func drawHills(_ context: inout GraphicsContext, _ world: CGSize) {
    func ridge(_ base: Double, _ amp: Double, _ freq: Double, _ speed: Double, _ color: Color) {
      var path = Path()
      path.move(to: CGPoint(x: 0, y: FlapEngine.waterLine))
      var x = 0.0
      while x <= world.width + 8 {
        let u = (x + scroll * speed) * freq
        let y = base - (sin(u) * 0.6 + sin(u * 2.3 + 1) * 0.4) * amp
        path.addLine(to: CGPoint(x: x, y: y))
        x += 8
      }
      path.addLine(to: CGPoint(x: world.width, y: FlapEngine.waterLine))
      path.closeSubpath()
      context.fill(path, with: .color(color))
    }
    ridge(520, 60, 0.008, 0.15, Palette.far)
    ridge(600, 38, 0.013, 0.3, Palette.near)
    let spacing = 46.0
    let offset = (scroll * 0.45).truncatingRemainder(dividingBy: spacing)
    var index = Int((scroll * 0.45) / spacing)
    var x = -offset - spacing
    while x < world.width + spacing {
      let h = 34 + Double((index &* 37) % 5) * 9
      var tree = Path()
      tree.move(to: CGPoint(x: x, y: FlapEngine.waterLine - 8 - h))
      tree.addLine(to: CGPoint(x: x + 15, y: FlapEngine.waterLine - 6))
      tree.addLine(to: CGPoint(x: x - 15, y: FlapEngine.waterLine - 6))
      tree.closeSubpath()
      context.fill(tree, with: .color(Palette.pine))
      x += spacing
      index += 1
    }
    context.fill(
      Path(CGRect(x: 0, y: FlapEngine.waterLine - 14, width: world.width, height: 16)),
      with: .color(Color(hex: 0x5E9A62)))
  }

  private func drawGate(_ context: inout GraphicsContext, _ gate: Gate) {
    let w = FlapEngine.gateWidth
    let top = gate.gapCenter - engine.gap / 2
    let bottom = gate.gapCenter + engine.gap / 2
    drawLog(
      &context, CGRect(x: gate.x - w / 2, y: -30, width: w, height: top + 30), capAtBottom: true,
      seed: gate.id)
    drawLog(
      &context,
      CGRect(x: gate.x - w / 2, y: bottom, width: w, height: FlapEngine.waterLine + 40 - bottom),
      capAtBottom: false, seed: gate.id + 99)
    if gate.hasShell && !gate.shellTaken {
      let bob = sin(engine.time * 4 + Double(gate.id)) * 5
      drawShell(&context, CGPoint(x: gate.x, y: gate.gapCenter + bob))
    }
  }

  private func drawLog(
    _ context: inout GraphicsContext, _ rect: CGRect, capAtBottom: Bool, seed: Int
  ) {
    let body = Path(roundedRect: rect.insetBy(dx: 6, dy: 0), cornerRadius: 10)
    context.fill(
      body,
      with: .linearGradient(
        Gradient(colors: [Palette.logDark, Palette.log, Palette.logLight, Palette.log]),
        startPoint: CGPoint(x: rect.minX, y: 0), endPoint: CGPoint(x: rect.maxX, y: 0)))
    var bark = Path()
    var y = rect.minY + 24 + Double(seed % 3) * 9
    while y < rect.maxY - 20 {
      let x = rect.minX + 18 + Double((Int(y) &* 13 + seed) % 40)
      bark.move(to: CGPoint(x: x, y: y))
      bark.addLine(to: CGPoint(x: x, y: y + 22))
      y += 46
    }
    context.stroke(
      bark, with: .color(Palette.logDark.opacity(0.55)),
      style: StrokeStyle(lineWidth: 3, lineCap: .round))
    let capY = capAtBottom ? rect.maxY - 26 : rect.minY
    let cap = CGRect(x: rect.minX - 2, y: capY, width: rect.width + 4, height: 26)
    context.fill(Path(roundedRect: cap, cornerRadius: 12), with: .color(Palette.logDark))
    let face = CGRect(
      x: cap.minX + 4, y: cap.minY + 4, width: cap.width - 8, height: cap.height - 8)
    context.fill(Path(ellipseIn: face), with: .color(Palette.ring))
    context.stroke(
      Path(ellipseIn: face.insetBy(dx: face.width * 0.22, dy: face.height * 0.22)),
      with: .color(Palette.log), lineWidth: 2)
    context.fill(
      Path(ellipseIn: CGRect(x: face.midX - 3, y: face.midY - 2, width: 6, height: 4)),
      with: .color(Palette.log))
    var moss = Path()
    let mossY = capAtBottom ? cap.minY : cap.maxY
    for i in 0..<5 {
      let x = cap.minX + 8 + Double(i) * (cap.width - 16) / 4
      let len = 8 + Double((seed + i * 7) % 4) * 4
      moss.addEllipse(
        in: CGRect(x: x - 6, y: mossY - (capAtBottom ? 6 : len - 6), width: 12, height: len))
    }
    context.fill(moss, with: .color(Palette.moss))
  }

  private func drawShell(_ context: inout GraphicsContext, _ at: CGPoint) {
    context.fill(
      Path(ellipseIn: CGRect(x: at.x - 24, y: at.y - 24, width: 48, height: 48)),
      with: .color(.white.opacity(0.35 + sin(engine.time * 6) * 0.1)))
    var fan = Path()
    fan.move(to: CGPoint(x: at.x, y: at.y + 12))
    fan.addArc(
      center: CGPoint(x: at.x, y: at.y + 2), radius: 16, startAngle: .degrees(160),
      endAngle: .degrees(20), clockwise: false)
    fan.closeSubpath()
    context.fill(fan, with: .color(Palette.shell))
    var ribs = Path()
    for i in 0..<5 {
      let a = Double.pi * (1.1 + Double(i) * 0.2)
      ribs.move(to: CGPoint(x: at.x, y: at.y + 12))
      ribs.addLine(to: CGPoint(x: at.x + cos(a) * 15, y: at.y + 2 + sin(a) * 15))
    }
    context.stroke(ribs, with: .color(Palette.shellDark), lineWidth: 2)
    context.fill(
      Path(roundedRect: CGRect(x: at.x - 6, y: at.y + 9, width: 12, height: 6), cornerRadius: 2),
      with: .color(Palette.shellDark))
  }

  private func drawWater(_ context: inout GraphicsContext, _ world: CGSize) {
    var water = Path()
    water.move(to: CGPoint(x: 0, y: world.height))
    var x = 0.0
    while x <= world.width + 6 {
      water.addLine(
        to: CGPoint(x: x, y: FlapEngine.waterLine + sin((x + scroll) * 0.045 + engine.time * 2) * 4)
      )
      x += 6
    }
    water.addLine(to: CGPoint(x: world.width, y: world.height))
    water.closeSubpath()
    context.fill(
      water,
      with: .linearGradient(
        Gradient(colors: [Palette.water, Palette.waterDeep]),
        startPoint: CGPoint(x: 0, y: FlapEngine.waterLine), endPoint: CGPoint(x: 0, y: world.height)
      ))
    var ripples = Path()
    for row in 0..<3 {
      let y = FlapEngine.waterLine + 24 + Double(row) * 28
      let spacing = 90.0 + Double(row) * 20
      let offset = (scroll * (0.9 + Double(row) * 0.2)).truncatingRemainder(dividingBy: spacing)
      var rx = -offset + Double(row) * 30
      while rx < world.width {
        ripples.move(to: CGPoint(x: rx, y: y))
        ripples.addLine(to: CGPoint(x: rx + 26, y: y))
        rx += spacing
      }
    }
    context.stroke(
      ripples, with: .color(Palette.foam.opacity(0.45)),
      style: StrokeStyle(lineWidth: 3, lineCap: .round))
    let splash = engine.phase == .over ? min(1, (engine.time - engine.crashTime) * 1.5) : 0
    if splash > 0 && splash < 1 {
      for i in 0..<7 {
        let a = Double.pi * (1.1 + Double(i) * 0.13)
        let r = 20 + splash * 60
        let p = CGPoint(
          x: engine.otterX + cos(a) * r, y: FlapEngine.waterLine + sin(a) * r * (1 - splash) * 1.4)
        context.fill(
          Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)),
          with: .color(Palette.foam.opacity(1 - splash)))
      }
    }
  }

  private func drawOtter(_ context: inout GraphicsContext) {
    var layer = context
    layer.translateBy(x: engine.otterX - 12, y: engine.y)
    layer.rotate(by: .radians(engine.tilt))
    layer.scaleBy(x: 1.3, y: 1.3)
    let dazed = engine.phase == .falling || engine.phase == .over
    let paddle = max(0, 1 - (engine.time - engine.lastFlapTime) * 4)
    let wiggle = sin(engine.time * 10) * 0.5 + paddle

    func oval(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Path {
      Path(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h))
    }

    var tail = layer
    tail.translateBy(x: -30, y: 6)
    tail.rotate(by: .radians(0.35 + wiggle * 0.25))
    tail.fill(oval(-16, 0, 36, 14), with: .color(Palette.furDark))

    layer.fill(oval(-18, 22, 14, 11), with: .color(Palette.furDark))
    layer.fill(oval(-4, 0, 60, 42), with: .color(Palette.fur))
    layer.fill(oval(0, 8, 40, 24), with: .color(Palette.cream))

    var backPaw = layer
    backPaw.translateBy(x: 6, y: 16)
    backPaw.rotate(by: .radians(-0.3 - paddle * 1.1))
    backPaw.fill(oval(0, 8, 12, 18), with: .color(Palette.furDark))

    layer.fill(oval(18, -12, 12, 11), with: .color(Palette.furDark))
    layer.fill(oval(18, -12, 6, 5), with: .color(Palette.blush.opacity(0.8)))
    layer.fill(oval(22, -2, 40, 36), with: .color(Palette.fur))
    layer.fill(oval(30, 6, 28, 18), with: .color(Palette.cream))
    layer.fill(oval(36, 11, 8, 4), with: .color(Palette.blush.opacity(0.9)))
    layer.fill(oval(16, 8, 8, 5), with: .color(Palette.blush.opacity(0.7)))

    if dazed {
      var x = Path()
      for (cx, cy) in [(24.0, -6.0), (37.0, -6.0)] {
        x.move(to: CGPoint(x: cx - 3.5, y: cy - 3.5))
        x.addLine(to: CGPoint(x: cx + 3.5, y: cy + 3.5))
        x.move(to: CGPoint(x: cx + 3.5, y: cy - 3.5))
        x.addLine(to: CGPoint(x: cx - 3.5, y: cy + 3.5))
      }
      layer.stroke(
        x, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    } else {
      let blink = engine.phase == .ready && engine.time.truncatingRemainder(dividingBy: 3.2) < 0.12
      for cx in [24.0, 37.0] {
        if blink {
          var lid = Path()
          lid.move(to: CGPoint(x: cx - 4, y: -6))
          lid.addLine(to: CGPoint(x: cx + 4, y: -6))
          layer.stroke(
            lid, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        } else {
          layer.fill(oval(cx, -6, 8, 9), with: .color(Palette.ink))
          layer.fill(oval(cx + 1.5, -8, 3, 3), with: .color(.white))
        }
      }
    }
    layer.fill(oval(33, 1, 11, 7), with: .color(Palette.ink))
    layer.fill(oval(32, -0.5, 3.5, 2), with: .color(.white.opacity(0.7)))
    var mouth = Path()
    mouth.move(to: CGPoint(x: 29, y: 6))
    mouth.addQuadCurve(to: CGPoint(x: 33, y: 7), control: CGPoint(x: 31, y: 10))
    mouth.addQuadCurve(to: CGPoint(x: 37, y: 6), control: CGPoint(x: 35, y: 10))
    layer.stroke(
      mouth, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    var whiskers = Path()
    for dy in [-2.0, 3.0] {
      whiskers.move(to: CGPoint(x: 40, y: 3 + dy * 0.4))
      whiskers.addLine(to: CGPoint(x: 52, y: 1 + dy))
      whiskers.move(to: CGPoint(x: 25, y: 4 + dy * 0.4))
      whiskers.addLine(to: CGPoint(x: 14, y: 2 + dy))
    }
    layer.stroke(whiskers, with: .color(Palette.cream.opacity(0.9)), lineWidth: 1.2)

    var frontPaw = layer
    frontPaw.translateBy(x: 14, y: 14)
    frontPaw.rotate(by: .radians(-0.5 - paddle * 1.3))
    frontPaw.fill(oval(0, 7, 11, 17), with: .color(Palette.furDark))
    frontPaw.fill(oval(0, 13, 8, 5), with: .color(Palette.blush.opacity(0.6)))

    if dazed {
      for i in 0..<3 {
        let a = engine.time * 5 + Double(i) * 2.09
        let p = CGPoint(x: 28 + cos(a) * 22, y: -30 + sin(a) * 7)
        context.drawLayer { star in
          star.translateBy(x: engine.otterX - 12, y: engine.y)
          star.scaleBy(x: 1.3, y: 1.3)
          star.draw(
            Text("✦").font(.system(size: 14, weight: .bold)).foregroundStyle(Color(hex: 0xFFD45A)),
            at: p)
        }
      }
    }
  }
}
