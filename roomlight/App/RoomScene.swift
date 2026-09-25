import SceneKit
import SwiftUI
import UIKit

struct RoomScene: UIViewRepresentable {
  let room: Room
  let yaw: Double
  let zoom: Double

  final class Coordinator {
    var room: Room?
    var camera = SCNNode()
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> SCNView {
    let view = SCNView()
    view.backgroundColor = UIColor(Palette.oat)
    view.antialiasingMode = .multisampling4X
    view.autoenablesDefaultLighting = false
    view.isPlaying = false
    view.accessibilityLabel = "Live three-dimensional room preview"
    return view
  }

  func updateUIView(_ view: SCNView, context: Context) {
    if context.coordinator.room != room {
      context.coordinator.room = room
      view.scene = SceneFactory.build(room)
      let camera = SCNNode()
      camera.camera = SCNCamera()
      camera.camera?.usesOrthographicProjection = true
      camera.camera?.zNear = 0.1
      camera.camera?.zFar = 100
      camera.camera?.wantsHDR = false
      camera.camera?.screenSpaceAmbientOcclusionIntensity = 0.7
      camera.camera?.screenSpaceAmbientOcclusionRadius = 0.3
      view.scene?.rootNode.addChildNode(camera)
      view.pointOfView = camera
      context.coordinator.camera = camera
    }
    let camera = context.coordinator.camera
    let distance = 12.0
    camera.position = SCNVector3(sin(yaw) * distance, 10, cos(yaw) * distance)
    camera.look(at: SCNVector3(0, 0.35, 0))
    camera.camera?.orthographicScale = max(room.width, room.depth) * zoom
    view.setNeedsDisplay()
  }
}

@MainActor
enum SceneFactory {
  static func material(_ color: UIColor, roughness: Double = 0.8) -> SCNMaterial {
    let material = SCNMaterial()
    material.diffuse.contents = color
    material.roughness.contents = roughness
    material.lightingModel = .physicallyBased
    return material
  }

  static func box(
    _ parent: SCNNode, _ w: Double, _ h: Double, _ d: Double,
    _ x: Double, _ y: Double, _ z: Double, _ color: UIColor,
    radius: Double = 0.025
  ) {
    let geometry = SCNBox(width: w, height: h, length: d, chamferRadius: min(radius, h / 3))
    geometry.materials = [material(color)]
    let node = SCNNode(geometry: geometry)
    node.position = SCNVector3(x, y, z)
    parent.addChildNode(node)
  }

  static func cylinder(
    _ parent: SCNNode, radius: Double, height: Double,
    x: Double, y: Double, z: Double, color: UIColor
  ) {
    let geometry = SCNCylinder(radius: radius, height: height)
    geometry.radialSegmentCount = 28
    geometry.materials = [material(color)]
    let node = SCNNode(geometry: geometry)
    node.position = SCNVector3(x, y, z)
    parent.addChildNode(node)
  }

  static func build(_ room: Room) -> SCNScene {
    let scene = SCNScene()
    scene.background.contents = UIColor(Palette.oat)
    let root = scene.rootNode
    let base = UIColor(red: 0.62, green: 0.53, blue: 0.41, alpha: 1)
    box(root, room.width + 0.18, 0.22, room.depth + 0.18, 0, -0.14, 0, base, radius: 0.03)
    let floor = SCNBox(width: room.width, height: 0.06, length: room.depth, chamferRadius: 0)
    let floorMat = material(UIColor(Palette.floor(room.floor)))
    floorMat.diffuse.contents = floorTexture(room.floor)
    floorMat.diffuse.wrapS = .repeat
    floorMat.diffuse.wrapT = .repeat
    floorMat.diffuse.contentsTransform = SCNMatrix4MakeScale(
      Float(room.width / 2), Float(room.depth / 2), 1)
    floor.materials = [floorMat]
    root.addChildNode(SCNNode(geometry: floor))
    let wall = UIColor(Palette.wall(room.wall))
    let height = 1.55
    box(root, room.width + 0.16, height, 0.12, 0, height / 2, -room.depth / 2 - 0.06, wall)
    box(root, 0.12, height, room.depth, -room.width / 2 - 0.06, height / 2, 0, wall)
    let trim = UIColor(red: 0.94, green: 0.91, blue: 0.84, alpha: 1)
    box(root, room.width, 0.09, 0.025, 0, 0.08, -room.depth / 2 + 0.02, trim, radius: 0)
    box(root, 0.025, 0.09, room.depth, -room.width / 2 + 0.02, 0.08, 0, trim, radius: 0)
    // The fixed clerestory is a decorative daylight opening.
    box(root, 2.25, 0.68, 0.035, 0, 1.02, -room.depth / 2 + 0.02, trim)
    box(
      root, 2.08, 0.53, 0.05, 0, 1.02, -room.depth / 2 + 0.045,
      UIColor(red: 0.76, green: 0.85, blue: 0.84, alpha: 1), radius: 0)
    for x in [-0.7, 0.0, 0.7] {
      box(root, 0.035, 0.55, 0.065, x, 1.02, -room.depth / 2 + 0.07, trim, radius: 0)
    }
    for item in room.furniture {
      let node = furniture(item.kind)
      node.position = SCNVector3(item.x - room.width / 2, 0.04, item.z - room.depth / 2)
      node.eulerAngles.y = Float(-Double(item.rotation) * .pi / 180)
      root.addChildNode(node)
    }
    let ambient = SCNNode()
    ambient.light = SCNLight()
    ambient.light?.type = .ambient
    ambient.light?.intensity = 650
    ambient.light?.color = UIColor(red: 0.89, green: 0.92, blue: 1, alpha: 1)
    root.addChildNode(ambient)
    let sun = SCNNode()
    sun.light = SCNLight()
    sun.light?.type = .directional
    sun.light?.intensity = 1450
    sun.light?.color = UIColor(red: 1, green: 0.91, blue: 0.76, alpha: 1)
    sun.light?.castsShadow = true
    sun.light?.shadowMode = .deferred
    sun.light?.shadowRadius = 5
    sun.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
    sun.light?.shadowColor = UIColor.black.withAlphaComponent(0.22)
    sun.eulerAngles = SCNVector3(-Double.pi / 3, -Double.pi / 5, 0)
    root.addChildNode(sun)
    return scene
  }

