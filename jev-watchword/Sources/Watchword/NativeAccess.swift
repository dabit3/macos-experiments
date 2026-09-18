import AppKit
import ApplicationServices
import Darwin
import Foundation
import UserNotifications
import WatchwordCore

enum NativeError: LocalizedError {
  case permission, disappeared, unreadable, tooLarge, folderChanged, actionFailed

  var errorDescription: String? {
    switch self {
    case .permission:
      return
        "Allow Watchword in System Settings → Privacy & Security → Accessibility, then refresh."
    case .disappeared: return "The selected app, window or content surface was closed or replaced."
    case .unreadable: return "This window exposes no readable AX text. Choose a supported window."
    case .tooLarge:
      return "Window text exceeds 16,000 characters or 1,200 AX elements. Use a smaller window."
    case .folderChanged: return "The selected folder moved or was replaced. Choose it again."
    case .actionFailed: return "macOS did not accept the selected action."
    }
  }
}

func axValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
    return nil
  }
  return value
}

func axString(_ element: AXUIElement, _ attribute: String) -> String {
  axValue(element, attribute) as? String ?? ""
}

func axElements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
  axValue(element, attribute) as? [AXUIElement] ?? []
}

struct WindowTarget: Identifiable {
  let id = UUID().uuidString
  let pid: pid_t
  let launchDate: Date?
  let appName: String
  let title: String
  let window: AXUIElement
  let anchor: AXUIElement?

  var label: String { "\(appName) — \(title.isEmpty ? "Untitled window" : title)" }
}

@MainActor
enum NativeAccess {
  static var trusted: Bool { AXIsProcessTrusted() }

  static func requestPermission() {
    let options =
      [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }

  static func windows() throws -> [WindowTarget] {
    guard trusted else { throw NativeError.permission }
    var result: [WindowTarget] = []
    for app in NSWorkspace.shared.runningApplications
    where app.activationPolicy == .regular
      && app.processIdentifier != ProcessInfo.processInfo.processIdentifier
    {
      let element = AXUIElementCreateApplication(app.processIdentifier)
      AXUIElementSetMessagingTimeout(element, 0.5)
      for window in axElements(element, kAXWindowsAttribute) {
        result.append(
          WindowTarget(
            pid: app.processIdentifier, launchDate: app.launchDate,
            appName: app.localizedName ?? "App",
            title: axString(window, kAXTitleAttribute), window: window,
            anchor: findAnchor(window)))
      }
    }
    return result.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
  }

  static func findAnchor(_ root: AXUIElement) -> AXUIElement? {
    var queue = [root]
    var index = 0
    while index < queue.count && index < 400 {
      let element = queue[index]
      index += 1
      if ["AXTextArea", "AXWebArea"].contains(axString(element, kAXRoleAttribute)) {
        return element
      }
      queue.append(contentsOf: axElements(element, kAXChildrenAttribute))
    }
    return nil
  }

  static func validate(_ target: WindowTarget) throws {
    guard trusted else { throw NativeError.permission }
    let element = AXUIElementCreateApplication(target.pid)
    AXUIElementSetMessagingTimeout(element, 0.5)
    AXUIElementSetMessagingTimeout(target.window, 0.5)
    guard let app = NSRunningApplication(processIdentifier: target.pid),
      !app.isTerminated, app.launchDate == target.launchDate,
      axElements(element, kAXWindowsAttribute)
        .contains(where: { CFEqual($0, target.window) })
    else { throw NativeError.disappeared }
    if let anchor = target.anchor {
      guard let current = findAnchor(target.window), CFEqual(anchor, current) else {
        throw NativeError.disappeared
      }
    }
  }

  static func snapshot(_ target: WindowTarget, sequence: Int) throws -> Snapshot {
    try validate(target)
    var queue = [target.window]
    var index = 0
    var pieces: [String] = []
    var seen = Set<String>()
    var characters = 0
    let started = Date()
    while index < queue.count {
      guard index < 1200, Date().timeIntervalSince(started) < 3 else { throw NativeError.tooLarge }
      let element = queue[index]
      index += 1
      let role = axString(element, kAXRoleAttribute)
      if role == "AXSecureTextField"
        || axString(element, kAXSubroleAttribute) == "AXSecureTextField"
      {
        continue
      }
      if ["AXTextArea", "AXTextField", "AXStaticText", "AXButton", "AXProgressIndicator"].contains(
        role)
      {
        let value = axString(element, kAXValueAttribute)
        let title = axString(element, kAXTitleAttribute)
        let text = (value.isEmpty ? title : value)
          .replacingOccurrences(
            of: #"\n[ \t]*\n(?:[ \t]*\n)+"#, with: "\n\n", options: .regularExpression
          )
          .trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty && seen.insert(text).inserted {
          characters += text.count
          guard characters <= 16_000 else { throw NativeError.tooLarge }
          pieces.append(text)
        }
      }
      queue.append(contentsOf: axElements(element, kAXChildrenAttribute))
    }
    guard !pieces.isEmpty else { throw NativeError.unreadable }
    try validate(target)
    return Snapshot(target: target.id, text: pieces.joined(separator: "\n"), sequence: sequence)
  }

  static func raise(_ target: WindowTarget) throws {
    try validate(target)
    guard AXUIElementPerformAction(target.window, kAXRaiseAction as CFString) == .success,
      let app = NSRunningApplication(processIdentifier: target.pid),
      app.activate(options: [])
    else { throw NativeError.actionFailed }
    _ = AXUIElementSetAttributeValue(target.window, kAXMainAttribute as CFString, kCFBooleanTrue)
  }

  static func isFocused(_ target: WindowTarget) -> Bool {
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid,
      let focused = axValue(AXUIElementCreateApplication(target.pid), kAXFocusedWindowAttribute)
    else { return false }
    return CFEqual(focused, target.window)
  }
}

struct SelectedFolder {
  let url: URL
  private let device: dev_t
  private let inode: ino_t

  init(url: URL) throws {
    let resolved = url.resolvingSymlinksInPath()
    var metadata = stat()
    guard stat(resolved.path, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFDIR else {
      throw NativeError.folderChanged
    }
    self.url = resolved
    device = metadata.st_dev
    inode = metadata.st_ino
  }

  func validate() throws {
    var metadata = stat()
    guard stat(url.path, &metadata) == 0,
      metadata.st_mode & S_IFMT == S_IFDIR,
      metadata.st_dev == device, metadata.st_ino == inode
    else { throw NativeError.folderChanged }
  }
}

enum FollowUp: String, CaseIterable, Identifiable {
  case notify = "Notify me"
  case reveal = "Reveal a folder"
  case raise = "Raise a window"
  var id: String { rawValue }
}

@MainActor
struct ArmedAction {
  let kind: FollowUp
  let folder: SelectedFolder?
  let window: WindowTarget?

  func validate() throws {
    switch kind {
    case .notify: break
    case .reveal:
      guard let folder else { throw NativeError.folderChanged }
      try folder.validate()
    case .raise:
      guard let window else { throw NativeError.disappeared }
      try NativeAccess.validate(window)
    }
  }

  func execute() async throws {
    try validate()
    switch kind {
    case .notify:
      let content = UNMutableNotificationContent()
      content.title = "Watchword · condition met"
      content.body = "Two fresh observations confirmed your condition."
      content.sound = .default
      try await UNUserNotificationCenter.current().add(
        UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    case .reveal:
      if let folder { NSWorkspace.shared.activateFileViewerSelecting([folder.url]) }
    case .raise:
      if let window { try NativeAccess.raise(window) }
    }
  }
}
