import SwiftUI

enum Palette {
  static let ink = Color(red: 0.025, green: 0.063, blue: 0.073)
  static let panel = Color(red: 0.055, green: 0.13, blue: 0.14)
  static let cream = Color(red: 0.96, green: 0.91, blue: 0.81)
  static let orange = Color(red: 0.91, green: 0.7, blue: 0.43)
  static let mint = Color(red: 0.65, green: 0.84, blue: 0.74)
  static let muted = Color(red: 0.62, green: 0.71, blue: 0.69)
  static let rule = orange.opacity(0.25)
  static let gold = LinearGradient(
    colors: [
      Color(red: 0.98, green: 0.82, blue: 0.57), orange, Color(red: 0.72, green: 0.47, blue: 0.25),
    ],
    startPoint: .topLeading, endPoint: .bottomTrailing)
}

enum Lettering {
  static func display(_ size: CGFloat) -> Font { .custom("Baskerville", size: size) }
  static func italic(_ size: CGFloat) -> Font { .custom("Baskerville-Italic", size: size) }
  static func label(_ size: CGFloat) -> Font { .custom("AvenirNext-DemiBold", size: size) }
}

struct MoonSeal: View {
  var size: CGFloat = 38
  var body: some View {
    ZStack {
      Circle().stroke(Palette.orange.opacity(0.5), lineWidth: 0.7)
      Circle().stroke(Palette.orange.opacity(0.25), lineWidth: 0.5).padding(4)
      Image(systemName: "moon.stars.fill")
        .font(.system(size: size * 0.38, weight: .light))
        .foregroundStyle(Palette.gold)
        .rotationEffect(.degrees(-15))
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

struct FineRule: View {
  var body: some View {
    HStack(spacing: 9) {
      Rectangle().fill(Palette.rule).frame(height: 0.5)
      Rectangle().fill(Palette.orange).frame(width: 4, height: 4).rotationEffect(.degrees(45))
      Rectangle().fill(Palette.rule).frame(height: 0.5)
    }
    .accessibilityHidden(true)
  }
}

struct ProduceArt: View {
  let kind: Int
  var body: some View {
    Image(["Moonpear", "Starcap", "Cometroot"][kind])
      .resizable()
      .scaledToFit()
      .mask {
        RoundedRectangle(cornerRadius: 16)
          .fill(.white)
          .overlay {
            RoundedRectangle(cornerRadius: 16)
              .stroke(.black, lineWidth: 9).blur(radius: 5).blendMode(.destinationOut)
          }
          .compositingGroup()
      }
      .accessibilityHidden(true)
  }
}

struct BazaarScene: View {
  var flourishing = false
  var celebrating = false
  var fitted = false
  @Environment(\.accessibilityReduceMotion) private var reducedMotion
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Image(flourishing ? "BazaarThriving" : "Bazaar")
          .resizable()
          .aspectRatio(contentMode: fitted ? .fit : .fill)
          .frame(width: geometry.size.width, height: geometry.size.height)
          .clipped()
        TimelineView(
          .animation(minimumInterval: 1.0 / 24, paused: reducedMotion || scenePhase != .active)
        ) { timeline in
          let time = reducedMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
          Canvas { context, size in
            for index in 0..<(celebrating ? 34 : 12) {
              let phase = (time * (celebrating ? 0.16 : 0.045) + Double(index) * 0.137)
                .truncatingRemainder(dividingBy: 1)
              let x = size.width * Double((index * 43 + 17) % 100) / 100
              let y = size.height * (0.9 - phase * 0.8)
              let radius = celebrating ? 1.5 : 0.8
              let opacity = sin(phase * .pi) * (celebrating ? 0.8 : 0.45)
              let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
              context.fill(
                Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)),
                with: .color(Palette.orange.opacity(opacity * 0.09)))
              context.fill(Path(ellipseIn: rect), with: .color(Palette.orange.opacity(opacity)))
            }
          }
        }
      }
      .mask {
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0),
            .init(color: .white, location: 0.13),
            .init(color: .white, location: 0.81),
            .init(color: .clear, location: 1),
          ], startPoint: .top, endPoint: .bottom)
      }
    }
    .accessibilityHidden(true)
  }
}

struct OrbitTrack: View {
  let night: Int
  var body: some View {
    HStack(spacing: 5) {
      ForEach(1...8, id: \.self) { index in
        Capsule()
          .fill(index <= night ? Palette.orange : Palette.cream.opacity(0.1))
          .frame(height: index == night ? 3 : 2)
      }
    }
    .accessibilityLabel("Night \(night) of 8")
  }
}

struct PaperGrain: View {
  var body: some View {
    Canvas { context, size in
      for index in 0..<900 {
        let x = Double((index * 73 + 19) % 997) / 997 * size.width
        let y = Double((index * 113 + 41) % 991) / 991 * size.height
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: y, width: 0.7, height: 0.7)),
          with: .color(Palette.ink.opacity(0.08)))
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
