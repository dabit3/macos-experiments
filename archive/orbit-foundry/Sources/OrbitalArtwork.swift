import SwiftUI

enum OrbitalDrawing {
  static func ellipse(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Path {
    Path(ellipseIn: CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height))
  }
  static func stars(_ context: inout GraphicsContext, size: CGSize) {
    for index in 0..<90 {
      let x = Double((index * 137 + 29) % 997) / 997 * size.width
      let y = Double((index * 277 + 83) % 991) / 991 * size.height
      let radius = index.isMultiple(of: 9) ? 1.8 : 0.8
      context.fill(
        ellipse(x, y, radius, radius),
        with: .color(Palette.ivory.opacity(index.isMultiple(of: 3) ? 0.45 : 0.17)))
    }
  }
  static func planet(
    _ context: inout GraphicsContext, center: CGPoint, radius: Double, hue: Double, time: Double = 0
  ) {
    let sphere = ellipse(center.x, center.y, radius * 2, radius * 2)
    let color = Color(hue: hue, saturation: 0.5, brightness: 0.76)
    context.fill(
      ellipse(center.x, center.y, radius * 2.5, radius * 2.5),
      with: .radialGradient(
        Gradient(colors: [color.opacity(0.22), .clear]), center: center, startRadius: radius * 0.8,
        endRadius: radius * 1.25))
    context.fill(
      sphere,
      with: .radialGradient(
        Gradient(colors: [
          Color(hue: hue, saturation: 0.32, brightness: 0.95), color, Palette.background,
        ]),
        center: CGPoint(x: center.x - radius * 0.48, y: center.y - radius * 0.52),
        startRadius: 0, endRadius: radius * 1.8))
    var surface = context
    surface.clip(to: sphere)
    for index in 0..<18 {
      let offset = Double(index) / 17 * radius * 2 - radius
      var contour = Path()
      contour.move(to: CGPoint(x: center.x - radius, y: center.y + offset))
      contour.addCurve(
        to: CGPoint(x: center.x + radius, y: center.y + offset - radius * 0.18),
        control1: CGPoint(x: center.x - radius * 0.1, y: center.y + offset + radius * 0.32),
        control2: CGPoint(x: center.x + radius * 0.32, y: center.y + offset - radius * 0.14))
      surface.stroke(
        contour, with: .color(Palette.ivory.opacity(index.isMultiple(of: 3) ? 0.17 : 0.07)),
        lineWidth: index.isMultiple(of: 3) ? 1.1 : 0.5)
    }
    context.stroke(sphere, with: .color(color.opacity(0.7)), lineWidth: 0.8)
    context.stroke(
      ellipse(center.x, center.y, radius * 2 + 12, radius * 2 + 12),
      with: .color(Palette.copper.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 5]))
  }
  static func line(_ context: inout GraphicsContext, points: [Vector], predicted: Bool) {
    guard let first = points.first, points.count > 1 else { return }
    var path = Path()
    path.move(to: CGPoint(x: first.x, y: first.y))
    for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.x, y: point.y)) }
    context.stroke(path, with: .color(Palette.cyan.opacity(0.06)), lineWidth: 12)
    context.stroke(
      path, with: .color(Palette.cyan.opacity(predicted ? 0.7 : 1)),
      style: StrokeStyle(
        lineWidth: predicted ? 1.2 : 2.0, lineCap: .round, dash: predicted ? [3, 5] : []))
  }
  static func beacon(
    _ context: inout GraphicsContext, at point: Vector, collected: Bool, time: Double
  ) {
    let r = collected ? 15.0 + sin(time * 3) * 2 : 15.0
    let opacity = collected ? 0.25 : 0.65
    context.fill(
      ellipse(point.x, point.y, 38, 38),
      with: .radialGradient(
        Gradient(colors: [Palette.cyan.opacity(collected ? 0.12 : 0.23), .clear]),
        center: CGPoint(x: point.x, y: point.y), startRadius: 0, endRadius: 19))
    context.stroke(
      ellipse(point.x, point.y, r * 2, r * 2), with: .color(Palette.cyan.opacity(opacity)),
      lineWidth: 0.7)
    if collected {
      var check = Path()
      check.move(to: CGPoint(x: point.x - 4, y: point.y))
      check.addLine(to: CGPoint(x: point.x - 1, y: point.y + 3))
      check.addLine(to: CGPoint(x: point.x + 5, y: point.y - 4))
      context.stroke(check, with: .color(Palette.cyan), lineWidth: 1.5)
    } else {
      var diamond = Path()
      diamond.move(to: CGPoint(x: point.x, y: point.y - 5))
      diamond.addLine(to: CGPoint(x: point.x + 5, y: point.y))
      diamond.addLine(to: CGPoint(x: point.x, y: point.y + 5))
      diamond.addLine(to: CGPoint(x: point.x - 5, y: point.y))
      diamond.closeSubpath()
      context.fill(diamond, with: .color(Palette.cyan))
    }
  }
  static func capture(_ context: inout GraphicsContext, at point: Vector, age: Double) {
    guard age >= 0, age < 0.7 else { return }
    let progress = age / 0.7
    let radius = 16 + progress * 30
    context.stroke(
      ellipse(point.x, point.y, radius * 2, radius * 2),
      with: .color(Palette.cyan.opacity(1 - progress)), lineWidth: 1.2)
    for index in 0..<8 {
      let angle = Double(index) * .pi / 4
      let x = point.x + cos(angle) * (radius + 4)
      let y = point.y + sin(angle) * (radius + 4)
      context.fill(ellipse(x, y, 2.5, 2.5), with: .color(Palette.ivory.opacity(1 - progress)))
    }
  }
  static func station(_ context: inout GraphicsContext, at point: Vector) {
    context.stroke(
      ellipse(point.x, point.y, 44, 44), with: .color(Palette.ivory.opacity(0.3)),
      style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
    context.stroke(ellipse(point.x, point.y, 18, 18), with: .color(Palette.ivory), lineWidth: 1.5)
    context.fill(
      Path(CGRect(x: point.x - 3, y: point.y - 6, width: 6, height: 12)),
      with: .color(Palette.ivory))
    for sign in [-1.0, 1.0] {
      context.stroke(
        Path(CGRect(x: point.x + sign * 15 - 4, y: point.y - 8, width: 8, height: 16)),
        with: .color(Palette.ivory), lineWidth: 1)
      var link = Path()
      link.move(to: CGPoint(x: point.x + sign * 5, y: point.y))
      link.addLine(to: CGPoint(x: point.x + sign * 19, y: point.y))
      context.stroke(link, with: .color(Palette.ivory), lineWidth: 1)
    }
    context.draw(
      Text("DOCK").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(2)
        .foregroundColor(Palette.ivory.opacity(0.7)),
      at: CGPoint(x: point.x, y: point.y - 33))
  }
  static func probe(_ context: inout GraphicsContext, at point: Vector, velocity: Vector) {
    context.fill(
      ellipse(point.x, point.y, 30, 30),
      with: .radialGradient(
        Gradient(colors: [Palette.cyan.opacity(0.25), .clear]),
        center: CGPoint(x: point.x, y: point.y), startRadius: 0, endRadius: 15))
    var transformed = context
    transformed.translateBy(x: point.x, y: point.y)
    transformed.rotate(by: .radians(atan2(velocity.x, -velocity.y)))
    var shape = Path()
    shape.move(to: CGPoint(x: 0, y: -8))
    shape.addLine(to: CGPoint(x: 5, y: 6))
    shape.addLine(to: CGPoint(x: 0, y: 3))
    shape.addLine(to: CGPoint(x: -5, y: 6))
    shape.closeSubpath()
    transformed.fill(shape, with: .color(Palette.ivory))
  }
}

