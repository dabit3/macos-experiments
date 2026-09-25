import SwiftUI

enum Palette {
  static let cream = Color(red: 0.97, green: 0.93, blue: 0.85)
  static let paper = Color(red: 1, green: 0.985, blue: 0.94)
  static let ink = Color(red: 0.12, green: 0.23, blue: 0.24)
  static let inkDeep = Color(red: 0.07, green: 0.15, blue: 0.17)
  static let gold = Color(red: 0.64, green: 0.42, blue: 0.13)
  static let brassLight = Color(red: 0.99, green: 0.88, blue: 0.60)
  static let brassMid = Color(red: 0.84, green: 0.62, blue: 0.26)
  static let brassDark = Color(red: 0.58, green: 0.38, blue: 0.11)
  static let orange = Color(red: 0.96, green: 0.52, blue: 0.18)
  static let orangeDeep = Color(red: 0.74, green: 0.30, blue: 0.06)
  static let teal = Color(red: 0.30, green: 0.63, blue: 0.64)
  static let tealDeep = Color(red: 0.12, green: 0.38, blue: 0.42)
  static let green = Color(red: 0.30, green: 0.58, blue: 0.38)
  static let greenDeep = Color(red: 0.12, green: 0.36, blue: 0.22)
  static let dusk = Color(red: 0.13, green: 0.14, blue: 0.27)
  static let duskMauve = Color(red: 0.42, green: 0.32, blue: 0.42)

  static let brass = LinearGradient(
    colors: [brassLight, brassMid, brassLight, brassDark], startPoint: .topLeading,
    endPoint: .bottomTrailing)
  static let brassGradient = Gradient(colors: [brassLight, brassMid, brassLight, brassDark])
  static let goldText = LinearGradient(
    colors: [brassDark, brassMid, brassDark], startPoint: .top, endPoint: .bottom)

  static func sky(for board: Int) -> Color {
    [
      Color(red: 0.86, green: 0.88, blue: 0.80),
      Color(red: 0.82, green: 0.82, blue: 0.93),
      Color(red: 0.94, green: 0.84, blue: 0.77),
      Color(red: 0.80, green: 0.88, blue: 0.92),
      Color(red: 0.81, green: 0.89, blue: 0.78),
      Color(red: 0.96, green: 0.85, blue: 0.64),
    ][board % 6]
  }
}

enum Type {
  static func display(_ size: Double) -> Font { .custom("Didot", size: size) }
  static func displayBold(_ size: Double) -> Font { .custom("Didot-Bold", size: size) }
  static func italic(_ size: Double) -> Font { .custom("Didot-Italic", size: size) }
  static func ui(_ size: Double) -> Font { .custom("AvenirNext-Regular", size: size) }
  static func medium(_ size: Double) -> Font { .custom("AvenirNext-Medium", size: size) }
  static func demi(_ size: Double) -> Font { .custom("AvenirNext-DemiBold", size: size) }
  static func bold(_ size: Double) -> Font { .custom("AvenirNext-Bold", size: size) }
}

