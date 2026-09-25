import AppKit
import NightjarCore
import SceneKit
import SwiftUI
import simd

struct StageView: NSViewRepresentable {
  @ObservedObject var store: ShowStore

  func makeNSView(context: Context) -> LightingView {
    let view = LightingView()
    view.onAim = { point in store.aim(at: point) }
    view.onFixture = { id in store.selectedFixture = id }
    return view
  }

  func updateNSView(_ view: LightingView, context: Context) {
    view.update(
      fixtures: store.show.live, selected: store.selectedFixture,
      haze: store.showHaze, camera: store.camera, aiming: store.isAiming
    )
  }
}

final class LightingView: SCNView {
  var onAim: ((Vector3) -> Void)?
  var onFixture: ((Int) -> Void)?
  private var aiming = false
  private let stage = SCNScene()
  private let cameraNode = SCNNode()
  private var fixtures: [Int: SCNNode] = [:]
  private var beams: [Int: SCNNode] = [:]
  private let targetMarker = SCNNode()
  private var currentCamera: StageCamera?

  init() {
    super.init(frame: .zero, options: nil)
    scene = stage
    backgroundColor = NSColor(red: 0.025, green: 0.033, blue: 0.047, alpha: 1)
    stage.background.contents = NSColor(red: 0.025, green: 0.033, blue: 0.047, alpha: 1)
    antialiasingMode = .multisampling4X
    autoenablesDefaultLighting = false
    rendersContinuously = false
    preferredFramesPerSecond = 30
    allowsCameraControl = false
    setAccessibilityLabel("Interactive three dimensional stage")
    setAccessibilityIdentifier("stage-canvas")
    buildStage()
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private func material(_ color: NSColor, metallic: CGFloat = 0, roughness: CGFloat = 0.8)
    -> SCNMaterial
  {
    let material = SCNMaterial()
    material.lightingModel = .blinn
    material.diffuse.contents = color
    material.emission.contents = color.blended(withFraction: 0.86, of: .black)
    material.specular.contents = NSColor(white: metallic * 0.25, alpha: 1)
    material.shininess = 0.35
    material.metalness.contents = metallic
    material.roughness.contents = roughness
    return material
  }

  private func box(
    _ width: CGFloat, _ height: CGFloat, _ length: CGFloat,
    at position: SCNVector3, color: NSColor, bevel: CGFloat = 0.02
  ) -> SCNNode {
    let geometry = SCNBox(width: width, height: height, length: length, chamferRadius: bevel)
    geometry.materials = [material(color)]
    let node = SCNNode(geometry: geometry)
    node.position = position
    stage.rootNode.addChildNode(node)
    return node
  }

  private func buildStage() {
    let ambient = SCNNode()
    ambient.light = SCNLight()
    ambient.light?.type = .ambient
    ambient.light?.color = NSColor(red: 0.52, green: 0.61, blue: 0.8, alpha: 1)
    ambient.light?.intensity = 360
    stage.rootNode.addChildNode(ambient)

    let workLight = SCNNode()
    workLight.light = SCNLight()
    workLight.light?.type = .directional
    workLight.light?.color = NSColor(red: 0.55, green: 0.65, blue: 0.85, alpha: 1)
    workLight.light?.intensity = 180
    workLight.eulerAngles = .init(-0.8, -0.5, 0)
    stage.rootNode.addChildNode(workLight)

    cameraNode.camera = SCNCamera()
    cameraNode.camera?.fieldOfView = 40
    cameraNode.camera?.zNear = 0.1
    cameraNode.camera?.zFar = 80
    cameraNode.camera?.wantsHDR = false
    cameraNode.camera?.wantsExposureAdaptation = false
    cameraNode.camera?.bloomIntensity = 0.08
    cameraNode.camera?.bloomThreshold = 1.2
    cameraNode.camera?.bloomBlurRadius = 5
    stage.rootNode.addChildNode(cameraNode)
    pointOfView = cameraNode

    let floor = box(13, 0.35, 9, at: .init(0, -0.2, 0), color: .init(white: 0.21, alpha: 1))
    floor.name = "stage-floor"
    floor.categoryBitMask = 2
    floor.geometry?.firstMaterial?.roughness.contents = 0.55
    _ = box(13, 0.18, 0.18, at: .init(0, -0.15, 4.5), color: .init(white: 0.4, alpha: 1))
    _ = box(13, 0.6, 0.25, at: .init(0, -0.62, 3.8), color: .init(white: 0.10, alpha: 1))
    for z in stride(from: -4.0, through: 4, by: 1) {
      _ = box(
        12.8, 0.006, 0.012, at: .init(0, -0.018, Float(z)), color: .init(white: 0.28, alpha: 1),
        bevel: 0)
    }
    for x in stride(from: -6.0, through: 6, by: 1) {
      _ = box(
        0.012, 0.006, 8.8, at: .init(Float(x), -0.018, 0), color: .init(white: 0.28, alpha: 1),
        bevel: 0)
    }
    _ = box(13, 5.8, 0.3, at: .init(0, 2.7, -4.5), color: .init(white: 0.09, alpha: 1))
    for index in 0..<33 {
      let x = -6.4 + Float(index) * 0.4
      _ = box(0.12, 5.5, 0.15, at: .init(x, 2.65, -4.27), color: .init(white: 0.14, alpha: 1))
    }
    for x: Float in [-6.4, 6.4] {
      _ = box(0.12, 6.6, 0.12, at: .init(x, 3.1, -3.8), color: .init(white: 0.34, alpha: 1))
      _ = box(0.12, 6.6, 0.12, at: .init(x, 3.1, 3.5), color: .init(white: 0.34, alpha: 1))
    }
    for z: Float in [-3.8, 3.5] {
      _ = box(13, 0.1, 0.1, at: .init(0, 6.3, z), color: .init(white: 0.34, alpha: 1))
    }
    let plinthGeometry = SCNCylinder(radius: 1.8, height: 0.25)
    plinthGeometry.radialSegmentCount = 96
    plinthGeometry.materials = [material(.init(white: 0.48, alpha: 1), roughness: 0.5)]
    let plinth = SCNNode(geometry: plinthGeometry)
    plinth.position = .init(0, 0.12, -0.5)
    stage.rootNode.addChildNode(plinth)

    let ringGeometry = SCNTorus(ringRadius: 1.42, pipeRadius: 0.15)
    ringGeometry.ringSegmentCount = 96
    ringGeometry.materials = [material(.init(white: 0.8, alpha: 1), metallic: 0.35, roughness: 0.3)]
    let ring = SCNNode(geometry: ringGeometry)
    ring.eulerAngles.x = .pi / 2
    ring.position = .init(0, 1.82, -1)
    stage.rootNode.addChildNode(ring)

    for (x, height) in [(-3.1, 0.95), (3.1, 1.45), (-3.8, 0.5), (3.8, 0.65)] {
      _ = box(
        0.65, height, 0.65, at: .init(Float(x), Float(height / 2), -1.5),
        color: .init(white: 0.57, alpha: 1))
    }
    let bodyGeometry = SCNCapsule(capRadius: 0.15, height: 0.75)
    bodyGeometry.materials = [material(.init(white: 0.72, alpha: 1))]
    let body = SCNNode(geometry: bodyGeometry)
    body.position = .init(0, 0.92, 0.15)
    stage.rootNode.addChildNode(body)
    let head = SCNNode(geometry: SCNSphere(radius: 0.145))
    head.geometry?.materials = [material(.init(white: 0.8, alpha: 1))]
    head.position = .init(0, 1.48, 0.15)
    stage.rootNode.addChildNode(head)
    for x: Float in [-0.09, 0.09] {
      let leg = SCNNode(geometry: SCNCapsule(capRadius: 0.06, height: 0.48))
      leg.geometry?.materials = [material(.init(white: 0.6, alpha: 1))]
      leg.position = .init(x, 0.49, 0.15)
      stage.rootNode.addChildNode(leg)
    }

    let markerGeometry = SCNTorus(ringRadius: 0.23, pipeRadius: 0.013)
    let markerMaterial = SCNMaterial()
    markerMaterial.lightingModel = .constant
    markerMaterial.diffuse.contents = NSColor.white
    markerGeometry.materials = [markerMaterial]
    targetMarker.geometry = markerGeometry
    targetMarker.castsShadow = false
    stage.rootNode.addChildNode(targetMarker)

    for id in 0..<6 {
      let rig = SCNNode()
      rig.name = "fixture-\(id)"
      let light = SCNLight()
      light.type = .spot
      light.castsShadow = true
      light.shadowMode = .forward
      light.shadowRadius = 4
      light.shadowSampleCount = 8
      light.shadowMapSize = CGSize(width: 1024, height: 1024)
      light.shadowColor = NSColor(white: 0, alpha: 0.7)
      light.attenuationStartDistance = 2
      light.attenuationEndDistance = 25
      rig.light = light
      let housing = SCNNode(geometry: SCNCylinder(radius: 0.16, height: 0.38))
      housing.eulerAngles.x = .pi / 2
      housing.castsShadow = false
      housing.geometry?.materials = [material(.init(white: 0.27, alpha: 1), metallic: 0.7)]
      housing.name = "fixture-\(id)"
      rig.addChildNode(housing)
      let lens = SCNNode(geometry: SCNCylinder(radius: 0.135, height: 0.012))
      lens.eulerAngles.x = .pi / 2
      lens.castsShadow = false
      lens.position.z = -0.2
      lens.name = "lens"
      let lensMaterial = SCNMaterial()
      lensMaterial.lightingModel = .constant
      lens.geometry?.materials = [lensMaterial]
      rig.addChildNode(lens)
      stage.rootNode.addChildNode(rig)
      fixtures[id] = rig

      let beam = SCNNode()
      beam.castsShadow = false
      beam.renderingOrder = 10
      stage.rootNode.addChildNode(beam)
      beams[id] = beam
    }
  }

  func update(
    fixtures values: [Fixture], selected: Int, haze: Bool, camera: StageCamera, aiming: Bool
  ) {
    self.aiming = aiming
    if currentCamera != camera {
      currentCamera = camera
      SCNTransaction.begin()
      SCNTransaction.animationDuration = 0.5
      cameraNode.camera?.usesOrthographicProjection = camera == .overhead
      cameraNode.camera?.orthographicScale = 9
      switch camera {
      case .perspective: cameraNode.position = .init(10.5, 8.5, 14.5)
      case .front: cameraNode.position = .init(0, 7.2, 20)
      case .overhead: cameraNode.position = .init(0, 24, 0.01)
      }
      cameraNode.look(at: camera == .overhead ? .init(0, 0, 0) : .init(0, 2.2, -0.2))
      SCNTransaction.commit()
    }
    for fixture in values {
      guard let rig = fixtures[fixture.id], let beam = beams[fixture.id] else { continue }
      rig.position = fixture.position.scn
      rig.look(at: fixture.target.scn)
      rig.light?.color = fixture.color.nsColor
      rig.light?.intensity = fixture.intensity * 950
      rig.light?.spotInnerAngle = CGFloat(fixture.beam * 0.55)
      rig.light?.spotOuterAngle = CGFloat(fixture.beam)
      if let lens = rig.childNode(withName: "lens", recursively: false) {
        lens.geometry?.firstMaterial?.diffuse.contents = fixture.color.nsColor
        lens.opacity = CGFloat(max(0.1, fixture.intensity))
      }
      let from = SIMD3<Float>(
        Float(fixture.position.x), Float(fixture.position.y), Float(fixture.position.z))
      let to = SIMD3<Float>(
        Float(fixture.target.x), Float(fixture.target.y), Float(fixture.target.z))
      let length = simd_distance(from, to)
      let cone = SCNCone(
        topRadius: 0.07, bottomRadius: CGFloat(length) * tan(CGFloat(fixture.beam * .pi / 360)),
        height: CGFloat(length)
      )
      cone.radialSegmentCount = 48
      let beamMaterial = SCNMaterial()
      beamMaterial.lightingModel = .constant
      beamMaterial.diffuse.contents = fixture.color.nsColor.withAlphaComponent(
        0.065 * fixture.intensity)
      beamMaterial.blendMode = .add
      beamMaterial.writesToDepthBuffer = false
      beamMaterial.readsFromDepthBuffer = true
      cone.materials = [beamMaterial]
      beam.geometry = cone
      beam.simdPosition = (from + to) / 2
      beam.simdOrientation = simd_quatf(from: SIMD3<Float>(0, -1, 0), to: simd_normalize(to - from))
      beam.isHidden = !haze || fixture.intensity == 0
      if fixture.id == selected {
        targetMarker.position = .init(Float(fixture.target.x), 0.025, Float(fixture.target.z))
        targetMarker.geometry?.firstMaterial?.diffuse.contents = fixture.color.nsColor
      }
    }
    needsDisplay = true
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    if aiming {
      let hits = hitTest(
        point, options: [.categoryBitMask: 2, .searchMode: SCNHitTestSearchMode.all.rawValue])
      if let floor = hits.first(where: { $0.node.name == "stage-floor" }) {
        onAim?(Vector3(Double(floor.worldCoordinates.x), 0, Double(floor.worldCoordinates.z)))
      }
    } else {
      let hits = hitTest(point, options: [:])
      for hit in hits {
        let name = hit.node.name ?? hit.node.parent?.name ?? ""
        if name.hasPrefix("fixture-"), let id = Int(name.dropFirst(8)) {
          onFixture?(id)
          break
        }
      }
    }
  }
}

extension Vector3 {
  var scn: SCNVector3 { .init(Float(x), Float(y), Float(z)) }
}

extension LightColor {
  var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }
  var swiftColor: Color { Color(nsColor: nsColor) }
}
