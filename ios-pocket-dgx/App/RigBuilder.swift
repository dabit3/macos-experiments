import RealityKit
import UIKit
import simd

/// Handles to the animated parts of a built rig.
final class RigParts {
  let root = Entity()
  var fans: [Entity] = []
  var leds: [ModelEntity] = []
  var accents: [ModelEntity] = []
  var hologram: ModelEntity?
  var hologramPivot: Entity?
  var hologramRing: ModelEntity?
  var floorHalo: ModelEntity?
  var glowLight: PointLight?
  var height: Float = 2
  /// Largest dimension, used to frame the showroom camera.
  var extent: Float = 2
  var hologramBaseY: Float = 2.2
}

/// Builds both toys from primitives and a couple of custom meshes. Life-size
/// dimensions in meters, origin at floor center, +Z faces the viewer.
enum RigBuilder {
  static let pcbTexture = ProceduralTextures.pcb()
  static let brushedTexture = ProceduralTextures.brushed()
  static let grilleTexture = ProceduralTextures.grille()
  static let haloTexture = ProceduralTextures.halo()
  static let fanMesh = Meshes.fan(radius: 1, blades: 7)

  static let green = UIColor(red: 0.463, green: 0.725, blue: 0, alpha: 1)
  static let mint = UIColor(red: 0.62, green: 0.95, blue: 0.35, alpha: 1)

  // MARK: Materials

  static func metal(
    _ tint: UIColor = UIColor(white: 0.5, alpha: 1), roughness: Float = 0.45, textured: Bool = true
  )
    -> PhysicallyBasedMaterial
  {
    var material = PhysicallyBasedMaterial()
    if textured, let texture = brushedTexture {
      material.baseColor = .init(tint: tint, texture: .init(texture))
    } else {
      material.baseColor = .init(tint: tint)
    }
    material.metallic = 0.85
    material.roughness = .init(floatLiteral: roughness)
    return material
  }

  static func matte(_ color: UIColor, roughness: Float = 0.8) -> PhysicallyBasedMaterial {
    var material = PhysicallyBasedMaterial()
    material.baseColor = .init(tint: color)
    material.metallic = 0.1
    material.roughness = .init(floatLiteral: roughness)
    return material
  }

  static func textured(_ texture: TextureResource?, tint: UIColor = .white, roughness: Float = 0.7)
    -> PhysicallyBasedMaterial
  {
    var material = PhysicallyBasedMaterial()
    if let texture {
      material.baseColor = .init(tint: tint, texture: .init(texture))
    } else {
      material.baseColor = .init(tint: tint)
    }
    material.roughness = .init(floatLiteral: roughness)
    material.metallic = 0.3
    return material
  }

  static func gold() -> PhysicallyBasedMaterial {
    var material = PhysicallyBasedMaterial()
    material.baseColor = .init(tint: UIColor(red: 0.9, green: 0.72, blue: 0.25, alpha: 1))
    material.metallic = 1.0
    material.roughness = .init(floatLiteral: 0.25)
    return material
  }

  /// LED emitter. `level` 0 = dark, 1 = full neon.
  static func led(level: Float, color: UIColor = green) -> UnlitMaterial {
    var material = UnlitMaterial()
    let dark = UIColor(red: 0.05, green: 0.09, blue: 0.03, alpha: 1)
    material.color = .init(tint: blend(dark, color, level))
    return material
  }

  static func blend(_ a: UIColor, _ b: UIColor, _ t: Float) -> UIColor {
    var ar: CGFloat = 0
    var ag: CGFloat = 0
    var ab: CGFloat = 0
    var aa: CGFloat = 0
    var br: CGFloat = 0
    var bg: CGFloat = 0
    var bb: CGFloat = 0
    var ba: CGFloat = 0
    a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
    b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
    let k = CGFloat(min(1, max(0, t)))
    return UIColor(
      red: ar + (br - ar) * k, green: ag + (bg - ag) * k, blue: ab + (bb - ab) * k, alpha: 1)
  }

