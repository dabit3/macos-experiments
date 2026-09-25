import SwiftUI

enum Palette {
  static let paper = Color(red: 0.98, green: 0.96, blue: 0.91)
  static let ink = Color(red: 0.21, green: 0.10, blue: 0.17)
  static let red = Color(red: 0.76, green: 0.19, blue: 0.12)
  static let muted = Color(red: 0.44, green: 0.36, blue: 0.36)
  static let line = Color(red: 0.84, green: 0.80, blue: 0.75)
  static let green = Color(red: 0.23, green: 0.35, blue: 0.22)
}

extension Font {
  static func editorial(_ size: CGFloat) -> Font {
    .custom("Georgia", size: size, relativeTo: .largeTitle)
  }
}

struct Eyebrow: View {
  let text: String
  var body: some View {
    Text(text.uppercased())
      .font(.caption.weight(.bold)).tracking(2)
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
  }
}

struct MainButton: View {
  let title: String
  var symbol: String = "arrow.right"
  var action: () -> Void

  var body: some View {
    Button(action: {
      UIImpactFeedbackGenerator(style: .soft).impactOccurred()
      action()
    }) {
      HStack(spacing: 12) {
        Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
        Spacer()
        Image(systemName: symbol).font(.headline)
      }
      .padding(.horizontal, 22).padding(.vertical, 17).frame(minHeight: 60)
      .foregroundStyle(.white)
      .background(Palette.red, in: RoundedRectangle(cornerRadius: 18))
    }.buttonStyle(.plain)
  }
}

struct PlateMark: View {
  var body: some View {
    ZStack {
      Circle().strokeBorder(Palette.red, lineWidth: 1.5)
      Circle().strokeBorder(Palette.red, lineWidth: 1).padding(5)
      Text("s").font(.system(size: 29, design: .serif).italic()).foregroundStyle(Palette.red)
    }.frame(width: 40, height: 40).accessibilityHidden(true)
  }
}

