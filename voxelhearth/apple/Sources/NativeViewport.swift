import MetalKit
import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

@MainActor final class Viewport: MTKView {
  var game: Game?
  var renderer: VoxelRenderer?
  #if os(macOS)
    var captured = false
    var tracking: NSTrackingArea?
    private var blurObserver: NSObjectProtocol?
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if let blurObserver { NotificationCenter.default.removeObserver(blurObserver) }
      blurObserver = NotificationCenter.default.addObserver(
        forName: NSWindow.didResignKeyNotification, object: window, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.releasePointer()
          self?.game?.resetInput()
          if self?.game?.session.phase == "playing" { self?.game?.paused = true }
        }
      }
      if window == nil { releasePointer() }
    }
    override func updateTrackingAreas() {
      super.updateTrackingAreas()
      if let tracking { removeTrackingArea(tracking) }
      tracking = NSTrackingArea(
        rect: bounds, options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved], owner: self)
      if let tracking { addTrackingArea(tracking) }
    }
    func releasePointer() {
      guard captured else { return }
      captured = false
      CGAssociateMouseAndMouseCursorPosition(1)
      NSCursor.unhide()
    }
    override func mouseDown(with event: NSEvent) {
      guard let game, !game.blocked else { return }
      window?.makeFirstResponder(self)
      if !captured {
        captured = true
        NSCursor.hide()
        CGAssociateMouseAndMouseCursorPosition(0)
      } else {
        game.startBreak()
      }
    }
    override func mouseUp(with event: NSEvent) { game?.breaking = false }
    override func rightMouseDown(with event: NSEvent) { game?.use() }
    override func mouseMoved(with event: NSEvent) {
      if captured { game?.look(event.deltaX, event.deltaY) }
    }
    override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }
    override func rightMouseDragged(with event: NSEvent) { mouseMoved(with: event) }
    override func scrollWheel(with event: NSEvent) {
      guard let game, !game.blocked else { return }
      game.session.select((game.session.selected + (event.scrollingDeltaY > 0 ? 8 : 1)) % 9)
    }
    override func keyDown(with event: NSEvent) {
      if event.isARepeat { return }
      let mapped: [UInt16: String] = [53: "escape", 123: "a", 124: "d", 125: "s", 126: "w"]
      game?.key(
        mapped[event.keyCode] ?? event.charactersIgnoringModifiers?.lowercased() ?? "", down: true)
      if game?.blocked == true { releasePointer() }
    }
    override func keyUp(with event: NSEvent) {
      let mapped: [UInt16: String] = [123: "a", 124: "d", 125: "s", 126: "w"]
      game?.key(
        mapped[event.keyCode] ?? event.charactersIgnoringModifiers?.lowercased() ?? "", down: false)
    }
    override func flagsChanged(with event: NSEvent) {
      game?.key("shift", down: event.modifierFlags.contains(.shift))
      game?.key("control", down: event.modifierFlags.contains(.control))
      game?.key("command", down: event.modifierFlags.contains(.command))
    }
    deinit { if let blurObserver { NotificationCenter.default.removeObserver(blurObserver) } }
  #else
    var lookTouch: UITouch?
    var startPoint = CGPoint.zero
    var previousPoint = CGPoint.zero
    var started = 0.0
    var hold: Task<Void, Never>?
    override var canBecomeFirstResponder: Bool { true }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard lookTouch == nil, let touch = touches.first, game?.blocked == false else { return }
      becomeFirstResponder()
      lookTouch = touch
      startPoint = touch.location(in: self)
      previousPoint = startPoint
      started = touch.timestamp
      hold = Task { [weak self] in
        do { try await Task.sleep(for: .milliseconds(220)) } catch { return }
        self?.game?.startBreak()
      }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let touch = lookTouch, touches.contains(touch) else { return }
      let point = touch.location(in: self)
      if hypot(point.x - startPoint.x, point.y - startPoint.y) > 6 { hold?.cancel() }
      game?.look((point.x - previousPoint.x) * 1.6, (point.y - previousPoint.y) * 1.6)
      previousPoint = point
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let touch = lookTouch, touches.contains(touch) else { return }
      hold?.cancel()
      game?.breaking = false
      lookTouch = nil
      if touch.timestamp - started < 0.22
        && hypot(previousPoint.x - startPoint.x, previousPoint.y - startPoint.y) < 6
      {
        game?.startBreak()
        hold = Task { [weak self] in
          try? await Task.sleep(for: .milliseconds(150))
          self?.game?.breaking = false
        }
      }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
      hold?.cancel()
      lookTouch = nil
      game?.breaking = false
    }
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      for press in presses {
        if let key = press.key {
          game?.key(keyName(key), down: true)
        }
      }
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      for press in presses { if let key = press.key { game?.key(keyName(key), down: false) } }
    }
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      game?.resetInput()
    }
    private func keyName(_ key: UIKey) -> String {
      let special: [UIKeyboardHIDUsage: String] = [
        .keyboardEscape: "escape", .keyboardUpArrow: "w", .keyboardDownArrow: "s",
        .keyboardLeftArrow: "a", .keyboardRightArrow: "d",
        .keyboardLeftShift: "shift", .keyboardRightShift: "shift",
        .keyboardLeftControl: "control", .keyboardRightControl: "control",
      ]
      return special[key.keyCode] ?? key.charactersIgnoringModifiers.lowercased()
    }
  #endif
  func configure(_ game: Game) {
    self.game = game
    guard let device = MTLCreateSystemDefaultDevice() else {
      game.session.error = "This device does not support Metal."
      return
    }
    self.device = device
    colorPixelFormat = .bgra8Unorm
    autoResizeDrawable = false
    preferredFramesPerSecond = 60
    do {
      renderer = try VoxelRenderer(game: game, device: device)
      delegate = renderer
    } catch { game.session.error = "The native renderer could not start: \(error)" }
  }
}

#if os(macOS)
  struct NativeViewport: NSViewRepresentable {
    @ObservedObject var game: Game
    func makeNSView(context: Context) -> Viewport {
      let view = Viewport()
      view.configure(game)
      return view
    }
    func updateNSView(_ view: Viewport, context: Context) {
      if game.blocked { view.releasePointer() }
    }
    static func dismantleNSView(_ view: Viewport, coordinator: ()) {
      view.releasePointer()
      view.isPaused = true
    }
  }
#else
  struct NativeViewport: UIViewRepresentable {
    @ObservedObject var game: Game
    func makeUIView(context: Context) -> Viewport {
      let view = Viewport()
      view.isMultipleTouchEnabled = true
      view.configure(game)
      return view
    }
    func updateUIView(_ view: Viewport, context: Context) {}
    static func dismantleUIView(_ view: Viewport, coordinator: ()) {
      view.hold?.cancel()
      view.isPaused = true
    }
  }
#endif
