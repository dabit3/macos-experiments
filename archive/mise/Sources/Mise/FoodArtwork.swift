import SwiftUI

enum Palette {
  static let paper = Color(hex: 0xF7F3EA)
  static let ink = Color(hex: 0x272F27)
  static let muted = Color(hex: 0x777A6D)
  static let red = Color(hex: 0xBC412E)
  static let green = Color(hex: 0x365845)
  static let line = Color(hex: 0xDEDCCD)
  static let cream = Color(hex: 0xEDE7D7)
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
  }
}

struct FoodArtwork: View {
  let kind: String
  var body: some View {
    Canvas { context, size in
      let s = min(size.width, size.height)
      let origin = CGPoint(x: (size.width - s) / 2, y: (size.height - s) / 2)
      context.translateBy(x: origin.x, y: origin.y)
      context.scaleBy(x: s / 400, y: s / 400)
      drawTable(&context)
      oval(&context, CGRect(x: 54, y: 64, width: 304, height: 298), Color.black.opacity(0.09))
      oval(&context, CGRect(x: 44, y: 43, width: 312, height: 312), Color(hex: 0xFAF6EB))
      context.stroke(
        Path(ellipseIn: CGRect(x: 53, y: 52, width: 294, height: 294)),
        with: .color(Color(hex: 0xD9D3C1)), lineWidth: 1.5)
      oval(&context, CGRect(x: 77, y: 76, width: 246, height: 246), Color(hex: 0xEEE8D9))
      switch kind {
      case "salmon": salmon(&context)
      case "risotto": risotto(&context)
      case "chickpeas": bowl(&context)
      case "pancakes": pancakes(&context)
      default: pasta(&context)
      }
      for i in 0..<34 {
        let x = 90 + random(i, 12) * 220
        let y = 90 + random(i, 23) * 220
        if hypot(x - 200, y - 200) < 115 {
          oval(&context, CGRect(x: x, y: y, width: 1.8, height: 2.3), Palette.ink.opacity(0.6))
        }
      }
    }
    .accessibilityLabel(
      "Original illustration of \(kind == "pomodoro" ? "tomato rigatoni with basil on a ceramic plate" : kind)"
    )
  }

  private func random(_ i: Int, _ seed: Int) -> Double {
    let value = sin(Double(i * 127 + seed * 31)) * 43_758.5453
    return value - floor(value)
  }

  private func oval(_ c: inout GraphicsContext, _ r: CGRect, _ color: Color) {
    c.fill(Path(ellipseIn: r), with: .color(color))
  }

  private func drawTable(_ c: inout GraphicsContext) {
    c.fill(
      Path(CGRect(x: -400, y: -400, width: 1200, height: 1200)), with: .color(Color(hex: 0xE1DCC7)))
    var cloth = Path()
    cloth.move(to: CGPoint(x: -80, y: 210))
    cloth.addLine(to: CGPoint(x: 105, y: 350))
    cloth.addLine(to: CGPoint(x: 150, y: 450))
    cloth.addLine(to: CGPoint(x: -80, y: 450))
    cloth.closeSubpath()
    c.fill(cloth, with: .color(Color(hex: 0xAFBA9A)))
    for i in 0..<25 {
      var line = Path()
      line.move(to: CGPoint(x: -70 + i * 10, y: 280))
      line.addLine(to: CGPoint(x: -30 + i * 10, y: 450))
      c.stroke(line, with: .color(Color.white.opacity(0.18)), lineWidth: 1)
    }
    for i in 0..<90 {
      oval(
        &c, CGRect(x: random(i, 7) * 440 - 20, y: random(i, 8) * 440 - 20, width: 1, height: 1),
        Color(hex: 0x968C70).opacity(0.25))
    }
  }

  private func leaf(
    _ c: inout GraphicsContext, x: Double, y: Double, angle: Double, scale: Double = 1
  ) {
    var local = c
    local.translateBy(x: x, y: y)
    local.rotate(by: .degrees(angle))
    local.scaleBy(x: scale, y: scale)
    var p = Path()
    p.move(to: CGPoint(x: 0, y: 0))
    p.addQuadCurve(to: CGPoint(x: 0, y: -43), control: CGPoint(x: -28, y: -26))
    p.addQuadCurve(to: .zero, control: CGPoint(x: 25, y: -34))
    local.fill(
      p,
      with: .linearGradient(
        Gradient(colors: [Color(hex: 0x648049), Color(hex: 0x2E5132)]),
        startPoint: CGPoint(x: -15, y: -40), endPoint: CGPoint(x: 12, y: 0)))
    var vein = Path()
    vein.move(to: .zero)
    vein.addLine(to: CGPoint(x: 0, y: -37))
    local.stroke(vein, with: .color(Color(hex: 0xABC17A).opacity(0.55)), lineWidth: 1)
  }

