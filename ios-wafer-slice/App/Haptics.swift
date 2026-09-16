import UIKit

final class Haptics {
  var enabled = true

  private let light = UIImpactFeedbackGenerator(style: .light)
  private let medium = UIImpactFeedbackGenerator(style: .medium)
  private let heavy = UIImpactFeedbackGenerator(style: .heavy)
  private let rigid = UIImpactFeedbackGenerator(style: .rigid)
  private let notification = UINotificationFeedbackGenerator()
  private let selection = UISelectionFeedbackGenerator()

  init() { prepare() }

  func prepare() {
    light.prepare()
    medium.prepare()
    heavy.prepare()
    rigid.prepare()
    notification.prepare()
  }

  func slice(swipeCount: Int) {
    guard enabled else { return }
    switch swipeCount {
    case 0...1: light.impactOccurred(intensity: 0.8)
    case 2: medium.impactOccurred(intensity: 0.9)
    default: rigid.impactOccurred(intensity: 1)
    }
  }

  func defective() {
    guard enabled else { return }
    notification.notificationOccurred(.error)
    heavy.impactOccurred()
  }

  func flagship() {
    guard enabled else { return }
    notification.notificationOccurred(.success)
  }

  func binning() {
    guard enabled else { return }
    heavy.impactOccurred(intensity: 1)
  }

  func tap() {
    guard enabled else { return }
    selection.selectionChanged()
  }
}
