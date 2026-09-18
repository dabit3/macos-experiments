import AppKit
import ApplicationServices
import Foundation

public enum AX {
  public static func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
      return nil
    }
    return value
  }

  public static func string(_ element: AXUIElement, _ name: String) -> String {
    value(element, name) as? String ?? ""
  }

  public static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
    guard let value = value(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else {
      return nil
    }
    return (value as! AXUIElement)
  }

  public static func children(_ element: AXUIElement) -> [AXUIElement] {
    value(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
  }

  public static func range(_ element: AXUIElement) -> CFRange? {
    guard let value = value(element, kAXSelectedTextRangeAttribute),
      CFGetTypeID(value) == AXValueGetTypeID()
    else { return nil }
    var range = CFRange()
    guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
    return range
  }
}

@MainActor
public final class MenuSnapshot {
  public let pid: pid_t
  public let launchDate: Date?
  public let context: MenuContext
  public let candidates: [MenuCandidate]
  public let capturedAt = Date()
  public let stateHash: String
  public let windowElement: AXUIElement
  public let focusElement: AXUIElement
  public let elements: [String: AXUIElement]
  public let truncated: Bool

  init(
    app: NSRunningApplication, context: MenuContext, candidates: [MenuCandidate],
    stateHash: String, window: AXUIElement, focus: AXUIElement,
    elements: [String: AXUIElement], truncated: Bool
  ) {
    pid = app.processIdentifier
    launchDate = app.launchDate
    self.context = context
    self.candidates = candidates
    self.stateHash = stateHash
    windowElement = window
    focusElement = focus
    self.elements = elements
    self.truncated = truncated
  }
}

@MainActor
public enum NativeMenus {
  public static var trusted: Bool { AXIsProcessTrusted() }