  private func pasta(_ c: inout GraphicsContext) {
    oval(&c, CGRect(x: 91, y: 92, width: 218, height: 212), Color(hex: 0xB74427))
    for i in 0..<58 {
      let x = 112 + random(i, 1) * 178
      let y = 110 + random(i, 2) * 175
      if hypot(x - 200, y - 200) > 103 { continue }
      var local = c
      local.translateBy(x: x, y: y)
      local.rotate(by: .degrees(random(i, 3) * 180))
      let rect = CGRect(x: -12, y: -22, width: 24, height: 45)
      local.fill(
        Path(roundedRect: rect, cornerRadius: 4),
        with: .linearGradient(
          Gradient(colors: [Color(hex: 0xF3BC64), Color(hex: 0xDE7B38), Color(hex: 0xBA542A)]),
          startPoint: CGPoint(x: -12, y: 0), endPoint: CGPoint(x: 12, y: 0)))
      for j in 0..<4 {
        var line = Path()
        line.move(to: CGPoint(x: -8 + j * 5, y: -18))
        line.addLine(to: CGPoint(x: -8 + j * 5, y: 17))
        local.stroke(line, with: .color(Color(hex: 0xFFD090).opacity(0.6)), lineWidth: 1.2)
      }
      oval(&local, CGRect(x: -11, y: -23, width: 22, height: 7), Color(hex: 0x984124))
      local.stroke(
        Path(ellipseIn: CGRect(x: -11, y: -23, width: 22, height: 7)),
        with: .color(Color(hex: 0xE8A755)), lineWidth: 2)
    }
    for (x, y) in [(125.0, 170.0), (248, 133), (268, 244), (152, 262), (188, 185)] {
      oval(&c, CGRect(x: x - 16, y: y - 13, width: 32, height: 27), Color(hex: 0xAA3024))
      oval(&c, CGRect(x: x - 12, y: y - 10, width: 24, height: 18), Color(hex: 0xDA4D2E))
      oval(&c, CGRect(x: x - 8, y: y - 6, width: 4, height: 3), Color(hex: 0xF4B95A))
    }
    for i in 0..<38 {
      let x = 112 + random(i, 13) * 175
      let y = 104 + random(i, 14) * 178
      c.fill(
        Path(roundedRect: CGRect(x: x, y: y, width: 7, height: 2), cornerRadius: 1),
        with: .color(Color(hex: 0xFFF0BC)))
    }
    leaf(&c, x: 207, y: 191, angle: -35, scale: 1.1)
    leaf(&c, x: 206, y: 191, angle: 60)
    leaf(&c, x: 158, y: 248, angle: -75, scale: 0.8)
    leaf(&c, x: 262, y: 200, angle: 130, scale: 0.65)
  }

  private func salmon(_ c: inout GraphicsContext) {
    for i in 0..<16 {
      var l = c
      l.translateBy(x: 136 + random(i, 3) * 50, y: 170 + random(i, 4) * 80)
      l.rotate(by: .degrees(-30 + random(i, 2) * 35))
      l.fill(
        Path(roundedRect: CGRect(x: -5, y: -70, width: 10, height: 145), cornerRadius: 5),
        with: .color(Color(hex: i % 2 == 0 ? 0x668149 : 0x496A39)))
    }
    var fish = c
    fish.translateBy(x: 230, y: 208)
    fish.rotate(by: .degrees(24))
    fish.fill(
      Path(roundedRect: CGRect(x: -45, y: -83, width: 92, height: 164), cornerRadius: 16),
      with: .linearGradient(
        Gradient(colors: [Color(hex: 0xE78A55), Color(hex: 0xF3B47E), Color(hex: 0xBD642F)]),
        startPoint: CGPoint(x: -40, y: 0), endPoint: CGPoint(x: 45, y: 0)))
    for i in 0..<11 {
      var line = Path()
      line.move(to: CGPoint(x: -39, y: -69 + i * 13))
      line.addQuadCurve(
        to: CGPoint(x: 38, y: -60 + i * 13), control: CGPoint(x: 5, y: -42 + i * 13))
      fish.stroke(line, with: .color(Color(hex: 0xFFE0AD)), lineWidth: 2)
    }
    oval(&c, CGRect(x: 105, y: 250, width: 64, height: 64), Color(hex: 0xE6BF4E))
    oval(&c, CGRect(x: 110, y: 255, width: 54, height: 54), Color(hex: 0xF8DD7B))
    leaf(&c, x: 240, y: 151, angle: 65, scale: 0.8)
  }

