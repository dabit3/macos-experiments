import SceneKit
import UIKit

@MainActor
final class Diorama {
  let puzzle: Puzzle
  let labels: Bool
  let scene = SCNScene()
  let camera = SCNNode()
  private let piecesRoot = SCNNode()
  private let marksRoot = SCNNode()
  private var placed: [Cell: Piece]?
  private var dominoes: [Cell: [SCNNode]] = [:]
  private var bells: [Cell: SCNNode] = [:]
  private var selection: Cell?
  private var showingGuides = false
  private var failedCells: Set<Cell> = []

  private let porcelain = Diorama.material(0xFAF8F0, shine: 0.3)
  private let ivory = Diorama.material(0xE1E2D8)
  private let wood = Diorama.material(0x694732, shine: 0.2)
  private let gold = Diorama.material(0xD5A353, shine: 0.8)
  private let forest = Diorama.material(0x2F6152)
  private let dark = Diorama.material(0x31483E)
  private let coral = Diorama.material(0xCF7E59, shine: 0.4)
  private let water = Diorama.material(0x6EA5AB, shine: 0.7)

  init(puzzle: Puzzle, labels: Bool) {
    self.puzzle = puzzle
    self.labels = labels
    scene.background.contents = UIColor.clear
    camera.camera = SCNCamera()
    camera.camera?.usesOrthographicProjection = true
    camera.camera?.orthographicScale = labels ? 4.6 : 5.65
    camera.camera?.zNear = 0.1
    camera.camera?.zFar = 100
    camera.position = SCNVector3(labels ? 0 : 2.2, 16, 12)
    camera.look(at: SCNVector3(0, 0, 0))
    scene.rootNode.addChildNode(camera)

    let key = SCNNode()
    key.light = SCNLight()
    key.light?.type = .directional
    key.light?.intensity = 1050
    key.light?.color = UIColor(red: 1, green: 0.97, blue: 0.91, alpha: 1)
    key.light?.castsShadow = true
    key.light?.shadowMode = .deferred
    key.light?.shadowColor = UIColor(red: 0.15, green: 0.22, blue: 0.18, alpha: 0.5)
    key.light?.shadowRadius = 5
    key.light?.shadowSampleCount = 16
    key.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
    key.light?.orthographicScale = 12
    key.position = SCNVector3(-8, 14, -9)
    key.look(at: SCNVector3Zero)
    scene.rootNode.addChildNode(key)
    let fill = SCNNode()
    fill.light = SCNLight()
    fill.light?.type = .ambient
    fill.light?.color = UIColor(red: 0.85, green: 0.91, blue: 0.97, alpha: 1)
    fill.light?.intensity = 650
    scene.rootNode.addChildNode(fill)

    buildTable()
    scene.rootNode.addChildNode(piecesRoot)
    scene.rootNode.addChildNode(marksRoot)
  }

  private static func material(_ hex: UInt32, shine: CGFloat = 0.08) -> SCNMaterial {
    let material = SCNMaterial()
    material.diffuse.contents = UIColor(
      red: CGFloat((hex >> 16) & 255) / 255,
      green: CGFloat((hex >> 8) & 255) / 255,
      blue: CGFloat(hex & 255) / 255, alpha: 1)
    material.lightingModel = .blinn
    material.specular.contents = UIColor(white: shine, alpha: 1)
    material.shininess = 0.45
    return material
  }

  @discardableResult
  private func box(
    _ parent: SCNNode, _ size: (CGFloat, CGFloat, CGFloat),
    _ position: (Float, Float, Float), _ material: SCNMaterial, bevel: CGFloat = 0.04
  ) -> SCNNode {
    let geometry = SCNBox(
      width: size.0, height: size.1, length: size.2,
      chamferRadius: min(bevel, min(size.0, size.1, size.2) / 2))
    geometry.chamferSegmentCount = 3
    geometry.materials = [material]
    let node = SCNNode(geometry: geometry)
    node.position = SCNVector3(position.0, position.1, position.2)
    parent.addChildNode(node)
    return node
  }

  @discardableResult
  private func sphere(
    _ parent: SCNNode, radius: CGFloat, at position: (Float, Float, Float),
    material: SCNMaterial, scale: SCNVector3 = SCNVector3(1, 1, 1)
  ) -> SCNNode {
    let geometry = SCNSphere(radius: radius)
    geometry.segmentCount = 16
    geometry.materials = [material]
    let node = SCNNode(geometry: geometry)
    node.position = SCNVector3(position.0, position.1, position.2)
    node.scale = scale
    parent.addChildNode(node)
    return node
  }

