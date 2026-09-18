import AppKit
import Foundation

@MainActor
public enum FinderActions {
  public static func validate(
    _ documents: [Document], identity: SearchIdentity, current: SearchIdentity
  ) throws {
    try identity.validate(current: current)
    guard !documents.isEmpty else { throw FinderError("Select at least one result.") }
    for document in documents { try document.verify() }
  }

  public static func reveal(
    _ documents: [Document], identity: SearchIdentity, current: SearchIdentity
  ) throws {
    try validate(documents, identity: identity, current: current)
    NSWorkspace.shared.activateFileViewerSelecting(documents.map(\.url))
  }

  public static func open(
    _ document: Document, identity: SearchIdentity, current: SearchIdentity
  ) throws {
    try validate([document], identity: identity, current: current)
    guard NSWorkspace.shared.open(document.url) else {
      throw FinderError("macOS could not open this document.")
    }
  }

  public static func quickLook(
    _ document: Document, identity: SearchIdentity, current: SearchIdentity
  ) throws {
    try validate([document], identity: identity, current: current)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
    process.arguments = ["-p", document.url.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
  }

  public static func currentFolder() throws -> URL {
    let value = try script(
      """
      tell application "Finder"
          if (count of Finder windows) is 0 then error "Open a Finder folder first."
          return POSIX path of (target of front Finder window as alias)
      end tell
      """)
    guard let path = value.stringValue else { throw FinderError("Finder did not return a folder.") }
    return URL(fileURLWithPath: path, isDirectory: true)
  }

  public static func currentSelection() throws -> [URL] {
    let value = try script(
      """
      tell application "Finder"
          set paths to {}
          repeat with selectedItem in (selection as alias list)
              set end of paths to POSIX path of selectedItem
          end repeat
          return paths
      end tell
      """)
    guard value.numberOfItems > 0 else { return [] }
    return (1...value.numberOfItems).compactMap { index in
      value.atIndex(index)?.stringValue.map { URL(fileURLWithPath: $0) }
    }
  }

  private static func script(_ source: String) throws -> NSAppleEventDescriptor {
    var error: NSDictionary?
    guard let script = NSAppleScript(source: source) else {
      throw FinderError("Could not compile Finder request.")
    }
    let result = script.executeAndReturnError(&error)
    if let error {
      let reason = error[NSAppleScript.errorMessage] as? String ?? "Finder automation unavailable."
      throw FinderError(
        "\(reason) Allow IntentFinder → Finder in System Settings → Privacy & Security → Automation, or use Choose folder."
      )
    }
    return result
  }
}
