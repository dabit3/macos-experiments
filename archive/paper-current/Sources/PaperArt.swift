import SwiftUI

enum Ink {
  static let night = Color(red: 0.035, green: 0.105, blue: 0.12)
  static let blue = Color(red: 0.20, green: 0.33, blue: 0.35)
  static let water = Color(red: 0.22, green: 0.40, blue: 0.43)
  static let foam = Color(red: 0.62, green: 0.79, blue: 0.73)
  static let paper = Color(red: 0.86, green: 0.83, blue: 0.75)
  static let cream = Color(red: 0.96, green: 0.93, blue: 0.85)
  static let red = Color(red: 0.70, green: 0.25, blue: 0.18)
  static let gold = Color(red: 0.83, green: 0.67, blue: 0.42)
  static let muted = Color(red: 0.62, green: 0.70, blue: 0.67)

  static func title(_ size: CGFloat) -> Font { .custom("Baskerville", size: size) }
  static func italic(_ size: CGFloat) -> Font { .custom("Baskerville-Italic", size: size) }
}

struct NightPaper: View {
  var body: some View {
    ZStack {
      Ink.night
      RadialGradient(
        colors: [Ink.blue.opacity(0.35), .clear],
        center: .init(x: 0.5, y: 0.35), startRadius: 0, endRadius: 500)
      PaperTexture(light: true)
    }.ignoresSafeArea().accessibilityHidden(true)
  }
}

struct HarborIllustration: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      Image("Harbor").resizable().scaledToFit()
        .mask {
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: .black, location: 0.12),
              .init(color: .black, location: 0.84),
              .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom
          )
          .mask {
            LinearGradient(
              stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.08),
                .init(color: .black, location: 0.92),
                .init(color: .clear, location: 1),
              ], startPoint: .leading, endPoint: .trailing)
          }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .overlay {
          TimelineView(.animation(minimumInterval: 0.06, paused: reduceMotion)) { timeline in
            Canvas { context, size in
              let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
              for index in 0..<24 {
                let x = CGFloat((index * 71 + 23) % 397) / 397 * size.width
                let y = (CGFloat(index * 43) + time.truncatingRemainder(dividingBy: 20) * 20)
                  .truncatingRemainder(dividingBy: size.height)
                var rain = Path()
                rain.move(to: CGPoint(x: x, y: y))
                rain.addLine(to: CGPoint(x: x - 2, y: y + 9))
                context.stroke(rain, with: .color(Ink.paper.opacity(0.13)), lineWidth: 0.6)
              }
            }
          }
        }
    }.accessibilityHidden(true)
  }
}

struct PostalRule: View {
  var color = Ink.gold
  var body: some View {
    HStack(spacing: 12) {
      Rectangle().frame(height: 0.5)
      Image(systemName: "water.waves").font(.system(size: 13, weight: .ultraLight))
      Rectangle().frame(height: 0.5)
    }.foregroundStyle(color.opacity(0.5)).accessibilityHidden(true)
  }
}

struct PostalSeal: View {
  var number = "10"
  var color = Ink.gold
  var body: some View {
    ZStack {
      Circle().strokeBorder(color.opacity(0.6), lineWidth: 0.7)
      Circle().strokeBorder(color.opacity(0.4), lineWidth: 0.5).padding(4)
      VStack(spacing: 3) {
        Text("PAPER POST").font(.system(size: 6, weight: .semibold)).tracking(1)
        Text(number).font(Ink.italic(22))
        Text("BY WATER").font(.system(size: 5, weight: .semibold)).tracking(1)
      }.foregroundStyle(color)
    }.frame(width: 62, height: 62).accessibilityHidden(true)
  }
}