  static func haloMaterial(alpha: Float) -> UnlitMaterial {
    var material = UnlitMaterial()
    if let haloTexture {
      material.color = .init(
        tint: UIColor(white: 1, alpha: CGFloat(alpha)), texture: .init(haloTexture))
    } else {
      material.color = .init(tint: green.withAlphaComponent(CGFloat(alpha)))
    }
    material.blending = .transparent(opacity: .init(floatLiteral: alpha))
    return material
  }

  // MARK: Builders

  static func build(_ kind: RigKind) -> RigParts {
    switch kind {
    case .rack: return buildRack()
    case .card: return buildCard()
    }
  }

  static func box(
    _ w: Float, _ h: Float, _ d: Float, _ material: RealityKit.Material, corner: Float = 0
  ) -> ModelEntity {
    ModelEntity(
      mesh: .generateBox(width: w, height: h, depth: d, cornerRadius: corner), materials: [material]
    )
  }

  static func buildRack() -> RigParts {
    let parts = RigParts()
    let width = Float(RackLayout.width)
    let height = Float(RackLayout.height)
    let depth = Float(RackLayout.depth)
    parts.height = height
    parts.extent = height
    parts.hologramBaseY = height + 0.25

    let cabinet = box(
      width, height, depth, metal(UIColor(white: 0.35, alpha: 1), roughness: 0.5), corner: 0.015)
    cabinet.position = [0, height / 2, -0.03]
    parts.root.addChild(cabinet)

    // Side panels with a chevron accent stripe.
    for side: Float in [-1, 1] {
      let panel = box(
        0.012, height * 0.96, depth * 0.94, matte(UIColor(white: 0.06, alpha: 1), roughness: 0.35))
      panel.position = [side * (width / 2 + 0.004), height / 2, -0.03]
      parts.root.addChild(panel)
      let stripe = ModelEntity(
        mesh: .generateBox(width: 0.006, height: height * 0.7, depth: 0.03),
        materials: [led(level: 0)])
      stripe.position = [side * (width / 2 + 0.012), height / 2, 0.1]
      parts.root.addChild(stripe)
      parts.accents.append(stripe)
    }

    // Top glow lip and base plinth.
    let lip = ModelEntity(
      mesh: .generateBox(width: width * 0.9, height: 0.012, depth: 0.02), materials: [led(level: 0)]
    )
    lip.position = [0, height + 0.006, depth / 2 - 0.05]
    parts.root.addChild(lip)
    parts.accents.append(lip)
    let plinth = box(
      width + 0.04, 0.05, depth + 0.02, matte(UIColor(white: 0.04, alpha: 1), roughness: 0.3))
    plinth.position = [0, 0.025, -0.03]
    parts.root.addChild(plinth)

    // Front rails.
    for side: Float in [-1, 1] {
      let rail = box(
        0.02, height * 0.9, 0.02, metal(UIColor(white: 0.25, alpha: 1), textured: false))
      rail.position = [side * (width / 2 - 0.02), height / 2, depth / 2 - 0.02]
      parts.root.addChild(rail)
    }

    // Blades: faceplate, grille, three fans, LED bar, status pips.
    let bladeHeight = Float(RackLayout.bladeHeight)
    let front = depth / 2 - 0.02
    for centerY in RackLayout.bladeCenters().map(Float.init) {
      let blade = box(
        width - 0.06, bladeHeight, 0.02, matte(UIColor(white: 0.12, alpha: 1), roughness: 0.6),
        corner: 0.004)
      blade.position = [0, centerY, front]
      parts.root.addChild(blade)
      let grille = ModelEntity(
        mesh: .generatePlane(width: width - 0.08, height: bladeHeight - 0.02),
        materials: [textured(grilleTexture)])
      grille.position = [0, centerY, front + 0.011]
      parts.root.addChild(grille)
      for centerX in RackLayout.fanCenters().map(Float.init) {
        let ring = ModelEntity(
          mesh: Meshes.ring(outer: 0.05, inner: 0.044, depth: 0.012),
          materials: [metal(UIColor(white: 0.6, alpha: 1), textured: false)])
        ring.position = [centerX, centerY + 0.005, front + 0.012]
        parts.root.addChild(ring)
        let fan = ModelEntity(
          mesh: fanMesh, materials: [matte(UIColor(white: 0.2, alpha: 1), roughness: 0.5)])
        fan.scale = [0.043, 0.043, 0.01]
        fan.position = [centerX, centerY + 0.005, front + 0.016]
        parts.root.addChild(fan)
        parts.fans.append(fan)
      }
      let bar = ModelEntity(
        mesh: .generateBox(width: width - 0.12, height: 0.008, depth: 0.006),
        materials: [led(level: 0)])
      bar.position = [0, centerY - bladeHeight / 2 + 0.012, front + 0.013]
      parts.root.addChild(bar)
      parts.leds.append(bar)
      for pip in 0..<3 {
        let dot = ModelEntity(
          mesh: .generateSphere(radius: 0.004),
          materials: [
            led(
              level: 0, color: pip == 2 ? UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 1) : green)
          ])
        if pip == 2 { dot.name = "amber" }
        dot.position = [
          width / 2 - 0.045 - Float(pip) * 0.012, centerY + bladeHeight / 2 - 0.016, front + 0.014,
        ]
        parts.root.addChild(dot)
        parts.leds.append(dot)
      }
    }

