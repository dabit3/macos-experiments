import AppKit
import ApplicationServices
import PasteCore

enum AX {
  static func value(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success else {
      return nil
    }
    return result
  }

  static func string(_ element: AXUIElement, _ key: String) -> String {
    value(element, key) as? String ?? ""
  }

  static func element(_ element: AXUIElement, _ key: String) -> AXUIElement? {
    guard let value = value(element, key), CFGetTypeID(value) == AXUIElementGetTypeID() else {
      return nil
    }
    return unsafeBitCast(value, to: AXUIElement.self)
  }

  static func children(_ element: AXUIElement) -> [AXUIElement] {
    value(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
  }

  static func range(_ element: AXUIElement) -> NSRange? {
    guard let raw = value(element, kAXSelectedTextRangeAttribute),
      CFGetTypeID(raw) == AXValueGetTypeID()
    else { return nil }
    let value = unsafeBitCast(raw, to: AXValue.self)
    guard AXValueGetType(value) == .cfRange else { return nil }
    var range = CFRange()
    guard AXValueGetValue(value, .cfRange, &range), range.location >= 0, range.length >= 0 else {
      return nil
    }
    return NSRange(location: range.location, length: range.length)
  }

  static func settable(_ element: AXUIElement, _ key: String) -> Bool {
    var result = DarwinBoolean(false)
    return AXUIElementIsAttributeSettable(element, key as CFString, &result) == .success
      && result.boolValue
  }

  static func set(_ element: AXUIElement, _ key: String, _ value: CFTypeRef) throws {
    let result = AXUIElementSetAttributeValue(element, key as CFString, value)
    guard result == .success else {
      throw PilotError.message(
        "macOS rejected \(key) (AX \(result.rawValue)). No keyboard fallback was sent.")
    }
  }

  static func secure(_ element: AXUIElement) -> Bool {
    let metadata = [
      string(element, kAXRoleAttribute), string(element, kAXSubroleAttribute),
      string(element, kAXTitleAttribute), string(element, kAXDescriptionAttribute),
      string(element, kAXHelpAttribute),
    ].joined(separator: " ").lowercased()
    return metadata.contains("secure") || metadata.contains("password")
      || metadata.contains("passcode")
      || (value(element, "AXProtectedContent") as? Bool == true)
  }

  static func context(_ element: AXUIElement, app: String, intent: String) -> FieldContext {
    var labels: [String] = []
    if let label = self.element(element, kAXTitleUIElementAttribute) {
      labels += [string(label, kAXValueAttribute), string(label, kAXTitleAttribute)].filter {
        !$0.isEmpty
      }
    }
    if let parent = self.element(element, kAXParentAttribute) {
      labels += children(parent).prefix(12).filter {
        string($0, kAXRoleAttribute) == kAXStaticTextRole
      }.map { String(string($0, kAXValueAttribute).prefix(160)) }
    }
    let title = [
      string(element, kAXTitleAttribute), string(element, kAXDescriptionAttribute),
      string(element, kAXPlaceholderValueAttribute),
    ].filter { !$0.isEmpty }.joined(separator: " · ")
    return FieldContext(
      app: app, role: string(element, kAXRoleAttribute), title: String(title.prefix(500)),
      help: String(string(element, kAXHelpAttribute).prefix(500)),
      labels: Array(labels.prefix(8)), intent: intent)
  }

  static func find(
    _ root: AXUIElement, matching predicate: (AXUIElement) -> Bool, budget: Int = 250
  ) -> AXUIElement? {
    var queue = [root]
    var visited = 0
    while !queue.isEmpty && visited < budget {
      let current = queue.removeFirst()
      visited += 1
      if predicate(current) { return current }
      queue.append(contentsOf: children(current).prefix(40))
    }
    return nil
  }
}

struct TargetSnapshot {
  let application: NSRunningApplication
  let appElement: AXUIElement
  let element: AXUIElement
  let window: AXUIElement
  let version: FieldVersion
  let context: FieldContext
  let launchDate: Date?

  @MainActor
  static func capture(intent: String, app: NSRunningApplication? = nil) throws -> TargetSnapshot {
    guard AXIsProcessTrusted() else {
      throw PilotError.message(
        "Enable PastePilot in System Settings → Privacy & Security → Accessibility, then relaunch.")
    }
    guard let application = app ?? NSWorkspace.shared.frontmostApplication,
      application.processIdentifier != ProcessInfo.processInfo.processIdentifier
    else { throw PilotError.message("Focus a field in another app, then press ⌘⇧V.") }
    let root = AXUIElementCreateApplication(application.processIdentifier)
    AXUIElementSetMessagingTimeout(root, 2)
    guard let element = AX.element(root, kAXFocusedUIElementAttribute) else {
      throw PilotError.message("This app did not expose a focused Accessibility field.")
    }
    guard !AX.secure(element) else {
      throw PilotError.message("Secure fields are never read or written.")
    }
    let role = AX.string(element, kAXRoleAttribute)
    guard [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role),
      let window = AX.element(element, kAXWindowAttribute)
        ?? AX.element(root, kAXFocusedWindowAttribute)
    else {
      throw PilotError.message(
        "Focus an editable text field. This Accessibility role is unsupported.")
    }
    let context = AX.context(
      element, app: application.localizedName ?? "Unknown app", intent: intent)
    let version = try makeVersion(application: application, element: element, context: context)
    return TargetSnapshot(
      application: application, appElement: root, element: element, window: window,
      version: version, context: context, launchDate: application.launchDate)
  }

