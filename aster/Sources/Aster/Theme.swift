import SwiftUI

enum Theme {
  static let background = Color(red: 0.024, green: 0.043, blue: 0.075)
  static let panel = Color(red: 0.043, green: 0.070, blue: 0.108)
  static let line = Color(red: 0.15, green: 0.21, blue: 0.27)
  static let muted = Color(red: 0.54, green: 0.64, blue: 0.72)
  static let cyan = Color(red: 0.40, green: 0.89, blue: 0.93)
  static let amber = Color(red: 1.0, green: 0.72, blue: 0.37)
  static let green = Color(red: 0.54, green: 0.91, blue: 0.72)
}

struct InstrumentButton: ButtonStyle {
  var primary = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .semibold))
      .padding(.horizontal, 14).padding(.vertical, 10)
      .foregroundStyle(primary ? Theme.background : Color.white.opacity(0.9))
      .background(primary ? Theme.amber : Theme.line.opacity(configuration.isPressed ? 0.7 : 0.3))
      .clipShape(RoundedRectangle(cornerRadius: 7))
      .overlay(
        RoundedRectangle(cornerRadius: 7).stroke(primary ? .clear : Theme.line, lineWidth: 1)
      )
      .opacity(configuration.isPressed ? 0.75 : 1)
  }
}

struct Eyebrow: View {
  let text: String
  var color: Color = Theme.muted
  var body: some View {
    Text(text).font(.system(size: 10, weight: .semibold, design: .monospaced))
      .tracking(1.8).foregroundStyle(color)
  }
}

func number(_ value: Double, digits: Int = 0) -> String {
  value.formatted(.number.precision(.fractionLength(digits)))
}