struct TheaterArt: View {
  let game: GameRules
  var sparks: [GameStore.Spark] = []
  var decorative = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Canvas { context, size in
      let scale = min(size.width / 390, size.height / 560)
      context.translateBy(x: (size.width - 390 * scale) / 2, y: (size.height - 560 * scale) / 2)
      context.scaleBy(x: scale, y: scale)
      drawStage(&context)
      if game.phase == .aiming && !decorative { drawAim(&context) }
      for peg in game.pegs { drawPeg(&context, peg) }
      if !decorative {
        for (index, point) in game.trail.enumerated() {
          circle(
            &context, point.x, point.y, Double(index) / 6.5,
            Palette.brassMid.opacity(Double(index) / 80))
        }
        if game.phase == .flying { drawBall(&context, game.ball) }
        for spark in sparks where !reduceMotion {
          let radius = 10 + spark.age * 46
          for i in 0..<8 {
            let a = Double(i) / 8 * .pi * 2 + spark.age * 2
            star(
              &context, spark.position.x + cos(a) * radius, spark.position.y + sin(a) * radius,
              max(0, 3.4 - spark.age * 4), Palette.brassLight.opacity(1 - spark.age))
          }
          context.stroke(
            Path(
              ellipseIn: CGRect(
                x: spark.position.x - radius * 0.7, y: spark.position.y - radius * 0.7,
                width: radius * 1.4, height: radius * 1.4)),
            with: .color(Palette.brassMid.opacity(0.6 - spark.age * 0.75)), lineWidth: 1)
        }
      }
      drawLauncher(&context)
      drawBucket(&context)
      drawFrame(&context)
      if let remaining = game.finaleRemaining { drawFinale(&context, remaining) }
    }
    .accessibilityHidden(true)
  }

  private var frameRect: CGRect { CGRect(x: 8, y: 6, width: 374, height: 546) }
  private var archPath: Path { Path(roundedRect: frameRect, cornerRadius: 150) }

  private func drawStage(_ context: inout GraphicsContext) {
    let sky = Palette.sky(for: game.board.id)
    let arch = archPath
    context.fill(
      arch,
      with: .linearGradient(
        Gradient(stops: [
          .init(color: sky, location: 0), .init(color: sky.opacity(0.55), location: 0.5),
          .init(color: Palette.paper, location: 1),
        ]),
        startPoint: .init(x: 195, y: 0), endPoint: .init(x: 195, y: 560)))
    var inside = context
    inside.clip(to: arch)
    inside.fill(
      arch,
      with: .radialGradient(
        Gradient(colors: [.clear, Palette.brassDark.opacity(0.10)]),
        center: .init(x: 195, y: 270), startRadius: 150, endRadius: 330))
    let twinkle = decorative ? 0 : game.time
    for i in 0..<42 {
      let x = 30 + Double((i * 71) % 330)
      let y = 88 + Double((i * 83) % 400)
      let pulse = 0.5 + 0.5 * sin(twinkle * 1.6 + Double(i))
      let big = i % 4 == 0
      star(
        &inside, x, y, big ? 2.6 + pulse : 1.4,
        Palette.brassMid.opacity(big ? 0.22 + pulse * 0.28 : 0.20))
    }
    let halo = CGRect(x: 88, y: 165, width: 214, height: 214)
    inside.fill(
      Path(ellipseIn: halo),
      with: .radialGradient(
        Gradient(colors: [Palette.paper.opacity(0.55), Palette.paper.opacity(0)]),
        center: .init(x: 195, y: 272), startRadius: 0, endRadius: 110))
    inside.stroke(
      Path(ellipseIn: halo.insetBy(dx: 8, dy: 8)), with: .color(Palette.brassMid.opacity(0.18)),
      style: StrokeStyle(lineWidth: 1, dash: [1, 5]))
    inside.stroke(
      Path(ellipseIn: halo.insetBy(dx: 22, dy: 22)), with: .color(Palette.brassMid.opacity(0.12)),
      lineWidth: 0.8)
    inside.draw(
      Text(Image(systemName: game.board.symbol))
        .font(.system(size: 118, weight: .ultraLight))
        .foregroundStyle(Palette.brassDark.opacity(0.11)),
      at: CGPoint(x: 195, y: 274))
    for i in 0..<24 {
      let a = Double(i) / 24 * .pi * 2
      let long = i % 2 == 0
      var ray = Path()
      ray.move(to: .init(x: 195 + cos(a) * 107, y: 272 + sin(a) * 107))
      ray.addLine(
        to: .init(x: 195 + cos(a) * (long ? 122 : 114), y: 272 + sin(a) * (long ? 122 : 114)))
      inside.stroke(ray, with: .color(Palette.brassMid.opacity(long ? 0.22 : 0.14)), lineWidth: 1)
    }
    sculptedCloud(&inside, x: -14, y: 470, scale: 1.18, sky: sky)
    sculptedCloud(&inside, x: 246, y: 470, scale: 1.18, sky: sky)
    sculptedCloud(&inside, x: -30, y: 494, scale: 1.24, sky: sky)
    sculptedCloud(&inside, x: 238, y: 494, scale: 1.24, sky: sky)
    let rail = CGRect(x: 40, y: 538, width: 310, height: 5)
    inside.fill(
      Path(roundedRect: rail, cornerRadius: 2.5),
      with: .linearGradient(
        Palette.brassGradient, startPoint: .init(x: 40, y: 538), endPoint: .init(x: 350, y: 543)))
    for x in stride(from: 58.0, through: 332, by: 34) {
      star(&inside, x, 549, 2.6, Palette.brassMid.opacity(0.55))
    }
  }

  private func sculptedCloud(
    _ context: inout GraphicsContext, x: Double, y: Double, scale: Double, sky: Color
  ) {
    cloud(&context, x: x + 3, y: y + 7, scale: scale, color: Palette.brassDark.opacity(0.10))
    cloud(&context, x: x, y: y, scale: scale, color: sky.opacity(0.9))
    cloud(&context, x: x, y: y, scale: scale * 0.94, color: Palette.paper)
    cloud(&context, x: x + 4, y: y - 5, scale: scale * 0.72, color: .white.opacity(0.7))
  }

  private func drawFrame(_ context: inout GraphicsContext) {
    let outer = archPath
    context.stroke(
      outer,
      with: .linearGradient(
        Palette.brassGradient, startPoint: .init(x: 0, y: 0), endPoint: .init(x: 390, y: 560)),
      lineWidth: 5)
    context.stroke(outer, with: .color(Palette.brassDark.opacity(0.55)), lineWidth: 0.8)
    context.stroke(
      Path(roundedRect: frameRect.insetBy(dx: 5.5, dy: 5.5), cornerRadius: 145),
      with: .color(Palette.brassLight.opacity(0.9)), lineWidth: 1)
    context.stroke(
      Path(roundedRect: frameRect.insetBy(dx: -3.2, dy: -3.2), cornerRadius: 153),
      with: .color(Palette.brassDark.opacity(0.35)), lineWidth: 0.8)
    for (x, y) in [(195.0, 6.0), (195, 552), (8, 279), (382, 279)] {
      circle(&context, x, y, 6.5, Palette.brassDark)
      circle(&context, x, y, 5, Palette.brassMid)
      star(&context, x, y, 3.6, Palette.brassLight)
    }
  }

  private func drawAim(_ context: inout GraphicsContext) {
    let preview = game.preview()
    for (index, point) in preview.enumerated() where index % 2 == 0 {
      let fade = 0.85 - Double(index) / 100
      circle(&context, point.x, point.y, 2.8, Palette.paper.opacity(fade))
      circle(&context, point.x, point.y, 1.9, Palette.inkDeep.opacity(fade))
    }
    for point in preview where point.x == 20 || point.x == 370 {
      context.stroke(
        Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)),
        with: .color(Palette.brassMid), lineWidth: 1.8)
      star(&context, point.x, point.y, 3, Palette.brassLight)
    }
    if let point = preview.last {
      context.stroke(
        Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)),
        with: .color(Palette.inkDeep.opacity(0.7)), lineWidth: 1.4)
      circle(&context, point.x, point.y, 1.6, Palette.inkDeep.opacity(0.7))
    }
  }

  private func drawPeg(_ context: inout GraphicsContext, _ peg: Peg) {
    let p = peg.position
    let (light, deep): (Color, Color) =
      switch peg.kind {
      case .gold: (Palette.orange, Palette.orangeDeep)
      case .green: (Palette.green, Palette.greenDeep)
      case .blue: (Palette.teal, Palette.tealDeep)
      }
    let radius = peg.hit ? 11.0 : peg.radius
    context.fill(
      Path(
        ellipseIn: CGRect(
          x: p.x - radius - 1, y: p.y + 1, width: radius * 2 + 2, height: radius * 1.5)),
      with: .radialGradient(
        Gradient(colors: [Palette.inkDeep.opacity(0.22), .clear]),
        center: .init(x: p.x, y: p.y + 4), startRadius: 0, endRadius: radius + 3))
    if peg.hit {
      context.fill(
        Path(ellipseIn: CGRect(x: p.x - 19, y: p.y - 19, width: 38, height: 38)),
        with: .radialGradient(
          Gradient(colors: [light.opacity(0.45), .clear]), center: .init(x: p.x, y: p.y),
          startRadius: 6, endRadius: 19))
    }
    let path = Path(
      ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
    context.fill(
      path,
      with: .radialGradient(
        Gradient(stops: [
          .init(color: peg.hit ? .white : light.opacity(0.75), location: 0),
          .init(color: peg.hit ? Palette.brassLight : light, location: 0.55),
          .init(color: peg.hit ? Palette.brassMid : deep, location: 1),
        ]),
        center: .init(x: p.x - 3, y: p.y - 4), startRadius: 0, endRadius: radius * 1.35))
    context.fill(
      Path(
        ellipseIn: CGRect(
          x: p.x - radius * 0.55, y: p.y + radius * 0.25, width: radius * 1.1, height: radius * 0.5)
      ),
      with: .color(.white.opacity(peg.hit ? 0.5 : 0.22)))
    context.stroke(
      path, with: .color(peg.hit ? Palette.brassDark : deep.opacity(0.9)), lineWidth: 1)
    context.fill(
      Path(ellipseIn: CGRect(x: p.x - 5.6, y: p.y - 7, width: 5.2, height: 3.6)),
      with: .color(.white.opacity(0.85)))
    if peg.kind == .gold {
      star(&context, p.x, p.y, 3.6, Palette.paper.opacity(peg.hit ? 1 : 0.9))
    } else if peg.kind == .green {
      var plus = Path()
      plus.move(to: .init(x: p.x - 3.5, y: p.y))
      plus.addLine(to: .init(x: p.x + 3.5, y: p.y))
      plus.move(to: .init(x: p.x, y: p.y - 3.5))
      plus.addLine(to: .init(x: p.x, y: p.y + 3.5))
      context.stroke(
        plus, with: .color(Palette.paper), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }
  }

  private func drawLauncher(_ context: inout GraphicsContext) {
    context.fill(
      Path(ellipseIn: CGRect(x: 165, y: 22, width: 60, height: 50)),
      with: .radialGradient(
        Gradient(colors: [Palette.brassDark.opacity(0.18), .clear]),
        center: .init(x: 195, y: 48), startRadius: 4, endRadius: 30))
    var launcher = context
    launcher.translateBy(x: 195, y: 46)
    launcher.rotate(by: .radians(-game.angle))
    let barrel = Path(roundedRect: CGRect(x: -10, y: 0, width: 20, height: 40), cornerRadius: 5)
    launcher.fill(
      barrel,
      with: .linearGradient(
        Gradient(colors: [
          Palette.brassDark, Palette.brassLight, Palette.brassMid, Palette.brassDark,
        ]),
        startPoint: .init(x: -10, y: 0), endPoint: .init(x: 10, y: 0)))
    launcher.fill(
      Path(roundedRect: CGRect(x: -5, y: 6, width: 10, height: 34), cornerRadius: 3),
      with: .linearGradient(
        Gradient(colors: [Palette.inkDeep.opacity(0.55), Palette.inkDeep.opacity(0.15)]),
        startPoint: .init(x: -5, y: 6), endPoint: .init(x: 5, y: 6)))
    launcher.fill(
      Path(roundedRect: CGRect(x: -12, y: 34, width: 24, height: 7), cornerRadius: 2),
      with: .linearGradient(
        Palette.brassGradient, startPoint: .init(x: -12, y: 34), endPoint: .init(x: 12, y: 41)))
    launcher.stroke(barrel, with: .color(Palette.brassDark.opacity(0.7)), lineWidth: 0.8)
    for x in [-7.0, 7.0] {
      circle(&launcher, x, 3, 1.4, Palette.brassLight)
    }
    circle(&context, 195, 46, 17, Palette.brassDark)
    circle(&context, 195, 46, 15, Palette.brassMid)
    context.fill(
      Path(ellipseIn: CGRect(x: 183, y: 34, width: 24, height: 24)),
      with: .radialGradient(
        Gradient(colors: [Palette.brassLight, Palette.brassMid]), center: .init(x: 191, y: 41),
        startRadius: 0, endRadius: 14))
    for i in 0..<8 {
      let a = Double(i) / 8 * .pi * 2
      circle(&context, 195 + cos(a) * 13.5, 46 + sin(a) * 13.5, 1.1, Palette.brassDark.opacity(0.7))
    }
    star(&context, 195, 46, 7, Palette.paper)
    if game.phase == .aiming {
      drawBall(&context, .init(x: 195 + sin(game.angle) * 36, y: 46 + cos(game.angle) * 36))
    }
  }

  private func drawBall(_ context: inout GraphicsContext, _ point: Vector) {
    context.fill(
      Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 6, width: 18, height: 16)),
      with: .radialGradient(
        Gradient(colors: [Palette.inkDeep.opacity(0.22), .clear]),
        center: .init(x: point.x, y: point.y + 3), startRadius: 0, endRadius: 9))
    circle(&context, point.x, point.y, 11, Palette.brassLight.opacity(0.28))
    let path = Path(ellipseIn: CGRect(x: point.x - 6.5, y: point.y - 6.5, width: 13, height: 13))
    context.fill(
      path,
      with: .radialGradient(
        Gradient(stops: [
          .init(color: .white, location: 0), .init(color: Palette.paper, location: 0.45),
          .init(color: Palette.brassMid, location: 1),
        ]),
        center: .init(x: point.x - 2.2, y: point.y - 2.4), startRadius: 0, endRadius: 8))
    context.stroke(path, with: .color(Palette.brassDark), lineWidth: 1.2)
  }

  private func drawBucket(_ outer: inout GraphicsContext) {
    var context = outer
    context.clip(to: Path(roundedRect: frameRect.insetBy(dx: 2, dy: 2), cornerRadius: 148))
    let x = decorative ? 195 : game.bucketX
    context.fill(
      Path(ellipseIn: CGRect(x: x - 48, y: 528, width: 96, height: 16)),
      with: .radialGradient(
        Gradient(colors: [Palette.inkDeep.opacity(0.2), .clear]), center: .init(x: x, y: 536),
        startRadius: 0, endRadius: 48))
    var bucket = Path()
    bucket.move(to: .init(x: x - 44, y: 512))
    bucket.addQuadCurve(to: .init(x: x - 27, y: 536), control: .init(x: x - 43, y: 536))
    bucket.addLine(to: .init(x: x + 27, y: 536))
    bucket.addQuadCurve(to: .init(x: x + 44, y: 512), control: .init(x: x + 43, y: 536))
    bucket.closeSubpath()
    context.fill(
      bucket,
      with: .linearGradient(
        Gradient(colors: [
          Palette.brassDark, Palette.brassMid, Palette.brassLight, Palette.brassMid,
          Palette.brassDark,
        ]),
        startPoint: .init(x: x - 44, y: 512), endPoint: .init(x: x + 44, y: 512)))
    context.stroke(bucket, with: .color(Palette.brassDark.opacity(0.8)), lineWidth: 1)
    context.fill(
      Path(ellipseIn: CGRect(x: x - 44, y: 507, width: 88, height: 11)),
      with: .linearGradient(
        Gradient(colors: [Palette.brassLight, Palette.brassMid]), startPoint: .init(x: x, y: 507),
        endPoint: .init(x: x, y: 518)))
    context.fill(
      Path(ellipseIn: CGRect(x: x - 39, y: 509, width: 78, height: 7)),
      with: .color(Palette.inkDeep.opacity(0.6)))
    context.stroke(
      Path(ellipseIn: CGRect(x: x - 44, y: 507, width: 88, height: 11)),
      with: .color(Palette.brassDark.opacity(0.8)), lineWidth: 1)
    star(&context, x, 526, 5, Palette.paper.opacity(0.9))
  }

  private func drawFinale(_ context: inout GraphicsContext, _ remaining: Double) {
    let progress = reduceMotion ? 0.7 : min(1, (1.8 - remaining) / 1.8)
    for ring in 0..<3 {
      let radius = 20 + progress * (26 + Double(ring) * 22)
      context.stroke(
        Path(
          ellipseIn: CGRect(
            x: game.ball.x - radius, y: game.ball.y - radius, width: radius * 2, height: radius * 2)
        ),
        with: .color(Palette.brassLight.opacity((0.9 - progress * 0.5) / Double(ring + 1))),
        lineWidth: 2.2 - Double(ring) * 0.5)
    }
    for i in 0..<36 {
      let a = Double(i) * 2.4 + progress * 0.6
      let r = (54 + Double(i % 9) * 26) * (0.3 + progress)
      star(
        &context, 195 + cos(a) * r, 270 + sin(a) * r, 3.5 + Double(i % 3) * 2.2,
        (i % 2 == 0 ? Palette.brassLight : Palette.paper).opacity(0.95 - progress * 0.4))
    }
  }
}