    addHologram(to: parts, width: width)
    addHalo(to: parts, radius: max(width, depth) * 0.9)
    return parts
  }

  static func buildCard() -> RigParts {
    let parts = RigParts()
    let length: Float = 1.2
    let height: Float = 0.45
    let thickness: Float = 0.02
    let baseY: Float = 0.06
    parts.height = height + baseY
    parts.extent = length * 1.05
    parts.hologramBaseY = height + baseY + 0.2

    // PCB board, standing on its PCIe fingers.
    let board = box(length, height, thickness, textured(pcbTexture, roughness: 0.6), corner: 0.01)
    board.position = [0, baseY + height / 2, 0]
    parts.root.addChild(board)
    let fingers = box(length * 0.55, baseY, thickness * 0.8, gold())
    fingers.position = [-length * 0.1, baseY / 2, 0]
    parts.root.addChild(fingers)
    for slot in 0..<24 {
      let gap = box(0.006, baseY * 0.9, thickness, matte(UIColor(white: 0.03, alpha: 1)))
      gap.position = [-length * 0.375 + Float(slot) * (length * 0.55 / 24), baseY / 2, 0]
      parts.root.addChild(gap)
    }

    // Shroud on the front, backplate on the back.
    let shroud = box(
      length * 0.98, height * 0.9, 0.11, metal(UIColor(white: 0.3, alpha: 1), roughness: 0.4),
      corner: 0.02)
    shroud.position = [0, baseY + height * 0.55, thickness / 2 + 0.055]
    parts.root.addChild(shroud)
    let backplate = box(
      length * 0.98, height * 0.9, 0.012, metal(UIColor(white: 0.22, alpha: 1), roughness: 0.35),
      corner: 0.01)
    backplate.position = [0, baseY + height * 0.55, -thickness / 2 - 0.006]
    parts.root.addChild(backplate)
    let backStripe = ModelEntity(
      mesh: .generateBox(width: length * 0.6, height: 0.02, depth: 0.006),
      materials: [led(level: 0)])
    backStripe.position = [0, baseY + height * 0.55, -thickness / 2 - 0.014]
    parts.root.addChild(backStripe)
    parts.accents.append(backStripe)

    // Bracket with slot cutouts.
    let bracket = box(
      0.015, height * 0.95, 0.08, metal(UIColor(white: 0.65, alpha: 1), textured: false))
    bracket.position = [-length / 2 - 0.008, baseY + height / 2, 0.04]
    parts.root.addChild(bracket)

    // Three big fans with rims plus top-edge accent bar.
    let frontZ = thickness / 2 + 0.11
    let fanRadius: Float = height * 0.36
    for index in 0..<3 {
      let x = -length * 0.31 + Float(index) * length * 0.31
      let ring = ModelEntity(
        mesh: Meshes.ring(outer: fanRadius + 0.012, inner: fanRadius, depth: 0.02),
        materials: [matte(UIColor(white: 0.08, alpha: 1), roughness: 0.4)])
      ring.position = [x, baseY + height * 0.55, frontZ]
      parts.root.addChild(ring)
      let glowRing = ModelEntity(
        mesh: Meshes.ring(outer: fanRadius + 0.008, inner: fanRadius + 0.003, depth: 0.022),
        materials: [led(level: 0)])
      glowRing.position = [x, baseY + height * 0.55, frontZ]
      parts.root.addChild(glowRing)
      parts.leds.append(glowRing)
      let fan = ModelEntity(
        mesh: fanMesh, materials: [matte(UIColor(white: 0.16, alpha: 1), roughness: 0.5)])
      fan.scale = [fanRadius * 0.92, fanRadius * 0.92, 0.03]
      fan.position = [x, baseY + height * 0.55, frontZ - 0.004]
      parts.root.addChild(fan)
      parts.fans.append(fan)
    }
    let topBar = ModelEntity(
      mesh: .generateBox(width: length * 0.7, height: 0.015, depth: 0.1), materials: [led(level: 0)]
    )
    topBar.position = [0.05, baseY + height * 0.55 + height * 0.45 + 0.008, thickness / 2 + 0.055]
    parts.root.addChild(topBar)
    parts.accents.append(topBar)

    // Power connector with a nervous amber LED.
    let connector = box(0.06, 0.03, 0.05, matte(UIColor(white: 0.05, alpha: 1), roughness: 0.4))
    connector.position = [length * 0.3, baseY + height + 0.015, 0.02]
    parts.root.addChild(connector)
    let connectorLed = ModelEntity(
      mesh: .generateSphere(radius: 0.006),
      materials: [led(level: 0, color: UIColor(red: 1, green: 0.62, blue: 0.16, alpha: 1))])
    connectorLed.name = "amber"
    connectorLed.position = [length * 0.3 + 0.035, baseY + height + 0.02, 0.02]
    parts.root.addChild(connectorLed)
    parts.leds.append(connectorLed)

    addHologram(to: parts, width: length)
    addHalo(to: parts, radius: length * 0.7)
    return parts
  }

  static func addHologram(to parts: RigParts, width: Float) {
    let ring = ModelEntity(
      mesh: .generatePlane(width: width * 1.1, depth: width * 1.1),
      materials: [haloMaterial(alpha: 0)])
    ring.position = [0, parts.hologramBaseY - 0.08, 0]
    parts.root.addChild(ring)
    parts.hologramRing = ring
    let pivot = Entity()
    pivot.position = [0, parts.hologramBaseY, 0]
    parts.root.addChild(pivot)
    parts.hologramPivot = pivot
    let text = ModelEntity(mesh: hologramMesh("STANDBY"), materials: [led(level: 0)])
    pivot.addChild(text)
    parts.hologram = text

    let light = PointLight()
    light.light.color = green
    light.light.intensity = 0
    light.light.attenuationRadius = 6
    light.position = [0, parts.height * 0.6, 0.8]
    parts.root.addChild(light)
    parts.glowLight = light
  }

  static func addHalo(to parts: RigParts, radius: Float) {
    let halo = ModelEntity(
      mesh: .generatePlane(width: radius * 2.4, depth: radius * 2.4),
      materials: [haloMaterial(alpha: 0)])
    halo.position = [0, 0.003, 0]
    parts.root.addChild(halo)
    parts.floorHalo = halo
  }

  /// Centered 3D text for the floating readout.
  static func hologramMesh(_ string: String) -> MeshResource {
    let mesh = MeshResource.generateText(
      string, extrusionDepth: 0.004, font: .systemFont(ofSize: 0.11, weight: .heavy),
      containerFrame: .zero, alignment: .center, lineBreakMode: .byClipping)
    return mesh
  }
}

