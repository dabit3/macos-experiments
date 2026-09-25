import SwiftUI

// MARK: - Sky and daylight

enum Daylight {
  /// Sky colours keyed by clock progress (0 = 5 AM, 1 = 11 PM).
  static func sky(_ t: Double, weather: WeatherKind) -> (top: Color, horizon: Color, light: Double) {
    let stops: [(Double, Color, Color, Double)] = [
      (0.00, Color(red: 0.09, green: 0.12, blue: 0.30), Color(red: 0.95, green: 0.55, blue: 0.35), 0.45),
      (0.10, Color(red: 0.30, green: 0.55, blue: 0.85), Color(red: 0.98, green: 0.80, blue: 0.60), 0.85),
      (0.30, Color(red: 0.22, green: 0.52, blue: 0.90), Color(red: 0.72, green: 0.86, blue: 0.96), 1.0),
      (0.60, Color(red: 0.25, green: 0.55, blue: 0.90), Color(red: 0.80, green: 0.88, blue: 0.95), 1.0),
      (0.80, Color(red: 0.35, green: 0.40, blue: 0.70), Color(red: 0.99, green: 0.62, blue: 0.35), 0.75),
      (0.90, Color(red: 0.10, green: 0.10, blue: 0.30), Color(red: 0.75, green: 0.35, blue: 0.40), 0.45),
      (1.00, Color(red: 0.02, green: 0.03, blue: 0.10), Color(red: 0.12, green: 0.14, blue: 0.30), 0.22),
    ]
    var lower = stops[0]
    var upper = stops[stops.count - 1]
    for i in 0..<(stops.count - 1) where t >= stops[i].0 && t <= stops[i + 1].0 {
      lower = stops[i]
      upper = stops[i + 1]
      break
    }
    let span = max(0.0001, upper.0 - lower.0)
    let f = ((t - lower.0) / span).clamped(0, 1)
    var top = mix(lower.1, upper.1, f)
    var horizon = mix(lower.2, upper.2, f)
    var light = lower.3 + (upper.3 - lower.3) * f
    switch weather {
    case .overcast, .rain:
      top = mix(top, Color(red: 0.45, green: 0.50, blue: 0.56), 0.7)
      horizon = mix(horizon, Color(red: 0.62, green: 0.66, blue: 0.70), 0.7)
      light *= 0.75
    case .fog:
      horizon = mix(horizon, Color(red: 0.85, green: 0.88, blue: 0.90), 0.8)
      light *= 0.85
    case .partlyCloudy:
      light *= 0.95
    case .sunny: break
    }
    return (top, horizon, light)
  }

  static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
    let ca = UIColor(a).rgba
    let cb = UIColor(b).rgba
    return Color(
      red: ca.r + (cb.r - ca.r) * t, green: ca.g + (cb.g - ca.g) * t, blue: ca.b + (cb.b - ca.b) * t,
      opacity: ca.a + (cb.a - ca.a) * t)
  }
}

extension UIColor {
  var rgba: (r: Double, g: Double, b: Double, a: Double) {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    getRed(&r, green: &g, blue: &b, alpha: &a)
    return (r, g, b, a)
  }
}

extension WaterTint {
  var colors: (near: Color, far: Color) {
    switch self {
    case .warmGreen: return (Color(red: 0.10, green: 0.32, blue: 0.30), Color(red: 0.35, green: 0.60, blue: 0.62))
    case .muddyBrown: return (Color(red: 0.28, green: 0.24, blue: 0.14), Color(red: 0.52, green: 0.48, blue: 0.36))
    case .coldBlue: return (Color(red: 0.05, green: 0.20, blue: 0.38), Color(red: 0.30, green: 0.55, blue: 0.75))
    case .deepTeal: return (Color(red: 0.05, green: 0.25, blue: 0.28), Color(red: 0.20, green: 0.50, blue: 0.55))
    case .blackwater: return (Color(red: 0.08, green: 0.10, blue: 0.08), Color(red: 0.28, green: 0.34, blue: 0.24))
    case .turquoise: return (Color(red: 0.05, green: 0.36, blue: 0.40), Color(red: 0.35, green: 0.75, blue: 0.72))
    case .glacial: return (Color(red: 0.16, green: 0.34, blue: 0.36), Color(red: 0.55, green: 0.72, blue: 0.70))
    }
  }
}

// MARK: - Scenery

/// First-person view from the bank: sky, far shore, water, dock, rod and line.
struct SceneryView: View {
  let waterway: Waterway
  let weather: WeatherKind
  let dayProgress: Double
  let session: FishingSession?
  let splash: GameStore.SplashEffect?
  var aim: Double = 0

