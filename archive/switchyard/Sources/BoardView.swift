import SwiftUI

enum Ink {
  static let navy = Color(red: 0.08, green: 0.19, blue: 0.22)
  static let paper = Color(red: 0.97, green: 0.96, blue: 0.90)
  static let mint = Color(red: 0.73, green: 0.86, blue: 0.76)
  static let butter = Color(red: 0.98, green: 0.81, blue: 0.35)
  static let muted = Color(red: 0.31, green: 0.43, blue: 0.41)
}

extension Freight {
  var color: Color {
    switch self {
    case .coral: Color(red: 0.83, green: 0.26, blue: 0.22)
    case .blue: Color(red: 0.12, green: 0.43, blue: 0.71)
    case .gold: Color(red: 0.70, green: 0.45, blue: 0.03)
    }
  }
}

struct BoardView: View {
  let railway: Railway
  var decorative = false
  var onTouch: () -> Void = {}

  var body: some View {
    GeometryReader { geometry in
      let scale = geometry.size.width / 360
      ZStack {
        Canvas { context, size in
          context.scaleBy(x: scale, y: scale)
          terrain(&context)
          for (from, to) in Node.tracks { track(&context, from: from.point, to: to.point) }
          route(&context)
          if !decorative {
            junction(&context, node: .a, control: RailPoint(x: 124, y: 238))
            junction(&context, node: .b, control: RailPoint(x: 278, y: 171))
          }
          station(&context, point: Node.rose.point, freight: .coral)
          station(&context, point: Node.lake.point, freight: .blue)
          station(&context, point: Node.sun.point, freight: .gold)
          if decorative {
            drawTrain(
              &context,
              train: Train(
                id: 10, freight: .coral, entrance: .west, from: .a, to: .rose, distance: 68))
            drawTrain(
              &context,
              train: Train(
                id: 11, freight: .gold, entrance: .west, from: .west, to: .westSignal, distance: 72)
            )
            drawTrain(
              &context,
              train: Train(
                id: 12, freight: .blue, entrance: .east, from: .east, to: .eastSignal, distance: 74)
            )
          } else {
            for train in railway.trains { drawTrain(&context, train: train) }
          }
        }
        .accessibilityHidden(true)
        if !decorative {
          boardControl(
            "A", symbol: railway.roseRoute ? "arrow.up.left" : "arrow.up.right",
            at: CGPoint(x: 124, y: 238), scale: scale,
            label: "Switch A", value: railway.roseRoute ? "Rosebay" : "Onward to switch B"
          ) {
            railway.roseRoute.toggle()
            onTouch()
          }
          boardControl(
            "B", symbol: railway.sunRoute ? "arrow.up.right" : "arrow.up.left",
            at: CGPoint(x: 278, y: 171), scale: scale,
            label: "Switch B", value: railway.sunRoute ? "Sunfield" : "Lakeview"
          ) {
            railway.sunRoute.toggle()
            onTouch()
          }
          signal(.west, at: CGPoint(x: 77, y: 297), scale: scale)
          signal(.east, at: CGPoint(x: 284, y: 297), scale: scale)
        }
        Text("WEST").font(.system(size: 9, weight: .heavy, design: .monospaced))
          .tracking(2).position(x: 37 * scale, y: 422 * scale)
        Text("EAST").font(.system(size: 9, weight: .heavy, design: .monospaced))
          .tracking(2).position(x: 325 * scale, y: 422 * scale)
      }
      .foregroundStyle(Ink.navy)
    }
    .aspectRatio(360 / 444, contentMode: .fit)
    .background(Ink.mint)
    .clipShape(RoundedRectangle(cornerRadius: 28))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Railway board")
  }

