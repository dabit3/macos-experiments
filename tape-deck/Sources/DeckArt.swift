import SwiftUI

enum Deck {
  static let bone = Color(red: 0.95, green: 0.94, blue: 0.91)
  static let paper = Color(red: 0.99, green: 0.98, blue: 0.96)
  static let ink = Color(red: 0.13, green: 0.14, blue: 0.14)
  static let charcoal = Color(red: 0.22, green: 0.23, blue: 0.23)
  static let muted = Color(red: 0.45, green: 0.46, blue: 0.43)
  static let red = Color(red: 0.83, green: 0.24, blue: 0.15)
  static let amber = Color(red: 0.98, green: 0.68, blue: 0.24)
  static let line = Color(red: 0.84, green: 0.83, blue: 0.79)

  static func label(_ text: String, color: Color = Deck.muted) -> Text {
    Text(text)
      .font(.footnote.weight(.semibold))
      .foregroundStyle(color)
  }
}

/// One cassette reel. Rotation is driven by the current step so it only moves while playing.
struct Reel: View {
  var angle: Double
  var body: some View {
    ZStack {
      Circle().fill(Deck.charcoal)
      Circle().stroke(Deck.bone.opacity(0.3), lineWidth: 1.5).padding(3)
      ForEach(0..<3) { index in
        Capsule()
          .fill(Deck.bone.opacity(0.9))
          .frame(width: 4, height: 13)
          .offset(y: -12)
          .rotationEffect(.degrees(Double(index) * 120))
      }
      Circle().fill(Deck.bone).scaleEffect(0.22)
    }
    .rotationEffect(.degrees(angle))
    .animation(.linear(duration: 0.12), value: angle)
    .accessibilityHidden(true)
  }
}

/// A single 16-step strip. Used for the track overview and library previews.
struct StepStrip: View {
  var steps: [Bool]
  var currentStep: Int = -1
  var on: Color = Deck.amber
  var off: Color = Deck.bone.opacity(0.14)
  var height: CGFloat = 12

  var body: some View {
    HStack(spacing: 0) {
      ForEach(0..<16) { step in
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(steps[step] ? on : off)
          .overlay {
            if currentStep == step {
              RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(Deck.red, lineWidth: 1.5)
            }
          }
          .frame(maxWidth: .infinity)
          .frame(height: height)
          .padding(.trailing, step == 15 ? 0 : (step % 4 == 3 ? 6 : 2))
      }
    }
    .accessibilityHidden(true)
  }
}

/// A four-row pattern preview.
struct PatternPreview: View {
  var pattern: Pattern
  var currentStep: Int = -1
  var height: CGFloat = 8

  var body: some View {
    VStack(spacing: 3) {
      ForEach(Drum.allCases) { drum in
        StepStrip(
          steps: pattern.steps[drum.rawValue], currentStep: currentStep,
          on: Deck.ink.opacity(0.85), off: Deck.ink.opacity(0.08), height: height)
      }
    }
  }
}

struct HardwareButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
      .opacity(configuration.isPressed ? 0.85 : 1)
      .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
  }
}
