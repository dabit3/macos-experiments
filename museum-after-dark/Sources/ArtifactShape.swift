import SwiftUI

struct ArtifactShape: Shape {
  let id: Int

  static func color(_ id: Int) -> Color {
    [
      Palette.ruby, Palette.muted, Palette.gold, Palette.gold, Palette.paper, Palette.paper,
      Palette.gold, Palette.ruby, Color(red: 0.35, green: 0.65, blue: 0.95), Palette.paper,
    ][max(0, min(9, id - 1))]
  }

  func path(in rect: CGRect) -> Path {
    var p = Path()
    func polygon(_ points: [CGPoint]) -> Path {
      Path { path in
        path.addLines(points)
        path.closeSubpath()
      }
    }
    switch id {
    case 2:
      p = polygon([
        CGPoint(x: 0.1, y: 0.9), CGPoint(x: 0.18, y: 0.2), CGPoint(x: 0.54, y: 0.5),
        CGPoint(x: 0.74, y: 0.05), CGPoint(x: 1, y: 0.2), CGPoint(x: 0.75, y: 0.27),
        CGPoint(x: 0.63, y: 0.8), CGPoint(x: 0.4, y: 1),
      ])
    case 3:
      p.addEllipse(in: CGRect(x: 0.05, y: 0.16, width: 0.9, height: 0.65))
      p.addEllipse(in: CGRect(x: 0.17, y: 0.25, width: 0.66, height: 0.47))
      p.addEllipse(in: CGRect(x: 0.38, y: 0.4, width: 0.24, height: 0.18))
      p.addRect(CGRect(x: 0.42, y: 0.8, width: 0.16, height: 0.2))
    case 4:
      p.move(to: CGPoint(x: 0.8, y: 0))
      p.addCurve(
        to: CGPoint(x: 0.8, y: 1), control1: CGPoint(x: -0.3, y: 0),
        control2: CGPoint(x: -0.3, y: 1))
      p.addCurve(
        to: CGPoint(x: 0.8, y: 0), control1: CGPoint(x: 0.12, y: 0.85),
        control2: CGPoint(x: 0.12, y: 0.15))
    case 5:
      p.addPath(Diamond().path(in: CGRect(x: 0.0, y: 0.15, width: 0.6, height: 0.8)))
      p.addPath(Diamond().path(in: CGRect(x: 0.4, y: 0.0, width: 0.6, height: 0.8)))
    case 6:
      p = polygon([
        CGPoint(x: 0.12, y: 1), CGPoint(x: 0.3, y: 0.3), CGPoint(x: 0.25, y: 0.15),
        CGPoint(x: 0.5, y: 0), CGPoint(x: 0.75, y: 0.15), CGPoint(x: 0.7, y: 0.3),
        CGPoint(x: 0.88, y: 1),
      ])
    case 7:
      p.addEllipse(in: CGRect(x: 0, y: 0.15, width: 0.5, height: 0.7))
      p.addEllipse(in: CGRect(x: 0.5, y: 0.15, width: 0.5, height: 0.7))
    case 8:
      p.move(to: CGPoint(x: 0.1, y: 0.1))
      p.addCurve(
        to: CGPoint(x: 0.8, y: 0.9), control1: CGPoint(x: 1.9, y: 0.25),
        control2: CGPoint(x: -1, y: 0.65))
      p.addLine(to: CGPoint(x: 0.9, y: 0.7))
      p.addCurve(
        to: CGPoint(x: 0.2, y: 0), control1: CGPoint(x: -0.5, y: 0.55),
        control2: CGPoint(x: 1.8, y: 0.25))
      p.closeSubpath()
    case 9:
      p = polygon([
        CGPoint(x: 0.1, y: 0), CGPoint(x: 0.9, y: 0), CGPoint(x: 0.58, y: 0.5),
        CGPoint(x: 0.9, y: 1), CGPoint(x: 0.1, y: 1), CGPoint(x: 0.42, y: 0.5),
      ])
    case 10:
      p.addLines(
        (0..<16).map { index in
          let angle = Double(index) * .pi / 8 - .pi / 2
          let radius = index.isMultiple(of: 2) ? 0.5 : 0.22
          return CGPoint(x: 0.5 + cos(angle) * radius, y: 0.5 + sin(angle) * radius)
        })
      p.closeSubpath()
    default:
      p = Diamond().path(in: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    return p.applying(
      CGAffineTransform(scaleX: rect.width, y: rect.height).concatenating(
        CGAffineTransform(translationX: rect.minX, y: rect.minY)))
  }
}

struct AcquisitionParticles: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var expanded = false
  var body: some View {
    ZStack {
      ForEach(0..<18) { index in
        let angle = Double(index) * .pi / 9
        Circle().fill(Palette.gold.opacity(expanded ? 0 : 0.85))
          .frame(width: index.isMultiple(of: 3) ? 3 : 1.5)
          .offset(x: cos(angle) * (expanded ? 155 : 35), y: sin(angle) * (expanded ? 155 : 35))
      }
    }
    .onAppear {
      if !reduceMotion { withAnimation(.easeOut(duration: 1.7)) { expanded = true } }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
