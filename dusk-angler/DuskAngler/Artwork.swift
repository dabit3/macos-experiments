import SwiftUI

enum Palette {
  static let night = Color(red: 0.043, green: 0.063, blue: 0.086)
  static let surface = Color(red: 0.078, green: 0.106, blue: 0.133)
  static let raised = Color(red: 0.125, green: 0.157, blue: 0.188)
  static let line = Color.white.opacity(0.1)
  static let text = Color(red: 0.965, green: 0.949, blue: 0.925)
  static let muted = Color(red: 0.965, green: 0.949, blue: 0.925).opacity(0.62)
  static let sunset = Color(red: 1.0, green: 0.576, blue: 0.435)
  static let reed = Color(red: 0.49, green: 0.85, blue: 0.69)
  static let amber = Color(red: 1.0, green: 0.78, blue: 0.4)
  static let danger = Color(red: 1.0, green: 0.36, blue: 0.36)
  static let violet = Color(red: 0.66, green: 0.6, blue: 1.0)
}

enum TypeStyle {
  static func display(_ size: CGFloat) -> Font {
    .system(size: size, weight: .bold).width(.expanded)
  }
  static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
  static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .regular) }
  static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
  static func number(_ size: CGFloat) -> Font {
    .system(size: size, weight: .bold).width(.expanded).monospacedDigit()
  }
}

struct LakeBackdrop: View {
  var violet = false
  var body: some View {
    GeometryReader { geometry in
      Image("Lake")
        .resizable()
        .scaledToFill()
        .frame(width: geometry.size.width, height: geometry.size.height)
        .clipped()
        .overlay(violet ? Color(red: 0.2, green: 0.16, blue: 0.5).opacity(0.35) : Color.clear)
        .overlay {
          LinearGradient(
            stops: [
              .init(color: Palette.night.opacity(0.55), location: 0),
              .init(color: .clear, location: 0.22),
              .init(color: .clear, location: 0.5),
              .init(color: Palette.night.opacity(0.94), location: 0.92),
            ], startPoint: .top, endPoint: .bottom)
        }
    }
    .ignoresSafeArea()
    .accessibilityHidden(true)
  }
}

struct FishArt: View {
  let species: Species
  var silhouette = false
  var body: some View {
    Image(species.rawValue)
      .renderingMode(silhouette ? .template : .original)
      .resizable()
      .scaledToFit()
      .foregroundStyle(Palette.night.opacity(0.88))
      .accessibilityHidden(true)
  }
}

struct WaterSparkles: View {
  let time: Double
  var body: some View {
    Canvas { context, size in
      for i in 0..<25 {
        let x = (Double(i * 37 % 101) / 101) * size.width
        let y = (Double(i * 17 % 97) / 97) * size.height
        let opacity = 0.1 + 0.4 * abs(sin(time * 0.6 + Double(i)))
        let length = 3 + 8 * abs(sin(time + Double(i)))
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: y, width: length, height: 1.2)),
          with: .color(Palette.text.opacity(opacity)))
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

struct PanelSurface: ViewModifier {
  var padding: CGFloat = 18
  func body(content: Content) -> some View {
    content
      .padding(padding)
      .background(Palette.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 22))
      .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Palette.line, lineWidth: 1))
  }
}

extension View {
  func panel(padding: CGFloat = 18) -> some View { modifier(PanelSurface(padding: padding)) }
}

struct ActionButton: View {
  enum Kind { case primary, secondary, quiet }
  let title: String
  var systemImage: String?
  var kind = Kind.primary
  var identifier: String?
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        if let systemImage {
          Image(systemName: systemImage).font(.system(size: 16, weight: .semibold))
        }
        Text(title).font(TypeStyle.label(17))
      }
      .frame(maxWidth: .infinity, minHeight: kind == .quiet ? 44 : 56)
      .foregroundStyle(kind == .primary ? Palette.night : Palette.text)
      .background {
        switch kind {
        case .primary: RoundedRectangle(cornerRadius: 16).fill(Palette.sunset)
        case .secondary: RoundedRectangle(cornerRadius: 16).fill(Palette.raised)
        case .quiet: Color.clear
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(PressedActionStyle())
    .accessibilityIdentifier(identifier ?? title)
  }
}

