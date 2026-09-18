import SceneKit
import SwiftUI
import UIKit

enum GlassContour {
  static let height = 3.6
  static let footHalfHeight = 0.06

  static func radius(_ profile: [Double], at fraction: Double) -> Double {
    guard profile.count > 1 else { return profile.first ?? 0 }
    let position = CraftRules.clamp(fraction) * Double(profile.count - 1)
    let index = min(profile.count - 2, Int(position))
    let t = position - Double(index)
    let slopes = CraftRules.contourTangents(profile)
    return (2 * t * t * t - 3 * t * t + 1) * profile[index]
      + (t * t * t - 2 * t * t + t) * slopes[index]
      + (-2 * t * t * t + 3 * t * t) * profile[index + 1]
      + (t * t * t - t * t) * slopes[index + 1]
  }

  static func geometry(profile: [Double], inside: Bool = false) -> SCNGeometry {
    let rows = 112
    let columns = 96
    var vertices: [SCNVector3] = []
    var normals: [SCNVector3] = []
    var coordinates: [CGPoint] = []
    var indices: [Int32] = []
    for row in 0...rows {
      let t = Double(row) / Double(rows)
      let radius = max(0.03, radius(profile, at: t) * 1.6 - (inside ? 0.065 : 0))
      let slope =
        (self.radius(profile, at: min(1, t + 0.001))
          - self.radius(profile, at: max(0, t - 0.001))) * 1.6
        / ((min(1, t + 0.001) - max(0, t - 0.001)) * height)
      let length = sqrt(1 + slope * slope)
      let sign = inside ? -1.0 : 1.0
      for column in 0...columns {
        let angle = Double(column) / Double(columns) * .pi * 2
        vertices.append(
          SCNVector3(radius * cos(angle), height * (0.5 - t), radius * sin(angle)))
        normals.append(
          SCNVector3(sign * cos(angle) / length, sign * slope / length, sign * sin(angle) / length))
        coordinates.append(CGPoint(x: Double(column) / Double(columns), y: t))
        if row < rows && column < columns {
          let a = Int32(row * (columns + 1) + column)
          let b = a + 1
          let c = a + Int32(columns + 1)
          let d = c + 1
          indices += inside ? [a, c, b, b, c, d] : [a, b, c, b, d, c]
        }
      }
    }
    return SCNGeometry(
      sources: [
        SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals),
        SCNGeometrySource(textureCoordinates: coordinates),
      ], elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
    )
  }
}

@MainActor
final class GlassStudio {
  let scene = SCNScene()
  let form = SCNNode()
  let camera = SCNNode()
  private let outside = SCNNode()
  private let inside = SCNNode()
  private let lip = SCNNode()
  private let foot = SCNNode()
  private let pedestal = SCNNode()
  private var profile: [Double] = []
  private var commission: Commission?
  private var molten = false
  private static let portraits = NSCache<NSString, UIImage>()
  private static let environment = makeEnvironment()