struct GardenThumbnail: View {
  let board: Board
  var body: some View {
    Canvas { context, size in
      for peg in board.pegs {
        let x = peg.position.x / 390 * size.width
        let y = (peg.position.y - 105) / 380 * size.height
        let color =
          peg.kind == .gold ? Palette.orange : (peg.kind == .green ? Palette.green : Palette.teal)
        circle(&context, x, y + 0.6, 2.4, Palette.inkDeep.opacity(0.18))
        circle(&context, x, y, 2.4, color)
        circle(&context, x - 0.7, y - 0.8, 0.8, .white.opacity(0.8))
      }
    }
    .padding(8).frame(width: 72, height: 72)
    .background(
      RadialGradient(
        colors: [Palette.paper, Palette.sky(for: board.id)], center: .center, startRadius: 4,
        endRadius: 40),
      in: Circle()
    )
    .overlay(Circle().stroke(Palette.brass, lineWidth: 1.6))
    .overlay(Circle().stroke(Palette.brassDark.opacity(0.4), lineWidth: 0.6).padding(3))
    .accessibilityHidden(true)
  }
}

struct BallTray: View {
  let balls: Int
  var body: some View {
    HStack(spacing: 4) {
      ForEach(0..<min(balls, 7), id: \.self) { _ in
        Circle()
          .fill(
            RadialGradient(
              colors: [.white, Palette.brassLight, Palette.brassMid],
              center: .init(x: 0.35, y: 0.3),
              startRadius: 0, endRadius: 6)
          )
          .overlay(Circle().stroke(Palette.brassDark.opacity(0.8), lineWidth: 0.8))
          .frame(width: 9, height: 9)
      }
      if balls > 7 {
        Text("+\(balls - 7)").font(Type.demi(11)).foregroundStyle(Palette.gold)
      }
    }
  }
}

func circle(_ context: inout GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ color: Color)
{
  context.fill(
    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(color))
}

func star(_ context: inout GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ color: Color) {
  var path = Path()
  for i in 0..<8 {
    let a = Double(i) * .pi / 4 - .pi / 2
    let radius = i % 2 == 0 ? r : r * 0.3
    let point = CGPoint(x: x + cos(a) * radius, y: y + sin(a) * radius)
    if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
  }
  path.closeSubpath()
  context.fill(path, with: .color(color))
}

func cloud(_ context: inout GraphicsContext, x: Double, y: Double, scale: Double, color: Color) {
  for (dx, dy, r) in [(0.0, 8.0, 23.0), (28, -3, 34), (66, 4, 27), (96, 16, 20)] {
    circle(&context, x + dx * scale, y + dy * scale, r * scale, color)
  }
  context.fill(
    Path(
      roundedRect: CGRect(
        x: x - 20 * scale, y: y + 4 * scale, width: 136 * scale, height: 35 * scale),
      cornerRadius: 16),
    with: .color(color))
}
