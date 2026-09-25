import BrickfolkCore
import CoreText
import SwiftUI

extension Color {
  init(argb: UInt32) {
    self.init(
      .sRGB, red: Double((argb >> 16) & 255) / 255,
      green: Double((argb >> 8) & 255) / 255,
      blue: Double(argb & 255) / 255,
      opacity: Double((argb >> 24) & 255) / 255)
  }
  static let brick = Color(argb: 0xFFFF_7856)
  static let sky = Color(argb: 0xFF52_6BFF)
  static let mint = Color(argb: 0xFF21_CB9C)
  static let sun = Color(argb: 0xFFFF_D454)
  static let ink = Color(argb: 0xFF0D_1226)
}

enum BrandFonts {
  static func register() {
    for name in [
      "Inter-Regular", "Inter-Medium", "Inter-SemiBold", "Inter-Bold", "Inter-ExtraBold",
    ] {
      if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
      }
    }
  }
}

struct BrickButtonStyle: ButtonStyle {
  var color: Color = .sky
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.custom("Inter-SemiBold", size: 14))
      .padding(.horizontal, 16).padding(.vertical, 12)
      .foregroundStyle(.white)
      .background(
        color.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 12)
      )
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
  }
}

struct Panel<Content: View>: View {
  @Environment(\.colorScheme) private var scheme
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        scheme == .dark ? Color(argb: 0xFF17_1F39) : .white, in: RoundedRectangle(cornerRadius: 20)
      )
      .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.07)))
  }
}

struct BrickLogo: View {
  var body: some View {
    HStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 8).fill(Color.brick)
        VStack(spacing: 4) {
          HStack(spacing: 4) {
            stud
            stud
          }
          HStack(spacing: 4) {
            stud
            stud
          }
        }
      }.frame(width: 34, height: 34).rotationEffect(.degrees(-8))
      Text("brickfolk").font(.custom("Inter-ExtraBold", size: 25)).tracking(-1.2)
    }
  }
  private var stud: some View {
    Circle().fill(.white.opacity(0.4)).frame(width: 7, height: 7)
  }
}

struct AvatarView: View {
  let avatar: Avatar
  var size: CGFloat = 84
  var body: some View {
    Canvas { context, bounds in
      AvatarPainter.draw(
        context,
        rect: CGRect(
          x: bounds.width * 0.15, y: bounds.height * 0.2,
          width: bounds.width * 0.7, height: bounds.height * 0.78), avatar: avatar)
    }
    .frame(width: size, height: size)
    .background(Color.sky.opacity(0.1), in: RoundedRectangle(cornerRadius: size * 0.2))
    .accessibilityLabel("Brickfolk avatar, \(avatar.face), \(avatar.hat), \(avatar.accessory)")
  }
}

