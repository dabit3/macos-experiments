import AppKit
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
    try await Task.sleep(nanoseconds: 1_500_000_000)
  }
}
