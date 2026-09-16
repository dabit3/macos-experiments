import ARKit
import Combine
import RealityKit
import SwiftUI
import UIKit

/// Values the SwiftUI HUD reads, published at ~12Hz.
struct HUDReadout: Equatable {
  var phase: PowerPhase = .off
  var transition: Double = 0
  var tokensPerSecond: Double = 0
  var watts: Double = 0
  var fan: Double = 0
  var uptime: Double = 0
  var scale: Double = 1
  var placed = false
}

/// Owns the ARView, the rig entity and the frame loop. Works in real AR when
/// world tracking exists, and as a showroom viewer with an orbit camera otherwise.
final class RigScene: NSObject, ObservableObject {
  @Published var readout = HUDReadout()
  @Published private(set) var isAR: Bool
  @Published var status = ""

  let arView: ARView
  let audio: SynthAudio
  var onPowerToggle: ((PowerPhase) -> Void)?
  var onScaleChanged: ((Double) -> Void)?
  var onSimulation: ((RigSimulation) -> Void)?

  private(set) var simulation: RigSimulation
  private var parts: RigParts
  private let rigAnchor: AnchorEntity
  private var camera: PerspectiveCamera?
  private var cameraYaw: Float = 0.1
  private var cameraPitch: Float = 0.22
  private var cameraDistanceFactor: Float = 1.7
  private var subscription: Cancellable?
  private var lastPublish: TimeInterval = 0
  private var lastHologram: TimeInterval = 0
  private var lastLEDBucket = -1
  private var pinchStartScale: Double = 1
  private var targetScale: Double
  private var idleSpin = true
  private var idleTime: TimeInterval = 0
  private var coaching: ARCoachingOverlayView?
  private var lastPhase: PowerPhase = .off

  init(kind: RigKind, scale: Double, audio: SynthAudio) {
    let supportsAR = ARWorldTrackingConfiguration.isSupported
    isAR = supportsAR
    self.audio = audio
    simulation = RigSimulation(kind: kind, scale: scale)
    targetScale = scale
    parts = RigBuilder.build(kind)
    if supportsAR {
      arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
      rigAnchor = AnchorEntity(plane: .horizontal, classification: .any, minimumBounds: [0.2, 0.2])
    } else {
      arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
      rigAnchor = AnchorEntity(world: .zero)
    }
    super.init()
    configureScene()
  }

  var kind: RigKind { simulation.kind }

  private func configureScene() {
    arView.renderOptions = [.disableMotionBlur, .disableDepthOfField]
    parts.root.scale = SIMD3(repeating: Float(targetScale))
    parts.root.generateCollisionShapes(recursive: true)
    rigAnchor.addChild(parts.root)
    arView.scene.addAnchor(rigAnchor)

    if isAR {
      arView.environment.sceneUnderstanding.options = [.occlusion, .receivesLighting]
      let configuration = ARWorldTrackingConfiguration()
      configuration.planeDetection = [.horizontal]
      configuration.environmentTexturing = .automatic
      if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
        configuration.frameSemantics.insert(.personSegmentationWithDepth)
      }
      arView.session.delegate = self
      arView.session.run(configuration)
      let overlay = ARCoachingOverlayView()
      overlay.session = arView.session
      overlay.goal = .horizontalPlane
      overlay.activatesAutomatically = true
      overlay.translatesAutoresizingMaskIntoConstraints = false
      arView.addSubview(overlay)
      NSLayoutConstraint.activate([
        overlay.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
        overlay.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
        overlay.topAnchor.constraint(equalTo: arView.topAnchor),
        overlay.bottomAnchor.constraint(equalTo: arView.bottomAnchor),
      ])
      coaching = overlay
      status = "Scan the floor to place your rig"
    } else {
      arView.environment.background = .color(UIColor(red: 0.04, green: 0.045, blue: 0.05, alpha: 1))
      configureShowroom()
      readout.placed = true
      status = "Showroom mode — AR needs a real device"
    }

