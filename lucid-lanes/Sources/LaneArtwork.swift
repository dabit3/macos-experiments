import SceneKit
import SwiftUI
import UIKit

enum Dream {
    static let ink = Color(red: 0.035, green: 0.085, blue: 0.12)
    static let velvet = Color(red: 0.075, green: 0.16, blue: 0.19)
    static let lavender = Color(red: 0.72, green: 0.76, blue: 0.79)
    static let peach = Color(red: 0.91, green: 0.70, blue: 0.44)
    static let cream = Color(red: 0.96, green: 0.92, blue: 0.83)
    static let mint = Color(red: 0.63, green: 0.89, blue: 0.81)
    static let muted = Color(red: 0.53, green: 0.64, blue: 0.66)

    static func display(_ size: CGFloat) -> Font { .custom("Didot", size: size) }
    static func label(_ size: CGFloat = 10) -> Font { .custom("AvenirNext-DemiBold", size: size) }
}

struct LaneArtwork: UIViewRepresentable {
    @ObservedObject var model: GameModel
    var hero = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> LaneStage { LaneStage() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.camera
        view.backgroundColor = UIColor(Dream.ink)
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.update(model: model, hero: hero, reduceMotion: reduceMotion, size: view.bounds.size)
    }
}

@MainActor
final class LaneStage {
    let scene = SCNScene()
    let camera = SCNNode()
    private let ball = SCNNode()
    private let gateRoot = SCNNode()
    private var pinNodes: [SCNNode] = []
    private var guides: [SCNNode] = []
    private var trails: [SCNNode] = []
    private var sparks: [SCNNode] = []
    private var gates: [(portal: SCNNode, left: SCNNode, right: SCNNode)] = []
    private var laneID = -1
    private var lastSize = CGSize.zero
    private var lastHero = false
    private let brass = LaneStage.material(UIColor(Dream.peach), metal: 0.78, roughness: 0.25)
    private let stone = LaneStage.material(UIColor(red: 0.82, green: 0.48, blue: 0.37, alpha: 1), roughness: 0.4)
    private let porcelain = LaneStage.material(UIColor(red: 0.75, green: 0.78, blue: 0.75, alpha: 1), roughness: 0.34)
    private let dark = LaneStage.material(UIColor(Dream.ink), roughness: 0.6)
    private let glow = LaneStage.material(UIColor(Dream.mint), emission: 0.8)

    init() {
        scene.background.contents = UIColor(Dream.ink)
        scene.fogColor = UIColor(Dream.ink)
        scene.fogStartDistance = 18
        scene.fogEndDistance = 32
        scene.lightingEnvironment.contents = Self.environment()
        scene.lightingEnvironment.intensity = 0.7
        camera.camera = SCNCamera()
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 60
        camera.camera?.wantsHDR = true
        camera.camera?.exposureOffset = -0.1
        camera.camera?.bloomIntensity = 0.15
        camera.camera?.bloomThreshold = 1.8
        camera.camera?.bloomBlurRadius = 7
        camera.camera?.vignettingIntensity = 0.35
        scene.rootNode.addChildNode(camera)
        scene.rootNode.addChildNode(gateRoot)
        buildRoom()
        buildPins()
        buildBall()
        for i in 0..<28 {
            let dot = node(SCNSphere(radius: 0.026), material: glow)
            guides.append(dot)
            scene.rootNode.addChildNode(dot)
            let trail = node(SCNCylinder(radius: 0.09, height: 0.009), material: glow)
            trails.append(trail)
            scene.rootNode.addChildNode(trail)
            let spark = node(
                SCNBox(width: 0.024, height: 0.065, length: 0.01, chamferRadius: 0), material: i % 2 == 0 ? brass : glow
            )
            sparks.append(spark)
            scene.rootNode.addChildNode(spark)
        }
    }

