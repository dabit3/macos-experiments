import SceneKit
import UIKit
import simd

final class BoardwalkScene {
  let scene = SCNScene()
  let camera = SCNNode()
  private let skater = SCNNode()
  private let rider = SCNNode()
  private let upperBody = SCNNode()
  private let board = SCNNode()
  private let head = SCNNode()
  private var legs: [Limb] = []
  private var arms: [Limb] = []
  private var wheelSpinners: [SCNNode] = []
  private var lean: Float = 0
  private var trick = 0
  private var airborne = false
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

  private struct Limb {
    let upper: SCNNode
    let lower: SCNNode
    let joint: SCNNode
    let end: SCNNode
    let side: Float
  }

  private static let rimLight = """
    float rim = 1.0 - abs(dot(normalize(_surface.normal), normalize(_surface.view)));
    float side = saturate(_surface.normal.x * 0.5 + 0.5);
    float3 tint = mix(float3(0.25, 1.0, 0.88), float3(1.0, 0.28, 0.66), side);
    _output.color.rgb += tint * pow(rim, 3.5) * 0.28;
    """

  private func outfit(_ color: UIColor, glow: CGFloat = 0, shiny: Bool = false) -> SCNMaterial {
    let result = material(color, glow: glow, shiny: shiny)
    result.roughness.contents = shiny ? 0.35 : 0.6
    result.metalness.contents = shiny ? 0.3 : 0
    result.shaderModifiers = [.fragment: Self.rimLight]
    return result
  }

  @discardableResult
  private func part(
    _ parent: SCNNode, _ geometry: SCNGeometry, _ look: SCNMaterial,
    _ position: SCNVector3 = SCNVector3Zero
  ) -> SCNNode {
    geometry.materials = [look]
    let node = SCNNode(geometry: geometry)
    node.position = position
    parent.addChildNode(node)
    return node
  }

  private func rounded(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ r: CGFloat) -> SCNBox {
    SCNBox(width: w, height: h, length: l, chamferRadius: r)
  }

  private func createBoard() {
    board.position.y = 0.28
    let deck = outfit(pink, glow: 0.05, shiny: true)
    let grip = outfit(UIColor(red: 0.07, green: 0.06, blue: 0.14, alpha: 1))
    let metal = outfit(UIColor(white: 0.7, alpha: 1), shiny: true)
    part(board, rounded(0.74, 0.08, 1.26, 0.04), deck)
    part(board, rounded(0.68, 0.014, 1.2, 0.006), grip, SCNVector3(0, 0.044, 0))
    for end: Float in [-1, 1] {
      let kick = part(
        board, rounded(0.74, 0.08, 0.36, 0.04), deck, SCNVector3(0, 0.055, end * 0.78))
      kick.eulerAngles.x = -end * 0.38
      part(kick, rounded(0.68, 0.014, 0.32, 0.006), grip, SCNVector3(0, 0.044, 0))
    }
    part(
      board, rounded(0.34, 0.012, 1.34, 0.006), outfit(teal, glow: 0.45), SCNVector3(0, -0.047, 0))
    let hub = outfit(UIColor(white: 0.75, alpha: 1))
    let tyre = outfit(teal, glow: 0.35)
    for z: Float in [-0.46, 0.46] {
      part(board, rounded(0.22, 0.05, 0.22, 0.02), metal, SCNVector3(0, -0.06, z))
      part(board, rounded(0.6, 0.06, 0.1, 0.03), metal, SCNVector3(0, -0.1, z))
      for x: Float in [-0.35, 0.35] {
        let spinner = SCNNode()
        spinner.position = SCNVector3(x, -0.14, z)
        board.addChildNode(spinner)
        part(spinner, SCNCylinder(radius: 0.12, height: 0.13), tyre).eulerAngles.z = .pi / 2
        part(spinner, SCNCylinder(radius: 0.05, height: 0.14), hub).eulerAngles.z = .pi / 2
        part(spinner, rounded(0.14, 0.2, 0.03, 0.01), hub)
        wheelSpinners.append(spinner)
      }
    }
    let glow = SCNNode()
    glow.light = SCNLight()
    glow.light?.type = .omni
    glow.light?.color = pink
    glow.light?.intensity = 30
    glow.light?.attenuationStartDistance = 0
    glow.light?.attenuationEndDistance = 2.6
    glow.position = SCNVector3(0, -0.2, 0)
    board.addChildNode(glow)
  }

