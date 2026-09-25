import SwiftUI

enum Deck {
  static let bone = Color(red: 0.94, green: 0.93, blue: 0.89)
  static let paper = Color(red: 0.98, green: 0.97, blue: 0.93)
  static let ink = Color(red: 0.15, green: 0.16, blue: 0.15)
  static let muted = Color(red: 0.40, green: 0.41, blue: 0.37)
  static let red = Color(red: 0.77, green: 0.22, blue: 0.14)
  static let amber = Color(red: 0.97, green: 0.69, blue: 0.29)
  static let line = Color(red: 0.80, green: 0.80, blue: 0.75)
}

struct Micro: View {
  let text: String
  var color: Color = Deck.muted

  var body: some View {
    Text(text)
      .font(.system(.caption2, design: .monospaced).weight(.semibold))
      .tracking(1.2)
      .foregroundStyle(color)
  }
}

struct Reel: View {
  var angle: Double

  var body: some View {
    ZStack {
      Circle().fill(Deck.ink)
      Circle().stroke(Color.white.opacity(0.16), lineWidth: 6).padding(5)
      ForEach(0..<6) { index in
        Capsule().fill(Deck.bone)
          .frame(width: 7, height: 20)
          .offset(y: -20)
          .rotationEffect(.degrees(Double(index) * 60 + angle))
      }
      Circle().fill(Deck.bone).frame(width: 29, height: 29)
      Circle().fill(Deck.ink).frame(width: 10, height: 10)
      Circle().stroke(Deck.bone.opacity(0.45), lineWidth: 1).padding(1)
    }
    .accessibilityHidden(true)
  }
}

struct CassetteView: View {
  var playing: Bool
  var step: Int
  var level: Float
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        Micro(text: "A / TD—01  •  TYPE IV", color: Deck.bone.opacity(0.85))
        Spacer()
        Circle().fill(playing ? Deck.red : Deck.muted).frame(width: 6, height: 6)
        Micro(text: playing ? "RUN" : "READY", color: Deck.bone)
      }
      HStack(spacing: 0) {
        Reel(angle: reduceMotion ? 0 : Double(max(0, step)) * 23)
          .frame(width: 60, height: 60)
        VStack(spacing: 7) {
          HStack(spacing: 3) {
            ForEach(0..<14) { index in
              RoundedRectangle(cornerRadius: 1)
                .fill(Float(index) < level * 24 ? Deck.amber : Deck.amber.opacity(0.13))
                .frame(height: 13)
            }
          }
          Micro(text: "FOUR VOICES / 16 STEPS", color: Deck.amber)
          Rectangle().fill(Deck.bone.opacity(0.17)).frame(height: 1)
        }
        .padding(.horizontal, 14)
        Reel(angle: reduceMotion ? 0 : Double(max(0, step)) * 23)
          .frame(width: 60, height: 60)
      }
    }
    .padding(14)
    .background(
      LinearGradient(
        colors: [Color(white: 0.23), Deck.ink, Color(white: 0.11)],
        startPoint: .topLeading, endPoint: .bottomTrailing),
      in: RoundedRectangle(cornerRadius: 17)
    )
    .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.black.opacity(0.75), lineWidth: 1))
    .overlay(alignment: .bottom) {
      Capsule().fill(Color.black.opacity(0.5)).frame(width: 88, height: 4).offset(y: 6)
    }
    .shadow(color: .black.opacity(0.18), radius: 2, y: 3)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(playing ? "Tape playing, audio output meter active" : "Tape ready")
  }
}

struct Knob: View {
  let fraction: Double

  var body: some View {
    ZStack {
      Circle().stroke(Deck.line, lineWidth: 1)
      ForEach(0..<11) { index in
        Rectangle().fill(Deck.muted.opacity(0.5)).frame(width: 1, height: 3)
          .offset(y: -24).rotationEffect(.degrees(-135 + Double(index) * 27))
      }
      Circle()
        .fill(
          LinearGradient(
            colors: [Color(white: 0.32), Deck.ink],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .padding(6)
        .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
      Capsule().fill(Deck.paper).frame(width: 2, height: 10).offset(y: -11)
        .rotationEffect(.degrees(-135 + fraction * 270))
    }
    .frame(width: 52, height: 52)
    .accessibilityHidden(true)
  }
}

struct HardwareButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.75 : 1)
      .offset(y: configuration.isPressed ? 1 : 0)
  }
}