  var body: some View {
    TimelineView(.animation) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate
      Canvas(rendersAsynchronously: true) { ctx, size in
        drawScene(&ctx, size: size, time: time)
      }
    }
    .ignoresSafeArea()
  }

  private func drawScene(_ ctx: inout GraphicsContext, size: CGSize, time: Double) {
    let sky = Daylight.sky(dayProgress, weather: weather)
    let horizonY = size.height * 0.42
    let rect = CGRect(origin: .zero, size: size)

    // Sky
    ctx.fill(
      Path(rect),
      with: .linearGradient(
        Gradient(colors: [sky.top, sky.horizon]), startPoint: .zero,
        endPoint: CGPoint(x: 0, y: horizonY)))

    // Sun / moon
    let sunT = dayProgress
    let sunX = size.width * (0.15 + 0.7 * sunT)
    let sunY = horizonY - sin(sunT * .pi) * horizonY * 0.9 + 10
    if weather != .overcast && weather != .rain {
      let isMoon = dayProgress > 0.9
      let sunColor = isMoon ? Color(red: 0.9, green: 0.92, blue: 1.0) : Color(red: 1.0, green: 0.95, blue: 0.75)
      ctx.fill(
        Path(ellipseIn: CGRect(x: sunX - 60, y: sunY - 60, width: 120, height: 120)),
        with: .radialGradient(
          Gradient(colors: [sunColor.opacity(0.5), .clear]), center: CGPoint(x: sunX, y: sunY),
          startRadius: 10, endRadius: 60))
      ctx.fill(
        Path(ellipseIn: CGRect(x: sunX - 16, y: sunY - 16, width: 32, height: 32)), with: .color(sunColor))
    }

    // Stars at night
    if sky.light < 0.4 {
      var rng = SeededRandom(seed: 42)
      for _ in 0..<60 {
        let x = rng.unit() * size.width
        let y = rng.unit() * horizonY * 0.9
        let a = (0.4 - sky.light) / 0.4 * (0.4 + 0.6 * rng.unit())
        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(.white.opacity(a)))
      }
    }

    // Clouds
    if weather != .sunny {
      let count = weather == .partlyCloudy ? 4 : 9
      var rng = SeededRandom(seed: 7)
      for i in 0..<count {
        let baseX = rng.unit() * size.width * 1.3 - size.width * 0.15
        let drift = (time * 6 + Double(i) * 40).truncatingRemainder(dividingBy: size.width * 1.4)
        let x = (baseX + drift).truncatingRemainder(dividingBy: size.width * 1.4) - size.width * 0.2
        let y = 20 + rng.unit() * horizonY * 0.5
        let w = 120 + rng.unit() * 140
        let alpha = weather == .partlyCloudy ? 0.85 : 0.6
        let tone = weather == .partlyCloudy ? Color.white : Color(red: 0.72, green: 0.75, blue: 0.80)
        var cloud = Path()
        cloud.addEllipse(in: CGRect(x: x, y: y, width: w, height: w * 0.28))
        cloud.addEllipse(in: CGRect(x: x + w * 0.2, y: y - w * 0.1, width: w * 0.45, height: w * 0.32))
        cloud.addEllipse(in: CGRect(x: x + w * 0.45, y: y - w * 0.05, width: w * 0.4, height: w * 0.3))
        ctx.fill(cloud, with: .color(tone.opacity(alpha * sky.light)))
      }
    }

    // Far shore
    drawShore(&ctx, size: size, horizonY: horizonY, light: sky.light)

    // Water
    let tint = waterway.waterTint.colors
    let waterRect = CGRect(x: 0, y: horizonY, width: size.width, height: size.height - horizonY)
    let far = Daylight.mix(tint.far, sky.horizon, 0.45).opacity(1)
    ctx.fill(
      Path(waterRect),
      with: .linearGradient(
        Gradient(colors: [far, tint.near.opacity(1)]), startPoint: CGPoint(x: 0, y: horizonY),
        endPoint: CGPoint(x: 0, y: size.height)))
    ctx.fill(Path(waterRect), with: .color(.black.opacity((1 - sky.light) * 0.55)))

    // Sun streak on the water
    if weather != .overcast && weather != .rain {
      let streak = Path(
        ellipseIn: CGRect(x: sunX - 40, y: horizonY, width: 80, height: (size.height - horizonY) * 0.7))
      ctx.fill(
        streak,
        with: .linearGradient(
          Gradient(colors: [.white.opacity(0.28 * sky.light), .clear]),
          startPoint: CGPoint(x: 0, y: horizonY), endPoint: CGPoint(x: 0, y: size.height)))
    }

    // Ripples
    var rippleRng = SeededRandom(seed: 99)
    for i in 0..<70 {
      let depth = rippleRng.unit()
      let y = horizonY + pow(depth, 1.6) * (size.height - horizonY)
      let w = 20 + depth * 140
      let speed = 8 + depth * 25
      let x = (rippleRng.unit() * size.width * 1.2 + time * speed * (i % 2 == 0 ? 1 : -1))
        .truncatingRemainder(dividingBy: size.width * 1.2) - size.width * 0.1
      let alpha = (0.05 + depth * 0.14) * sky.light
      var p = Path()
      p.move(to: CGPoint(x: x, y: y))
      p.addLine(to: CGPoint(x: x + w, y: y))
      ctx.stroke(p, with: .color(.white.opacity(alpha)), lineWidth: 1 + depth * 1.5)
    }

    // Fog
    if weather == .fog {
      ctx.fill(
        Path(rect),
        with: .linearGradient(
          Gradient(colors: [.white.opacity(0.15), .white.opacity(0.55), .white.opacity(0.1)]),
          startPoint: CGPoint(x: 0, y: horizonY - 80), endPoint: CGPoint(x: 0, y: horizonY + 160)))
    }

    // Rain
    if weather == .rain {
      var rng = SeededRandom(seed: 3)
      for _ in 0..<80 {
        let x = rng.unit() * size.width
        let y = (rng.unit() * size.height + time * 900).truncatingRemainder(dividingBy: size.height)
        var p = Path()
        p.move(to: CGPoint(x: x, y: y))
        p.addLine(to: CGPoint(x: x - 3, y: y + 18))
        ctx.stroke(p, with: .color(.white.opacity(0.25)), lineWidth: 1)
      }
    }

    // Lure, line and rod
    drawTackle(&ctx, size: size, horizonY: horizonY, time: time, light: sky.light)

    // Splash rings
    if let splash {
      let age = Date().timeIntervalSince(splash.started)
      if age < 1.4, let session {
        let point = lurePoint(size: size, horizonY: horizonY, distance: session.lureDistanceFt)
        for ring in 0..<3 {
          let t = (age - Double(ring) * 0.15).clamped(0, 1.2)
          guard t > 0 else { continue }
          let r = (10 + t * 60 * splash.strength) * (0.4 + 0.6 * point.scale)
          ctx.stroke(
            Path(ellipseIn: CGRect(x: point.point.x - r, y: point.point.y - r * 0.35, width: r * 2, height: r * 0.7)),
            with: .color(.white.opacity((1 - t / 1.2) * 0.7)), lineWidth: 2)
        }
      }
    }

    // Dock planks
    drawDock(&ctx, size: size, light: sky.light)

    // Night vignette
    ctx.fill(
      Path(rect),
      with: .radialGradient(
        Gradient(colors: [.clear, .black.opacity(0.35 + (1 - sky.light) * 0.3)]),
        center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: size.width * 0.3,
        endRadius: size.width * 0.8))
  }

  private func drawShore(_ ctx: inout GraphicsContext, size: CGSize, horizonY: CGFloat, light: Double) {
    let w = size.width
    let profileSeed: UInt64
    let hillHeight: CGFloat
    let treeDensity: Int
    let hillColor: Color
    let treeColor: Color
    switch waterway.waterTint {
    case .warmGreen:
      profileSeed = 11; hillHeight = 40; treeDensity = 90
      hillColor = Color(red: 0.42, green: 0.52, blue: 0.30); treeColor = Color(red: 0.14, green: 0.28, blue: 0.14)
    case .muddyBrown:
      profileSeed = 23; hillHeight = 26; treeDensity = 120
      hillColor = Color(red: 0.36, green: 0.42, blue: 0.24); treeColor = Color(red: 0.18, green: 0.26, blue: 0.10)
    case .coldBlue:
      profileSeed = 37; hillHeight = 130; treeDensity = 70
      hillColor = Color(red: 0.30, green: 0.36, blue: 0.48); treeColor = Color(red: 0.08, green: 0.20, blue: 0.16)
    case .blackwater:
      profileSeed = 53; hillHeight = 18; treeDensity = 150
      hillColor = Color(red: 0.30, green: 0.34, blue: 0.20); treeColor = Color(red: 0.12, green: 0.18, blue: 0.10)
    case .deepTeal:
      profileSeed = 71; hillHeight = 190; treeDensity = 50
      hillColor = Color(red: 0.36, green: 0.38, blue: 0.42); treeColor = Color(red: 0.06, green: 0.16, blue: 0.12)
    case .turquoise:
      profileSeed = 89; hillHeight = 14; treeDensity = 60
      hillColor = Color(red: 0.62, green: 0.58, blue: 0.40); treeColor = Color(red: 0.16, green: 0.34, blue: 0.18)
    case .glacial:
      profileSeed = 97; hillHeight = 220; treeDensity = 40
      hillColor = Color(red: 0.62, green: 0.66, blue: 0.72); treeColor = Color(red: 0.08, green: 0.18, blue: 0.14)
    }

    // Distant ridge
    var rng = SeededRandom(seed: profileSeed)
    var ridge = Path()
    ridge.move(to: CGPoint(x: 0, y: horizonY))
    let segments = 14
    for i in 0...segments {
      let x = CGFloat(i) / CGFloat(segments) * w
      let h = hillHeight * CGFloat(0.35 + 0.65 * rng.unit()) * (i == 0 || i == segments ? 0.5 : 1)
      ridge.addLine(to: CGPoint(x: x, y: horizonY - h))
    }
    ridge.addLine(to: CGPoint(x: w, y: horizonY))
    ridge.closeSubpath()
    ctx.fill(ridge, with: .color(Daylight.mix(hillColor, .black, 1 - light).opacity(0.85)))

    // Snow caps for fjords
    if waterway.waterTint == .deepTeal {
      var snow = SeededRandom(seed: profileSeed)
      for i in 0...segments {
        let x = CGFloat(i) / CGFloat(segments) * w
        let h = hillHeight * CGFloat(0.35 + 0.65 * snow.unit()) * (i == 0 || i == segments ? 0.5 : 1)
        if h > hillHeight * 0.75 {
          var cap = Path()
          cap.move(to: CGPoint(x: x, y: horizonY - h))
          cap.addLine(to: CGPoint(x: x - 18, y: horizonY - h + 26))
          cap.addLine(to: CGPoint(x: x + 18, y: horizonY - h + 26))
          cap.closeSubpath()
          ctx.fill(cap, with: .color(.white.opacity(0.8 * light)))
        }
      }
    }

    // Treeline
    var trees = SeededRandom(seed: profileSeed &+ 1)
    var treePath = Path()
    let baseY = horizonY + 1
    for _ in 0..<treeDensity {
      let x = CGFloat(trees.unit()) * w
      let h = CGFloat(10 + trees.unit() * 22)
      let tw = h * 0.45
      if waterway.waterTint == .blackwater {
        // Cypress: tall trunk, mushroom crown
        treePath.addRect(CGRect(x: x - 1, y: baseY - h, width: 2, height: h))
        treePath.addEllipse(in: CGRect(x: x - tw, y: baseY - h - tw * 0.5, width: tw * 2, height: tw))
      } else {
        treePath.move(to: CGPoint(x: x - tw, y: baseY))
        treePath.addLine(to: CGPoint(x: x, y: baseY - h))
        treePath.addLine(to: CGPoint(x: x + tw, y: baseY))
        treePath.closeSubpath()
      }
    }
    ctx.fill(treePath, with: .color(Daylight.mix(treeColor, .black, (1 - light) * 0.8)))

    // Shore reflection band
    ctx.fill(
      Path(CGRect(x: 0, y: horizonY, width: w, height: 22)),
      with: .linearGradient(
        Gradient(colors: [Daylight.mix(treeColor, .black, 0.3).opacity(0.7), .clear]),
        startPoint: CGPoint(x: 0, y: horizonY), endPoint: CGPoint(x: 0, y: horizonY + 22)))
  }

  private func drawDock(_ ctx: inout GraphicsContext, size: CGSize, light: Double) {
    let dockTop = size.height * 0.84
    let plank = Color(red: 0.42, green: 0.30, blue: 0.18)
    let dark = Color(red: 0.25, green: 0.17, blue: 0.10)
    var p = Path()
    p.move(to: CGPoint(x: size.width * 0.18, y: size.height))
    p.addLine(to: CGPoint(x: size.width * 0.34, y: dockTop))
    p.addLine(to: CGPoint(x: size.width * 0.66, y: dockTop))
    p.addLine(to: CGPoint(x: size.width * 0.82, y: size.height))
    p.closeSubpath()
    ctx.fill(p, with: .color(Daylight.mix(plank, .black, (1 - light) * 0.7)))
    for i in 0..<7 {
      let t = CGFloat(i) / 7
      let y = dockTop + (size.height - dockTop) * pow(t, 1.4)
      let inset = (size.height - y) / (size.height - dockTop) * size.width * 0.16
      var line = Path()
      line.move(to: CGPoint(x: size.width * 0.18 + inset, y: y))
      line.addLine(to: CGPoint(x: size.width * 0.82 - inset, y: y))
      ctx.stroke(line, with: .color(dark.opacity(0.8)), lineWidth: 2)
    }
  }

  struct LurePoint {
    let point: CGPoint
    let scale: CGFloat
  }

  /// Maps a line-out distance to a point on the water in perspective.
  func lurePoint(size: CGSize, horizonY: CGFloat, distance: Double) -> LurePoint {
    let maxD = max(60.0, (session?.lineLengthFt ?? 200) * 0.6)
    let t = (distance / maxD).clamped(0, 1)
    let depth = 1 - pow(1 - t, 1.9)
    let bottom = size.height * 0.80
    let y = bottom - depth * (bottom - horizonY - 6)
    let spread = (0.16 + 0.35 * depth) * size.width * aim
    let x = size.width * 0.56 + spread * 0.5 + CGFloat(distance) * 0.2 * (1 - depth) * CGFloat(aim)
    return LurePoint(point: CGPoint(x: x, y: y), scale: 1 - depth * 0.8)
  }

  private func drawTackle(_ ctx: inout GraphicsContext, size: CGSize, horizonY: CGFloat, time: Double, light: Double) {
    guard let session else { return }
    let rodBase = CGPoint(x: size.width * 0.78, y: size.height + 30)
    let tension = session.lineTension
    let fight = session.phase == .fighting
    let raise = session.rodRaised ? 1.0 : 0.0

    // Rod: a bezier that bends more as tension climbs.
    let rodLength = size.height * 0.62
    let bend = CGFloat(0.08 + tension * 0.55) * (session.phase.lureIsInWater || fight ? 1 : 0.15)
    let angle = -CGFloat.pi / 2 + 0.55 - CGFloat(raise) * 0.35 + CGFloat(session.castPower) * 0.7
    let tip = CGPoint(
      x: rodBase.x + cos(angle) * rodLength - bend * 120,
      y: rodBase.y + sin(angle) * rodLength + bend * 90)
    let control = CGPoint(
      x: rodBase.x + cos(angle) * rodLength * 0.6, y: rodBase.y + sin(angle) * rodLength * 0.6)
    var rod = Path()
    rod.move(to: rodBase)
    rod.addQuadCurve(to: tip, control: control)
    ctx.stroke(rod, with: .color(Color(red: 0.12, green: 0.12, blue: 0.14)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
    ctx.stroke(rod, with: .color(Color(red: 0.55, green: 0.55, blue: 0.60).opacity(0.7)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    // Guides
    for i in 1...5 {
      let t = CGFloat(i) / 5.5
      let pt = quadPoint(rodBase, control, tip, t)
      ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)), with: .color(Color(red: 0.75, green: 0.75, blue: 0.8)))
    }
    // Reel
    let reelPt = quadPoint(rodBase, control, tip, 0.12)
    ctx.fill(Path(ellipseIn: CGRect(x: reelPt.x - 22, y: reelPt.y - 4, width: 30, height: 30)), with: .color(Color(red: 0.2, green: 0.22, blue: 0.26)))
    ctx.fill(Path(ellipseIn: CGRect(x: reelPt.x - 17, y: reelPt.y + 1, width: 20, height: 20)), with: .color(Color(red: 0.55, green: 0.58, blue: 0.64)))

    // Line and lure
    let inWater = session.phase.lureIsInWater
    let flying = session.phase == .flying
    if inWater || flying {
      let lp = lurePoint(size: size, horizonY: horizonY, distance: session.lureDistanceFt)
      var lureY = lp.point.y
      if flying {
        let t = (session.phaseTime / max(0.01, session.flightDuration)).clamped(0, 1)
        lureY -= sin(t * .pi) * size.height * 0.35
      }
      let bob = session.phase == .bite ? sin(time * 24) * 5 : sin(time * 2.2) * 1.5
      let fishPull = fight ? CGFloat(session.fish?.direction ?? 0) * 40 * CGFloat(session.fish?.surge ?? 0) : 0
      let lureAt = CGPoint(x: lp.point.x + fishPull, y: lureY + CGFloat(bob) * lp.scale)

      var line = Path()
      line.move(to: tip)
      let sag = CGFloat(max(0, 0.35 - tension)) * 90
      line.addQuadCurve(to: lureAt, control: CGPoint(x: (tip.x + lureAt.x) / 2, y: (tip.y + lureAt.y) / 2 + sag))
      let lineColor: Color = tension > 0.85 ? Theme.red : tension > 0.62 ? Theme.gold : .white
      ctx.stroke(line, with: .color(lineColor.opacity(0.85)), lineWidth: tension > 0.85 ? 1.6 : 1)

      if session.rig.tackleKind.isBait {
        // Float
        let s = 6 * (0.5 + lp.scale)
        var float = Path()
        float.addEllipse(in: CGRect(x: lureAt.x - s / 2, y: lureAt.y - s * 1.6, width: s, height: s * 2))
        ctx.fill(float, with: .color(Theme.red))
        ctx.fill(Path(ellipseIn: CGRect(x: lureAt.x - s / 2, y: lureAt.y - s * 1.6, width: s, height: s * 0.7)), with: .color(.white))
      } else {
        let s = 5 * (0.5 + lp.scale)
        ctx.fill(Path(ellipseIn: CGRect(x: lureAt.x - s / 2, y: lureAt.y - s / 2, width: s, height: s)), with: .color(Color(red: 0.9, green: 0.9, blue: 0.95)))
      }

      // Fighting fish shadow and splash
      if fight, let fish = session.fish {
        let shadowW = 30 * (0.4 + lp.scale) * CGFloat(0.6 + min(2, fish.weightLb) / 2)
        let flip = fish.direction < 0
        var body = Path()
        body.addEllipse(in: CGRect(x: lureAt.x - shadowW / 2, y: lureAt.y + 4, width: shadowW, height: shadowW * 0.35))
        ctx.fill(body, with: .color(.black.opacity(0.35)))
        if fish.surge > 0.5 {
          for i in 0..<5 {
            let a = Double(i) * 0.7 + time * 8
            let dx = cos(a) * 14 * lp.scale * (flip ? -1 : 1)
            ctx.fill(Path(ellipseIn: CGRect(x: lureAt.x + dx, y: lureAt.y - 6 - abs(sin(a)) * 12, width: 4, height: 4)), with: .color(.white.opacity(0.8)))
          }
        }
      }

      // Ring around the float when a fish nibbles
      if session.phase == .bite {
        let r = 12 + CGFloat((time * 3).truncatingRemainder(dividingBy: 1)) * 24
        ctx.stroke(Path(ellipseIn: CGRect(x: lureAt.x - r, y: lureAt.y - r * 0.35, width: r * 2, height: r * 0.7)), with: .color(.white.opacity(0.6)), lineWidth: 1.5)
      }
    } else if session.phase == .ready || session.phase == .charging {
      // Lure dangling from the tip
      var line = Path()
      line.move(to: tip)
      let dangle = CGPoint(x: tip.x + 4, y: tip.y + 40)
      line.addLine(to: dangle)
      ctx.stroke(line, with: .color(.white.opacity(0.8)), lineWidth: 1)
      ctx.fill(Path(ellipseIn: CGRect(x: dangle.x - 3, y: dangle.y - 3, width: 6, height: 6)), with: .color(session.rig.tackleKind.isBait ? Theme.red : Color(red: 0.9, green: 0.9, blue: 0.95)))
    }
  }

  private func quadPoint(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    let mt = 1 - t
    return CGPoint(
      x: mt * mt * a.x + 2 * mt * t * c.x + t * t * b.x,
      y: mt * mt * a.y + 2 * mt * t * c.y + t * t * b.y)
  }
}