  static func furniture(_ kind: FurnitureKind) -> SCNNode {
    let node = SCNNode()
    let cream = UIColor(red: 0.87, green: 0.82, blue: 0.71, alpha: 1)
    let wood = UIColor(red: 0.45, green: 0.28, blue: 0.15, alpha: 1)
    let oak = UIColor(red: 0.68, green: 0.49, blue: 0.29, alpha: 1)
    let clay = UIColor(Palette.clay)
    let w = kind.width
    let d = kind.depth
    switch kind {
    case .sofa, .chair:
      for x in [-w / 2 + 0.14, w / 2 - 0.14] {
        for z in [-d / 2 + 0.12, d / 2 - 0.12] {
          cylinder(node, radius: 0.035, height: 0.18, x: x, y: 0.09, z: z, color: wood)
        }
      }
      box(node, w, 0.24, d, 0, 0.27, 0, cream, radius: 0.1)
      box(node, w - 0.08, 0.45, 0.18, 0, 0.59, -d / 2 + 0.1, cream, radius: 0.08)
      for x in [-w / 2 + 0.08, w / 2 - 0.08] {
        box(node, 0.16, 0.33, d - 0.08, x, 0.47, 0.02, cream, radius: 0.06)
      }
      let count = kind == .sofa ? 3 : 1
      let seatW = (w - 0.38) / Double(count)
      for i in 0..<count {
        let x = -w / 2 + 0.19 + seatW * (Double(i) + 0.5)
        box(
          node, seatW - 0.025, 0.16, d - 0.3, x, 0.43, 0.07,
          UIColor(red: 0.94, green: 0.89, blue: 0.79, alpha: 1), radius: 0.07)
      }
      if kind == .sofa {
        box(node, 0.34, 0.28, 0.15, -w / 2 + 0.44, 0.62, -0.16, clay, radius: 0.07)
        box(
          node, 0.32, 0.28, 0.15, w / 2 - 0.4, 0.62, -0.16,
          UIColor(red: 0.44, green: 0.5, blue: 0.38, alpha: 1), radius: 0.07)
      }
    case .coffeeTable:
      box(node, w, 0.10, d, 0, 0.39, 0, wood, radius: 0.12)
      for x in [-0.37, 0.37] {
        cylinder(node, radius: 0.09, height: 0.34, x: x, y: 0.17, z: 0, color: wood)
      }
      box(node, 0.26, 0.03, 0.22, -0.2, 0.46, 0, cream, radius: 0.002)
      cylinder(node, radius: 0.09, height: 0.12, x: 0.28, y: 0.5, z: 0, color: clay)
    case .console:
      box(node, w, 0.55, d, 0, 0.42, 0, oak)
      for i in 0..<24 {
        box(node, 0.025, 0.50, 0.035, -0.86 + Double(i) * 0.074, 0.43, d / 2, wood, radius: 0.007)
      }
      for x in [-0.7, 0.7] {
        box(node, 0.07, 0.16, 0.3, x, 0.08, 0, wood)
      }
      cylinder(node, radius: 0.1, height: 0.22, x: 0.5, y: 0.80, z: 0, color: cream)
      box(node, 0.34, 0.04, 0.24, -0.45, 0.72, 0, clay)
    case .diningTable:
      box(node, w, 0.09, d, 0, 0.76, 0, oak, radius: 0.07)
      for x in [-0.58, 0.58] {
        for z in [-0.28, 0.28] {
          cylinder(node, radius: 0.045, height: 0.72, x: x, y: 0.36, z: z, color: oak)
        }
      }
      for x in [-0.42, 0.42] {
        cylinder(node, radius: 0.15, height: 0.025, x: x, y: 0.82, z: 0, color: cream)
      }
    case .rug:
      box(node, w, 0.022, d, 0, 0.015, 0, UIColor(Palette.oat), radius: 0.006)
      for z in [-d / 2 + 0.12, d / 2 - 0.12] {
        box(node, w - 0.1, 0.002, 0.08, 0, 0.028, z, clay.withAlphaComponent(0.65), radius: 0)
      }
      for i in 0..<42 {
        box(
          node, w - 0.1, 0.002, 0.007, 0, 0.03, -d / 2 + 0.04 + Double(i) * 0.048,
          UIColor(red: 0.77, green: 0.72, blue: 0.61, alpha: 1), radius: 0)
      }
    case .plant:
      let pot = SCNCone(topRadius: 0.22, bottomRadius: 0.15, height: 0.4)
      pot.materials = [material(clay)]
      let potNode = SCNNode(geometry: pot)
      potNode.position.y = 0.2
      node.addChildNode(potNode)
      cylinder(node, radius: 0.018, height: 0.9, x: 0, y: 0.75, z: 0, color: wood)
      for i in 0..<9 {
        let angle = Double(i) * 2.4
        let leaf = SCNSphere(radius: 0.17)
        leaf.materials = [
          material(UIColor(red: 0.24 + Double(i % 3) * 0.035, green: 0.39, blue: 0.23, alpha: 1))
        ]
        let leafNode = SCNNode(geometry: leaf)
        leafNode.scale = SCNVector3(0.75, 0.2, 1.5)
        leafNode.position = SCNVector3(
          cos(angle) * 0.17, 0.62 + Double(i) * 0.075, sin(angle) * 0.17)
        leafNode.eulerAngles = SCNVector3(0.35, angle, 0.2)
        node.addChildNode(leafNode)
      }
    case .lamp:
      cylinder(node, radius: 0.19, height: 0.04, x: 0, y: 0.02, z: 0, color: wood)
      cylinder(node, radius: 0.016, height: 1.3, x: 0, y: 0.65, z: 0, color: oak)
      let shade = SCNSphere(radius: 0.25)
      let m = material(cream)
      m.emission.contents = UIColor(red: 0.24, green: 0.20, blue: 0.10, alpha: 1)
      shade.materials = [m]
      let shadeNode = SCNNode(geometry: shade)
      shadeNode.position.y = 1.35
      shadeNode.scale.y = 1.15
      node.addChildNode(shadeNode)
      for i in 0..<9 {
        let y = -0.2 + Double(i) * 0.05
        let ring = SCNTorus(ringRadius: sqrt(max(0, 0.0625 - y * y)), pipeRadius: 0.002)
        ring.materials = [material(oak)]
        let ringNode = SCNNode(geometry: ring)
        ringNode.position.y = Float(1.35 + y * 1.15)
        node.addChildNode(ringNode)
      }
    }
    return node
  }

