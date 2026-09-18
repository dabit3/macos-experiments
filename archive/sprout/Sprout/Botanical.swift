import SwiftUI

enum Palette {
  static let cream = Color(red: 0.97, green: 0.955, blue: 0.92)
  static let forest = Color(red: 0.12, green: 0.25, blue: 0.20)
  static let muted = Color(red: 0.37, green: 0.43, blue: 0.35)
  static let terracotta = Color(red: 0.66, green: 0.30, blue: 0.20)
  static let line = Color(red: 0.83, green: 0.83, blue: 0.76)
  static let sage = Color(red: 0.88, green: 0.91, blue: 0.83)
}

struct Botanical: View {
  var kind: PlantKind
  var body: some View {
    Canvas { context, size in
      let sx = size.width / 240
      let sy = size.height / 280
      context.scaleBy(x: sx, y: sy)
      context.fill(
        Path(ellipseIn: CGRect(x: 57, y: 258, width: 130, height: 13)),
        with: .color(Palette.forest.opacity(0.09)))
      let count = kind == .fern ? 15 : kind == .snake ? 9 : 10
      for i in 0..<count {
        let progress = Double(i) / Double(count - 1)
        let side = i.isMultiple(of: 2) ? -1.0 : 1.0
        let x = 120 + side * (22 + 52 * sin(progress * .pi))
        let y = 22 + progress * 147
        var stem = Path()
        stem.move(to: CGPoint(x: 120, y: 215))
        stem.addQuadCurve(
          to: CGPoint(x: x, y: y + 15), control: CGPoint(x: 120 + side * 8, y: y + 50))
        context.stroke(stem, with: .color(Palette.forest.opacity(0.8)), lineWidth: 2)
        if kind == .snake {
          var leaf = Path()
          leaf.move(to: CGPoint(x: 117, y: 220))
          leaf.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 21, y: y + 53))
          leaf.addQuadCurve(to: CGPoint(x: 126, y: 220), control: CGPoint(x: x + 21, y: y + 45))
          context.fill(
            leaf,
            with: .linearGradient(
              Gradient(colors: [Color(red: 0.45, green: 0.55, blue: 0.29), Palette.forest]),
              startPoint: CGPoint(x: x - 10, y: y), endPoint: CGPoint(x: x + 14, y: y)))
        } else if kind == .fern {
          for j in 0..<8 {
            let t = Double(j) / 8
            let px = 120 + (x - 120) * t
            let py = 213 + (y - 213) * t
            drawLeaf(
              context: context, center: CGPoint(x: px, y: py), length: 23 - t * 8, width: 7,
              angle: side * (0.6 + t), shade: i + j)
          }
        } else {
          drawLeaf(
            context: context, center: CGPoint(x: x, y: y + 15),
            length: kind == .monstera ? 42 : 35, width: kind == .monstera ? 29 : 19,
            angle: side * (0.55 + progress * 0.7), shade: i)
        }
      }
      var pot = Path()
      pot.move(to: CGPoint(x: 76, y: 208))
      pot.addLine(to: CGPoint(x: 164, y: 208))
      pot.addLine(to: CGPoint(x: 151, y: 260))
      pot.addQuadCurve(to: CGPoint(x: 89, y: 260), control: CGPoint(x: 120, y: 273))
      pot.closeSubpath()
      context.fill(
        pot,
        with: .linearGradient(
          Gradient(colors: [
            Color(red: 0.83, green: 0.49, blue: 0.32), Palette.terracotta,
          ]), startPoint: CGPoint(x: 78, y: 208), endPoint: CGPoint(x: 163, y: 251)))
      context.fill(
        Path(roundedRect: CGRect(x: 71, y: 201, width: 98, height: 14), cornerRadius: 4),
        with: .color(Color(red: 0.76, green: 0.39, blue: 0.26)))
      context.fill(
        Path(ellipseIn: CGRect(x: 76, y: 199, width: 88, height: 9)),
        with: .color(Color(red: 0.26, green: 0.22, blue: 0.14)))
      for i in 0..<6 {
        var line = Path()
        line.move(to: CGPoint(x: 92 + i * 10, y: 222))
        line.addLine(to: CGPoint(x: 97 + i * 8, y: 251))
        context.stroke(line, with: .color(.white.opacity(0.11)), lineWidth: 1)
      }
    }
    .accessibilityHidden(true)
  }

  private func drawLeaf(
    context: GraphicsContext, center: CGPoint, length: Double, width: Double, angle: Double,
    shade: Int
  ) {
    var context = context
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: .radians(angle))
    var leaf = Path()
    leaf.move(to: CGPoint(x: 0, y: length / 2))
    leaf.addCurve(
      to: CGPoint(x: 0, y: -length), control1: CGPoint(x: -width * 1.6, y: 4),
      control2: CGPoint(x: -width, y: -length * 0.8))
    leaf.addCurve(
      to: CGPoint(x: 0, y: length / 2), control1: CGPoint(x: width, y: -length * 0.8),
      control2: CGPoint(x: width * 1.3, y: 5))
    let light = Color(
      red: 0.28 + Double(shade % 3) * 0.05, green: 0.46 + Double(shade % 3) * 0.035, blue: 0.26)
    context.fill(
      leaf,
      with: .linearGradient(
        Gradient(colors: [light, Palette.forest]), startPoint: CGPoint(x: -width, y: 0),
        endPoint: CGPoint(x: width, y: 0)))
    var vein = Path()
    vein.move(to: CGPoint(x: 0, y: length / 2))
    vein.addLine(to: CGPoint(x: 0, y: -length * 0.85))
    context.stroke(vein, with: .color(.white.opacity(0.23)), lineWidth: 0.8)
    if kind == .monstera {
      for i in 0..<3 {
        for side in [-1.0, 1.0] {
          var cut = Path()
          cut.move(to: CGPoint(x: side * 5, y: -Double(i) * 10))
          cut.addQuadCurve(
            to: CGPoint(x: side * width * 0.86, y: -Double(i) * 10 - 10),
            control: CGPoint(x: side * 17, y: -Double(i) * 10 - 2))
          context.stroke(
            cut, with: .color(Palette.cream.opacity(0.80)),
            style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
        }
      }
    }
  }
}

struct Eyebrow: View {
  var text: String
  @Environment(\.dynamicTypeSize) private var typeSize
  var body: some View {
    Text(text.uppercased()).font(.system(.caption2, design: .monospaced).weight(.medium))
      .tracking(typeSize.isAccessibilitySize ? 0 : 2).foregroundStyle(Palette.muted)
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct PrimaryButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.body.weight(.semibold)).frame(maxWidth: .infinity)
      .padding(.vertical, 17).foregroundStyle(Palette.cream)
      .background(
        Palette.forest.opacity(configuration.isPressed ? 0.8 : 1),
        in: RoundedRectangle(cornerRadius: 18))
  }
}

struct PlantPortrait: View {
  var plant: Plant
  var body: some View {
    Group {
      if let data = plant.photo, let image = UIImage(data: data) {
        Image(uiImage: image).resizable().scaledToFill()
          .clipShape(RoundedRectangle(cornerRadius: 28))
      } else {
        Botanical(kind: plant.kind)
      }
    }
    .accessibilityHidden(true)
  }
}