  private func createSkater() {
    scene.rootNode.addChildNode(skater)
    skater.scale = SCNVector3(1.08, 1.08, 1.08)
    skater.addChildNode(board)
    skater.addChildNode(rider)
    createBoard()
    let jacket = outfit(UIColor(red: 0.09, green: 0.70, blue: 0.60, alpha: 1))
    let trim = outfit(pink, glow: 0.22)
    let cap = outfit(UIColor(red: 0.92, green: 0.2, blue: 0.55, alpha: 1))
    let denim = outfit(UIColor(red: 0.17, green: 0.13, blue: 0.34, alpha: 1))
    let dark = outfit(UIColor(red: 0.06, green: 0.07, blue: 0.16, alpha: 1), shiny: true)
    let skin = outfit(UIColor(red: 0.78, green: 0.47, blue: 0.34, alpha: 1))
    let hair = outfit(UIColor(red: 0.22, green: 0.10, blue: 0.30, alpha: 1))
    let white = outfit(UIColor(white: 0.8, alpha: 1))
    let sole = outfit(pink, glow: 0.4)
    let neonTeal = outfit(teal, glow: 1)
    let neonPink = outfit(pink, glow: 1)

    for side: Float in [-1, 1] {
      let thigh = part(rider, SCNCapsule(capRadius: 0.17, height: 1), denim)
      let shin = part(rider, SCNCapsule(capRadius: 0.14, height: 1), denim)
      let pad = part(rider, SCNSphere(radius: 0.16), dark)
      pad.scale = SCNVector3(1, 1.1, 0.9)
      let shoe = SCNNode()
      shoe.eulerAngles.y = -side * 0.1
      rider.addChildNode(shoe)
      part(shoe, rounded(0.3, 0.08, 0.56, 0.035), white, SCNVector3(0, -0.07, -0.05))
      part(shoe, rounded(0.31, 0.02, 0.57, 0.01), sole, SCNVector3(0, -0.1, -0.05))
      part(shoe, rounded(0.27, 0.2, 0.46, 0.09), white, SCNVector3(0, 0.05, -0.04))
      part(shoe, rounded(0.285, 0.045, 0.3, 0.02), neonTeal, SCNVector3(0, 0.04, 0.02))
      part(shoe, SCNCylinder(radius: 0.14, height: 0.2), dark, SCNVector3(0, 0.15, 0.06))
      legs.append(Limb(upper: thigh, lower: shin, joint: pad, end: shoe, side: side))
    }

    rider.addChildNode(upperBody)
    upperBody.pivot = SCNMatrix4MakeTranslation(0, 1.25, 0)
    part(upperBody, SCNCapsule(capRadius: 0.3, height: 0.8), denim, SCNVector3(0, 1.32, 0))
      .eulerAngles.z = .pi / 2
    let torso = part(
      upperBody, SCNCapsule(capRadius: 0.42, height: 1.1), jacket, SCNVector3(0, 1.72, 0))
    torso.scale.z = 0.74
    part(upperBody, SCNTorus(ringRadius: 0.38, pipeRadius: 0.045), trim, SCNVector3(0, 1.3, 0))
      .scale.z = 0.76
    part(upperBody, SCNTorus(ringRadius: 0.2, pipeRadius: 0.08), trim, SCNVector3(0, 2.17, 0))
    for side: Float in [-1, 1] {
      part(upperBody, SCNSphere(radius: 0.2), jacket, SCNVector3(side * 0.44, 2.0, 0))
      part(upperBody, rounded(0.1, 0.1, 0.52, 0.04), dark, SCNVector3(side * 0.21, 2.12, 0.08))
    }
    part(upperBody, rounded(0.6, 0.7, 0.28, 0.12), dark, SCNVector3(0, 1.74, 0.36))
    part(upperBody, rounded(0.44, 0.26, 0.08, 0.05), jacket, SCNVector3(0, 1.56, 0.51))
    part(upperBody, rounded(0.46, 0.05, 0.02, 0.01), neonTeal, SCNVector3(0, 1.94, 0.505))
    for side: Float in [-1, 1] {
      part(upperBody, rounded(0.04, 0.5, 0.02, 0.01), neonPink, SCNVector3(side * 0.27, 1.75, 0.5))
    }

    let hood = part(
      upperBody, SCNSphere(radius: 0.28),
      outfit(UIColor(red: 0.06, green: 0.52, blue: 0.46, alpha: 1)), SCNVector3(0, 2.1, 0.22))
    hood.scale = SCNVector3(1.05, 0.55, 0.7)
    for side: Float in [-1, 1] {
      part(head, SCNSphere(radius: 0.1), hair, SCNVector3(side * 0.2, -0.06, 0.2))
    }
    part(upperBody, SCNCapsule(capRadius: 0.12, height: 0.34), skin, SCNVector3(0, 2.26, 0))
    head.position = SCNVector3(0, 2.56, -0.02)
    upperBody.addChildNode(head)
    part(head, SCNSphere(radius: 0.3), skin)
    part(head, SCNSphere(radius: 0.305), hair, SCNVector3(0, 0.03, 0.05)).scale = SCNVector3(
      1, 0.95, 1)
    part(head, SCNSphere(radius: 0.325), cap, SCNVector3(0, 0.16, 0.01)).scale = SCNVector3(
      1, 0.62, 1.02)
    let brim = part(head, rounded(0.36, 0.03, 0.3, 0.015), cap, SCNVector3(0, 0.1, 0.36))
    brim.eulerAngles.x = -0.22
    part(brim, rounded(0.33, 0.01, 0.27, 0.005), neonTeal, SCNVector3(0, -0.02, 0))
    part(head, SCNSphere(radius: 0.045), white, SCNVector3(0, 0.36, 0.01))
    for side: Float in [-1, 1] {
      part(head, SCNCylinder(radius: 0.13, height: 0.1), dark, SCNVector3(side * 0.31, -0.02, 0.02))
        .eulerAngles.z = .pi / 2
      part(
        head, SCNTorus(ringRadius: 0.1, pipeRadius: 0.026), neonTeal,
        SCNVector3(side * 0.36, -0.02, 0.02)
      )
      .eulerAngles.z = .pi / 2
      part(head, rounded(0.04, 0.3, 0.06, 0.02), dark, SCNVector3(side * 0.3, 0.17, 0.02))
        .eulerAngles.z = side * 0.5
    }

    for side: Float in [-1, 1] {
      let upper = part(upperBody, SCNCapsule(capRadius: 0.135, height: 1), jacket)
      let fore = part(upperBody, SCNCapsule(capRadius: 0.12, height: 1), jacket)
      let elbow = part(upperBody, SCNSphere(radius: 0.13), jacket)
      let glove = part(upperBody, SCNSphere(radius: 0.13), dark)
      glove.scale = SCNVector3(0.95, 1.1, 0.9)
      part(glove, SCNSphere(radius: 0.05), neonTeal, SCNVector3(side * 0.02, 0, -0.11))
      part(fore, SCNCylinder(radius: 0.13, height: 0.05), trim, SCNVector3(0, -0.4, 0))
      arms.append(Limb(upper: upper, lower: fore, joint: elbow, end: glove, side: side))
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

  private func solveJoint(
    from start: SIMD3<Float>, to end: SIMD3<Float>, lengths: (Float, Float), bend: SIMD3<Float>
  ) -> SIMD3<Float> {
    let span = end - start
    let distance = min(max(simd_length(span), 0.001), lengths.0 + lengths.1 - 0.001)
    let direction = simd_normalize(span)
    let along =
      (lengths.0 * lengths.0 - lengths.1 * lengths.1 + distance * distance) / (2 * distance)
    let height = sqrt(max(0, lengths.0 * lengths.0 - along * along))
    let perpendicular = simd_normalize(bend - direction * simd_dot(bend, direction))
    return start + direction * along + perpendicular * height
  }

  private func poseRider(_ engine: RunnerEngine, time: Double, reducedMotion: Bool) {
    let active = engine.phase != .paused && engine.phase != .finished
    let motion: Float = reducedMotion || !active ? 0 : 1
    let t = Float(time)
    lean += (Float(engine.lanePosition - Double(engine.lane)) - lean) * 0.3
    skater.eulerAngles.z = lean * 0.35
    if engine.jumpTime > 0, !airborne { trick += 1 }
    airborne = engine.jumpTime > 0
    let progress = airborne ? Float(1 - engine.jumpTime / RunnerEngine.jumpDuration) : 0
    let eased = progress * progress * (3 - 2 * progress)
    let spin = reducedMotion ? 0 : eased * 2 * .pi
    board.eulerAngles =
      trick % 2 == 1 ? SCNVector3(0, 0, spin - lean * 0.2) : SCNVector3(0, spin, -lean * 0.2)
    let lift: Float = reducedMotion ? 0 : sin(.pi * progress) * 0.5
    let air = Float(engine.jumpHeight / 2.3)
    let slide = min(1, max(0, (crouch - 0.3) / 0.42)) * (engine.isSliding ? 1 : 0)

    upperBody.position = SCNVector3(0, 1.25 - crouch, crouch * 0.18)
    upperBody.eulerAngles = SCNVector3(-crouch * 0.65, lean * 0.15, -lean * 0.2)
    head.eulerAngles = SCNVector3(crouch * 0.55, -lean * 0.2, 0)

    for leg in legs {
      let x = leg.side * 0.24
      let hip = SIMD3<Float>(x, 1.3 - crouch, crouch * 0.18)
      let ankle = SIMD3<Float>(x, 0.58 + lift, 0.02)
      let knee = solveJoint(
        from: hip, to: ankle, lengths: (0.5, 0.48), bend: SIMD3<Float>(leg.side * 0.25, 0, -1))
      poseBone(leg.upper, from: hip, to: knee)
      poseBone(leg.lower, from: knee, to: ankle)
      leg.joint.simdPosition = knee + SIMD3<Float>(0, 0, -0.06)
      leg.end.position = SCNVector3(x, 0.44 + lift, -0.02)
    }

    for arm in arms {
      let side = arm.side
      let shoulder = SIMD3<Float>(side * 0.5, 1.98, 0)
      let sway = sin(t * 3 + side) * 0.07 * motion
      var hand = SIMD3<Float>(side * 0.86, 1.3 + sway, -0.24 + sin(t * 3) * 0.08 * side * motion)
      hand.y += max(0, lean * side) * 0.55
      hand = simd_mix(hand, SIMD3<Float>(side * 1.08, 2.4, -0.15), SIMD3<Float>(repeating: air))
      hand = simd_mix(hand, SIMD3<Float>(side * 0.62, 1.25, 0.62), SIMD3<Float>(repeating: slide))
      let elbow = solveJoint(
        from: shoulder, to: hand, lengths: (0.44, 0.42), bend: SIMD3<Float>(side * 0.5, -0.3, 0.8))
      poseBone(arm.upper, from: shoulder, to: elbow)
      poseBone(arm.lower, from: elbow, to: hand)
      arm.joint.simdPosition = elbow
      arm.end.simdPosition = hand
    }

    let rolled = engine.phase == .ready ? time * 2 : engine.distance
    let angle = Float((rolled / 0.12).truncatingRemainder(dividingBy: 2 * .pi))
    for spinner in wheelSpinners { spinner.eulerAngles.x = -angle }
    rider.position.y = Float(sin(time * 6) * 0.025) * motion
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
    if engine.phase != .paused && engine.phase != .finished {
      if previousHeight > 0 && engine.jumpHeight == 0 { landing = 0.22 }
      landing *= 0.84
      previousHeight = engine.jumpHeight
      let tuck = Float(engine.jumpHeight / 2.3) * 0.24
      let target: Float = engine.isSliding ? 0.72 : tuck + landing
      crouch += (target - crouch) * 0.28
    }
    poseRider(engine, time: time, reducedMotion: reducedMotion)
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