  private func boardControl(
    _ title: String, symbol: String, at point: CGPoint, scale: CGFloat,
    label: String, value: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 3) {
        HStack(spacing: 5) {
          Text(title).font(.system(size: 14, weight: .black, design: .rounded))
          Image(systemName: symbol).font(.system(size: 12, weight: .heavy))
        }
        Text(value == "Onward to switch B" ? "To B" : value)
          .font(.system(size: 10, weight: .semibold))
      }
      .foregroundStyle(Ink.paper).frame(width: 72, height: 50)
      .background(Ink.navy, in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(Ink.paper, lineWidth: 2))
      .shadow(color: Ink.navy.opacity(0.15), radius: 0, y: 3)
    }
    .buttonStyle(.plain)
    .position(x: point.x * scale, y: point.y * scale)
    .accessibilityLabel(label).accessibilityValue(value)
    .accessibilityHint("Double tap to change the route")
  }

  private func signal(_ entrance: Entrance, at point: CGPoint, scale: CGFloat) -> some View {
    let isOpen = entrance == .west ? railway.westOpen : railway.eastOpen
    return Button {
      if entrance == .west { railway.westOpen.toggle() } else { railway.eastOpen.toggle() }
      onTouch()
    } label: {
      VStack(spacing: 3) {
        Image(systemName: isOpen ? "arrow.up" : "pause.fill")
          .font(.system(size: 15, weight: .heavy)).frame(width: 30, height: 30)
          .background(
            isOpen ? Color(red: 0.14, green: 0.47, blue: 0.32) : Freight.coral.color, in: Circle()
          )
          .overlay(Circle().stroke(Ink.paper, lineWidth: 2))
        Text(isOpen ? "GO" : "HOLD").font(.system(size: 10, weight: .black, design: .monospaced))
          .foregroundStyle(Ink.navy)
      }.foregroundStyle(.white).frame(width: 50, height: 50)
    }
    .buttonStyle(.plain)
    .position(x: point.x * scale, y: point.y * scale)
    .accessibilityLabel("\(entrance.rawValue.capitalized) signal")
    .accessibilityValue(isOpen ? "Go" : "Hold")
    .accessibilityHint("Double tap to \(isOpen ? "hold" : "release") trains")
  }

  private func terrain(_ context: inout GraphicsContext) {
    func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
      context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
    }
    ellipse(-80, 105, 220, 210, Color.white.opacity(0.11))
    ellipse(240, 170, 180, 230, Color.white.opacity(0.10))
    ellipse(14, 164, 76, 99, Color(red: 0.49, green: 0.74, blue: 0.72))
    ellipse(21, 170, 60, 82, Color(red: 0.59, green: 0.81, blue: 0.80))
    for offset in 0..<3 {
      let y = CGFloat(191 + offset * 17)
      var wave = Path()
      wave.move(to: CGPoint(x: 32, y: y))
      wave.addQuadCurve(to: CGPoint(x: 64, y: y), control: CGPoint(x: 48, y: y + 5))
      context.stroke(wave, with: .color(.white.opacity(0.35)), lineWidth: 2)
    }
    for (x, y, r) in [
      (26.0, 132.0, 9.0), (118, 62, 12), (316, 227, 13), (303, 247, 10),
      (47, 349, 13), (205, 379, 12), (219, 396, 9), (136, 185, 10), (326, 145, 9),
    ] {
      ellipse(x - r + 2, y - r + 4, r * 2, r * 2, Ink.navy.opacity(0.09))
      ellipse(x - r, y - r, r * 2, r * 2, Color(red: 0.39, green: 0.63, blue: 0.43))
      ellipse(x - r + 3, y - r + 2, r * 1.25, r * 1.25, Color(red: 0.53, green: 0.73, blue: 0.49))
    }
    for index in 0..<32 {
      let x = CGFloat((index * 73 + 19) % 344)
      let y = CGFloat((index * 61 + 29) % 408)
      ellipse(x, y, 2, 2, Ink.navy.opacity(0.12))
    }
  }

  private func path(_ start: RailPoint, _ end: RailPoint) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: start.x, y: start.y))
    path.addLine(to: CGPoint(x: end.x, y: end.y))
    return path
  }

  private func track(_ context: inout GraphicsContext, from: RailPoint, to: RailPoint) {
    let line = path(from, to)
    context.stroke(
      line, with: .color(Ink.paper.opacity(0.48)),
      style: StrokeStyle(lineWidth: 18, lineCap: .round))
    let length = from.distance(to: to)
    let dx = (to.x - from.x) / length
    let dy = (to.y - from.y) / length
    for index in 0...Int(length / 10) {
      let x = from.x + dx * Double(index) * 10
      let y = from.y + dy * Double(index) * 10
      context.stroke(
        path(
          RailPoint(x: x - dy * 7, y: y + dx * 7),
          RailPoint(x: x + dy * 7, y: y - dx * 7)),
        with: .color(Ink.navy.opacity(0.65)), lineWidth: 3)
    }
    context.stroke(line, with: .color(Ink.navy), style: StrokeStyle(lineWidth: 8, lineCap: .round))
    context.stroke(line, with: .color(Ink.mint), style: StrokeStyle(lineWidth: 3, lineCap: .round))
  }

  private func junction(_ context: inout GraphicsContext, node: Node, control: RailPoint) {
    context.stroke(
      path(node.point, control), with: .color(Ink.navy.opacity(0.45)),
      style: StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
    let marker = Path(
      ellipseIn: CGRect(x: node.point.x - 5, y: node.point.y - 5, width: 10, height: 10))
    context.fill(marker, with: .color(Ink.paper))
    context.stroke(marker, with: .color(Ink.navy), lineWidth: 2)
  }

  private func route(_ context: inout GraphicsContext) {
    let nodes: [Node] =
      railway.roseRoute ? [.merge, .a, .rose] : [.merge, .a, .b, railway.sunRoute ? .sun : .lake]
    var line = Path()
    line.move(to: CGPoint(x: nodes[0].point.x, y: nodes[0].point.y))
    for node in nodes.dropFirst() { line.addLine(to: CGPoint(x: node.point.x, y: node.point.y)) }
    context.stroke(
      line, with: .color(railway.route.color.opacity(0.2)),
      style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))
    context.stroke(
      line, with: .color(railway.route.color),
      style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [3, 6]))
  }

  private func station(_ context: inout GraphicsContext, point: RailPoint, freight: Freight) {
    let x = point.x
    let y = point.y
    let signY = freight == .blue ? y - 49 : y - 54
    let platform = CGRect(x: x - 29, y: y - 11, width: 58, height: 20)
    context.fill(
      Path(roundedRect: platform.offsetBy(dx: 0, dy: 4), cornerRadius: 5),
      with: .color(Ink.navy.opacity(0.15)))
    context.fill(Path(roundedRect: platform, cornerRadius: 5), with: .color(Ink.paper))
    context.fill(
      Path(roundedRect: CGRect(x: x - 24, y: y - 37, width: 48, height: 29), cornerRadius: 3),
      with: .color(Ink.butter))
    context.fill(
      Path(roundedRect: CGRect(x: x - 28, y: y - 42, width: 56, height: 12), cornerRadius: 3),
      with: .color(Ink.navy))
    for dx in [-16.0, 9.0] {
      context.fill(
        Path(roundedRect: CGRect(x: x + dx, y: y - 24, width: 8, height: 10), cornerRadius: 2),
        with: .color(Ink.navy))
    }
    context.fill(
      Path(ellipseIn: CGRect(x: x - 9, y: y - 23, width: 18, height: 18)),
      with: .color(freight.color))
    context.draw(
      Text(freight.code).font(.system(size: 11, weight: .black, design: .rounded)).foregroundStyle(
        .white),
      at: CGPoint(x: x, y: y - 14))
    context.fill(
      Path(roundedRect: CGRect(x: x - 43, y: signY - 9, width: 86, height: 18), cornerRadius: 5),
      with: .color(Ink.paper))
    context.draw(
      Text(freight.station.uppercased()).font(
        .system(size: 10.5, weight: .heavy, design: .monospaced)
      )
      .foregroundStyle(Ink.navy),
      at: CGPoint(x: x, y: signY))
  }

  private func drawTrain(_ context: inout GraphicsContext, train: Train) {
    var local = context
    local.translateBy(x: train.point.x, y: train.point.y)
    local.rotate(by: .radians(train.angle))
    let body = CGRect(x: -16, y: -8, width: 32, height: 16)
    local.fill(
      Path(roundedRect: body.offsetBy(dx: 1, dy: 3), cornerRadius: 5),
      with: .color(Ink.navy.opacity(0.25)))
    local.fill(
      Path(roundedRect: CGRect(x: -13, y: -10, width: 22, height: 20), cornerRadius: 3),
      with: .color(Ink.navy))
    local.fill(Path(roundedRect: body, cornerRadius: 5), with: .color(train.freight.color))
    local.stroke(Path(roundedRect: body, cornerRadius: 5), with: .color(Ink.paper), lineWidth: 1.5)
    local.fill(
      Path(roundedRect: CGRect(x: 5, y: -5, width: 6, height: 10), cornerRadius: 2),
      with: .color(Ink.navy))
    local.fill(Path(CGRect(x: 13, y: -4, width: 3, height: 3)), with: .color(Ink.butter))
    context.draw(
      Text(train.freight.code).font(.system(size: 12, weight: .black, design: .rounded))
        .foregroundStyle(.white),
      at: CGPoint(x: train.point.x - 6 * cos(train.angle), y: train.point.y - 6 * sin(train.angle)))
  }
}