// MARK: - Fish illustration

/// Stylised side-on fish drawn from the species colouring; used in catch cards and lists.
struct FishIllustration: View {
  let coloring: FishColoring
  var facingLeft = true

  var body: some View {
    Canvas { ctx, size in
      let w = size.width
      let h = size.height
      var body = Path()
      let palette = colors
      let (bodyH, tailW) = shape
      let midY = h / 2
      let bh = h * bodyH
      // Body
      body.move(to: CGPoint(x: w * 0.08, y: midY))
      body.addCurve(to: CGPoint(x: w * 0.72, y: midY - bh * 0.15), control1: CGPoint(x: w * 0.2, y: midY - bh), control2: CGPoint(x: w * 0.55, y: midY - bh * 0.9))
      body.addCurve(to: CGPoint(x: w * 0.72, y: midY + bh * 0.15), control1: CGPoint(x: w * 0.78, y: midY - bh * 0.05), control2: CGPoint(x: w * 0.78, y: midY + bh * 0.05))
      body.addCurve(to: CGPoint(x: w * 0.08, y: midY), control1: CGPoint(x: w * 0.55, y: midY + bh * 0.9), control2: CGPoint(x: w * 0.2, y: midY + bh))
      body.closeSubpath()
      // Tail
      var tail = Path()
      tail.move(to: CGPoint(x: w * 0.70, y: midY))
      tail.addLine(to: CGPoint(x: w * (0.70 + tailW), y: midY - bh * 0.7))
      tail.addLine(to: CGPoint(x: w * (0.70 + tailW * 0.8), y: midY))
      tail.addLine(to: CGPoint(x: w * (0.70 + tailW), y: midY + bh * 0.7))
      tail.closeSubpath()
      // Dorsal fin
      var dorsal = Path()
      dorsal.move(to: CGPoint(x: w * 0.28, y: midY - bh * 0.75))
      dorsal.addLine(to: CGPoint(x: w * 0.38, y: midY - bh * 1.35))
      dorsal.addLine(to: CGPoint(x: w * 0.6, y: midY - bh * 0.6))
      dorsal.closeSubpath()
      var pelvic = Path()
      pelvic.move(to: CGPoint(x: w * 0.32, y: midY + bh * 0.7))
      pelvic.addLine(to: CGPoint(x: w * 0.4, y: midY + bh * 1.15))
      pelvic.addLine(to: CGPoint(x: w * 0.5, y: midY + bh * 0.62))
      pelvic.closeSubpath()

      if !facingLeft {
        ctx.translateBy(x: w, y: 0)
        ctx.scaleBy(x: -1, y: 1)
      }
      ctx.fill(tail, with: .color(palette.fin))
      ctx.fill(dorsal, with: .color(palette.fin))
      ctx.fill(pelvic, with: .color(palette.fin))
      ctx.fill(body, with: .linearGradient(Gradient(colors: [palette.back, palette.belly]), startPoint: CGPoint(x: 0, y: midY - bh), endPoint: CGPoint(x: 0, y: midY + bh)))
      // Markings
      ctx.clip(to: body)
      switch coloring {
      case .bass, .pike, .walleye, .snakehead:
        var stripe = Path()
        stripe.move(to: CGPoint(x: w * 0.1, y: midY))
        stripe.addCurve(to: CGPoint(x: w * 0.7, y: midY), control1: CGPoint(x: w * 0.3, y: midY + bh * 0.2), control2: CGPoint(x: w * 0.5, y: midY - bh * 0.1))
        ctx.stroke(stripe, with: .color(palette.marking.opacity(0.7)), style: StrokeStyle(lineWidth: bh * 0.22, dash: coloring == .bass ? [w * 0.04, w * 0.02] : []))
      case .perch, .crappie, .sunfish, .drum, .cichlid:
        for i in 0..<6 {
          let x = w * (0.16 + Double(i) * 0.09)
          var bar = Path()
          bar.move(to: CGPoint(x: x, y: midY - bh))
          bar.addLine(to: CGPoint(x: x + w * 0.02, y: midY + bh))
          ctx.stroke(bar, with: .color(palette.marking.opacity(coloring == .perch ? 0.8 : 0.35)), lineWidth: bh * 0.16)
        }
      case .trout, .salmon:
        var rng = SeededRandom(seed: 5)
        for _ in 0..<18 {
          let x = w * (0.12 + rng.unit() * 0.55)
          let y = midY + (rng.unit() - 0.5) * bh * 1.2
          ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3)), with: .color(palette.marking))
        }
        var band = Path()
        band.move(to: CGPoint(x: w * 0.1, y: midY))
        band.addLine(to: CGPoint(x: w * 0.7, y: midY))
        ctx.stroke(band, with: .color(Color(red: 0.95, green: 0.45, blue: 0.5).opacity(0.5)), lineWidth: bh * 0.3)
      case .sturgeon:
        for i in 0..<7 {
          let x = w * (0.18 + Double(i) * 0.08)
          ctx.fill(
            Path(ellipseIn: CGRect(x: x, y: midY - bh * 0.9, width: w * 0.03, height: bh * 0.3)),
            with: .color(palette.marking))
        }
      case .gar, .catfish, .carp, .shiner:
        break
      }
      // Eye
      let eye = CGRect(x: w * 0.13, y: midY - bh * 0.35, width: h * 0.11, height: h * 0.11)
      ctx.fill(Path(ellipseIn: eye), with: .color(.white))
      ctx.fill(Path(ellipseIn: eye.insetBy(dx: h * 0.03, dy: h * 0.03)), with: .color(.black))
      // Gill
      var gill = Path()
      gill.move(to: CGPoint(x: w * 0.24, y: midY - bh * 0.5))
      gill.addQuadCurve(to: CGPoint(x: w * 0.24, y: midY + bh * 0.5), control: CGPoint(x: w * 0.29, y: midY))
      ctx.stroke(gill, with: .color(.black.opacity(0.25)), lineWidth: 1.5)
    }
  }

  private var shape: (Double, Double) {
    switch coloring {
    case .sunfish, .crappie, .cichlid: return (0.42, 0.22)
    case .gar, .pike, .snakehead: return (0.16, 0.22)
    case .catfish, .carp, .drum: return (0.32, 0.24)
    case .shiner, .trout, .walleye, .salmon: return (0.24, 0.26)
    case .bass, .perch: return (0.30, 0.24)
    case .sturgeon: return (0.20, 0.20)
    }
  }

  private var colors: (back: Color, belly: Color, fin: Color, marking: Color) {
    switch coloring {
    case .sunfish: return (Color(red: 0.16, green: 0.36, blue: 0.30), Color(red: 0.98, green: 0.65, blue: 0.20), Color(red: 0.25, green: 0.30, blue: 0.20), Color(red: 0.10, green: 0.25, blue: 0.25))
    case .bass: return (Color(red: 0.20, green: 0.36, blue: 0.16), Color(red: 0.90, green: 0.92, blue: 0.80), Color(red: 0.22, green: 0.32, blue: 0.18), Color(red: 0.08, green: 0.15, blue: 0.06))
    case .shiner: return (Color(red: 0.55, green: 0.55, blue: 0.35), Color(red: 0.98, green: 0.93, blue: 0.60), Color(red: 0.75, green: 0.70, blue: 0.40), .clear)
    case .crappie: return (Color(red: 0.30, green: 0.36, blue: 0.30), Color(red: 0.92, green: 0.94, blue: 0.90), Color(red: 0.25, green: 0.30, blue: 0.28), Color(red: 0.10, green: 0.12, blue: 0.10))
    case .catfish: return (Color(red: 0.28, green: 0.32, blue: 0.36), Color(red: 0.85, green: 0.85, blue: 0.80), Color(red: 0.22, green: 0.25, blue: 0.28), .clear)
    case .carp: return (Color(red: 0.50, green: 0.40, blue: 0.20), Color(red: 0.95, green: 0.82, blue: 0.50), Color(red: 0.70, green: 0.40, blue: 0.18), .clear)
    case .walleye: return (Color(red: 0.55, green: 0.45, blue: 0.18), Color(red: 0.98, green: 0.92, blue: 0.70), Color(red: 0.40, green: 0.32, blue: 0.14), Color(red: 0.25, green: 0.20, blue: 0.05))
    case .gar: return (Color(red: 0.32, green: 0.40, blue: 0.24), Color(red: 0.85, green: 0.88, blue: 0.70), Color(red: 0.30, green: 0.35, blue: 0.20), .clear)
    case .trout: return (Color(red: 0.22, green: 0.40, blue: 0.30), Color(red: 0.95, green: 0.90, blue: 0.75), Color(red: 0.55, green: 0.30, blue: 0.20), Color(red: 0.05, green: 0.05, blue: 0.05))
    case .pike: return (Color(red: 0.24, green: 0.36, blue: 0.16), Color(red: 0.90, green: 0.92, blue: 0.70), Color(red: 0.55, green: 0.35, blue: 0.14), Color(red: 0.85, green: 0.88, blue: 0.55))
    case .perch: return (Color(red: 0.38, green: 0.50, blue: 0.20), Color(red: 0.98, green: 0.82, blue: 0.30), Color(red: 0.95, green: 0.45, blue: 0.10), Color(red: 0.12, green: 0.20, blue: 0.08))
    case .drum: return (Color(red: 0.45, green: 0.45, blue: 0.48), Color(red: 0.90, green: 0.90, blue: 0.88), Color(red: 0.35, green: 0.35, blue: 0.40), Color(red: 0.25, green: 0.25, blue: 0.28))
    case .salmon: return (Color(red: 0.20, green: 0.34, blue: 0.42), Color(red: 0.92, green: 0.88, blue: 0.85), Color(red: 0.30, green: 0.36, blue: 0.40), Color(red: 0.10, green: 0.12, blue: 0.16))
    case .sturgeon: return (Color(red: 0.36, green: 0.38, blue: 0.36), Color(red: 0.88, green: 0.88, blue: 0.84), Color(red: 0.28, green: 0.30, blue: 0.30), Color(red: 0.70, green: 0.72, blue: 0.68))
    case .snakehead: return (Color(red: 0.30, green: 0.26, blue: 0.16), Color(red: 0.86, green: 0.80, blue: 0.62), Color(red: 0.34, green: 0.28, blue: 0.16), Color(red: 0.12, green: 0.10, blue: 0.06))
    case .cichlid: return (Color(red: 0.36, green: 0.44, blue: 0.16), Color(red: 0.98, green: 0.78, blue: 0.24), Color(red: 0.80, green: 0.30, blue: 0.10), Color(red: 0.10, green: 0.10, blue: 0.08))
    }
  }
}

