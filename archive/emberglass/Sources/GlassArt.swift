import SwiftUI

enum Palette {
  static let background = Color(red: 0.043, green: 0.063, blue: 0.071)
  static let surface = Color(red: 0.106, green: 0.141, blue: 0.149)
  static let cream = Color(red: 0.933, green: 0.910, blue: 0.851)
  static let muted = Color(red: 0.588, green: 0.643, blue: 0.635)
  static let brass = Color(red: 0.808, green: 0.678, blue: 0.471)
  static let ember = Color(red: 0.957, green: 0.494, blue: 0.271)
  static let mint = Color(red: 0.510, green: 0.784, blue: 0.725)
}

enum StudioType {
  static func display(_ size: CGFloat) -> Font { .custom("Didot", fixedSize: size) }
  static func italic(_ size: CGFloat) -> Font { .custom("Didot-Italic", fixedSize: size) }
  static func body(_ size: CGFloat) -> Font { .custom("AvenirNext-Regular", fixedSize: size) }
  static func label(_ size: CGFloat) -> Font { .custom("AvenirNext-DemiBold", fixedSize: size) }
}

struct VesselShape: Shape {
  var profile: [Double]

  func path(in rect: CGRect) -> Path {
    guard profile.count >= 2 else { return Path() }
    let center = rect.midX
    let unit = rect.width * 0.48
    let top = rect.minY + rect.height * 0.09
    let height = rect.height * 0.79
    let step = height / Double(profile.count - 1)
    let tangents = CraftRules.contourTangents(profile)
    var path = Path()
    path.move(to: CGPoint(x: center + profile[0] * unit, y: top))
    for index in 1..<profile.count {
      let previousY = top + Double(index - 1) * step
      let y = top + Double(index) * step
      path.addCurve(
        to: CGPoint(x: center + profile[index] * unit, y: y),
        control1: CGPoint(
          x: center + (profile[index - 1] + tangents[index - 1] / 3) * unit, y: previousY + step / 3
        ),
        control2: CGPoint(
          x: center + (profile[index] - tangents[index] / 3) * unit, y: y - step / 3)
      )
    }
    let last = profile[profile.count - 1] * unit
    let foot = top + height + height * GlassContour.footHalfHeight / GlassContour.height
    path.addLine(to: CGPoint(x: center + last, y: foot))
    path.addLine(to: CGPoint(x: center - last, y: foot))
    path.addLine(to: CGPoint(x: center - last, y: top + height))
    for index in (0..<(profile.count - 1)).reversed() {
      let y = top + Double(index) * step
      path.addCurve(
        to: CGPoint(x: center - profile[index] * unit, y: y),
        control1: CGPoint(
          x: center - (profile[index + 1] - tangents[index + 1] / 3) * unit, y: y + step * 2 / 3),
        control2: CGPoint(
          x: center - (profile[index] + tangents[index] / 3) * unit, y: y + step / 3)
      )
    }
    path.addLine(to: CGPoint(x: center + profile[0] * unit, y: top))
    path.closeSubpath()
    return path
  }
}

struct StudioBackdrop: View {
  var warm = false

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Palette.background
        RadialGradient(
          colors: [
            (warm ? Palette.ember : Palette.mint).opacity(warm ? 0.20 : 0.08), .clear,
          ],
          center: UnitPoint(x: 0.5, y: 0.43), startRadius: 10,
          endRadius: geometry.size.width * 0.85
        )
        Canvas { context, size in
          for index in 0..<180 {
            let x = Double(index) / 180 * size.width
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(
              line, with: .color(Palette.cream.opacity(index % 3 == 0 ? 0.018 : 0.008)),
              lineWidth: 0.5)
          }
        }
      }
    }
    .ignoresSafeArea()
    .accessibilityHidden(true)
  }
}

struct MakerMark: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let x = rect.midX
    let w = rect.width
    let h = rect.height
    path.move(to: CGPoint(x: x, y: 0))
    path.addLine(to: CGPoint(x: x, y: h * 0.37))
    path.move(to: CGPoint(x: x, y: h * 0.34))
    path.addCurve(
      to: CGPoint(x: x, y: h),
      control1: CGPoint(x: x - w * 0.82, y: h * 0.75),
      control2: CGPoint(x: x - w * 0.25, y: h))
    path.addCurve(
      to: CGPoint(x: x, y: h * 0.34),
      control1: CGPoint(x: x + w * 0.52, y: h),
      control2: CGPoint(x: x + w * 0.47, y: h * 0.77))
    path.move(to: CGPoint(x: x, y: h * 0.57))
    path.addCurve(
      to: CGPoint(x: x, y: h),
      control1: CGPoint(x: x - w * 0.2, y: h * 0.81),
      control2: CGPoint(x: x + w * 0.30, y: h * 0.86))
    return path
  }
}

