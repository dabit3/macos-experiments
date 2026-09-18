import SwiftUI

enum Palette {
  static let paper = Color(hex: 0xF7F7EF)
  static let ink = Color(hex: 0x263D30)
  static let secondary = Color(hex: 0x687661)
  static let sage = Color(hex: 0xE6EBDA)
  static let fern = Color(hex: 0x50764A)
  static let gold = Color(hex: 0xAF713B)
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1
    )
  }
}

struct BotanicalArt: View {
  let specimen: Specimen
  var body: some View {
    Canvas { context, size in
      let scale = min(size.width / 260, size.height / 320)
      context.translateBy(x: (size.width - 260 * scale) / 2, y: (size.height - 320 * scale) / 2)
      context.scaleBy(x: scale, y: scale)
      context.fill(
        Path(ellipseIn: CGRect(x: 62, y: 290, width: 144, height: 15)),
        with: .color(Palette.ink.opacity(0.08))
      )
      switch specimen {
      case .monstera:
        branch(&context, to: CGPoint(x: 53, y: 117))
        branch(&context, to: CGPoint(x: 200, y: 117))
        branch(&context, to: CGPoint(x: 120, y: 60))
        leaf(&context, x: 129, y: 214, angle: -44, length: 135, width: 83, style: 1, tone: 0)
        leaf(&context, x: 137, y: 183, angle: 39, length: 141, width: 90, style: 1, tone: 1)
        leaf(&context, x: 125, y: 147, angle: -12, length: 119, width: 85, style: 1, tone: 2)
        leaf(&context, x: 126, y: 218, angle: 55, length: 102, width: 69, style: 1, tone: 0)
      case .fiddle:
        branch(&context, to: CGPoint(x: 127, y: 34))
        for (x, y, angle, tone) in [
          (127.0, 202.0, -62.0, 0), (131, 181, 56, 1), (128, 144, -54, 2),
          (127, 118, 48, 0), (127, 78, -20, 1),
        ] {
          leaf(&context, x: x, y: y, angle: angle, length: 88, width: 58, style: 2, tone: tone)
        }
      case .snake:
        for (x, angle, length, tone) in [
          (110.0, -25.0, 185.0, 1), (140, 22, 206, 0), (131, 4, 226, 2),
          (156, 29, 155, 1), (107, -8, 151, 0),
        ] {
          leaf(
            &context, x: x, y: 245, angle: angle, length: length, width: 26, style: 3, tone: tone)
        }
      case .calathea:
        for (x, y, angle, length, tone) in [
          (128.0, 234.0, -64.0, 131.0, 0), (128, 206, 50, 150, 1),
          (129, 190, -38, 157, 2), (129, 175, 14, 151, 0), (129, 239, 54, 110, 2),
        ] {
          branch(&context, to: CGPoint(x: x, y: y - 40))
          leaf(&context, x: x, y: y, angle: angle, length: length, width: 61, style: 4, tone: tone)
        }
      case .pothos:
        var vine = Path()
        vine.move(to: CGPoint(x: 131, y: 238))
        vine.addCurve(
          to: CGPoint(x: 64, y: 298), control1: CGPoint(x: 19, y: 71),
          control2: CGPoint(x: 13, y: 272))
        context.stroke(vine, with: .color(Palette.fern), lineWidth: 3)
        for (x, y, angle, length, tone) in [
          (128.0, 221.0, -45.0, 93.0, 0), (136, 209, 42, 100, 1),
          (126, 168, -10, 103, 2), (108, 172, -69, 80, 0),
          (43, 224, -34, 61, 1), (46, 275, 44, 59, 2),
        ] {
          leaf(
            &context, x: x, y: y, angle: angle, length: length, width: length * 0.7, style: 0,
            tone: tone)
        }
      case .rubber:
        branch(&context, to: CGPoint(x: 125, y: 36))
        for (x, y, angle, length, tone) in [
          (129.0, 214.0, -67.0, 100.0, 0), (129, 173, 57, 108, 1),
          (127, 130, -49, 110, 0), (127, 90, 37, 85, 2),
        ] {
          leaf(&context, x: x, y: y, angle: angle, length: length, width: 56, style: 5, tone: tone)
        }
      }
      pot(&context)
    }
    .accessibilityHidden(true)
  }

