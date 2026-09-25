import SwiftUI

enum Palette {
  static let cream = Color(hex: 0xF8F5EE)
  static let plum = Color(hex: 0x38243D)
  static let muted = Color(hex: 0x817782)
  static let coral = Color(hex: 0xD97459)
  static let lilac = Color(hex: 0xB7B6EA)
  static let green = Color(hex: 0x3B705F)
  static let line = Color(hex: 0xE6E0D9)
  static let people = [
    Color(hex: 0xEEC3AC), Color(hex: 0xC4C8F2), Color(hex: 0xCEDBC4), Color(hex: 0xE8D1E7),
  ]

  static func color(_ category: Category) -> Color {
    switch category {
    case .stay: Color(hex: 0xE8DFF0)
    case .food: Color(hex: 0xF5DFCB)
    case .travel: Color(hex: 0xDFE5D7)
    case .experiences: Color(hex: 0xDFE2F6)
    }
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
  }
}

struct PersonAvatar: View {
  let person: Traveler
  var size: CGFloat = 40

  var body: some View {
    Text(person.initials)
      .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
      .foregroundStyle(Palette.plum)
      .frame(width: size, height: size)
      .background(
        Palette.people[["alex", "jamie", "sam", "you"].firstIndex(of: person.id) ?? 0], in: Circle()
      )
      .accessibilityLabel(person.name)
  }
}

struct PrimaryButton: View {
  let title: String
  var icon: String = "plus"
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: icon).font(.system(size: 15, weight: .semibold))
        Text(title).font(.system(size: 16, weight: .semibold))
      }
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .foregroundStyle(.white)
      .background(Palette.plum, in: RoundedRectangle(cornerRadius: 18))
    }
    .buttonStyle(.plain)
  }
}

struct Eyebrow: View {
  let text: String
  var body: some View {
    Text(text.uppercased())
      .font(.system(size: 10, weight: .bold, design: .monospaced))
      .tracking(1.7)
      .foregroundStyle(Palette.muted)
  }
}