  private func risotto(_ c: inout GraphicsContext) {
    oval(&c, CGRect(x: 92, y: 98, width: 216, height: 210), Color(hex: 0xC6A16C))
    for i in 0..<280 {
      let x = 97 + random(i, 1) * 206
      let y = 100 + random(i, 2) * 200
      if hypot(x - 200, y - 200) < 100 {
        oval(
          &c, CGRect(x: x, y: y, width: 9, height: 5), Color(hex: i % 3 == 0 ? 0xE2C792 : 0xD4B982))
      }
    }
    for i in 0..<10 {
      var l = c
      l.translateBy(x: 132 + random(i, 5) * 135, y: 125 + random(i, 6) * 140)
      l.rotate(by: .degrees(random(i, 7) * 360))
      l.fill(
        Path(roundedRect: CGRect(x: -5, y: -8, width: 10, height: 33), cornerRadius: 3),
        with: .color(Color(hex: 0xC0A07A)))
      oval(&l, CGRect(x: -23, y: -20, width: 46, height: 28), Color(hex: 0x694730))
      oval(&l, CGRect(x: -19, y: -19, width: 38, height: 17), Color(hex: 0x9A7650))
    }
    leaf(&c, x: 215, y: 172, angle: 60, scale: 0.6)
    leaf(&c, x: 215, y: 172, angle: -30, scale: 0.7)
  }

  private func bowl(_ c: inout GraphicsContext) {
    for i in 0..<22 {
      leaf(
        &c, x: 110 + random(i, 1) * 170, y: 140 + random(i, 2) * 145, angle: random(i, 3) * 360,
        scale: 1.3)
    }
    for i in 0..<80 {
      let x = 112 + random(i, 4) * 88
      let y = 126 + random(i, 5) * 150
      oval(
        &c, CGRect(x: x, y: y, width: 12, height: 10), Color(hex: i % 2 == 0 ? 0xD4AD64 : 0xE9CA85))
    }
    for i in 0..<20 {
      var l = c
      l.translateBy(x: 219 + random(i, 6) * 70, y: 126 + random(i, 7) * 150)
      l.rotate(by: .degrees(random(i, 8) * 90))
      l.fill(
        Path(roundedRect: CGRect(x: -12, y: -12, width: 25, height: 26), cornerRadius: 4),
        with: .color(Color(hex: i % 2 == 0 ? 0xC97739 : 0xE3A052)))
    }
    var drizzle = Path()
    drizzle.move(to: CGPoint(x: 138, y: 130))
    drizzle.addCurve(
      to: CGPoint(x: 260, y: 268), control1: CGPoint(x: 360, y: 200),
      control2: CGPoint(x: 53, y: 177))
    c.stroke(
      drizzle, with: .color(Color(hex: 0xF4E4BB)), style: StrokeStyle(lineWidth: 6, lineCap: .round)
    )
  }

  private func pancakes(_ c: inout GraphicsContext) {
    for i in 0..<4 {
      let rect = CGRect(x: 99 + i * 2, y: 142 - i * 11, width: 202, height: 152)
      oval(&c, rect, Color(hex: 0xA76430))
      oval(
        &c, rect.insetBy(dx: 3, dy: 4).offsetBy(dx: 0, dy: -5),
        Color(hex: i == 3 ? 0xD6A15B : 0xEAC088))
    }
    oval(&c, CGRect(x: 130, y: 140, width: 140, height: 85), Color(hex: 0xB67B39).opacity(0.45))
    c.fill(
      Path(roundedRect: CGRect(x: 181, y: 160, width: 35, height: 28), cornerRadius: 4),
      with: .color(Color(hex: 0xF8DB8C)))
    for i in 0..<24 {
      let x = 111 + random(i, 2) * 167
      let y = 119 + random(i, 3) * 145
      oval(&c, CGRect(x: x, y: y, width: 17, height: 16), Color(hex: 0x39485C))
      oval(&c, CGRect(x: x + 3, y: y + 2, width: 6, height: 5), Color(hex: 0x7B87A0))
    }
    leaf(&c, x: 245, y: 162, angle: 65, scale: 0.7)
  }
}
