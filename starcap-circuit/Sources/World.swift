import Metal
import SceneKit
import UIKit

@MainActor
final class RaceWorld {
  let scene = SCNScene()
  let cameraNode = SCNNode()
  private let courseRoot = SCNNode()
  private let racersRoot = SCNNode()
  private let hazardsRoot = SCNNode()
  private var kartNodes: [String: SCNNode] = [:]
  private var itemNodes: [SCNNode] = []
  private var previewKart = SCNNode()
  private var previewRacer = 0
  private var lastHazards = -1
  private var lastRace = -1
  private var cameraReady = false
  private var sunNode = SCNNode()
  private var rimNode = SCNNode()
  private var ambientNode = SCNNode()
  private let ambientFX = SCNNode()
  private var waterMaterial = SCNMaterial()
  private(set) var track = -1
  private let colors: [UIColor] = [
    UIColor(red: 1, green: 0.24, blue: 0.34, alpha: 1),
    UIColor(red: 0.14, green: 0.92, blue: 0.72, alpha: 1),
    UIColor(red: 1, green: 0.73, blue: 0.1, alpha: 1),
  ]
  private let ink = UIColor(red: 0.07, green: 0.08, blue: 0.19, alpha: 1)

  init() {
    scene.rootNode.addChildNode(courseRoot)
    scene.rootNode.addChildNode(racersRoot)
    scene.rootNode.addChildNode(hazardsRoot)
    cameraNode.camera = SCNCamera()
    cameraNode.camera?.fieldOfView = 68
    cameraNode.camera?.zFar = 750
    if let camera = cameraNode.camera {
      camera.zNear = 0.3
      camera.wantsHDR = true
      camera.wantsExposureAdaptation = false
      camera.exposureOffset = 0
      camera.bloomIntensity = 0.9
      camera.bloomThreshold = 0.85
      camera.bloomBlurRadius = 10
      camera.bloomIterationCount = 2
      camera.vignettingIntensity = 0.45
      camera.vignettingPower = 1.2
      camera.saturation = 1.12
      camera.contrast = 0.08
      camera.screenSpaceAmbientOcclusionIntensity = 0.9
      camera.screenSpaceAmbientOcclusionRadius = 1.6
      camera.screenSpaceAmbientOcclusionBias = 0.05
      camera.screenSpaceAmbientOcclusionNormalThreshold = 0.3
      camera.screenSpaceAmbientOcclusionDepthThreshold = 0.2
    }
    scene.rootNode.addChildNode(cameraNode)
    let sun = SCNNode()
    sun.light = SCNLight()
    sun.light?.type = .directional
    sun.light?.castsShadow = true
    sun.light?.shadowMode = .deferred
    sun.light?.shadowColor = UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 0.45)
    sun.light?.shadowRadius = 2.5
    sun.light?.shadowSampleCount = 8
    sun.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
    sun.light?.shadowCascadeCount = 3
    sun.light?.maximumShadowDistance = 140
    sun.light?.automaticallyAdjustsShadowProjection = true
    sun.eulerAngles = SCNVector3(-Float.pi / 3.2, -Float.pi / 4, 0)
    scene.rootNode.addChildNode(sun)
    sunNode = sun
    let rim = SCNNode()
    rim.light = SCNLight()
    rim.light?.type = .directional
    rim.eulerAngles = SCNVector3(-Float.pi / 6, Float.pi * 0.8, 0)
    scene.rootNode.addChildNode(rim)
    rimNode = rim
    let ambient = SCNNode()
    ambient.light = SCNLight()
    ambient.light?.type = .ambient
    scene.rootNode.addChildNode(ambient)
    ambientNode = ambient
    ambientFX.position = SCNVector3(0, 4, 18)
    cameraNode.addChildNode(ambientFX)
  }

  private func material(
    _ color: UIColor, glow: Bool = false, roughness: CGFloat = 0.55, metal: CGFloat = 0
  ) -> SCNMaterial {
    let result = SCNMaterial()
    result.lightingModel = .physicallyBased
    result.diffuse.contents = color
    result.roughness.contents = roughness
    result.metalness.contents = metal
    if glow {
      result.emission.contents = color
      result.emission.intensity = 1.6
    }
    return result
  }

  private func paint(_ color: UIColor) -> SCNMaterial {
    let result = material(color, roughness: 0.32, metal: 0.15)
    result.clearCoat.contents = 1
    result.clearCoatRoughness.contents = 0.05
    return result
  }

  private func chrome() -> SCNMaterial {
    material(UIColor(white: 0.92, alpha: 1), roughness: 0.18, metal: 1)
  }

  private func rubber() -> SCNMaterial {
    material(UIColor(red: 0.09, green: 0.09, blue: 0.13, alpha: 1), roughness: 0.85)
  }

  @discardableResult
  private func shape(
    _ geometry: SCNGeometry, _ color: UIColor, _ position: SCNVector3, parent: SCNNode,
    glow: Bool = false
  ) -> SCNNode {
    geometry.materials = [material(color, glow: glow)]
    smooth(geometry)
    let node = SCNNode(geometry: geometry)
    node.position = position
    parent.addChildNode(node)
    return node
  }

  private func smooth(_ geometry: SCNGeometry) {
    if let g = geometry as? SCNSphere { g.segmentCount = max(g.segmentCount, 40) }
    if let g = geometry as? SCNCylinder { g.radialSegmentCount = 36 }
    if let g = geometry as? SCNCone { g.radialSegmentCount = 36 }
    if let g = geometry as? SCNCapsule {
      g.radialSegmentCount = 36
      g.capSegmentCount = 24
    }
    if let g = geometry as? SCNTorus {
      g.ringSegmentCount = 48
      g.pipeSegmentCount = 20
    }
    if let g = geometry as? SCNBox { g.chamferSegmentCount = 6 }
  }

  @discardableResult
  private func part(
    _ geometry: SCNGeometry, _ mat: SCNMaterial, _ position: SCNVector3, parent: SCNNode
  ) -> SCNNode {
    geometry.materials = [mat]
    smooth(geometry)
    let node = SCNNode(geometry: geometry)
    node.position = position
    parent.addChildNode(node)
    return node
  }

  @discardableResult
  private func ball(_ radius: CGFloat, _ color: UIColor, _ position: SCNVector3, parent: SCNNode)
    -> SCNNode
  {
    let sphere = SCNSphere(radius: radius)
    return shape(sphere, color, position, parent: parent)
  }

  @discardableResult
  private func box(
    _ w: CGFloat, _ h: CGFloat, _ d: CGFloat, _ color: UIColor, _ position: SCNVector3,
    parent: SCNNode, bevel: CGFloat = 0.15
  ) -> SCNNode {
    shape(
      SCNBox(width: w, height: h, length: d, chamferRadius: bevel), color, position, parent: parent)
  }

  @discardableResult
  private func text(
    _ string: String, size: CGFloat, color: UIColor, parent: SCNNode, position: SCNVector3
  ) -> SCNNode {
    let geo = SCNText(string: string, extrusionDepth: 0.05)
    geo.font = UIFont.systemFont(ofSize: size, weight: .black)
    geo.flatness = 0.4
    let node = shape(geo, color, position, parent: parent)
    let (minimum, maximum) = node.boundingBox
    node.pivot = SCNMatrix4MakeTranslation((minimum.x + maximum.x) / 2, minimum.y, 0)
    return node
  }

  func build(track: Int) {
    self.track = track
    for node in courseRoot.childNodes { node.removeFromParentNode() }
    for node in racersRoot.childNodes { node.removeFromParentNode() }
    for node in hazardsRoot.childNodes { node.removeFromParentNode() }
    kartNodes = [:]
    itemNodes = []
    lastHazards = -1
    cameraReady = false
    let night = track == 1
    let skyImage = Art.cached("sky\(night)") { Art.sky(night: night) }
    scene.background.contents = skyImage
    scene.lightingEnvironment.contents = skyImage
    scene.lightingEnvironment.intensity = night ? 0.8 : 1.3
    sunNode.light?.intensity = night ? 420 : 1650
    sunNode.light?.color =
      night
      ? UIColor(red: 0.72, green: 0.62, blue: 1, alpha: 1)
      : UIColor(red: 1, green: 0.95, blue: 0.84, alpha: 1)
    rimNode.light?.intensity = night ? 650 : 380
    rimNode.light?.color =
      night
      ? UIColor(red: 1, green: 0.3, blue: 0.75, alpha: 1)
      : UIColor(red: 0.55, green: 0.8, blue: 1, alpha: 1)
    ambientNode.light?.intensity = night ? 220 : 180
    ambientNode.light?.color =
      night
      ? UIColor(red: 0.45, green: 0.32, blue: 0.95, alpha: 1)
      : UIColor(red: 0.75, green: 0.86, blue: 1, alpha: 1)
    cameraNode.camera?.bloomThreshold = night ? 0.55 : 0.92
    cameraNode.camera?.bloomIntensity = night ? 1.3 : 0.7
    ambientFX.removeAllParticleSystems()
    ambientFX.addParticleSystem(Art.ambient(night: night))
    scene.fogColor =
      night
      ? UIColor(red: 0.42, green: 0.14, blue: 0.5, alpha: 1)
      : UIColor(red: 0.78, green: 0.9, blue: 1, alpha: 1)
    scene.fogStartDistance = 150
    scene.fogEndDistance = 520
    scene.fogDensityExponent = 1.3
    let floor = SCNFloor()
    floor.reflectivity = night ? 0.4 : 0.25
    floor.reflectionFalloffEnd = 40
    floor.reflectionResolutionScaleFactor = 0.5
    waterMaterial = material(
      night
        ? UIColor(red: 0.07, green: 0.08, blue: 0.3, alpha: 1)
        : UIColor(red: 0.0, green: 0.5, blue: 0.75, alpha: 1), roughness: 0.06)
    waterMaterial.normal.contents = Art.cached("waves") { Art.waves() }
    waterMaterial.normal.intensity = 0.55
    waterMaterial.normal.wrapS = .repeat
    waterMaterial.normal.wrapT = .repeat
    floor.materials = [waterMaterial]
    let waterNode = SCNNode(geometry: floor)
    waterNode.position.y = -1.6
    courseRoot.addChildNode(waterNode)
    ribbon(
      inner: -9.3, outer: 9.3, height: 0.02,
      mat: surface(
        Art.cached("road\(night)") { Art.asphalt(night: night) },
        normal: Art.cached("b32") { Art.bumps(32, strength: 3, seed: 4) },
        roughness: night ? 0.3 : 0.7))
    let ground = surface(
      Art.cached("grass\(night)") { Art.grass(night: night) },
      normal: Art.cached("b16") { Art.bumps(16, strength: 5, seed: 8) }, roughness: 0.85)
    let shore =
      night
      ? material(UIColor(red: 0.3, green: 0.9, blue: 1, alpha: 1), glow: true, roughness: 0.2)
      : surface(
        Art.cached("sand") { Art.sand() },
        normal: Art.cached("b24") { Art.bumps(24, strength: 2, seed: 12) }, roughness: 0.9)
    let kerb = surface(
      Art.stripes(
        night
          ? [UIColor(red: 1, green: 0.3, blue: 0.7, alpha: 1), .white]
          : [UIColor(red: 0.95, green: 0.12, blue: 0.2, alpha: 1), .white], count: 1,
        gloss: false), roughness: 0.4)
    for side in [-1.0, 1.0] {
      ribbon(inner: side * 9.3, outer: side * 10.6, height: 0.05, mat: kerb, along: 1.5)
      ribbon(inner: side * 10.6, outer: side * 18, height: 0.0, mat: ground, across: 2)
      ribbon(
        inner: side * 18, outer: side * 26, height: 0, drop: -0.35, mat: ground, across: 2)
      ribbon(
        inner: side * 26, outer: side * 31, height: -0.35, drop: -1.6, mat: shore, across: 1)
      let rail = surface(
        Art.stripes(
          night
            ? [
              UIColor(red: 1, green: 0.35, blue: 0.8, alpha: 1),
              UIColor(red: 0.3, green: 0.9, blue: 1, alpha: 1),
            ]
            : [
              UIColor(red: 0.12, green: 0.45, blue: 1, alpha: 1),
              UIColor(red: 1, green: 0.84, blue: 0.1, alpha: 1),
            ]),
        roughness: 0.3)
      rail.clearCoat.contents = 1
      if night {
        rail.emission.contents = rail.diffuse.contents
        rail.emission.intensity = 0.5
      }
      tube(offset: side * 12.3, radius: 0.55, y: 0.6, mat: rail)
      tube(offset: side * 12.3, radius: 0.3, y: 1.55, mat: rail)
    }
    let scenery = SCNNode()
    for i in stride(from: 0, to: 240, by: 6) {
      let p = Course.point(track, Double(i))
      let h = Course.heading(track, Double(i))
      let dash = box(
        0.28, 0.02, 2.6, UIColor.white.withAlphaComponent(night ? 0.9 : 0.75),
        SCNVector3(p.x, 0.04, p.z), parent: scenery, bevel: 0)
      dash.eulerAngles.y = Float(h)
      if night { dash.geometry?.firstMaterial?.emission.contents = UIColor.white }
      for side in [-1.0, 1.0] where i % 12 == 0 {
        let post = shape(
          SCNCylinder(radius: 0.14, height: 1.7), UIColor(white: 0.9, alpha: 1),
          SCNVector3(p.x + cos(h) * side * 12.3, 0.85, p.z - sin(h) * side * 12.3), parent: scenery)
        post.geometry?.firstMaterial = chrome()
      }
    }
    for i in stride(from: 0, to: 240, by: 4) {
      let p = Course.point(track, Double(i))
      let h = Course.heading(track, Double(i))
      for side in [-1.0, 1.0] {
        let seed = i * 7 + (side > 0 ? 3 : 0)
        let distance = 15 + Art.hash(seed, 1) * 3
        let root = SCNNode()
        root.position = SCNVector3(
          p.x + cos(h) * side * distance, 0, p.z - sin(h) * side * distance)
        scenery.addChildNode(root)
        flowers(parent: root, night: night, seed: seed)
        guard i % 8 == 0 else { continue }
        let far = SCNNode()
        let reach = 21 + Art.hash(seed, 2) * 4
        far.position = SCNVector3(p.x + cos(h) * side * reach, -0.2, p.z - sin(h) * side * reach)
        far.eulerAngles.y = Float(Art.hash(seed, 3) * 6.28)
        let s = Float(0.85 + Art.hash(seed, 4) * 0.4)
        far.scale = SCNVector3(s, s, s)
        scenery.addChildNode(far)
        if i % 24 == 0 {
          tower(parent: far, night: night, index: i)
        } else if night {
          i % 16 == 0 ? lamp(parent: far) : lollipop(parent: far, seed: seed)
        } else {
          Art.hash(seed, 5) > 0.5 ? palm(parent: far, seed: seed) : tree(parent: far, seed: seed)
        }
      }
    }
    for i in 0..<22 {
      let t = Double(i) * .pi * 2 / 22
      let r = 330 + Art.hash(i, 30) * 70
      let root = SCNNode()
      root.position = SCNVector3(sin(t) * r, -3, cos(t) * r)
      courseRoot.addChildNode(root)
      if night {
        skyline(parent: root, seed: i)
      } else {
        hill(parent: root, seed: i)
      }
    }
    grandstand(night: night, parent: scenery)
    courseRoot.addChildNode(scenery.flattenedClone())
    if !night {
      for i in 0..<5 {
        let root = SCNNode()
        let t = Double(i) * 1.3
        root.position = SCNVector3(sin(t) * 120, 38 + Double(i % 3) * 9, cos(t) * 120)
        balloon(parent: root, color: colors[i % 3])
        root.runAction(
          .repeatForever(
            .sequence([
              .moveBy(x: 0, y: 3, z: 0, duration: 4 + Double(i)),
              .moveBy(x: 0, y: -3, z: 0, duration: 4 + Double(i)),
            ])))
        courseRoot.addChildNode(root)
      }
    }
    for i in [0, 60, 120, 180] { arch(index: i, start: i == 0, night: night) }
    for index in [24, 84, 144, 204] {
      let p = Course.point(track, Double(index))
      let h = Course.heading(track, Double(index))
      for lane in [-5.0, 0, 5] {
        let root = SCNNode()
        root.position = SCNVector3(p.x + cos(h) * lane, 1.7, p.z - sin(h) * lane)
        let cube = box(
          1.8, 1.8, 1.8, UIColor(red: 0.34, green: 0.85, blue: 1, alpha: 0.82), SCNVector3Zero,
          parent: root, bevel: 0.25)
        if let glass = cube.geometry?.firstMaterial {
          glass.roughness.contents = 0.05
          glass.clearCoat.contents = 1
          glass.transparency = 0.8
          glass.emission.intensity = 0.6
          glass.blendMode = .alpha
        }
        let core = ball(0.55, .white, SCNVector3Zero, parent: root)
        core.geometry?.firstMaterial?.emission.contents = UIColor.white
        core.geometry?.firstMaterial?.emission.intensity = 0.7
        text("?", size: 1.6, color: .white, parent: root, position: SCNVector3(0, -0.8, 0.95))
        text("?", size: 1.6, color: .white, parent: root, position: SCNVector3(0, -0.8, -0.95))
          .eulerAngles.y = .pi
        root.runAction(.repeatForever(.rotateBy(x: 0.4, y: 2.4, z: 0.3, duration: 2)))
        courseRoot.addChildNode(root)
        itemNodes.append(root)
      }
    }
    for index in [12, 72, 132, 192] { dashPanel(index: index, night: night) }
    preview(racer: previewRacer)
  }

  func preview(racer: Int) {
    previewRacer = racer
    previewKart.removeFromParentNode()
    previewKart = makeKart(racer: racer)
    let p = Course.point(track, 0)
    previewKart.position = SCNVector3(p.x, 0.15, p.z)
    let podium = part(
      SCNCylinder(radius: 3.9, height: 0.35),
      paint(UIColor(red: 0.12, green: 0.14, blue: 0.3, alpha: 1)),
      SCNVector3(0, -0.2, 0), parent: previewKart)
    podium.castsShadow = false
    let halo = part(
      SCNTorus(ringRadius: 3.9, pipeRadius: 0.1),
      material(colors[min(2, max(0, racer))], glow: true), SCNVector3(0, -0.02, 0),
      parent: previewKart)
    halo.geometry?.firstMaterial?.emission.intensity = 3
    racersRoot.addChildNode(previewKart)
    previewKart.scale = SCNVector3(0.6, 0.6, 0.6)
    previewKart.runAction(
      .sequence([
        .scale(to: 1.12, duration: 0.14), .scale(to: 1, duration: 0.12),
      ]))
  }

  private func dashPanel(index: Int, night: Bool) {
    let p = Course.point(track, Double(index))
    let root = SCNNode()
    root.position = SCNVector3(p.x, 0.07, p.z)
    root.eulerAngles.y = Float(Course.heading(track, Double(index)))
    courseRoot.addChildNode(root)
    let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { context in
      UIColor(red: 1, green: 0.45, blue: 0.05, alpha: 1).setFill()
      context.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
      UIColor(red: 1, green: 0.92, blue: 0.3, alpha: 1).setFill()
      for row in 0..<3 {
        let y = CGFloat(row) * 42 + 8
        let chevron = UIBezierPath()
        chevron.move(to: CGPoint(x: 14, y: y))
        chevron.addLine(to: CGPoint(x: 64, y: y + 26))
        chevron.addLine(to: CGPoint(x: 114, y: y))
        chevron.addLine(to: CGPoint(x: 114, y: y + 12))
        chevron.addLine(to: CGPoint(x: 64, y: y + 38))
        chevron.addLine(to: CGPoint(x: 14, y: y + 12))
        chevron.close()
        chevron.fill()
      }
    }
    let plane = SCNPlane(width: 6.2, height: 5)
    let mat = SCNMaterial()
    mat.diffuse.contents = image
    mat.emission.contents = image
    mat.emission.intensity = night ? 0.9 : 0.45
    mat.isDoubleSided = true
    plane.materials = [mat]
    let node = SCNNode(geometry: plane)
    node.eulerAngles.x = -.pi / 2
    root.addChildNode(node)
    node.runAction(
      .repeatForever(
        .sequence([.fadeOpacity(to: 0.7, duration: 0.35), .fadeOpacity(to: 1, duration: 0.35)])))
  }

  private func nameTag(_ name: String, color: UIColor) -> SCNNode {
    let font = UIFont.systemFont(ofSize: 34, weight: .black)
    let textSize = (name as NSString).size(withAttributes: [.font: font])
    let size = CGSize(width: textSize.width + 44, height: 58)
    let image = UIGraphicsImageRenderer(size: size).image { _ in
      let pill = UIBezierPath(
        roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 3, dy: 3), cornerRadius: 26)
      color.setFill()
      pill.fill()
      ink.setStroke()
      pill.lineWidth = 5
      pill.stroke()
      (name as NSString).draw(
        at: CGPoint(x: 22, y: (size.height - textSize.height) / 2),
        withAttributes: [.font: font, .foregroundColor: UIColor.white])
    }
    let plane = SCNPlane(width: size.width / 58 * 0.9, height: 0.9)
    let mat = SCNMaterial()
    mat.diffuse.contents = image
    mat.lightingModel = .constant
    mat.isDoubleSided = true
    plane.materials = [mat]
    let node = SCNNode(geometry: plane)
    node.constraints = [SCNBillboardConstraint()]
    node.renderingOrder = 10
    return node
  }

  private func surface(
    _ image: UIImage, normal: UIImage? = nil, roughness: CGFloat
  ) -> SCNMaterial {
    let result = material(.white, roughness: roughness)
    result.diffuse.contents = image
    result.normal.contents = normal
    result.normal.intensity = 0.7
    for property in [result.diffuse, result.normal] {
      property.wrapS = .repeat
      property.wrapT = .repeat
      property.mipFilter = .linear
      property.maxAnisotropy = 8
    }
    return result
  }

  private func ribbon(
    inner: Double, outer: Double, height: Double, drop: Double = 0, mat: SCNMaterial,
    across: Double = 1, along: Double = 8
  ) {
    var vertices: [SCNVector3] = []
    var normals: [SCNVector3] = []
    var texture: [CGPoint] = []
    var indices: [Int32] = []
    for i in 0...240 {
      let p = Course.point(track, Double(i))
      let h = Course.heading(track, Double(i))
      for offset in [inner, outer] {
        let y = offset == inner ? height : height + drop
        vertices.append(SCNVector3(p.x + cos(h) * offset, y, p.z - sin(h) * offset))
        normals.append(SCNVector3(0, 1, 0))
        texture.append(CGPoint(x: offset == inner ? 0 : across, y: Double(i) / along))
      }
      if i < 240 {
        let n = Int32(i * 2)
        indices += [n, n + 2, n + 1, n + 1, n + 2, n + 3]
      }
    }
    let geo = SCNGeometry(
      sources: [
        .init(vertices: vertices), .init(normals: normals), .init(textureCoordinates: texture),
      ], elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
    mat.isDoubleSided = true
    geo.materials = [mat]
    courseRoot.addChildNode(SCNNode(geometry: geo))
  }

  private func tube(offset: Double, radius: Double, y: Double, mat: SCNMaterial) {
    let ring = 14
    var vertices: [SCNVector3] = []
    var normals: [SCNVector3] = []
    var texture: [CGPoint] = []
    var indices: [Int32] = []
    for i in 0...240 {
      let p = Course.point(track, Double(i))
      let h = Course.heading(track, Double(i))
      let cx = p.x + cos(h) * offset
      let cz = p.z - sin(h) * offset
      for k in 0...ring {
        let a = Double(k) / Double(ring) * .pi * 2
        let n = SCNVector3(cos(h) * cos(a), sin(a), -sin(h) * cos(a))
        normals.append(n)
        vertices.append(
          SCNVector3(
            cx + Double(n.x) * radius, y + Double(n.y) * radius, cz + Double(n.z) * radius))
        texture.append(CGPoint(x: Double(k) / Double(ring), y: Double(i) / 3))
      }
      if i < 240 {
        for k in 0..<ring {
          let a = Int32(i * (ring + 1) + k)
          let b = a + Int32(ring + 1)
          indices += [a, a + 1, b, a + 1, b + 1, b]
        }
      }
    }
    let geo = SCNGeometry(
      sources: [
        .init(vertices: vertices), .init(normals: normals), .init(textureCoordinates: texture),
      ], elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
    mat.isDoubleSided = true
    geo.materials = [mat]
    courseRoot.addChildNode(SCNNode(geometry: geo))
  }

  private func flowers(parent: SCNNode, night: Bool, seed: Int) {
    let palette: [UIColor] =
      night
      ? [.systemCyan, .systemYellow, .white]
      : [
        UIColor(red: 1, green: 0.35, blue: 0.5, alpha: 1), .systemYellow, .white,
        UIColor(red: 0.7, green: 0.45, blue: 1, alpha: 1),
      ]
    let bush = ball(
      CGFloat(0.9 + Art.hash(seed, 7) * 0.5),
      night
        ? UIColor(red: 0.55, green: 0.2, blue: 0.7, alpha: 1)
        : UIColor(red: 0.18, green: 0.55, blue: 0.2, alpha: 1), SCNVector3(0, 0.2, 0),
      parent: parent)
    bush.scale = SCNVector3(1.3, 0.75, 1.1)
    for j in 0..<5 {
      let a = Double(j) * 1.25 + Double(seed)
      let bloom = ball(
        0.2, palette[(seed + j) % palette.count],
        SCNVector3(sin(a) * 1.0, 0.75 + Art.hash(seed, j) * 0.25, cos(a) * 0.8), parent: parent)
      if night { bloom.geometry?.firstMaterial?.emission.intensity = 2 }
      bloom.geometry?.firstMaterial?.emission.contents =
        night ? palette[(seed + j) % palette.count] : UIColor.black
    }
  }

  private func tree(parent: SCNNode, seed: Int) {
    shape(
      SCNCone(topRadius: 0.35, bottomRadius: 0.7, height: 5),
      UIColor(red: 0.45, green: 0.28, blue: 0.2, alpha: 1), SCNVector3(0, 2.4, 0), parent: parent)
    let tones = [
      UIColor(red: 0.22, green: 0.66, blue: 0.24, alpha: 1),
      UIColor(red: 0.36, green: 0.8, blue: 0.28, alpha: 1),
      UIColor(red: 0.5, green: 0.88, blue: 0.3, alpha: 1),
    ]
    for j in 0..<5 {
      let angle = Double(j) * 1.3 + Double(seed)
      let r = CGFloat(2.2 + Art.hash(seed, j + 10) * 1.2)
      ball(
        r, tones[j % 3],
        SCNVector3(sin(angle) * 1.6, 6.2 + Double(j % 3) * 1.1, cos(angle) * 1.6),
        parent: parent)
    }
  }

  private func palm(parent: SCNNode, seed: Int) {
    let bark = UIColor(red: 0.62, green: 0.45, blue: 0.28, alpha: 1)
    var top = SCNVector3(0, 0, 0)
    for j in 0..<7 {
      let segment = shape(
        SCNCylinder(radius: CGFloat(0.5 - Double(j) * 0.04), height: 1.35), bark,
        SCNVector3(Float(j * j) * 0.035, Float(j) * 1.25 + 0.6, 0), parent: parent)
      segment.eulerAngles.z = -Float(j) * 0.05
      top = segment.position
    }
    for j in 0..<7 {
      let a = Float(j) / 7 * .pi * 2
      let frond = ball(
        1, UIColor(red: 0.18, green: 0.62, blue: 0.22, alpha: 1),
        SCNVector3(top.x + sin(a) * 1.6, top.y + 0.2, cos(a) * 1.6), parent: parent)
      frond.scale = SCNVector3(0.45, 0.12, 1.9)
      frond.eulerAngles = SCNVector3(0.35, a, 0)
    }
    for j in 0..<3 {
      let a = Double(j) * 2.1
      ball(
        0.32, UIColor(red: 0.45, green: 0.3, blue: 0.15, alpha: 1),
        SCNVector3(Double(top.x) + sin(a) * 0.4, Double(top.y) - 0.3, cos(a) * 0.4),
        parent: parent)
    }
  }

  private func lollipop(parent: SCNNode, seed: Int) {
    shape(SCNCylinder(radius: 0.22, height: 7), .white, SCNVector3(0, 3.5, 0), parent: parent)
    let swirl = SCNCylinder(radius: 2.6, height: 0.6)
    let front = material(.white, roughness: 0.15)
    let image = Art.swirl(
      [colors[seed % 3], .white, UIColor(red: 0.4, green: 0.85, blue: 1, alpha: 1)])
    front.diffuse.contents = image
    front.emission.contents = image
    front.emission.intensity = 0.35
    front.clearCoat.contents = 1
    let rim = paint(colors[seed % 3])
    swirl.materials = [rim, front, front]
    swirl.radialSegmentCount = 40
    let node = SCNNode(geometry: swirl)
    node.position = SCNVector3(0, 8.4, 0)
    node.eulerAngles.x = .pi / 2
    parent.addChildNode(node)
  }

  private func lamp(parent: SCNNode) {
    let pole = part(
      SCNCylinder(radius: 0.18, height: 8),
      surface(Art.stripes([.white, UIColor.systemPink], count: 6, gloss: false), roughness: 0.3),
      SCNVector3(0, 4, 0), parent: parent)
    pole.geometry?.firstMaterial?.diffuse.contentsTransform = SCNMatrix4MakeScale(1, 3, 1)
    let bulb = ball(
      0.8, UIColor(red: 1, green: 0.82, blue: 0.45, alpha: 1), SCNVector3(0, 8.4, 0),
      parent: parent)
    bulb.geometry?.firstMaterial?.emission.contents = UIColor(
      red: 1, green: 0.75, blue: 0.35, alpha: 1)
    bulb.geometry?.firstMaterial?.emission.intensity = 4
  }

  private func hill(parent: SCNNode, seed: Int) {
    let green = surface(Art.cached("grassfalse") { Art.grass(night: false) }, roughness: 0.9)
    green.diffuse.contentsTransform = SCNMatrix4MakeScale(10, 10, 1)
    green.diffuse.wrapS = .repeat
    green.diffuse.wrapT = .repeat
    green.multiply.contents = UIColor(red: 0.62, green: 0.78, blue: 0.9, alpha: 1)
    let base = CGFloat(55 + Art.hash(seed, 1) * 35)
    part(
      SCNCone(
        topRadius: base * 0.18, bottomRadius: base,
        height: CGFloat(22 + Art.hash(seed, 2) * 26)), green, SCNVector3(0, 10, 0),
      parent: parent)
    if seed % 4 == 0 {
      let peak = shape(
        SCNCone(topRadius: 2, bottomRadius: 36, height: 70),
        UIColor(red: 0.45, green: 0.55, blue: 0.7, alpha: 1), SCNVector3(20, 30, -30),
        parent: parent)
      shape(
        SCNCone(topRadius: 2, bottomRadius: 12, height: 22), .white,
        SCNVector3(peak.position.x, 55, peak.position.z), parent: parent)
    }
  }

  private func skyline(parent: SCNNode, seed: Int) {
    let windows = Art.cached("win\(seed % 4)") { Art.windows(seed: seed % 4) }
    for j in 0..<4 {
      let w = CGFloat(10 + Art.hash(seed, j) * 10)
      let h = CGFloat(22 + Art.hash(seed, j + 5) * 55)
      let mat = material(UIColor(red: 0.12, green: 0.08, blue: 0.3, alpha: 1), roughness: 0.3)
      mat.emission.contents = windows
      mat.emission.intensity = 1.4
      mat.emission.wrapS = .repeat
      mat.emission.wrapT = .repeat
      mat.emission.contentsTransform = SCNMatrix4MakeScale(Float(w / 8), Float(h / 12), 1)
      let tower = part(
        SCNBox(width: w, height: h, length: w, chamferRadius: 1.2), mat,
        SCNVector3(Float(j) * 13 - 20, Float(h / 2), Float(Art.hash(seed, j + 9) * 12)),
        parent: parent)
      let cap = ball(
        1.4, [UIColor.systemPink, .systemCyan, .systemYellow][j % 3],
        SCNVector3(tower.position.x, Float(h) + 1.5, tower.position.z), parent: parent)
      cap.geometry?.firstMaterial?.emission.intensity = 4
      cap.geometry?.firstMaterial?.emission.contents = cap.geometry?.firstMaterial?.diffuse.contents
    }
  }

  private func grandstand(night: Bool, parent: SCNNode) {
    let p = Course.point(track, 6)
    let h = Course.heading(track, 6)
    let root = SCNNode()
    root.position = SCNVector3(p.x + cos(h) * 24, 0, p.z - sin(h) * 24)
    root.eulerAngles.y = Float(h + .pi / 2)
    parent.addChildNode(root)
    let crowd = surface(Art.cached("crowd") { Art.crowd() }, roughness: 0.8)
    crowd.diffuse.contentsTransform = SCNMatrix4MakeScale(4, 1, 1)
    for row in 0..<4 {
      part(
        SCNBox(width: 30, height: 1.4, length: 2.2, chamferRadius: 0.2), crowd,
        SCNVector3(0, Float(row) * 1.4 + 0.7, Float(row) * 2.2), parent: root)
    }
    let roof = box(
      32, 0.5, 11, night ? .systemPink : UIColor(red: 1, green: 0.3, blue: 0.35, alpha: 1),
      SCNVector3(0, 8.5, 3.6), parent: root, bevel: 0.25)
    roof.eulerAngles.x = -0.12
    for x: Float in [-15, 0, 15] {
      shape(SCNCylinder(radius: 0.3, height: 8.5), .white, SCNVector3(x, 4.2, 7.6), parent: root)
    }
  }

  private func balloon(parent: SCNNode, color: UIColor) {
    let envelope = part(
      SCNSphere(radius: 5),
      surface(Art.stripes([color, .white], count: 4), roughness: 0.4), SCNVector3Zero,
      parent: parent)
    envelope.scale = SCNVector3(1, 1.2, 1)
    envelope.eulerAngles.z = .pi / 2
    box(
      1.6, 1.3, 1.6, UIColor(red: 0.6, green: 0.4, blue: 0.25, alpha: 1), SCNVector3(0, -8, 0),
      parent: parent, bevel: 0.2)
  }

  private func tower(parent: SCNNode, night: Bool, index: Int) {
    let color = colors[index % 3]
    shape(
      SCNCylinder(radius: 3, height: 10),
      night ? UIColor(red: 0.5, green: 0.24, blue: 0.6, alpha: 1) : .white, SCNVector3(0, 5, 0),
      parent: parent)
    let roof = part(
      SCNCone(topRadius: 0.1, bottomRadius: 4.3, height: 5), paint(color), SCNVector3(0, 12.5, 0),
      parent: parent)
    roof.castsShadow = true
    for i in 0..<6 {
      let t = Float(i) * .pi / 3
      let window = box(
        1, 2, 0.3, night ? .systemYellow : UIColor(red: 0.4, green: 0.8, blue: 1, alpha: 1),
        SCNVector3(sin(t) * 2.95, 6.5, cos(t) * 2.95), parent: parent, bevel: 0.5)
      window.eulerAngles.y = t
      if night { window.geometry?.firstMaterial?.emission.contents = UIColor.orange }
    }
    shape(SCNCylinder(radius: 0.13, height: 3.5), .white, SCNVector3(0, 16.5, 0), parent: parent)
    box(2.3, 1.1, 0.06, color, SCNVector3(1.1, 17.3, 0), parent: parent)
  }
  private func arch(index: Int, start: Bool, night: Bool) {
    let p = Course.point(track, Double(index))
    let h = Course.heading(track, Double(index))
    let root = SCNNode()
    root.position = SCNVector3(p.x, 0, p.z)
    root.eulerAngles.y = Float(h)
    courseRoot.addChildNode(root)
    for side: Float in [-1, 1] {
      shape(SCNCylinder(radius: 0.7, height: 11), .white, SCNVector3(side * 11, 5, 0), parent: root)
      ball(1.15, .systemYellow, SCNVector3(side * 11, 10.7, 0), parent: root)
    }
    box(
      23, 3.2, 1.1,
      night ? UIColor.systemPink : UIColor(red: 0.15, green: 0.28, blue: 0.61, alpha: 1),
      SCNVector3(0, 9, 0), parent: root, bevel: 1)
    let label = start ? "STARCAP  CIRCUIT" : "★  GO  GO  GO!  ★"
    text(label, size: 1.55, color: .white, parent: root, position: SCNVector3(0, 8.25, -0.65))
      .eulerAngles.y = .pi
    text(label, size: 1.55, color: .white, parent: root, position: SCNVector3(0, 8.25, 0.65))
    if start {
      for x in -9..<9 {
        for z in 0..<3 {
          box(
            1, 0.03, 1, (x + z) % 2 == 0 ? .white : ink,
            SCNVector3(Float(x) + 0.5, 0.07, Float(z) - 1), parent: root, bevel: 0)
        }
      }
    }
    for i in -4...4 {
      let flag = box(
        1.2, 0.7, 0.12, colors[abs(i) % 3],
        SCNVector3(Float(i) * 2.2, 6.5 + Float(abs(i)) * 0.3, 0), parent: root)
      flag.eulerAngles.z = Float(i) * 0.1
    }
  }

  static var portraits: [Int: UIImage] = [:]

  func renderPortraits() {
    guard RaceWorld.portraits.isEmpty, let device = MTLCreateSystemDefaultDevice() else { return }
    for racer in 0..<3 {
      let stage = SCNScene()
      stage.background.contents = UIColor.clear
      let kart = makeKart(racer: racer)
      kart.eulerAngles.y = 0.35
      stage.rootNode.addChildNode(kart)
      let key = SCNNode()
      key.light = SCNLight()
      key.light?.type = .directional
      key.light?.intensity = 1500
      key.eulerAngles = SCNVector3(-0.7, 0.5, 0)
      stage.rootNode.addChildNode(key)
      let rim = SCNNode()
      rim.light = SCNLight()
      rim.light?.type = .directional
      rim.light?.intensity = 900
      rim.light?.color = UIColor(red: 0.6, green: 0.8, blue: 1, alpha: 1)
      rim.eulerAngles = SCNVector3(-0.3, .pi + 0.6, 0)
      stage.rootNode.addChildNode(rim)
      let fill = SCNNode()
      fill.light = SCNLight()
      fill.light?.type = .ambient
      fill.light?.intensity = 450
      stage.rootNode.addChildNode(fill)
      let eye = SCNNode()
      eye.camera = SCNCamera()
      eye.camera?.fieldOfView = 30
      eye.position = SCNVector3(1.6, 3.4, 8.2)
      eye.look(at: SCNVector3(0, 2.1, 0))
      stage.rootNode.addChildNode(eye)
      let renderer = SCNRenderer(device: device, options: nil)
      renderer.scene = stage
      renderer.pointOfView = eye
      RaceWorld.portraits[racer] = renderer.snapshot(
        atTime: 0, with: CGSize(width: 360, height: 300), antialiasingMode: .multisampling4X)
    }
  }

  func makeKart(racer: Int) -> SCNNode {
    let root = SCNNode()
    let index = min(2, max(0, racer))
    let color = colors[index]
    let coat = paint(color)
    let dark = material(ink, roughness: 0.35)
    let white = material(.white, roughness: 0.3)
    let shadowPlane = SCNPlane(width: 4.4, height: 5.6)
    let shadowMat = SCNMaterial()
    shadowMat.lightingModel = .constant
    shadowMat.diffuse.contents = Art.softDot
    shadowMat.multiply.contents = UIColor.black
    shadowMat.transparency = 0.55
    shadowMat.writesToDepthBuffer = false
    shadowMat.diffuse.intensity = 1
    shadowPlane.materials = [shadowMat]
    let shadow = SCNNode(geometry: shadowPlane)
    shadow.eulerAngles.x = -.pi / 2
    shadow.position.y = 0.04
    shadow.castsShadow = false
    shadow.geometry?.firstMaterial?.diffuse.contents = UIColor.black
    shadow.geometry?.firstMaterial?.transparent.contents = Art.softDot
    shadow.opacity = 0.5
    root.addChildNode(shadow)
    part(
      SCNBox(width: 2.5, height: 0.35, length: 3.9, chamferRadius: 0.17), dark,
      SCNVector3(0, 0.55, 0), parent: root)
    let shell = part(
      SCNCapsule(capRadius: 0.8, height: 3.8), coat, SCNVector3(0, 1, 0.1),
      parent: root)
    shell.eulerAngles.x = .pi / 2
    shell.scale = SCNVector3(1.5, 1, 0.62)
    let nose = part(SCNSphere(radius: 0.75), coat, SCNVector3(0, 0.88, 1.75), parent: root)
    nose.scale = SCNVector3(1.45, 0.62, 0.95)
    let bumper = part(
      SCNCapsule(capRadius: 0.22, height: 2.7), dark, SCNVector3(0, 0.62, 2.3),
      parent: root)
    bumper.eulerAngles.z = .pi / 2
    let plate = part(
      SCNBox(width: 0.95, height: 0.06, length: 0.6, chamferRadius: 0.03), white,
      SCNVector3(0, 1.3, 1.55), parent: root)
    plate.eulerAngles.x = 0.28
    text(
      "\(index + 1)", size: 0.55, color: color, parent: root, position: SCNVector3(0, 1.28, 1.52)
    )
    .eulerAngles.x = -.pi / 2 + 0.28
    for side: Float in [-1, 1] {
      let pod = part(
        SCNCapsule(capRadius: 0.36, height: 2.3), coat,
        SCNVector3(side * 1.12, 0.85, 0.15), parent: root)
      pod.eulerAngles.x = .pi / 2
      let stripe = part(
        SCNCapsule(capRadius: 0.1, height: 2.0), white,
        SCNVector3(side * 1.46, 0.92, 0.15), parent: root)
      stripe.eulerAngles.x = .pi / 2
      let light = ball(0.14, .white, SCNVector3(side * 0.62, 0.95, 2.35), parent: root)
      light.geometry?.firstMaterial?.emission.contents = UIColor.white
      light.geometry?.firstMaterial?.emission.intensity = 2.5
      part(
        SCNBox(width: 0.14, height: 0.7, length: 0.3, chamferRadius: 0.05), dark,
        SCNVector3(side * 0.75, 1.95, -1.95), parent: root)
      part(
        SCNBox(width: 0.1, height: 0.55, length: 0.95, chamferRadius: 0.05), dark,
        SCNVector3(side * 1.36, 2.32, -2.05), parent: root)
      let pipe = part(
        SCNCylinder(radius: 0.2, height: 0.8), chrome(),
        SCNVector3(side * 0.45, 1.1, -2.25), parent: root)
      pipe.eulerAngles.x = .pi / 2
      let mouth = part(
        SCNCylinder(radius: 0.13, height: 0.82), dark,
        SCNVector3(side * 0.45, 1.1, -2.25), parent: root)
      mouth.eulerAngles.x = .pi / 2
      let flame = SCNNode()
      flame.name = "flame"
      flame.position = SCNVector3(side * 0.45, 1.1, -2.7)
      flame.addParticleSystem(Art.flame())
      root.addChildNode(flame)
      for axle: Float in [-1.25, 1.3] {
        let radius: CGFloat = axle < 0 ? 0.64 : 0.52
        let wheel = SCNNode()
        wheel.name = "wheel"
        wheel.position = SCNVector3(side * 1.5, Float(radius) + 0.02, axle)
        root.addChildNode(wheel)
        let tire = part(
          SCNTorus(ringRadius: radius * 0.62, pipeRadius: radius * 0.4), rubber(),
          SCNVector3Zero, parent: wheel)
        tire.eulerAngles.z = .pi / 2
        let rim = part(
          SCNCylinder(radius: radius * 0.52, height: radius * 0.62), chrome(),
          SCNVector3Zero, parent: wheel)
        rim.eulerAngles.z = .pi / 2
        let cap = part(
          SCNCylinder(radius: radius * 0.24, height: radius * 0.72), coat,
          SCNVector3Zero, parent: wheel)
        cap.eulerAngles.z = .pi / 2
        for spoke in 0..<3 {
          let bar = part(
            SCNBox(
              width: radius * 0.66, height: radius * 0.14, length: radius * 0.95,
              chamferRadius: 0.02), dark, SCNVector3Zero, parent: wheel)
          bar.eulerAngles.x = Float(spoke) * .pi / 3
        }
      }
    }
    let rim = part(
      SCNTorus(ringRadius: 0.78, pipeRadius: 0.14), dark, SCNVector3(0, 1.45, -0.15),
      parent: root)
    rim.scale.z = 1.25
    let seat = part(
      SCNBox(width: 1.25, height: 1.05, length: 0.35, chamferRadius: 0.17), dark,
      SCNVector3(0, 1.85, -0.85), parent: root)
    seat.eulerAngles.x = -0.15
    part(
      SCNBox(width: 1.5, height: 0.7, length: 0.9, chamferRadius: 0.2), chrome(),
      SCNVector3(0, 1.35, -1.6), parent: root)
    part(
      SCNBox(width: 2.8, height: 0.14, length: 0.85, chamferRadius: 0.07), coat,
      SCNVector3(0, 2.35, -2.05), parent: root)
    let column = part(
      SCNCylinder(radius: 0.07, height: 0.9), dark, SCNVector3(0, 1.65, 1.1),
      parent: root)
    column.eulerAngles.x = .pi / 3.5
    let steering = part(
      SCNTorus(ringRadius: 0.5, pipeRadius: 0.08), dark,
      SCNVector3(0, 2.0, 0.85), parent: root)
    steering.eulerAngles.x = .pi / 2.6
    driver(racer: index, parent: root)
    let shieldMat = SCNMaterial()
    shieldMat.lightingModel = .constant
    shieldMat.diffuse.contents = UIColor(red: 0.3, green: 0.9, blue: 1, alpha: 1)
    shieldMat.transparent.contents = Art.cached("rim") { Art.rim() }
    shieldMat.transparencyMode = .rgbZero
    shieldMat.blendMode = .add
    shieldMat.writesToDepthBuffer = false
    shieldMat.isDoubleSided = false
    let bubble = SCNSphere(radius: 2.9)
    bubble.segmentCount = 48
    bubble.materials = [shieldMat]
    let shield = SCNNode(geometry: bubble)
    shield.name = "shield"
    shield.position = SCNVector3(0, 1.8, 0)
    shield.isHidden = true
    shield.castsShadow = false
    shield.runAction(.repeatForever(.rotateBy(x: 0, y: 2, z: 0, duration: 2)))
    root.addChildNode(shield)
    let sparks = SCNNode()
    sparks.name = "sparks"
    root.addChildNode(sparks)
    for side: Float in [-1, 1] {
      let emitter = SCNNode()
      emitter.position = SCNVector3(side * 1.5, 0.12, -1.5)
      emitter.addParticleSystem(Art.sparks())
      sparks.addChildNode(emitter)
      let dust = SCNNode()
      dust.name = "dust"
      dust.position = SCNVector3(side * 1.5, 0.2, -1.7)
      dust.addParticleSystem(Art.dust())
      root.addChildNode(dust)
    }
    return root
  }

  private func driver(racer: Int, parent root: SCNNode) {
    let suits = [
      UIColor(red: 0.16, green: 0.42, blue: 1, alpha: 1),
      UIColor(red: 0.62, green: 0.42, blue: 1, alpha: 1),
      UIColor(red: 0.22, green: 0.26, blue: 0.48, alpha: 1),
    ]
    let suit = material(suits[racer], roughness: 0.6)
    let glove = material(.white, roughness: 0.5)
    let torso = part(
      SCNCapsule(capRadius: 0.58, height: 1.5), suit, SCNVector3(0, 2.05, -0.3),
      parent: root)
    torso.scale.z = 0.85
    for side: Float in [-1, 1] {
      let arm = part(
        SCNCapsule(capRadius: 0.18, height: 1.15), suit,
        SCNVector3(side * 0.55, 2.05, 0.25), parent: root)
      arm.eulerAngles = SCNVector3(-1.15, 0, side * 0.25)
      ball(0.22, .white, SCNVector3(side * 0.42, 1.95, 0.78), parent: root)
        .geometry?.firstMaterial = glove
    }
    let y: Float = 3.15
    let eyeWhite = material(.white, roughness: 0.15)
    let pupil = material(ink, roughness: 0.08)
    let shine = material(.white, glow: true)
    if racer == 2 {
      let steel = material(
        UIColor(red: 0.86, green: 0.89, blue: 0.96, alpha: 1), roughness: 0.25,
        metal: 0.7)
      part(
        SCNBox(width: 1.75, height: 1.4, length: 1.45, chamferRadius: 0.5), steel,
        SCNVector3(0, y, -0.05), parent: root)
      let visor = material(UIColor(red: 0.05, green: 0.07, blue: 0.18, alpha: 1), roughness: 0.04)
      visor.clearCoat.contents = 1
      part(
        SCNBox(width: 1.4, height: 0.72, length: 0.12, chamferRadius: 0.3), visor,
        SCNVector3(0, y + 0.02, 0.68), parent: root)
      for x: Float in [-0.32, 0.32] {
        let eye = part(
          SCNCapsule(capRadius: 0.1, height: 0.36),
          material(UIColor(red: 0.3, green: 1, blue: 0.95, alpha: 1), glow: true),
          SCNVector3(x, y + 0.06, 0.76), parent: root)
        eye.geometry?.firstMaterial?.emission.intensity = 3
        let bolt = part(
          SCNCylinder(radius: 0.26, height: 0.2), chrome(),
          SCNVector3(x > 0 ? 0.92 : -0.92, y, -0.05), parent: root)
        bolt.eulerAngles.z = .pi / 2
      }
      let mouth = part(
        SCNCapsule(capRadius: 0.05, height: 0.4),
        material(UIColor(red: 0.3, green: 1, blue: 0.95, alpha: 1), glow: true),
        SCNVector3(0, y - 0.2, 0.76), parent: root)
      mouth.eulerAngles.z = .pi / 2
      part(
        SCNCylinder(radius: 0.07, height: 0.8), chrome(), SCNVector3(0, y + 1.05, -0.05),
        parent: root)
      let tip = ball(0.24, .systemPink, SCNVector3(0, y + 1.5, -0.05), parent: root)
      tip.geometry?.firstMaterial?.emission.contents = UIColor.systemPink
      tip.geometry?.firstMaterial?.emission.intensity = 3
      return
    }
    let fur =
      racer == 0
      ? material(UIColor(red: 0.92, green: 0.52, blue: 0.24, alpha: 1), roughness: 0.75)
      : material(UIColor(red: 0.98, green: 0.95, blue: 1, alpha: 1), roughness: 0.75)
    let cream = material(UIColor(red: 1, green: 0.93, blue: 0.82, alpha: 1), roughness: 0.7)
    let pink = material(UIColor(red: 1, green: 0.5, blue: 0.62, alpha: 1), roughness: 0.5)
    let head = part(SCNSphere(radius: 0.98), fur, SCNVector3(0, y, 0), parent: root)
    head.scale = SCNVector3(1.06, 0.96, 0.96)
    let muzzle = part(SCNSphere(radius: 0.5), cream, SCNVector3(0, y - 0.32, 0.62), parent: root)
    muzzle.scale = SCNVector3(1.25, 0.78, 0.72)
    part(
      SCNSphere(radius: 0.13), racer == 0 ? pupil : pink, SCNVector3(0, y - 0.14, 1.02),
      parent: root)
    for x: Float in [-0.37, 0.37] {
      let white = part(
        SCNSphere(radius: 0.26), eyeWhite, SCNVector3(x, y + 0.14, 0.76),
        parent: root)
      white.scale = SCNVector3(0.85, 1.12, 0.6)
      let iris = part(
        SCNSphere(radius: 0.17), pupil, SCNVector3(x * 1.02, y + 0.11, 0.88),
        parent: root)
      iris.scale = SCNVector3(0.88, 1.15, 0.6)
      part(SCNSphere(radius: 0.055), shine, SCNVector3(x + 0.05, y + 0.21, 0.97), parent: root)
      let blush = part(
        SCNSphere(radius: 0.15), pink, SCNVector3(x * 1.7, y - 0.22, 0.72),
        parent: root)
      blush.scale.z = 0.3
      blush.opacity = 0.8
      if racer == 0 {
        let ear = part(
          SCNCone(topRadius: 0.04, bottomRadius: 0.32, height: 0.8), fur,
          SCNVector3(x * 1.35, y + 0.95, -0.1), parent: root)
        ear.eulerAngles.z = -x * 0.8
        let inner = part(
          SCNCone(topRadius: 0.02, bottomRadius: 0.17, height: 0.5), pink,
          SCNVector3(x * 1.35, y + 0.9, 0.05), parent: root)
        inner.eulerAngles.z = -x * 0.8
      } else {
        let ear = part(
          SCNCapsule(capRadius: 0.22, height: 1.8), fur,
          SCNVector3(x * 0.95, y + 1.45, -0.15), parent: root)
        ear.eulerAngles = SCNVector3(-0.2, 0, -x * 0.35)
        let inner = part(
          SCNCapsule(capRadius: 0.11, height: 1.35), pink,
          SCNVector3(x * 0.95, y + 1.45, -0.02), parent: root)
        inner.eulerAngles = SCNVector3(-0.2, 0, -x * 0.35)
      }
    }
    if racer == 0 {
      let strap = part(
        SCNTorus(ringRadius: 0.97, pipeRadius: 0.07), material(ink, roughness: 0.5),
        SCNVector3(0, y + 0.55, 0), parent: root)
      strap.eulerAngles.x = 0.12
      for x: Float in [-0.32, 0.32] {
        let lens = part(
          SCNCylinder(radius: 0.24, height: 0.14),
          material(UIColor(red: 0.4, green: 0.85, blue: 1, alpha: 1), roughness: 0.05, metal: 0.3),
          SCNVector3(x, y + 0.72, 0.72), parent: root)
        lens.eulerAngles.x = .pi / 2 - 0.6
        let frame = part(
          SCNTorus(ringRadius: 0.25, pipeRadius: 0.05), chrome(),
          SCNVector3(x, y + 0.72, 0.74), parent: root)
        frame.eulerAngles.x = .pi / 2 - 0.6
      }
      for j in 0..<5 {
        let t = Float(j) / 4
        let puff = part(
          SCNSphere(radius: CGFloat(0.32 + t * 0.2)), fur,
          SCNVector3(0, 1.6 + t * 1.5, -1.3 - sin(t * 2.6) * 0.55), parent: root)
        puff.scale.z = 0.8
      }
      part(SCNSphere(radius: 0.3), cream, SCNVector3(0, 3.2, -1.6), parent: root)
    } else {
      part(SCNSphere(radius: 0.42), fur, SCNVector3(0, 1.9, -1.2), parent: root)
      let bow = part(SCNSphere(radius: 0.22), pink, SCNVector3(0.55, y + 0.75, 0.3), parent: root)
      bow.scale = SCNVector3(1.6, 1, 0.6)
    }
  }
  func flash(target: String) {
    guard let node = kartNodes[target] else { return }
    let flash = ball(
      3, UIColor.systemYellow.withAlphaComponent(0.7), SCNVector3(0, 2, 0), parent: node)
    flash.runAction(.sequence([.fadeOut(duration: 0.45), .removeFromParentNode()]))
  }

  func update(state: RaceState?, playerID: String, time: Double) {
    waterMaterial.normal.contentsTransform = SCNMatrix4Mult(
      SCNMatrix4MakeScale(0.03, 0.03, 1),
      SCNMatrix4MakeTranslation(Float(time * 0.015), Float(time * 0.01), 0))
    for (i, node) in itemNodes.enumerated() {
      let hue = (time * 0.25 + Double(i) * 0.08).truncatingRemainder(dividingBy: 1)
      node.childNodes.first?.geometry?.firstMaterial?.emission.contents = UIColor(
        hue: hue, saturation: 0.8, brightness: 0.55, alpha: 1)
    }
    guard let state, let me = state.players.first(where: { $0.id == playerID }),
      ["racing", "countdown", "results"].contains(state.phase)
    else {
      previewKart.isHidden = false
      let p = Course.point(track, 0)
      let h = Course.heading(track, 0)
      previewKart.eulerAngles.y = Float(h + 0.65 + sin(time * 0.6) * 0.55)
      previewKart.position.y = 0.15 + Float(abs(sin(time * 2.2)) * 0.08)
      let side = 6.4
      let baseX = p.x + cos(h) * side
      let baseZ = p.z - sin(h) * side
      let cameraX = baseX + sin(h) * 12.5
      let cameraZ = baseZ + cos(h) * 12.5
      cameraNode.position = SCNVector3(cameraX, 3.1, cameraZ)
      cameraNode.look(
        at: SCNVector3(baseX, 1.0, baseZ), up: SCNVector3(0, 1, 0),
        localFront: SCNVector3(0, 0, -1))
      cameraNode.camera?.fieldOfView = 60
      return
    }
    previewKart.isHidden = true
    if lastRace != state.race {
      lastRace = state.race
      cameraReady = false
    }
    for p in state.players {
      let node: SCNNode
      if let existing = kartNodes[p.id] {
        node = existing
      } else {
        node = makeKart(racer: p.racer)
        kartNodes[p.id] = node
        racersRoot.addChildNode(node)
        node.position = SCNVector3(p.x, 0.15, p.z)
        node.eulerAngles.y = Float(p.heading)
        let tag = nameTag(p.name.uppercased(), color: colors[min(2, max(0, p.racer))])
        tag.position = SCNVector3(0, 5.4, 0)
        tag.name = "tag"
        tag.isHidden = p.id == playerID
        node.addChildNode(tag)
      }
      let gap = hypot(p.x - me.x, p.z - me.z)
      node.childNode(withName: "tag", recursively: false)?.opacity = CGFloat(
        min(1, max(0, (gap - 14) / 10)))
      let factor: Float = 0.42
      node.position.x += (Float(p.x) - node.position.x) * factor
      node.position.z += (Float(p.z) - node.position.z) * factor
      node.position.y = 0.15 + Float(sin(time * 17) * min(0.05, p.speed / 400))
      let turn = wrappedAngle(p.heading - Double(node.eulerAngles.y))
      node.eulerAngles.y += Float(turn) * factor
      node.eulerAngles.z =
        p.drifting ? Float(sin(time * 6) * 0.04) - Float(turn) * 0.9 : -Float(turn) * 0.6
      for flame in node.childNodes where flame.name == "flame" {
        flame.particleSystems?.first?.birthRate = p.boost > 0 ? 260 : p.speed > 4 ? 12 : 0
      }
      for wheel in node.childNodes where wheel.name == "wheel" {
        wheel.eulerAngles.x += Float(p.speed / 30 / 0.58)
      }
      for dust in node.childNodes where dust.name == "dust" {
        dust.particleSystems?.first?.birthRate = p.drifting || p.stun > 0 ? 40 : 0
      }
      node.childNode(withName: "shield", recursively: false)?.isHidden = p.shield <= 0
      let sparks = node.childNode(withName: "sparks", recursively: false)
      let tier = Turbo.tier(p.charge)
      let sparkColor: UIColor =
        switch tier {
        case 0: UIColor.white.withAlphaComponent(0.6)
        case 1: UIColor(red: 0.25, green: 0.7, blue: 1, alpha: 1)
        case 2: UIColor.systemOrange
        default:
          UIColor(
            hue: (time * 2).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 1,
            alpha: 1)
        }
      for emitter in sparks?.childNodes ?? [] {
        guard let system = emitter.particleSystems?.first else { continue }
        system.birthRate = p.drifting ? CGFloat(30 + tier * 90) : 0
        system.particleColor = sparkColor
        system.particleSize = 0.12 + CGFloat(tier) * 0.05
        system.particleVelocity = 6 + CGFloat(tier) * 3
      }
      node.opacity = p.connected ? 1 : 0.35
      if p.stun > 0 { node.eulerAngles.z = Float(sin(time * 32) * 0.2) }
    }
    if state.hazards.count != lastHazards {
      for node in hazardsRoot.childNodes { node.removeFromParentNode() }
      for h in state.hazards {
        let gum = part(
          SCNSphere(radius: 1.1), paint(UIColor(red: 1, green: 0.35, blue: 0.7, alpha: 1)),
          SCNVector3(h.x, 0.3, h.z), parent: hazardsRoot)
        gum.scale.y = 0.4
        let drip = ball(0.45, .white, SCNVector3(h.x - 0.3, 0.62, h.z + 0.2), parent: hazardsRoot)
        drip.scale.y = 0.5
        drip.opacity = 0.7
      }
      lastHazards = state.hazards.count
    }
    let h = me.heading
    let target = SCNVector3(me.x - sin(h) * 9.6, 5.4, me.z - cos(h) * 9.6)
    if !cameraReady {
      cameraNode.position = target
      cameraReady = true
    }
    cameraNode.position.x += (target.x - cameraNode.position.x) * 0.22
    cameraNode.position.z += (target.z - cameraNode.position.z) * 0.22
    cameraNode.position.y += (target.y - cameraNode.position.y) * 0.22
    cameraNode.look(
      at: SCNVector3(me.x + sin(h) * 7, 1.9, me.z + cos(h) * 7),
      up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    let fov = (me.boost > 0 ? 80.0 : 66.0) + min(4, me.speed / 10)
    let current = Double(cameraNode.camera?.fieldOfView ?? 66)
    cameraNode.camera?.fieldOfView = CGFloat(current + (fov - current) * 0.12)
    if state.phase == "results"
      && courseRoot.childNode(withName: "confetti", recursively: false) == nil
    {
      let root = SCNNode()
      root.name = "confetti"
      courseRoot.addChildNode(root)
      root.position = SCNVector3(me.x, 14, me.z)
      root.addParticleSystem(Art.confetti())
    }
    if state.phase != "results" {
      courseRoot.childNode(withName: "confetti", recursively: false)?.removeFromParentNode()
    }
  }
}