  static func makeVersion(
    application: NSRunningApplication, element: AXUIElement,
    context: FieldContext
  ) throws -> FieldVersion {
    guard let value = AX.value(element, kAXValueAttribute) as? String, value.utf16.count <= 20_000
    else {
      throw PilotError.message(
        "Field content is unavailable or exceeds 20,000 characters. Cannot safely verify edits.")
    }
    let label = [context.title, context.help, context.labels.joined(separator: "|")].joined(
      separator: "\n")
    return FieldVersion(
      identity: "\(application.processIdentifier):\(application.bundleIdentifier ?? "")",
      role: AX.string(element, kAXRoleAttribute), label: label, value: value,
      selection: AX.range(element))
  }

  @MainActor
  func validate() throws {
    guard !application.isTerminated, application.launchDate == launchDate,
      let focused = AX.element(appElement, kAXFocusedUIElementAttribute),
      let window = AX.element(element, kAXWindowAttribute)
        ?? AX.element(appElement, kAXFocusedWindowAttribute),
      let front = NSWorkspace.shared.frontmostApplication,
      [application.processIdentifier, ProcessInfo.processInfo.processIdentifier].contains(
        front.processIdentifier)
    else {
      throw PilotError.message("Target app, window or focus changed. Inspect the field again.")
    }
    guard !AX.secure(element) else {
      throw PilotError.message("Secure fields are never read or written.")
    }
    let current = try Self.makeVersion(
      application: application, element: element,
      context: AX.context(element, app: context.app, intent: context.intent))
    try version.validate(
      against: current, sameElement: CFEqual(focused, element),
      sameWindow: CFEqual(window, self.window), focused: true, secure: false)
  }
}

struct UndoEdit {
  let after: TargetSnapshot
  let original: String
  let originalSelection: NSRange?
}

@MainActor
enum FieldAction {
  static func paste(_ text: String, into target: TargetSnapshot) async throws -> UndoEdit {
    try target.validate()
    target.application.activate(options: [])
    try await Task.sleep(for: .milliseconds(120))
    try target.validate()
    let expected: String
    if target.version.role == kAXTextAreaRole {
      guard let range = target.version.selection,
        NSMaxRange(range) <= (target.version.value as NSString).length,
        AX.settable(target.element, kAXSelectedTextAttribute)
      else {
        throw PilotError.message(
          "This editor cannot safely replace selected text through Accessibility.")
      }
      expected = (target.version.value as NSString).replacingCharacters(in: range, with: text)
      try AX.set(target.element, kAXSelectedTextAttribute, text as CFString)
    } else {
      guard AX.settable(target.element, kAXValueAttribute) else {
        throw PilotError.message(
          "This field does not permit AXValue edits. Copy exact value and paste manually.")
      }
      expected = text
      try AX.set(target.element, kAXValueAttribute, text as CFString)
    }
    try await Task.sleep(for: .milliseconds(100))
    guard AX.string(target.element, kAXValueAttribute) == expected else {
      throw PilotError.message(
        "The app changed the inserted text. Readback differs; inspect the field before continuing.")
    }
    let after = try TargetSnapshot.capture(intent: target.context.intent, app: target.application)
    guard CFEqual(after.element, target.element), CFEqual(after.window, target.window) else {
      throw PilotError.message("The app moved focus after editing. Undo is unavailable.")
    }
    return UndoEdit(
      after: after, original: target.version.value, originalSelection: target.version.selection)
  }

  static func undo(_ edit: UndoEdit) async throws {
    try edit.after.validate()
    guard AX.settable(edit.after.element, kAXValueAttribute) else {
      throw PilotError.message(
        "This app does not support verified undo via AXValue. Use its native Undo command.")
    }
    edit.after.application.activate(options: [])
    try await Task.sleep(for: .milliseconds(120))
    try edit.after.validate()
    try AX.set(edit.after.element, kAXValueAttribute, edit.original as CFString)
    if let original = edit.originalSelection,
      AX.settable(edit.after.element, kAXSelectedTextRangeAttribute)
    {
      var range = CFRange(location: original.location, length: original.length)
      if let value = AXValueCreate(.cfRange, &range) {
        try AX.set(edit.after.element, kAXSelectedTextRangeAttribute, value)
      }
    }
    guard AX.string(edit.after.element, kAXValueAttribute) == edit.original else {
      throw PilotError.message("Undo readback failed. Inspect the original app.")
    }
  }
}
