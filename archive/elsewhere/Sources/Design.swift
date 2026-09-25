import SwiftUI
import UIKit

enum Ink {
  static let paper = Color(hex: 0xF6F1E6)
  static let pale = Color(hex: 0xEAE3D4)
  static let navy = Color(hex: 0x182E40)
  static let blue = Color(hex: 0x254DC7)
  static let red = Color(hex: 0xBB412D)
  static let muted = Color(hex: 0x6D726C)
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1)
  }
}

struct Eyebrow: View {
  @ScaledMetric(relativeTo: .caption) private var textSize = 12.0
  var text: String
  var color: Color = Ink.red
  var body: some View {
    Text(text.uppercased())
      .font(.system(size: min(textSize, 20), weight: .medium, design: .monospaced))
      .tracking(1.1).foregroundStyle(color)
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct Stamp: View {
  var text = "MEMORIES\nIN TRANSIT"
  var body: some View {
    ZStack {
      Circle().stroke(Ink.blue.opacity(0.75), lineWidth: 1.2)
      Circle().stroke(Ink.blue.opacity(0.5), lineWidth: 0.6).padding(5)
      VStack(spacing: 3) {
        Image(systemName: "globe.europe.africa").font(.system(size: 17, weight: .light))
        Text(text).font(.system(size: 8, weight: .bold, design: .monospaced))
          .multilineTextAlignment(.center).tracking(1)
      }
      .foregroundStyle(Ink.blue)
    }
    .frame(width: 72, height: 72).rotationEffect(.degrees(-14))
    .accessibilityHidden(true)
  }
}

struct PaperButton: ButtonStyle {
  var secondary = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(.subheadline, weight: .semibold))
      .frame(maxWidth: .infinity).padding(.vertical, 17)
      .background(secondary ? Ink.pale : Ink.blue, in: RoundedRectangle(cornerRadius: 8))
      .foregroundStyle(secondary ? Ink.navy : .white)
      .opacity(configuration.isPressed ? 0.75 : 1)
  }
}

struct ActionShelf<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content
      .buttonStyle(PaperButton())
      .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
      .background(Ink.paper)
      .overlay(alignment: .top) { Rectangle().fill(Ink.pale).frame(height: 1) }
  }
}

extension View {
  func journalNavigation() -> some View {
    toolbarBackground(Ink.paper, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.light, for: .navigationBar)
  }
}

struct EmptyJournal: View {
  var title: String
  var detail: String
  var body: some View {
    VStack(spacing: 16) {
      Stamp(text: "A LITTLE\nWONDER")
      Text(title).font(.system(.title2, design: .serif)).foregroundStyle(Ink.navy)
      Text(detail).font(.subheadline).foregroundStyle(Ink.muted)
        .multilineTextAlignment(.center)
    }
    .padding(32).frame(maxWidth: .infinity)
  }
}

