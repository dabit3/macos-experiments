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
    cameraNode.camera?.wantsHDR = true
    cameraNode.camera?.bloomIntensity = 0.3
    cameraNode.camera?.bloomThreshold = 1
    cameraNode.camera?.exposureOffset = 0.15
    scene.rootNode.addChildNode(cameraNode)
    let sun = SCNNode()
    sun.light = SCNLight()
    sun.light?.type = .directional
    sun.light?.intensity = 1100
    sun.light?.castsShadow = true
    sun.light?.shadowMode = .deferred
    sun.light?.shadowColor = UIColor.black.withAlphaComponent(0.22)
    sun.light?.shadowRadius = 3
    sun.light?.shadowMapSize = CGSize(width: 1024, height: 1024)
    sun.light?.orthographicScale = 110
    sun.eulerAngles = SCNVector3(-Float.pi / 3, -Float.pi / 5, 0)
    scene.rootNode.addChildNode(sun)
    let ambient = SCNNode()
    ambient.light = SCNLight()
    ambient.light?.type = .ambient
    ambient.light?.color = UIColor(red: 0.78, green: 0.85, blue: 1, alpha: 1)
    ambient.light?.intensity = 650
    scene.rootNode.addChildNode(ambient)
  }

  private func material(_ color: UIColor, glow: Bool = false) -> SCNMaterial {
    let result = SCNMaterial()
    result.diffuse.contents = color
    result.roughness.contents = 0.65
    if glow { result.emission.contents = color }
    return result
  }

  @discardableResult
  private func shape(
    _ geometry: SCNGeometry, _ color: UIColor, _ position: SCNVector3, parent: SCNNode,
    glow: Bool = false
  ) -> SCNNode {
    geometry.materials = [material(color, glow: glow)]
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
    sphere.segmentCount = 16
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
    let sky =
      night
      ? UIColor(red: 0.19, green: 0.1, blue: 0.39, alpha: 1)
      : UIColor(red: 0.26, green: 0.73, blue: 0.97, alpha: 1)
    scene.background.contents = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 256)).image {
      context in
      let top =
        night
        ? UIColor(red: 0.08, green: 0.04, blue: 0.25, alpha: 1)
        : UIColor(red: 0.1, green: 0.48, blue: 0.95, alpha: 1)
      let colors = [top.cgColor, sky.cgColor, UIColor.white.withAlphaComponent(1).cgColor]
      let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray,
        locations: [0, 0.62, 1])
      if let gradient {
        context.cgContext.drawLinearGradient(
          gradient, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
      }
    }
    scene.fogColor = sky
    scene.fogStartDistance = 190
    scene.fogEndDistance = 440
    let water =
      night
      ? UIColor(red: 0.1, green: 0.2, blue: 0.47, alpha: 1)
      : UIColor(red: 0.05, green: 0.68, blue: 0.82, alpha: 1)
    box(1300, 1, 1300, water, SCNVector3(0, -4, 0), parent: courseRoot)
    ribbon(
      inner: -17, outer: 17, height: -0.55,
      color: night ? .systemPink : UIColor(red: 0.36, green: 0.76, blue: 0.21, alpha: 1))
    ribbon(
      inner: -9.2, outer: 9.2, height: 0,
      color: night
        ? UIColor(red: 0.34, green: 0.16, blue: 0.55, alpha: 1)
        : UIColor(red: 0.34, green: 0.55, blue: 0.7, alpha: 1), textured: true)
    for side in [-1.0, 1.0] {
      ribbon(inner: side * 9.2, outer: side * 10.3, height: 0.025, color: .white, striped: true)
      ribbon(inner: side * 10.3, outer: side * 10.55, height: 0.05, color: .systemYellow)
    }
    for i in stride(from: 0, to: 240, by: 3) {
      let p = Course.point(track, Double(i))
      let h = Course.heading(track, Double(i))
      for side in [-1.0, 1.0] {
        let rail = box(
          1, 0.95, 6.4, (i / 3) % 2 == 0 ? (night ? .systemPink : .systemBlue) : .systemYellow,
          SCNVector3(p.x + cos(h) * side * 12.3, 0.6, p.z - sin(h) * side * 12.3),
          parent: courseRoot, bevel: 0.35)
        rail.eulerAngles.y = Float(h)
      }
      if i % 6 == 0 {
        let dash = box(
          0.24, 0.015, 2.3, UIColor.white.withAlphaComponent(0.7), SCNVector3(p.x, 0.06, p.z),
          parent: courseRoot, bevel: 0)
        dash.eulerAngles.y = Float(h)
      }
    }
    for i in stride(from: 7, to: 240, by: 8) {
      let p = Course.point(track, Double(i))
      let h = Course.heading(track, Double(i))
      for side in [-1.0, 1.0] {
        let root = SCNNode()
        root.position = SCNVector3(p.x + cos(h) * side * 20, -0.7, p.z - sin(h) * side * 20)
        courseRoot.addChildNode(root)
        if i % 3 == 0 {
          tower(parent: root, night: night, index: i)
        } else {
          tree(parent: root, night: night, seed: i)
        }
      }
    }
    for i in 0..<16 {
      let t = Double(i) * .pi / 8
      let root = SCNNode()
      root.position = SCNVector3(sin(t) * 180, -5, cos(t) * 180)
      courseRoot.addChildNode(root)
      let color =
        night
        ? UIColor(red: 0.35, green: 0.17, blue: 0.51, alpha: 1)
        : UIColor(red: 0.31, green: 0.7, blue: 0.54, alpha: 1)
      shape(
        SCNCone(
          topRadius: 6, bottomRadius: CGFloat(25 + i % 5 * 3), height: CGFloat(35 + i % 4 * 9)),
        color, SCNVector3(0, 10, 0), parent: root)
      if !night {
        for j in 0..<4 {
          ball(
            CGFloat(7 + j), .white, SCNVector3(Float(j * 8 - 10), Float(50 + i % 4 * 7), 0),
            parent: root)
        }
      } else {
        ball(0.65, UIColor.systemYellow, SCNVector3(0, Float(60 + i % 4 * 9), 0), parent: root)
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
        cube.geometry?.firstMaterial?.emission.contents = UIColor(
          red: 0.1, green: 0.4, blue: 0.5, alpha: 1)
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

  private func ribbon(
    inner: Double, outer: Double, height: Double, color: UIColor, textured: Bool = false,
    striped: Bool = false
  ) {
    var vertices: [SCNVector3] = []
    var normals: [SCNVector3] = []
    var texture: [CGPoint] = []
    var indices: [Int32] = []
    for i in 0...240 {
      let p = Course.point(track, Double(i))
      let h = Course.heading(track, Double(i))
      for offset in [inner, outer] {
        vertices.append(SCNVector3(p.x + cos(h) * offset, height, p.z - sin(h) * offset))
        normals.append(SCNVector3(0, 1, 0))
        texture.append(CGPoint(x: offset == inner ? 0 : 1, y: Double(i) / (striped ? 2 : 8)))
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
    let mat = material(color)
    mat.isDoubleSided = true
    if textured || striped {
      let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { context in
        color.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
        if striped {
          UIColor(red: 1, green: 0.22, blue: 0.36, alpha: 1).setFill()
          context.fill(CGRect(x: 0, y: 0, width: 128, height: 64))
        } else {
          UIColor.white.withAlphaComponent(0.04).setFill()
          for x in 0..<16 {
            for y in 0..<16 where (x + y) % 2 == 0 {
              context.fill(CGRect(x: x * 8, y: y * 8, width: 8, height: 8))
            }
          }
        }
      }
      mat.diffuse.contents = image
      mat.diffuse.wrapT = .repeat
      mat.diffuse.wrapS = .repeat
    }
    geo.materials = [mat]
    courseRoot.addChildNode(SCNNode(geometry: geo))
  }

  private func tree(parent: SCNNode, night: Bool, seed: Int) {
    shape(
      SCNCylinder(radius: 0.55, height: 6), UIColor(red: 0.49, green: 0.27, blue: 0.24, alpha: 1),
      SCNVector3(0, 2.5, 0), parent: parent)
    let color =
      night
      ? UIColor(red: 1, green: 0.4 + CGFloat(seed % 3) * 0.1, blue: 0.73, alpha: 1)
      : UIColor(red: 0.36, green: 0.82, blue: 0.28, alpha: 1)
    for j in 0..<4 {
      let angle = Double(j) * .pi * 2 / 3
      ball(
        CGFloat(3.5 + Double(seed % 3) * 0.4), color,
        SCNVector3(sin(angle) * 2, 7 + Double(j % 2), cos(angle) * 2), parent: parent)
    }
    if night {
      let lantern = ball(0.85, .systemYellow, SCNVector3(2.2, 4, 0), parent: parent)
      lantern.geometry?.firstMaterial?.emission.contents = UIColor.orange
    }
  }

  private func tower(parent: SCNNode, night: Bool, index: Int) {
    let color = colors[index % 3]
    shape(
      SCNCylinder(radius: 3, height: 10),
      night ? UIColor(red: 0.6, green: 0.24, blue: 0.5, alpha: 1) : .white, SCNVector3(0, 4.5, 0),
      parent: parent)
    shape(
      SCNCone(topRadius: 0.1, bottomRadius: 4.3, height: 5), color, SCNVector3(0, 11.7, 0),
      parent: parent)
    for i in 0..<4 {
      let t = Float(i) * .pi / 2
      let window = box(
        1.2, 2.4, 0.25, night ? .systemYellow : .systemCyan, SCNVector3(sin(t) * 3, 6, cos(t) * 3),
        parent: parent, bevel: 0.6)
      window.eulerAngles.y = t
    }
    shape(SCNCylinder(radius: 0.13, height: 3.5), .white, SCNVector3(0, 15.5, 0), parent: parent)
    box(2.3, 1.1, 0.06, color, SCNVector3(1.1, 16.3, 0), parent: parent)
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

  func makeKart(racer: Int) -> SCNNode {
    let root = SCNNode()
    let color = colors[min(2, max(0, racer))]
    let shadow = shape(
      SCNCylinder(radius: 1.7, height: 0.02), UIColor.black.withAlphaComponent(0.19),
      SCNVector3(0, 0.08, 0), parent: root)
    shadow.scale.z = 1.5
    box(2.6, 0.55, 3.5, ink, SCNVector3(0, 0.65, 0), parent: root, bevel: 0.25)
    box(2.7, 0.9, 3.2, color, SCNVector3(0, 1, 0.1), parent: root, bevel: 0.45)
    box(1.7, 0.45, 1.5, color, SCNVector3(0, 1.2, 1.4), parent: root, bevel: 0.2)
    box(2.1, 0.16, 0.5, .white, SCNVector3(0, 1.15, 2), parent: root)
    box(2.5, 0.18, 0.6, color, SCNVector3(0, 1.8, -1.65), parent: root)
    box(0.25, 0.9, 0.25, ink, SCNVector3(-0.8, 1.35, -1.6), parent: root)
    box(0.25, 0.9, 0.25, ink, SCNVector3(0.8, 1.35, -1.6), parent: root)
    for side: Float in [-1, 1] {
      for axle: Float in [-1.1, 1.2] {
        let wheel = shape(
          SCNCylinder(radius: 0.62, height: 0.6), ink, SCNVector3(side * 1.45, 0.65, axle),
          parent: root)
        wheel.eulerAngles.z = .pi / 2
        let hub = shape(
          SCNCylinder(radius: 0.33, height: 0.63), .white, SCNVector3(side * 1.47, 0.65, axle),
          parent: root)
        hub.eulerAngles.z = .pi / 2
        let bolt = shape(
          SCNCylinder(radius: 0.14, height: 0.65), color, SCNVector3(side * 1.48, 0.65, axle),
          parent: root)
        bolt.eulerAngles.z = .pi / 2
      }
      let pipe = shape(
        SCNCylinder(radius: 0.28, height: 0.9), .lightGray, SCNVector3(side * 0.85, 1.2, -1.9),
        parent: root)
      pipe.eulerAngles.x = .pi / 2
      ball(0.22, ink, SCNVector3(side * 0.85, 1.2, -2.36), parent: root)
      let flame = shape(
        SCNCone(topRadius: 0, bottomRadius: 0.34, height: 2.8), .systemCyan,
        SCNVector3(side * 0.85, 1.2, -3), parent: root, glow: true)
      flame.eulerAngles.x = -.pi / 2
      flame.name = "flame"
      flame.isHidden = true
    }
    box(1.3, 1, 1.2, ink, SCNVector3(0, 1.7, -0.45), parent: root, bevel: 0.4)
    let torso = ball(0.85, color, SCNVector3(0, 2, 0), parent: root)
    torso.scale = SCNVector3(0.8, 1, 0.75)
    let head = ball(
      1.03, racer == 2 ? UIColor.systemYellow : UIColor(red: 1, green: 0.88, blue: 0.74, alpha: 1),
      SCNVector3(0, 3, 0), parent: root)
    head.scale.z = 0.93
    if racer == 2 {
      box(1.6, 0.8, 0.2, ink, SCNVector3(0, 3.1, 0.83), parent: root, bevel: 0.2)
      for x: Float in [-0.38, 0.38] { ball(0.19, .cyan, SCNVector3(x, 3.15, 1), parent: root) }
      shape(SCNCylinder(radius: 0.09, height: 0.6), .white, SCNVector3(0, 4.2, 0), parent: root)
      ball(0.23, .systemPink, SCNVector3(0, 4.55, 0), parent: root)
    } else {
      let helmet = ball(1.075, color, SCNVector3(0, 3.35, -0.08), parent: root)
      helmet.scale.y = 0.8
      box(1.55, 0.14, 0.9, color, SCNVector3(0, 3.45, 0.7), parent: root, bevel: 0.1)
      for x: Float in [-0.48, 0.48] {
        let ear = ball(
          racer == 1 ? 0.32 : 0.39, color, SCNVector3(x, racer == 1 ? 4.35 : 4.05, -0.05),
          parent: root)
        ear.scale.y = racer == 1 ? 2.5 : 1.2
        ball(0.12, ink, SCNVector3(x * 0.65, 3.05, 0.94), parent: root)
      }
      ball(0.16, .systemPink, SCNVector3(0, 2.82, 1.02), parent: root)
      let tail = ball(
        racer == 0 ? 0.68 : 0.38, racer == 0 ? color : .white, SCNVector3(0, 2.1, -1.08),
        parent: root)
      tail.scale.y = racer == 0 ? 1.5 : 1
    }
    for x: Float in [-0.77, 0.77] { ball(0.26, .white, SCNVector3(x, 2.05, 0.85), parent: root) }
    let steering = shape(
      SCNTorus(ringRadius: 0.55, pipeRadius: 0.07), ink, SCNVector3(0, 2.0, 0.95), parent: root)
    steering.eulerAngles.x = .pi / 5
    text("★", size: 0.7, color: .white, parent: root, position: SCNVector3(0, 3.3, -1.0))
      .eulerAngles.y = .pi
    let shield = ball(
      2.65, UIColor.cyan.withAlphaComponent(0.2), SCNVector3(0, 1.7, 0), parent: root)
    shield.name = "shield"
    shield.isHidden = true
    shield.geometry?.firstMaterial?.transparency = 0.25
    shield.geometry?.firstMaterial?.writesToDepthBuffer = false
    let sparks = SCNNode()
    sparks.name = "sparks"
    root.addChildNode(sparks)
    for i in 0..<12 {
      let spark = shape(
        SCNCone(topRadius: 0, bottomRadius: 0.1, height: 0.8), .cyan,
        SCNVector3(Float(i % 2 == 0 ? -1.7 : 1.7), 0.45, -1.6 - Float(i / 2) * 0.3), parent: sparks,
        glow: true)
      spark.eulerAngles = SCNVector3(.pi / 3, 0, Float(i) * 0.5)
    }
    sparks.isHidden = true
    return root
  }

  func flash(target: String) {
    guard let node = kartNodes[target] else { return }
    let flash = ball(
      3, UIColor.systemYellow.withAlphaComponent(0.7), SCNVector3(0, 2, 0), parent: node)
    flash.runAction(.sequence([.fadeOut(duration: 0.45), .removeFromParentNode()]))
  }

  func update(state: RaceState?, playerID: String, time: Double) {
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
        at: SCNVector3(baseX, 1.9, baseZ), up: SCNVector3(0, 1, 0),
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
        tag.isHidden = p.id == playerID
        node.addChildNode(tag)
      }
      let factor: Float = 0.42
      node.position.x += (Float(p.x) - node.position.x) * factor
      node.position.z += (Float(p.z) - node.position.z) * factor
      node.position.y = 0.15 + Float(sin(time * 17) * min(0.05, p.speed / 400))
      let turn = wrappedAngle(p.heading - Double(node.eulerAngles.y))
      node.eulerAngles.y += Float(turn) * factor
      node.eulerAngles.z =
        p.drifting ? Float(sin(time * 6) * 0.04) - Float(turn) * 0.9 : -Float(turn) * 0.6
      for flame in node.childNodes where flame.name == "flame" {
        flame.isHidden = p.boost <= 0
        flame.scale.y = 0.7 + Float(sin(time * 45) * 0.3)
      }
      node.childNode(withName: "shield", recursively: false)?.isHidden = p.shield <= 0
      let sparks = node.childNode(withName: "sparks", recursively: false)
      sparks?.isHidden = !p.drifting
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
      sparks?.scale = SCNVector3(1, 0.7 + Float(tier) * 0.35, 1 + Float(tier) * 0.25)
      for spark in sparks?.childNodes ?? [] {
        spark.geometry?.firstMaterial?.emission.contents = sparkColor
        spark.geometry?.firstMaterial?.diffuse.contents = sparkColor
        spark.opacity = 0.5 + CGFloat(abs(sin(time * 32 + Double(spark.position.z)))) * 0.5
      }
      node.opacity = p.connected ? 1 : 0.35
      if p.stun > 0 { node.eulerAngles.z = Float(sin(time * 32) * 0.2) }
    }
    if state.hazards.count != lastHazards {
      for node in hazardsRoot.childNodes { node.removeFromParentNode() }
      for h in state.hazards {
        let gum = ball(1.1, .systemPink, SCNVector3(h.x, 0.3, h.z), parent: hazardsRoot)
        gum.scale.y = 0.35
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
      for i in 0..<90 {
        let confetti = box(
          0.23, 0.5, 0.05, colors[i % 3],
          SCNVector3(me.x + Double(i % 15 - 7), Double(i % 12 + 5), me.z + Double(i % 9 - 4)),
          parent: root, bevel: 0)
        confetti.runAction(
          .repeatForever(
            .group([
              .rotateBy(x: 2, y: 3, z: 1, duration: 2),
              .sequence([
                .moveBy(x: 0, y: -8, z: 0, duration: 3), .moveBy(x: 0, y: 8, z: 0, duration: 0),
              ]),
            ])))
      }
    }
    if state.phase != "results" {
      courseRoot.childNode(withName: "confetti", recursively: false)?.removeFromParentNode()
    }
  }
}
