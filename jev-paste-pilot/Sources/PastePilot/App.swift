import AppKit
import PasteCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = PilotModel()
  var panel: FloatingPanel!
  var shortcuts: Shortcuts?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let arguments = CommandLine.arguments
    if arguments.contains("--native-smoke") {
      Task {
        do {
          try await Commands.nativeSmoke()
          NSApp.terminate(nil)
        } catch {
          print("FAIL native smoke: \(error.localizedDescription)")
          exit(1)
        }
      }
      return
    }
    if let index = arguments.firstIndex(of: "--eval"), arguments.count > index + 1 {
      Task {
        do {
          try await Commands.evaluate(path: arguments[index + 1])
          NSApp.terminate(nil)
        } catch {
          print("FAIL live evaluation: \(error.localizedDescription)")
          exit(1)
        }
      }
      return
    }
    panel = FloatingPanel(
      contentRect: NSRect(x: 735, y: 120, width: 508, height: 790),
      styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered, defer: false)
    panel.title = "PastePilot"
    panel.titlebarAppearsTransparent = true
    panel.titleVisibility = .hidden
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isMovableByWindowBackground = true
    panel.contentView = NSHostingView(rootView: PilotView(model: model))
    panel.setContentSize(NSSize(width: 508, height: 800))
    if let screen = NSScreen.main {
      panel.setFrameTopLeftPoint(
        NSPoint(x: screen.visibleFrame.maxX - 535, y: screen.visibleFrame.maxY - 40))
    }
    model.reveal = { [weak self] in self?.panel.orderFrontRegardless() }
    shortcuts = Shortcuts(model: model)
    let menu = NSMenu()
    let item = NSMenuItem()
    menu.addItem(item)
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "Show PastePilot", action: #selector(showPanel), keyEquivalent: "0")
    appMenu.addItem(
      withTitle: "Quit PastePilot", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    item.submenu = appMenu
    NSApp.mainMenu = menu
    panel.orderFrontRegardless()
    if arguments.contains("--showcase") {
      Task {
        do {
          let text = try String(contentsOf: AppPaths.fixture)
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(text, forType: .string)
          model.captureClipboard()
          let app = try await Commands.launchForm()
          app.activate(options: [])
          try await Task.sleep(for: .milliseconds(250))
          model.captureTarget()
          model.preview()
        } catch { model.status = error.localizedDescription }
      }
    }
  }

  @objc func showPanel() { panel.orderFrontRegardless() }
}

@main
struct PastePilotApp {
  @MainActor static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
  }
}
