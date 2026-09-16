import SwiftUI

enum Theme {
  static let green = Color(red: 0.463, green: 0.725, blue: 0)
  static let lime = Color(red: 0.68, green: 0.95, blue: 0.18)
  static let ink = Color(red: 0.043, green: 0.043, blue: 0.047)
  static let panel = Color(red: 0.078, green: 0.078, blue: 0.086)
  static let panel2 = Color(red: 0.11, green: 0.11, blue: 0.125)
  static let muted = Color(red: 0.52, green: 0.55, blue: 0.54)
  static let red = Color(red: 0.95, green: 0.27, blue: 0.24)
}

extension View {
  func neonGlow(_ radius: CGFloat = 8) -> some View {
    shadow(color: Theme.green.opacity(0.7), radius: radius)
      .shadow(color: Theme.green.opacity(0.25), radius: radius * 2)
  }
}

struct CircuitBackground: View {
  var body: some View {
    TimelineView(.animation(minimumInterval: 0.15)) { context in
      Canvas { canvas, size in
        let drift =
          context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 30) * 2
        canvas.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.ink))
        var path = Path()
        let step: CGFloat = 58
        for row in stride(from: -step, through: size.height + step, by: step) {
          for column in stride(from: -step, through: size.width + step, by: step) {
            let x = column + CGFloat(Int(row / step).isMultiple(of: 2) ? drift : -drift)
            path.move(to: CGPoint(x: x, y: row))
            path.addLine(to: CGPoint(x: x + 20, y: row))
            path.addLine(to: CGPoint(x: x + 34, y: row + 14))
            path.addLine(to: CGPoint(x: x + 34, y: row + 34))
          }
        }
        canvas.stroke(path, with: .color(Theme.green.opacity(0.09)), lineWidth: 1)
        for row in stride(from: 0, through: size.height, by: step) {
          for column in stride(from: 0, through: size.width, by: step) {
            let point = CGPoint(x: column + CGFloat(Int(row / step) % 3) * 12, y: row + 34)
            canvas.fill(
              Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)),
              with: .color(Theme.green.opacity(0.13)))
          }
        }
      }
    }
    .ignoresSafeArea()
  }
}

struct DieArt: View {
  var size: CGFloat
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.16).fill(Theme.panel2)
        .overlay(
          RoundedRectangle(cornerRadius: size * 0.16).stroke(Theme.green.opacity(0.8), lineWidth: 2)
        )
      RoundedRectangle(cornerRadius: size * 0.1).fill(
        RadialGradient(
          colors: [Theme.lime, Theme.green.opacity(0.55), .clear], center: .center, startRadius: 2,
          endRadius: size * 0.42)
      ).padding(size * 0.19).neonGlow(6)
      ForEach(0..<6, id: \.self) { index in
        Capsule().fill(Theme.green).frame(width: size * 0.06, height: size * 0.15)
          .offset(x: -size * 0.53, y: (CGFloat(index) - 2.5) * size * 0.14)
        Capsule().fill(Theme.green).frame(width: size * 0.06, height: size * 0.15)
          .offset(x: size * 0.53, y: (CGFloat(index) - 2.5) * size * 0.14)
      }
    }
    .frame(width: size, height: size)
  }
}

struct WaferArt: View {
  var body: some View {
    ZStack {
      Circle().fill(Theme.panel2).overlay(Circle().stroke(Theme.green.opacity(0.55), lineWidth: 2))
      Circle().stroke(Theme.green.opacity(0.25), lineWidth: 1).padding(11)
      ForEach(0..<4, id: \.self) { row in
        ForEach(0..<4, id: \.self) { column in
          RoundedRectangle(cornerRadius: 3).stroke(Theme.green.opacity(0.5), lineWidth: 1)
            .frame(width: 22, height: 22)
            .offset(x: CGFloat(column - 1) * 25, y: CGFloat(row - 1) * 25)
        }
      }
      Circle().trim(from: 0, to: 0.72).stroke(
        Theme.lime.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round)
      )
      .rotationEffect(.degrees(-50)).padding(5).neonGlow(8)
    }
    .frame(width: 184, height: 184)
  }
}
