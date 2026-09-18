import AppKit
import ApplicationServices
import Foundation

@MainActor
public final class NativeWindows {
  struct Handle {
    let element: AXUIElement
    let app: NSRunningApplication
    let evidence: WindowEvidence
  }
  struct UndoEntry {
    let handle: Handle
    let frame: Frame
    let minimized: Bool
    var afterFrame: Frame?
    var afterMinimized: Bool?
  }
  private var handles: [UUID: Handle] = [:]
  private var undoEntries: [UndoEntry] = []
  private var previousApp: NSRunningApplication?
  private var operating = false
  public private(set) var notices: [String] = []
  public var canUndo: Bool { !undoEntries.isEmpty }
  public var trusted: Bool { AXIsProcessTrusted() }

  public init() {}

  public func requestPermission() {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    NSWorkspace.shared.open(
      URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
  }

  public func availableApps() -> [NSRunningApplication] {
    NSWorkspace.shared.runningApplications.filter {
      $0.activationPolicy == .regular
        && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
    }.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
  }

  public func capture(bundleIDs: Set<String>) throws -> [WindowEvidence] {
    guard !operating else {
      throw DeckError.message("Wait for the current window action to finish.")
    }
    guard trusted else {
      throw DeckError.message(
        "Enable TaskDeck in System Settings → Privacy & Security → Accessibility, then scan again.")
    }
    notices = []
    handles = [:]
    var result: [WindowEvidence] = []
    for app in availableApps() where bundleIDs.contains(app.bundleIdentifier ?? "") {
      let root = AXUIElementCreateApplication(app.processIdentifier)
      AXUIElementSetMessagingTimeout(root, 0.3)
      let windows = elements(root, kAXWindowsAttribute)
      if windows.isEmpty { notices.append("\(app.localizedName ?? "App"): no accessible windows.") }
      for window in windows {
        guard result.count < 40 else {
          notices.append("40-window capture limit reached. Narrow the app scope.")
          return result
        }
        if bool(window, "AXFullScreen") {
          notices.append("\(app.localizedName ?? "App"): full-screen window skipped.")
          continue
        }
        guard string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole,
          frame(window) != nil
        else { continue }
        let evidence = observe(window, app: app)
        handles[evidence.id] = Handle(element: window, app: app, evidence: evidence)
        result.append(evidence)
      }
    }
    return result
  }

  public func arrange(ids: [UUID], screen: NSScreen? = nil) async throws -> [String] {
    guard !operating else { throw DeckError.message("A window action is already running.") }
    operating = true
    defer { operating = false }
    guard !canUndo else {
      throw DeckError.message("Undo the current layout before composing another task.")
    }
    guard (1...4).contains(ids.count), Set(ids).count == ids.count else {
      throw DeckError.message("Choose one to four different windows.")
    }
    let chosen = try ids.map { id -> Handle in
      guard let handle = handles[id], alive(handle),
        handle.evidence.isFresh(comparedTo: observe(handle.element, app: handle.app))
      else {
        throw DeckError.message("A window changed or closed. Scan and rank again before arranging.")
      }
      return handle
    }
    let target = screen ?? NSScreen.main
    guard let target, let primary = NSScreen.screens.first else {
      throw DeckError.message("No display available.")
    }
    let visible = target.visibleFrame.insetBy(dx: 18, dy: 18)
    let bounds = Frame(
      x: visible.minX, y: primary.frame.maxY - visible.maxY,
      width: visible.width, height: visible.height)
    let layouts = DeckLayout.frames(count: ids.count, in: bounds)
    guard layouts.count == chosen.count else {
      throw DeckError.message("Display is too small for this layout.")
    }
    previousApp = NSWorkspace.shared.frontmostApplication
    var report: [String] = []
    for (handle, layout) in zip(chosen, layouts) {
      guard alive(handle),
        handle.evidence.isFresh(comparedTo: observe(handle.element, app: handle.app)),
        let before = frame(handle.element)
      else {
        report.append("Skipped changed window: \(handle.evidence.title)")
        continue
      }
      var entry = UndoEntry(
        handle: handle, frame: before,
        minimized: bool(handle.element, kAXMinimizedAttribute))
      undoEntries.append(entry)
      let index = undoEntries.count - 1
      let window = handle.element
      if entry.minimized {
        setBool(window, kAXMinimizedAttribute, false)
        let ready = await settle(window, minimized: false, minimumDelay: 0.7)
        guard ready, alive(handle),
          handle.evidence.isFresh(comparedTo: observe(handle.element, app: handle.app))
        else {
          entry.afterFrame = frame(window)
          entry.afterMinimized = bool(window, kAXMinimizedAttribute)
          undoEntries[index] = entry
          report.append(
            "Could not restore minimized window: \(handle.evidence.title); Undo retained.")
          continue
        }
      }
      handle.app.activate(options: [])
      let raised = AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success
      let moved = setFrame(window, layout)
      _ = await settle(window, minimized: false)
      entry.afterFrame = frame(window)
      entry.afterMinimized = bool(window, kAXMinimizedAttribute)
      undoEntries[index] = entry
      if moved, entry.afterFrame?.approximatelyEquals(layout) == true {
        report.append("Arranged: \(handle.evidence.title)")
      } else {
        report.append(
          "\(raised ? "Raised" : "Could not raise"): \(handle.evidence.title) — app constrained its frame; Undo retained."
        )
      }
    }
    return report
  }

  public func undo() async -> [String] {
    guard !operating else { return ["Wait for the current window action to finish."] }
    operating = true
    defer { operating = false }
    var report: [String] = []
    var remaining: [UndoEntry] = []
    for entry in undoEntries.reversed() {
      let handle = entry.handle
      guard alive(handle) else {
        report.append("Skipped closed or changed document: \(handle.evidence.title)")
        continue
      }
      guard let current = frame(handle.element), let after = entry.afterFrame,
        current.approximatelyEquals(after),
        bool(handle.element, kAXMinimizedAttribute) == entry.afterMinimized
      else {
        report.append("Skipped externally moved window: \(handle.evidence.title)")
        continue
      }
      _ = setFrame(handle.element, entry.frame)
      _ = await settle(handle.element, minimized: entry.afterMinimized ?? false)
      setBool(handle.element, kAXMinimizedAttribute, entry.minimized)
      _ = await settle(
        handle.element, minimized: entry.minimized,
        minimumDelay: entry.minimized != entry.afterMinimized ? 0.7 : 0.3)
      if frame(handle.element)?.approximatelyEquals(entry.frame) == true,
        bool(handle.element, kAXMinimizedAttribute) == entry.minimized
      {
        report.append("Restored: \(handle.evidence.title)")
      } else {
        var retry = entry
        retry.afterFrame = frame(handle.element)
        retry.afterMinimized = bool(handle.element, kAXMinimizedAttribute)
        remaining.append(retry)
        report.append("Restore incomplete: \(handle.evidence.title); retry Undo.")
      }
    }
    undoEntries = remaining
    previousApp?.activate(options: [])
    return report
  }

  public func readFrame(id: UUID) -> Frame? { handles[id].flatMap { frame($0.element) } }
  public func readMinimized(id: UUID) -> Bool? {
    handles[id].map { bool($0.element, kAXMinimizedAttribute) }
  }
  public func minimizeFixture(id: UUID) {
    guard let handle = handles[id] else { return }
    setBool(handle.element, kAXMinimizedAttribute, true)
  }

  private func alive(_ handle: Handle) -> Bool {
    guard !handle.app.isTerminated,
      handle.app.launchDate?.timeIntervalSince1970 == handle.evidence.launchTime,
      handle.app.bundleIdentifier == handle.evidence.bundleID
    else { return false }
    let app = AXUIElementCreateApplication(handle.app.processIdentifier)
    let exists = elements(app, kAXWindowsAttribute).contains { CFEqual($0, handle.element) }
    return exists && string(handle.element, kAXTitleAttribute) == handle.evidence.title
      && string(handle.element, kAXDocumentAttribute) == handle.evidence.document
      && !bool(handle.element, "AXFullScreen")
  }

  private func settle(
    _ window: AXUIElement, minimized: Bool, minimumDelay: TimeInterval = 0.3
  ) async -> Bool {
    let start = Date()
    var previous: Frame?
    var stableSamples = 0
    for _ in 0..<20 {
      try? await Task.sleep(nanoseconds: 100_000_000)
      guard let current = frame(window) else { return false }
      if let previous, current.approximatelyEquals(previous),
        bool(window, kAXMinimizedAttribute) == minimized
      {
        stableSamples += 1
      } else {
        stableSamples = 0
      }
      previous = current
      if stableSamples >= 3, Date().timeIntervalSince(start) >= minimumDelay { return true }
    }
    return false
  }

  private func observe(_ window: AXUIElement, app: NSRunningApplication) -> WindowEvidence {
    WindowEvidence(
      app: app.localizedName ?? "Unknown", bundleID: app.bundleIdentifier ?? "",
      pid: app.processIdentifier, launchTime: app.launchDate?.timeIntervalSince1970 ?? 0,
      title: string(window, kAXTitleAttribute), document: string(window, kAXDocumentAttribute),
      text: boundedText(window))
  }

  private func boundedText(_ window: AXUIElement) -> String {
    var queue: [AXUIElement] = [window]
    var index = 0
    var fragments: [String] = []
    var seen: Set<String> = []
    var budget = 4000
    let deadline = Date().addingTimeInterval(1.5)
    while index < queue.count, index < 180, budget > 0, Date() < deadline {
      let element = queue[index]
      index += 1
      let role = string(element, kAXRoleAttribute)
      if string(element, kAXSubroleAttribute) == kAXSecureTextFieldSubrole { continue }
      var text = ""
      if role == kAXTextAreaRole || role == kAXTextFieldRole || role == kAXStaticTextRole {
        if let range = attribute(element, "AXVisibleCharacterRange") {
          var value: CFTypeRef?
          if AXUIElementCopyParameterizedAttributeValue(
            element, "AXStringForRange" as CFString, range, &value) == .success
          {
            text = value as? String ?? ""
          }
        }
        if text.isEmpty { text = string(element, kAXValueAttribute) }
      } else if role == kAXButtonRole || role == "AXLink" || role == kAXCellRole {
        text = string(element, kAXTitleAttribute)
        if text.isEmpty { text = string(element, kAXDescriptionAttribute) }
      }
      text = String(text.prefix(budget)).trimmingCharacters(in: .whitespacesAndNewlines)
      if !text.isEmpty, seen.insert(text).inserted {
        fragments.append(text)
        budget -= text.count
      }
      if queue.count < 360 {
        queue.append(contentsOf: elements(element, kAXChildrenAttribute).prefix(60))
      }
    }
    return fragments.joined(separator: "\n")
  }

  private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
      return nil
    }
    return value
  }

  private func string(_ element: AXUIElement, _ name: String) -> String {
    attribute(element, name) as? String ?? ""
  }
  private func bool(_ element: AXUIElement, _ name: String) -> Bool {
    attribute(element, name) as? Bool ?? false
  }
  private func elements(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
    attribute(element, name) as? [AXUIElement] ?? []
  }
  private func writable(_ element: AXUIElement, _ name: String) -> Bool {
    var result = DarwinBoolean(false)
    return AXUIElementIsAttributeSettable(element, name as CFString, &result) == .success
      && result.boolValue
  }
  private func frame(_ element: AXUIElement) -> Frame? {
    guard let rawPoint = attribute(element, kAXPositionAttribute),
      let rawSize = attribute(element, kAXSizeAttribute),
      CFGetTypeID(rawPoint) == AXValueGetTypeID(),
      CFGetTypeID(rawSize) == AXValueGetTypeID()
    else { return nil }
    var point = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(rawPoint as! AXValue, .cgPoint, &point),
      AXValueGetValue(rawSize as! AXValue, .cgSize, &size)
    else { return nil }
    return Frame(x: point.x, y: point.y, width: size.width, height: size.height)
  }
  @discardableResult
  private func setFrame(_ window: AXUIElement, _ frame: Frame) -> Bool {
    guard writable(window, kAXPositionAttribute), writable(window, kAXSizeAttribute) else {
      return false
    }
    var point = CGPoint(x: frame.x, y: frame.y)
    var size = CGSize(width: frame.width, height: frame.height)
    guard let position = AXValueCreate(.cgPoint, &point),
      let dimensions = AXValueCreate(.cgSize, &size)
    else { return false }
    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
    let resized = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions)
    let moved = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
    return resized == .success && moved == .success
  }
  private func setBool(_ window: AXUIElement, _ name: String, _ value: Bool) {
    guard writable(window, name) else { return }
    AXUIElementSetAttributeValue(window, name as CFString, value ? kCFBooleanTrue : kCFBooleanFalse)
  }
}
