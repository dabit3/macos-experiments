import SwiftUI

enum Gallery {
  static let paper = Color(red: 0.96, green: 0.95, blue: 0.92)
  static let ink = Color(red: 0.17, green: 0.21, blue: 0.22)
  static let muted = Color(red: 0.39, green: 0.42, blue: 0.41)
  static let line = Color(red: 0.80, green: 0.81, blue: 0.77)
  static let accent = Color(red: 0.65, green: 0.25, blue: 0.14)
  static let colors: [Color] = [
    Color(red: 0.84, green: 0.30, blue: 0.20),
    Color(red: 0.22, green: 0.35, blue: 0.71),
    Color(red: 0.90, green: 0.64, blue: 0.17),
    Color(red: 0.17, green: 0.49, blue: 0.43),
    Color(red: 0.51, green: 0.29, blue: 0.49),
  ]
  static let names = ["Vermilion", "Cobalt", "Ochre", "Jade", "Mulberry"]
  static let symbols = ["circle.fill", "diamond.fill", "triangle.fill", "square.fill", "star.fill"]
}

struct GalleryBackground: View {
  var body: some View {
    ZStack {
      Gallery.paper
      RadialGradient(
        colors: [.white.opacity(0.8), .clear],
        center: .topLeading, startRadius: 10, endRadius: 700)
      Canvas { context, size in
        for row in stride(from: 0, to: Int(size.height), by: 7) {
          for col in stride(from: 0, to: Int(size.width), by: 7) {
            let opacity = Double((row * 17 + col * 13) % 9) / 700
            context.fill(
              Path(ellipseIn: CGRect(x: col, y: row, width: 1, height: 1)),
              with: .color(.black.opacity(opacity)))
          }
        }
      }
      .accessibilityHidden(true)
    }
    .ignoresSafeArea()
  }
}

struct Eyebrow: View {
  let text: String
  var body: some View {
    Text(text.uppercased())
      .font(.system(.caption2, design: .monospaced, weight: .medium))
      .tracking(2.2)
      .foregroundStyle(Gallery.muted)
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
  }
}

struct PrimaryButton: View {
  let title: String
  var icon = "arrow.right"
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        Text(title).font(.system(.body, design: .rounded, weight: .medium))
        Spacer()
        Image(systemName: icon)
      }
      .padding(.horizontal, 22)
      .padding(.vertical, 20)
      .foregroundStyle(Gallery.paper)
      .background(Gallery.ink, in: RoundedRectangle(cornerRadius: 18))
    }
    .buttonStyle(.plain)
  }
}

struct CircleControl: View {
  let icon: String
  let label: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: 18, weight: .regular))
        .frame(width: 48, height: 48)
        .background(.white.opacity(0.5), in: Circle())
        .overlay(Circle().strokeBorder(Gallery.line.opacity(0.7), lineWidth: 1))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

struct GlassSilhouette: Shape {
  func path(in rect: CGRect) -> Path {
    Path(roundedRect: rect, cornerSize: CGSize(width: rect.width * 0.23, height: rect.width * 0.23))
  }
}

struct Vessel: View {
  let colors: [Int]
  var symbols = false
  var selected = false
  var height: CGFloat = 154
  var capacityMarks = false

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let innerWidth = width - 14
      let unit = (height - 30) / 4
      ZStack(alignment: .bottom) {
        Ellipse()
          .fill(Gallery.ink.opacity(0.17))
          .frame(width: width + 14, height: 16)
          .blur(radius: 9)
          .offset(x: 8, y: 11)
        GlassSilhouette()
          .fill(
            LinearGradient(
              colors: [.white.opacity(0.55), Gallery.ink.opacity(0.05), .white.opacity(0.6)],
              startPoint: .leading, endPoint: .trailing))
        ZStack(alignment: .bottom) {
          ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
            Rectangle()
              .fill(
                LinearGradient(
                  colors: [
                    Gallery.colors[color].opacity(0.83),
                    Gallery.colors[color],
                    Gallery.colors[color].opacity(0.78),
                  ],
                  startPoint: .leading, endPoint: .trailing)
              )
              .frame(height: unit + 1)
              .overlay(alignment: .top) {
                Rectangle().fill(.white.opacity(0.18)).frame(height: 1)
              }
              .overlay {
                if symbols {
                  Image(systemName: Gallery.symbols[color])
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                }
              }
              .offset(y: -CGFloat(index) * unit)
          }
        }
        .frame(width: innerWidth, height: height - 15, alignment: .bottom)
        .clipShape(GlassSilhouette())
        .padding(.bottom, 7)
        if !colors.isEmpty {
          Ellipse()
            .fill(Gallery.colors[colors.last ?? 0].opacity(0.7))
            .overlay(Ellipse().strokeBorder(.white.opacity(0.3), lineWidth: 1))
            .frame(width: innerWidth, height: 9)
            .offset(y: -CGFloat(colors.count) * unit + 2)
        }
        GlassSilhouette()
          .stroke(
            LinearGradient(
              colors: [.white, Gallery.ink.opacity(0.16), .white.opacity(0.9)],
              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
        Capsule()
          .fill(.white.opacity(0.48))
          .frame(width: 3, height: height * 0.70)
          .offset(x: -width * 0.32, y: -height * 0.15)
        if capacityMarks {
          ForEach(1...4, id: \.self) { slot in
            Capsule()
              .fill(Gallery.ink.opacity(0.38))
              .frame(width: 7, height: 1)
              .offset(x: width / 2 - 3, y: -CGFloat(slot) * unit - 5)
          }
        }
        Ellipse()
          .strokeBorder(Gallery.ink.opacity(0.18), lineWidth: 1)
          .background(Ellipse().fill(.white.opacity(0.2)))
          .frame(height: 10)
          .offset(y: -height + 7)
      }
      .frame(height: height)
      .overlay {
        if selected {
          GlassSilhouette().stroke(Gallery.accent, lineWidth: 2).padding(-5)
        }
      }
    }
    .frame(height: height)
    .accessibilityHidden(true)
  }
}

struct GallerySculpture: View {
  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      ZStack {
        Ellipse()
          .fill(.white.opacity(0.5))
          .frame(width: width * 0.85, height: 220)
          .blur(radius: 25)
        RoundedRectangle(cornerRadius: 6)
          .fill(
            LinearGradient(
              colors: [.white, Color(red: 0.84, green: 0.84, blue: 0.79)],
              startPoint: .top, endPoint: .bottom)
          )
          .frame(width: width * 0.89, height: 34)
          .rotationEffect(.degrees(-5))
          .shadow(color: Gallery.ink.opacity(0.10), radius: 16, x: 7, y: 19)
          .offset(y: 98)
        Vessel(colors: [2, 2, 0, 0], height: 183)
          .frame(width: 82)
          .rotationEffect(.degrees(-7))
          .offset(x: -width * 0.28, y: 1)
        Vessel(colors: [1, 1, 1, 1], height: 219)
          .frame(width: 90)
          .offset(y: -18)
        Vessel(colors: [3, 3, 2], height: 163)
          .frame(width: 80)
          .rotationEffect(.degrees(8))
          .offset(x: width * 0.28, y: 15)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(height: 300)
    .accessibilityLabel("A sculpture of glass vessels holding cobalt, vermilion, ochre and jade.")
  }
}