    let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
    let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    pan.maximumNumberOfTouches = 1
    let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotate))
    for recognizer in [tap, pinch, pan, rotate] { arView.addGestureRecognizer(recognizer) }
    pinch.delegate = self
    rotate.delegate = self

    subscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
      self?.frame(event.deltaTime)
    }
  }

  private func configureShowroom() {
    let floor = ModelEntity(
      mesh: .generatePlane(width: 60, depth: 60),
      materials: [RigBuilder.textured(ProceduralTextures.grid(), roughness: 0.9)])
    floor.position = [0, -0.002, 0]
    rigAnchor.addChild(floor)

    let key = DirectionalLight()
    key.light.intensity = 2600
    key.light.color = UIColor(red: 0.9, green: 0.95, blue: 1, alpha: 1)
    key.orientation = simd_quatf(angle: -0.9, axis: normalize([1, 0.2, 0.3]))
    key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 30, depthBias: 2)
    rigAnchor.addChild(key)
    let fill = DirectionalLight()
    fill.light.intensity = 900
    fill.light.color = UIColor(red: 0.6, green: 0.9, blue: 0.5, alpha: 1)
    fill.orientation = simd_quatf(angle: -2.4, axis: normalize([0.4, 1, -0.5]))
    rigAnchor.addChild(fill)

    let camera = PerspectiveCamera()
    camera.camera.fieldOfViewInDegrees = 55
    rigAnchor.addChild(camera)
    self.camera = camera
    updateCamera()
  }

  private func updateCamera() {
    guard let camera else { return }
    let size = Float(targetScale)
    let height = parts.height * size
    let focus = SIMD3<Float>(0, height * 0.52, 0)
    let distance = max(0.5, parts.extent * size * cameraDistanceFactor + 0.6 * size)
    let position =
      focus
      + SIMD3(
        cos(cameraPitch) * sin(cameraYaw) * distance, sin(cameraPitch) * distance,
        cos(cameraPitch) * cos(cameraYaw) * distance)
    camera.position = position
    camera.look(at: focus, from: position, relativeTo: nil)
  }

  // MARK: Frame loop

  private func frame(_ delta: TimeInterval) {
    let previous = simulation.phase
    simulation.tick(delta)
    if simulation.phase != previous {
      if simulation.phase == .running {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      }
      if simulation.phase == .off { audio.setFan(0) }
    }
    audio.setFan(simulation.fan)

    // Smoothly ease the entity toward the requested scale.
    let current = Double(parts.root.scale.x)
    if abs(current - targetScale) > 0.0005 {
      let next = current + (targetScale - current) * min(1, delta * 9)
      parts.root.scale = SIMD3(repeating: Float(next))
      simulation.scale = next
      updateCamera()
    }
    if !isAR && idleSpin {
      idleTime += delta
      cameraYaw = 0.1 + 0.4 * Float(sin(idleTime * 0.25))
      updateCamera()
    }

    let angle = Float(simulation.fanAngle)
    for fan in parts.fans {
      fan.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
    }

    let bucket = Int(simulation.ledPulse * 40)
    if bucket != lastLEDBucket {
      lastLEDBucket = bucket
      let level = Float(simulation.ledPulse)
      for led in parts.leds {
        if var material = led.model?.materials.first as? UnlitMaterial {
          let tint = ledTint(for: led)
          material.color = .init(
            tint: RigBuilder.blend(
              UIColor(red: 0.05, green: 0.09, blue: 0.03, alpha: 1), tint, level))
          led.model?.materials = [material]
        }
      }
      for accent in parts.accents {
        accent.model?.materials = [RigBuilder.led(level: level * 0.9, color: RigBuilder.mint)]
      }
      parts.hologram?.model?.materials = [
        RigBuilder.led(level: max(0.15, level), color: RigBuilder.mint)
      ]
      parts.hologramRing?.model?.materials = [RigBuilder.haloMaterial(alpha: level * 0.55)]
      parts.floorHalo?.model?.materials = [RigBuilder.haloMaterial(alpha: level * 0.7)]
      parts.glowLight?.light.intensity =
        level * (isAR ? 9000 : 4000) * Float(simulation.scale * simulation.scale)
      parts.hologram?.isEnabled = simulation.phase != .off
      parts.hologramRing?.isEnabled = simulation.phase != .off
      parts.floorHalo?.isEnabled = simulation.phase != .off
    }

    let now = CACurrentMediaTime()
    if simulation.phase != .off, now - lastHologram > 0.18 {
      lastHologram = now
      let text: String
      switch simulation.phase {
      case .booting: text = "BOOTING \(Int(simulation.transition * 100))%"
      case .running: text = "\(Format.tokens(simulation.tokensPerSecond)) tok/s"
      case .shuttingDown: text = "HALTING"
      case .off: text = ""
      }
      if let hologram = parts.hologram {
        hologram.model?.mesh = RigBuilder.hologramMesh(text)
        let bounds = hologram.model?.mesh.bounds ?? .empty
        hologram.position = [
          -(bounds.min.x + bounds.max.x) / 2, -(bounds.min.y + bounds.max.y) / 2, 0,
        ]
        parts.hologramPivot?.position.y = parts.hologramBaseY + Float(sin(now * 1.3)) * 0.02
      }
    }
    if let hologram = parts.hologramPivot, parts.hologram?.isEnabled == true {
      if isAR, let cameraTransform = arView.session.currentFrame?.camera.transform {
        let cameraPosition = SIMD3(
          cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let local = parts.root.convert(position: cameraPosition, from: nil)
        let yaw = atan2(local.x, local.z)
        hologram.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        parts.hologramRing?.orientation = simd_quatf(angle: Float(now * 0.6), axis: [0, 1, 0])
      } else {
        hologram.orientation = simd_quatf(angle: cameraYaw, axis: [0, 1, 0])
        parts.hologramRing?.orientation = simd_quatf(angle: Float(now * 0.6), axis: [0, 1, 0])
      }
    }

    if now - lastPublish > 1 / 12 {
      lastPublish = now
      var next = readout
      next.phase = simulation.phase
      next.transition = simulation.transition
      next.tokensPerSecond = simulation.tokensPerSecond
      next.watts = simulation.watts
      next.fan = simulation.fan
      next.uptime = simulation.uptime
      next.scale = simulation.scale
      if next != readout { readout = next }
      onSimulation?(simulation)
    }
  }

  private func ledTint(for led: ModelEntity) -> UIColor {
    if led.name == "amber" { return UIColor(red: 1, green: 0.62, blue: 0.16, alpha: 1) }
    return RigBuilder.green
  }

  // MARK: Controls

  func togglePower() {
    let phase = simulation.togglePower()
    if phase == .booting {
      audio.bootChime()
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    } else {
      audio.powerDown()
      UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
    onPowerToggle?(phase)
  }

  func setScale(_ multiplier: Double, announce: Bool = true) {
    let clamped = ScalePreset.clamp(multiplier)
    if announce {
      audio.scaleWhoosh(up: clamped > targetScale)
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    targetScale = clamped
    onScaleChanged?(clamped)
  }

  func swapKind(_ kind: RigKind) {
    guard kind != simulation.kind else { return }
    parts.root.removeFromParent()
    parts = RigBuilder.build(kind)
    parts.root.scale = SIMD3(repeating: Float(targetScale))
    parts.root.generateCollisionShapes(recursive: true)
    rigAnchor.addChild(parts.root)
    simulation = RigSimulation(kind: kind, scale: targetScale)
    lastLEDBucket = -1
    audio.tick()
    UISelectionFeedbackGenerator().selectionChanged()
    updateCamera()
  }

  func snapshot(_ completion: @escaping (UIImage?) -> Void) {
    audio.shutter()
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    arView.snapshot(saveToHDR: false) { image in
      DispatchQueue.main.async { completion(image) }
    }
  }

  @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
    let point = gesture.location(in: arView)
    if let hit = arView.entity(at: point), hit.isDescendant(of: parts.root) {
      togglePower()
      return
    }
    if isAR,
      let result = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal)
        .first
    {
      let position = result.worldTransform.columns.3
      parts.root.setPosition([position.x, position.y, position.z], relativeTo: nil)
      audio.tick()
      UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    } else if !isAR {
      idleSpin.toggle()
      audio.tick()
    }
  }

  @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
    switch gesture.state {
    case .began:
      pinchStartScale = targetScale
    case .changed:
      let next = ScalePreset.clamp(pinchStartScale * Double(gesture.scale))
      targetScale = next
      onScaleChanged?(next)
    case .ended:
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    default: break
    }
  }

  @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: arView)
    gesture.setTranslation(.zero, in: arView)
    if isAR {
      let center = gesture.location(in: arView)
      if let result = arView.raycast(
        from: center, allowing: .estimatedPlane, alignment: .horizontal
      ).first {
        let position = result.worldTransform.columns.3
        parts.root.setPosition([position.x, position.y, position.z], relativeTo: nil)
      }
    } else {
      idleSpin = false
      cameraYaw -= Float(translation.x) * 0.006
      cameraPitch = min(1.2, max(-0.1, cameraPitch + Float(translation.y) * 0.004))
      updateCamera()
    }
  }

  @objc private func handleRotate(_ gesture: UIRotationGestureRecognizer) {
    parts.root.orientation =
      simd_quatf(angle: -Float(gesture.rotation), axis: [0, 1, 0]) * parts.root.orientation
    gesture.rotation = 0
  }

  func pause() { arView.session.pause() }
}

extension RigScene: UIGestureRecognizerDelegate {
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
  ) -> Bool {
    true
  }
}

extension RigScene: ARSessionDelegate {
  func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
    guard !readout.placed, anchors.contains(where: { $0 is ARPlaneAnchor }) else { return }
    DispatchQueue.main.async {
      self.readout.placed = true
      self.status = "Tap the rig to power it on"
      UINotificationFeedbackGenerator().notificationOccurred(.success)
      self.audio.tick()
    }
  }
  func session(_ session: ARSession, didFailWithError error: Error) {
    DispatchQueue.main.async { self.status = "AR unavailable: \(error.localizedDescription)" }
  }
}

extension Entity {
  func isDescendant(of ancestor: Entity) -> Bool {
    var node: Entity? = self
    while let current = node {
      if current === ancestor { return true }
      node = current.parent
    }
    return false
  }
}

struct RigViewContainer: UIViewRepresentable {
  let scene: RigScene
  func makeUIView(context: Context) -> ARView { scene.arView }
  func updateUIView(_ uiView: ARView, context: Context) {}
}
