import SwiftUI

enum Ink {
  static let night = Color(red: 0.035, green: 0.085, blue: 0.12)
  static let panel = Color(red: 0.07, green: 0.145, blue: 0.175)
  static let gold = Color(red: 0.86, green: 0.72, blue: 0.47)
  static let cream = Color(red: 0.95, green: 0.90, blue: 0.79)
  static let muted = Color(red: 0.58, green: 0.67, blue: 0.67)
  static let rose = Color(red: 0.86, green: 0.51, blue: 0.44)
  static let jade = Color(red: 0.47, green: 0.73, blue: 0.62)
  static let rule = gold.opacity(0.24)
}

enum TypeStyle {
  static func title(_ size: CGFloat) -> Font { .custom("Baskerville", size: size) }
  static func italic(_ size: CGFloat) -> Font { .custom("Baskerville-Italic", size: size) }
}

struct FestivalRule: View {
  var body: some View {
    HStack(spacing: 9) {
      Rectangle().fill(Ink.rule).frame(height: 0.5)
      Rectangle().fill(Ink.gold).frame(width: 4, height: 4).rotationEffect(.degrees(45))
      Rectangle().fill(Ink.rule).frame(height: 0.5)
    }.accessibilityHidden(true)
  }
}

extension LanternColor {
  var ink: Color { [Ink.gold, Ink.rose, Ink.jade][rawValue] }
}

struct NightBackground: View {
  var body: some View {
    ZStack {
      Ink.night
      RadialGradient(
        colors: [Ink.panel.opacity(0.7), .clear],
        center: .init(x: 0.5, y: 0.3), startRadius: 0, endRadius: 500)
      Canvas { context, size in
        for index in 0..<1800 {
          let x = CGFloat((index * 137 + 19) % 997) / 997 * size.width
          let y = CGFloat((index * 71 + 11) % 991) / 991 * size.height
          context.fill(
            Path(CGRect(x: x, y: y, width: 0.6, height: 0.6)),
            with: .color(Ink.cream.opacity(index % 3 == 0 ? 0.06 : 0.025)))
        }
      }.drawingGroup()
    }.ignoresSafeArea().accessibilityHidden(true)
  }
}

struct PaperLantern: View {
  var color: Color = Ink.gold
  var size: CGFloat = 34
  var body: some View {
    Canvas { context, bounds in
      Art.lantern(
        &context, at: CGPoint(x: bounds.width / 2, y: bounds.height / 2), radius: size / 2,
        color: color, glowRadius: 1.7)
    }
    .frame(width: size * 1.8, height: size * 1.9)
    .accessibilityHidden(true)
  }
}

enum Art {
  static func line(
    _ context: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color, width: CGFloat = 1
  ) {
    var path = Path()
    path.move(to: from)
    path.addLine(to: to)
    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
  }

  static func lantern(
    _ context: inout GraphicsContext, at p: CGPoint, radius r: CGFloat, color: Color,
    glowRadius: CGFloat = 2.3
  ) {
    context.fill(
      Path(
        ellipseIn: CGRect(
          x: p.x - r * glowRadius, y: p.y - r * glowRadius, width: r * glowRadius * 2,
          height: r * glowRadius * 2)),
      with: .radialGradient(
        Gradient(colors: [color.opacity(0.25), color.opacity(0)]),
        center: p, startRadius: r * 0.3, endRadius: r * glowRadius))
    let rect = CGRect(x: p.x - r, y: p.y - r * 1.13, width: r * 2, height: r * 2.26)
    context.fill(
      Path(ellipseIn: rect),
      with: .linearGradient(
        Gradient(colors: [color, Ink.cream, color]), startPoint: CGPoint(x: rect.minX, y: p.y),
        endPoint: CGPoint(x: rect.maxX, y: p.y)))
    for offset in [-0.65, -0.38, 0.38, 0.65] {
      context.stroke(
        Path(ellipseIn: rect.insetBy(dx: r * abs(offset), dy: 0)),
        with: .color(Ink.night.opacity(0.2)), lineWidth: 0.5)
    }
    for index in -3...3 {
      let y = p.y + CGFloat(index) * r * 0.26
      let halfWidth = r * sqrt(1 - pow(CGFloat(index) * 0.23, 2))
      line(
        &context, from: CGPoint(x: p.x - halfWidth, y: y),
        to: CGPoint(x: p.x + halfWidth, y: y), color: Ink.night.opacity(0.09), width: 0.5)
    }
    for y in [-1.12, 1.12] {
      let cap = CGRect(x: p.x - r * 0.42, y: p.y + r * y - 1.5, width: r * 0.84, height: 3)
      context.fill(Path(roundedRect: cap, cornerRadius: 1), with: .color(Ink.gold))
      context.stroke(
        Path(roundedRect: cap, cornerRadius: 1), with: .color(Ink.night.opacity(0.5)),
        lineWidth: 0.5)
    }
    line(
      &context, from: CGPoint(x: p.x, y: p.y + r * 1.2),
      to: CGPoint(x: p.x, y: p.y + r * 1.65), color: color.opacity(0.8), width: 1.4)
    for x in -1...1 {
      line(
        &context, from: CGPoint(x: p.x, y: p.y + r * 1.55),
        to: CGPoint(x: p.x + CGFloat(x) * r * 0.12, y: p.y + r * 1.95),
        color: color.opacity(0.65), width: 0.7)
    }
  }

