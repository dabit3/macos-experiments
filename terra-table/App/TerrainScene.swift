import SceneKit
import SwiftUI
import UIKit

@MainActor
final class SceneCapture: ObservableObject {
  weak var view: SCNView?

  func exportImage() throws -> URL {
    guard let data = view?.snapshot().pngData() else { throw CocoaError(.fileWriteUnknown) }
    let directory = URL.documentsDirectory.appendingPathComponent("Exports")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("TerraTable.png")
    try data.write(to: url, options: .atomic)
    return url
  }
}

struct TerrainCanvas: UIViewRepresentable {
  @ObservedObject var model: StudioModel
  let capture: SceneCapture

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }

  func makeUIView(context: Context) -> SCNView {
    let view = SCNView()
    view.backgroundColor = UIColor(red: 0.947, green: 0.941, blue: 0.909, alpha: 1)
    view.antialiasingMode = .multisampling4X
    view.preferredFramesPerSecond = 30
    view.autoenablesDefaultLighting = false
    view.accessibilityLabel = "Interactive terrain. Drag to sculpt; select Orbit to rotate."
    view.accessibilityIdentifier = "terrainCanvas"
    context.coordinator.install(in: view)
    capture.view = view
    return view
  }

  func updateUIView(_ view: SCNView, context: Context) {
    context.coordinator.update()
  }

  @MainActor
  final class Coordinator: NSObject {
    let model: StudioModel
    weak var view: SCNView?
    let scene = SCNScene()
    let terrainNode = SCNNode()
    let waterNode = SCNNode()
    let skirtNode = SCNNode()
    let cameraNode = SCNNode()
    let cursorNode = SCNNode()
    var lastRevision = -1
    var lastContours = false
    var lastHome = 0
    var yaw: Float = .pi / 4
    var pitch: Float = 0.66
    var lastDrag = CGPoint.zero
    var lastPoint: SCNVector3?
    var pinchStart: Float = 1

    init(model: StudioModel) { self.model = model }

    func install(in view: SCNView) {
      self.view = view
      view.scene = scene
      scene.rootNode.addChildNode(terrainNode)
      terrainNode.name = "terrain"
      scene.rootNode.addChildNode(skirtNode)
      let base = SCNBox(width: 10.16, height: 0.42, length: 10.16, chamferRadius: 0.07)
      base.firstMaterial?.diffuse.contents = UIColor(red: 0.43, green: 0.40, blue: 0.32, alpha: 1)
      let baseNode = SCNNode(geometry: base)
      baseNode.position.y = -0.23
      scene.rootNode.addChildNode(baseNode)

      let floor = SCNFloor()
      floor.reflectivity = 0
      floor.firstMaterial?.diffuse.contents = UIColor(
        red: 0.947, green: 0.941, blue: 0.909, alpha: 1)
      floor.firstMaterial?.lightingModel = .constant
      let floorNode = SCNNode(geometry: floor)
      floorNode.position.y = -0.46
      scene.rootNode.addChildNode(floorNode)

      let shadowImage = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image {
        context in
        let colors = [UIColor.black.withAlphaComponent(0.2).cgColor, UIColor.clear.cgColor]
        if let gradient = CGGradient(
          colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])
        {
          context.cgContext.drawRadialGradient(
            gradient, startCenter: CGPoint(x: 128, y: 128), startRadius: 50,
            endCenter: CGPoint(x: 128, y: 128), endRadius: 128, options: [])
        }
      }
      let shadow = SCNPlane(width: 14, height: 14)
      shadow.firstMaterial?.diffuse.contents = shadowImage
      shadow.firstMaterial?.lightingModel = .constant
      shadow.firstMaterial?.writesToDepthBuffer = false
      let shadowNode = SCNNode(geometry: shadow)
      shadowNode.eulerAngles.x = -.pi / 2
      shadowNode.position = SCNVector3(0.35, -0.45, 0.35)
      scene.rootNode.addChildNode(shadowNode)

      let water = SCNBox(width: 10.02, height: 0.035, length: 10.02, chamferRadius: 0)
      let waterMaterial = SCNMaterial()
      waterMaterial.diffuse.contents = UIColor(red: 0.27, green: 0.66, blue: 0.66, alpha: 1)
      waterMaterial.metalness.contents = 0.12
      waterMaterial.roughness.contents = 0.28
      waterMaterial.lightingModel = .constant
      waterMaterial.shaderModifiers = [
        .surface: """
        float ripples = sin(_surface.position.x * 34.0 + _surface.position.z * 21.0)
            * sin(_surface.position.z * 38.0) * 0.006;
        _surface.diffuse.rgb += float3(ripples);
        """
      ]
      let waterSide = SCNMaterial()
      waterSide.diffuse.contents = UIColor(red: 0.20, green: 0.53, blue: 0.53, alpha: 1)
      waterSide.lightingModel = .constant
      water.materials = [waterSide, waterSide, waterSide, waterSide, waterMaterial, waterSide]
      waterNode.geometry = water
      scene.rootNode.addChildNode(waterNode)

      let ambient = SCNNode()
      ambient.light = SCNLight()
      ambient.light?.type = .ambient
      ambient.light?.intensity = 450
      ambient.light?.color = UIColor(red: 0.94, green: 0.96, blue: 1, alpha: 1)
      scene.rootNode.addChildNode(ambient)

      let sun = SCNNode()
      sun.light = SCNLight()
      sun.light?.type = .directional
      sun.light?.intensity = 650
      sun.light?.castsShadow = true
      sun.light?.shadowMode = .deferred
      sun.light?.shadowColor = UIColor.black.withAlphaComponent(0.16)
      sun.light?.shadowRadius = 8
      sun.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
      sun.light?.orthographicScale = 16
      sun.eulerAngles = SCNVector3(-Float.pi / 3, -Float.pi / 5, 0)
      scene.rootNode.addChildNode(sun)

      cameraNode.camera = SCNCamera()
      cameraNode.camera?.usesOrthographicProjection = true
      cameraNode.camera?.zNear = 0.1
      cameraNode.camera?.zFar = 100
      cameraNode.camera?.wantsHDR = false
      scene.rootNode.addChildNode(cameraNode)
      view.pointOfView = cameraNode

      cursorNode.geometry = SCNTorus(ringRadius: CGFloat(model.radius), pipeRadius: 0.018)
      cursorNode.geometry?.firstMaterial?.diffuse.contents = UIColor.white
      cursorNode.geometry?.firstMaterial?.emission.contents = UIColor.white
      cursorNode.isHidden = true
      scene.rootNode.addChildNode(cursorNode)

      let pan = UIPanGestureRecognizer(target: self, action: #selector(drag(_:)))
      pan.maximumNumberOfTouches = 1
      view.addGestureRecognizer(pan)
      view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(_:))))
      view.addGestureRecognizer(
        UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:))))
      update()
    }

    func update() {
      if lastRevision != model.revision || lastContours != model.contours {
        rebuildMesh()
        lastRevision = model.revision
        lastContours = model.contours
      }
      if lastHome != model.homeRevision {
        yaw = .pi / 4
        pitch = 0.66
        lastHome = model.homeRevision
      }
      (waterNode.geometry as? SCNBox)?.height = CGFloat(model.terrain.water * 3 + 0.02)
      waterNode.position.y = (model.terrain.water * 3 - 0.02) / 2
      waterNode.isHidden = model.terrain.water < 0.02
      updateCamera()
    }

    func updateCamera() {
      let distance: Float = 20
      cameraNode.position = SCNVector3(
        sin(yaw) * cos(pitch) * distance,
        sin(pitch) * distance + 0.5,
        cos(yaw) * cos(pitch) * distance)
      cameraNode.look(
        at: SCNVector3(0, 0.5, 0), up: SCNVector3(0, 1, 0),
        localFront: SCNVector3(0, 0, -1))
      cameraNode.camera?.orthographicScale = Double(8.0 / model.zoom)
    }

    func rebuildMesh() {
      let n = Terrain.resolution
      let heights = model.terrain.heights
      let step: Float = 10 / Float(n - 1)
      var vertices: [SCNVector3] = []
      var normals: [SCNVector3] = []
      var coordinates: [CGPoint] = []
      var colors: [Float] = []
      var indices: [Int32] = []
      for z in 0..<n {
        for x in 0..<n {
          let h = heights[z * n + x]
          vertices.append(SCNVector3(Float(x) * step - 5, h * 3, Float(z) * step - 5))
          coordinates.append(CGPoint(x: CGFloat(h * 3), y: 0))
          let dx = (heights[z * n + min(n - 1, x + 1)] - heights[z * n + max(0, x - 1)]) * 3
          let dz = (heights[min(n - 1, z + 1) * n + x] - heights[max(0, z - 1) * n + x]) * 3
          let length = sqrt(dx * dx + 4 * step * step + dz * dz)
          normals.append(SCNVector3(-dx / length, 2 * step / length, -dz / length))
          let color = terrainColor(h, slope: hypot(dx, dz), water: model.terrain.water)
          colors.append(contentsOf: color)
          if x < n - 1 && z < n - 1 {
            let a = Int32(z * n + x)
            indices.append(contentsOf: [
              a, a + Int32(n), a + 1, a + 1, a + Int32(n), a + Int32(n) + 1,
            ])
          }
        }
      }
      let colorData = colors.withUnsafeBufferPointer { Data(buffer: $0) }
      let colorSource = SCNGeometrySource(
        data: colorData, semantic: .color, vectorCount: vertices.count, usesFloatComponents: true,
        componentsPerVector: 4, bytesPerComponent: 4, dataOffset: 0, dataStride: 16)
      let geometry = SCNGeometry(
        sources: [
          SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals),
          SCNGeometrySource(textureCoordinates: coordinates), colorSource,
        ],
        elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
      let material = SCNMaterial()
      material.diffuse.contents = UIColor.white
      material.roughness.contents = 0.95
      material.lightingModel = .lambert
      if model.contours {
        material.shaderModifiers = [
          .surface: """
            float level = _surface.diffuseTexcoord.x / 0.15;
          float line = 1.0 - smoothstep(0.025, 0.075, abs(fract(level) - 0.5));
          _surface.diffuse.rgb = mix(_surface.diffuse.rgb, float3(0.14, 0.22, 0.17), line * 0.72);
          """
        ]
      }
      geometry.materials = [material]
      terrainNode.geometry = geometry

      var skirtVertices: [SCNVector3] = []
      var skirtIndices: [Int32] = []
      var edge: [Int] = []
      for x in 0..<n { edge.append(x) }
      for z in 1..<n { edge.append(z * n + n - 1) }
      for x in stride(from: n - 2, through: 0, by: -1) { edge.append((n - 1) * n + x) }
      for z in stride(from: n - 2, through: 1, by: -1) { edge.append(z * n) }
      for index in edge {
        let vertex = vertices[index]
        skirtVertices.append(vertex)
        skirtVertices.append(SCNVector3(vertex.x, -0.02, vertex.z))
      }
      for i in 0..<edge.count {
        let a = Int32(i * 2)
        let b = Int32(((i + 1) % edge.count) * 2)
        skirtIndices.append(contentsOf: [a, b, a + 1, a + 1, b, b + 1])
      }
      let skirt = SCNGeometry(
        sources: [SCNGeometrySource(vertices: skirtVertices)],
        elements: [SCNGeometryElement(indices: skirtIndices, primitiveType: .triangles)])
      skirt.firstMaterial?.diffuse.contents = UIColor(red: 0.39, green: 0.36, blue: 0.25, alpha: 1)
      skirt.firstMaterial?.isDoubleSided = true
      skirtNode.geometry = skirt
    }

    func terrainColor(_ height: Float, slope: Float, water: Float) -> [Float] {
      let sand: [Float] = [0.77, 0.73, 0.49, 1]
      let moss: [Float] = [0.35, 0.47, 0.25, 1]
      let forest: [Float] = [0.19, 0.34, 0.23, 1]
      let stone: [Float] = [0.58, 0.60, 0.55, 1]
      let snow: [Float] = [0.90, 0.90, 0.84, 1]
      if height < water + 0.045 { return sand }
      if height > 0.80 { return mix(stone, snow, min(1, (height - 0.80) * 5)) }
      if height > 0.56 || slope > 0.25 {
        return mix(forest, stone, min(1, max((height - 0.50) * 3, slope * 2)))
      }
      return mix(moss, forest, min(1, (height - water) * 2.7))
    }

    func mix(_ a: [Float], _ b: [Float], _ amount: Float) -> [Float] {
      zip(a, b).map { $0 + ($1 - $0) * max(0, amount) }
    }

    func terrainPoint(_ location: CGPoint) -> SCNVector3? {
      guard let view else { return nil }
      let hits = view.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
      return hits.first(where: { $0.node === terrainNode })?.localCoordinates
    }

    func paint(_ point: SCNVector3) {
      if let previous = lastPoint {
        let distance = hypot(point.x - previous.x, point.z - previous.z)
        let steps = max(1, min(40, Int(distance / 0.09)))
        for i in 1...steps {
          let t = Float(i) / Float(steps)
          model.sculpt(
            x: previous.x + (point.x - previous.x) * t,
            z: previous.z + (point.z - previous.z) * t)
        }
      } else {
        model.sculpt(x: point.x, z: point.z)
      }
      lastPoint = point
      cursorNode.isHidden = false
      cursorNode.position = SCNVector3(
        point.x, max(point.y, model.terrain.water * 3) + 0.04, point.z)
      (cursorNode.geometry as? SCNTorus)?.ringRadius = CGFloat(model.radius)
    }

    @objc func drag(_ gesture: UIPanGestureRecognizer) {
      let position = gesture.location(in: view)
      if gesture.state == .began {
        lastDrag = position
        lastPoint = nil
        if model.brush != .orbit { model.begin() }
      }
      if gesture.state == .began || gesture.state == .changed {
        if model.brush == .orbit {
          yaw -= Float(position.x - lastDrag.x) * 0.009
          pitch = max(0.24, min(1.35, pitch + Float(position.y - lastDrag.y) * 0.006))
          updateCamera()
        } else if let point = terrainPoint(position) {
          paint(point)
        }
        lastDrag = position
      }
      if [.ended, .cancelled, .failed].contains(gesture.state) {
        model.end()
        lastPoint = nil
        cursorNode.isHidden = true
      }
    }

    @objc func tap(_ gesture: UITapGestureRecognizer) {
      guard model.brush != .orbit, let point = terrainPoint(gesture.location(in: view)) else {
        return
      }
      model.begin()
      for _ in 0..<4 { model.sculpt(x: point.x, z: point.z) }
      model.end()
    }

    @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
      if gesture.state == .began { pinchStart = model.zoom }
      model.zoom = max(0.7, min(1.8, pinchStart * Float(gesture.scale)))
      updateCamera()
    }
  }
}
