import SwiftUI

let ink = Color(red: 0.06, green: 0.08, blue: 0.22)
let sunshine = Color(red: 1, green: 0.84, blue: 0.16)
let cherry = Color(red: 1, green: 0.25, blue: 0.36)
let skyBlue = Color(red: 0.12, green: 0.55, blue: 1)
let mintGlow = Color(red: 0.25, green: 0.93, blue: 0.74)
let cloud = Color(red: 0.95, green: 0.97, blue: 1)

func display(_ size: CGFloat) -> Font {
  .system(size: size, weight: .black, design: .rounded).italic()
}
func label(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }

func ordinal(_ rank: Int) -> (String, String) {
  (String(rank), rank == 1 ? "st" : rank == 2 ? "nd" : rank == 3 ? "rd" : "th")
}

struct OutlinedText: View {
  let text: String
  var size: CGFloat = 36
  var color: Color = .white
  var fill: [Color]? = nil
  var stroke: CGFloat = 2
  var body: some View {
    let base = Text(text).font(display(size))
    return ZStack {
      ForEach(0..<8, id: \.self) { i in
        let a = Double(i) * .pi / 4
        base.foregroundStyle(ink).offset(x: cos(a) * stroke, y: sin(a) * stroke)
      }
      base.foregroundStyle(ink).offset(y: stroke + size * 0.07)
      if let fill {
        base.foregroundStyle(LinearGradient(colors: fill, startPoint: .top, endPoint: .bottom))
      } else {
        base.foregroundStyle(color)
      }
    }.fixedSize()
  }
}

struct ChunkyButtonStyle: ButtonStyle {
  var tint: Color = sunshine
  var foreground: Color = ink
  var height: CGFloat = 50
  func makeBody(configuration: Configuration) -> some View {
    let pressed = configuration.isPressed
    return configuration.label
      .font(display(height * 0.36)).foregroundStyle(foreground)
      .frame(maxWidth: .infinity, minHeight: height)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: height * 0.34).fill(ink).offset(y: pressed ? 1 : 5)
          RoundedRectangle(cornerRadius: height * 0.34).fill(
            LinearGradient(
              colors: [tint.opacity(0.85), tint], startPoint: .top, endPoint: .bottom))
          RoundedRectangle(cornerRadius: height * 0.34).strokeBorder(ink, lineWidth: 3)
          Capsule().fill(.white.opacity(0.4)).frame(height: 5).padding(.horizontal, 18)
            .frame(maxHeight: .infinity, alignment: .top).padding(.top, 5)
        }
      )
      .offset(y: pressed ? 4 : 0)
      .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
  }
}

struct ArcadeButton: View {
  let title: String
  var tint: Color = sunshine
  var height: CGFloat = 50
  var icon: String? = nil
  let action: () -> Void

  init(
    _ title: String, tint: Color = sunshine, height: CGFloat = 50, icon: String? = nil,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.tint = tint
    self.height = height
    self.icon = icon
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Text(title).lineLimit(1).minimumScaleFactor(0.6)
        if let icon { Image(systemName: icon).font(.system(size: height * 0.32, weight: .black)) }
      }.padding(.horizontal, 14)
    }.buttonStyle(ChunkyButtonStyle(tint: tint, height: height))
  }
}

struct CardBackground: View {
  var fill: Color = cloud
  var radius: CGFloat = 22
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: radius).fill(ink).offset(y: 6)
      RoundedRectangle(cornerRadius: radius).fill(fill)
      RoundedRectangle(cornerRadius: radius).strokeBorder(ink, lineWidth: 3)
    }
  }
}

struct Ribbon: View {
  let text: String
  var tint: Color = skyBlue
  var body: some View {
    Text(text).font(display(13)).foregroundStyle(.white).tracking(0.5)
      .padding(.horizontal, 16).padding(.vertical, 6)
      .background(
        Parallelogram().fill(tint).overlay(Parallelogram().stroke(ink, lineWidth: 2.5)))
  }
}

struct Parallelogram: Shape {
  func path(in rect: CGRect) -> Path {
    let skew = rect.height * 0.3
    var path = Path()
    path.move(to: CGPoint(x: rect.minX + skew, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - skew, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}

struct StatBar: View {
  let name: String
  let value: Double
  let tint: Color
  var body: some View {
    HStack(spacing: 8) {
      Text(name).font(label(9)).foregroundStyle(.white).frame(width: 62, alignment: .leading)
      HStack(spacing: 3) {
        ForEach(0..<6, id: \.self) { i in
          Parallelogram().fill(Double(i) < value ? tint : .white.opacity(0.18))
            .overlay(Parallelogram().stroke(ink.opacity(0.8), lineWidth: 1.5))
            .frame(width: 16, height: 10)
        }
      }
    }
  }
}

struct Logo: View {
  var size: CGFloat = 26
  var body: some View {
    HStack(spacing: 8) {
      ZStack {
        Circle().fill(ink).frame(width: size * 1.55, height: size * 1.55).offset(y: 3)
        Circle().fill(
          LinearGradient(colors: [sunshine, .orange], startPoint: .top, endPoint: .bottom)
        )
        .frame(width: size * 1.55, height: size * 1.55).overlay(Circle().stroke(ink, lineWidth: 3))
        Image(systemName: "star.fill").font(.system(size: size * 0.85, weight: .black))
          .foregroundStyle(.white).shadow(color: ink, radius: 0, x: 1.5, y: 1.5)
      }
      VStack(alignment: .leading, spacing: -4) {
        OutlinedText(text: "STARCAP", size: size, fill: [.white, cloud])
        OutlinedText(text: "CIRCUIT", size: size * 0.5, fill: [sunshine, .orange], stroke: 1.5)
      }
    }
  }
}
