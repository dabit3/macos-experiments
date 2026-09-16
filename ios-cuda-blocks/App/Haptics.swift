import UIKit

enum Haptics {
  private static let light = UIImpactFeedbackGenerator(style: .light)
  private static let medium = UIImpactFeedbackGenerator(style: .medium)
  private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
  private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
  private static let notify = UINotificationFeedbackGenerator()
  private static let selection = UISelectionFeedbackGenerator()

  static var isEnabled = true

  static func prepare() {
    light.prepare()
    medium.prepare()
    heavy.prepare()
    rigid.prepare()
  }

  static func tick() {
    guard isEnabled else { return }
    selection.selectionChanged()
  }

  static func soft() {
    guard isEnabled else { return }
    light.impactOccurred(intensity: 0.6)
  }

  static func lock() {
    guard isEnabled else { return }
    rigid.impactOccurred(intensity: 0.9)
  }

  static func drop() {
    guard isEnabled else { return }
    heavy.impactOccurred()
  }

  static func clear(count: Int) {
    guard isEnabled else { return }
    medium.impactOccurred(intensity: min(1, 0.6 + Double(count) * 0.1))
  }

  static func tensor() {
    guard isEnabled else { return }
    notify.notificationOccurred(.success)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { heavy.impactOccurred() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { heavy.impactOccurred() }
  }

  static func failure() {
    guard isEnabled else { return }
    notify.notificationOccurred(.error)
  }
}
