import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

enum PlatformActions {
  static func copy(_ text: String) {
    #if os(macOS)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(text, forType: .string)
    #else
      UIPasteboard.general.string = text
    #endif
  }
  static func haptic(success: Bool?) {
    #if os(iOS)
      if let success {
        UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .warning)
      } else {
        UISelectionFeedbackGenerator().selectionChanged()
      }
    #endif
  }
}

func pantryKey(_ value: String) -> String? {
  switch value.lowercased() {
  case "a", "left": return "left"
  case "d", "right": return "right"
  case "w", "up": return "up"
  case "s", "down": return "down"
  case " ", "j", "\r": return "grab"
  case "e", "k", "shift": return "action"
  case "f", "l": return "dash"
  case "t": return "pings"
  case "\u{1B}": return "escape"
  case "1", "2", "3", "4", "5", "6": return value
  default: return nil
  }
}

#if os(macOS)
  struct KeyboardCapture: NSViewRepresentable {
    let enabled: Bool
    let onChange: (Set<String>, String?) -> Void
    func makeNSView(context: Context) -> CaptureView { CaptureView() }
    func updateNSView(_ view: CaptureView, context: Context) {
      view.onChange = onChange
      if view.enabled && !enabled { view.keys.removeAll() }
      view.enabled = enabled
    }
    final class CaptureView: NSView {
      var enabled = false
      var onChange: ((Set<String>, String?) -> Void)?
      var keys: [UInt16: String] = [:]
      private var removeMonitor: (() -> Void)?
      override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeMonitor?()
        removeMonitor = nil
        guard window != nil else { return }
        let monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged])
        { [weak self] event in
          guard let self, self.enabled, self.window?.isKeyWindow == true,
            !event.modifierFlags.contains(.command)
          else { return event }
          let special: [UInt16: String] = [
            123: "left", 124: "right", 125: "down", 126: "up", 56: "shift", 60: "shift",
          ]
          guard
            let action = pantryKey(
              special[event.keyCode] ?? event.charactersIgnoringModifiers ?? "")
          else { return event }
          let isDown =
            event.type == .keyDown
            || (event.type == .flagsChanged && event.modifierFlags.contains(.shift))
          let fresh = isDown && self.keys[event.keyCode] == nil
          if isDown {
            self.keys[event.keyCode] = action
          } else {
            self.keys.removeValue(forKey: event.keyCode)
          }
          if !event.isARepeat { self.onChange?(Set(self.keys.values), fresh ? action : nil) }
          return nil
        }
        if let monitor { removeMonitor = { NSEvent.removeMonitor(monitor) } }
      }
      deinit { removeMonitor?() }
    }
  }
#else
  struct KeyboardCapture: UIViewRepresentable {
    let enabled: Bool
    let onChange: (Set<String>, String?) -> Void
    func makeUIView(context: Context) -> CaptureView { CaptureView() }
    func updateUIView(_ view: CaptureView, context: Context) {
      view.onChange = onChange
      if view.enabled && !enabled { view.keys.removeAll() }
      view.enabled = enabled
      if enabled && view.window != nil && !view.isFirstResponder { view.becomeFirstResponder() }
      if !enabled && view.isFirstResponder { view.resignFirstResponder() }
    }
    final class CaptureView: UIView {
      var enabled = false
      var onChange: ((Set<String>, String?) -> Void)?
      var keys: [UIKeyboardHIDUsage: String] = [:]
      override var canBecomeFirstResponder: Bool { enabled }
      override func didMoveToWindow() {
        super.didMoveToWindow()
        if enabled { becomeFirstResponder() }
      }
      private func update(_ presses: Set<UIPress>, down: Bool) -> Bool {
        guard enabled else { return false }
        var handled = false
        for press in presses {
          guard let key = press.key else { continue }
          let special: [UIKeyboardHIDUsage: String] = [
            .keyboardLeftArrow: "left", .keyboardRightArrow: "right", .keyboardUpArrow: "up",
            .keyboardDownArrow: "down",
            .keyboardLeftShift: "shift", .keyboardRightShift: "shift",
          ]
          guard !key.modifierFlags.contains(.command),
            let action = pantryKey(special[key.keyCode] ?? key.charactersIgnoringModifiers)
          else { continue }
          let fresh = down && keys[key.keyCode] == nil
          if down { keys[key.keyCode] = action } else { keys.removeValue(forKey: key.keyCode) }
          onChange?(Set(keys.values), fresh ? action : nil)
          handled = true
        }
        return handled
      }
      override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !update(presses, down: true) { super.pressesBegan(presses, with: event) }
      }
      override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !update(presses, down: false) { super.pressesEnded(presses, with: event) }
      }
      override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        _ = update(presses, down: false)
        super.pressesCancelled(presses, with: event)
      }
    }
  }
#endif