struct StampShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let horizontal = max(2, Int(rect.width / 6))
    let vertical = max(2, Int(rect.height / 6))
    let dx = rect.width / CGFloat(horizontal)
    let dy = rect.height / CGFloat(vertical)
    path.move(to: .zero)
    for index in 0..<horizontal {
      let x = CGFloat(index) * dx
      path.addLine(to: CGPoint(x: x + dx * 0.28, y: 0))
      path.addQuadCurve(
        to: CGPoint(x: x + dx * 0.72, y: 0),
        control: CGPoint(x: x + dx * 0.5, y: 3))
      path.addLine(to: CGPoint(x: x + dx, y: 0))
    }
    for index in 0..<vertical {
      let y = CGFloat(index) * dy
      path.addLine(to: CGPoint(x: rect.width, y: y + dy * 0.28))
      path.addQuadCurve(
        to: CGPoint(x: rect.width, y: y + dy * 0.72),
        control: CGPoint(x: rect.width - 3, y: y + dy * 0.5))
      path.addLine(to: CGPoint(x: rect.width, y: y + dy))
    }
    for index in 0..<horizontal {
      let x = rect.width - CGFloat(index) * dx
      path.addLine(to: CGPoint(x: x - dx * 0.28, y: rect.height))
      path.addQuadCurve(
        to: CGPoint(x: x - dx * 0.72, y: rect.height),
        control: CGPoint(x: x - dx * 0.5, y: rect.height - 3))
      path.addLine(to: CGPoint(x: x - dx, y: rect.height))
    }
    for index in 0..<vertical {
      let y = rect.height - CGFloat(index) * dy
      path.addLine(to: CGPoint(x: 0, y: y - dy * 0.28))
      path.addQuadCurve(
        to: CGPoint(x: 0, y: y - dy * 0.72),
        control: CGPoint(x: 3, y: y - dy * 0.5))
      path.addLine(to: CGPoint(x: 0, y: y - dy))
    }
    path.closeSubpath()
    return path
  }
}

struct PaperStamp: View {
  var filled = true
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        StampShape().fill(filled ? Ink.gold : Ink.paper.opacity(0.15))
        Rectangle().strokeBorder(
          filled ? Ink.night.opacity(0.3) : Ink.paper.opacity(0.35), lineWidth: 0.6
        )
        .padding(4)
        Image(systemName: "envelope").font(
          .system(size: geometry.size.width * 0.42, weight: .light)
        )
        .foregroundStyle(filled ? Ink.night : Ink.paper)
      }
    }.accessibilityHidden(true)
  }
}

struct BookArrival: ViewModifier {
  @State private var opened = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func body(content: Content) -> some View {
    content
      .opacity(opened ? 1 : 0)
      .rotation3DEffect(
        .degrees(opened || reduceMotion ? 0 : -8),
        axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.3
      )
      .offset(y: opened || reduceMotion ? 0 : 14)
      .onAppear {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.7)) { opened = true }
      }
  }
}

func polygon(_ points: [CGPoint]) -> Path {
  Path { path in
    guard let first = points.first else { return }
    path.move(to: first)
    for point in points.dropFirst() { path.addLine(to: point) }
    path.closeSubpath()
  }
}

struct PaperBoat: View {
  var body: some View {
    Canvas { context, size in
      let w = size.width
      let h = size.height
      func shape(_ points: [(CGFloat, CGFloat)], _ color: Color) {
        context.fill(
          polygon(points.map { CGPoint(x: $0.0 * w, y: $0.1 * h) }), with: .color(color))
      }
      context.fill(
        Path(ellipseIn: CGRect(x: w * 0.08, y: h * 0.77, width: w * 0.84, height: h * 0.14)),
        with: .color(Ink.night.opacity(0.2)))
      shape([(0.08, 0.40), (0.43, 0.04), (0.47, 0.51)], Ink.cream)
      shape([(0.43, 0.04), (0.82, 0.47), (0.47, 0.51)], Ink.paper)
      shape([(0, 0.42), (0.47, 0.57), (1, 0.34), (0.75, 0.82), (0.26, 0.82)], Ink.cream)
      shape(
        [(0.47, 0.57), (1, 0.34), (0.75, 0.82), (0.47, 0.72)],
        Color(red: 0.82, green: 0.78, blue: 0.67))
      shape([(0.42, 0.48), (0.58, 0.45), (0.59, 0.58), (0.43, 0.61)], Ink.red)
      var crease = Path()
      crease.move(to: CGPoint(x: w * 0.26, y: h * 0.82))
      crease.addLine(to: CGPoint(x: w * 0.47, y: h * 0.57))
      context.stroke(crease, with: .color(Ink.blue.opacity(0.3)), lineWidth: 0.8)
    }
    .accessibilityHidden(true)
  }
}

