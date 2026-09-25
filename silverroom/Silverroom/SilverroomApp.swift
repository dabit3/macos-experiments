import SwiftUI

@main
struct SilverroomApp: App {
  @StateObject private var library = LibraryStore()

  var body: some Scene {
    WindowGroup {
      LibraryView()
        .environmentObject(library)
        .preferredColorScheme(.dark)
        .tint(Palette.amber)
    }
  }
}

enum Palette {
  static let background = Color(red: 0.067, green: 0.071, blue: 0.071)
  static let panel = Color(red: 0.105, green: 0.11, blue: 0.11)
  static let silver = Color(red: 0.90, green: 0.89, blue: 0.86)
  static let muted = Color(red: 0.57, green: 0.58, blue: 0.56)
  static let amber = Color(red: 0.86, green: 0.66, blue: 0.38)
  static let line = Color.white.opacity(0.13)
}

struct Eyebrow: View {
  let text: String
  var body: some View {
    Text(text.uppercased())
      .font(.system(.caption2, design: .monospaced))
      .tracking(2)
      .foregroundStyle(Palette.muted)
  }
}

struct DarkroomMark: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 4).stroke(Palette.amber, lineWidth: 1)
      Circle().stroke(Palette.amber, lineWidth: 1).padding(7)
      Rectangle().fill(Palette.amber).frame(width: 1).rotationEffect(.degrees(35)).padding(6)
    }
    .frame(width: 31, height: 35)
    .accessibilityHidden(true)
  }
}

struct RoundControl: View {
  let symbol: String
  let label: String
  var action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 18, weight: .regular))
        .frame(width: 46, height: 46)
        .background(Palette.panel, in: Circle())
    }
    .foregroundStyle(Palette.silver)
    .accessibilityLabel(label)
  }
}

struct AmberButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(.subheadline, weight: .semibold))
      .foregroundStyle(Palette.background)
      .padding(.horizontal, 22)
      .frame(minHeight: 52)
      .background(
        Palette.amber.opacity(configuration.isPressed ? 0.7 : 1),
        in: RoundedRectangle(cornerRadius: 7))
  }
}

struct Hairline: View {
  var body: some View { Rectangle().fill(Palette.line).frame(height: 1) }
}
