import UIKit

enum Haptics {
  static func marked(_ marked: Bool) {
    UIImpactFeedbackGenerator(style: marked ? .light : .medium).impactOccurred()
  }

  static func success() {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
  }
}
