import SwiftUI

enum Palette {
  static let cream = Color(red: 0.96, green: 0.95, blue: 0.91)
  static let ink = Color(red: 0.10, green: 0.12, blue: 0.11)
  static let graphite = Color(red: 0.15, green: 0.17, blue: 0.16)
  static let lime = Color(red: 0.79, green: 0.97, blue: 0.27)
  static let muted = Color(red: 0.39, green: 0.42, blue: 0.38)
  static let rest = Color(red: 0.66, green: 0.80, blue: 0.77)
}

extension Font {
  static func instrument(_ size: CGFloat) -> Font {
    .system(size: size, weight: .heavy, design: .default).width(.compressed)
  }
}

struct InstrumentType: ViewModifier {
  @ScaledMetric private var size: CGFloat

  init(size: CGFloat) {
    _size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
  }

  func body(content: Content) -> some View {
    content.font(.instrument(size))
  }
}

extension View {
  func instrumentDisplay(_ size: CGFloat) -> some View {
    modifier(InstrumentType(size: size))
  }
}

struct AdaptiveRow<Content: View>: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  var spacing: CGFloat = 18
  @ViewBuilder var content: () -> Content

  var body: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
      : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
    layout { content() }
  }
}

struct Eyebrow: View {
  var text: String
  var body: some View {
    Text(text.uppercased()).font(.caption.weight(.bold)).tracking(2)
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
  }
}

struct CadenceMark: View {
  var color: Color = Palette.lime
  var body: some View {
    HStack(alignment: .center, spacing: 3) {
      ForEach(0..<5) { i in
        Capsule().fill(color).frame(width: 5, height: [14.0, 25, 36, 25, 14][i])
      }
    }
    .rotationEffect(.degrees(12))
    .accessibilityHidden(true)
  }
}

struct IntervalSculpture: View {
  var body: some View {
    Canvas { context, size in
      for index in 0..<15 {
        let x = CGFloat(index) * size.width / 15
        let wave = sin(Double(index) * 0.48 - 0.6)
        let height = 30 + CGFloat((wave + 1) / 2) * (size.height - 36)
        let rect = CGRect(
          x: x, y: (size.height - height) / 2, width: size.width / 15 - 6, height: height)
        context.fill(
          Path(roundedRect: rect, cornerRadius: 9),
          with: .color(index % 3 == 2 ? Palette.lime.opacity(0.24) : Palette.lime))
      }
    }
    .rotationEffect(.degrees(-9))
    .accessibilityHidden(true)
  }
}

struct ActionButton: View {
  var title: String
  var symbol = "arrow.up.right"
  var dark = true
  var action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack {
        Text(title).font(.headline)
        Spacer()
        Image(systemName: symbol).font(.headline)
      }
      .padding(.horizontal, 22).padding(.vertical, 12).frame(minHeight: 58)
      .background(dark ? Palette.ink : Palette.lime)
      .foregroundStyle(dark ? Palette.cream : Palette.ink)
      .clipShape(RoundedRectangle(cornerRadius: 18))
    }.buttonStyle(.plain)
  }
}

struct Metric: View {
  var value: String
  var label: String
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(value).instrumentDisplay(32).minimumScaleFactor(0.6).lineLimit(1)
      Text(label).font(.caption).foregroundStyle(Palette.muted)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}