struct LisbonArt: View {
  var body: some View {
    Canvas { context, size in
      let sx = size.width / 360
      let sy = size.height / 170
      context.scaleBy(x: sx, y: sy)
      func polygon(_ points: [CGPoint], _ color: Color) {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        context.fill(path, with: .color(color))
      }
      func rectangle(
        _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color, radius: Double = 0
      ) {
        context.fill(
          Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius),
          with: .color(color))
      }
      func line(_ points: [CGPoint], _ color: Color, _ width: Double = 1) {
        var path = Path()
        path.addLines(points)
        context.stroke(
          path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
      }
      rectangle(0, 0, 360, 170, Color(hex: 0xE5E3F5))
      context.fill(
        Path(ellipseIn: CGRect(x: 268, y: 16, width: 44, height: 44)),
        with: .color(Color(hex: 0xF5B996)))
      polygon(
        [
          CGPoint(x: 0, y: 110), CGPoint(x: 118, y: 67), CGPoint(x: 210, y: 88),
          CGPoint(x: 360, y: 67), CGPoint(x: 360, y: 170), CGPoint(x: 0, y: 170),
        ], Color(hex: 0xC5CBDD))
      rectangle(0, 136, 360, 34, Color(hex: 0x8BAEBC))
      for x in stride(from: 8, to: 350, by: 48) {
        line([CGPoint(x: x, y: 149), CGPoint(x: x + 25, y: 149)], Color.white.opacity(0.45))
        line([CGPoint(x: x + 14, y: 160), CGPoint(x: x + 36, y: 160)], Color.white.opacity(0.3))
      }
      polygon(
        [
          CGPoint(x: 0, y: 123), CGPoint(x: 146, y: 112), CGPoint(x: 269, y: 145),
          CGPoint(x: 360, y: 170), CGPoint(x: 0, y: 170),
        ], Color(hex: 0xDBBC9F))
      for house in [
        (18.0, 61.0, 43.0, 69.0, 0xE6A58C as UInt32), (67, 43, 42, 83, 0xF2D7AC),
        (117, 69, 50, 61, 0xEEB7A8), (172, 54, 40, 80, 0xECE8DC), (220, 85, 34, 54, 0xD89880),
      ] {
        let (x, y, w, h, color) = house
        rectangle(x, y, w, h, Color(hex: color))
        polygon(
          [CGPoint(x: x - 3, y: y), CGPoint(x: x + w / 2, y: y - 15), CGPoint(x: x + w + 3, y: y)],
          Palette.coral)
        for row in 0..<3 {
          for column in 0..<2 {
            rectangle(
              x + 8 + Double(column) * (w - 21), y + 10 + Double(row) * 18, 7, 10,
              Palette.plum.opacity(0.7), radius: 1)
            line(
              [
                CGPoint(x: x + 6 + Double(column) * (w - 21), y: y + 22 + Double(row) * 18),
                CGPoint(x: x + 17 + Double(column) * (w - 21), y: y + 22 + Double(row) * 18),
              ], .white.opacity(0.7))
          }
        }
      }
      rectangle(181, 21, 22, 35, Color(hex: 0xECE8DC))
      rectangle(186, 7, 12, 14, Color(hex: 0xECE8DC))
      polygon([CGPoint(x: 182, y: 8), CGPoint(x: 192, y: 0), CGPoint(x: 202, y: 8)], Palette.coral)
      context.fill(
        Path(ellipseIn: CGRect(x: 188, y: 26, width: 9, height: 9)),
        with: .color(Palette.plum.opacity(0.65)))
      line(
        [CGPoint(x: 5, y: 143), CGPoint(x: 180, y: 155), CGPoint(x: 288, y: 170)],
        Palette.plum.opacity(0.35), 2)
      line(
        [CGPoint(x: 3, y: 153), CGPoint(x: 169, y: 164), CGPoint(x: 202, y: 170)],
        Palette.plum.opacity(0.35), 2)
      rectangle(53, 115, 69, 34, Color(hex: 0xE6B755), radius: 5)
      rectangle(50, 111, 75, 6, Palette.plum, radius: 3)
      rectangle(53, 137, 69, 5, Color(hex: 0xF9EACA))
      for x in stride(from: 60, to: 114, by: 14) {
        rectangle(Double(x), 119, 10, 13, Palette.plum.opacity(0.8), radius: 2)
      }
      for x in [64.0, 104.0] {
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: 146, width: 8, height: 8)), with: .color(Palette.plum))
      }
      line(
        [CGPoint(x: 86, y: 111), CGPoint(x: 99, y: 93), CGPoint(x: 0, y: 88)],
        Palette.plum.opacity(0.55))
      line([CGPoint(x: 99, y: 93), CGPoint(x: 350, y: 80)], Palette.plum.opacity(0.55))
      polygon(
        [CGPoint(x: 298, y: 110), CGPoint(x: 298, y: 145), CGPoint(x: 321, y: 145)],
        Color(hex: 0xFFF8E8))
      line([CGPoint(x: 295, y: 104), CGPoint(x: 295, y: 150)], Palette.plum.opacity(0.7))
      polygon(
        [
          CGPoint(x: 282, y: 151), CGPoint(x: 320, y: 151), CGPoint(x: 313, y: 157),
          CGPoint(x: 288, y: 157),
        ], Palette.plum)
      line(
        [CGPoint(x: 247, y: 36), CGPoint(x: 252, y: 33), CGPoint(x: 257, y: 36)],
        Palette.plum.opacity(0.45))
      line(
        [CGPoint(x: 323, y: 62), CGPoint(x: 328, y: 59), CGPoint(x: 333, y: 62)],
        Palette.plum.opacity(0.45))
    }
    .accessibilityLabel(
      "Original illustration of Lisbon: tiled houses, a yellow tram and a sailboat on the Tagus.")
  }
}