  @discardableResult
  private func cylinder(
    _ parent: SCNNode, radius: CGFloat, height: CGFloat, at position: (Float, Float, Float),
    material: SCNMaterial
  ) -> SCNNode {
    let geometry = SCNCylinder(radius: radius, height: height)
    geometry.radialSegmentCount = 24
    geometry.materials = [material]
    let node = SCNNode(geometry: geometry)
    node.position = SCNVector3(position.0, position.1, position.2)
    parent.addChildNode(node)
    return node
  }

  private func lettering(
    _ text: String, at position: (Float, Float, Float), size: Float, material: SCNMaterial
  ) {
    let font = UIFont.monospacedSystemFont(ofSize: 64, weight: .medium)
    let attributes: [NSAttributedString.Key: NSObject] = [
      .font: font, .foregroundColor: UIColor.white,
    ]
    let extent = (text as NSString).size(withAttributes: attributes)
    let image = UIGraphicsImageRenderer(size: extent).image { _ in
      (text as NSString).draw(at: .zero, withAttributes: attributes)
    }
    let ink = SCNMaterial()
    ink.lightingModel = .constant
    ink.diffuse.contents = image
    ink.multiply.contents = material.diffuse.contents
    ink.writesToDepthBuffer = false
    let scale = CGFloat(size) / font.pointSize
    let shape = SCNPlane(width: extent.width * scale, height: extent.height * scale)
    shape.materials = [ink]
    let node = SCNNode(geometry: shape)
    node.name = "lettering-\(text)"
    node.eulerAngles.x = -.pi / 2
    node.position = SCNVector3(position.0, position.1, position.2 - Float(shape.height / 2))
    scene.rootNode.addChildNode(node)
  }

  private func buildTable() {
    let root = scene.rootNode
    box(root, (8.3, 0.38, 10.3), (0, -0.34, 0), wood, bevel: 0.18)
    box(root, (8.14, 0.09, 10.14), (0, -0.12, 0), gold, bevel: 0.12)
    box(root, (7.98, 0.16, 9.98), (0, -0.055, 0), forest, bevel: 0.15)
    box(root, (7.76, 0.1, 9.76), (0, 0.015, 0), ivory, bevel: 0.17)
    for side: Float in [-1, 1] {
      for z: Float in [-4.85, 4.85] {
        cylinder(root, radius: 0.065, height: 0.012, at: (side * 3.85, 0.04, z), material: gold)
      }
      for index in 0..<32 {
        box(
          root, (0.01, 0.009, 0.24), (side * 4.04, -0.068, Float(index) * 0.3 - 4.6),
          gold, bevel: 0)
      }
    }
    for y in 0..<9 {
      for x in 0..<7 {
        let cell = Cell(x: x, y: y)
        let px = Float(x - 3)
        let pz = Float(y - 4)
        cylinder(root, radius: 0.022, height: 0.005, at: (px, 0.073, pz), material: gold)
        if puzzle.water.contains(cell) {
          box(root, (0.98, 0.09, 0.98), (px, 0.095, pz), water, bevel: 0.12)
          for offset: Float in [-0.24, 0, 0.24] {
            box(root, (0.54, 0.012, 0.018), (px, 0.15, pz + offset), porcelain)
          }
        }
      }
      if labels {
        lettering("\(y + 1)", at: (-3.65, 0.08, Float(y - 4) + 0.1), size: 0.35, material: dark)
      }
    }
    if labels {
      for x in 0..<7 {
        lettering(
          String(UnicodeScalar(65 + x)!), at: (Float(x - 3), 0.08, -4.45),
          size: 0.35, material: dark)
      }
    }
    lettering("D O M I N O   •   D A Y D R E A M", at: (0, 0.08, 4.65), size: 0.12, material: dark)
    scenery()
    let start = SCNNode()
    start.position = point(puzzle.start)
    root.addChildNode(start)
    cylinder(start, radius: 0.36, height: 0.12, at: (0, 0.08, 0), material: gold)
    cylinder(start, radius: 0.29, height: 0.13, at: (0, 0.2, 0), material: coral)
    box(start, (0.32, 0.012, 0.045), (0, 0.275, 0), porcelain)
    for sign: Float in [-1, 1] {
      let arrow = box(start, (0.15, 0.012, 0.04), (0.09, 0.275, sign * 0.043), porcelain)
      arrow.eulerAngles.y = sign * .pi / 4
    }
    for (index, cell) in puzzle.targets.enumerated() {
      let bell = SCNNode()
      bell.position = point(cell)
      bell.scale = SCNVector3(1.12, 1.12, 1.12)
      root.addChildNode(bell)
      cylinder(bell, radius: 0.32, height: 0.11, at: (0, 0.08, 0), material: wood)
      cylinder(bell, radius: 0.29, height: 0.05, at: (0, 0.17, 0), material: gold)
      sphere(
        bell, radius: 0.27, at: (0, 0.2, 0), material: gold,
        scale: SCNVector3(1, 0.85, 1))
      cylinder(bell, radius: 0.055, height: 0.14, at: (0, 0.47, 0), material: gold)
      sphere(bell, radius: 0.075, at: (0, 0.54, 0), material: porcelain)
      bells[cell] = bell
      if labels {
        lettering(
          "\(index + 1)", at: (Float(cell.x - 3), 0.078, Float(cell.y - 4) + 0.48),
          size: 0.29, material: dark)
      }
    }
  }