    func update(model: GameModel, hero: Bool, reduceMotion: Bool, size: CGSize) {
        if size != lastSize || hero != lastHero {
            let aspect = size.width / max(1, size.height)
            camera.camera?.projectionDirection = .horizontal
            camera.camera?.fieldOfView = hero ? 40 : 38
            camera.position =
                hero ? SCNVector3(3.2, 5.4, 10.8) : SCNVector3(0, aspect > 1 ? 7.3 : 4.8, aspect > 1 ? 11.2 : 9.4)
            camera.look(at: hero ? SCNVector3(0, 0.5, -0.3) : SCNVector3(0, 0, -1.5))
            lastSize = size
            lastHero = hero
        }
        let desiredLane = hero ? -2 : model.selectedLane
        if desiredLane != laneID {
            buildGates(hero ? [] : model.lane.gates)
            laneID = desiredLane
        }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        let pins = hero ? BowlingPhysics.rack() : model.physics.pins
        for (id, pinNode) in pinNodes.enumerated() {
            guard let pin = pins.first(where: { $0.id == id }) else {
                pinNode.isHidden = true
                continue
            }
            pinNode.isHidden = false
            pinNode.position = position(pin.x, pin.y, height: 0.02)
            pinNode.eulerAngles = SCNVector3(-pin.fall * 1.2, 0, (pin.vx < 0 ? -1 : 1) * pin.fall * 1.1)
            pinNode.opacity = max(0.2, 1 - max(0, pin.y - 9) * 0.3)
        }
        let state = hero ? Ball(x: 0.1, y: 1) : model.physics.ball
        ball.position = position(state.x, state.y, height: model.physics.gutter && !hero ? 0.13 : 0.245)
        ball.eulerAngles = SCNVector3(hero ? model.time * 0.12 : -state.y * 2.5, 0, -state.x)
        ball.isHidden = state.y > 10
        for (i, gate) in model.lane.gates.enumerated() where i < gates.count {
            let opening = gate.opening(at: model.time)
            gates[i].portal.position = position((opening.lowerBound + opening.upperBound) / 2, gate.y)
            let leftWidth = max(0.01, (opening.lowerBound + 1.12) * 1.6)
            let rightWidth = max(0.01, (1.12 - opening.upperBound) * 1.6)
            gates[i].left.scale.x = Float(leftWidth)
            gates[i].left.position = position(-1.12 + leftWidth / 3.2, gate.y, height: 0.08)
            gates[i].right.scale.x = Float(rightWidth)
            gates[i].right.position = position(1.12 - rightWidth / 3.2, gate.y, height: 0.08)
        }
        for i in guides.indices {
            let t = Double(i + 1) / Double(guides.count) * 0.78
            let x = model.aim * 1.7 * t + model.curve * BowlingPhysics.curveAcceleration / 2 * t * t
            let y = 0.35 + (3.5 + model.power * 3) * t
            guides[i].position = position(x, y, height: 0.045)
            guides[i].opacity = 0.8 - Double(i) / 55
            guides[i].isHidden = hero || model.phase != "ready" || abs(x) > 0.92
            trails[i].isHidden = hero || reduceMotion || i >= model.physics.trail.count
            if i < model.physics.trail.count {
                let point = model.physics.trail[i]
                trails[i].position = position(point.0, point.1, height: 0.025)
                trails[i].opacity = Double(i) / 85
            }
            sparks[i].isHidden = hero || reduceMotion || model.phase != "settling"
            let angle = Double(i) * 2.4 + model.time * 0.4
            sparks[i].position = position(
                cos(angle) * 0.85, 7.6 + sin(angle) * 0.7, height: 0.35 + Double(i % 7) * 0.16)
            sparks[i].eulerAngles = SCNVector3(angle, model.time, angle)
        }
        SCNTransaction.commit()
    }