  static func roof(_ context: inout GraphicsContext, rect: CGRect, seed: Int, lit: Bool) {
    let w = rect.width
    let h = rect.height
    let x = rect.minX
    let y = rect.minY
    let clay = [Ink.rose.opacity(0.65), Ink.muted.opacity(0.55), Ink.gold.opacity(0.45)][seed % 3]
    let wall = CGRect(x: x + w * 0.12, y: y + h * 0.4, width: w * 0.76, height: h * 0.58)
    context.fill(
      Path(ellipseIn: rect.offsetBy(dx: 2, dy: h * 0.4)), with: .color(Ink.night.opacity(0.5)))
    context.fill(Path(wall), with: .color(lit ? Ink.gold.opacity(0.26) : Ink.muted.opacity(0.22)))
    context.stroke(Path(wall), with: .color(Ink.night), lineWidth: 0.8)
    for index in 0...4 {
      let postX = wall.minX + CGFloat(index) * wall.width / 4
      line(
        &context, from: CGPoint(x: postX, y: wall.minY), to: CGPoint(x: postX, y: wall.maxY),
        color: Ink.night.opacity(0.65), width: 1)
    }
    line(
      &context, from: CGPoint(x: wall.minX, y: wall.maxY - 2),
      to: CGPoint(x: wall.maxX, y: wall.maxY - 2), color: Ink.gold.opacity(0.35), width: 0.6)
    let roof = Path { path in
      path.move(to: CGPoint(x: x - 1, y: y + h * 0.57))
      path.addQuadCurve(
        to: CGPoint(x: x + w * 0.24, y: y + h * 0.05),
        control: CGPoint(x: x + w * 0.18, y: y + h * 0.45))
      path.addLine(to: CGPoint(x: x + w * 0.73, y: y + h * 0.05))
      path.addQuadCurve(
        to: CGPoint(x: x + w + 1, y: y + h * 0.57),
        control: CGPoint(x: x + w * 0.83, y: y + h * 0.43))
      path.closeSubpath()
    }
    context.fill(
      roof,
      with: .linearGradient(
        Gradient(colors: [clay, Ink.panel]), startPoint: CGPoint(x: x, y: y),
        endPoint: CGPoint(x: x, y: y + h * 0.7)))
    context.stroke(roof, with: .color(Ink.gold.opacity(0.45)), lineWidth: 0.6)
    var tiles = context
    tiles.clip(to: roof)
    for index in 0...8 {
      let t = CGFloat(index) / 8
      line(
        &tiles, from: CGPoint(x: x + w * (0.24 + t * 0.49), y: y + h * 0.05),
        to: CGPoint(x: x + w * t, y: y + h * 0.58), color: Ink.gold.opacity(0.2), width: 0.6)
    }
    for index in 1...4 {
      let ty = y + CGFloat(index) * h * 0.13
      line(
        &tiles, from: CGPoint(x: x, y: ty), to: CGPoint(x: x + w, y: ty),
        color: Ink.night.opacity(0.5), width: 0.65)
    }
    line(
      &context, from: CGPoint(x: x + w * 0.19, y: y + h * 0.03),
      to: CGPoint(x: x + w * 0.78, y: y + h * 0.03), color: clay, width: 1.5)
    for index in 0..<3 {
      let window = CGRect(
        x: wall.minX + 2 + CGFloat(index) * wall.width * 0.3, y: y + h * 0.66, width: w * 0.13,
        height: h * 0.18)
      context.fill(
        Path(window), with: .color(lit ? Ink.cream.opacity(0.9) : Ink.gold.opacity(0.28)))
      line(
        &context, from: CGPoint(x: window.midX, y: window.minY),
        to: CGPoint(x: window.midX, y: window.maxY), color: Ink.night.opacity(0.5), width: 0.5)
    }
    if seed % 3 == 0 {
      let banner = CGRect(
        x: wall.maxX - 1, y: wall.minY + h * 0.15, width: w * 0.14, height: h * 0.36)
      context.fill(Path(banner), with: .color(Ink.rose.opacity(0.7)))
      line(
        &context, from: CGPoint(x: banner.midX, y: banner.minY + 2),
        to: CGPoint(x: banner.midX, y: banner.maxY - 2), color: Ink.cream.opacity(0.7), width: 0.6)
    }
  }

