import AppKit
import SwiftUI

@main
enum ShareStageMain {
  @MainActor
  static func main() {
    if CommandLine.arguments.contains("--live-eval") {
      Task.detached {
        await Evaluation.run()
        exit(0)
      }
      dispatchMain()
    }
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.regular)
    application.run()
    withExtendedLifetime(delegate) {}
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = StageModel()
  var window: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let menu = NSMenu()
    let root = NSMenuItem()
    menu.addItem(root)
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "Restore all covers", action: #selector(restore), keyEquivalent: "r")
    appMenu.addItem(.separator())
    appMenu.addItem(
      withTitle: "Quit ShareStage", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    root.submenu = appMenu
    NSApp.mainMenu = menu
    let frame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    let width = min(1060.0, frame.width - 70)
    let height = min(840.0, frame.height - 70)
    let window = NSWindow(
      contentRect: CGRect(
        x: frame.minX + 28, y: frame.midY - height / 2,
        width: width, height: height),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered, defer: false)
    window.title = "ShareStage"
    window.titlebarAppearsTransparent = true
    window.backgroundColor = NSColor(red: 0.96, green: 0.97, blue: 0.94, alpha: 1)
    window.contentView = NSHostingView(rootView: StageView(model: model))
    window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
    window.isReleasedWhenClosed = false
    window.makeKeyAndOrderFront(nil)
    self.window = window
    NSApp.activate(ignoringOtherApps: true)

    if CommandLine.arguments.contains("--request-permission") { AXReader.requestPermission() }
    if CommandLine.arguments.contains("--native-smoke") {
      Task { await NativeSmoke.run(model: model) }
    } else if CommandLine.arguments.contains("--showcase") {
      Task {
        model.selectDemoWindows()
        model.analyze()
        while model.busy { try? await Task.sleep(nanoseconds: 100_000_000) }
        model.stageSuggested()
      }
    }
  }
  @objc func restore() { model.restore() }
  func applicationWillTerminate(_ notification: Notification) { model.overlays.restore() }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