  init(profile: [Double], commission: Commission, molten: Bool = false, tracing: Bool = false) {
    scene.background.contents = UIColor.clear
    scene.lightingEnvironment.contents = Self.environment
    scene.lightingEnvironment.intensity = 0.65
    camera.camera = SCNCamera()
    camera.camera?.usesOrthographicProjection = true
    camera.camera?.orthographicScale = tracing ? 2.278481 : 2.72
    camera.camera?.zNear = 0.1
    camera.camera?.zFar = 30
    camera.camera?.wantsHDR = true
    camera.camera?.exposureOffset = tracing ? -0.9 : -0.65
    camera.camera?.bloomIntensity = molten ? 0.18 : 0
    camera.camera?.bloomThreshold = 1.2
    camera.position = tracing ? SCNVector3(0, 0, 9) : SCNVector3(0, 1.05, 9)
    camera.look(at: tracing ? SCNVector3Zero : SCNVector3(0, -0.12, 0))
    scene.rootNode.addChildNode(camera)
    scene.rootNode.addChildNode(form)
    for node in [outside, inside, lip, foot] { form.addChildNode(node) }
    form.eulerAngles.y = -0.45
    if tracing { form.position.y = 0.068354 }
    if !tracing {
      makePedestal()
      form.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 48)))
    }
    light(
      .directional, color: UIColor(red: 0.86, green: 0.95, blue: 1, alpha: 1),
      intensity: 420, at: SCNVector3(-3, 5, 5))
    light(
      .omni, color: UIColor(red: 0.43, green: 0.80, blue: 0.92, alpha: 1),
      intensity: 90, at: SCNVector3(3, 1, -2))
    light(
      .omni, color: UIColor(red: 1, green: 0.64, blue: 0.29, alpha: 1),
      intensity: 110, at: SCNVector3(-3, 0, -3))
    light(
      .ambient, color: UIColor(white: 0.5, alpha: 1),
      intensity: 70, at: SCNVector3Zero)
    update(profile: profile, commission: commission, molten: molten)
  }

  func update(profile: [Double], commission: Commission, molten: Bool) {
    guard self.profile != profile || self.commission != commission || self.molten != molten else {
      return
    }
    if self.profile != profile {
      self.profile = profile
      outside.geometry = GlassContour.geometry(profile: profile)
      inside.geometry = GlassContour.geometry(profile: profile, inside: true)
      let radius = (profile.first ?? 0.4) * 1.6
      lip.geometry = SCNTorus(ringRadius: radius - 0.028, pipeRadius: 0.033)
      lip.position.y = Float(GlassContour.height / 2)
      let base = SCNCylinder(
        radius: (profile.last ?? 0.4) * 1.6, height: GlassContour.footHalfHeight * 2)
      base.radialSegmentCount = 96
      foot.geometry = base
      foot.position.y = -Float(GlassContour.height / 2)
    }
    if self.commission != commission || self.molten != molten
      || outside.geometry?.firstMaterial == nil
    {
      self.commission = commission
      self.molten = molten
    }
    let material = Self.material(commission: commission, molten: molten)
    outside.geometry?.materials = [material]
    inside.geometry?.materials = [material]
    lip.geometry?.materials = [material]
    foot.geometry?.materials = [material]
    camera.camera?.bloomIntensity = molten ? 0.18 : 0
  }

  private func light(
    _ type: SCNLight.LightType, color: UIColor, intensity: CGFloat, at position: SCNVector3
  ) {
    let node = SCNNode()
    let light = SCNLight()
    light.type = type
    light.color = color
    light.intensity = intensity
    node.light = light
    node.position = position
    node.look(at: SCNVector3Zero)
    scene.rootNode.addChildNode(node)
  }

  private func makePedestal() {
    let stone = SCNMaterial()
    stone.lightingModel = .physicallyBased
    stone.diffuse.contents = UIColor(red: 0.09, green: 0.12, blue: 0.13, alpha: 1)
    stone.roughness.contents = 0.85
    stone.metalness.contents = 0
    let body = SCNCylinder(radius: 1.72, height: 0.32)
    body.radialSegmentCount = 128
    body.materials = [stone]
    pedestal.geometry = body
    pedestal.position.y = -2.025
    scene.rootNode.addChildNode(pedestal)
    let metal = SCNMaterial()
    metal.lightingModel = .physicallyBased
    metal.diffuse.contents = UIColor(red: 0.58, green: 0.43, blue: 0.23, alpha: 1)
    metal.metalness.contents = 0.8
    metal.roughness.contents = 0.28
    for y in [-1.875, -2.175] {
      let ring = SCNTorus(ringRadius: 1.715, pipeRadius: 0.009)
      ring.ringSegmentCount = 128
      ring.firstMaterial = metal
      let node = SCNNode(geometry: ring)
      node.position.y = Float(y)
      scene.rootNode.addChildNode(node)
    }
    let contact = SCNCylinder(radius: 1.1, height: 0.005)
    let shadowMaterial = SCNMaterial()
    shadowMaterial.diffuse.contents = UIColor.black.withAlphaComponent(0.35)
    shadowMaterial.lightingModel = .constant
    contact.materials = [shadowMaterial]
    let shadow = SCNNode(geometry: contact)
    shadow.position.y = -1.862
    scene.rootNode.addChildNode(shadow)
  }

  private static var materials: [String: SCNMaterial] = [:]

  private static func material(commission: Commission, molten: Bool) -> SCNMaterial {
    let key = "\(commission.rawValue)-\(molten)"
    if let cached = materials[key] { return cached }
    let material = SCNMaterial()
    material.lightingModel = .physicallyBased
    let texture = makeGlaze(commission: commission, molten: molten)
    material.diffuse.contents = texture
    material.diffuse.wrapS = .repeat
    material.metalness.contents = molten ? 0.08 : 0.22
    material.roughness.contents = molten ? 0.24 : 0.19
    material.fresnelExponent = 1.8
    material.transparency = 0.93
    if molten {
      material.emission.contents = texture
      material.emission.intensity = 0.65
    }
    materials[key] = material
    return material
  }

  private static func makeGlaze(commission: Commission, molten: Bool) -> UIImage {
    let size = CGSize(width: 1024, height: 1024)
    let colors: [UIColor]
    if molten {
      colors = [
        UIColor(red: 0.24, green: 0.025, blue: 0.01, alpha: 1),
        UIColor(red: 0.97, green: 0.20, blue: 0.015, alpha: 1),
        UIColor(red: 1, green: 0.72, blue: 0.17, alpha: 1),
        UIColor(red: 0.47, green: 0.065, blue: 0.018, alpha: 1),
      ]
    } else {
      switch commission {
      case .tide:
        colors = [
          UIColor(red: 0.035, green: 0.17, blue: 0.22, alpha: 1),
          UIColor(red: 0.10, green: 0.53, blue: 0.57, alpha: 1),
          UIColor(red: 0.38, green: 0.68, blue: 0.59, alpha: 1),
          UIColor(red: 0.11, green: 0.14, blue: 0.35, alpha: 1),
        ]
      case .bloom:
        colors = [
          UIColor(red: 0.16, green: 0.055, blue: 0.25, alpha: 1),
          UIColor(red: 0.59, green: 0.22, blue: 0.38, alpha: 1),
          UIColor(red: 0.78, green: 0.47, blue: 0.34, alpha: 1),
          UIColor(red: 0.23, green: 0.10, blue: 0.33, alpha: 1),
        ]
      case .spire:
        colors = [
          UIColor(red: 0.23, green: 0.06, blue: 0.015, alpha: 1),
          UIColor(red: 0.70, green: 0.31, blue: 0.08, alpha: 1),
          UIColor(red: 0.88, green: 0.63, blue: 0.24, alpha: 1),
          UIColor(red: 0.28, green: 0.10, blue: 0.13, alpha: 1),
        ]
      }
    }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { output in
      let context = output.cgContext
      let colorSpace = CGColorSpaceCreateDeviceRGB()
      if let gradient = CGGradient(
        colorsSpace: colorSpace, colors: colors.map(\.cgColor) as CFArray,
        locations: [0, 0.36, 0.68, 1]
      ) {
        context.drawLinearGradient(
          gradient, start: .zero, end: CGPoint(x: 180, y: 1024), options: [])
      }
      for line in 0..<64 {
        let offset = Double(line) * 25 - 250
        let path = UIBezierPath()
        path.move(to: CGPoint(x: offset, y: -100))
        path.addCurve(
          to: CGPoint(x: offset + 490, y: 1124),
          controlPoint1: CGPoint(x: offset + 650, y: 200),
          controlPoint2: CGPoint(x: offset - 180, y: 760))
        let color =
          line % 5 == 0
          ? UIColor(red: 0.94, green: 0.70, blue: 0.32, alpha: 0.62)
          : colors[(line + 1) % colors.count].withAlphaComponent(0.30)
        color.setStroke()
        path.lineWidth = line % 5 == 0 ? 2 : CGFloat(6 + line % 4 * 3)
        path.stroke()
      }
    }
  }

  private static func makeEnvironment() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 512), format: format).image {
      output in
      let context = output.cgContext
      UIColor(red: 0.12, green: 0.16, blue: 0.19, alpha: 1).setFill()
      context.fill(CGRect(x: 0, y: 0, width: 1024, height: 512))
      let panels: [(CGRect, UIColor)] = [
        (CGRect(x: 120, y: 65, width: 46, height: 300), UIColor(white: 1, alpha: 1)),
        (CGRect(x: 178, y: 65, width: 10, height: 300), UIColor(white: 0.8, alpha: 1)),
        (
          CGRect(x: 480, y: 160, width: 210, height: 120),
          UIColor(red: 0.34, green: 0.53, blue: 0.60, alpha: 1)
        ),
        (
          CGRect(x: 810, y: 100, width: 90, height: 220),
          UIColor(red: 1, green: 0.80, blue: 0.51, alpha: 1)
        ),
        (CGRect(x: 320, y: 10, width: 400, height: 25), UIColor(white: 0.85, alpha: 1)),
      ]
      for (rect, color) in panels {
        color.setFill()
        context.fill(rect)
      }
    }
  }

  static func portrait(profile: [Double], commission: Commission) -> UIImage {
    let key = "\(commission.rawValue):\(profile)" as NSString
    if let cached = portraits.object(forKey: key) { return cached }
    let studio = GlassStudio(profile: profile, commission: commission)
    studio.form.removeAllActions()
    let renderer = SCNRenderer(device: nil, options: nil)
    renderer.scene = studio.scene
    renderer.pointOfView = studio.camera
    let image = renderer.snapshot(
      atTime: 0, with: CGSize(width: 720, height: 880), antialiasingMode: .multisampling4X)
    portraits.countLimit = 28
    portraits.setObject(image, forKey: key)
    return image
  }
}

final class GlassViewport: SCNView {
  var studio: GlassStudio?
  var tracing = false

  override func layoutSubviews() {
    super.layoutSubviews()
    if tracing, bounds.height > 0 {
      studio?.form.scale.x = Float(bounds.width / bounds.height * 1.367089)
    }
  }
}

struct GlassDisplay: UIViewRepresentable {
  var profile: [Double]
  var commission: Commission
  var molten = false
  var paused = false
  var tracing = false

  func makeUIView(context: Context) -> GlassViewport {
    let view = GlassViewport()
    let studio = GlassStudio(
      profile: profile, commission: commission, molten: molten, tracing: tracing)
    view.studio = studio
    view.tracing = tracing
    view.scene = studio.scene
    view.pointOfView = studio.camera
    view.backgroundColor = .clear
    view.isOpaque = false
    view.antialiasingMode = .multisampling4X
    view.preferredFramesPerSecond = 30
    view.isUserInteractionEnabled = false
    view.accessibilityElementsHidden = true
    return view
  }

  func updateUIView(_ view: GlassViewport, context: Context) {
    view.studio?.update(profile: profile, commission: commission, molten: molten)
    view.scene?.isPaused = paused
    view.isPlaying = !paused
  }
}