  private func scenery() {
    let center = puzzle.town
    let occupied = Set(puzzle.solution.keys).union(puzzle.targets).union(puzzle.water).union([
      puzzle.start
    ])
    let candidates = [
      (center, false), (Cell(x: center.x + 1, y: center.y), true),
      (Cell(x: center.x, y: center.y - 1), true),
    ]
    for (index, entry) in candidates.enumerated() {
      guard puzzle.contains(entry.0), entry.0.y > 0, !occupied.contains(entry.0) else { continue }
      let town = SCNNode()
      town.position = point(entry.0)
      scene.rootNode.addChildNode(town)
      if entry.1 {
        tree(town, tall: index == 2)
      } else {
        box(town, (0.87, 0.11, 0.85), (0, 0.09, 0), forest, bevel: 0.13)
        box(town, (0.66, 0.58, 0.56), (0, 0.4, 0), porcelain)
        for sign: Float in [-1, 1] {
          let roof = box(town, (0.48, 0.08, 0.72), (sign * 0.19, 0.83, 0), coral)
          roof.eulerAngles.z = sign * -.pi / 4
        }
        box(town, (0.13, 0.25, 0.035), (0, 0.29, 0.294), forest)
        for sign: Float in [-1, 1] {
          box(town, (0.11, 0.12, 0.024), (sign * 0.2, 0.5, 0.29), water)
          box(town, (0.16, 0.045, 0.065), (sign * 0.2, 0.42, 0.32), gold)
        }
        box(town, (0.1, 0.32, 0.13), (0.2, 0.95, -0.16), ivory)
      }
    }
    for cell in [Cell(x: 0, y: 1), Cell(x: 6, y: 8)] where !occupied.contains(cell) {
      let plant = SCNNode()
      plant.position = point(cell)
      plant.scale = SCNVector3(0.65, 0.65, 0.65)
      scene.rootNode.addChildNode(plant)
      tree(plant, tall: false)
    }
  }

  private func tree(_ parent: SCNNode, tall: Bool) {
    cylinder(parent, radius: 0.22, height: 0.17, at: (0, 0.13, 0), material: coral)
    cylinder(parent, radius: 0.05, height: 0.6, at: (0, 0.44, 0), material: wood)
    for (index, offset) in [-0.14, 0.16, 0.0].enumerated() {
      sphere(
        parent, radius: 0.25,
        at: (Float(offset), 0.57 + Float(index) * 0.18, Float(offset * 0.3)),
        material: index == 1 ? Diorama.material(0x7A9871) : forest,
        scale: SCNVector3(0.85, tall ? 1.5 : 1, 0.9))
    }
  }

  private func point(_ cell: Cell) -> SCNVector3 {
    SCNVector3(Float(cell.x - 3), 0.07, Float(cell.y - 4))
  }

  func update(
    pieces: [Cell: Piece], selected: Cell?, result: ChainResult?, beat: Double,
    guides: Bool, reduceMotion: Bool
  ) {
    if pieces != placed {
      let previous = placed
      placed = pieces
      for node in piecesRoot.childNodes { node.removeFromParentNode() }
      dominoes = [:]
      for (cell, piece) in pieces {
        let node = makePiece(piece, cell: cell)
        piecesRoot.addChildNode(node)
        if previous != nil, previous?[cell] != piece, !reduceMotion {
          node.position.y += 0.2
          node.runAction(.moveBy(x: 0, y: -0.2, z: 0, duration: 0.2))
        }
      }
    }
    let failures =
      beat > Double(result?.events.map(\.beat).max() ?? 0) + 0.6
      ? Set(result?.failures.keys.map { $0 } ?? []) : []
    if selection != selected || showingGuides != guides || failedCells != failures
      || marksRoot.childNodes.isEmpty
    {
      selection = selected
      showingGuides = guides
      failedCells = failures
      for node in marksRoot.childNodes { node.removeFromParentNode() }
      if guides {
        for cell in puzzle.sockets { rim(cell, material: forest, dashed: true) }
      }
      if let selected { rim(selected, material: gold, dashed: false) }
      for cell in failures where puzzle.contains(cell) { rim(cell, material: coral, dashed: false) }
    }
    for (cell, nodes) in dominoes {
      let event = result?.events.first { $0.cell == cell }
      for (index, node) in nodes.enumerated() {
        var amount: Double = 0
        if let event {
          let elapsed = beat - Double(event.beat) - Double(index) * 0.08
          amount = max(0.0, min(1.0, elapsed * 1.5))
        }
        if reduceMotion { amount = amount > 0 ? 1 : 0 }
        let direction = event?.direction ?? .east
        node.eulerAngles.x = Float(amount * 1.4) * Float(direction.dy)
        node.eulerAngles.z = -Float(amount * 1.4) * Float(direction.dx)
      }
    }
    for (cell, bell) in bells {
      let event = result?.events.first { $0.cell == cell }
      let elapsed = event.map { beat - Double($0.beat) } ?? -1
      bell.eulerAngles.z =
        elapsed >= 0 && elapsed < 1.5 && !reduceMotion
        ? Float(sin(elapsed * 20) * 0.13 * (1 - elapsed / 1.5)) : 0
      bell.childNode(withName: "halo", recursively: false)?.removeFromParentNode()
      if elapsed >= 0 {
        let geometry = SCNTorus(ringRadius: 0.4, pipeRadius: 0.02)
        geometry.materials = [gold]
        let halo = SCNNode(geometry: geometry)
        halo.name = "halo"
        halo.position.y = 0.13
        let scale = Float(1 + (reduceMotion ? 0 : min(elapsed, 1) * 0.2))
        halo.scale = SCNVector3(scale, 1, scale)
        bell.addChildNode(halo)
      }
    }
  }