struct ExhibitionNiche: View {
  var warm = false

  var body: some View {
    GeometryReader { geometry in
      let arch = UnevenRoundedRectangle(
        topLeadingRadius: geometry.size.width / 2, bottomLeadingRadius: 4,
        bottomTrailingRadius: 4, topTrailingRadius: geometry.size.width / 2)
      ZStack {
        arch.fill(
          LinearGradient(
            colors: [Palette.surface.opacity(0.65), Palette.background.opacity(0)],
            startPoint: .top, endPoint: .bottom))
        arch.stroke(
          LinearGradient(
            colors: [Palette.brass.opacity(0.22), Palette.brass.opacity(0.04), .clear],
            startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.75)
        RadialGradient(
          colors: [(warm ? Palette.ember : Palette.mint).opacity(warm ? 0.16 : 0.045), .clear],
          center: UnitPoint(x: 0.5, y: 0.55), startRadius: 0, endRadius: geometry.size.width * 0.58
        )
        .clipShape(arch)
        VStack {
          HStack {
            Rectangle().fill(Palette.brass.opacity(0.3)).frame(width: 15, height: 0.5)
            Spacer()
            Rectangle().fill(Palette.brass.opacity(0.3)).frame(width: 15, height: 0.5)
          }
          Spacer()
        }.padding(.top, geometry.size.height * 0.52).padding(.horizontal, 9)
      }
    }.accessibilityHidden(true)
  }
}

struct GradeSeal: View {
  let score: Int

  var body: some View {
    ZStack {
      Circle().stroke(Palette.brass.opacity(0.65), lineWidth: 0.6)
      Circle().stroke(Palette.brass.opacity(0.22), lineWidth: 0.6).padding(4)
      VStack(spacing: -1) {
        Text("\(score)").font(StudioType.display(29))
        Text("OF 100").font(StudioType.label(6)).tracking(1.5).foregroundStyle(Palette.brass)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Score \(score) out of 100")
  }
}

struct PressStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .brightness(configuration.isPressed ? -0.08 : 0)
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
  }
}

struct RotationControl: View {
  @Binding var value: Double
  let target: Double

  var body: some View {
    GeometryReader { geometry in
      let travel = max(1, geometry.size.width - 56)
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 15)
          .fill(
            LinearGradient(
              colors: [Palette.surface, Palette.background],
              startPoint: .top, endPoint: .bottom)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 15).stroke(Palette.brass.opacity(0.25), lineWidth: 0.7))
        HStack {
          Image(systemName: "minus")
          Spacer()
          Image(systemName: "plus")
        }.font(.system(size: 9)).foregroundStyle(Palette.muted).padding(.horizontal, 14)
        Capsule().fill(Palette.brass.opacity(0.2)).frame(height: 1).padding(.horizontal, 30)
        ZStack {
          Circle().fill(
            LinearGradient(
              colors: [Palette.cream, Palette.brass, Palette.brass.opacity(0.7)],
              startPoint: .topLeading, endPoint: .bottomTrailing))
          Circle().stroke(Palette.background.opacity(0.25), lineWidth: 0.5).padding(5)
          HStack(spacing: 3) {
            ForEach(0..<3) { _ in
              Capsule().fill(Palette.background.opacity(0.5)).frame(width: 1, height: 13)
            }
          }
        }
        .frame(width: 42, height: 42)
        .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
        .offset(x: 7 + travel * value)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { gesture in
          value = CraftRules.clamp((gesture.location.x - 28) / travel)
        })
    }
    .frame(height: 56)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Rotation speed")
    .accessibilityValue("\(Int(value * 100)) percent. Target \(Int(target * 100)) percent")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: value = CraftRules.clamp(value + 0.05)
      case .decrement: value = CraftRules.clamp(value - 0.05)
      @unknown default: break
      }
    }
    .accessibilityIdentifier("rotationSlider")
  }
}
