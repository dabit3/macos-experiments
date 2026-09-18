import SceneKit
import SwiftUI

enum Palette {
  static let ink = Color(hex: 0x203D37)
  static let cream = Color(hex: 0xF7EEDB)
  static let muted = Color(hex: 0xAABEB0)
  static let walnut = Color(hex: 0x18352F)
  static let coral = Color(hex: 0xE69B70)
  static let sage = Color(hex: 0x87A795)
  static let brass = Color(hex: 0xD5B573)
  static let blue = Color(hex: 0x81BBC1)
  static let surface = Color(hex: 0x25473F)
  static let separator = Color(hex: 0x46645A)
  static let success = Color(hex: 0xB8D9BC)
  static let failure = Color(hex: 0xFFB3A8)
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
  }
}

struct WorkshopBackground: View {
  var body: some View {
    Palette.walnut.ignoresSafeArea().accessibilityHidden(true)
  }
}

struct TabletopView: View {
  let puzzle: Puzzle
  let pieces: [Cell: Piece]
  var selected: Cell?
  var result: ChainResult?
  var beat: Double = -1
  var guides = true
  var labels = true
  var reduceMotion = false
  var interactive = true
  var tap: (Cell) -> Void = { _ in }

  var body: some View {
    DioramaSurface(
      puzzle: puzzle, pieces: pieces, selected: selected, result: result,
      beat: beat, guides: guides, labels: labels, reduceMotion: reduceMotion,
      interactive: interactive, tap: tap)
  }
}

struct DioramaSurface: UIViewRepresentable {
  let puzzle: Puzzle
  let pieces: [Cell: Piece]
  let selected: Cell?
  let result: ChainResult?
  let beat: Double
  let guides: Bool
  let labels: Bool
  let reduceMotion: Bool
  let interactive: Bool
  let tap: (Cell) -> Void

  func makeUIView(context: Context) -> DioramaView {
    let view = DioramaView(frame: .zero)
    view.backgroundColor = .clear
    view.isOpaque = false
    view.antialiasingMode = .multisampling4X
    view.preferredFramesPerSecond = 60
    return view
  }

  func updateUIView(_ view: DioramaView, context: Context) {
    if view.model?.puzzle.id != puzzle.id || view.model?.labels != labels {
      let model = Diorama(puzzle: puzzle, labels: labels)
      view.model = model
      view.scene = model.scene
      view.pointOfView = model.camera
    }
    view.onCell = tap
    view.isUserInteractionEnabled = interactive
    view.accessibilityElementsHidden = !interactive
    view.model?.update(
      pieces: pieces, selected: selected, result: result, beat: beat,
      guides: guides, reduceMotion: reduceMotion)
    view.refreshAccessibility(pieces: pieces)
  }
}

final class DominoAccessibilityElement: UIAccessibilityElement {
  var activate: () -> Void = {}
  override func accessibilityActivate() -> Bool {
    activate()
    return true
  }
}

final class DioramaView: SCNView {
  var model: Diorama?
  var onCell: (Cell) -> Void = { _ in }
  private var cellElements: [DominoAccessibilityElement] = []

  override init(frame: CGRect) {
    super.init(frame: frame, options: nil)
    addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    isAccessibilityElement = false
  }

  required init?(coder: NSCoder) { nil }

  @objc private func tapped(_ gesture: UITapGestureRecognizer) {
    if let cell = cell(at: gesture.location(in: self)) { onCell(cell) }
  }

  func cell(at point: CGPoint) -> Cell? {
    guard let model else { return nil }
    let near = unprojectPoint(SCNVector3(point.x, point.y, 0))
    let far = unprojectPoint(SCNVector3(point.x, point.y, 1))
    let distance = far.y - near.y
    guard abs(distance) > 0.001 else { return nil }
    let t = (0.08 - near.y) / distance
    let x = Int((near.x + (far.x - near.x) * t + 3).rounded())
    let y = Int((near.z + (far.z - near.z) * t + 4).rounded())
    let cell = Cell(x: x, y: y)
    return model.puzzle.contains(cell) ? cell : nil
  }

  func refreshAccessibility(pieces: [Cell: Piece]) {
    guard let model else { return }
    if cellElements.isEmpty {
      cellElements = (0..<63).map { index in
        let cell = Cell(x: index % 7, y: index / 7)
        let element = DominoAccessibilityElement(accessibilityContainer: self)
        element.accessibilityIdentifier = "cell-\(cell.x)-\(cell.y)"
        element.accessibilityTraits = .button
        element.activate = { [weak self] in self?.onCell(cell) }
        return element
      }
      accessibilityElements = cellElements
    }
    for (index, element) in cellElements.enumerated() {
      let cell = Cell(x: index % 7, y: index / 7)
      let coordinate = "\(String(UnicodeScalar(65 + cell.x)!))\(cell.y + 1)"
      let description: String
      if cell == model.puzzle.start {
        description = "start trigger"
      } else if model.puzzle.targets.contains(cell) {
        description = "bell target"
      } else if let piece = pieces[cell] {
        description = "\(piece.kind.title), rotation \(piece.rotation)"
      } else {
        description = model.puzzle.canEdit(cell) ? "empty socket" : "scenery"
      }
      element.accessibilityLabel = "\(coordinate), \(description)"
    }
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    for (index, element) in cellElements.enumerated() {
      let p = projectPoint(SCNVector3(Float(index % 7) - 3, 0.08, Float(index / 7) - 4))
      element.accessibilityFrameInContainerSpace = CGRect(
        x: CGFloat(p.x) - 20, y: CGFloat(p.y) - 18, width: 40, height: 36)
    }
  }
}