struct Landscape: View {
  var style: JourneyStyle
  var body: some View {
    Canvas { context, size in
      let w = size.width
      let h = size.height
      func polygon(_ points: [CGPoint], _ color: Color) {
        var path = Path()
        path.addLines(points.map { CGPoint(x: $0.x * w, y: $0.y * h) })
        path.closeSubpath()
        context.fill(path, with: .color(color))
      }
      func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ color: Color) {
        context.fill(
          Path(CGRect(x: x * w, y: y * h, width: width * w, height: height * h)),
          with: .color(color))
      }
      rect(0, 0, 1, 1, Color(hex: 0xEBCBA2))
      context.fill(
        Path(ellipseIn: CGRect(x: w * 0.69, y: h * 0.10, width: h * 0.23, height: h * 0.23)),
        with: .color(Color(hex: 0xFDF0C1)))
      switch style {
      case .coast:
        rect(0, 0.47, 1, 0.53, Color(hex: 0x529EAB))
        polygon(
          [
            .init(x: 0, y: 0.32), .init(x: 0.31, y: 0.37), .init(x: 0.49, y: 0.64),
            .init(x: 0.72, y: 0.8), .init(x: 0.49, y: 1), .init(x: 0, y: 1),
          ],
          Color(hex: 0x4A6B54))
        polygon(
          [
            .init(x: 0, y: 0.59), .init(x: 0.38, y: 0.53), .init(x: 0.61, y: 0.8),
            .init(x: 0.40, y: 0.97), .init(x: 0, y: 0.83),
          ],
          Color(hex: 0xC19068))
        let colors: [Color] = [
          Color(hex: 0xC75B3F), Color(hex: 0xEDC37A), Color(hex: 0xDA8C67),
          Color(hex: 0xF3D59B), Color(hex: 0xC75B3F),
        ]
        for i in 0..<12 {
          let x = CGFloat(i % 6) * 0.075 - 0.015 + CGFloat(i / 6) * 0.045
          let y = 0.42 + CGFloat(i % 3) * 0.043 + CGFloat(i / 6) * 0.19
          let height = 0.19 - CGFloat(i % 2) * 0.035
          rect(x, y, 0.072, height, colors[i % colors.count])
          polygon(
            [
              .init(x: x - 0.008, y: y), .init(x: x + 0.036, y: y - 0.032),
              .init(x: x + 0.08, y: y),
            ], Color(hex: 0x793E31))
          for row in 0..<3 {
            for col in 0..<2 {
              rect(
                x + 0.014 + CGFloat(col) * 0.028, y + 0.027 + CGFloat(row) * 0.042,
                0.012, 0.025, Ink.navy.opacity(0.75))
            }
          }
        }
        rect(0.322, 0.247, 0.041, 0.25, Color(hex: 0xE7C69C))
        polygon(
          [
            .init(x: 0.315, y: 0.247), .init(x: 0.342, y: 0.195),
            .init(x: 0.37, y: 0.247),
          ], Color(hex: 0x703E35))
        for i in 0..<14 {
          let x = 0.60 + CGFloat((i * 3) % 7) * 0.055
          let y = 0.55 + CGFloat(i) * 0.027
          rect(x, y, 0.065, 0.003, Color.white.opacity(0.38))
        }
        polygon(
          [
            .init(x: 0.77, y: 0.75), .init(x: 0.87, y: 0.75),
            .init(x: 0.85, y: 0.774), .init(x: 0.79, y: 0.774),
          ], Ink.navy)
        polygon(
          [
            .init(x: 0.818, y: 0.74), .init(x: 0.818, y: 0.60),
            .init(x: 0.76, y: 0.74),
          ], Color(hex: 0xFFF1D1))
      case .mountains:
        rect(0, 0.50, 1, 0.5, Color(hex: 0x78A8A7))
        polygon(
          [.init(x: 0, y: 0.67), .init(x: 0.29, y: 0.14), .init(x: 0.63, y: 0.73)],
          Color(hex: 0x6C8981))
        polygon(
          [.init(x: 0.31, y: 0.72), .init(x: 0.67, y: 0.18), .init(x: 1.1, y: 0.8)],
          Color(hex: 0x375C62))
        polygon(
          [
            .init(x: 0.54, y: 0.375), .init(x: 0.67, y: 0.18), .init(x: 0.83, y: 0.42),
            .init(x: 0.69, y: 0.35), .init(x: 0.64, y: 0.40),
          ], Ink.paper)
        polygon(
          [
            .init(x: 0, y: 0.83), .init(x: 0.3, y: 0.7), .init(x: 0.62, y: 0.95),
            .init(x: 1, y: 0.78), .init(x: 1, y: 1), .init(x: 0, y: 1),
          ],
          Color(hex: 0x293F43))
        for i in 0..<8 {
          let x = CGFloat(i) * 0.06
          polygon(
            [
              .init(x: x, y: 0.94), .init(x: x + 0.035, y: 0.68 - CGFloat(i % 3) * 0.04),
              .init(x: x + 0.08, y: 0.94),
            ], Color(hex: 0x1F4B44))
        }
      case .city:
        rect(0, 0.6, 1, 0.4, Color(hex: 0xC89975))
        polygon(
          [
            .init(x: 0.40, y: 0.50), .init(x: 0.57, y: 0.5), .init(x: 0.8, y: 1),
            .init(x: 0.2, y: 1),
          ], Color(hex: 0xE4C9AA))
        for i in 0..<4 {
          let x = CGFloat(i) * 0.24 - 0.05
          rect(x, 0.48 + CGFloat(i % 2) * 0.1, 0.23, 0.38, Color(hex: 0x885B46))
          polygon(
            [
              .init(x: x - 0.03, y: 0.50), .init(x: x + 0.1, y: 0.38),
              .init(x: x + 0.25, y: 0.50),
            ], Color(hex: 0x334E48))
          for j in 0..<5 {
            rect(x + 0.025 + CGFloat(j) * 0.036, 0.55, 0.012, 0.20, Color(hex: 0x513F35))
          }
        }
        rect(0.70, 0.23, 0.021, 0.50, Ink.red)
        rect(0.89, 0.23, 0.021, 0.50, Ink.red)
        rect(0.64, 0.23, 0.33, 0.035, Ink.red)
        rect(0.67, 0.31, 0.27, 0.022, Ink.red)
        for i in 0..<30 {
          let x = CGFloat((i * 17) % 41) / 100
          let y = CGFloat((i * 7) % 33) / 100
          context.fill(
            Path(ellipseIn: CGRect(x: x * w, y: y * h, width: 0.065 * w, height: 0.04 * h)),
            with: .color(Color(hex: i % 2 == 0 ? 0xD68876 : 0xE7B49B)))
        }
      }
      for i in 0..<85 {
        let y = CGFloat(i) / 85 * h
        var line = Path()
        line.move(to: CGPoint(x: 0, y: y))
        line.addLine(to: CGPoint(x: w, y: y))
        context.stroke(line, with: .color(Ink.paper.opacity(0.07)), lineWidth: 0.4)
      }
    }
    .accessibilityLabel("Original \(style.name.lowercased()) illustration")
  }
}

struct MemoryArt: View {
  var photo: Data?
  var style: JourneyStyle
  var body: some View {
    if let photo, let image = UIImage(data: photo) {
      GeometryReader { geo in
        Image(uiImage: image).resizable().scaledToFill()
          .frame(width: geo.size.width, height: geo.size.height).clipped()
      }
      .accessibilityLabel("Imported memory photo")
    } else {
      Landscape(style: style)
    }
  }
}