struct SolarArtwork: View {
  let time: Double
  var body: some View {
    Canvas { context, size in
      OrbitalDrawing.stars(&context, size: size)
      let center = CGPoint(x: size.width * 0.54, y: size.height * 0.48)
      var orbits = context
      orbits.translateBy(x: center.x, y: center.y)
      orbits.rotate(by: .degrees(-28))
      for index in 0..<4 {
        let width = 190.0 + Double(index) * 62
        orbits.stroke(
          OrbitalDrawing.ellipse(0, 0, width, width * 0.43),
          with: .color(index == 1 ? Palette.cyan.opacity(0.5) : Palette.copper.opacity(0.33)),
          style: StrokeStyle(lineWidth: index == 1 ? 1.1 : 0.6))
      }
      OrbitalDrawing.planet(&context, center: center, radius: 72, hue: 0.065)
      let phase = time * 0.13
      let point = Vector(x: center.x + cos(phase) * 143, y: center.y + sin(phase) * 82)
      OrbitalDrawing.probe(&context, at: point, velocity: Vector(x: -sin(phase), y: cos(phase)))
      OrbitalDrawing.planet(
        &context, center: CGPoint(x: center.x - 118, y: center.y + 66), radius: 19, hue: 0.58)
      context.draw(
        Text("G  /  6.674").font(.system(size: 9, design: .monospaced)).tracking(2).foregroundColor(
          Palette.muted),
        at: CGPoint(x: 48, y: 25))
      context.draw(
        Text("EST.  ∞").font(.system(size: 9, design: .monospaced)).tracking(2).foregroundColor(
          Palette.copper),
        at: CGPoint(x: size.width - 35, y: size.height - 15))
    }
    .accessibilityElement(children: .ignore)
  }
}