struct TownArt: View {
  var animated = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 0.08, paused: !animated || reduceMotion)) { timeline in
      let time = animated && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0
      Canvas { context, size in
        context.scaleBy(x: size.width / 400, y: size.height / 380)
        drawTown(&context, time: time)
      }
      .overlay(alignment: .bottom) {
        PaperBoat().frame(width: 89, height: 65)
          .rotationEffect(.degrees(-8))
          .offset(x: -16, y: -27 + (reduceMotion ? 0 : sin(time * 1.5) * 3))
      }
    }
    .accessibilityHidden(true)
  }

  private func drawTown(_ context: inout GraphicsContext, time: Double) {
    let island = polygon([
      CGPoint(x: 5, y: 182), CGPoint(x: 80, y: 98), CGPoint(x: 191, y: 129),
      CGPoint(x: 230, y: 66), CGPoint(x: 369, y: 114), CGPoint(x: 400, y: 232),
      CGPoint(x: 341, y: 314), CGPoint(x: 228, y: 347), CGPoint(x: 59, y: 302),
    ])
    var shadow = context
    shadow.translateBy(x: 0, y: 13)
    shadow.fill(island, with: .color(Ink.night.opacity(0.9)))
    context.fill(island, with: .color(Ink.paper))
    context.stroke(island, with: .color(Ink.cream), lineWidth: 3)
    var river = Path()
    river.move(to: CGPoint(x: 154, y: 337))
    river.addCurve(
      to: CGPoint(x: 248, y: 264), control1: CGPoint(x: 141, y: 279),
      control2: CGPoint(x: 249, y: 321))
    river.addCurve(
      to: CGPoint(x: 177, y: 206), control1: CGPoint(x: 250, y: 224),
      control2: CGPoint(x: 170, y: 255))
    river.addCurve(
      to: CGPoint(x: 279, y: 143), control1: CGPoint(x: 173, y: 161),
      control2: CGPoint(x: 288, y: 197))
    river.addLine(to: CGPoint(x: 268, y: 83))
    context.stroke(
      river, with: .color(Color(red: 0.69, green: 0.67, blue: 0.58)),
      style: StrokeStyle(lineWidth: 54, lineCap: .butt))
    context.stroke(river, with: .color(Ink.blue), style: StrokeStyle(lineWidth: 46, lineCap: .butt))
    context.stroke(
      river, with: .color(Ink.water), style: StrokeStyle(lineWidth: 35, lineCap: .butt))
    context.stroke(
      river, with: .color(Ink.foam.opacity(0.5)),
      style: StrokeStyle(lineWidth: 1, dash: [10, 15], dashPhase: time * 6))
    for house in [
      (56.0, 151.0, 42.0, 58.0, false), (101, 141, 38, 81, true),
      (150, 157, 32, 57, false), (213, 119, 30, 66, false),
      (302, 151, 41, 87, true), (346, 191, 32, 55, false),
      (69, 245, 39, 70, true), (115, 265, 37, 64, false),
      (298, 261, 43, 72, false), (342, 253, 26, 46, true),
      (213, 295, 28, 47, true),
    ] {
      drawHouse(&context, x: house.0, y: house.1, width: house.2, height: house.3, red: house.4)
    }
    for i in 0..<11 {
      let x = CGFloat((i * 79 + 32) % 360) + 20
      let y = CGFloat((i * 43 + 210) % 165) + 154
      context.fill(
        Path(ellipseIn: CGRect(x: x, y: y, width: 10, height: 4)),
        with: .color(Ink.blue.opacity(0.12)))
    }
    for i in 0..<40 {
      let x = CGFloat((i * 73 + 19) % 400)
      let y = (CGFloat((i * 47) % 380) + time.truncatingRemainder(dividingBy: 20) * 11)
        .truncatingRemainder(dividingBy: 380)
      var rain = Path()
      rain.move(to: CGPoint(x: x, y: y))
      rain.addLine(to: CGPoint(x: x - 2, y: y + 7))
      context.stroke(rain, with: .color(Ink.foam.opacity(0.25)), lineWidth: 1)
    }
    drawBridge(&context, x: 190, y: 196)
  }
}