/// Hand-built meshes that RealityKit does not ship on iOS 17.
enum Meshes {
  struct Builder {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []

    mutating func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
      let normal = normalize(cross(b - a, c - a))
      let base = UInt32(positions.count)
      positions += [a, b, c, d]
      normals += [normal, normal, normal, normal]
      indices += [base, base + 1, base + 2, base, base + 2, base + 3]
    }
    mutating func triangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
      let normal = normalize(cross(b - a, c - a))
      let base = UInt32(positions.count)
      positions += [a, b, c]
      normals += [normal, normal, normal]
      indices += [base, base + 1, base + 2]
    }
    func resource() -> MeshResource {
      var descriptor = MeshDescriptor(name: "custom")
      descriptor.positions = MeshBuffer(positions)
      descriptor.normals = MeshBuffer(normals)
      descriptor.primitives = .triangles(indices)
      return try! MeshResource.generate(from: [descriptor])
    }
  }

  /// Fan: unit radius, hub + twisted blades, spinning around +Z, depth 1.
  static func fan(radius: Float, blades: Int) -> MeshResource {
    var builder = Builder()
    let segments = 18
    let hub = radius * 0.3
    for index in 0..<segments {
      let a0 = Float(index) / Float(segments) * 2 * .pi
      let a1 = Float(index + 1) / Float(segments) * 2 * .pi
      let p0 = SIMD3<Float>(cos(a0) * hub, sin(a0) * hub, 0.5)
      let p1 = SIMD3<Float>(cos(a1) * hub, sin(a1) * hub, 0.5)
      builder.triangle(SIMD3(0, 0, 0.5), p0, p1)
      builder.quad(p0, SIMD3(p0.x, p0.y, -0.5), SIMD3(p1.x, p1.y, -0.5), p1)
    }
    for blade in 0..<blades {
      let angle = Float(blade) / Float(blades) * 2 * .pi
      let sweep: Float = 0.75
      let steps = 5
      for step in 0..<steps {
        let t0 = Float(step) / Float(steps)
        let t1 = Float(step + 1) / Float(steps)
        let r0 = hub * 0.9 + (radius - hub * 0.9) * t0
        let r1 = hub * 0.9 + (radius - hub * 0.9) * t1
        let width0 = 0.32 + 0.2 * t0
        let width1 = 0.32 + 0.2 * t1
        func point(_ r: Float, _ t: Float, _ w: Float, _ edge: Float) -> SIMD3<Float> {
          let theta = angle + sweep * t + edge * w * 0.5
          return SIMD3(cos(theta) * r, sin(theta) * r, edge * 0.35 * (1 - t * 0.5))
        }
        let a = point(r0, t0, width0, -1)
        let b = point(r1, t1, width1, -1)
        let c = point(r1, t1, width1, 1)
        let d = point(r0, t0, width0, 1)
        builder.quad(a, b, c, d)
        builder.quad(d, c, b, a)
      }
    }
    return builder.resource()
  }

  /// Flat ring facing +Z, centered at origin.
  static func ring(outer: Float, inner: Float, depth: Float) -> MeshResource {
    var builder = Builder()
    let segments = 40
    for index in 0..<segments {
      let a0 = Float(index) / Float(segments) * 2 * .pi
      let a1 = Float(index + 1) / Float(segments) * 2 * .pi
      let o0 = SIMD2<Float>(cos(a0), sin(a0)) * outer
      let o1 = SIMD2<Float>(cos(a1), sin(a1)) * outer
      let i0 = SIMD2<Float>(cos(a0), sin(a0)) * inner
      let i1 = SIMD2<Float>(cos(a1), sin(a1)) * inner
      let z = depth / 2
      builder.quad(SIMD3(i0, z), SIMD3(o0, z), SIMD3(o1, z), SIMD3(i1, z))
      builder.quad(SIMD3(i1, -z), SIMD3(o1, -z), SIMD3(o0, -z), SIMD3(i0, -z))
      builder.quad(SIMD3(o0, z), SIMD3(o0, -z), SIMD3(o1, -z), SIMD3(o1, z))
      builder.quad(SIMD3(i1, z), SIMD3(i1, -z), SIMD3(i0, -z), SIMD3(i0, z))
    }
    return builder.resource()
  }
}