// MARK: - Globe map

/// Stylised world map with pins for every waterway; the home screen "globe".
struct MapView: View {
  let waterways: [Waterway]
  let profile: PlayerProfile
  let selected: String?
  let onSelect: (Waterway) -> Void

  /// Simplified landmasses as (longitude, latitude) rings.
  static let landmasses: [[(Double, Double)]] = [
    // North and Central America
    [(-168, 66), (-140, 70), (-110, 73), (-80, 72), (-65, 60), (-55, 50), (-66, 44), (-76, 36),
     (-80, 31), (-81, 25), (-86, 30), (-90, 29), (-97, 26), (-97, 17), (-84, 10), (-77, 8),
     (-83, 10), (-92, 15), (-105, 20), (-110, 23), (-113, 31), (-118, 33), (-124, 41),
     (-124, 48), (-132, 55), (-145, 60), (-152, 58), (-165, 54), (-165, 62)],
    // South America
    [(-78, 8), (-72, 12), (-62, 10), (-52, 4), (-35, -6), (-38, -14), (-42, -23), (-48, -28),
     (-53, -34), (-58, -39), (-65, -42), (-68, -52), (-72, -53), (-75, -45), (-72, -30),
     (-70, -18), (-77, -10), (-81, -4), (-78, 1)],
    // Eurasia
    [(-10, 36), (-9, 43), (-2, 48), (2, 51), (8, 54), (5, 58), (10, 63), (20, 70), (40, 68),
     (60, 70), (80, 73), (105, 77), (140, 72), (170, 69), (180, 66), (170, 60), (160, 55),
     (158, 52), (142, 48), (135, 43), (130, 35), (122, 30), (121, 23), (109, 18), (106, 10),
     (103, 1), (99, 8), (98, 16), (90, 22), (85, 20), (80, 10), (77, 8), (72, 20), (67, 25),
     (58, 25), (56, 20), (52, 15), (44, 12), (43, 15), (35, 28), (33, 31), (36, 36), (28, 36),
     (23, 38), (20, 40), (16, 38), (12, 44), (6, 43), (3, 43), (-1, 38), (-6, 36)],
    // Africa
    [(-17, 21), (-17, 15), (-14, 10), (-8, 5), (0, 5), (8, 4), (10, 2), (9, -2), (12, -6),
     (12, -15), (15, -22), (18, -34), (26, -34), (33, -27), (36, -20), (40, -12), (41, -2),
     (46, 5), (51, 12), (43, 12), (37, 18), (33, 31), (30, 32), (20, 32), (10, 37), (0, 36),
     (-6, 35), (-10, 30), (-16, 25)],
    // Australia
    [(114, -22), (114, -34), (118, -35), (130, -32), (138, -35), (141, -38), (146, -39),
     (150, -37), (153, -30), (153, -25), (146, -19), (142, -11), (137, -12), (131, -12),
     (126, -14), (122, -17), (116, -20)],
    // British Isles
    [(-5, 50), (1, 51), (2, 53), (-2, 56), (-4, 58), (-6, 57), (-6, 55), (-3, 54), (-5, 52),
     (-6, 50)],
    // Japan
    [(130, 31), (132, 34), (136, 35), (140, 36), (142, 40), (141, 43), (145, 44), (142, 45),
     (140, 41), (137, 37), (133, 35), (131, 33)],
    // New Zealand
    [(173, -35), (178, -38), (177, -40), (174, -41), (172, -44), (170, -46), (167, -46),
     (167, -44), (171, -41), (172, -40), (174, -38)],
  ]