  public static func requestPermission() {
    let options =
      [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }

  public static func capture(_ app: NSRunningApplication) throws -> MenuSnapshot {
    guard trusted else {
      throw LensError.message(
        "Enable MenuLens in System Settings → Privacy & Security → Accessibility, then retry.")
    }
    guard !app.isTerminated, app.processIdentifier != ProcessInfo.processInfo.processIdentifier
    else {
      throw LensError.message("Focus TextEdit, Finder or Safari, then press ⌃⌥Space.")
    }
    let application = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(application, 2)
    guard let menu = AX.element(application, kAXMenuBarAttribute),
      let window = AX.element(application, kAXFocusedWindowAttribute),
      let focus = AX.element(application, kAXFocusedUIElementAttribute)
    else {
      throw LensError.message(
        "No accessible menu and focused window. Open a document or Finder window first.")
    }
    let bundleID = app.bundleIdentifier ?? ""
    let context = MenuContext(
      app: app.localizedName ?? "Unknown app", bundleID: bundleID,
      window: AX.string(window, kAXTitleAttribute),
      selection: String(AX.string(focus, kAXSelectedTextAttribute).prefix(180)),
      focusedRole: AX.string(focus, kAXRoleAttribute)
    )
    var candidates: [MenuCandidate] = []
    var elements: [String: AXUIElement] = [:]
    var visited = 0
    var truncated = false
    func walk(_ node: AXUIElement, path: [String], address: [Int], depth: Int) {
      visited += 1
      guard visited <= 3000, depth <= 12, candidates.count < 500 else {
        truncated = true
        return
      }
      let role = AX.string(node, kAXRoleAttribute)
      let title = AX.string(node, kAXTitleAttribute)
      var path = path
      if !title.isEmpty && (role == kAXMenuBarItemRole || role == kAXMenuItemRole) {
        path.append(title)
      }
      let children = AX.children(node)
      if role == kAXMenuItemRole && !title.isEmpty && children.isEmpty {
        let enabled = (AX.value(node, kAXEnabledAttribute) as? Bool) ?? false
        let mark = AX.string(node, kAXMenuItemMarkCharAttribute)
        let character = AX.string(node, kAXMenuItemCmdCharAttribute)
        let modifiers = (AX.value(node, kAXMenuItemCmdModifiersAttribute) as? Int) ?? 0
        let shortcut =
          character.isEmpty
          ? ""
          : "\(modifiers & 8 == 0 ? "⌘" : "")\(modifiers & 4 != 0 ? "⌃" : "")\(modifiers & 2 != 0 ? "⌥" : "")\(modifiers & 1 != 0 ? "⇧" : "")\(character.uppercased())"
        let id = "m_" + address.map(String.init).joined(separator: "_")
        candidates.append(
          MenuCandidate(
            id: id, path: path, enabled: enabled, checked: !mark.isEmpty, shortcut: shortcut,
            permitted: GuardPolicy.permits(bundleID: bundleID, path: path)
          ))
        elements[id] = node
      } else {
        for (index, child) in children.enumerated() {
          walk(child, path: path, address: address + [index], depth: depth + 1)
        }
      }
    }
    walk(menu, path: [], address: [], depth: 0)
    guard !candidates.isEmpty else {
      throw LensError.message("This app did not expose menu commands through Accessibility.")
    }
    return MenuSnapshot(
      app: app, context: context, candidates: candidates,
      stateHash: stateHash(window: window, focus: focus), window: window, focus: focus,
      elements: elements, truncated: truncated
    )
  }

  public static func stateHash(window: AXUIElement, focus: AXUIElement) -> String {
    let range = AX.range(focus)
    let selected = (AX.value(focus, kAXSelectedChildrenAttribute) as? [AXUIElement] ?? [])
      .map {
        CFHash($0).description + AX.string($0, kAXTitleAttribute) + AX.string($0, kAXValueAttribute)
      }
    return digest(
      [
        AX.string(window, kAXTitleAttribute), AX.string(window, kAXDocumentAttribute),
        AX.string(focus, kAXValueAttribute), AX.string(focus, kAXSelectedTextAttribute),
        "\(range?.location ?? -1):\(range?.length ?? -1)", selected.joined(separator: "|"),
      ].joined(separator: "\u{0}"))
  }

  public static func execute(_ candidate: MenuCandidate, snapshot: MenuSnapshot) async throws
    -> String
  {
    guard let app = NSRunningApplication(processIdentifier: snapshot.pid),
      app.launchDate == snapshot.launchDate, app.bundleIdentifier == snapshot.context.bundleID
    else { throw LensError.message("The original app exited or restarted. Capture again.") }
    let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
    guard frontPID == snapshot.pid || frontPID == ProcessInfo.processInfo.processIdentifier else {
      throw LensError.message("Another app is now active. Capture its menus instead.")
    }
    app.activate()
    try await Task.sleep(nanoseconds: 180_000_000)
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == snapshot.pid else {
      throw LensError.message("Could not activate the observed app. Nothing was executed.")
    }
    let current = try capture(app)
    guard CFEqual(snapshot.windowElement, current.windowElement),
      CFEqual(snapshot.focusElement, current.focusElement),
      let fresh = current.candidates.first(where: { $0.id == candidate.id }),
      let element = current.elements[candidate.id],
      let originalElement = snapshot.elements[candidate.id],
      CFEqual(originalElement, element)
    else {
      throw LensError.message("The target window, focus or menu identity changed. Capture again.")
    }
    try GuardPolicy.validate(
      original: candidate, current: fresh, originalState: snapshot.stateHash,
      currentState: current.stateHash, age: Date().timeIntervalSince(snapshot.capturedAt)
    )
    let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
    guard result == .success else {
      throw LensError.message(
        "macOS refused AXPress (\(result.rawValue)). No successful action was reported.")
    }
    try await Task.sleep(nanoseconds: 220_000_000)
    let after = try capture(app)
    if after.stateHash != current.stateHash {
      return "AXPress succeeded • target state changed on readback"
    }
    if after.candidates != current.candidates {
      return "AXPress succeeded • menu state changed on readback"
    }
    return "AXPress accepted • no observable state change; verify in the target app"
  }
}