  static func floorTexture(_ floor: FloorMaterial) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512))
    return renderer.image { output in
      let c = output.cgContext
      UIColor(Palette.floor(floor)).setFill()
      c.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
      for i in 0..<16 {
        let x = Double(i) * 32
        c.setFillColor(UIColor.white.withAlphaComponent(Double(i % 4) * 0.035).cgColor)
        c.fill(CGRect(x: x, y: 0, width: 31, height: 512))
        c.setStrokeColor(UIColor.black.withAlphaComponent(0.13).cgColor)
        c.setLineWidth(1)
        c.move(to: CGPoint(x: x, y: 0))
        c.addLine(to: CGPoint(x: x, y: 512))
        c.strokePath()
        for j in 0..<7 {
          let y = Double((i * 67 + j * 79) % 512)
          c.setStrokeColor(
            UIColor.black.withAlphaComponent(floor == .limestone ? 0.015 : 0.06).cgColor)
          c.move(to: CGPoint(x: x + Double(j % 4) * 7 + 2, y: y))
          c.addCurve(
            to: CGPoint(x: x + Double(j % 4) * 7 + 5, y: y + 65),
            control1: CGPoint(x: x + 18, y: y + 20),
            control2: CGPoint(x: x + 10, y: y + 45))
          c.strokePath()
        }
      }
    }
  }
}