struct FlightCanvas: View {
  let controller: FlightController
  let reduceMotion: Bool
  let onAim: (Vector) -> Void
  var body: some View {
    GeometryReader { geometry in
      let scale = min(geometry.size.width / 360, geometry.size.height / 540)
      let offsetX = (geometry.size.width - 360 * scale) / 2
      let offsetY = (geometry.size.height - 540 * scale) / 2
      Canvas { context, size in
        context.translateBy(x: offsetX, y: offsetY)
        context.scaleBy(x: scale, y: scale)
        OrbitalDrawing.stars(&context, size: CGSize(width: 360, height: 540))
        for y in stride(from: 30, through: 510, by: 30) {
          var rule = Path()
          rule.move(to: CGPoint(x: 4, y: y))
          rule.addLine(to: CGPoint(x: y.isMultiple(of: 90) ? 11 : 7, y: y))
          rule.move(to: CGPoint(x: 356, y: y))
          rule.addLine(to: CGPoint(x: y.isMultiple(of: 90) ? 349 : 353, y: y))
          context.stroke(rule, with: .color(Palette.muted.opacity(0.3)), lineWidth: 0.5)
        }
        for planet in controller.mission.planets {
          OrbitalDrawing.planet(
            &context, center: CGPoint(x: planet.center.x, y: planet.center.y),
            radius: planet.radius, hue: planet.hue)
          context.draw(
            Text(String(format: "μ %.1f", planet.gravity / 100_000))
              .font(.system(size: 10, design: .monospaced)).foregroundColor(Palette.copper),
            at: CGPoint(x: planet.center.x, y: planet.center.y + planet.radius + 22))
        }
        OrbitalDrawing.line(
          &context, points: controller.isReady ? controller.prediction : controller.trail,
          predicted: controller.isReady)
        for (index, beacon) in controller.mission.beacons.enumerated() {
          OrbitalDrawing.beacon(
            &context, at: beacon, collected: controller.flight?.collected.contains(index) == true,
            time: reduceMotion ? 0 : controller.flight?.elapsed ?? 0)
          if !reduceMotion, let moment = controller.captureMoments[index] {
            OrbitalDrawing.capture(
              &context, at: beacon, age: (controller.flight?.elapsed ?? 0) - moment)
          }
        }
        OrbitalDrawing.station(&context, at: controller.mission.station)
        let position = controller.flight?.position ?? controller.mission.origin
        OrbitalDrawing.probe(
          &context, at: position, velocity: controller.flight?.velocity ?? controller.velocity)
        if controller.isReady {
          let origin = controller.mission.origin
          context.stroke(
            OrbitalDrawing.ellipse(origin.x, origin.y, 60, 60),
            with: .color(Palette.copper.opacity(0.6)),
            style: StrokeStyle(lineWidth: 0.8, dash: [3, 4]))
          context.draw(
            Text("DRAG TO AIM").font(.system(size: 10, weight: .medium, design: .monospaced))
              .tracking(1.5).foregroundColor(Palette.copper),
            at: CGPoint(x: min(300, max(63, origin.x)), y: origin.y + 42))
        }
      }
      .overlay {
        if controller.isReady {
          Circle().fill(Color.clear).frame(width: 72, height: 72)
            .contentShape(Circle())
            .position(
              x: controller.mission.origin.x * scale + offsetX,
              y: controller.mission.origin.y * scale + offsetY
            )
            .highPriorityGesture(
              DragGesture(minimumDistance: 4, coordinateSpace: .named("flightField"))
                .onChanged { value in
                  controller.isAiming = true
                  onAim(
                    Vector(
                      x: (value.location.x - offsetX) / scale,
                      y: (value.location.y - offsetY) / scale))
                }
                .onEnded { _ in controller.isAiming = false }
            )
            .accessibilityHidden(true)
        }
      }
      .coordinateSpace(name: "flightField")
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        "Orbital flight field, \(controller.mission.planets.count) planets, \(controller.flight?.collected.count ?? 0) of \(controller.mission.beacons.count) beacons collected"
      )
      .accessibilityHint(
        "Use the bearing and thrust controls below to aim, or align with Flight guide.")
    }
  }
}
