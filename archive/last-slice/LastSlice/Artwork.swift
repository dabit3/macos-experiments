import SwiftUI

enum Palette {
  static let cream = Color(red: 0.98, green: 0.95, blue: 0.86)
  static let paper = Color(red: 1, green: 0.98, blue: 0.92)
  static let red = Color(red: 0.72, green: 0.15, blue: 0.10)
  static let ink = Color(red: 0.22, green: 0.25, blue: 0.15)
  static let olive = Color(red: 0.30, green: 0.36, blue: 0.20)
  static let gold = Color(red: 0.96, green: 0.66, blue: 0.23)
  static let line = Color(red: 0.80, green: 0.76, blue: 0.65)
  static let portionColors = [
    red, olive, Color(red: 0.60, green: 0.36, blue: 0.18),
    Color(red: 0.40, green: 0.38, blue: 0.57),
  ]
  static func serif(_ size: CGFloat) -> Font { .custom("Georgia", size: size) }
}

struct CheckerBand: View {
  var height: CGFloat = 14
  var body: some View {
    Canvas { context, size in
      let unit = height / 2
      for row in 0..<2 {
        for column in 0..<Int(size.width / unit + 1) where (row + column).isMultiple(of: 2) {
          context.fill(
            Path(
              CGRect(x: CGFloat(column) * unit, y: CGFloat(row) * unit, width: unit, height: unit)),
            with: .color(Palette.red))
        }
      }
    }.frame(height: height)
  }
}

