import AppKit
import ApplicationServices
import StageCore

struct AppChoice: Identifiable {
  let id: pid_t
  let name: String
  let icon: NSImage?
}

final class WindowTarget: Identifiable {
  let id = UUID()
  let pid: pid_t
  let launchDate: Date?
  let element: AXUIElement
  let appName: String
  var title: String

  init(pid: pid_t, element: AXUIElement, appName: String, title: String) {
    self.pid = pid
    self.launchDate = NSRunningApplication(processIdentifier: pid)?.launchDate
    self.element = element
    self.appName = appName
    self.title = title
  }
}

enum AXReader {
  static var trusted: Bool { AXIsProcessTrusted() }

  static func requestPermission() {
    AXIsProcessTrustedWithOptions(
      [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
  }

  static func apps() -> [AppChoice] {
    NSWorkspace.shared.runningApplications
      .filter { $0.activationPolicy == .regular && $0.processIdentifier != getpid() }
      .map {
        AppChoice(id: $0.processIdentifier, name: $0.localizedName ?? "Application", icon: $0.icon)
      }
      .sorted { $0.name < $1.name }
  }

  static func string(_ element: AXUIElement, _ attribute: String) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
      return nil
    }
    return value as? String
  }

  static func elements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement]? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
      return nil
    }
    return value as? [AXUIElement]
  }

  static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
      return nil
    }
    return value as? Bool
  }

  static func windows(pid: pid_t, appName: String) -> [WindowTarget] {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.3)
    return (elements(app, kAXWindowsAttribute) ?? []).compactMap { element in
      guard bool(element, kAXMinimizedAttribute) != true,
        let title = string(element, kAXTitleAttribute)
      else { return nil }
      return WindowTarget(
        pid: pid, element: element, appName: appName,
        title: title.isEmpty ? "Untitled window" : title)
    }
  }

  static func isCurrent(_ target: WindowTarget) -> Bool {
    guard let app = NSRunningApplication(processIdentifier: target.pid), !app.isTerminated,
      app.launchDate == target.launchDate
    else { return false }
    let element = AXUIElementCreateApplication(target.pid)
    AXUIElementSetMessagingTimeout(element, 0.3)
    return (elements(element, kAXWindowsAttribute) ?? []).contains { CFEqual($0, target.element) }
  }

  static func frame(_ target: WindowTarget) -> CGRect? {
    guard bool(target.element, kAXMinimizedAttribute) != true else { return nil }
    var position: CFTypeRef?
    var size: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(target.element, kAXPositionAttribute as CFString, &position)
        == .success,
      AXUIElementCopyAttributeValue(target.element, kAXSizeAttribute as CFString, &size)
        == .success,
      let position, let size, CFGetTypeID(position) == AXValueGetTypeID(),
      CFGetTypeID(size) == AXValueGetTypeID()
    else { return nil }
    var point = CGPoint.zero
    var dimensions = CGSize.zero
    guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &point),
      AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &dimensions),
      dimensions.width > 0, dimensions.height > 0,
      point.x.isFinite, point.y.isFinite, dimensions.width.isFinite, dimensions.height.isFinite
    else { return nil }
    let mainHeight = NSScreen.screens.first?.frame.height ?? 0
    return CGRect(
      x: point.x, y: mainHeight - point.y - dimensions.height,
      width: dimensions.width, height: dimensions.height)
  }

  static func capture(_ target: WindowTarget) -> Evidence {
    guard isCurrent(target), frame(target) != nil else {
      return Evidence(
        identity: target.id.uuidString, title: target.title, text: "", complete: false)
    }
    let title = string(target.element, kAXTitleAttribute) ?? target.title
    var stack: [(AXUIElement, Int)] = [(target.element, 0)]
    var texts: [String] = []
    var seen = Set<String>()
    var nodes = 0
    var characters = 0
    var complete = true
    let deadline = Date().addingTimeInterval(1.5)
    while let (element, depth) = stack.popLast() {
      nodes += 1
      if nodes > 180 || characters >= 6000 || Date() > deadline {
        complete = false
        break
      }
      if bool(element, "AXHidden") == true { continue }
      let role = string(element, kAXRoleAttribute) ?? ""
      let subrole = string(element, kAXSubroleAttribute) ?? ""
      if subrole == kAXSecureTextFieldSubrole { continue }
      if [kAXTextAreaRole, kAXTextFieldRole, kAXStaticTextRole].contains(role) {
        if let value = string(element, kAXValueAttribute), !value.isEmpty,
          seen.insert(value).inserted
        {
          let clipped = String(value.prefix(max(0, 6000 - characters)))
          texts.append(clipped)
          characters += clipped.count
          if clipped.count < value.count { complete = false }
        }
      }
      let children = elements(element, kAXChildrenAttribute) ?? []
      if depth >= 12 && !children.isEmpty { complete = false }
      if depth < 12 { stack.append(contentsOf: children.reversed().map { ($0, depth + 1) }) }
    }
    return Evidence(
      identity: target.id.uuidString, title: title,
      text: texts.joined(separator: "\n\n"), complete: complete && !texts.isEmpty)
  }
}
