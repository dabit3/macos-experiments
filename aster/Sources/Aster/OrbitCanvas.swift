import AsterCore
import SwiftUI

struct OrbitCanvas: View {
  @Bindable var controller: MissionController

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let center = CGPoint(x: size.width * 0.48, y: size.height * 0.56)
      let extent = max(10_800.0, min(30_000, maxRadius))
      let scale = min(size.width * 0.44, size.height * 0.40) / extent
      ZStack(alignment: .topLeading) {
        Canvas { context, canvas in
          drawSpace(context: &context, size: canvas, center: center, scale: scale)
          drawOrbit(
            controller.previousPath, context: &context, center: center, scale: scale,
            color: Theme.muted.opacity(0.25), dashed: true)
          drawOrbit(
            controller.currentPath, context: &context, center: center, scale: scale,
            color: .white.opacity(0.55), dashed: false)
          if controller.showPrediction {
            drawOrbit(
              controller.plannedPath, context: &context, center: center, scale: scale,
              color: Theme.cyan, dashed: false)
          }
          drawPlanet(context: &context, center: center, radius: Orbit.earthRadius * scale)
          drawProbe(context: &context, center: center, scale: scale)
        }
        .accessibilityLabel(
          "Earth orbital map. White current orbit, cyan planned trajectory, dashed target altitude."
        )
        VStack(alignment: .leading, spacing: 10) {
          HStack(spacing: 8) {
            Circle().fill(controller.paused ? Theme.amber : Theme.green).frame(width: 6, height: 6)
            Eyebrow(
              text: controller.state.impacted
                ? "SURFACE CONTACT" : controller.paused ? "FLIGHT PAUSED" : "LIVE PROPAGATION",
              color: controller.paused ? Theme.amber : Theme.green)
          }
          Text("The art of the orbit.").font(.system(size: 31, weight: .light, design: .serif))
          Text("ONE PLANET. INFINITE POSSIBILITIES.")
            .font(.system(size: 9, design: .monospaced)).tracking(2).foregroundStyle(Theme.muted)
        }.padding(28)
        VStack {
          HStack {
            Spacer()
            Toggle("Prediction", isOn: $controller.showPrediction)
              .toggleStyle(.switch).controlSize(.mini)
              .font(.system(size: 11)).foregroundStyle(Theme.muted)
          }
          Spacer()
          HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
              legend("CURRENT ORBIT", color: .white.opacity(0.65))
              legend("PLANNED TRAJECTORY", color: Theme.cyan)
              legend("TARGET ALTITUDE", color: Theme.cyan.opacity(0.4))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 7) {
              Eyebrow(text: "EARTH / SOL III")
              Text("μ 398,600.4418 km³/s²").font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.muted)
              Text("PLANAR · INERTIAL FRAME").font(.system(size: 8, design: .monospaced)).tracking(
                1
              ).foregroundStyle(Theme.muted)
            }
          }
        }.padding(28)
        if controller.burnFlash {
          Text("BURN EXECUTED").font(.system(size: 12, weight: .semibold, design: .monospaced))
            .tracking(3).foregroundStyle(Theme.amber)
            .padding(14).background(Theme.background.opacity(0.9))
            .clipShape(Capsule()).position(x: size.width / 2, y: size.height - 75)
        }
      }
    }
    .clipped()
  }

  private var maxRadius: Double {
    let paths =
      controller.showPrediction
      ? controller.currentPath + controller.plannedPath : controller.currentPath
    return paths.map { $0.state.position.magnitude }.max() ?? 10_800
  }

  private func legend(_ title: String, color: Color) -> some View {
    HStack(spacing: 8) {
      Rectangle().fill(color).frame(width: 17, height: 1)
      Text(title).font(.system(size: 8, design: .monospaced)).tracking(1).foregroundStyle(
        Theme.muted)
    }
  }

  private func point(_ vector: Vector, center: CGPoint, scale: Double) -> CGPoint {
    CGPoint(x: center.x + vector.x * scale, y: center.y - vector.y * scale)
  }

  private func drawSpace(
    context: inout GraphicsContext, size: CGSize, center: CGPoint, scale: Double
  ) {
    for index in 0..<150 {
      let x = Double((index * 7919 + 113) % 1009) / 1009 * size.width
      let y = Double((index * 3571 + 397) % 1013) / 1013 * size.height
      let radius = index % 7 == 0 ? 1.1 : 0.6
      let opacity = Double(index % 5 + 1) * 0.065
      context.fill(
        Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
        with: .color(.white.opacity(opacity)))
    }
    for radius in [8_000.0, 10_000, 12_000, 14_000] {
      let r = radius * scale
      context.stroke(
        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)),
        with: .color(Theme.line.opacity(0.35)), lineWidth: 0.5)
    }
    var axes = Path()
    axes.move(to: CGPoint(x: 20, y: center.y))
    axes.addLine(to: CGPoint(x: size.width - 20, y: center.y))
    axes.move(to: CGPoint(x: center.x, y: 70))
    axes.addLine(to: CGPoint(x: center.x, y: size.height - 30))
    context.stroke(
      axes, with: .color(Theme.line.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 6]))
    let target = (Orbit.earthRadius + Orbit.goalAltitude) * scale
    context.stroke(
      Path(
        ellipseIn: CGRect(
          x: center.x - target, y: center.y - target, width: target * 2, height: target * 2)),
      with: .color(Theme.cyan.opacity(0.28)), style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
    let label = Text("2,400 km TARGET").font(.system(size: 9, design: .monospaced)).foregroundStyle(
      Theme.cyan.opacity(0.65))
    context.draw(label, at: CGPoint(x: center.x, y: center.y - target - 13))
  }

  private func drawOrbit(
    _ points: [TrajectoryPoint], context: inout GraphicsContext, center: CGPoint, scale: Double,
    color: Color, dashed: Bool
  ) {
    guard let first = points.first else { return }
    var path = Path()
    path.move(to: point(first.state.position, center: center, scale: scale))
    for sample in points.dropFirst() {
      path.addLine(to: point(sample.state.position, center: center, scale: scale))
    }
    context.stroke(
      path, with: .color(color), style: StrokeStyle(lineWidth: 1.35, dash: dashed ? [4, 6] : []))
    if !dashed, points.count > 50,
      let farthest = points.max(by: { $0.state.altitude < $1.state.altitude })
    {
      let location = point(farthest.state.position, center: center, scale: scale)
      context.fill(
        Path(ellipseIn: CGRect(x: location.x - 2.5, y: location.y - 2.5, width: 5, height: 5)),
        with: .color(color))
    }
  }

  private func drawPlanet(context: inout GraphicsContext, center: CGPoint, radius: Double) {
    let disk = CGRect(
      x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    for layer in (1...15).reversed() {
      let spread = Double(layer) * 1.6
      context.stroke(
        Path(ellipseIn: disk.insetBy(dx: -spread, dy: -spread)),
        with: .color(Theme.cyan.opacity(0.025 * (1 - Double(layer) / 18))), lineWidth: 2)
    }
    context.fill(
      Path(ellipseIn: disk),
      with: .radialGradient(
        Gradient(colors: [
          Color(red: 0.18, green: 0.40, blue: 0.48), Color(red: 0.06, green: 0.20, blue: 0.29),
          Color(red: 0.018, green: 0.065, blue: 0.12),
        ]),
        center: CGPoint(x: center.x - radius * 0.5, y: center.y - radius * 0.6), startRadius: 0,
        endRadius: radius * 1.85))
    var globe = context
    globe.clip(to: Path(ellipseIn: disk))
    let continents: [[(Double, Double)]] = [
      [
        (-0.81, -0.48), (-0.61, -0.73), (-0.34, -0.72), (-0.22, -0.60), (-0.03, -0.56),
        (0.02, -0.40), (-0.20, -0.25), (-0.24, -0.07), (-0.38, 0.04), (-0.42, 0.19), (-0.58, 0.09),
        (-0.64, -0.11), (-0.81, -0.22),
      ],
      [
        (-0.36, 0.12), (-0.15, 0.16), (0.04, 0.32), (-0.06, 0.52), (-0.18, 0.64), (-0.26, 0.91),
        (-0.40, 0.72), (-0.44, 0.40),
      ],
      [
        (0.06, -0.55), (0.19, -0.70), (0.53, -0.74), (0.71, -0.54), (0.97, -0.46), (1.12, -0.19),
        (0.83, -0.05), (0.62, -0.15), (0.51, 0.06), (0.36, -0.03), (0.25, -0.18), (0.05, -0.20),
      ],
      [
        (0.13, -0.10), (0.39, -0.13), (0.57, 0.09), (0.48, 0.35), (0.31, 0.61), (0.17, 0.38),
        (0.04, 0.10),
      ],
      [(0.72, 0.52), (0.95, 0.39), (1.03, 0.63), (0.88, 0.77), (0.71, 0.71)],
      [(-0.37, -0.85), (-0.11, -0.94), (-0.01, -0.77), (-0.16, -0.64)],
    ]
    for (index, coordinates) in continents.enumerated() {
      var land = Path()
      for (offset, coordinate) in coordinates.enumerated() {
        let p = CGPoint(x: center.x + coordinate.0 * radius, y: center.y + coordinate.1 * radius)
        if offset == 0 { land.move(to: p) } else { land.addLine(to: p) }
      }
      land.closeSubpath()
      globe.fill(
        land,
        with: .color(Color(red: 0.30, green: 0.48, blue: 0.47).opacity(index < 2 ? 0.50 : 0.25)))
      globe.stroke(land, with: .color(Theme.cyan.opacity(0.12)), lineWidth: 0.7)
    }
    for latitude in [-0.66, -0.33, 0.0, 0.33, 0.66] {
      let halfWidth = radius * sqrt(1 - latitude * latitude)
      let ellipse = CGRect(
        x: center.x - halfWidth, y: center.y + radius * latitude - radius * 0.11,
        width: halfWidth * 2, height: radius * 0.22)
      globe.stroke(
        Path(ellipseIn: ellipse), with: .color(Theme.cyan.opacity(0.10)), lineWidth: 0.55)
    }
    for width in [0.35, 0.70, 1.0] {
      globe.stroke(
        Path(
          ellipseIn: CGRect(
            x: center.x - radius * width, y: center.y - radius, width: radius * width * 2,
            height: radius * 2)), with: .color(Theme.cyan.opacity(0.10)), lineWidth: 0.55)
    }
    globe.fill(
      Path(ellipseIn: disk),
      with: .linearGradient(
        Gradient(stops: [
          .init(color: .clear, location: 0.22), .init(color: .black.opacity(0.15), location: 0.47),
          .init(color: .black.opacity(0.78), location: 1),
        ]),
        startPoint: CGPoint(x: disk.minX, y: disk.minY),
        endPoint: CGPoint(x: disk.maxX, y: disk.maxY)))
    context.stroke(Path(ellipseIn: disk), with: .color(Theme.cyan.opacity(0.38)), lineWidth: 0.8)
  }

  private func drawProbe(context: inout GraphicsContext, center: CGPoint, scale: Double) {
    let position = point(controller.state.position, center: center, scale: scale)
    context.fill(
      Path(ellipseIn: CGRect(x: position.x - 11, y: position.y - 11, width: 22, height: 22)),
      with: .color(Theme.cyan.opacity(0.08)))
    var diamond = Path()
    diamond.move(to: CGPoint(x: position.x, y: position.y - 5))
    diamond.addLine(to: CGPoint(x: position.x + 5, y: position.y))
    diamond.addLine(to: CGPoint(x: position.x, y: position.y + 5))
    diamond.addLine(to: CGPoint(x: position.x - 5, y: position.y))
    diamond.closeSubpath()
    context.fill(diamond, with: .color(.white))
    context.draw(
      Text("PROBE 01").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(
        .white), at: CGPoint(x: position.x + 17, y: position.y - 16), anchor: .leading)
    if controller.deltaV > 0.01 {
      let impulse = (controller.proposed.velocity - controller.state.velocity).unit
      let tip = CGPoint(x: position.x + impulse.x * 58, y: position.y - impulse.y * 58)
      var arrow = Path()
      arrow.move(to: position)
      arrow.addLine(to: tip)
      context.stroke(arrow, with: .color(Theme.amber), lineWidth: 2)
      context.fill(
        Path(ellipseIn: CGRect(x: tip.x - 4, y: tip.y - 4, width: 8, height: 8)),
        with: .color(Theme.amber))
      context.draw(
        Text("Δv").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.amber),
        at: CGPoint(x: tip.x + 13, y: tip.y))
    }
  }
}