  static func blossom(_ context: inout GraphicsContext, at p: CGPoint, scale: CGFloat) {
    for branch in -1...1 {
      line(
        &context, from: CGPoint(x: p.x + 1, y: p.y + scale * 1.25),
        to: CGPoint(x: p.x + CGFloat(branch) * scale * 0.6, y: p.y - scale * 0.2),
        color: Ink.gold.opacity(0.38), width: branch == 0 ? 1.4 : 0.8)
    }
    for index in 0..<33 {
      let angle = Double(index) * 2.399
      let spread = sqrt(Double(index) / 33) * scale
      let x = p.x + cos(angle) * spread
      let y = p.y + sin(angle) * spread * 0.7
      context.fill(
        Path(
          ellipseIn: CGRect(
            x: x - scale * 0.2, y: y - scale * 0.2, width: scale * 0.43, height: scale * 0.37)),
        with: .color(
          [Ink.rose.opacity(0.6), Ink.cream.opacity(0.45), Ink.rose.opacity(0.35)][index % 3]))
    }
  }

  static func pine(_ context: inout GraphicsContext, at p: CGPoint, scale: CGFloat) {
    line(
      &context, from: CGPoint(x: p.x, y: p.y - scale), to: CGPoint(x: p.x, y: p.y + scale),
      color: Ink.gold.opacity(0.35), width: 1)
    for tier in 0..<4 {
      let y = p.y - scale + CGFloat(tier) * scale * 0.4
      let w = scale * (0.3 + CGFloat(tier) * 0.2)
      let path = Path { path in
        path.move(to: CGPoint(x: p.x, y: y - scale * 0.35))
        path.addQuadCurve(
          to: CGPoint(x: p.x - w, y: y + scale * 0.45),
          control: CGPoint(x: p.x - w * 0.2, y: y + scale * 0.25))
        path.addQuadCurve(
          to: CGPoint(x: p.x + w, y: y + scale * 0.45),
          control: CGPoint(x: p.x, y: y + scale * 0.62))
        path.closeSubpath()
      }
      context.fill(path, with: .color(Ink.jade.opacity(0.16 + Double(tier) * 0.03)))
      context.stroke(path, with: .color(Ink.jade.opacity(0.22)), lineWidth: 0.5)
    }
  }
}

struct BoardGeometry {
  let side: CGFloat
  let count: Int
  var inset: CGFloat { side * 0.09 }
  var step: CGFloat { (side - inset * 2) / CGFloat(count - 1) }
  func point(_ tile: Tile) -> CGPoint {
    CGPoint(x: inset + CGFloat(tile.x) * step, y: inset + CGFloat(tile.y) * step)
  }
  func tile(at point: CGPoint) -> Tile? {
    let x = Int(((point.x - inset) / step).rounded())
    let y = Int(((point.y - inset) / step).rounded())
    guard (0..<count).contains(x), (0..<count).contains(y) else { return nil }
    let tile = Tile(x: x, y: y)
    let center = self.point(tile)
    guard hypot(center.x - point.x, center.y - point.y) <= step * 0.48 else { return nil }
    return tile
  }
}

struct TownMap: View {
  let puzzle: Puzzle
  let route: [Tile]
  var celebrating = false
  var procession: Double = 0
  var hint = false
  var decorative = false
  var nextSteps: Set<Tile> = []