  private func rim(_ cell: Cell, material: SCNMaterial, dashed: Bool) {
    let p = point(cell)
    for sign: Float in [-1, 1] {
      if dashed {
        for offset: Float in [-0.32, 0, 0.32] {
          box(marksRoot, (0.18, 0.016, 0.025), (p.x + offset, 0.085, p.z + sign * 0.43), material)
          box(marksRoot, (0.025, 0.016, 0.18), (p.x + sign * 0.43, 0.085, p.z + offset), material)
        }
      } else {
        box(marksRoot, (0.9, 0.025, 0.035), (p.x, 0.093, p.z + sign * 0.45), material)
        box(marksRoot, (0.035, 0.025, 0.9), (p.x + sign * 0.45, 0.093, p.z), material)
      }
    }
  }

  private func makePiece(_ piece: Piece, cell: Cell) -> SCNNode {
    let root = SCNNode()
    root.position = point(cell)
    let tint: SCNMaterial
    switch piece.kind {
    case .straight: tint = Diorama.material(0x8FAF9F, shine: 0.4)
    case .turn: tint = Diorama.material(0xB8A1B4, shine: 0.4)
    case .bridge: tint = water
    case .fork: tint = coral
    }
    box(root, (0.78, 0.065, 0.78), (0, 0.045, 0), tint, bevel: 0.1)
    for port in piece.ports {
      box(
        root, (port.dx == 0 ? 0.085 : 0.52, 0.022, port.dy == 0 ? 0.085 : 0.52),
        (Float(port.dx) * 0.26, 0.09, Float(port.dy) * 0.26), gold)
    }
    if piece.kind == .bridge {
      let direction = piece.ports.first { puzzle.water.contains(cell.moved($0)) } ?? piece.ports[1]
      for index in 0..<10 {
        let distance = Float(index) * 0.14
        let height = sin(distance / 1.4 * .pi) * 0.26
        box(
          root, (direction.dx == 0 ? 0.27 : 0.16, 0.04, direction.dy == 0 ? 0.27 : 0.16),
          (Float(direction.dx) * distance, 0.16 + height, Float(direction.dy) * distance), tint)
      }
    }
    let offsets = [(0, 0)] + piece.ports.map { ($0.dx, $0.dy) }
    var nodes: [SCNNode] = []
    for offset in offsets {
      let pivot = SCNNode()
      pivot.position = SCNVector3(Float(offset.0) * 0.27, 0.09, Float(offset.1) * 0.27)
      root.addChildNode(pivot)
      let body = box(pivot, (0.15, 0.58, 0.33), (0, 0.29, 0), porcelain, bevel: 0.035)
      if offset.1 != 0 { body.eulerAngles.y = .pi / 2 }
      for sign: Float in [-1, 1] {
        box(body, (0.004, 0.009, 0.27), (sign * 0.078, 0, 0), gold)
        for y: Float in [-0.13, 0.13] {
          sphere(
            body, radius: 0.03, at: (sign * 0.08, y, 0), material: dark,
            scale: SCNVector3(0.12, 1, 1))
        }
      }
      nodes.append(pivot)
    }
    dominoes[cell] = nodes
    return root
  }

  func snapshot(size: CGSize) -> UIImage {
    let renderer = SCNRenderer(device: nil, options: nil)
    renderer.scene = scene
    renderer.pointOfView = camera
    return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
  }
}