struct GuestPortrait: View {
  let id: Int
  var happy = false
  var body: some View {
    Canvas { context, size in
      context.scaleBy(x: size.width / 64, y: size.height / 64)
      func ellipse(_ rect: CGRect, _ color: Color) {
        context.fill(Path(ellipseIn: rect), with: .color(color))
      }
      let hair = [
        Palette.ink, Palette.red, Color(red: 0.38, green: 0.25, blue: 0.16), Palette.ink,
      ][id % 4]
      let skin = [
        Color(red: 0.92, green: 0.64, blue: 0.43), Color(red: 0.97, green: 0.74, blue: 0.54),
        Color(red: 0.68, green: 0.43, blue: 0.27), Color(red: 0.94, green: 0.64, blue: 0.44),
      ][id % 4]
      ellipse(CGRect(x: 1, y: 1, width: 62, height: 62), Palette.paper)
      ellipse(
        CGRect(x: 8, y: 42, width: 49, height: 44),
        id.isMultiple(of: 2) ? Palette.olive : Palette.red)
      ellipse(CGRect(x: 13, y: 5, width: 40, height: 45), hair)
      ellipse(CGRect(x: 17, y: 13, width: 31, height: 38), skin)
      ellipse(CGRect(x: 13, y: 27, width: 8, height: 11), skin)
      ellipse(CGRect(x: 44, y: 27, width: 8, height: 11), skin)
      if id == 0 {
        ellipse(CGRect(x: 14, y: 6, width: 35, height: 16), hair)
        ellipse(CGRect(x: 31, y: 3, width: 19, height: 14), hair)
      } else if id == 1 {
        ellipse(CGRect(x: 8, y: 2, width: 20, height: 20), hair)
        ellipse(CGRect(x: 15, y: 8, width: 31, height: 13), hair)
      } else if id == 2 {
        ellipse(CGRect(x: 13, y: 4, width: 37, height: 15), Palette.cream)
      } else {
        ellipse(CGRect(x: 15, y: 8, width: 18, height: 21), hair)
      }
      ellipse(CGRect(x: 23, y: 28, width: 3, height: happy ? 2 : 4), Palette.ink)
      ellipse(CGRect(x: 38, y: 28, width: 3, height: happy ? 2 : 4), Palette.ink)
      var nose = Path()
      nose.move(to: CGPoint(x: 32, y: 30))
      nose.addLines([CGPoint(x: 30, y: 36), CGPoint(x: 34, y: 36)])
      context.stroke(
        nose, with: .color(Palette.red.opacity(0.55)),
        style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
      var mouth = Path()
      mouth.move(to: CGPoint(x: 27, y: 40))
      mouth.addQuadCurve(to: CGPoint(x: 38, y: 40), control: CGPoint(x: 32, y: happy ? 48 : 42))
      context.stroke(
        mouth, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
      if id == 0 {
        var mustache = Path()
        mustache.move(to: CGPoint(x: 24, y: 38))
        mustache.addQuadCurve(to: CGPoint(x: 41, y: 38), control: CGPoint(x: 32, y: 31))
        context.stroke(
          mustache, with: .color(hair), style: StrokeStyle(lineWidth: 3, lineCap: .round))
      }
      var collar = Path()
      collar.move(to: CGPoint(x: 23, y: 52))
      collar.addLines([CGPoint(x: 32, y: 60), CGPoint(x: 41, y: 52)])
      context.stroke(collar, with: .color(Palette.cream), lineWidth: 2)
    }
    .clipShape(Circle())
    .accessibilityHidden(true)
  }
}

enum PizzaPainter {
  static func path(_ polygon: Polygon) -> Path {
    var path = Path()
    guard let first = polygon.vertices.first else { return path }
    path.move(to: CGPoint(x: first.x, y: first.y))
    for point in polygon.vertices.dropFirst() { path.addLine(to: CGPoint(x: point.x, y: point.y)) }
    path.closeSubpath()
    return path
  }

  static func topping(_ topping: Topping, in context: GraphicsContext, scale: Double = 1) {
    var context = context
    context.translateBy(x: topping.point.x, y: topping.point.y)
    context.rotate(by: .degrees(Double(topping.id * 71 % 360)))
    context.scaleBy(x: scale, y: scale)
    switch topping.kind {
    case .tomato:
      context.fill(
        Path(ellipseIn: CGRect(x: -0.105, y: -0.098, width: 0.21, height: 0.196)),
        with: .color(Color(red: 0.55, green: 0.12, blue: 0.07).opacity(0.25)))
      context.fill(
        Path(ellipseIn: CGRect(x: -0.098, y: -0.105, width: 0.19, height: 0.19)),
        with: .color(Palette.red))
      context.stroke(
        Path(ellipseIn: CGRect(x: -0.074, y: -0.081, width: 0.144, height: 0.144)),
        with: .color(Color(red: 0.94, green: 0.35, blue: 0.17)), lineWidth: 0.018)
      for index in 0..<5 {
        let a = Double(index) * .pi * 2 / 5
        context.fill(
          Path(
            ellipseIn: CGRect(
              x: cos(a) * 0.042 - 0.008, y: sin(a) * 0.042 - 0.008, width: 0.016, height: 0.022)),
          with: .color(Palette.gold))
      }
    case .basil:
      var leaf = Path()
      leaf.move(to: CGPoint(x: 0, y: -0.13))
      leaf.addCurve(
        to: CGPoint(x: 0, y: 0.13), control1: CGPoint(x: 0.14, y: -0.06),
        control2: CGPoint(x: 0.11, y: 0.08))
      leaf.addCurve(
        to: CGPoint(x: 0, y: -0.13), control1: CGPoint(x: -0.13, y: 0.06),
        control2: CGPoint(x: -0.09, y: -0.08))
      context.fill(leaf, with: .color(Palette.olive))
      var vein = Path()
      vein.move(to: CGPoint(x: 0, y: -0.1))
      vein.addLine(to: CGPoint(x: 0, y: 0.15))
      for offset in [-0.05, 0.01, 0.06] {
        vein.move(to: CGPoint(x: -0.04, y: offset - 0.03))
        vein.addLines([CGPoint(x: 0, y: offset), CGPoint(x: 0.05, y: offset - 0.03)])
      }
      context.stroke(
        vein, with: .color(Color(red: 0.62, green: 0.66, blue: 0.29)), lineWidth: 0.009)
    case .olive:
      context.fill(
        Path(ellipseIn: CGRect(x: -0.061, y: -0.078, width: 0.13, height: 0.165)),
        with: .color(Palette.ink.opacity(0.2)))
      context.fill(
        Path(ellipseIn: CGRect(x: -0.068, y: -0.09, width: 0.13, height: 0.16)),
        with: .color(Palette.ink))
      context.fill(
        Path(ellipseIn: CGRect(x: -0.027, y: -0.046, width: 0.047, height: 0.07)),
        with: .color(Color(red: 0.76, green: 0.66, blue: 0.26)))
      context.stroke(
        Path(ellipseIn: CGRect(x: -0.052, y: -0.07, width: 0.09, height: 0.12)),
        with: .color(Palette.olive), lineWidth: 0.012)
    }
  }

  static func pizza(in context: GraphicsContext, toppings: [Topping]) {
    let crust = Color(red: 0.75, green: 0.39, blue: 0.14)
    let cheese = Color(red: 0.98, green: 0.77, blue: 0.34)
    let edge = Polygon(
      vertices: (0..<120).map { index in
        let angle = Double(index) * .pi * 2 / 120
        let radius = 0.98 + sin(angle * 9) * 0.011 + cos(angle * 17) * 0.007
        return Point(x: cos(angle) * radius, y: sin(angle) * radius)
      })
    context.fill(path(edge), with: .color(crust))
    let innerEdge = Polygon(vertices: edge.vertices.map { $0 * 0.983 })
    context.fill(path(innerEdge), with: .color(Color(red: 0.91, green: 0.63, blue: 0.30)))
    for index in 0..<76 {
      let angle = Double(index) * 2 * .pi / 76
      let radius = 0.937 + sin(Double(index) * 9) * 0.009
      let width = 0.08 + Double(index % 3) * 0.016
      let rect = CGRect(
        x: cos(angle) * radius - width / 2, y: sin(angle) * radius - width / 2, width: width,
        height: width)
      context.fill(
        Path(ellipseIn: rect),
        with: .color(index % 5 == 0 ? crust.opacity(0.8) : Palette.gold.opacity(0.6)))
    }
    context.fill(
      Path(ellipseIn: CGRect(x: -0.89, y: -0.89, width: 1.78, height: 1.78)),
      with: .color(Palette.red))
    var cheesePath = Path()
    for index in 0...90 {
      let angle = Double(index) * 2 * .pi / 90
      let radius = 0.855 + sin(Double(index) * 2.7) * 0.025
      let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
      if index == 0 { cheesePath.move(to: point) } else { cheesePath.addLine(to: point) }
    }
    cheesePath.closeSubpath()
    context.fill(cheesePath, with: .color(cheese))
    for index in 0..<155 {
      let angle = Double(index) * 2.39996
      let radius = sqrt(Double(index) / 155) * 0.82
      let width = 0.018 + Double(index % 7) * 0.009
      let rect = CGRect(
        x: cos(angle) * radius - width / 2, y: sin(angle) * radius - width / 2, width: width,
        height: width * 0.75)
      context.fill(
        Path(ellipseIn: rect),
        with: .color(index % 4 == 0 ? Palette.red.opacity(0.27) : Palette.paper.opacity(0.5)))
    }
    for index in 0..<80 {
      let angle = Double(index) * 3.88
      let radius = sqrt(Double(index) / 80) * 0.85
      let rect = CGRect(x: cos(angle) * radius, y: sin(angle) * radius, width: 0.009, height: 0.019)
      context.fill(Path(ellipseIn: rect), with: .color(Palette.olive.opacity(0.6)))
    }
    for topping in toppings { Self.topping(topping, in: context) }
  }
}

struct PizzaArt: View {
  var toppings: [Topping]
  var cuts: [Cut] = []
  var preview: Cut?
  var hint: Cut?
  var labels = false
  var exploded = false
  var decorative = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Canvas { context, size in
      let radius = min(size.width, size.height) * (exploded ? 0.355 : 0.40)
      context.translateBy(x: size.width / 2, y: size.height / 2)
      context.scaleBy(x: radius, y: radius)
      context.fill(
        Path(ellipseIn: CGRect(x: -1.17, y: -1.13, width: 2.34, height: 2.34)),
        with: .color(Palette.ink.opacity(0.08)))
      context.fill(
        Path(ellipseIn: CGRect(x: -1.16, y: -1.16, width: 2.32, height: 2.32)),
        with: .color(Palette.paper))
      for inset in [1.12, 1.09, 1.025] {
        context.stroke(
          Path(ellipseIn: CGRect(x: -inset, y: -inset, width: inset * 2, height: inset * 2)),
          with: .color(Palette.olive.opacity(inset == 1.025 ? 0.16 : 0.7)), lineWidth: 0.008)
      }
      let allCuts = cuts + (preview.map { [$0] } ?? [])
      let pieces = Rules.polygons(cuts: allCuts)
      for (index, piece) in pieces.enumerated() {
        var sliceContext = context
        let displacement = cuts.isEmpty && preview == nil ? 0.0 : (exploded ? 0.26 : 0.018)
        sliceContext.translateBy(x: piece.center.x * displacement, y: piece.center.y * displacement)
        sliceContext.clip(to: PizzaPainter.path(piece))
        PizzaPainter.pizza(in: sliceContext, toppings: toppings)
        if labels, pieces.count > 1,
          let center = FoodLayout.labelPosition(
            in: piece, toppings: toppings, halfWidth: 20 / radius, halfHeight: 11 / radius)
        {
          let text = Text("\(Int((piece.area / Polygon.pizza.area * 100).rounded()))%")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Palette.paper)
          var labelContext = context
          labelContext.translateBy(
            x: center.x + piece.center.x * displacement, y: center.y + piece.center.y * displacement
          )
          labelContext.scaleBy(x: 1 / radius, y: 1 / radius)
          labelContext.fill(
            Path(roundedRect: CGRect(x: -20, y: -11, width: 40, height: 22), cornerRadius: 11),
            with: .color(Palette.portionColors[index % 4]))
          labelContext.draw(text, at: .zero)
        }
      }
      if let cut = preview ?? hint {
        let direction = cut.end - cut.start
        let midpoint = (cut.end + cut.start) * 0.5
        let unit = direction * (1 / max(0.001, direction.length))
        var line = Path()
        line.move(to: CGPoint(x: (midpoint - unit * 1.4).x, y: (midpoint - unit * 1.4).y))
        line.addLine(to: CGPoint(x: (midpoint + unit * 1.4).x, y: (midpoint + unit * 1.4).y))
        context.stroke(
          line, with: .color(Palette.paper), style: StrokeStyle(lineWidth: 0.034, lineCap: .round))
        context.stroke(
          line, with: .color(Palette.red),
          style: StrokeStyle(lineWidth: 0.014, lineCap: .round, dash: [0.055, 0.045]))
      }
      if decorative {
        for index in 0..<28 {
          let angle = Double(index) * 2.4
          let radius = 1.18 + Double(index % 4) * 0.035
          context.fill(
            Path(
              ellipseIn: CGRect(
                x: cos(angle) * radius, y: sin(angle) * radius, width: 0.012, height: 0.012)),
            with: .color(Palette.paper.opacity(0.9)))
        }
      }
    }
    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75), value: exploded)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "Pizza with \(toppings.filter { $0.kind == .tomato }.count) tomatoes, \(toppings.filter { $0.kind == .basil }.count) basil leaves, and \(toppings.filter { $0.kind == .olive }.count) olives. \(Rules.polygons(cuts: cuts).count) portions."
    )
  }
}