  static func project(lat: Double, lon: Double) -> CGPoint {
    let x = ((lon + 170) / 350).clamped(0, 1)
    let y = ((75 - lat) / 125).clamped(0, 1)
    return CGPoint(x: 0.03 + x * 0.94, y: 0.05 + y * 0.9)
  }

  /// Projected pin positions, nudged apart so clustered waterways stay individually tappable.
  static func pinPositions(for waterways: [Waterway], in size: CGSize) -> [String: CGPoint] {
    var points = waterways.map { w -> CGPoint in
      let p = project(lat: w.latitude, lon: w.longitude)
      return CGPoint(x: p.x * size.width, y: p.y * size.height)
    }
    let minGap: CGFloat = 24
    for _ in 0..<12 {
      for i in points.indices {
        for j in points.indices where j > i {
          let dx = points[j].x - points[i].x
          let dy = points[j].y - points[i].y
          let dist = max(sqrt(dx * dx + dy * dy), 0.01)
          guard dist < minGap else { continue }
          let push = (minGap - dist) / 2
          let ux = dist < 0.02 ? 1 : dx / dist
          let uy = dist < 0.02 ? 0 : dy / dist
          points[i].x -= ux * push; points[i].y -= uy * push
          points[j].x += ux * push; points[j].y += uy * push
        }
      }
    }
    return Dictionary(uniqueKeysWithValues: zip(waterways.map(\.id), points))
  }