enum AvatarPainter {
  static func draw(
    _ original: GraphicsContext, rect bounds: CGRect, avatar: Avatar,
    facingRight: Bool = true, walk: Double = 0, frozen: Bool = false
  ) {
    var ctx = original
    let unit = min(bounds.width / 6, bounds.height / 10)
    ctx.translateBy(x: bounds.midX + (facingRight ? -3 : 3) * unit, y: bounds.minY)
    ctx.scaleBy(x: facingRight ? unit : -unit, y: unit)
    let ink = Color(argb: 0xFF1B_1F27)
    func rect(
      _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color, radius: Double = 0.18
    ) {
      ctx.fill(
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius),
        with: .color(color))
    }
    func dot(_ x: Double, _ y: Double, _ r: Double, _ color: Color) {
      ctx.fill(
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
        with: .color(color))
    }
    func polygon(_ points: [CGPoint], _ color: Color) {
      var path = Path()
      path.addLines(points)
      path.closeSubpath()
      ctx.fill(path, with: .color(color))
    }
    func line(_ a: CGPoint, _ b: CGPoint, _ color: Color = Color(argb: 0xFF1B_1F27)) {
      var path = Path()
      path.move(to: a)
      path.addLine(to: b)
      ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 0.22, lineCap: .round))
    }
    func block(
      _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ argb: UInt32, radius: Double = 0.18
    ) {
      let bounds = CGRect(x: x, y: y, width: w, height: h)
      let color = Color(argb: argb)
      ctx.fill(
        Path(roundedRect: bounds, cornerRadius: radius),
        with: .linearGradient(
          Gradient(colors: [color, color.opacity(0.85)]),
          startPoint: bounds.origin, endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)))
      rect(x, y, w, 0.22, .white.opacity(0.25))
      rect(x, y + h - 0.22, w, 0.22, .black.opacity(0.22))
      if frozen { rect(x, y, w, h, Color.cyan.opacity(0.45), radius: radius) }
    }
    let swing = sin(walk * .pi * 2) * 0.9
    block(1, 7, 1.9, 3, avatar.legColor)
    block(3.1, 7, 1.9, 3, avatar.legColor)
    block(1, 3, 4, 4, avatar.torsoColor)
    block(0, 3 + swing * 0.15, 0.95, 3.8, avatar.armColor)
    block(5.05, 3 - swing * 0.15, 0.95, 3.8, avatar.armColor)
    block(1.5, 0, 3, 3, avatar.headColor, radius: 0.35)
    switch avatar.accessory {
    case "acc_scarf":
      rect(1.2, 2.85, 3.6, 0.75, .red)
      rect(3.6, 3.4, 0.9, 1.8, .red)
    case "acc_backpack":
      rect(-0.1, 3.3, 1.3, 3.2, .brick)
      rect(0.1, 4.2, 0.9, 0.3, .red)
    case "acc_cape":
      polygon([.init(x: 1, y: 3.2), .init(x: 0.1, y: 8.4), .init(x: 1.4, y: 7.9)], .purple)
    case "acc_tie":
      polygon(
        [
          .init(x: 2.3, y: 3.2), .init(x: 3.7, y: 3.9), .init(x: 3.7, y: 3.2),
          .init(x: 2.3, y: 3.9),
        ], .red)
    case "acc_wings":
      polygon(
        [.init(x: 1, y: 3.6), .init(x: -1.3, y: 2.6), .init(x: -0.9, y: 5.2), .init(x: 1, y: 5.4)],
        .cyan)
      polygon(
        [.init(x: 5, y: 3.6), .init(x: 7.3, y: 2.6), .init(x: 6.9, y: 5.2), .init(x: 5, y: 5.4)],
        .cyan)
    default: break
    }
    switch avatar.face {
    case "face_shades":
      rect(1.75, 0.85, 1.15, 0.7, ink)
      rect(3.1, 0.85, 1.15, 0.7, ink)
      line(.init(x: 2.9, y: 1.1), .init(x: 3.1, y: 1.1))
    case "face_sleepy":
      line(.init(x: 2.05, y: 1.25), .init(x: 2.65, y: 1.25))
      line(.init(x: 3.35, y: 1.25), .init(x: 3.95, y: 1.25))
    case "face_robot":
      rect(2.05, 0.95, 0.6, 0.5, .cyan, radius: 0)
      rect(3.35, 0.95, 0.6, 0.5, .cyan, radius: 0)
    case "face_wink":
      dot(2.35, 1.2, 0.28, ink)
      line(.init(x: 3.35, y: 1.2), .init(x: 3.95, y: 1.2))
    default:
      dot(2.35, 1.2, 0.28, ink)
      dot(3.65, 1.2, 0.28, ink)
    }
    if avatar.face == "face_robot" {
      for i in 0..<4 {
        line(.init(x: 2.2 + Double(i) * 0.5, y: 2.1), .init(x: 2.2 + Double(i) * 0.5, y: 2.4))
      }
      line(.init(x: 2.2, y: 2.1), .init(x: 3.8, y: 2.1))
    } else if avatar.face == "face_sleepy" {
      dot(3, 2.15, 0.22, ink)
    } else {
      var mouth = Path()
      mouth.move(to: .init(x: 2.25, y: 1.9))
      mouth.addQuadCurve(to: .init(x: 3.75, y: 1.9), control: .init(x: 3, y: 2.8))
      ctx.stroke(
        mouth, with: .color(ink),
        style: StrokeStyle(lineWidth: avatar.face == "face_grin" ? 0.4 : 0.2, lineCap: .round))
      if avatar.face == "face_grin" { rect(2.4, 1.95, 1.2, 0.2, .white) }
    }
    switch avatar.hat {
    case "hat_cap":
      rect(1.35, -0.55, 3.3, 1, .sky, radius: 0.35)
      rect(3.6, 0.05, 1.9, 0.42, Color(argb: 0xFF2B_5FD1))
    case "hat_crown":
      polygon(
        [
          .init(x: 1.5, y: 0.35), .init(x: 1.5, y: -0.9), .init(x: 2.25, y: -0.2),
          .init(x: 3, y: -1.1), .init(x: 3.75, y: -0.2), .init(x: 4.5, y: -0.9),
          .init(x: 4.5, y: 0.35),
        ], .sun)
      dot(3, -0.1, 0.18, .red)
    case "hat_helmet":
      rect(1.3, -0.7, 3.4, 1.15, .sun, radius: 0.55)
      rect(1.15, 0.2, 3.7, 0.3, Color(argb: 0xFFCB_9A1C))
    case "hat_wizard":
      polygon(
        [
          .init(x: 1.2, y: 0.4), .init(x: 4.8, y: 0.4), .init(x: 3.7, y: -0.1),
          .init(x: 3.3, y: -2.4), .init(x: 2.3, y: -0.1),
        ], .purple)
      dot(2.9, -1, 0.2, .sun)
    case "hat_beanie":
      rect(1.35, -0.75, 3.3, 1.3, .red, radius: 0.7)
      rect(1.35, 0.15, 3.3, 0.4, Color(argb: 0xFFC2_354A))
      dot(3, -0.85, 0.3, .white)
    case "hat_propeller":
      rect(1.5, -0.35, 3, 0.8, .mint, radius: 0.5)
      rect(2.9, -1.1, 0.2, 0.8, .gray)
      rect(1.6, -1.25, 2.8, 0.3, .sun)
    default: break
    }
    if frozen {
      line(.init(x: 1.2, y: 3.4), .init(x: 2.4, y: 5.4), .white.opacity(0.6))
      line(.init(x: 4.6, y: 4.2), .init(x: 3.4, y: 6.6), .white.opacity(0.6))
    }
  }
}
