import SceneKit
import UIKit
import simd

final class BoardwalkScene {
  let scene = SCNScene()
  let camera = SCNNode()
  private let skater = SCNNode()
  private let rider = SCNNode()
  private let upperBody = SCNNode()
  private var legs: [(SCNNode, SCNNode, Float)] = []
  private var crouch: Float = 0
  private var landing: Float = 0
  private var previousHeight = 0.0
  private let shadow = SCNNode()
  private let shield = SCNNode()
  private let world = SCNNode()
  private let wheel = SCNNode()
  private var scenery: [(SCNNode, Float)] = []
  private var obstacles: [Int: SCNNode] = [:]
  private var pickups: [Int: SCNNode] = [:]
  private var leftArm = SCNNode()
  private var rightArm = SCNNode()
  private let teal = UIColor(red: 0.22, green: 1, blue: 0.88, alpha: 1)
  private let pink = UIColor(red: 1, green: 0.20, blue: 0.60, alpha: 1)
  private let ink = UIColor(red: 0.035, green: 0.05, blue: 0.13, alpha: 1)

  init() {
    scene.background.contents = sky()
    scene.fogColor = UIColor(red: 0.20, green: 0.12, blue: 0.30, alpha: 1)
    scene.fogStartDistance = 65
    scene.fogEndDistance = 140
    scene.rootNode.addChildNode(world)
    camera.camera = SCNCamera()
    camera.camera?.fieldOfView = 69
    camera.camera?.zFar = 210
    camera.camera?.wantsHDR = true
    camera.camera?.bloomIntensity = 0.55
    camera.camera?.bloomThreshold = 1.1
    camera.camera?.bloomBlurRadius = 8
    camera.camera?.exposureOffset = -0.15
    camera.position = SCNVector3(0, 8.2, 16.5)
    camera.look(at: SCNVector3(0, 1.1, -20))
    scene.rootNode.addChildNode(camera)
    let ambient = SCNNode()
    ambient.light = SCNLight()
    ambient.light?.type = .ambient
    ambient.light?.color = UIColor(red: 0.58, green: 0.52, blue: 0.75, alpha: 1)
    ambient.light?.intensity = 400
    scene.rootNode.addChildNode(ambient)
    let key = SCNNode()
    key.light = SCNLight()
    key.light?.type = .omni
    key.light?.color = UIColor(red: 1, green: 0.66, blue: 0.59, alpha: 1)
    key.light?.intensity = 650
    key.position = SCNVector3(-6, 15, 5)
    scene.rootNode.addChildNode(key)
    createCoast()
    createTrack()
    createSkater()
  }

  private func material(_ color: UIColor, glow: CGFloat = 0, shiny: Bool = false) -> SCNMaterial {
    let result = SCNMaterial()
    result.diffuse.contents = color
    result.lightingModel = .physicallyBased
    result.roughness.contents = shiny ? 0.25 : 0.75
    result.metalness.contents = shiny ? 0.55 : 0.05
    if glow > 0 {
      result.emission.contents = color
      result.emission.intensity = glow
    }
    return result
  }

