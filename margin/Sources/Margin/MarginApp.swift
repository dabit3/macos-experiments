import AppKit
import MarginCore
import SwiftUI

@main
struct MarginApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  @StateObject private var workspace = Workspace()

  init() {
    if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--generate-source" {
      do {
        try PDFRenderer.generateSource(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        exit(0)
      } catch {
        print("PDF generation failed: \(error)")
        exit(1)
      }
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView(workspace: workspace)
        .preferredColorScheme(.light)
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 1440, height: 900)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("Open Project…", action: workspace.openProject).keyboardShortcut("o")
        Button("Restore Sample Workspace…") { workspace.showReset = true }
      }
      CommandGroup(replacing: .saveItem) {
        Button("Save Project…", action: workspace.saveProject).keyboardShortcut("s")
        Button("Export PDF…") { workspace.export(pdf: true) }
          .keyboardShortcut("e", modifiers: [.command, .shift])
        Button("Export Markdown…") { workspace.export(pdf: false) }
      }
      CommandMenu("Research") {
        Button("Collect Selection", action: workspace.capture)
          .keyboardShortcut("h", modifiers: [.command, .shift])
          .disabled(workspace.selectedText.isEmpty)
        Button("Undo Collection Change", action: workspace.undoClipping)
          .disabled(workspace.undoClippings.isEmpty)
      }
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
