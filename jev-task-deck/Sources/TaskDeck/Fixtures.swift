import AppKit
import ApplicationServices
import Foundation
import TaskDeckCore

enum Fixtures {
  static var directory: URL {
    if let path = ProcessInfo.processInfo.environment["TASKDECK_FIXTURES"] {
      return URL(fileURLWithPath: path)
    }
    return Bundle.main.resourceURL!.appendingPathComponent("Fixtures")
  }

  @MainActor
  static func open() async throws {
    let source = directory.appendingPathComponent("Desktop")
    let files = try FileManager.default.contentsOfDirectory(
      at: source, includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "txt" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    guard files.count >= 6,
      let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit")
    else {
      throw DeckError.message("The bundled desktop fixtures or TextEdit are unavailable.")
    }
    let config = NSWorkspace.OpenConfiguration()
    config.activates = false
    _ = try await NSWorkspace.shared.open(files, withApplicationAt: app, configuration: config)
    guard AXIsProcessTrusted() else { return }
    let expected = Set(files.map { $0.standardizedFileURL.path })
    for _ in 0..<40 {
      if let textEdit = NSRunningApplication.runningApplications(
        withBundleIdentifier: "com.apple.TextEdit"
      ).first {
        let root = AXUIElementCreateApplication(textEdit.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.3)
        var rawWindows: CFTypeRef?
        AXUIElementCopyAttributeValue(root, kAXWindowsAttribute as CFString, &rawWindows)
        let windows = rawWindows as? [AXUIElement] ?? []
        var paths: Set<String> = []
        for window in windows {
          var document: CFTypeRef?
          AXUIElementCopyAttributeValue(window, kAXDocumentAttribute as CFString, &document)
          if let text = document as? String, let url = URL(string: text) {
            paths.insert(url.standardizedFileURL.path)
          }
        }
        if expected.isSubset(of: paths) { return }
      }
      try await Task.sleep(nanoseconds: 200_000_000)
    }
    throw DeckError.message(
      "TextEdit did not expose all eight fixture windows within 8 seconds. Move grouped tabs to separate windows, then retry."
    )
  }
}
