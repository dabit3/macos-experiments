import SwiftUI

enum Ink {
  static let deep = Color(red: 0.07, green: 0.27, blue: 0.27)
  static let teal = Color(red: 0.09, green: 0.52, blue: 0.49)
  static let sand = Color(red: 0.96, green: 0.93, blue: 0.85)
  static let muted = Color(red: 0.32, green: 0.45, blue: 0.43)
  static let coral = Color(red: 0.90, green: 0.39, blue: 0.28)
}

struct CreatureArt: View {
  let creature: Creature
  var animated = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !animated || reduceMotion)) {
      timeline in
      Canvas { context, size in
        let phase = animated && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0
        let scale = min(size.width, size.height) / 100
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: 0, y: sin(phase * 1.8) * (animated ? 2 : 0))
        draw(context: context, phase: phase)
      }
    }
    .accessibilityHidden(true)
  }

  private func draw(context: GraphicsContext, phase: Double) {
    func ellipse(_ rect: CGRect, _ color: Color) {
      context.fill(Path(ellipseIn: rect), with: .color(color))
    }
    switch creature {
    case .coral:
      let shadow = Path(ellipseIn: CGRect(x: -25, y: 25, width: 53, height: 13))
      context.fill(shadow, with: .color(.black.opacity(0.12)))
      var branches = Path()
      branches.move(to: CGPoint(x: 0, y: 29))
      branches.addCurve(
        to: CGPoint(x: -6, y: -34), control1: CGPoint(x: 4, y: 0),
        control2: CGPoint(x: -10, y: -12))
      for (start, joint, end) in [
        (CGPoint(x: 0, y: 19), CGPoint(x: -27, y: 0), CGPoint(x: -31, y: -18)),
        (CGPoint(x: 0, y: 10), CGPoint(x: 24, y: -1), CGPoint(x: 32, y: -24)),
        (CGPoint(x: -5, y: -8), CGPoint(x: -18, y: -20), CGPoint(x: -22, y: -34)),
        (CGPoint(x: 1, y: -2), CGPoint(x: 13, y: -15), CGPoint(x: 13, y: -38)),
      ] {
        branches.move(to: start)
        branches.addQuadCurve(to: end, control: joint)
      }
      context.stroke(
        branches,
        with: .linearGradient(
          Gradient(colors: [Color(red: 1, green: 0.76, blue: 0.55), Ink.coral]),
          startPoint: CGPoint(x: 0, y: -35), endPoint: CGPoint(x: 0, y: 30)),
        style: StrokeStyle(lineWidth: 10, lineCap: .round))
      context.stroke(
        branches, with: .color(.white.opacity(0.30)),
        style: StrokeStyle(lineWidth: 2, lineCap: .round))
      ellipse(CGRect(x: -13, y: 23, width: 27, height: 12), Ink.coral)
    case .anemone:
      for index in 0..<20 {
        let angle = Double(index) * .pi * 2 / 20
        let radius = 24.0 + sin(Double(index) * 1.9 + phase * 1.5) * 3
        var tentacle = Path()
        tentacle.move(to: CGPoint(x: cos(angle) * 8, y: sin(angle) * 7 + 9))
        tentacle.addQuadCurve(
          to: CGPoint(x: cos(angle) * radius, y: sin(angle) * radius - 7),
          control: CGPoint(x: cos(angle + 0.4) * 39, y: sin(angle + 0.4) * 31))
        context.stroke(
          tentacle,
          with: .color(
            index % 2 == 0
              ? Color(red: 0.75, green: 0.43, blue: 0.60)
              : Color(red: 0.94, green: 0.62, blue: 0.65)),
          style: StrokeStyle(lineWidth: 7, lineCap: .round))
      }
      ellipse(
        CGRect(x: -15, y: -14, width: 30, height: 28), Color(red: 0.94, green: 0.72, blue: 0.61))
      ellipse(CGRect(x: -5, y: -5, width: 10, height: 9), Color(red: 0.62, green: 0.30, blue: 0.46))
      ellipse(CGRect(x: -2, y: -4, width: 4, height: 3), .white.opacity(0.6))
    case .clownfish:
      var tail = Path()
      tail.move(to: CGPoint(x: -20, y: 0))
      tail.addLine(to: CGPoint(x: -42, y: -18))
      tail.addQuadCurve(to: CGPoint(x: -42, y: 18), control: CGPoint(x: -34, y: 0))
      tail.closeSubpath()
      context.fill(tail, with: .color(Ink.coral))
      context.stroke(tail, with: .color(Ink.deep.opacity(0.6)), lineWidth: 2)
      var fin = Path()
      fin.move(to: CGPoint(x: -15, y: -13))
      fin.addQuadCurve(to: CGPoint(x: 20, y: -13), control: CGPoint(x: 0, y: -35))
      context.fill(fin, with: .color(Color(red: 0.98, green: 0.62, blue: 0.22)))
      let body = Path(ellipseIn: CGRect(x: -29, y: -19, width: 64, height: 40))
      context.fill(
        body,
        with: .linearGradient(
          Gradient(colors: [Color(red: 1, green: 0.75, blue: 0.28), Ink.coral]),
          startPoint: CGPoint(x: 0, y: -19), endPoint: CGPoint(x: 0, y: 20)))
      context.stroke(body, with: .color(Ink.deep.opacity(0.45)), lineWidth: 1.5)
      var stripes = context
      stripes.clip(to: body)
      for x in [-17.0, 8.0] {
        var stripe = Path()
        stripe.move(to: CGPoint(x: x, y: -22))
        stripe.addQuadCurve(
          to: CGPoint(x: x + 1, y: 24), control: CGPoint(x: x - 10, y: 0))
        stripes.stroke(stripe, with: .color(Ink.deep), lineWidth: 12)
        stripes.stroke(stripe, with: .color(Ink.sand), lineWidth: 8)
      }
      ellipse(CGRect(x: 21, y: -8, width: 6, height: 7), Ink.deep)
      ellipse(CGRect(x: 23, y: -7, width: 2, height: 2), .white)
      var pectoral = Path()
      pectoral.move(to: CGPoint(x: 6, y: 5))
      pectoral.addQuadCurve(to: CGPoint(x: -6, y: 15), control: CGPoint(x: 0, y: 23))
      context.stroke(
        pectoral, with: .color(Ink.coral), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    case .seastar:
      var star = Path()
      var points: [CGPoint] = []
      for index in 0..<10 {
        let angle = Double(index) * .pi / 5 - .pi / 2
        let radius = index % 2 == 0 ? 37.0 : 14.0
        points.append(CGPoint(x: cos(angle) * radius, y: sin(angle) * radius))
      }
      star.move(to: points[0])
      for point in points.dropFirst() { star.addLine(to: point) }
      star.closeSubpath()
      context.fill(
        star,
        with: .linearGradient(
          Gradient(colors: [Color(red: 1, green: 0.77, blue: 0.47), Ink.coral]),
          startPoint: CGPoint(x: -20, y: -30), endPoint: CGPoint(x: 25, y: 30)))
      context.stroke(
        star, with: .color(Color(red: 0.88, green: 0.43, blue: 0.29)),
        style: StrokeStyle(lineWidth: 4, lineJoin: .round))
      for index in 0..<5 {
        let angle = Double(index) * .pi * 2 / 5 - .pi / 2
        for radius in stride(from: 8.0, through: 26.0, by: 6) {
          ellipse(
            CGRect(x: cos(angle) * radius - 1.5, y: sin(angle) * radius - 1.5, width: 3, height: 3),
            .white.opacity(0.55))
        }
      }
    case .urchin:
      for index in 0..<32 {
        let angle = Double(index) * .pi / 16
        let radius = index % 2 == 0 ? 37.0 : 30.0
        var spine = Path()
        spine.move(to: CGPoint(x: cos(angle) * 15, y: sin(angle) * 15))
        spine.addLine(to: CGPoint(x: cos(angle) * radius, y: sin(angle) * radius))
        context.stroke(
          spine, with: .color(Color(red: 0.31, green: 0.32, blue: 0.49)),
          style: StrokeStyle(lineWidth: 3, lineCap: .round))
      }
      ellipse(
        CGRect(x: -23, y: -23, width: 46, height: 46), Color(red: 0.43, green: 0.43, blue: 0.61))
      for index in 0..<18 {
        let angle = Double(index) * 2.4
        let radius = sqrt(Double(index)) * 4.4
        ellipse(
          CGRect(x: cos(angle) * radius - 2, y: sin(angle) * radius - 2, width: 4, height: 4),
          Color(red: 0.73, green: 0.68, blue: 0.79))
      }
    }
  }
}

struct WaterLight: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { timeline in
      Canvas { context, size in
        let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
        for index in 0..<14 {
          let x = Double(index) * 37 + sin(time * 0.35 + Double(index)) * 12
          let y = Double((index * 71) % 310) + cos(time * 0.3 + Double(index)) * 8
          var ripple = Path()
          ripple.addEllipse(in: CGRect(x: x - 20, y: y, width: 84, height: 27))
          context.stroke(ripple, with: .color(.white.opacity(0.11)), lineWidth: 1.5)
        }
        for index in 0..<55 {
          let x = Double((index * 53 + 11) % 337) / 337 * size.width
          let y = Double((index * 97 + 19) % 331) / 331 * size.height
          context.fill(
            Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)),
            with: .color(.white.opacity(0.22)))
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
