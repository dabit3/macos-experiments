import SpriteKit
import SwiftUI

#if os(iOS)
  import UIKit

  @MainActor final class GamePlatformView: SKView {
    weak var model: AppModel?
    override var canBecomeFirstResponder: Bool { true }
    override func didMoveToWindow() {
      super.didMoveToWindow()
      if window != nil { becomeFirstResponder() }
    }
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      for press in presses { if let key = press.key { model?.control(name(key), down: true) } }
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      for press in presses { if let key = press.key { model?.control(name(key), down: false) } }
    }
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      pressesEnded(presses, with: event)
    }
    private func name(_ key: UIKey) -> String {
      switch key.keyCode {
      case .keyboardUpArrow: return "up"
      case .keyboardDownArrow: return "down"
      case .keyboardLeftArrow: return "left"
      case .keyboardRightArrow: return "right"
      case .keyboardSpacebar: return "space"
      case .keyboardReturnOrEnter: return "return"
      case .keyboardEscape: return "escape"
      case .keyboardLeftShift, .keyboardRightShift: return "shift"
      case .keyboardLeftControl, .keyboardRightControl: return "control"
      case .keyboardLeftAlt, .keyboardRightAlt: return "option"
      default: return key.charactersIgnoringModifiers.lowercased()
      }
    }
  }
  struct GameSurface: UIViewRepresentable {
    let scene: RaceScene, model: AppModel
    func makeUIView(context: Context) -> GamePlatformView {
      let view = GamePlatformView()
      view.model = model
      view.preferredFramesPerSecond = 60
      view.ignoresSiblingOrder = true
      view.presentScene(scene)
      return view
    }
    func updateUIView(_ view: GamePlatformView, context: Context) {}
  }
#else
  import AppKit

  @MainActor final class GamePlatformView: SKView {
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      window?.makeFirstResponder(self)
    }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
  }
  struct GameSurface: NSViewRepresentable {
    let scene: RaceScene, model: AppModel
    func makeNSView(context: Context) -> GamePlatformView {
      let view = GamePlatformView()
      view.preferredFramesPerSecond = 60
      view.ignoresSiblingOrder = true
      view.presentScene(scene)
      return view
    }
    func updateNSView(_ view: GamePlatformView, context: Context) {}
  }
#endif
