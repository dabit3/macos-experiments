import SwiftUI
import UIKit

struct InkCanvas: UIViewRepresentable {
  @ObservedObject var store: BoardStore

  func makeUIView(context: Context) -> CanvasView { CanvasView(store: store) }
  func updateUIView(_ view: CanvasView, context: Context) { view.refresh() }
}

@MainActor
final class CanvasView: UIView {
  private let store: BoardStore
  private var fittedBoard: UUID?
  private var fitRequest = -1
  private var baseScale: CGFloat = 1
  private var worldCenter = CGPoint(x: 500, y: 375)
  private var start = CGPoint.zero
  private var startOffset = CGPoint.zero
  private var before: Board?
  private var points: [CGPoint] = []
  private var moving: BoardElement?
  private var creating: BoardElement?
  private var resizing = false
  private var drawing = false
  private var panning = false
  private var pinchZoom: CGFloat = 1
  private var previousSize: CGSize = .zero

  private var scale: CGFloat { baseScale * store.zoom }

  init(store: BoardStore) {
    self.store = store
    super.init(frame: .zero)
    backgroundColor = BoardRenderer.paper
    isMultipleTouchEnabled = true
    isAccessibilityElement = true
    accessibilityLabel = "Idea canvas"
    accessibilityHint = "Use the floating tools to draw, create objects and connect ideas."
    accessibilityIdentifier = "idea-canvas"
    let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:)))
    addGestureRecognizer(pinch)
  }

  required init?(coder: NSCoder) { nil }
  override var canBecomeFirstResponder: Bool { true }

  override var keyCommands: [UIKeyCommand]? {
    [
      UIKeyCommand(title: "Undo", action: #selector(undoKey), input: "z", modifierFlags: .command),
      UIKeyCommand(
        title: "Redo", action: #selector(redoKey), input: "z", modifierFlags: [.command, .shift]),
      UIKeyCommand(
        title: "Delete selection", action: #selector(deleteKey), input: "\u{8}", modifierFlags: []),
    ]
  }

  @objc private func undoKey() { store.undo() }
  @objc private func redoKey() { store.redo() }
  @objc private func deleteKey() { store.deleteSelection() }

  override func layoutSubviews() {
    super.layoutSubviews()
    if previousSize != bounds.size {
      previousSize = bounds.size
      fittedBoard = nil
    }
    refresh()
  }

  func refresh() {
    if fittedBoard != store.board.id || fitRequest != store.fitRequest {
      fittedBoard = store.board.id
      fitRequest = store.fitRequest
      let content =
        store.board.elements.isEmpty
        ? CGRect(x: 0, y: 0, width: 1000, height: 750)
        : store.board.contentBounds.insetBy(dx: -65, dy: -65)
      worldCenter = CGPoint(x: content.midX, y: content.midY)
      baseScale = min(
        max(1, bounds.width) / max(1000, content.width),
        max(1, bounds.height) / max(750, content.height))
      DispatchQueue.main.async { [weak self] in
        self?.store.zoom = 1
        self?.store.offset = .zero
      }
    }
    accessibilityValue =
      "\(store.board.elements.count) objects, \(store.board.connections.count) connectors. \(store.tool.label) tool."
    setNeedsDisplay()
  }

  private func world(_ point: CGPoint) -> CGPoint {
    CGPoint(
      x: (point.x - bounds.midX) / scale + worldCenter.x - store.offset.x,
      y: (point.y - bounds.midY) / scale + worldCenter.y - store.offset.y)
  }

  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    context.saveGState()
    context.translateBy(x: bounds.midX, y: bounds.midY)
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -worldCenter.x + store.offset.x, y: -worldCenter.y + store.offset.y)
    let visible = CGRect(
      origin: world(.zero), size: CGSize(width: bounds.width / scale, height: bounds.height / scale)
    )
    context.setFillColor(UIColor(hex: "#738079").withAlphaComponent(0.17).cgColor)
    let grid: CGFloat = 25
    for x in stride(from: floor(visible.minX / grid) * grid, through: visible.maxX, by: grid) {
      for y in stride(from: floor(visible.minY / grid) * grid, through: visible.maxY, by: grid) {
        context.fillEllipse(in: CGRect(x: x, y: y, width: 1.35 / scale, height: 1.35 / scale))
      }
    }
    context.setFillColor(UIColor(hex: "#756F59").withAlphaComponent(0.04).cgColor)
    for index in 0..<1200 {
      let x = visible.minX + CGFloat((index * 541) % 1297) / 1297 * visible.width
      let y = visible.minY + CGFloat((index * 739) % 1217) / 1217 * visible.height
      context.fill(CGRect(x: x, y: y, width: 0.7 / scale, height: 0.7 / scale))
    }
    BoardRenderer.draw(store.board, in: context)
    if let creating { BoardRenderer.draw(creating, in: context) }
    if drawing, let stroke = Geometry.stroke(points, tone: store.tone, width: store.penWidth) {
      BoardRenderer.draw(stroke, in: context)
    }
    if let selected = store.selectedElement {
      drawSelection(selected.frame, context: context)
    }
    if let id = store.connectionStart, let from = store.board.elements.first(where: { $0.id == id })
    {
      context.setStrokeColor(BoardRenderer.ink.cgColor)
      context.setLineWidth(2 / scale)
      context.setLineDash(phase: 0, lengths: [5 / scale, 5 / scale])
      context.stroke(from.frame.insetBy(dx: -7 / scale, dy: -7 / scale))
    }
    context.restoreGState()
  }

  private func drawSelection(_ frame: CGRect, context: CGContext) {
    let r = frame.insetBy(dx: -5 / scale, dy: -5 / scale)
    context.setStrokeColor(BoardRenderer.ink.withAlphaComponent(0.7).cgColor)
    context.setLineWidth(1.4 / scale)
    context.stroke(r)
    for p in [
      CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
      CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY),
    ] {
      let size: CGFloat = p == CGPoint(x: r.maxX, y: r.maxY) ? 13 : 8
      let handle = CGRect(
        x: p.x - size / scale / 2, y: p.y - size / scale / 2, width: size / scale,
        height: size / scale)
      context.setFillColor(UIColor.white.cgColor)
      context.fillEllipse(in: handle)
      context.strokeEllipse(in: handle)
    }
  }

  private func hit(_ point: CGPoint) -> BoardElement? {
    store.board.elements.reversed().first { element in
      if element.kind == .ellipse {
        let dx = (point.x - element.frame.midX) / (element.frame.width / 2 + 6 / scale)
        let dy = (point.y - element.frame.midY) / (element.frame.height / 2 + 6 / scale)
        return dx * dx + dy * dy <= 1
      }
      return element.frame.insetBy(dx: -6 / scale, dy: -6 / scale).contains(point)
    }
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first, event?.allTouches?.count == 1 else { return }
    becomeFirstResponder()
    start = world(touch.location(in: self))
    before = store.board
    startOffset = store.offset
    moving = nil
    creating = nil
    resizing = false
    drawing = false
    panning = false
    switch store.tool {
    case .select:
      if let selected = store.selectedElement,
        hypot(start.x - selected.frame.maxX - 5 / scale, start.y - selected.frame.maxY - 5 / scale)
          < 24 / scale
      {
        moving = selected
        resizing = true
      } else if let element = hit(start) {
        store.selection = element.id
        if touch.tapCount == 2 && element.kind != .stroke {
          store.editing = element.id
        } else {
          moving = element
        }
      } else {
        store.selection = nil
      }
    case .pen:
      store.selection = nil
      drawing = true
      points = [start]
    case .pan:
      panning = true
    case .card, .ellipse:
      store.selection = nil
      creating = BoardElement(
        kind: store.tool == .card ? .card : .ellipse,
        frame: CGRect(origin: start, size: CGSize(width: 220, height: 140)),
        text: store.tool == .card ? "A new idea" : "What if?",
        detail: store.tool == .card ? "Double-tap to make it yours" : "",
        tone: store.tone == .ink && store.tool == .card ? .paper : store.tone)
    case .text:
      store.selection = nil
      creating = BoardElement(
        kind: .text, frame: CGRect(origin: start, size: CGSize(width: 285, height: 100)),
        text: "A thought to keep", tone: store.tone)
    case .connect:
      if let target = hit(start), target.kind != .stroke {
        if let from = store.connectionStart {
          store.apply { $0.connect(from, target.id, tone: store.tone) }
          store.connectionStart = nil
        } else {
          store.connectionStart = target.id
        }
      } else {
        store.connectionStart = nil
      }
      before = nil
    }
    setNeedsDisplay()
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    let point = world(touch.location(in: self))
    if panning {
      let screen = touch.location(in: self)
      let originalScreenX = (start.x - worldCenter.x + startOffset.x) * scale + bounds.midX
      let originalScreenY = (start.y - worldCenter.y + startOffset.y) * scale + bounds.midY
      store.offset = CGPoint(
        x: startOffset.x + (screen.x - originalScreenX) / scale,
        y: startOffset.y + (screen.y - originalScreenY) / scale)
    } else if drawing {
      for coalesced in event?.coalescedTouches(for: touch) ?? [touch] {
        points.append(world(coalesced.location(in: self)))
      }
    } else if var item = creating, item.kind != .text {
      item.frame = Geometry.rect(from: start, to: point)
      creating = item
    } else if var item = moving,
      let index = store.board.elements.firstIndex(where: { $0.id == item.id })
    {
      let dx = point.x - start.x
      let dy = point.y - start.y
      if resizing {
        item.frame.size = CGSize(
          width: max(item.kind == .stroke ? 15 : 120, item.frame.width + dx),
          height: max(item.kind == .stroke ? 15 : 80, item.frame.height + dy))
      } else {
        item.frame.origin.x += dx
        item.frame.origin.y += dy
      }
      store.board.elements[index] = item
    }
    setNeedsDisplay()
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    if drawing, let stroke = Geometry.stroke(points, tone: store.tone, width: store.penWidth) {
      store.board.elements.append(stroke)
    }
    if let creating {
      store.board.elements.append(creating)
      store.selection = creating.id
      store.tool = .select
      if creating.kind == .text { store.editing = creating.id }
    }
    if let before { store.record(before) }
    resetInteraction()
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    if let before { store.board = before }
    resetInteraction()
  }

  private func resetInteraction() {
    moving = nil
    creating = nil
    before = nil
    drawing = false
    panning = false
    points = []
    setNeedsDisplay()
  }

  @objc private func pinched(_ gesture: UIPinchGestureRecognizer) {
    if gesture.state == .began { pinchZoom = store.zoom }
    store.zoom = min(3.5, max(0.35, pinchZoom * gesture.scale))
    setNeedsDisplay()
  }
}