struct ServedPlate: View {
  let portion: Portion
  let index: Int
  @State private var arrived = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      Circle().fill(Palette.paper)
      Circle().strokeBorder(Palette.olive.opacity(0.55), lineWidth: 1).padding(2)
      Canvas { context, size in
        let vertices = portion.polygon.vertices
        let width = (vertices.map(\.x).max() ?? 1) - (vertices.map(\.x).min() ?? -1)
        let height = (vertices.map(\.y).max() ?? 1) - (vertices.map(\.y).min() ?? -1)
        let scale = size.width * 0.67 / max(width, height)
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -portion.polygon.center.x, y: -portion.polygon.center.y)
        context.clip(to: PizzaPainter.path(portion.polygon))
        PizzaPainter.pizza(in: context, toppings: portion.toppings)
      }
      .offset(x: arrived ? 0 : -70, y: arrived ? 0 : -35)
      .rotationEffect(.degrees(arrived ? 0 : -25))
      .opacity(arrived ? 1 : 0)
    }
    .accessibilityHidden(true)
    .onAppear {
      withAnimation(
        reduceMotion
          ? nil : .spring(response: 0.6, dampingFraction: 0.72).delay(Double(index) * 0.12)
      ) {
        arrived = true
      }
    }
  }
}

struct ToppingIcon: View {
  let kind: ToppingKind
  var body: some View {
    Canvas { context, size in
      context.translateBy(x: size.width / 2, y: size.height / 2)
      context.scaleBy(x: size.width * 3.4, y: size.height * 3.4)
      PizzaPainter.topping(Topping(id: 0, kind: kind, point: Point(x: 0, y: 0)), in: context)
    }.frame(width: 19, height: 19).accessibilityHidden(true)
  }
}

struct FlourBurst: View {
  @State private var expand = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    GeometryReader { geometry in
      ForEach(0..<24, id: \.self) { index in
        let angle = Double(index) * 2.4
        let distance = expand ? geometry.size.width * (0.22 + Double(index % 4) * 0.035) : 0
        Circle()
          .fill(index.isMultiple(of: 3) ? Palette.gold : Palette.paper)
          .frame(width: CGFloat(2 + index % 4), height: CGFloat(2 + index % 4))
          .position(
            x: geometry.size.width / 2 + cos(angle) * distance,
            y: geometry.size.height / 2 + sin(angle) * distance
          )
          .opacity(expand ? 0 : 1)
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.7)) { expand = true } }
  }
}
