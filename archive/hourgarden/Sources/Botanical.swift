import SwiftUI

enum Palette {
  static let paper = Color(red: 0.965, green: 0.950, blue: 0.908)
  static let ink = Color(red: 0.17, green: 0.22, blue: 0.18)
  static let sage = Color(red: 0.37, green: 0.45, blue: 0.33)
  static let muted = Color(red: 0.33, green: 0.37, blue: 0.31)
  static let line = Color(red: 0.80, green: 0.81, blue: 0.74)
  static let apricot = Color(red: 0.96, green: 0.81, blue: 0.65)
}

struct Botanical: View {
  var species = 0
  var growth: Double = 1

  var body: some View {
    Canvas { context, size in
      let sx = size.width / 300
      let sy = size.height / 380
      func point(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: x * sx, y: y * sy)
      }
      var stem = Path()
      stem.move(to: point(150, 365))
      stem.addCurve(to: point(157, 37), control1: point(119, 245), control2: point(181, 159))
      context.stroke(stem, with: .color(Palette.ink.opacity(0.7)), lineWidth: 1.5 * sx)

      let leaves: [(Double, Double, Double, Double)] = [
        (148, 323, 76, 272), (147, 301, 213, 254),
        (149, 274, 66, 218), (151, 249, 233, 196),
        (155, 225, 86, 166), (159, 198, 222, 134),
        (161, 173, 107, 115), (162, 148, 215, 88),
        (162, 119, 120, 71), (160, 91, 186, 47),
        (158, 69, 143, 26),
      ]
      for (index, leaf) in leaves.enumerated() {
        let (x, y, endX, endY) = leaf
        let visible = max(0.12, min(1, growth * 1.6 - Double(index) * 0.055))
        let dx = (endX - x) * visible
        let dy = (endY - y) * visible
        let length = hypot(dx, dy)
        let width = length * (species == 1 ? 0.40 : 0.22)
        let normalX = -dy / max(1, length) * width
        let normalY = dx / max(1, length) * width
        var shape = Path()
        shape.move(to: point(x, y))
        shape.addCurve(
          to: point(x + dx, y + dy),
          control1: point(x + dx * 0.28 + normalX, y + dy * 0.28 + normalY),
          control2: point(x + dx * 0.78 + normalX, y + dy * 0.78 + normalY))
        shape.addCurve(
          to: point(x, y),
          control1: point(x + dx * 0.78 - normalX, y + dy * 0.78 - normalY),
          control2: point(x + dx * 0.28 - normalX, y + dy * 0.28 - normalY))
        context.fill(
          shape,
          with: .linearGradient(
            Gradient(colors: [Palette.sage.opacity(0.76), Palette.sage.opacity(0.24)]),
            startPoint: point(x, y), endPoint: point(x + dx, y + dy)))
        context.stroke(shape, with: .color(Palette.sage.opacity(0.8)), lineWidth: 0.8 * sx)
        var vein = Path()
        vein.move(to: point(x, y))
        vein.addQuadCurve(
          to: point(x + dx * 0.9, y + dy * 0.9),
          control: point(x + dx * 0.45, y + dy * 0.45))
        context.stroke(vein, with: .color(Palette.paper.opacity(0.65)), lineWidth: 0.8 * sx)
      }
      if species == 2 {
        for (x, y, scale) in [(157.0, 38.0, 1.0), (222.0, 132.0, 0.7), (84.0, 162.0, 0.6)] {
          for petal in 0..<8 {
            let angle = Double(petal) * .pi / 4
            let cx = x + cos(angle) * 17 * scale
            let cy = y + sin(angle) * 17 * scale
            let rect = CGRect(
              x: (cx - 10 * scale) * sx, y: (cy - 14 * scale) * sy,
              width: 20 * scale * sx, height: 28 * scale * sy)
            context.fill(Path(ellipseIn: rect), with: .color(Palette.apricot.opacity(0.88)))
          }
          context.fill(
            Path(
              ellipseIn: CGRect(x: (x - 8) * sx, y: (y - 8) * sy, width: 16 * sx, height: 16 * sy)),
            with: .color(Palette.ink))
        }
      }
      var ground = Path()
      ground.move(to: point(111, 367))
      ground.addQuadCurve(to: point(195, 367), control: point(153, 361))
      context.stroke(ground, with: .color(Palette.sage.opacity(0.35)), lineWidth: sx)
    }
    .accessibilityHidden(true)
  }
}

struct Paper: ViewModifier {
  func body(content: Content) -> some View {
    content
      .foregroundStyle(Palette.ink)
      .background(Palette.paper.ignoresSafeArea())
      .preferredColorScheme(.light)
  }
}

struct Eyebrow: View {
  var text: String
  var body: some View {
    Text(text.uppercased())
      .font(.system(.caption2, design: .monospaced).weight(.medium))
      .tracking(2)
      .foregroundStyle(Palette.muted)
  }
}

struct EditorialHeading: ViewModifier {
  @ScaledMetric private var size: CGFloat

  init(size: CGFloat) {
    _size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
  }

  func body(content: Content) -> some View {
    content
      .font(.system(size: size, design: .serif))
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader)
  }
}

struct PrimaryButton: View {
  @Environment(\.dynamicTypeSize) private var textSize
  var title: String
  var icon = "arrow.right"
  var action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack {
        Text(title).font(.system(.body, design: .rounded).weight(.medium))
          .fixedSize(horizontal: false, vertical: true)
        Spacer()
        if !textSize.isAccessibilitySize {
          Image(systemName: icon).accessibilityHidden(true)
        }
      }
      .padding(.horizontal, 22)
      .padding(.vertical, 19)
      .foregroundStyle(Palette.paper)
      .background(Palette.ink, in: RoundedRectangle(cornerRadius: 18))
    }
    .buttonStyle(.plain)
  }
}
