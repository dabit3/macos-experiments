import SwiftUI

@main
struct CelestiaApp: App {
  @StateObject private var observatory = Observatory()

  var body: some Scene {
    WindowGroup {
      ObservatoryView()
        .environmentObject(observatory)
        .preferredColorScheme(.dark)
    }
  }
}

enum Palette {
  static let ink = Color(red: 0.025, green: 0.055, blue: 0.10)
  static let panel = Color(red: 0.045, green: 0.085, blue: 0.14)
  static let raised = Color(red: 0.07, green: 0.12, blue: 0.19)
  static let ivory = Color(red: 0.93, green: 0.91, blue: 0.83)
  static let muted = Color(red: 0.56, green: 0.65, blue: 0.72)
  static let gold = Color(red: 0.81, green: 0.68, blue: 0.43)
  static let mint = Color(red: 0.48, green: 0.77, blue: 0.71)
  static let line = Color(red: 0.16, green: 0.23, blue: 0.30)
}

struct Eyebrow: View {
  let text: String
  var body: some View {
    Text(text.uppercased()).font(.system(size: 10, weight: .medium, design: .monospaced))
      .tracking(2).foregroundStyle(Palette.muted)
  }
}

struct InstrumentButton: ButtonStyle {
  var active = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .medium))
      .padding(.horizontal, 15).frame(minHeight: 42)
      .foregroundStyle(active ? Palette.ink : Palette.ivory)
      .background(active ? Palette.gold : Palette.raised)
      .clipShape(RoundedRectangle(cornerRadius: 9))
      .opacity(configuration.isPressed ? 0.65 : 1)
  }
}