struct PressedActionStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.82 : 1)
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
  }
}

struct IconButton: View {
  let systemImage: String
  let label: String
  let identifier: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 17, weight: .semibold))
        .frame(width: 44, height: 44)
        .background(Palette.night.opacity(0.55), in: Circle())
        .overlay(Circle().strokeBorder(Palette.line, lineWidth: 1))
    }
    .buttonStyle(PressedActionStyle())
    .accessibilityLabel(label)
    .accessibilityIdentifier(identifier)
  }
}

struct Stat: View {
  let value: String
  let label: String
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value).font(TypeStyle.number(20)).lineLimit(1).minimumScaleFactor(0.7)
      Text(label).font(TypeStyle.body(12)).foregroundStyle(Palette.muted)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

struct RarityTag: View {
  let rare: Bool
  var body: some View {
    HStack(spacing: 5) {
      Circle().fill(rare ? Palette.violet : Palette.reed).frame(width: 6, height: 6)
      Text(rare ? "Rare" : "Common").font(TypeStyle.label(12))
    }
    .foregroundStyle(rare ? Palette.violet : Palette.reed)
  }
}

struct StepIndicator: View {
  let step: Int
  private let steps = ["Aim", "Hook", "Reel"]
  var body: some View {
    HStack(spacing: 6) {
      ForEach(steps.indices, id: \.self) { index in
        VStack(alignment: .leading, spacing: 5) {
          Capsule()
            .fill(index <= step ? Palette.sunset : Palette.text.opacity(0.18))
            .frame(height: 3)
          Text(steps[index]).font(TypeStyle.label(11))
            .foregroundStyle(index == step ? Palette.text : Palette.muted)
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Step \(step + 1) of 3, \(steps[step])")
  }
}

struct Meter: View {
  let fraction: Double
  var color = Palette.sunset
  var height: CGFloat = 6
  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().fill(Palette.text.opacity(0.12))
        Capsule().fill(color).frame(width: max(height, g.size.width * min(1, max(0, fraction))))
      }
    }
    .frame(height: height)
    .accessibilityHidden(true)
  }
}

enum TensionZone {
  case slack, safe, danger
  init(_ tension: Double) {
    self = tension >= 0.8 ? .danger : tension < 0.1 ? .slack : .safe
  }
  var color: Color {
    switch self {
    case .slack: return Palette.amber
    case .safe: return Palette.reed
    case .danger: return Palette.danger
    }
  }
  var word: String {
    switch self {
    case .slack: return "Slack"
    case .safe: return "Safe"
    case .danger: return "About to snap"
    }
  }
}

struct TensionMeter: View {
  let tension: Double
  var showsLegend = true
  var body: some View {
    VStack(spacing: 6) {
      GeometryReader { g in
        let w = g.size.width
        ZStack(alignment: .leading) {
          HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3).fill(Palette.amber.opacity(0.22))
              .frame(width: w * 0.1 - 2)
            RoundedRectangle(cornerRadius: 3).fill(Palette.reed.opacity(0.2))
              .frame(width: w * 0.7 - 2)
            RoundedRectangle(cornerRadius: 3).fill(Palette.danger.opacity(0.25))
          }
          RoundedRectangle(cornerRadius: 3).fill(TensionZone(tension).color)
            .frame(width: max(6, w * min(1, tension)))
          RoundedRectangle(cornerRadius: 1.5).fill(Palette.text)
            .frame(width: 3, height: 22)
            .offset(x: min(w - 3, max(0, w * tension - 1.5)))
        }
        .frame(height: 22)
      }
      .frame(height: 22)
      if showsLegend {
        GeometryReader { g in
          ZStack(alignment: .topLeading) {
            Text("Slack").offset(x: 0)
            Text("Safe").offset(x: g.size.width * 0.42)
            Text("Snap").frame(maxWidth: .infinity, alignment: .trailing)
          }
          .font(TypeStyle.body(11)).foregroundStyle(Palette.muted)
        }
        .frame(height: 14)
      }
    }
    .accessibilityHidden(true)
  }
}

