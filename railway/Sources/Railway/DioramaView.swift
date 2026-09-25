import RailwayCore
import SwiftUI

struct DioramaView: View {
  let simulation: Simulation
  var body: some View {
    GeometryReader { proxy in
      let scale = min(proxy.size.width / 980, proxy.size.height / 740)
      let offset = CGPoint(
        x: (proxy.size.width - 980 * scale) / 2, y: (proxy.size.height - 740 * scale) / 2)
      Canvas { context, size in
        context.translateBy(x: offset.x, y: offset.y)
        context.scaleBy(x: scale, y: scale)
        drawTerrain(&context)
        drawTracks(&context)
        drawScenery(&context)
        for station in Station.allCases { drawStation(station, context: &context) }
        drawLabels(&context)
        for train in simulation.trains { drawTrain(train, context: &context) }
      }
      .accessibilityLabel(
        "Stillwater railway diorama. Three stations connected by a main line and forest loop. Block 01 \(simulation.corridorLabel)."
      )
    }
    .background(Color(red: 0.87, green: 0.90, blue: 0.82))
    .clipped()
  }
  private func color(_ r: Double, _ g: Double, _ b: Double) -> Color {
    Color(red: r, green: g, blue: b)
  }
  private func path(_ points: [MapPoint]) -> Path {
    Path { p in
      guard let first = points.first else { return }
      p.move(to: CGPoint(x: first.x, y: first.y))
      for point in points.dropFirst() { p.addLine(to: CGPoint(x: point.x, y: point.y)) }
    }
  }
  private func ellipse(
    _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ fill: Color,
    _ context: inout GraphicsContext
  ) {
    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), with: .color(fill))
  }
  private func rect(
    _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ radius: Double, _ fill: Color,
    _ context: inout GraphicsContext
  ) {
    context.fill(
      Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius),
      with: .color(fill))
  }
  private func label(
    _ text: String, _ x: Double, _ y: Double, size: Double = 11, fill: Color = Palette.ink,
    serif: Bool = false, context: inout GraphicsContext
  ) {
    context.draw(
      Text(text).font(.system(size: size, weight: .medium, design: serif ? .serif : .monospaced))
        .foregroundStyle(fill), at: CGPoint(x: x, y: y))
  }
  private func drawTerrain(_ context: inout GraphicsContext) {
    ellipse(210, 70, 450, 450, color(0.83, 0.87, 0.77), &context)
    ellipse(435, 5, 520, 325, color(0.84, 0.88, 0.78), &context)
    ellipse(635, 450, 390, 360, color(0.83, 0.87, 0.77), &context)
    for ring in 0..<6 {
      let inset = Double(ring) * 14
      let contour = Path(
        ellipseIn: CGRect(
          x: 345 + inset, y: 80 + inset * 0.6, width: 240 - inset * 2, height: 150 - inset))
      context.stroke(contour, with: .color(color(0.65, 0.72, 0.58).opacity(0.22)), lineWidth: 1)
    }
    var water = Path()
    water.move(to: CGPoint(x: -600, y: 485))
    water.addLine(to: CGPoint(x: -60, y: 485))
    water.addCurve(
      to: CGPoint(x: 260, y: 570), control1: CGPoint(x: 70, y: 420),
      control2: CGPoint(x: 130, y: 550))
    water.addCurve(
      to: CGPoint(x: 510, y: 790), control1: CGPoint(x: 380, y: 600),
      control2: CGPoint(x: 270, y: 735))
    water.addLine(to: CGPoint(x: -600, y: 1200))
    water.closeSubpath()
    context.stroke(water, with: .color(color(0.74, 0.80, 0.69)), lineWidth: 25)
    context.fill(water, with: .color(color(0.53, 0.70, 0.70)))
    for n in 0..<38 {
      let x = Double((n * 73) % 290)
      let y = 560 + Double((n * 39) % 170)
      context.stroke(
        path([MapPoint(x, y), MapPoint(x + 12 + Double(n % 12), y)]),
        with: .color(.white.opacity(0.22)), lineWidth: 1.2)
    }
    for n in 0..<380 {
      let x = Double((n * 181 + 35) % 960)
      let y = Double((n * 97 + 21) % 730)
      if y > 480 && x < (y - 440) * 1.3 { continue }
      ellipse(x, y, 1.7, 1.7, Palette.ink.opacity(0.08), &context)
    }
    let road = path([
      MapPoint(35, 290), MapPoint(195, 300), MapPoint(240, 215), MapPoint(380, 178),
      MapPoint(625, 150), MapPoint(820, 135),
    ])
    context.stroke(
      road, with: .color(color(0.79, 0.78, 0.66)),
      style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
    context.stroke(
      road, with: .color(color(0.89, 0.87, 0.76)),
      style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
    label(
      "S T I L L W A T E R", 172, 620, size: 13, fill: color(0.27, 0.46, 0.47), context: &context)
    label(
      "N A T I O N A L   F O R E S T", 449, 116, size: 11, fill: Palette.muted, context: &context)
    label("N", 921, 75, size: 12, context: &context)
    var compass = Path()
    compass.move(to: CGPoint(x: 920, y: 91))
    compass.addLine(to: CGPoint(x: 914, y: 111))
    compass.addLine(to: CGPoint(x: 920, y: 106))
    compass.addLine(to: CGPoint(x: 926, y: 111))
    compass.closeSubpath()
    context.fill(compass, with: .color(Palette.ink.opacity(0.6)))
    label("1 : 240", 914, 139, size: 9, fill: Palette.muted, context: &context)
  }
  private func drawTracks(_ context: inout GraphicsContext) {
    for track in Network.tracks {
      let line = path(track.points)
      let reserved = simulation.corridorOwner.flatMap { id in
        simulation.trains.first { $0.id == id }
      }
      let active = reserved?.route.contains { $0.trackID == track.id } == true
      context.stroke(
        line, with: .color(color(0.64, 0.66, 0.55).opacity(0.32)),
        style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round))
      context.stroke(
        line, with: .color(color(0.76, 0.75, 0.64)),
        style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))
      if active {
        context.stroke(
          line, with: .color(Palette.brass.opacity(0.30)),
          style: StrokeStyle(lineWidth: 31, lineCap: .round, lineJoin: .round))
      }
      for distance in stride(from: 0.0, through: track.length, by: 9) {
        let t = distance / track.length
        let p = track.point(at: t)
        let q = track.point(at: min(1, t + 0.008))
        let angle = atan2(q.y - p.y, q.x - p.x) + .pi / 2
        let dx = cos(angle) * 8
        let dy = sin(angle) * 8
        context.stroke(
          path([MapPoint(p.x - dx, p.y - dy), MapPoint(p.x + dx, p.y + dy)]),
          with: .color(color(0.42, 0.39, 0.31)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
      }
      context.stroke(
        line, with: .color(color(0.24, 0.30, 0.25)),
        style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
      context.stroke(
        line, with: .color(color(0.80, 0.81, 0.70)),
        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
      context.stroke(
        line, with: .color(color(0.46, 0.46, 0.36)),
        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
    for (x, code, value) in [
      (370.0, "W1", simulation.scenic ? "LOOP" : "MAIN"), (590.0, "W2", simulation.eastSwitch.code),
    ] {
      ellipse(x - 11, 384, 22, 22, Palette.brass, &context)
      ellipse(x - 6, 389, 12, 12, Palette.paper, &context)
      rect(x - 35, 432, 70, 38, 6, Palette.ink, &context)
      label(code, x, 444, size: 10, fill: color(0.88, 0.77, 0.52), context: &context)
      label(value, x, 458, size: 9, fill: Palette.paper, context: &context)
    }
    rect(438, 354, 88, 24, 12, Palette.paper.opacity(0.95), &context)
    label("BLOCK 01", 482, 366, size: 10, fill: Palette.muted, context: &context)
    label("FOREST LOOP", 480, 307, size: 9, fill: Palette.muted, context: &context)
  }
  private func drawScenery(_ context: inout GraphicsContext) {
    var trees: [(point: MapPoint, size: Double, variant: Int)] = []
    for n in 0..<280 {
      let x = 30 + noise(n * 3) * 920
      let y = 48 + noise(n * 3 + 1) * 665
      if y > 465 && x < (y - 440) * 1.5 { continue }
      if Station.allCases.contains(where: {
        abs($0.point.x - x) < 100 && abs($0.point.y - 40 - y) < 100
      }) {
        continue
      }
      if (330...640).contains(x) && (350...490).contains(y) { continue }
      if (350...585).contains(x) && (70...185).contains(y) { continue }
      if x > 875 && y < 175 { continue }
      if (390...565).contains(x) && (280...327).contains(y) { continue }
      if (230...365).contains(x) && (530...625).contains(y) { continue }
      if trees.contains(where: { $0.point.distance(to: MapPoint(x, y)) < 23 }) { continue }
      let nearTrack = Network.tracks.contains { track in
        stride(from: 0.0, through: 1.0, by: 0.04).contains {
          track.point(at: $0).distance(to: MapPoint(x, y)) < 37
        }
      }
      if nearTrack { continue }
      trees.append((MapPoint(x, y), 17 + noise(n * 3 + 2) * 14, n % 3))
    }
    for tree in trees.sorted(by: { $0.point.y < $1.point.y }) {
      self.tree(
        tree.point.x, tree.point.y, size: tree.size, variant: tree.variant, context: &context)
    }
    for n in 0..<16 {
      let x = 380 + noise(n * 2 + 900) * 210
      let y = 531 + noise(n * 2 + 901) * 137
      ellipse(x + 4, y + 6, 14, 7, Palette.ink.opacity(0.09), &context)
      ellipse(x, y, 13, 9, color(0.69, 0.72, 0.63), &context)
      ellipse(x + 1, y, 8, 5, color(0.80, 0.81, 0.72), &context)
    }
    rect(276, 562, 71, 13, 2, color(0.49, 0.43, 0.31), &context)
    for x in stride(from: 280.0, through: 343, by: 7) {
      context.stroke(
        path([MapPoint(x, 562), MapPoint(x, 575)]), with: .color(color(0.70, 0.61, 0.43)),
        lineWidth: 1)
    }
    label("RANGER'S LANDING", 300, 596, size: 8, fill: Palette.muted, context: &context)
  }
  private func noise(_ seed: Int) -> Double {
    var value = UInt64(seed) &+ 0x9E37_79B9_7F4A_7C15
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    return Double((value ^ (value >> 31)) >> 11) / 9_007_199_254_740_992
  }
  private func tree(
    _ x: Double, _ y: Double, size: Double, variant: Int, context: inout GraphicsContext
  ) {
    ellipse(x - size * 0.3 + 8, y + 3, size * 1.5, size * 0.5, Palette.ink.opacity(0.10), &context)
    rect(x - 2, y - 8, 4, 15, 1, color(0.41, 0.38, 0.26), &context)
    let shades = [color(0.26, 0.40, 0.29), color(0.34, 0.47, 0.33), color(0.40, 0.51, 0.34)]
    for layer in 0..<3 {
      let width = size * (1 - Double(layer) * 0.18)
      let bottom = y - Double(layer) * size * 0.29
      var triangle = Path()
      triangle.move(to: CGPoint(x: x, y: bottom - size * 0.92))
      triangle.addLine(to: CGPoint(x: x - width * 0.57, y: bottom))
      triangle.addQuadCurve(
        to: CGPoint(x: x + width * 0.57, y: bottom), control: CGPoint(x: x, y: bottom + 7))
      triangle.closeSubpath()
      context.fill(triangle, with: .color(shades[(variant + layer) % 3]))
    }
  }
  private func drawStation(_ station: Station, context: inout GraphicsContext) {
    let p = station.point
    let x = p.x - 38
    let y = p.y - 62
    rect(x - 28, p.y - 23, 140, 13, 3, color(0.69, 0.66, 0.52), &context)
    rect(x - 25, p.y - 25, 134, 9, 2, color(0.91, 0.87, 0.72), &context)
    for n in 0..<13 {
      rect(x - 20 + Double(n) * 10, p.y - 17, 5, 2, 0, color(0.65, 0.62, 0.49), &context)
    }
    rect(x + 9, y + 12, 90, 44, 4, Palette.ink.opacity(0.12), &context)
    rect(x, y, 82, 39, 2, color(0.95, 0.89, 0.72), &context)
    rect(x, y + 28, 82, 11, 0, color(0.77, 0.73, 0.58), &context)
    for window in [8.0, 25.0, 58.0] {
      rect(x + window, y + 10, 10, 12, 1, color(0.29, 0.40, 0.36), &context)
      rect(x + window + 2, y + 11, 6, 5, 0, color(0.69, 0.79, 0.68), &context)
    }
    rect(x + 42, y + 10, 11, 28, 1, color(0.36, 0.43, 0.32), &context)
    var roof = Path()
    roof.move(to: CGPoint(x: x - 8, y: y + 2))
    roof.addLine(to: CGPoint(x: x + 12, y: y - 17))
    roof.addLine(to: CGPoint(x: x + 71, y: y - 17))
    roof.addLine(to: CGPoint(x: x + 91, y: y + 2))
    roof.closeSubpath()
    context.fill(roof, with: .color(color(0.41, 0.36, 0.28)))
    for n in 0..<9 {
      context.stroke(
        path([MapPoint(x + Double(n) * 9, y), MapPoint(x + 14 + Double(n) * 6, y - 14)]),
        with: .color(.white.opacity(0.12)), lineWidth: 1)
    }
    rect(x + 58, y - 23, 8, 14, 0, color(0.63, 0.53, 0.38), &context)
    rect(x + 86, y + 23, 17, 4, 1, color(0.43, 0.36, 0.24), &context)
    label(station.title, p.x + 3, p.y - 107, size: 20, serif: true, context: &context)
    label(
      station == .alder
        ? "01  ·  WOODLAND TERMINUS"
        : station == .summit ? "02  ·  HIGHLAND PLATFORM" : "03  ·  LAKESIDE PLATFORM", p.x + 3,
      p.y - 88, size: 8, fill: Palette.muted, context: &context)
  }
  private func drawLabels(_ context: inout GraphicsContext) {
    for (station, x, y) in [
      (Station.alder, 305.0, 368.0), (.summit, 657.0, 298.0), (.harbor, 654.0, 496.0),
    ] {
      let clear = simulation.signals[station.rawValue] == true
      rect(x - 2, y, 4, 29, 1, color(0.28, 0.32, 0.25), &context)
      rect(x - 8, y - 15, 16, 26, 6, Palette.ink, &context)
      ellipse(x - 4, y - 11, 8, 8, clear ? color(0.65, 0.80, 0.49) : Palette.red, &context)
      ellipse(x - 3, y + 1, 6, 6, Palette.paper.opacity(0.18), &context)
    }
  }
  private func drawTrain(_ train: Train, context: inout GraphicsContext) {
    let p = train.point
    var local = context
    local.translateBy(x: p.x, y: p.y)
    local.rotate(by: .radians(train.angle))
    let body = train.id == "R01" ? Palette.red : Palette.blue
    ellipse(-32, -7, 68, 21, Palette.ink.opacity(0.20), &local)
    for wheel in [-28.0, -14.0, 4.0, 18.0] {
      rect(wheel, -10, 5, 4, 1, Palette.ink, &local)
      rect(wheel, 6, 5, 4, 1, Palette.ink, &local)
    }
    rect(-32, -8, 24, 16, 3, body, &local)
    rect(-29, -5, 18, 10, 2, color(0.90, 0.85, 0.68), &local)
    for x in [-27.0, -20.0] { rect(x, -4, 5, 8, 1, color(0.33, 0.44, 0.40), &local) }
    rect(-7, -2, 5, 4, 0, Palette.ink, &local)
    rect(-3, -9, 28, 18, 4, body, &local)
    rect(-1, -7, 9, 14, 2, color(0.94, 0.87, 0.67), &local)
    rect(1, -5, 5, 10, 1, color(0.28, 0.38, 0.36), &local)
    rect(11, -6, 10, 12, 3, body.opacity(0.6), &local)
    ellipse(17, -4, 7, 8, Palette.ink, &local)
    rect(24, -7, 4, 14, 2, Palette.brass, &local)
    if train.state == .running && train.waiting.isEmpty && !simulation.paused {
      for n in 0..<3 {
        let phase = (simulation.elapsed * 0.7 + Double(n) * 0.3).truncatingRemainder(dividingBy: 1)
        ellipse(
          14 - phase * 25, -14 - phase * 20, 8 + phase * 9, 8 + phase * 7,
          .white.opacity((1 - phase) * 0.55), &local)
      }
    }
    rect(p.x - 19, p.y + 19, 38, 17, 6, Palette.paper, &context)
    label(train.id, p.x, p.y + 27.5, size: 9, fill: body, context: &context)
  }
}