  private func branch(_ context: inout GraphicsContext, to point: CGPoint) {
    var stem = Path()
    stem.move(to: CGPoint(x: 132, y: 260))
    stem.addQuadCurve(to: point, control: CGPoint(x: 126, y: 168))
    context.stroke(
      stem, with: .color(Color(hex: 0x617248)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
  }

  private func leaf(
    _ context: inout GraphicsContext, x: Double, y: Double, angle: Double,
    length: Double, width: Double, style: Int, tone: Int
  ) {
    var ctx = context
    ctx.translateBy(x: x, y: y)
    ctx.rotate(by: .degrees(angle))
    let greens: [UInt32] =
      style == 5 ? [0x244A37, 0x365840, 0x6C8050] : [0x426B3C, 0x6D8B4C, 0x315B39]
    let base = Color(hex: greens[tone % 3])
    var path = Path()
    path.move(to: .zero)
    if style == 1 {
      path.addCurve(
        to: CGPoint(x: 0, y: -length), control1: CGPoint(x: -width * 0.9, y: -length * 0.15),
        control2: CGPoint(x: -width * 0.54, y: -length * 0.81))
      path.addCurve(
        to: .zero, control1: CGPoint(x: width * 0.76, y: -length * 0.72),
        control2: CGPoint(x: width * 0.71, y: -length * 0.12))
    } else if style == 2 {
      path.addCurve(
        to: CGPoint(x: -width * 0.42, y: -length * 0.62),
        control1: CGPoint(x: -width, y: -length * 0.22),
        control2: CGPoint(x: -width * 0.15, y: -length * 0.38))
      path.addCurve(
        to: CGPoint(x: 0, y: -length), control1: CGPoint(x: -width * 0.85, y: -length),
        control2: CGPoint(x: -width * 0.21, y: -length * 1.05))
      path.addCurve(
        to: CGPoint(x: width * 0.42, y: -length * 0.62),
        control1: CGPoint(x: width * 0.78, y: -length * 1.04),
        control2: CGPoint(x: width * 0.78, y: -length * 0.79))
      path.addCurve(
        to: .zero, control1: CGPoint(x: width * 0.12, y: -length * 0.38),
        control2: CGPoint(x: width * 0.82, y: -length * 0.19))
    } else {
      path.addCurve(
        to: CGPoint(x: 0, y: -length), control1: CGPoint(x: -width * 0.9, y: -length * 0.38),
        control2: CGPoint(x: -width * 0.55, y: -length * 0.75))
      path.addCurve(
        to: .zero, control1: CGPoint(x: width * 0.65, y: -length * 0.78),
        control2: CGPoint(x: width * 0.73, y: -length * 0.3))
    }
    path.closeSubpath()
    ctx.fill(
      path,
      with: .linearGradient(
        Gradient(colors: [base.opacity(0.88), base, Color(hex: 0x234C32)]),
        startPoint: CGPoint(x: -width, y: -length), endPoint: CGPoint(x: width, y: 0)
      ))
    ctx.clip(to: path)
    var midrib = Path()
    midrib.move(to: .zero)
    midrib.addQuadCurve(to: CGPoint(x: 0, y: -length), control: CGPoint(x: 8, y: -length * 0.55))
    ctx.stroke(
      midrib, with: .color(Color(hex: 0xB4C28A).opacity(0.75)), lineWidth: style == 3 ? 3 : 1.1)
    for index in 1...6 {
      let position = Double(index) / 8
      for sign in [-1.0, 1.0] {
        var vein = Path()
        vein.move(to: CGPoint(x: 2, y: -length * position))
        vein.addQuadCurve(
          to: CGPoint(x: sign * width * 0.65, y: -length * (position + 0.18)),
          control: CGPoint(x: sign * width * 0.38, y: -length * (position + 0.08))
        )
        ctx.stroke(
          vein,
          with: .color(
            style == 4 ? Color(hex: 0xBDCB95).opacity(0.66) : Color(hex: 0xBBCA8C).opacity(0.25)),
          lineWidth: style == 4 ? 5 : (style == 3 ? 4 : 0.8)
        )
      }
    }
    if style == 1 {
      for index in 2...4 {
        for sign in [-1.0, 1.0] {
          let yy = -length * Double(index) / 6
          var cut = Path()
          cut.move(to: CGPoint(x: sign * width * 0.75, y: yy + 14))
          cut.addQuadCurve(
            to: CGPoint(x: sign * width * 0.14, y: yy + 10),
            control: CGPoint(x: sign * width * 0.42, y: yy + 21))
          cut.addQuadCurve(
            to: CGPoint(x: sign * width * 0.75, y: yy - 3),
            control: CGPoint(x: sign * width * 0.39, y: yy + 4))
          cut.closeSubpath()
          ctx.blendMode = .destinationOut
          ctx.fill(cut, with: .color(.black))
          ctx.blendMode = .normal
        }
      }
    }
  }

  private func pot(_ context: inout GraphicsContext) {
    let terracotta = specimen == .fiddle || specimen == .rubber
    let colors =
      terracotta
      ? [Color(hex: 0xC49B7F), Color(hex: 0xA77557)]
      : [Color(hex: 0xDED4BF), Color(hex: 0xBCAF93)]
    var body = Path()
    body.move(to: CGPoint(x: 87, y: 238))
    body.addLine(to: CGPoint(x: 99, y: 286))
    body.addQuadCurve(to: CGPoint(x: 165, y: 286), control: CGPoint(x: 130, y: 307))
    body.addLine(to: CGPoint(x: 178, y: 238))
    body.closeSubpath()
    context.fill(
      body,
      with: .linearGradient(
        Gradient(colors: colors), startPoint: CGPoint(x: 95, y: 238),
        endPoint: CGPoint(x: 179, y: 290)))
    context.fill(
      Path(ellipseIn: CGRect(x: 86, y: 226, width: 93, height: 27)), with: .color(colors[0]))
    context.fill(
      Path(ellipseIn: CGRect(x: 94, y: 230, width: 76, height: 17)),
      with: .color(Color(hex: 0x67583E)))
    var rim = Path()
    rim.addArc(
      center: CGPoint(x: 132, y: 235), radius: 42, startAngle: .degrees(15),
      endAngle: .degrees(165), clockwise: false,
      transform: CGAffineTransform(scaleX: 1, y: 0.25).translatedBy(x: 0, y: 705))
    for index in 0..<13 {
      let xx = 101 + Double(index) * 5
      var line = Path()
      line.move(to: CGPoint(x: xx, y: 257))
      line.addLine(to: CGPoint(x: xx + (132 - xx) * 0.1, y: 287))
      context.stroke(line, with: .color(Color.white.opacity(0.13)), lineWidth: 1)
    }
  }
}