    private func buildRoom() {
        let floorMaterial = Self.material(.white, metal: 0.25, roughness: 0.23)
        floorMaterial.diffuse.contents = Self.terrazzo()
        floorMaterial.diffuse.wrapS = .repeat
        floorMaterial.diffuse.wrapT = .repeat
        floorMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(1, 4, 1)
        addBox(width: 3.2, height: 0.18, length: 13, at: SCNVector3(0, -0.1, -1), material: floorMaterial)
        addBox(width: 18, height: 0.3, length: 28, at: SCNVector3(0, -0.4, -4), material: dark)
        for side in [-1.0, 1.0] {
            let chrome = Self.material(
                UIColor(red: 0.27, green: 0.41, blue: 0.46, alpha: 1), metal: 0.85, roughness: 0.16)
            addBox(width: 0.3, height: 0.09, length: 13, at: SCNVector3(side * 1.77, -0.07, -1), material: chrome)
            addBox(width: 0.075, height: 0.16, length: 13, at: SCNVector3(side * 1.96, 0.02, -1), material: brass)
            addBox(width: 0.018, height: 0.018, length: 13, at: SCNVector3(side * 1.62, 0.014, -1), material: glow)
            addBox(width: 0.9, height: 0.22, length: 18, at: SCNVector3(side * 2.5, -0.1, -3), material: dark)
            for z in stride(from: -8.0, through: 5, by: 2.5) {
                for j in 0..<5 {
                    addBox(
                        width: 0.045, height: 3.4, length: 0.07,
                        at: SCNVector3(side * (3.05 + Double(j) * 0.055), 1.6, z), material: j == 0 ? brass : dark)
                }
                addBox(
                    width: 0.12, height: 0.6, length: 0.12, at: SCNVector3(side * 2.96, 1.65, z),
                    material: Self.material(UIColor(Dream.cream), emission: 0.45))
                let sconce = SCNNode()
                sconce.light = SCNLight()
                sconce.light?.type = .omni
                sconce.light?.color = UIColor(Dream.peach)
                sconce.light?.intensity = 40
                sconce.light?.attenuationStartDistance = 0.1
                sconce.light?.attenuationEndDistance = 3
                sconce.position = SCNVector3(side * 2.8, 1.8, z)
                scene.rootNode.addChildNode(sconce)
            }
        }
        for depth in [9.5, 6.0, 2.0] {
            let arch = portal(width: 5.9, height: 4.6, thickness: 0.23, material: stone)
            arch.position = position(0, depth, height: -0.12)
            scene.rootNode.addChildNode(arch)
        }
        let endWall = node(SCNBox(width: 11, height: 8, length: 0.4, chamferRadius: 0), material: dark)
        endWall.position = SCNVector3(0, 2, -8.9)
        scene.rootNode.addChildNode(endWall)
        let fan = node(SCNTorus(ringRadius: 0.57, pipeRadius: 0.012), material: brass)
        fan.eulerAngles.x = .pi / 2
        fan.position = SCNVector3(0, 2.65, -8.65)
        scene.rootNode.addChildNode(fan)
        for i in 0..<17 {
            let ray = node(SCNBox(width: 0.012, height: 0.45, length: 0.016, chamferRadius: 0), material: brass)
            let angle = Double(i) / 16 * .pi
            ray.position = SCNVector3(cos(angle) * 0.89, 2.65 + sin(angle) * 0.89, -8.65)
            ray.eulerAngles.z = Float(angle - .pi / 2)
            scene.rootNode.addChildNode(ray)
        }
        let lettering = SCNText(string: "LL", extrusionDepth: 0.012)
        lettering.font = UIFont(name: "Didot", size: 1)
        lettering.flatness = 0.1
        let sign = node(lettering, material: brass)
        let bounds = sign.boundingBox
        sign.pivot = SCNMatrix4MakeTranslation((bounds.min.x + bounds.max.x) / 2, 0, 0)
        sign.scale = SCNVector3(0.55, 0.55, 0.55)
        sign.position = SCNVector3(0, 2.38, -8.55)
        scene.rootNode.addChildNode(sign)
        for x in [-0.48, -0.24, 0, 0.24, 0.48] {
            let diamond = node(SCNBox(width: 0.052, height: 0.004, length: 0.12, chamferRadius: 0.005), material: brass)
            diamond.position = position(x, 2.1)
            diamond.eulerAngles.y = .pi / 4
            scene.rootNode.addChildNode(diamond)
        }
        addBox(width: 3.18, height: 0.008, length: 0.035, at: position(0, 0), material: brass)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(red: 0.64, green: 0.75, blue: 0.92, alpha: 1)
        ambient.light?.intensity = 200
        scene.rootNode.addChildNode(ambient)
        for (z, intensity) in [(-5.0, 650.0), (1.0, 500.0), (5.5, 350.0)] {
            let light = SCNNode()
            light.light = SCNLight()
            light.light?.type = .spot
            light.light?.color = UIColor(red: 1, green: 0.85, blue: 0.69, alpha: 1)
            light.light?.intensity = CGFloat(intensity)
            light.light?.spotInnerAngle = 38
            light.light?.spotOuterAngle = 85
            light.light?.castsShadow = z == -5
            light.light?.shadowRadius = 4
            light.light?.shadowColor = UIColor.black.withAlphaComponent(0.65)
            light.light?.shadowMapSize = CGSize(width: 1024, height: 1024)
            light.position = SCNVector3(-1.2, 5.2, z)
            light.look(at: SCNVector3(0, 0, z - 0.5))
            scene.rootNode.addChildNode(light)
        }
    }