  var body: some View {
    Canvas { context, size in
      let geo = BoardGeometry(side: size.width, count: puzzle.size)
      let step = geo.step
      let lit = celebrating || decorative
      let frame = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
      context.fill(
        FestivalTicket().path(in: frame),
        with: .linearGradient(
          Gradient(colors: [Ink.panel, Ink.night]),
          startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
      context.stroke(
        FestivalTicket().path(in: frame), with: .color(Ink.gold.opacity(0.3)), lineWidth: 0.6)
      context.stroke(
        FestivalTicket().path(in: frame.insetBy(dx: 4, dy: 4)),
        with: .color(Ink.gold.opacity(0.12)), lineWidth: 0.5)
      for index in 0..<900 {
        let x = CGFloat((index * 137 + 23) % 997) / 997 * (size.width - 16) + 8
        let y = CGFloat((index * 73 + 11) % 991) / 991 * (size.height - 16) + 8
        context.fill(
          Path(CGRect(x: x, y: y, width: 0.7, height: 0.7)), with: .color(Ink.cream.opacity(0.06)))
      }
      for y in 0..<puzzle.size - 1 {
        for x in 0..<puzzle.size - 1 {
          let p = geo.point(Tile(x: x, y: y))
          let seed = x * 13 + y * 7 + puzzle.par
          let narrow = seed % 3 == 1
          if seed % 7 == 0 {
            let pond = CGRect(
              x: p.x + step * 0.23, y: p.y + step * 0.3, width: step * 0.44, height: step * 0.32)
            context.fill(Path(ellipseIn: pond), with: .color(Ink.jade.opacity(0.09)))
            context.stroke(
              Path(ellipseIn: pond.insetBy(dx: 3, dy: 3)), with: .color(Ink.jade.opacity(0.23)),
              lineWidth: 0.6)
            Art.pine(
              &context, at: CGPoint(x: p.x + step * 0.72, y: p.y + step * 0.52), scale: step * 0.17)
          } else {
            Art.roof(
              &context,
              rect: CGRect(
                x: p.x + step * (narrow ? 0.3 : 0.2), y: p.y + step * (seed % 2 == 0 ? 0.24 : 0.3),
                width: step * (narrow ? 0.43 : 0.6), height: step * (narrow ? 0.54 : 0.42)),
              seed: seed, lit: lit || route.contains(Tile(x: x, y: y)))
          }
          if seed % 4 == 1 {
            Art.line(
              &context, from: CGPoint(x: p.x + step * 0.22, y: p.y + step * 0.74),
              to: CGPoint(x: p.x + step * 0.72, y: p.y + step * 0.74),
              color: Ink.gold.opacity(0.25), width: 1)
            for i in 0..<3 {
              context.fill(
                Path(
                  CGRect(
                    x: p.x + step * (0.25 + Double(i) * 0.18), y: p.y + step * 0.76, width: 3,
                    height: 4)),
                with: .color([Ink.gold, Ink.rose, Ink.jade][i].opacity(0.45)))
            }
          }
          if seed % 3 == 0 {
            Art.blossom(
              &context, at: CGPoint(x: p.x + step * 0.8, y: p.y + step * 0.72), scale: step * 0.16)
          } else if seed % 3 == 1 {
            Art.pine(
              &context, at: CGPoint(x: p.x + step * 0.23, y: p.y + step * 0.76), scale: step * 0.12)
          }
        }
      }
      for y in 0..<puzzle.size {
        for x in 0..<puzzle.size {
          let tile = Tile(x: x, y: y)
          let p = geo.point(tile)
          if puzzle.blocked.contains(tile) {
            Art.pine(&context, at: CGPoint(x: p.x - 3, y: p.y - 2), scale: step * 0.2)
            Art.pine(&context, at: CGPoint(x: p.x + 5, y: p.y + 3), scale: step * 0.14)
            continue
          }
          for next in [Tile(x: x + 1, y: y), Tile(x: x, y: y + 1)]
          where next.x < puzzle.size && next.y < puzzle.size && !puzzle.blocked.contains(next) {
            Art.line(
              &context, from: p, to: geo.point(next), color: Ink.gold.opacity(0.06), width: 12)
            Art.line(
              &context, from: p, to: geo.point(next), color: Ink.muted.opacity(0.12), width: 8)
            let end = geo.point(next)
            for stone in 1..<6 {
              let t = CGFloat(stone) / 6
              let center = CGPoint(x: p.x + (end.x - p.x) * t, y: p.y + (end.y - p.y) * t)
              let horizontal = next.x != tile.x
              Art.line(
                &context,
                from: CGPoint(
                  x: center.x - (horizontal ? 0 : 3), y: center.y - (horizontal ? 3 : 0)),
                to: CGPoint(x: center.x + (horizontal ? 0 : 3), y: center.y + (horizontal ? 3 : 0)),
                color: Ink.gold.opacity(0.11), width: 0.5)
            }
          }
          context.fill(
            Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)),
            with: .color(Ink.muted.opacity(0.6)))
          if nextSteps.contains(tile) {
            context.stroke(
              Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)),
              with: .color(Ink.gold.opacity(0.55)), lineWidth: 1)
            context.fill(
              Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)),
              with: .color(Ink.gold.opacity(0.8)))
          }
        }
      }
      if hint {
        strokeRoute(
          &context, route: puzzle.solution, geometry: geo, color: Ink.cream.opacity(0.45), width: 2,
          dash: [3, 7])
      }
      context.drawLayer { glow in
        glow.addFilter(.blur(radius: 4))
        strokeRoute(&glow, route: route, geometry: geo, color: Ink.gold.opacity(0.4), width: 9)
      }
      strokeRoute(&context, route: route, geometry: geo, color: Ink.gold, width: 3)
      strokeRoute(&context, route: route, geometry: geo, color: Ink.cream.opacity(0.8), width: 0.8)

      let finish = geo.point(puzzle.finish)
      let r = step * 0.24
      context.fill(
        Path(
          ellipseIn: CGRect(x: finish.x - r * 2, y: finish.y - r * 2, width: r * 4, height: r * 4)),
        with: .radialGradient(
          Gradient(colors: [Ink.gold.opacity(lit ? 0.6 : 0.12), .clear]),
          center: finish, startRadius: 0, endRadius: r * 2))
      let square = CGRect(x: finish.x - r, y: finish.y - r, width: r * 2, height: r * 2)
      context.fill(FestivalTicket().path(in: square), with: .color(Ink.panel))
      context.stroke(
        FestivalTicket().path(in: square), with: .color(Ink.gold.opacity(0.9)), lineWidth: 1)
      context.stroke(
        Path(ellipseIn: square.insetBy(dx: 4, dy: 4)), with: .color(Ink.gold.opacity(0.45)),
        lineWidth: 0.5)
      context.draw(
        Text(Image(systemName: "sparkle")).font(.system(size: step * 0.23, weight: .light))
          .foregroundColor(
            Ink.gold),
        at: finish)

      let start = geo.point(puzzle.start)
      context.fill(
        Path(ellipseIn: CGRect(x: start.x - 10, y: start.y - 10, width: 20, height: 20)),
        with: .color(Ink.cream))
      context.draw(
        Text(Image(systemName: "flag.fill")).font(.system(size: 10)).foregroundColor(Ink.night),
        at: start)
      for (tile, gate) in puzzle.gates {
        let p = geo.point(tile)
        let open = route.compactMap { puzzle.lanterns[$0] }.contains(gate)
        let color = gate.ink.opacity(open ? 0.65 : 1)
        for x in [-1.0, 1.0] {
          Art.line(
            &context, from: CGPoint(x: p.x + x * (open ? 14 : 10), y: p.y - 9),
            to: CGPoint(x: p.x + x * (open ? 14 : 10), y: p.y + 10), color: color, width: 2.4)
        }
        Art.line(
          &context, from: CGPoint(x: p.x - 18, y: p.y - (open ? 16 : 10)),
          to: CGPoint(x: p.x + 18, y: p.y - (open ? 16 : 10)), color: color, width: 2.8)
        Art.line(
          &context, from: CGPoint(x: p.x - 14, y: p.y - (open ? 12 : 6)),
          to: CGPoint(x: p.x + 14, y: p.y - (open ? 12 : 6)), color: color.opacity(0.7), width: 1)
        context.draw(
          Text(Image(systemName: open ? "checkmark" : gate.symbol)).font(.system(size: 9))
            .foregroundColor(color),
          at: CGPoint(x: p.x, y: p.y + (open ? -25 : 1)))
      }
      for (tile, lantern) in puzzle.lanterns {
        let p = geo.point(tile)
        Art.lantern(&context, at: p, radius: step * 0.17, color: lantern.ink)
        context.draw(
          Text("\(lantern.rawValue + 1)").font(TypeStyle.title(13)).foregroundColor(
            Ink.night),
          at: p)
        if route.contains(tile) {
          context.stroke(
            Path(ellipseIn: CGRect(x: p.x - 16, y: p.y - 17, width: 32, height: 34)),
            with: .color(lantern.ink.opacity(0.6)), lineWidth: 1)
        }
      }
      if let head = route.last, !celebrating, !decorative {
        let p = geo.point(head)
        context.stroke(
          Path(ellipseIn: CGRect(x: p.x - 20, y: p.y - 20, width: 40, height: 40)),
          with: .color(Ink.cream.opacity(0.55)), style: StrokeStyle(lineWidth: 0.7, dash: [1, 5]))
      }
      if celebrating || decorative {
        for index in 0..<min(route.count, 9) {
          let progress = max(
            0,
            min(
              Double(route.count - 1), procession * Double(route.count + 3) - Double(index) * 0.52))
          let low = Int(progress)
          let high = min(low + 1, route.count - 1)
          let fraction = progress - Double(low)
          let a = geo.point(route[low])
          let b = geo.point(route[high])
          let p = CGPoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction)
          context.fill(
            Path(ellipseIn: CGRect(x: p.x - 3, y: p.y + 2, width: 6, height: 8)),
            with: .color([Ink.rose, Ink.jade, Ink.gold][index % 3]))
          context.fill(
            Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)),
            with: .color(Ink.cream))
          Art.lantern(&context, at: CGPoint(x: p.x + 5, y: p.y - 6), radius: 3.3, color: Ink.gold)
        }
        if celebrating {
          for index in 0..<30 {
            let phase = procession * 4 + Double(index) * 0.31
            let p = CGPoint(
              x: finish.x + sin(Double(index) * 4.1) * step
                * (0.4 + phase.truncatingRemainder(dividingBy: 1)),
              y: finish.y - phase.truncatingRemainder(dividingBy: 1) * step * 1.8)
            context.fill(
              Path(ellipseIn: CGRect(x: p.x, y: p.y, width: 2.5, height: 2.5)),
              with: .color(Ink.gold.opacity(0.65)))
          }
        }
      }
    }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
  }

  private func strokeRoute(
    _ context: inout GraphicsContext, route: [Tile], geometry: BoardGeometry, color: Color,
    width: CGFloat, dash: [CGFloat] = []
  ) {
    guard let first = route.first else { return }
    var path = Path()
    path.move(to: geometry.point(first))
    for tile in route.dropFirst() { path.addLine(to: geometry.point(tile)) }
    context.stroke(
      path, with: .color(color),
      style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash))
  }
}

