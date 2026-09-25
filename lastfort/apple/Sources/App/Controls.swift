import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

@MainActor final class Controls: ObservableObject {
  @Published var move = CGVector.zero
  @Published var aim = 0.0
  @Published var fire = false
  @Published var sprint = false
  @Published var menu = false
  var pointer: CGPoint?
  var keys: Set<String> = []
  var actions: [GameAction] = []
  var player: Player?
  private var editIndex = 0
  func queue(_ kind: ActionKind, slot: Int? = nil, value: String? = nil) {
    actions.append(GameAction(kind, slot: slot, value: value))
  }
  func drain() -> [GameAction] {
    let values = actions
    actions.removeAll()
    return values
  }
  func reset() {
    keys.removeAll()
    move = .zero
    fire = false
    sprint = false
    actions.removeAll()
  }
  func toggleBuild() { queue(.buildMode, value: player?.bm == true ? "off" : "on") }
  func edit() {
    editIndex = (editIndex + 1) % PieceEdit.allCases.count
    queue(.edit, value: PieceEdit.allCases[editIndex].rawValue)
  }
  func piece(_ value: Piece) {
    queue(.setPiece, value: value.rawValue)
    queue(.buildMode, value: "on")
  }
  func material() {
    let current = player?.bmat ?? .wood
    queue(.setMaterial, value: BuildingMaterial.allCases[(current.index + 1) % 3].rawValue)
  }
  func wheel(_ delta: Double) {
    queue(.select, slot: ((player?.slot ?? 0) + (delta > 0 ? 1 : 5)) % 6)
  }
  func key(_ key: String, down: Bool, repeated: Bool = false) {
    if down { keys.insert(key) } else { keys.remove(key) }
    if down && !repeated {
      switch key {
      case " ": queue(.jump)
      case "e": queue(.interact)
      case "r": queue(.reload)
      case "q": toggleBuild()
      case "f": edit()
      case "g": queue(.drop, slot: player?.slot)
      case "b": queue(.emote)
      case "t": queue(.thank)
      case "m": material()
      case "z": piece(.wall)
      case "x": piece(.floor)
      case "c": piece(.ramp)
      case "v": piece(.roof)
      case "\t": queue(.spectateNext)
      case "\u{1b}":
        menu.toggle()
        reset()
      case "1", "2", "3", "4", "5", "6": queue(.select, slot: (Int(key) ?? 1) - 1)
      default: break
      }
    }
    move = CGVector(
      dx: (keys.contains("d") || keys.contains("right") ? 1 : 0)
        - (keys.contains("a") || keys.contains("left") ? 1 : 0),
      dy: (keys.contains("s") || keys.contains("down") ? 1 : 0)
        - (keys.contains("w") || keys.contains("up") ? 1 : 0))
  }
}

#if os(macOS)
  struct DesktopInput: NSViewRepresentable {
    let controls: Controls
    func makeNSView(context: Context) -> InputView { InputView(controls) }
    func updateNSView(_ nsView: InputView, context: Context) {}
    final class InputView: NSView {
      let controls: Controls
      init(_ controls: Controls) {
        self.controls = controls
        super.init(frame: .zero)
      }
      required init?(coder: NSCoder) { nil }
      override var acceptsFirstResponder: Bool { true }
      override var isFlipped: Bool { true }
      override func viewDidMoveToWindow() { window?.makeFirstResponder(self) }
      override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(
          NSTrackingArea(
            rect: bounds, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self, userInfo: nil))
      }
      override func mouseMoved(with event: NSEvent) {
        controls.pointer = convert(event.locationInWindow, from: nil)
      }
      override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }
      override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        mouseMoved(with: event)
        controls.fire = true
      }
      override func mouseUp(with event: NSEvent) { controls.fire = false }
      override func rightMouseDown(with event: NSEvent) { controls.queue(.interact) }
      override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaY) > 0.1 { controls.wheel(event.scrollingDeltaY) }
      }
      override func flagsChanged(with event: NSEvent) {
        controls.sprint = event.modifierFlags.contains(.shift)
      }
      private func name(_ event: NSEvent) -> String {
        switch event.keyCode {
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        default: return event.charactersIgnoringModifiers?.lowercased() ?? ""
        }
      }
      override func keyDown(with event: NSEvent) {
        controls.key(name(event), down: true, repeated: event.isARepeat)
      }
      override func keyUp(with event: NSEvent) { controls.key(name(event), down: false) }
      override func resignFirstResponder() -> Bool {
        controls.reset()
        return true
      }
    }
  }
#endif

struct TouchStick: View {
  let label: String
  var diameter = 96.0
  let action: (CGVector) -> Void
  @State private var offset = CGSize.zero
  var body: some View {
    let active = offset != .zero
    Circle().fill(.black.opacity(active ? 0.45 : 0.3))
      .overlay(Circle().strokeBorder(.white.opacity(active ? 0.6 : 0.3), lineWidth: 1.5))
      .overlay(
        Circle().fill(.white.opacity(active ? 0.9 : 0.6))
          .frame(width: diameter * 0.42, height: diameter * 0.42).offset(offset)
          .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
          .animation(.easeOut(duration: active ? 0 : 0.15), value: offset)
      )
      .overlay(alignment: .bottom) {
        Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
          .offset(y: 18)
      }
      .frame(width: diameter, height: diameter)
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { value in
          let radius = diameter * 0.4
          let dx = value.location.x - diameter / 2
          let dy = value.location.y - diameter / 2
          let length = max(radius, hypot(dx, dy))
          offset = CGSize(width: dx / length * radius, height: dy / length * radius)
          action(CGVector(dx: dx / length, dy: dy / length))
        }.onEnded { _ in
          offset = .zero
          action(.zero)
        }
      )
      .accessibilityLabel(label)
  }
}
