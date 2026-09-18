import AppKit

final class FormDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!
  var fields: [NSTextField] = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    window = NSWindow(
      contentRect: NSRect(x: 55, y: 140, width: 650, height: 760),
      styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    window.title = "Northstar · Vendor onboarding — disposable fixture"
    window.backgroundColor = NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.98, alpha: 1)
    let view = NSView(frame: NSRect(x: 0, y: 0, width: 650, height: 760))
    window.contentView = view
    func label(
      _ text: String, x: CGFloat, y: CGFloat, size: CGFloat,
      color: NSColor = .labelColor, weight: NSFont.Weight = .regular
    ) {
      let label = NSTextField(labelWithString: text)
      label.font = .systemFont(ofSize: size, weight: weight)
      label.textColor = color
      label.frame = NSRect(x: x, y: y, width: 560, height: size + 12)
      view.addSubview(label)
    }
    label("N / NORTHSTAR ATELIER", x: 38, y: 696, size: 13, color: .systemIndigo, weight: .bold)
    label("One brief. Every field.", x: 38, y: 644, size: 31, weight: .bold)
    label("Vendor onboarding", x: 38, y: 609, size: 16, color: .secondaryLabelColor)
    label(
      "Focus a field, then press ⌘⇧V to ask PastePilot.", x: 38, y: 570, size: 13,
      color: .secondaryLabelColor)
    let names = [
      "Company", "Billing email", "Sales email", "Shipping address", "Net amount before tax",
      "Gross total payable",
    ]
    for (index, name) in names.enumerated() {
      let y = CGFloat(491 - index * 73)
      let group = NSView(frame: NSRect(x: 38, y: y, width: 574, height: 66))
      let title = NSTextField(labelWithString: name.uppercased())
      title.font = .systemFont(ofSize: 10, weight: .semibold)
      title.textColor = .secondaryLabelColor
      title.frame = NSRect(x: 0, y: 44, width: 550, height: 18)
      let field = NSTextField(frame: NSRect(x: 0, y: 6, width: 574, height: 34))
      field.font = .systemFont(ofSize: 15)
      field.placeholderString = name
      field.bezelStyle = .roundedBezel
      field.setAccessibilityLabel(name)
      field.setAccessibilityIdentifier("pastepilot-\(index)")
      field.setAccessibilityHelp("Enter the \(name.lowercased()) from the vendor handoff.")
      group.addSubview(title)
      group.addSubview(field)
      view.addSubview(group)
      fields.append(field)
    }
    label(
      "LOCAL FIXTURE  ·  No submission, no account, no saved data", x: 38, y: 32,
      size: 11, color: .secondaryLabelColor)
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    window.makeFirstResponder(fields[1])
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let application = NSApplication.shared
application.setActivationPolicy(.regular)
let delegate = FormDelegate()
application.delegate = delegate
application.run()