    private func buildPins() {
        let geometry = Self.pinGeometry()
        geometry.materials = [porcelain]
        let stripeMaterial = Self.material(UIColor(red: 0.48, green: 0.12, blue: 0.11, alpha: 1), roughness: 0.4)
        for id in 0..<10 {
            let pin = SCNNode(geometry: geometry)
            pin.name = "pin-\(id)"
            for height in [0.57, 0.62] {
                let stripe = node(SCNTorus(ringRadius: 0.079, pipeRadius: 0.018), material: stripeMaterial)
                stripe.position.y = Float(height)
                pin.addChildNode(stripe)
            }
            pinNodes.append(pin)
            scene.rootNode.addChildNode(pin)
        }
    }

    private func buildBall() {
        let lacquer = Self.material(UIColor(Dream.mint), metal: 0.4, roughness: 0.12)
        lacquer.diffuse.contents = Self.ballTexture()
        ball.geometry = SCNSphere(radius: 0.235)
        ball.name = "ball"
        ball.geometry?.firstMaterial = lacquer
        for point in [
            SCNVector3(-0.063, 0.16, 0.155), SCNVector3(0.037, 0.18, 0.145), SCNVector3(-0.003, 0.105, 0.204),
        ] {
            let hole = node(SCNSphere(radius: 0.033), material: dark)
            hole.position = point
            ball.addChildNode(hole)
        }
        scene.rootNode.addChildNode(ball)
    }

    private func buildGates(_ definitions: [Gate]) {
        for child in gateRoot.childNodes { child.removeFromParentNode() }
        gates = []
        for gate in definitions {
            let arch = portal(
                width: gate.width * 1.6, height: 1.5 + gate.width * 0.35, thickness: 0.13, material: stone)
            let left = node(SCNBox(width: 1, height: 0.16, length: 0.22, chamferRadius: 0.015), material: brass)
            let right = node(SCNBox(width: 1, height: 0.16, length: 0.22, chamferRadius: 0.015), material: brass)
            for part in [arch, left, right] { gateRoot.addChildNode(part) }
            gates.append((arch, left, right))
        }
    }