struct FoodArt: View {
  let style: Int
  var body: some View {
    Canvas { context, size in
      let s = min(size.width, size.height)
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      var c = context
      c.translateBy(x: center.x - s / 2, y: center.y - s / 2)
      c.scaleBy(x: s / 300, y: s / 300)
      let backgrounds: [Color] = [
        Color(red: 0.92, green: 0.72, blue: 0.54),
        Color(red: 0.79, green: 0.82, blue: 0.65),
        Color(red: 0.76, green: 0.73, blue: 0.80),
      ]
      c.fill(
        Path(CGRect(x: -500, y: -500, width: 1300, height: 1300)),
        with: .color(backgrounds[style % 3]))
      for index in 0..<28 {
        let x = Double(index) * 16 - 50
        var stripe = Path()
        stripe.move(to: CGPoint(x: x, y: -20))
        stripe.addLine(to: CGPoint(x: x + 90, y: 340))
        c.stroke(stripe, with: .color(.white.opacity(0.08)), lineWidth: 1)
      }
      c.addFilter(.shadow(color: .black.opacity(0.14), radius: 8, x: 2, y: 8))
      c.fill(
        Path(ellipseIn: CGRect(x: 27, y: 24, width: 250, height: 250)), with: .color(Palette.paper))
      c = context
      c.translateBy(x: center.x - s / 2, y: center.y - s / 2)
      c.scaleBy(x: s / 300, y: s / 300)
      c.stroke(
        Path(ellipseIn: CGRect(x: 36, y: 33, width: 232, height: 232)),
        with: .color(Color(red: 0.61, green: 0.67, blue: 0.64)), lineWidth: 2)
      c.stroke(
        Path(ellipseIn: CGRect(x: 53, y: 50, width: 198, height: 198)), with: .color(Palette.line),
        lineWidth: 1)
      let sauce =
        style == 4
        ? Color(red: 0.55, green: 0.65, blue: 0.31)
        : (style == 0 || style == 6 || style == 9
          ? Color(red: 0.72, green: 0.24, blue: 0.12) : Color(red: 0.77, green: 0.65, blue: 0.42))
      c.fill(Path(ellipseIn: CGRect(x: 61, y: 58, width: 182, height: 183)), with: .color(sauce))
      if style == 1 {
        for offset in [0.0, 60.0] {
          let toast = Path(
            roundedRect: CGRect(x: 76 + offset, y: 82, width: 77, height: 128), cornerRadius: 21)
          c.fill(toast, with: .color(Color(red: 0.49, green: 0.27, blue: 0.13)))
          c.fill(
            Path(
              roundedRect: CGRect(x: 81 + offset, y: 88, width: 67, height: 114), cornerRadius: 18),
            with: .color(Color(red: 0.91, green: 0.75, blue: 0.48)))
        }
      }
      for i in 0..<230 {
        let angle = Double(i) * 2.399963
        let radius = sqrt(Double(i) / 230) * 80
        let x = 151 + cos(angle) * radius + sin(Double(i) * 7.31) * 3
        let y = 149 + sin(angle) * radius + cos(Double(i) * 5.17) * 3
        var grain = c
        grain.translateBy(x: x, y: y)
        grain.rotate(by: .radians(angle * 3.7 + Double(i % 7)))
        let colors: [Color] = [
          Color(red: 0.95, green: 0.79, blue: 0.45),
          Color(red: 0.90, green: 0.68, blue: 0.32),
          Color(red: 0.98, green: 0.87, blue: 0.59),
        ]
        let isBean = style == 1 || style == 6 || style == 8
        let isLentil = style == 3
        let rect = CGRect(
          x: -5, y: -3, width: isBean ? 12 : (isLentil ? 5 : 11),
          height: isBean ? 9 : (isLentil ? 5 : 4))
        grain.fill(
          Path(ellipseIn: rect),
          with: .color(style == 4 ? Color(red: 0.71, green: 0.78, blue: 0.39) : colors[i % 3]))
      }
      if style == 0 || style == 9 {
        for (index, point) in [
          CGPoint(x: 102, y: 100), CGPoint(x: 188, y: 93),
          CGPoint(x: 119, y: 174), CGPoint(x: 202, y: 172),
          CGPoint(x: 160, y: 215),
        ].enumerated() {
          var tomato = c
          tomato.translateBy(x: point.x, y: point.y)
          tomato.rotate(by: .degrees(Double(index) * 53))
          tomato.fill(
            Path(ellipseIn: CGRect(x: -19, y: -14, width: 38, height: 28)),
            with: .color(Color(red: 0.58, green: 0.12, blue: 0.07)))
          tomato.fill(
            Path(ellipseIn: CGRect(x: -17, y: -14, width: 33, height: 24)),
            with: .color(Color(red: 0.94, green: 0.29, blue: 0.12)))
          tomato.stroke(
            Path(ellipseIn: CGRect(x: -12, y: -10, width: 24, height: 17)),
            with: .color(Color.orange.opacity(0.7)), lineWidth: 2)
          for seed in 0..<5 {
            tomato.fill(
              Path(
                ellipseIn: CGRect(
                  x: Double(seed) * 4 - 9, y: sin(Double(seed)) * 4 - 2, width: 2, height: 3)),
              with: .color(.yellow.opacity(0.8)))
          }
        }
      }
      if style == 2 {
        for i in 0..<9 {
          var mushroom = c
          mushroom.translateBy(x: 98 + Double(i % 3) * 49, y: 94 + Double(i / 3) * 49)
          mushroom.rotate(by: .degrees(Double(i) * 32))
          mushroom.fill(
            Path(roundedRect: CGRect(x: -5, y: 0, width: 12, height: 22), cornerRadius: 4),
            with: .color(Color(red: 0.77, green: 0.61, blue: 0.45)))
          mushroom.fill(
            Path(ellipseIn: CGRect(x: -20, y: -13, width: 40, height: 26)),
            with: .color(Color(red: 0.34, green: 0.22, blue: 0.18)))
          mushroom.stroke(
            Path(ellipseIn: CGRect(x: -15, y: -9, width: 30, height: 18)),
            with: .color(Color(red: 0.55, green: 0.40, blue: 0.29)), lineWidth: 3)
        }
      }
      if [3, 5, 7, 8].contains(style) {
        for i in 0..<(style == 5 ? 1 : 5) {
          var piece = c
          piece.translateBy(x: 116 + Double(i % 3) * 34, y: 117 + Double(i / 3) * 54)
          piece.rotate(by: .degrees(-25 + Double(i) * 17))
          let color =
            style == 5
            ? Color(red: 0.93, green: 0.48, blue: 0.32)
            : (style == 7
              ? Color(red: 0.80, green: 0.55, blue: 0.27)
              : Color(red: 0.89, green: 0.40, blue: 0.10))
          let width: Double = style == 5 ? 82 : 27
          piece.fill(
            Path(roundedRect: CGRect(x: -12, y: -30, width: width, height: 78), cornerRadius: 9),
            with: .color(color))
          for j in 0..<5 {
            var line = Path()
            line.move(to: CGPoint(x: -7, y: Double(j) * 12 - 20))
            line.addLine(to: CGPoint(x: width - 17, y: Double(j) * 12 - 14))
            piece.stroke(line, with: .color(.white.opacity(style == 5 ? 0.45 : 0.15)), lineWidth: 2)
          }
        }
      }
      if style == 9 {
        for point in [CGPoint(x: 112, y: 133), CGPoint(x: 188, y: 175)] {
          c.fill(
            Path(ellipseIn: CGRect(x: point.x - 34, y: point.y - 28, width: 68, height: 56)),
            with: .color(Palette.paper))
          c.fill(
            Path(ellipseIn: CGRect(x: point.x - 14, y: point.y - 15, width: 29, height: 29)),
            with: .color(Color(red: 0.99, green: 0.64, blue: 0.08)))
        }
      }
      for i in 0..<11 {
        var leaf = c
        let angle = Double(i) * 2.4
        leaf.translateBy(x: 150 + cos(angle) * (i % 2 == 0 ? 70 : 39), y: 148 + sin(angle) * 70)
        leaf.rotate(by: .radians(angle))
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: 25, y: 0), control: CGPoint(x: 14, y: -18))
        path.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: 13, y: 14))
        leaf.fill(
          path, with: .color(i % 2 == 0 ? Palette.green : Color(red: 0.34, green: 0.49, blue: 0.25))
        )
        var vein = Path()
        vein.move(to: .zero)
        vein.addLine(to: CGPoint(x: 21, y: -1))
        leaf.stroke(vein, with: .color(.white.opacity(0.3)), lineWidth: 0.7)
      }
      for i in 0..<50 {
        let a = Double(i) * 2.4
        let r = sqrt(Double(i) / 50) * 90
        c.fill(
          Path(
            ellipseIn: CGRect(x: 150 + cos(a) * r, y: 150 + sin(a) * r, width: 1.5, height: 1.5)),
          with: .color(Palette.ink.opacity(0.4)))
      }
    }
    .accessibilityHidden(true)
  }
}
