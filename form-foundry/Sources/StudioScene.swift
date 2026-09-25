import SceneKit
import SwiftUI

enum CameraView: String, CaseIterable {
  case studio = "Studio"
  case top = "Top"
  case front = "Front"
  case right = "Right"
}

struct StudioScene: UIViewRepresentable {
  var solids: [Solid]
  var selectedID: UUID?
  var cameraView: CameraView
  var cameraCommand: Int
  var zoom: Double
  var onSelect: (UUID) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

  func makeUIView(context: Context) -> SCNView {
    let view = SCNView()
    view.scene = context.coordinator.scene
    view.backgroundColor = UIColor(red: 0.94, green: 0.93, blue: 0.90, alpha: 1)
    view.antialiasingMode = .multisampling4X
    view.autoenablesDefaultLighting = false
    view.allowsCameraControl = true
    view.defaultCameraController.interactionMode = .orbitTurntable
    view.defaultCameraController.inertiaEnabled = true
    view.defaultCameraController.target = SCNVector3(0, 20, 0)
    view.defaultCameraController.minimumVerticalAngle = 5
    view.defaultCameraController.maximumVerticalAngle = 88
    view.pointOfView = context.coordinator.camera
    let tap = UITapGestureRecognizer(
      target: context.coordinator, action: #selector(Coordinator.selectSolid(_:)))
    view.addGestureRecognizer(tap)
    view.accessibilityLabel =
      "3D modeling canvas. Drag to orbit, pinch to zoom, tap a solid to select."
    return view
  }

  func updateUIView(_ view: SCNView, context: Context) {
    context.coordinator.update(solids: solids, selectedID: selectedID)
    if context.coordinator.command != cameraCommand {
      context.coordinator.command = cameraCommand
      context.coordinator.setCamera(cameraView, zoom: zoom, view: view)
    }
  }

  final class Coordinator: NSObject {
    let scene = SCNScene()
    let camera = SCNNode()
    let assembly = SCNNode()
    var command = -1
    var previous: [Solid] = []
    var previousSelection: UUID?
    var onSelect: (UUID) -> Void

    init(onSelect: @escaping (UUID) -> Void) {
      self.onSelect = onSelect
      super.init()
      scene.rootNode.addChildNode(assembly)
      camera.camera = SCNCamera()
      camera.camera?.usesOrthographicProjection = true
      camera.camera?.orthographicScale = 230
      camera.camera?.zNear = 1
      camera.camera?.zFar = 3000
      camera.camera?.wantsHDR = false
      camera.camera?.screenSpaceAmbientOcclusionIntensity = 0.55
      camera.camera?.screenSpaceAmbientOcclusionRadius = 10
      scene.rootNode.addChildNode(camera)

      let floor = SCNFloor()
      floor.reflectivity = 0
      floor.firstMaterial?.diffuse.contents = UIColor(red: 0.94, green: 0.93, blue: 0.90, alpha: 1)
      floor.firstMaterial?.roughness.contents = 0.95
      floor.firstMaterial?.lightingModel = .physicallyBased
      let ground = SCNNode(geometry: floor)
      ground.position.y = -0.35
      scene.rootNode.addChildNode(ground)
      for i in -25...25 {
        let strong = i % 5 == 0
        let color = UIColor(white: strong ? 0.65 : 0.74, alpha: strong ? 0.36 : 0.20)
        let across = SCNBox(
          width: 500, height: 0.015, length: strong ? 0.20 : 0.10, chamferRadius: 0)
        across.firstMaterial?.diffuse.contents = color
        across.firstMaterial?.lightingModel = .constant
        let acrossNode = SCNNode(geometry: across)
        acrossNode.position = SCNVector3(0, -0.26, Double(i) * 10)
        scene.rootNode.addChildNode(acrossNode)
        let down = SCNBox(width: strong ? 0.20 : 0.10, height: 0.015, length: 500, chamferRadius: 0)
        down.firstMaterial = across.firstMaterial
        let downNode = SCNNode(geometry: down)
        downNode.position = SCNVector3(Double(i) * 10, -0.25, 0)
        scene.rootNode.addChildNode(downNode)
      }
      let key = SCNNode()
      key.light = SCNLight()
      key.light?.type = .directional
      key.light?.intensity = 1100
      key.light?.color = UIColor(red: 1, green: 0.96, blue: 0.88, alpha: 1)
      key.light?.castsShadow = true
      key.light?.shadowMode = .deferred
      key.light?.shadowRadius = 6
      key.light?.shadowColor = UIColor(white: 0.22, alpha: 0.28)
      key.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
      key.light?.orthographicScale = 350
      key.position = SCNVector3(-150, 320, 140)
      key.look(at: SCNVector3Zero)
      scene.rootNode.addChildNode(key)
      let fill = SCNNode()
      fill.light = SCNLight()
      fill.light?.type = .ambient
      fill.light?.intensity = 650
      fill.light?.color = UIColor(red: 0.87, green: 0.91, blue: 1, alpha: 1)
      scene.rootNode.addChildNode(fill)
    }

    func update(solids: [Solid], selectedID: UUID?) {
      guard solids != previous || selectedID != previousSelection else { return }
      previous = solids
      previousSelection = selectedID
      for child in assembly.childNodes { child.removeFromParentNode() }
      for solid in solids {
        let mesh = Mesh.make(for: solid)
        let vertices = mesh.triangles.flatMap { $0.map { mesh.vertices[$0] } }
        var normals: [SCNVector3] = []
        for triangle in mesh.triangles {
          let a = mesh.vertices[triangle[0]]
          let b = mesh.vertices[triangle[1]]
          let c = mesh.vertices[triangle[2]]
          let u = SIMD3(b.x - a.x, b.y - a.y, b.z - a.z)
          let v = SIMD3(c.x - a.x, c.y - a.y, c.z - a.z)
          let normal = simd_normalize(simd_cross(u, v))
          normals += Array(repeating: SCNVector3(normal.x, normal.y, normal.z), count: 3)
        }
        let source = SCNGeometrySource(vertices: vertices.map { SCNVector3($0.x, $0.y, $0.z) })
        let normalSource = SCNGeometrySource(normals: normals)
        let indices = (0..<vertices.count).map(Int32.init)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [source, normalSource], elements: [element])
        let rgb = solid.finish.rgb
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        material.roughness.contents = 0.70
        material.metalness.contents = 0.05
        material.lightingModel = .physicallyBased
        geometry.firstMaterial = material
        let node = SCNNode(geometry: geometry)
        node.name = solid.id.uuidString
        assembly.addChildNode(node)
        if solid.id == selectedID {
          let outline = SCNBox(
            width: solid.width + 0.6, height: solid.height + 0.6,
            length: solid.depth + 0.6, chamferRadius: 0
          )
          outline.firstMaterial?.diffuse.contents = UIColor(
            red: 0.88, green: 0.26, blue: 0.15, alpha: 1)
          outline.firstMaterial?.lightingModel = .constant
          outline.firstMaterial?.fillMode = .lines
          let cage = SCNNode(geometry: outline)
          cage.position = SCNVector3(solid.x, solid.y + solid.height / 2, solid.z)
          cage.eulerAngles.y = Float(solid.rotation * .pi / 180)
          assembly.addChildNode(cage)
        }
      }
    }

    func setCamera(_ mode: CameraView, zoom: Double, view: SCNView) {
      let target = SCNVector3(0, 18, 0)
      switch mode {
      case .studio: camera.position = SCNVector3(240, 265, 335)
      case .top: camera.position = SCNVector3(0, 520, 0.01)
      case .front: camera.position = SCNVector3(0, 18, 520)
      case .right: camera.position = SCNVector3(520, 18, 0)
      }
      camera.look(at: target)
      camera.camera?.orthographicScale = 230 * zoom
      view.pointOfView = camera
      view.defaultCameraController.target = target
      view.defaultCameraController.clearRoll()
    }

    @objc func selectSolid(_ recognizer: UITapGestureRecognizer) {
      guard let view = recognizer.view as? SCNView else { return }
      let hits = view.hitTest(recognizer.location(in: view))
      for hit in hits {
        if let name = hit.node.name, let id = UUID(uuidString: name) {
          onSelect(id)
          return
        }
      }
    }
  }
}
