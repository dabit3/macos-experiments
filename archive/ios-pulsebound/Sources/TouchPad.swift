import SwiftUI
import UIKit

struct TouchPad: UIViewRepresentable {
  let label: String
  let value: String
  let action: () -> Void
  let pressed: (Bool) -> Void

  func makeUIView(context: Context) -> JumpControl {
    let view = JumpControl()
    view.isAccessibilityElement = true
    view.accessibilityTraits = .button
    view.accessibilityIdentifier = "jump"
    return view
  }

  func updateUIView(_ view: JumpControl, context: Context) {
    view.action = action
    view.pressed = pressed
    view.accessibilityLabel = label
    view.accessibilityValue = value
  }
}

final class JumpControl: UIControl {
  var action: () -> Void = {}
  var pressed: (Bool) -> Void = { _ in }

  override var canBecomeFirstResponder: Bool { true }
  override var keyCommands: [UIKeyCommand]? {
    let jump = UIKeyCommand(input: " ", modifierFlags: [], action: #selector(activate))
    jump.wantsPriorityOverSystemBehavior = true
    return [jump]
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil { becomeFirstResponder() }
  }

  override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    pressed(true)
    action()
    return true
  }

  override func endTracking(_ touch: UITouch?, with event: UIEvent?) { pressed(false) }
  override func cancelTracking(with event: UIEvent?) { pressed(false) }
  override func accessibilityActivate() -> Bool {
    action()
    return true
  }

  @objc private func activate() { action() }
}