func drawHouse(
  _ context: inout GraphicsContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
  red: Bool
) {
  let wall =
    red ? Color(red: 0.66, green: 0.42, blue: 0.32) : Color(red: 0.72, green: 0.73, blue: 0.64)
  let face = CGRect(x: x, y: y - height, width: width, height: height)
  context.fill(
    Path(roundedRect: CGRect(x: x - 7, y: y - 4, width: width + 24, height: 12), cornerRadius: 3),
    with: .color(Ink.blue.opacity(0.1)))
  context.fill(
    polygon([
      CGPoint(x: x, y: y), CGPoint(x: x + 17, y: y + 9),
      CGPoint(x: x + width + 24, y: y + 5), CGPoint(x: x + width, y: y - 12),
    ]), with: .color(Ink.night.opacity(0.19)))
  context.fill(
    Path(face),
    with: .linearGradient(
      Gradient(colors: [wall, wall.opacity(0.7)]),
      startPoint: CGPoint(x: x, y: y - height), endPoint: CGPoint(x: x + width, y: y)))
  context.fill(
    polygon([
      CGPoint(x: x + width, y: y - height), CGPoint(x: x + width + 9, y: y - height + 7),
      CGPoint(x: x + width + 9, y: y - 5), CGPoint(x: x + width, y: y),
    ]), with: .color(Ink.blue.opacity(0.75)))
  let roof = red ? Ink.red : Ink.blue
  context.fill(
    polygon([
      CGPoint(x: x + width / 2, y: y - height - 19),
      CGPoint(x: x + width / 2 + 8, y: y - height - 13),
      CGPoint(x: x + width + 12, y: y - height + 7),
      CGPoint(x: x + width + 4, y: y - height + 1),
    ]), with: .color(roof.opacity(0.7)))
  context.fill(
    polygon([
      CGPoint(x: x - 3, y: y - height + 1), CGPoint(x: x + width / 2, y: y - height - 19),
      CGPoint(x: x + width + 4, y: y - height + 1),
    ]), with: .color(roof))
  context.fill(
    Path(CGRect(x: x + width * 0.70, y: y - height - 16, width: 5, height: 12)),
    with: .color(wall))
  context.fill(
    Path(CGRect(x: x + width * 0.70 - 1, y: y - height - 17, width: 7, height: 2)),
    with: .color(Ink.paper))
  var fold = Path()
  fold.move(to: CGPoint(x: x + width / 2, y: y - height - 17))
  fold.addLine(to: CGPoint(x: x + width / 2, y: y - height))
  context.stroke(fold, with: .color(Ink.cream.opacity(0.4)), lineWidth: 0.6)
  var eave = Path()
  eave.move(to: CGPoint(x: x - 3, y: y - height + 1))
  eave.addLine(to: CGPoint(x: x + width + 3, y: y - height + 1))
  context.stroke(eave, with: .color(Ink.night.opacity(0.25)), lineWidth: 2)
  for index in 0..<14 {
    let xx = x + CGFloat(index * 13 % max(1, Int(width)))
    let yy = y - height + CGFloat(index * 17 % max(1, Int(height)))
    context.fill(
      Path(CGRect(x: xx, y: yy, width: 2, height: 0.4)),
      with: .color(Ink.night.opacity(0.1)))
  }
  for row in 0..<max(1, Int(height / 23)) {
    for col in 0..<2 {
      let rect = CGRect(
        x: x + 7 + CGFloat(col) * (width - 19), y: y - height + 10 + CGFloat(row) * 18, width: 6,
        height: 9)
      context.fill(Path(rect.insetBy(dx: -1, dy: -1)), with: .color(Ink.blue.opacity(0.6)))
      context.fill(
        Path(rect),
        with: .linearGradient(
          Gradient(colors: [Ink.gold, Ink.cream]), startPoint: rect.origin,
          endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
      context.fill(
        Path(CGRect(x: rect.minX - 1, y: rect.maxY, width: 8, height: 1.2)),
        with: .color(Ink.cream.opacity(0.7)))
      context.fill(
        Path(CGRect(x: rect.midX, y: rect.minY, width: 0.8, height: rect.height)),
        with: .color(wall))
    }
  }
  let door = CGRect(x: x + width / 2 - 4, y: y - 12, width: 8, height: 12)
  context.fill(Path(roundedRect: door, cornerRadius: 3), with: .color(Ink.blue))
  context.fill(
    Path(CGRect(x: x + width / 2 - 6, y: y - 1, width: 12, height: 2)),
    with: .color(Ink.cream))
  context.fill(
    Path(ellipseIn: CGRect(x: door.maxX - 2.5, y: door.midY, width: 1, height: 1)),
    with: .color(Ink.gold))
}

private func drawBridge(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat) {
  let deck = CGRect(x: x, y: y, width: 52, height: 20)
  context.fill(Path(deck.offsetBy(dx: 3, dy: 5)), with: .color(Ink.night.opacity(0.25)))
  context.fill(Path(deck), with: .color(Ink.cream))
  for i in 0..<7 {
    let xx = x + CGFloat(i) * 8
    var line = Path()
    line.move(to: CGPoint(x: xx, y: y))
    line.addLine(to: CGPoint(x: xx, y: y + 20))
    context.stroke(line, with: .color(Ink.blue.opacity(0.25)), lineWidth: 1)
  }
  context.fill(Path(CGRect(x: x - 2, y: y - 4, width: 56, height: 4)), with: .color(Ink.red))
  context.fill(Path(CGRect(x: x - 2, y: y + 18, width: 56, height: 4)), with: .color(Ink.red))
}

struct PaperTexture: View {
  var light = false
  var body: some View {
    Canvas { context, size in
      var seed: UInt64 = 0x5041_5045_52
      let fibers = max(0, min(4000, Int(size.width * size.height / 90)))
      for i in 0..<fibers {
        seed = seed &* 2_862_933_555_777_941_757 &+ 3_037_000_493
        let x = CGFloat((seed >> 32) % 65_536) / 65_536 * size.width
        seed = seed &* 2_862_933_555_777_941_757 &+ 3_037_000_493
        let y = CGFloat((seed >> 32) % 65_536) / 65_536 * size.height
        context.fill(
          Path(CGRect(x: x, y: y, width: i % 3 == 0 ? 1.5 : 0.6, height: 0.5)),
          with: .color(light ? Ink.cream.opacity(0.035) : Ink.night.opacity(0.06)))
      }
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}

struct CanalDrawing: View {
  let canal: Canal
  let lit: Bool
  @State private var angle: Double
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  init(canal: Canal, lit: Bool) {
    self.canal = canal
    self.lit = lit
    _angle = State(initialValue: Double(canal.turns) * 90)
  }

  var body: some View {
    Canvas { context, size in
      let w = size.width
      let h = size.height
      let center = CGPoint(x: w / 2, y: h / 2)
      func point(_ direction: Direction) -> CGPoint {
        switch direction {
        case .north: return CGPoint(x: w / 2, y: -2)
        case .east: return CGPoint(x: w + 2, y: h / 2)
        case .south: return CGPoint(x: w / 2, y: h + 2)
        case .west: return CGPoint(x: -2, y: h / 2)
        }
      }
      var water = Path()
      water.move(to: point(canal.entry))
      water.addLine(to: center)
      water.addLine(to: point(canal.exit))
      context.stroke(
        water, with: .color(Ink.night.opacity(0.18)),
        style: StrokeStyle(lineWidth: w * 0.51, lineJoin: .round))
      context.stroke(
        water, with: .color(Ink.cream), style: StrokeStyle(lineWidth: w * 0.47, lineJoin: .round))
      context.stroke(
        water, with: .color(Ink.blue.opacity(0.6)),
        style: StrokeStyle(lineWidth: w * 0.36, lineJoin: .round))
      context.stroke(
        water,
        with: .linearGradient(
          Gradient(colors: [lit ? Ink.foam : Ink.water, lit ? Ink.water : Ink.blue]),
          startPoint: .zero, endPoint: CGPoint(x: w, y: h)),
        style: StrokeStyle(lineWidth: w * 0.30, lineJoin: .round))
      context.stroke(
        water, with: .color(Ink.cream.opacity(lit ? 0.6 : 0.18)),
        style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [3, 8]))
      for index in 0..<4 {
        let x = CGFloat(index % 2 == 0 ? 7 : w - 7)
        let y = CGFloat(index < 2 ? 7 : h - 7)
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
          with: .color(Ink.blue.opacity(0.25)))
      }
      if canal.isCurrent {
        let direction = canal.exit
        var arrowContext = context
        arrowContext.translateBy(x: w / 2, y: h / 2)
        arrowContext.rotate(by: .degrees(Double(direction.rawValue) * 90))
        let arrow = polygon([
          CGPoint(x: 0, y: -10), CGPoint(x: 6, y: 0), CGPoint(x: 2, y: 0),
          CGPoint(x: 2, y: 8), CGPoint(x: -2, y: 8), CGPoint(x: -2, y: 0),
          CGPoint(x: -6, y: 0),
        ])
        arrowContext.fill(arrow, with: .color(Ink.cream))
      }
      if canal.isLock {
        var gate = context
        gate.translateBy(x: w / 2, y: h / 2)
        gate.rotate(by: .degrees(Double(canal.entry.rawValue) * 90))
        for side in [-1.0, 1.0] {
          var leaf = gate
          leaf.translateBy(x: side * w * 0.23, y: -h * 0.04)
          leaf.rotate(by: .degrees(canal.open ? side * 65 : 0))
          let rect = CGRect(x: side < 0 ? 0 : -w * 0.23, y: 0, width: w * 0.23, height: h * 0.1)
          leaf.fill(Path(rect.offsetBy(dx: 0, dy: 2)), with: .color(Ink.night.opacity(0.3)))
          leaf.fill(Path(rect), with: .color(canal.open ? Ink.gold : Ink.red))
          leaf.stroke(
            Path(rect.insetBy(dx: 2, dy: 2)), with: .color(Ink.cream.opacity(0.5)), lineWidth: 0.8)
        }
      }
    }
    .rotationEffect(.degrees(angle))
    .onChange(of: canal.turns) { old, new in
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
        angle += Double((new - old + 6) % 4 - 2) * 90
      }
    }
  }
}

func drawGarden(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat, variant: Int) {
  context.fill(
    Path(ellipseIn: CGRect(x: x - 3, y: y, width: 14, height: 4)),
    with: .color(Ink.night.opacity(0.12)))
  if variant % 2 == 0 {
    context.fill(Path(CGRect(x: x + 3, y: y - 13, width: 1.3, height: 14)), with: .color(Ink.blue))
    for index in 0..<7 {
      let yy = y - CGFloat(index) * 2.5 - 8
      let xx = x + (index % 2 == 0 ? 0 : 5)
      context.fill(
        Path(ellipseIn: CGRect(x: xx, y: yy, width: 6, height: 4)),
        with: .color(index % 2 == 0 ? Ink.water : Ink.blue))
    }
    context.fill(
      polygon([
        CGPoint(x: x, y: y - 2), CGPoint(x: x + 8, y: y - 2),
        CGPoint(x: x + 7, y: y + 3), CGPoint(x: x + 1, y: y + 3),
      ]),
      with: .color(Ink.red.opacity(0.75)))
  } else {
    context.fill(Path(CGRect(x: x + 3, y: y - 21, width: 1.5, height: 22)), with: .color(Ink.blue))
    context.fill(
      Path(ellipseIn: CGRect(x: x - 2, y: y - 25, width: 12, height: 12)),
      with: .color(Ink.gold.opacity(0.25)))
    context.fill(Path(CGRect(x: x, y: y - 23, width: 7, height: 7)), with: .color(Ink.gold))
    context.fill(
      polygon([
        CGPoint(x: x - 2, y: y - 23), CGPoint(x: x + 3.5, y: y - 28),
        CGPoint(x: x + 9, y: y - 23),
      ]), with: .color(Ink.blue))
    context.fill(Path(CGRect(x: x - 1, y: y - 16, width: 9, height: 1)), with: .color(Ink.blue))
  }
}

struct Postbox: View {
  var body: some View {
    GeometryReader { geometry in
      let w = geometry.size.width
      let h = geometry.size.height
      ZStack {
        RoundedRectangle(cornerRadius: w * 0.25)
          .fill(Ink.red.gradient).padding(.horizontal, w * 0.08)
        VStack(spacing: h * 0.09) {
          Rectangle().fill(Ink.cream.opacity(0.7)).frame(height: 1)
          RoundedRectangle(cornerRadius: 1).fill(Ink.night)
            .frame(width: w * 0.48, height: h * 0.07)
          Image(systemName: "envelope").font(.system(size: w * 0.3, weight: .light))
            .foregroundStyle(Ink.cream)
          Rectangle().fill(Ink.cream.opacity(0.3)).frame(height: 1)
        }.padding(.horizontal, w * 0.1)
      }
      .overlay(alignment: .bottom) {
        RoundedRectangle(cornerRadius: 1).fill(Ink.blue).frame(height: h * 0.1)
      }
      .shadow(color: Ink.night.opacity(0.22), radius: 1, x: 2, y: 3)
    }.accessibilityHidden(true)
  }
}

struct StampBurst: View {
  @State private var expanded = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        ForEach(0..<8) { index in
          let angle = Double(index) * .pi / 4
          RoundedRectangle(cornerRadius: 1)
            .fill(Ink.gold)
            .frame(width: 4, height: 7)
            .rotationEffect(.radians(angle))
            .offset(
              x: cos(angle) * (expanded ? geometry.size.width * 0.44 : 8),
              y: sin(angle) * (expanded ? geometry.size.height * 0.44 : 8)
            )
            .opacity(expanded ? 0 : 1)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .onAppear {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.75)) { expanded = true }
      }
    }.accessibilityHidden(true)
  }
}