  @discardableResult
  private func box(
    _ parent: SCNNode, _ size: SCNVector3, _ position: SCNVector3,
    _ color: UIColor, glow: CGFloat = 0, radius: CGFloat = 0.04
  ) -> SCNNode {
    let geometry = SCNBox(
      width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z),
      chamferRadius: radius)
    geometry.materials = [material(color, glow: glow, shiny: true)]
    let node = SCNNode(geometry: geometry)
    node.position = position
    parent.addChildNode(node)
    return node
  }

  private func sky() -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 1024))
    return renderer.image { context in
      let colors = [
        UIColor(red: 0.025, green: 0.035, blue: 0.13, alpha: 1).cgColor,
        UIColor(red: 0.20, green: 0.11, blue: 0.31, alpha: 1).cgColor,
        UIColor(red: 0.78, green: 0.30, blue: 0.43, alpha: 1).cgColor,
        UIColor(red: 0.08, green: 0.11, blue: 0.22, alpha: 1).cgColor,
      ]
      if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray,
        locations: [0, 0.28, 0.54, 1])
      {
        context.cgContext.drawLinearGradient(
          gradient, start: .zero, end: CGPoint(x: 0, y: 1024), options: [])
      }
      var seed: UInt64 = 0x5EED
      func next(_ range: UInt64) -> CGFloat {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return CGFloat((seed >> 33) % range)
      }
      for _ in 0..<170 {
        let x = next(512)
        let y = next(380)
        let size = 0.9 + next(3) * 0.5
        let alpha = 0.2 + next(60) / 100
        context.cgContext.setFillColor(UIColor(white: 1, alpha: alpha).cgColor)
        context.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
      }
    }
  }

  private func halo(_ color: UIColor) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image { context in
      let colors = [
        color.withAlphaComponent(0.55).cgColor, color.withAlphaComponent(0.12).cgColor,
        color.withAlphaComponent(0).cgColor,
      ]
      if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray,
        locations: [0, 0.45, 1])
      {
        context.cgContext.drawRadialGradient(
          gradient, startCenter: CGPoint(x: 128, y: 128), startRadius: 0,
          endCenter: CGPoint(x: 128, y: 128), endRadius: 128, options: [])
      }
    }
  }

  private func createCoast() {
    let sun = SCNNode(geometry: SCNSphere(radius: 6.4))
    let sunlight = material(UIColor(red: 1, green: 0.60, blue: 0.39, alpha: 1), glow: 0.7)
    sunlight.lightingModel = .constant
    sun.geometry?.materials = [sunlight]
    sun.position = SCNVector3(-15, 4.6, -85)
    sun.scale.z = 0.1
    world.addChildNode(sun)
    let glow = SCNPlane(width: 30, height: 30)
    let glowMaterial = SCNMaterial()
    glowMaterial.lightingModel = .constant
    glowMaterial.diffuse.contents = halo(UIColor(red: 1, green: 0.55, blue: 0.45, alpha: 1))
    glowMaterial.writesToDepthBuffer = false
    glowMaterial.blendMode = .add
    glow.materials = [glowMaterial]
    let haloNode = SCNNode(geometry: glow)
    haloNode.position = SCNVector3(-15, 5.2, -86)
    world.addChildNode(haloNode)
    for band in 0..<4 {
      let stripe = box(
        world, SCNVector3(14, 0.35 + Float(band) * 0.2, 0.05),
        SCNVector3(-15, 1.6 + Float(band) * 1.55, -84.9),
        UIColor(red: 0.25, green: 0.10, blue: 0.30, alpha: 1), radius: 0)
      stripe.geometry?.firstMaterial?.lightingModel = .constant
    }
    createWheel()
    box(
      world, SCNVector3(180, 0.15, 200), SCNVector3(-42, -0.6, -70),
      UIColor(red: 0.055, green: 0.16, blue: 0.25, alpha: 1), radius: 0)
    for index in 0..<40 {
      box(
        world, SCNVector3(Float(5 + index % 5), 0.01, 0.06),
        SCNVector3(-12 - Float(index % 4) * 9, -0.48, -Float(index) * 4),
        teal.withAlphaComponent(0.2), glow: 0.25, radius: 0)
    }
    for index in 0..<9 {
      let z = -Float(index) * 18
      let block = SCNNode()
      block.position.z = z
      world.addChildNode(block)
      scenery.append((block, z))
      createFacade(parent: block, index: index)
      createPalm(parent: block, x: -6.4, z: -7, height: 6.4 + Float(index % 3))
      if index % 2 == 0 {
        createPalm(parent: block, x: 7.5, z: 1, height: 7.5)
      }
      box(block, SCNVector3(0.13, 1.4, 0.13), SCNVector3(-5.15, 0.7, -4), teal, glow: 0.2)
      box(block, SCNVector3(0.1, 0.1, 18), SCNVector3(-5.15, 1.25, -8), teal, glow: 0.25)
      for strip in 0..<2 {
        let tint = index % 2 == 0 ? pink : teal
        let surface = SCNPlane(width: 1.6, height: CGFloat(6 + strip * 2))
        let reflected = SCNMaterial()
        reflected.lightingModel = .constant
        reflected.diffuse.contents = reflection(tint)
        reflected.writesToDepthBuffer = false
        surface.materials = [reflected]
        let patch = SCNNode(geometry: surface)
        patch.eulerAngles.x = -.pi / 2
        patch.position = SCNVector3(
          3.3 + Float((index + strip) % 3) * 0.3, 0.025, -1 - Float(strip) * 8.5)
        block.addChildNode(patch)
      }
    }
  }

  private func createWheel() {
    wheel.position = SCNVector3(-21, 11.2, -92)
    world.addChildNode(wheel)
    let rim = SCNTorus(ringRadius: 9.5, pipeRadius: 0.16)
    rim.materials = [material(teal, glow: 1.2)]
    let rimNode = SCNNode(geometry: rim)
    rimNode.eulerAngles.x = .pi / 2
    wheel.addChildNode(rimNode)
    let inner = SCNTorus(ringRadius: 6.2, pipeRadius: 0.09)
    inner.materials = [material(pink, glow: 0.9)]
    let innerNode = SCNNode(geometry: inner)
    innerNode.eulerAngles.x = .pi / 2
    wheel.addChildNode(innerNode)
    for spoke in 0..<12 {
      let bar = box(
        wheel, SCNVector3(0.1, 19, 0.1), SCNVector3Zero,
        UIColor(red: 0.55, green: 0.85, blue: 0.95, alpha: 1), glow: 0.5, radius: 0)
      bar.eulerAngles.z = Float(spoke) * .pi / 12
      let cabin = box(
        wheel, SCNVector3(0.9, 0.9, 0.7), SCNVector3Zero, spoke % 2 == 0 ? pink : teal, glow: 1,
        radius: 0.2)
      let angle = Float(spoke) * .pi * 2 / 12
      cabin.position = SCNVector3(cos(angle) * 9.5, sin(angle) * 9.5, 0)
    }
    for x: Float in [-4.5, 4.5] {
      let leg = box(
        world, SCNVector3(0.35, 26, 0.35), SCNVector3(-21 + x, 0, -92.2),
        UIColor(red: 0.10, green: 0.10, blue: 0.20, alpha: 1), radius: 0)
      leg.eulerAngles.z = x < 0 ? -0.18 : 0.18
    }
  }

  private func reflection(_ color: UIColor) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { context in
      let colors = [color.withAlphaComponent(0.11).cgColor, color.withAlphaComponent(0).cgColor]
      if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])
      {
        context.cgContext.drawRadialGradient(
          gradient, startCenter: CGPoint(x: 64, y: 64), startRadius: 0,
          endCenter: CGPoint(x: 64, y: 64), endRadius: 64, options: [])
      }
      context.cgContext.setBlendMode(.clear)
      for index in 0..<12 {
        context.cgContext.fill(CGRect(x: 0, y: index * 11, width: 128, height: 2))
      }
    }
  }

  private func createFacade(parent: SCNNode, index: Int) {
    let colors = [
      UIColor(red: 0.14, green: 0.15, blue: 0.30, alpha: 1),
      UIColor(red: 0.24, green: 0.12, blue: 0.26, alpha: 1),
      UIColor(red: 0.09, green: 0.21, blue: 0.29, alpha: 1),
    ]
    let height = Float(5 + index % 3)
    let color = colors[index % colors.count]
    let accent = index % 2 == 0 ? pink : teal
    box(parent, SCNVector3(7, height, 12), SCNVector3(9.1, height / 2, -6), color)
    box(parent, SCNVector3(7.2, 0.10, 12.2), SCNVector3(9.1, height, -6), accent, glow: 1)
    if index % 3 != 0 {
      box(
        parent, SCNVector3(4.3, 1.3 + Float(index % 2), 7),
        SCNVector3(10.2, height + 0.65, -7), color)
      box(
        parent, SCNVector3(4.4, 0.08, 7.1),
        SCNVector3(10.2, height + 1.3 + Float(index % 2) * 0.5, -7), accent, glow: 0.4)
    }
    box(
      parent, SCNVector3(0.12, height - 0.4, 0.12), SCNVector3(5.52, height / 2, -0.1), accent,
      glow: 1)
    for window in 0..<4 {
      box(
        parent, SCNVector3(0.08, 2.2, 1.55), SCNVector3(5.55, 1.8, -1.6 - Float(window) * 2.65), ink
      )
      box(
        parent, SCNVector3(0.10, 0.05, 1.6), SCNVector3(5.45, 2.85, -1.6 - Float(window) * 2.65),
        accent, glow: 1)
      box(
        parent, SCNVector3(0.10, 1.1, 0.08), SCNVector3(5.44, 1.7, -1.6 - Float(window) * 2.65),
        accent, glow: 0.55)
    }
    box(parent, SCNVector3(2.5, 0.2, 10), SCNVector3(5.5, 3.1, -6), color)
    box(parent, SCNVector3(0.08, 0.09, 10), SCNVector3(4.25, 3.1, -6), accent, glow: 1.2)
    let words = [
      "ARCADE", "AFTERGLOW", "SKATE", "PALMS", "SODA", "COAST", "GLOW", "NIGHT", "WAVES",
    ]
    let sign = SCNNode()
    box(sign, SCNVector3(2.6, 1.15, 0.18), SCNVector3(0, 0, 0), ink)
    let letters = SCNText(string: words[index], extrusionDepth: 0.015)
    letters.font = UIFont.systemFont(ofSize: 0.43, weight: .heavy)
    letters.flatness = 0.2
    letters.materials = [material(accent, glow: 1.4)]
    let text = SCNNode(geometry: letters)
    let bounds = text.boundingBox
    let width = bounds.max.x - bounds.min.x
    text.scale = SCNVector3(min(1, 2.3 / width), 1, 1)
    text.position = SCNVector3(-min(width, 2.3) / 2, -0.22, 0.14)
    sign.addChildNode(text)
    sign.position = SCNVector3(5.8, 4.25, 0.4)
    parent.addChildNode(sign)
  }

  private func createPalm(parent: SCNNode, x: Float, z: Float, height: Float) {
    let palm = SCNNode()
    palm.position = SCNVector3(x, 0, z)
    let trunk = SCNCylinder(radius: 0.16, height: CGFloat(height))
    trunk.materials = [material(UIColor(red: 0.085, green: 0.095, blue: 0.17, alpha: 1))]
    let stem = SCNNode(geometry: trunk)
    stem.position.y = height / 2
    stem.eulerAngles.z = x < 0 ? -0.06 : 0.06
    palm.addChildNode(stem)
    for frond in 0..<7 {
      let path = UIBezierPath()
      path.move(to: .zero)
      path.addQuadCurve(to: CGPoint(x: 3.3, y: -0.8), controlPoint: CGPoint(x: 1.8, y: 1.5))
      path.addQuadCurve(to: .zero, controlPoint: CGPoint(x: 1.7, y: 0.5))
      let shape = SCNShape(path: path, extrusionDepth: 0.025)
      shape.materials = [material(UIColor(red: 0.035, green: 0.16, blue: 0.20, alpha: 1))]
      let leaf = SCNNode(geometry: shape)
      leaf.position.y = height
      leaf.eulerAngles.y = Float(frond) * .pi * 2 / 7
      palm.addChildNode(leaf)
    }
    parent.addChildNode(palm)
  }

  private func createTrack() {
    box(world, SCNVector3(10.2, 0.3, 180), SCNVector3(0, -0.2, -70), ink, radius: 0)
    for x: Float in [-4.65, 4.65] {
      box(world, SCNVector3(0.09, 0.04, 180), SCNVector3(x, 0.01, -70), teal, glow: 0.8)
    }
    for index in 0..<220 {
      let plank = SCNNode()
      let z = -Float(index) * 0.75
      let grain = Double((index * 7) % 5) * 0.006
      box(
        plank, SCNVector3(9.2, 0.04, 0.71), SCNVector3(0, -0.03, 0),
        UIColor(red: 0.13 + grain, green: 0.12 + grain, blue: 0.19 + grain, alpha: 1),
        radius: 0)
      box(
        plank, SCNVector3(0.025, 0.005, 0.71),
        SCNVector3(Float(index % 4) * 2.1 - 3.2, -0.006, 0), ink, radius: 0)
      for x: Float in [-1.5, 1.5] {
        let guide = box(
          plank, SCNVector3(0.025, 0.01, 0.74), SCNVector3(x, 0.002, 0),
          teal, glow: 0.1)
        guide.opacity = 0.18
      }
      plank.position.z = z
      world.addChildNode(plank)
      scenery.append((plank, z))
    }
  }

  private func capsule(
    _ parent: SCNNode, radius: CGFloat, height: CGFloat, color: UIColor, position: SCNVector3
  ) -> SCNNode {
    let geometry = SCNCapsule(capRadius: radius, height: height)
    geometry.materials = [material(color)]
    let node = SCNNode(geometry: geometry)
    node.position = position
    parent.addChildNode(node)
    return node
  }

  private func createSkater() {
    scene.rootNode.addChildNode(skater)
    skater.addChildNode(rider)
    let deck = box(
      skater, SCNVector3(0.75, 0.12, 1.65), SCNVector3(0, 0.28, 0), pink, glow: 0.35, radius: 0.06)
    deck.eulerAngles.y = -0.15
    for x: Float in [-0.36, 0.36] {
      for z: Float in [-0.48, 0.48] {
        let wheel = SCNNode(geometry: SCNCylinder(radius: 0.13, height: 0.14))
        wheel.geometry?.materials = [material(teal, glow: 0.25)]
        wheel.eulerAngles.z = .pi / 2
        wheel.position = SCNVector3(x, 0.14, z)
        skater.addChildNode(wheel)
      }
    }
    let pants = UIColor(red: 0.16, green: 0.12, blue: 0.30, alpha: 1)
    for x: Float in [-0.23, 0.23] {
      let thigh = capsule(rider, radius: 0.16, height: 1, color: pants, position: SCNVector3Zero)
      let shin = capsule(rider, radius: 0.135, height: 1, color: pants, position: SCNVector3Zero)
      legs.append((thigh, shin, x))
      box(rider, SCNVector3(0.33, 0.18, 0.53), SCNVector3(x, 0.43, x - 0.08), .white, radius: 0.07)
    }
    rider.addChildNode(upperBody)
    upperBody.pivot = SCNMatrix4MakeTranslation(0, 1.25, 0)
    let fabric = UIColor(red: 0.07, green: 0.63, blue: 0.53, alpha: 1)
    let jacket = capsule(
      rider, radius: 0.39, height: 1.12, color: fabric, position: SCNVector3(0, 1.65, 0))
    jacket.scale.z = 0.76
    box(rider, SCNVector3(0.13, 0.50, 0.05), SCNVector3(0, 1.7, 0.31), pink, glow: 0.15)
    let skin = UIColor(red: 0.72, green: 0.40, blue: 0.29, alpha: 1)
    _ = capsule(
      rider, radius: 0.26, height: 0.57, color: skin, position: SCNVector3(0, 2.42, -0.04))
    let helmet = capsule(
      rider, radius: 0.31, height: 0.42, color: pink, position: SCNVector3(0, 2.62, -0.04))
    helmet.scale.z = 1.08
    box(rider, SCNVector3(0.12, 0.035, 0.61), SCNVector3(0, 2.82, -0.04), teal, glow: 0.5)
    leftArm = capsule(
      rider, radius: 0.13, height: 0.8, color: fabric, position: SCNVector3(-0.56, 1.68, 0))
    rightArm = capsule(
      rider, radius: 0.13, height: 0.8, color: fabric, position: SCNVector3(0.56, 1.68, 0))
    leftArm.eulerAngles.z = -0.60
    rightArm.eulerAngles.z = 0.60
    for x: Float in [-0.76, 0.76] {
      _ = capsule(rider, radius: 0.13, height: 0.23, color: skin, position: SCNVector3(x, 1.38, 0))
    }
    let lowerBody = Set(legs.flatMap { [$0.0, $0.1] })
    for node in rider.childNodes
    where node !== upperBody && !lowerBody.contains(node) && node.position.y > 1 {
      upperBody.addChildNode(node)
    }
    let ellipse = SCNCylinder(radius: 0.68, height: 0.008)
    ellipse.materials = [material(UIColor.black.withAlphaComponent(0.45))]
    shadow.geometry = ellipse
    shadow.position.y = 0.04
    shadow.scale.z = 1.45
    scene.rootNode.addChildNode(shadow)
    let bubble = SCNSphere(radius: 1.75)
    let bubbleMaterial = material(teal.withAlphaComponent(0.07), glow: 0.5)
    bubbleMaterial.transparency = 0.15
    bubbleMaterial.fillMode = .lines
    bubble.materials = [bubbleMaterial]
    bubble.segmentCount = 18
    shield.geometry = bubble
    shield.position.y = 1.4
    shield.isHidden = true
    skater.addChildNode(shield)
  }

  private func obstacleNode(_ obstacle: Obstacle) -> SCNNode {
    let root = SCNNode()
    switch obstacle.kind {
    case .barrier:
      box(
        root, SCNVector3(2.15, 0.85, 0.48), SCNVector3(0, 0.65, 0),
        UIColor(red: 0.35, green: 0.16, blue: 0.25, alpha: 1))
      box(
        root, SCNVector3(2.25, 0.11, 0.53), SCNVector3(0, 1.10, 0),
        UIColor(red: 1, green: 0.72, blue: 0.33, alpha: 1), glow: 0.9)
      for x: Float in [-0.7, 0, 0.7] {
        let stripe = box(
          root, SCNVector3(0.16, 0.65, 0.025), SCNVector3(x, 0.65, 0.26), .systemOrange, glow: 0.5)
        stripe.eulerAngles.z = -0.3
      }
      for x: Float in [-0.8, 0.8] {
        box(root, SCNVector3(0.18, 0.4, 0.75), SCNVector3(x, 0.18, 0), ink)
      }
    case .sign:
      for x: Float in [-1.15, 1.15] {
        box(root, SCNVector3(0.14, 3.7, 0.25), SCNVector3(x, 1.85, 0), pink, glow: 0.4)
      }
      box(
        root, SCNVector3(2.45, 1.55, 0.48), SCNVector3(0, 2.95, 0),
        UIColor(red: 0.28, green: 0.10, blue: 0.27, alpha: 1))
      box(root, SCNVector3(2.45, 0.1, 0.5), SCNVector3(0, 2.18, 0), pink, glow: 1)
      for x: Float in [-0.65, 0, 0.65] {
        let chevron = box(
          root, SCNVector3(0.25, 0.45, 0.04), SCNVector3(x, 2.8, 0.27), pink, glow: 1)
        chevron.eulerAngles.z = .pi / 4
      }
    case .cart:
      box(
        root, SCNVector3(2.1, 2.7, 1.45), SCNVector3(0, 1.5, 0),
        UIColor(red: 0.17, green: 0.20, blue: 0.34, alpha: 1), radius: 0.15)
      box(root, SCNVector3(1.85, 1.05, 0.05), SCNVector3(0, 1.95, 0.75), ink)
      for x: Float in [-0.97, 0.97] {
        box(root, SCNVector3(0.07, 2.3, 0.08), SCNVector3(x, 1.5, 0.75), teal, glow: 0.8)
      }
      box(root, SCNVector3(2.2, 0.16, 1.65), SCNVector3(0, 2.95, 0), pink, glow: 0.7)
      box(root, SCNVector3(1.3, 0.07, 0.08), SCNVector3(0, 0.8, 0.8), pink, glow: 1)
    }
    let marker = box(
      root, SCNVector3(2.2, 0.015, 2.6), SCNVector3(0, 0.03, 1.3), pink.withAlphaComponent(0.09),
      glow: 0.1)
    marker.opacity = 0.35
    return root
  }

  private func pickupNode(_ pickup: Pickup) -> SCNNode {
    let root = SCNNode()
    let geometry = SCNTorus(ringRadius: pickup.kind == .coin ? 0.30 : 0.53, pipeRadius: 0.09)
    geometry.materials = [material(pickup.kind == .coin ? .systemYellow : teal, glow: 1)]
    let ring = SCNNode(geometry: geometry)
    ring.eulerAngles.x = .pi / 2
    root.addChildNode(ring)
    if pickup.kind == .shield {
      let center = SCNNode(geometry: SCNSphere(radius: 0.26))
      center.geometry?.materials = [material(teal, glow: 0.7)]
      root.addChildNode(center)
    }
    return root
  }

  func update(_ engine: RunnerEngine, time: Double, reducedMotion: Bool) {
    let movement = engine.phase == .ready ? time * 2 : engine.distance
    for (node, origin) in scenery {
      let length: Float = node.childNodes.count < 5 ? 165 : 162
      var z = (origin + Float(movement)).truncatingRemainder(dividingBy: length)
      if z > 14 { z -= length }
      node.position.z = z
    }
    skater.position.x = Float((engine.lanePosition - 1) * 3)
    skater.position.y = Float(engine.jumpHeight)
    skater.position.z = engine.phase == .ready ? -6.5 : 0
    skater.eulerAngles.z = Float((engine.lanePosition - Double(engine.lane)) * 0.35)
    if engine.phase != .paused && engine.phase != .finished {
      if previousHeight > 0 && engine.jumpHeight == 0 { landing = 0.22 }
      landing *= 0.84
      previousHeight = engine.jumpHeight
      let tuck = Float(engine.jumpHeight / 2.3) * 0.24
      let target: Float = engine.isSliding ? 0.72 : tuck + landing
      crouch += (target - crouch) * 0.28
    }
    upperBody.position = SCNVector3(0, 1.25 - crouch, crouch * 0.18)
    upperBody.eulerAngles.x = -crouch * 0.65
    for (thigh, shin, x) in legs {
      let hip = SIMD3<Float>(x, 1.3 - crouch, crouch * 0.18)
      let knee = SIMD3<Float>(x, 0.86 - crouch * 0.22, x - 0.08 - crouch * 0.8)
      let ankle = SIMD3<Float>(x, 0.46, x - 0.08)
      poseBone(thigh, from: hip, to: knee)
      poseBone(shin, from: knee, to: ankle)
    }
    if !reducedMotion && engine.phase != .paused && engine.phase != .finished {
      rider.position.y = Float(sin(time * 6) * 0.025)
      leftArm.eulerAngles.x = Float(sin(time * 3) * 0.15)
      rightArm.eulerAngles.x = -Float(sin(time * 3) * 0.15)
    }
    shadow.position.x = skater.position.x
    shadow.position.z = skater.position.z
    shadow.opacity = CGFloat(0.65 - engine.jumpHeight * 0.15)
    shield.isHidden = !engine.isShielded
    shield.eulerAngles.y = Float(time * 0.4)
    wheel.eulerAngles.z = Float(time * 0.12)
    skater.opacity = engine.graceTime > 0 && Int(time * 12) % 2 == 0 ? 0.45 : 1
    for item in engine.obstacles {
      let node: SCNNode
      if let existing = obstacles[item.id] {
        node = existing
      } else {
        node = obstacleNode(item)
        obstacles[item.id] = node
        scene.rootNode.addChildNode(node)
      }
      node.position = SCNVector3(Float(item.lane - 1) * 3, 0, -Float(item.distance))
    }
    for id in Array(obstacles.keys) where !engine.obstacles.contains(where: { $0.id == id }) {
      obstacles.removeValue(forKey: id)?.removeFromParentNode()
    }
    for item in engine.pickups {
      let node: SCNNode
      if let existing = pickups[item.id] {
        node = existing
      } else {
        node = pickupNode(item)
        pickups[item.id] = node
        scene.rootNode.addChildNode(node)
      }
      node.position = SCNVector3(Float(item.lane - 1) * 3, 1.1, -Float(item.distance))
      node.eulerAngles.y = Float(time * 2)
    }
    for id in Array(pickups.keys) where !engine.pickups.contains(where: { $0.id == id }) {
      pickups.removeValue(forKey: id)?.removeFromParentNode()
    }
  }

  private func poseBone(_ node: SCNNode, from start: SIMD3<Float>, to end: SIMD3<Float>) {
    let direction = end - start
    node.simdPosition = (start + end) / 2
    node.simdScale = SIMD3<Float>(1, simd_length(direction), 1)
    node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(direction))
  }
}