struct SurgeForecast: View {
  let elapsed: Double
  static let horizon = 9.0
  var body: some View {
    Canvas { context, size in
      let steps = 90
      let width = size.width / CGFloat(steps)
      for index in 0..<steps {
        let t = elapsed + Self.horizon * Double(index) / Double(steps)
        let cycle = t.truncatingRemainder(dividingBy: 7)
        let color: Color =
          Duel.surges(at: t)
          ? Palette.danger
          : cycle >= 3.2 && cycle < 4.5
            ? Palette.amber.opacity(0.7)
            : Palette.text.opacity(0.14)
        let height: CGFloat =
          Duel.surges(at: t) ? size.height : cycle >= 3.2 && cycle < 4.5 ? size.height * 0.6 : 3
        context.fill(
          Path(
            roundedRect: CGRect(
              x: CGFloat(index) * width, y: (size.height - height) / 2, width: max(1, width - 1),
              height: height), cornerRadius: 1),
          with: .color(color))
      }
      context.fill(
        Path(roundedRect: CGRect(x: 0, y: 0, width: 3, height: size.height), cornerRadius: 1.5),
        with: .color(Palette.text))
    }
    .frame(height: 18)
    .accessibilityHidden(true)
  }
}

struct ReelButton: View {
  @Binding var holding: Bool
  let tension: Double
  let surging: Bool
  let warning: Bool
  let elapsed: Double
  @State private var spin = 0.0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var title: String {
    if surging { return holding ? "Let go!" : "Hold off…" }
    if holding { return "Reeling" }
    return warning ? "Hold briefly" : "Hold to reel"
  }
  private var subtitle: String {
    if surging { return holding ? "The fish is surging" : "Wait out the surge" }
    if warning { return "Surge coming — ease off soon" }
    return holding ? "Release to ease the line" : "Press and hold anywhere here"
  }
  private var tint: Color {
    if surging { return holding ? Palette.danger : Palette.amber }
    return warning ? Palette.amber : Palette.reed
  }

  var body: some View {
    HStack(spacing: 16) {
      ZStack {
        Circle().strokeBorder(tint, lineWidth: 2)
        ForEach(0..<6) { index in
          Capsule().fill(tint).frame(width: 2.5, height: 12).offset(y: -9)
            .rotationEffect(.degrees(Double(index) * 60))
        }
        .rotationEffect(.degrees(spin))
        Circle().fill(tint).frame(width: 8, height: 8)
      }
      .frame(width: 46, height: 46)
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(TypeStyle.display(21))
        Text(subtitle).font(TypeStyle.body(13)).foregroundStyle(Palette.muted)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 20)
    .frame(maxWidth: .infinity, minHeight: 88)
    .background(
      RoundedRectangle(cornerRadius: 20).fill(holding ? tint.opacity(0.22) : Palette.raised)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 20).strokeBorder(
        tint.opacity(holding ? 1 : 0.55), lineWidth: holding ? 2 : 1)
    )
    .scaleEffect(holding && !reduceMotion ? 0.985 : 1)
    .contentShape(RoundedRectangle(cornerRadius: 20))
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in holding = true }
        .onEnded { _ in holding = false }
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Reel")
    .accessibilityValue(
      "\(holding ? "Reeling" : "Released"), tension \(Int(tension * 100)) percent"
    )
    .accessibilityHint("Double tap to toggle reeling. Release before a surge.")
    .accessibilityAddTraits(.isButton)
    .accessibilityIdentifier("reel")
    .accessibilityAction { holding.toggle() }
    .onChange(of: elapsed) { old, new in
      if holding && !reduceMotion { spin += max(0, new - old) * 260 }
    }
  }
}
