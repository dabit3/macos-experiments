import AppKit
import SwiftUI

final class CoverPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayManager {
  private(set) var panels: [UUID: CoverPanel] = [:]

  func cover(_ target: WindowTarget, frame: CGRect, reveal: @escaping () -> Void) {
    let panel = CoverPanel(
      contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false)
    panel.title = "ShareStage cover"
    panel.isOpaque = true
    panel.backgroundColor = NSColor(red: 0.055, green: 0.12, blue: 0.14, alpha: 1)
    panel.level = .floating
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.contentView = NSHostingView(rootView: CoverView(reveal: reveal))
    panels[target.id]?.close()
    panels[target.id] = panel
    panel.orderFrontRegardless()
  }

  func move(_ id: UUID, frame: CGRect) {
    panels[id]?.setFrame(frame, display: true)
  }

  func remove(_ id: UUID) {
    panels.removeValue(forKey: id)?.close()
  }

  func restore() {
    for panel in panels.values { panel.close() }
    panels.removeAll()
  }
}

private struct CoverView: View {
  let reveal: () -> Void
  var body: some View {
    ZStack {
      Color(red: 0.055, green: 0.12, blue: 0.14)
      VStack(spacing: 16) {
        Image(systemName: "rectangle.slash")
          .font(.system(size: 38, weight: .ultraLight))
        Text("OFF STAGE").font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(4)
        Text("A little privacy.\nA better presentation.")
          .font(.system(size: 25, weight: .medium, design: .serif))
          .multilineTextAlignment(.center)
        Text("Covered locally by ShareStage").font(.system(size: 11)).opacity(0.65)
        Button("Reveal this window", action: reveal)
          .buttonStyle(.bordered).tint(.white)
      }
      .foregroundStyle(Color(red: 0.72, green: 0.93, blue: 0.83))
      .padding(12)
    }
    .overlay(Rectangle().strokeBorder(Color(red: 0.51, green: 0.89, blue: 0.72), lineWidth: 3))
  }
}