struct FestivalTicket: Shape {
  func path(in rect: CGRect) -> Path {
    let cut: CGFloat = 7
    return Path { path in
      path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
      path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
      path.closeSubpath()
    }
  }
}

struct GoldButtonStyle: ButtonStyle {
  var secondary = false
  @Environment(\.isEnabled) private var isEnabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 14, weight: .medium))
      .tracking(0.2)
      .frame(maxWidth: .infinity, minHeight: 54)
      .foregroundStyle(secondary ? Ink.cream : Ink.night)
      .background(secondary ? Color.clear : Ink.cream, in: FestivalTicket())
      .overlay {
        if secondary {
          Rectangle().fill(Ink.rule).frame(height: 0.5).frame(
            maxHeight: .infinity, alignment: .bottom)
        } else {
          FestivalTicket().stroke(Ink.night.opacity(0.2), lineWidth: 0.5).padding(4)
        }
      }
      .contentShape(Rectangle())
      .opacity(!isEnabled ? 0.35 : configuration.isPressed ? 0.7 : 1)
  }
}

struct FestivalVignette: View {
  var body: some View {
    GeometryReader { geometry in
      Image("FestivalTown")
        .resizable().scaledToFill()
        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        .clipped()
        .mask(
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: .black, location: 0.12),
              .init(color: .black, location: 0.82),
              .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        )
    }.accessibilityHidden(true)
  }
}

struct Eyebrow: View {
  let text: String
  var body: some View {
    Text(text.uppercased()).font(.system(size: 9, weight: .medium))
      .tracking(2.3).foregroundStyle(Ink.gold)
  }
}

struct Stars: View {
  let count: Int
  var onPaper = false
  var body: some View {
    HStack(spacing: 5) {
      ForEach(0..<3) { index in
        Image(systemName: index < count ? "star.fill" : "star")
          .foregroundStyle(
            index < count
              ? (onPaper ? Ink.night : Ink.gold)
              : (onPaper ? Ink.night.opacity(0.45) : Ink.muted.opacity(0.8)))
      }
    }.accessibilityLabel("\(count) of 3 stars")
  }
}