  var body: some View {
    GeometryReader { geo in
      let size = geo.size
      let pins = Self.pinPositions(for: waterways, in: size)
      ZStack {
        Canvas { ctx, size in
          // Ocean grid
          var grid = Path()
          for i in stride(from: 0, through: size.width, by: 36) { grid.move(to: CGPoint(x: i, y: 0)); grid.addLine(to: CGPoint(x: i, y: size.height)) }
          for j in stride(from: 0, through: size.height, by: 36) { grid.move(to: CGPoint(x: 0, y: j)); grid.addLine(to: CGPoint(x: size.width, y: j)) }
          ctx.stroke(grid, with: .color(Theme.cyan.opacity(0.08)), lineWidth: 1)

          var land = Path()
          for ring in Self.landmasses {
            for (i, (lon, lat)) in ring.enumerated() {
              let p = Self.project(lat: lat, lon: lon)
              let pt = CGPoint(x: p.x * size.width, y: p.y * size.height)
              if i == 0 { land.move(to: pt) } else { land.addLine(to: pt) }
            }
            land.closeSubpath()
          }
          ctx.fill(land, with: .linearGradient(Gradient(colors: [Color(red: 0.16, green: 0.40, blue: 0.30), Color(red: 0.10, green: 0.26, blue: 0.22)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
          ctx.stroke(land, with: .color(Theme.cyan.opacity(0.7)), lineWidth: 1.2)
          // Routes between unlocked waterways
          let unlocked = waterways.filter { profile.level >= $0.requiredLevel }
          if unlocked.count > 1 {
            var route = Path()
            for (i, w) in unlocked.enumerated() {
              let pt = pins[w.id] ?? .zero
              if i == 0 { route.move(to: pt) } else { route.addLine(to: pt) }
            }
            ctx.stroke(route, with: .color(Theme.gold.opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
          }
        }
        ForEach(waterways) { waterway in
          let pt = pins[waterway.id] ?? .zero
          MapPin(
            waterway: waterway, locked: profile.level < waterway.requiredLevel,
            current: profile.currentWaterwayID == waterway.id, selected: selected == waterway.id,
            labelSide: labelSide(for: waterway)
          ) { onSelect(waterway) }
          .zIndex(selected == waterway.id ? 2 : (profile.currentWaterwayID == waterway.id ? 1 : 0))
          .position(pt)
        }
      }
    }
  }

  /// Only the selected and current pins carry captions. When both sit close together the
  /// western one puts its caption to the left and the eastern one to the right; pins near the
  /// map edge always caption inward.
  private func labelSide(for waterway: Waterway) -> MapPin.LabelSide {
    let p = Self.project(lat: waterway.latitude, lon: waterway.longitude)
    if p.x > 0.82 { return .leading }
    if p.x < 0.18 { return .trailing }
    let captioned = waterways.filter {
      $0.id != waterway.id && ($0.id == selected || $0.id == profile.currentWaterwayID)
    }
    for other in captioned {
      let q = Self.project(lat: other.latitude, lon: other.longitude)
      if abs(q.x - p.x) < 0.22 && abs(q.y - p.y) < 0.12 {
        return p.x <= q.x ? .leading : .trailing
      }
    }
    return .below
  }
}

struct MapPin: View {
  enum LabelSide { case below, leading, trailing }

  let waterway: Waterway
  let locked: Bool
  let current: Bool
  let selected: Bool
  var labelSide: LabelSide = .below
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      marker
        .overlay {
          caption
            .opacity(selected || current ? 1 : 0)
            .fixedSize()
            .alignmentGuide(HorizontalAlignment.center) { d in
              switch labelSide {
              case .below: return d[HorizontalAlignment.center]
              case .leading: return d[.trailing] + 14
              case .trailing: return d[.leading] - 14
              }
            }
            .alignmentGuide(VerticalAlignment.center) { d in
              labelSide == .below ? d[.top] - 12 : d[VerticalAlignment.center]
            }
        }
        .scaleEffect(selected ? 1.15 : 1)
        .animation(.spring(response: 0.3), value: selected)
    }
    .buttonStyle(.plain)
  }

  private var marker: some View {
    ZStack {
      Circle().fill(locked ? Color(red: 0.35, green: 0.38, blue: 0.42) : (current ? Theme.gold : Theme.cyan))
        .frame(width: 20, height: 20)
        .shadow(color: (locked ? Color.black : Theme.cyan).opacity(0.7), radius: selected ? 10 : 4)
      Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5).frame(width: 20, height: 20)
      Image(systemName: locked ? "lock.fill" : "fish.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(locked ? Theme.inkDim : .black.opacity(0.75))
    }
  }

  private var caption: some View {
    VStack(alignment: labelSide == .leading ? .trailing : (labelSide == .trailing ? .leading : .center), spacing: 0) {
      Text(waterway.name).font(Theme.display(11)).textCase(.uppercase).foregroundStyle(.white)
        .shadow(color: .black, radius: 2)
      if locked {
        Text("LVL \(waterway.requiredLevel)").font(Theme.mono(9)).foregroundStyle(Theme.gold)
      }
    }
  }
}
