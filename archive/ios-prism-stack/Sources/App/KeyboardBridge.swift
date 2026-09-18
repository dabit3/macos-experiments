import SwiftUI
import UIKit

struct KeyboardBridge: UIViewControllerRepresentable {
  let model: GameModel

  func makeUIViewController(context: Context) -> PrismKeyController {
    let controller = PrismKeyController()
    controller.model = model
    return controller
  }

  func updateUIViewController(_ controller: PrismKeyController, context: Context) {
    controller.model = model
  }
}

final class PrismKeyController: UIViewController {
  var model: GameModel?
  override var canBecomeFirstResponder: Bool { true }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    becomeFirstResponder()
  }

  override var keyCommands: [UIKeyCommand]? {
    [
      command(UIKeyCommand.inputLeftArrow, "Move left"),
      command(UIKeyCommand.inputRightArrow, "Move right"),
      command(UIKeyCommand.inputDownArrow, "Soft drop"),
      command(UIKeyCommand.inputUpArrow, "Rotate"),
      command("x", "Rotate"),
      command(" ", "Hard drop"),
      command("c", "Hold"),
      command(UIKeyCommand.inputEscape, "Pause or resume"),
    ]
  }

  private func command(_ key: String, _ title: String) -> UIKeyCommand {
    let command = UIKeyCommand(
      title: title, action: #selector(keyPressed(_:)), input: key, modifierFlags: [])
    command.wantsPriorityOverSystemBehavior = true
    return command
  }

  @objc private func keyPressed(_ command: UIKeyCommand) {
    guard let model else { return }
    switch command.input {
    case UIKeyCommand.inputLeftArrow: model.act(.left)
    case UIKeyCommand.inputRightArrow: model.act(.right)
    case UIKeyCommand.inputDownArrow: model.act(.softDrop)
    case UIKeyCommand.inputUpArrow, "x": model.act(.rotate)
    case " ": model.act(.hardDrop)
    case "c": model.act(.hold)
    case UIKeyCommand.inputEscape:
      if model.screen == .paused { model.resume() } else { model.pause() }
    default: break
    }
  }
}
