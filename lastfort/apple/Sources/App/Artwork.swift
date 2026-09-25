import SwiftUI

extension GraphicsContext {
  func rectangle(_ rect: CGRect, _ color: Color, radius: Double = 0) {
    fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(color))
  }
  func ellipse(_ x: Double, _ y: Double, _ width: Double, _ height: Double, _ color: Color) {
    fill(
      Path(ellipseIn: CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)),
      with: .color(color))
  }
  func line(_ points: [CGPoint], _ color: Color, width: Double = 1) {
    guard let first = points.first else { return }
    var path = Path()
    path.move(to: first)
    for point in points.dropFirst() { path.addLine(to: point) }
    stroke(path, with: .color(color), lineWidth: width)
  }
  func label(_ text: String, _ x: Double, _ y: Double, size: Double = 12, color: Color = .white) {
    draw(
      Text(text).font(.system(size: size, weight: .bold)).foregroundColor(color),
      at: CGPoint(x: x, y: y))
  }
}

struct CosmeticArt: View {
  let cosmetic: Cosmetic
  var body: some View {
    Canvas { context, size in
      var canvas = context
      let scale = min(size.width, size.height) / 240
      canvas.translateBy(x: size.width / 2, y: size.height / 2)
      canvas.scaleBy(x: scale, y: scale)
      let primary = Color(rgb: cosmetic.primary)
      let secondary = Color(rgb: cosmetic.secondary)
      let accent = Color(rgb: cosmetic.accent)
      canvas.ellipse(0, 96, 164, 26, .black.opacity(0.25))
      switch cosmetic.slot {
      case .outfit:
        for sign in [-1.0, 1] {
          canvas.rectangle(
            CGRect(x: sign * 25 - 15, y: 35, width: 30, height: 60), secondary, radius: 10)
          canvas.rectangle(
            CGRect(x: sign * 27 - 21, y: 80, width: 42, height: 22), primary, radius: 7)
          canvas.rectangle(
            CGRect(x: sign * 51 - 16, y: -30, width: 32, height: 70), primary, radius: 12)
          canvas.rectangle(
            CGRect(x: sign * 51 - 13, y: 29, width: 26, height: 24), secondary, radius: 8)
          canvas.rectangle(
            CGRect(x: sign * 52 - 20, y: -39, width: 40, height: 30), accent.opacity(0.65),
            radius: 8)
        }
        canvas.rectangle(CGRect(x: -40, y: -44, width: 80, height: 94), primary, radius: 18)
        canvas.rectangle(CGRect(x: -34, y: 26, width: 68, height: 14), secondary, radius: 4)
        canvas.rectangle(CGRect(x: -8, y: 27, width: 16, height: 12), accent, radius: 2)
        canvas.rectangle(CGRect(x: -18, y: -39, width: 36, height: 53), secondary, radius: 6)
        canvas.line(
          [CGPoint(x: -12, y: -19), CGPoint(x: 0, y: -6), CGPoint(x: 16, y: -25)], accent, width: 5)
        canvas.rectangle(CGRect(x: -31, y: -100, width: 62, height: 63), primary, radius: 19)
        canvas.rectangle(CGRect(x: -26, y: -77, width: 52, height: 23), .lfInk, radius: 8)
        canvas.rectangle(CGRect(x: -21, y: -72, width: 42, height: 8), accent, radius: 3)
        canvas.line(
          [CGPoint(x: -20, y: -90), CGPoint(x: -5, y: -94)], .white.opacity(0.7), width: 3)
        if cosmetic.shape == 1 || cosmetic.shape == 4 {
          canvas.line(
            [CGPoint(x: -16, y: -98), CGPoint(x: 0, y: -112), CGPoint(x: 16, y: -98)], accent,
            width: 7)
        }
        if cosmetic.shape == 2 {
          canvas.ellipse(-34, -66, 14, 30, secondary)
          canvas.ellipse(34, -66, 14, 30, secondary)
        }
        if cosmetic.shape == 3 {
          canvas.line(
            [CGPoint(x: -31, y: -85), CGPoint(x: -45, y: -108), CGPoint(x: -18, y: -97)], primary,
            width: 10)
          canvas.line(
            [CGPoint(x: 31, y: -85), CGPoint(x: 45, y: -108), CGPoint(x: 18, y: -97)], primary,
            width: 10)
        }
      case .pickaxe:
        canvas.rotate(by: .degrees(32))
        canvas.rectangle(CGRect(x: -9, y: -64, width: 18, height: 153), secondary, radius: 6)
        canvas.rectangle(CGRect(x: -69, y: -70, width: 138, height: 28), primary, radius: 8)
        canvas.line([CGPoint(x: -65, y: -53), CGPoint(x: -86, y: -23)], accent, width: 15)
        if cosmetic.shape > 0 {
          canvas.line([CGPoint(x: 62, y: -65), CGPoint(x: 83, y: -92)], accent, width: 17)
        }
        canvas.rectangle(CGRect(x: -12, y: 42, width: 24, height: 14), accent, radius: 2)
      case .glider:
        var path = Path()
        path.move(to: CGPoint(x: -104, y: 0))
        path.addQuadCurve(to: CGPoint(x: 104, y: 0), control: CGPoint(x: 0, y: -140))
        path.addQuadCurve(to: CGPoint(x: -104, y: 0), control: CGPoint(x: 0, y: -35))
        canvas.fill(path, with: .color(primary))
        canvas.stroke(path, with: .color(accent), lineWidth: 5)
        canvas.line(
          [
            CGPoint(x: -95, y: -2), CGPoint(x: -15, y: 83), CGPoint(x: 15, y: 83),
            CGPoint(x: 95, y: -2),
          ], accent, width: 3)
        canvas.line([CGPoint(x: 0, y: -70), CGPoint(x: 0, y: -24)], secondary, width: 12)
      case .banner:
        canvas.rectangle(CGRect(x: -65, y: -85, width: 130, height: 145), primary, radius: 12)
        canvas.line(
          [CGPoint(x: -60, y: 53), CGPoint(x: 0, y: 96), CGPoint(x: 60, y: 53)], primary, width: 20)
        if cosmetic.shape == 2 {
          canvas.ellipse(0, -10, 92, 49, secondary)
          canvas.ellipse(0, -10, 29, 29, accent)
        } else if cosmetic.shape == 1 {
          canvas.line(
            [
              CGPoint(x: 15, y: -61), CGPoint(x: -24, y: -8), CGPoint(x: 19, y: -8),
              CGPoint(x: -13, y: 40),
            ], accent, width: 11)
        } else {
          canvas.rectangle(CGRect(x: -29, y: -34, width: 58, height: 64), secondary, radius: 4)
          for x in [-24.0, 0, 24] {
            canvas.rectangle(CGRect(x: x - 8, y: -47, width: 16, height: 25), accent, radius: 2)
          }
        }
      }
    }.accessibilityLabel(cosmetic.name)
  }
}