    private func portal(width: Double, height: Double, thickness: Double, material: SCNMaterial) -> SCNNode {
        let path = UIBezierPath()
        path.flatness = 0.005
        let radius = width / 2
        let center = CGPoint(x: 0, y: height - radius)
        path.move(to: CGPoint(x: -radius - thickness, y: 0))
        path.addLine(to: CGPoint(x: -radius - thickness, y: center.y))
        path.addArc(withCenter: center, radius: radius + thickness, startAngle: .pi, endAngle: 0, clockwise: false)
        path.addLine(to: CGPoint(x: radius + thickness, y: 0))
        path.addLine(to: CGPoint(x: radius, y: 0))
        path.addLine(to: CGPoint(x: radius, y: center.y))
        path.addArc(withCenter: center, radius: radius, startAngle: 0, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: -radius, y: 0))
        path.close()
        let shape = SCNShape(path: path, extrusionDepth: 0.28)
        shape.chamferRadius = 0.025
        let arch = node(shape, material: material)
        let trim = SCNShape(path: path, extrusionDepth: 0.015)
        let rim = node(trim, material: brass)
        rim.scale = SCNVector3(1.015, 1.005, 1)
        rim.position.z = -0.12
        arch.addChildNode(rim)
        return arch
    }

    private func position(_ x: Double, _ y: Double, height: Double = 0.01) -> SCNVector3 {
        SCNVector3(x * 1.6, height, 4.5 - y * 1.3)
    }

    private func node(_ geometry: SCNGeometry, material: SCNMaterial) -> SCNNode {
        geometry.firstMaterial = material
        return SCNNode(geometry: geometry)
    }

    private func addBox(width: CGFloat, height: CGFloat, length: CGFloat, at point: SCNVector3, material: SCNMaterial) {
        let box = node(
            SCNBox(width: width, height: height, length: length, chamferRadius: min(0.025, height / 4)),
            material: material)
        box.position = point
        scene.rootNode.addChildNode(box)
    }

    private static func material(_ color: UIColor, metal: CGFloat = 0, roughness: CGFloat = 0.3, emission: CGFloat = 0)
        -> SCNMaterial
    {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.metalness.contents = metal
        material.roughness.contents = roughness
        if emission > 0 {
            material.emission.contents = color
            material.emission.intensity = emission
        }
        return material
    }

    private static func environment() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 512, height: 256)).image { renderer in
            let colors = [UIColor(Dream.ink), UIColor(Dream.lavender), UIColor(Dream.cream), UIColor(Dream.velvet)]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray,
                locations: [0, 0.35, 0.47, 1])!
            renderer.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
        }
    }

    private static func terrazzo() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 768, height: 768), format: format).image { renderer in
            let context = renderer.cgContext
            UIColor(red: 0.42, green: 0.43, blue: 0.54, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 768, height: 768))
            var seed: UInt64 = 81
            func random() -> CGFloat {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1
                return CGFloat((seed >> 33) % 10000) / 10000
            }
            let colors = [UIColor(Dream.cream), UIColor(Dream.ink), UIColor(Dream.peach), UIColor(Dream.lavender)]
            for i in 0..<5200 {
                let x = random() * 768
                let y = random() * 768
                let radius = 0.4 + random() * 3.5
                colors[i % colors.count].withAlphaComponent(0.12 + random() * 0.23).setFill()
                context.beginPath()
                context.move(to: CGPoint(x: x, y: y))
                context.addLine(to: CGPoint(x: x + radius, y: y - radius * 0.2))
                context.addLine(to: CGPoint(x: x + radius * 1.4, y: y + radius * 0.8))
                context.addLine(to: CGPoint(x: x - radius * 0.4, y: y + radius))
                context.closePath()
                context.fillPath()
            }
        }
    }

    private static func ballTexture() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 512, height: 256), format: format).image { renderer in
            for y in 0..<256 {
                for x in stride(from: 0, to: 512, by: 2) {
                    let wave = sin(Double(x) * 0.06 + sin(Double(y) * 0.032) * 3) * 0.5 + 0.5
                    UIColor(red: 0.12 + wave * 0.35, green: 0.42 + wave * 0.4, blue: 0.39 + wave * 0.36, alpha: 1)
                        .setFill()
                    renderer.fill(CGRect(x: x, y: y, width: 2, height: 1))
                }
            }
        }
    }

    private static func pinGeometry() -> SCNGeometry {
        let profile: [(Float, Float)] = [
            (0, 0.125), (0.03, 0.16), (0.1, 0.185), (0.2, 0.19), (0.3, 0.16), (0.4, 0.11), (0.5, 0.071), (0.59, 0.065),
            (0.65, 0.083), (0.71, 0.107), (0.77, 0.105), (0.82, 0.075), (0.85, 0),
        ]
        let segments = 32
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [Int32] = []
        for (row, point) in profile.enumerated() {
            let before = profile[max(0, row - 1)]
            let after = profile[min(profile.count - 1, row + 1)]
            let slope = (after.1 - before.1) / max(0.01, after.0 - before.0)
            let length = sqrt(1 + slope * slope)
            for column in 0...segments {
                let angle = Float(column) / Float(segments) * .pi * 2
                vertices.append(SCNVector3(cos(angle) * point.1, point.0, sin(angle) * point.1))
                normals.append(SCNVector3(cos(angle) / length, -slope / length, sin(angle) / length))
                if row < profile.count - 1 && column < segments {
                    let a = Int32(row * (segments + 1) + column)
                    let b = a + Int32(segments + 1)
                    indices += [a, b, a + 1, a + 1, b, b + 1]
                }
            }
        }
        return SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
    }
}
