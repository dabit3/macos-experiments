import SwiftUI

struct GalleryBackground: View {
  var body: some View {
    ZStack {
      Earth.night
      RadialGradient(
        colors: [Color(hex: 0x2E5048), Earth.night.opacity(0)],
        center: UnitPoint(x: 0.38, y: 0.46), startRadius: 10, endRadius: 420)
      Canvas { context, size in
        for mark in 0..<1500 {
          let x = CGFloat((mark * 127 + 31) % 997) / 997 * size.width
          let y = CGFloat((mark * 233 + 71) % 991) / 991 * size.height
          context.fill(
            Path(ellipseIn: CGRect(x: x, y: y, width: 0.7, height: 0.7)),
            with: .color(Earth.paper.opacity(mark % 3 == 0 ? 0.07 : 0.025)))
        }
      }
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

struct ContourEmblem: View {
  var body: some View {
    Canvas { context, size in
      let unit = min(size.width, size.height)
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      for ring in 0..<4 {
        var path = Path()
        for step in 0...80 {
          let angle = Double(step) / 80 * .pi * 2
          let radius = Double(0.45 - CGFloat(ring) * 0.087)
          let ripple = 1 + sin(angle * 3 + 1) * 0.12
          let point = CGPoint(
            x: center.x + cos(angle) * unit * radius * ripple,
            y: center.y + sin(angle) * unit * radius * 0.77 * ripple)
          if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        context.stroke(path, with: .color(Earth.brass), lineWidth: unit * 0.018)
      }
    }
    .accessibilityHidden(true)
  }
}

struct Medal: View {
  let filled: Bool

  var body: some View {
    ZStack {
      Circle().fill(
        LinearGradient(
          colors: filled
            ? [Color(hex: 0xECCD91), Earth.brass, Color(hex: 0x9E7844)]
            : [Earth.surface, Earth.surface],
          startPoint: .topLeading, endPoint: .bottomTrailing))
      Circle().strokeBorder(
        filled ? Earth.paper.opacity(0.55) : Earth.paper.opacity(0.16), lineWidth: 1
      )
      .padding(4)
      Image(systemName: "sparkle")
        .font(.system(size: 21, weight: .light))
        .foregroundStyle(filled ? Earth.ink : Earth.muted)
    }
    .frame(width: 47, height: 47)
    .shadow(color: .black.opacity(0.18), radius: 6, y: 4)
    .accessibilityHidden(true)
  }
}

struct PressedArtifact: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .brightness(configuration.isPressed ? -0.06 : 0)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
  }
}

struct InstrumentSurface: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(
        LinearGradient(
          colors: [Color(hex: 0x30463F), Color(hex: 0x1D302B)],
          startPoint: .topLeading, endPoint: .bottomTrailing),
        in: RoundedRectangle(cornerRadius: 22)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 22)
          .strokeBorder(
            LinearGradient(
              colors: [Earth.paper.opacity(0.22), Earth.paper.opacity(0.035)],
              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.18), radius: 18, y: 9)
  }
}
