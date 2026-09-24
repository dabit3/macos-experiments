import SceneKit
import UIKit

/// A limited, saturated palette in the tradition of 8-bit console hardware.
enum ToyColor {
    static let mint = UIColor(red: 0.35, green: 0.85, blue: 0.33, alpha: 1)
    static let dark = UIColor(red: 0.05, green: 0.05, blue: 0.09, alpha: 1)
    static let navy = UIColor(red: 0.07, green: 0.09, blue: 0.42, alpha: 1)
    static let royal = UIColor(red: 0.13, green: 0.28, blue: 0.86, alpha: 1)
    static let yellow = UIColor(red: 0.99, green: 0.88, blue: 0.10, alpha: 1)
    static let coral = UIColor(red: 0.97, green: 0.24, blue: 0.09, alpha: 1)
    static let beak = UIColor(red: 0.98, green: 0.53, blue: 0.09, alpha: 1)
    static let cream = UIColor(red: 0.99, green: 0.99, blue: 0.99, alpha: 1)
    static let water = UIColor(red: 0.09, green: 0.45, blue: 0.97, alpha: 1)
    static let haze = UIColor(red: 0.36, green: 0.58, blue: 0.99, alpha: 1)
    static let meadowLight = UIColor(red: 0.43, green: 0.78, blue: 0.16, alpha: 1)
    static let meadowDeep = UIColor(red: 0.33, green: 0.69, blue: 0.13, alpha: 1)
    static let asphalt = UIColor(red: 0.36, green: 0.36, blue: 0.38, alpha: 1)
    static let curb = UIColor(red: 0.74, green: 0.74, blue: 0.74, alpha: 1)
    static let sand = UIColor(red: 0.95, green: 0.80, blue: 0.42, alpha: 1)
    static let bark = UIColor(red: 0.62, green: 0.36, blue: 0.09, alpha: 1)
    static let barkLight = UIColor(red: 0.86, green: 0.60, blue: 0.21, alpha: 1)
    static let leafDeep = UIColor(red: 0.0, green: 0.50, blue: 0.09, alpha: 1)
    static let leafMid = UIColor(red: 0.0, green: 0.66, blue: 0.12, alpha: 1)
    static let leafLight = UIColor(red: 0.35, green: 0.85, blue: 0.33, alpha: 1)
    static let sky = UIColor(red: 0.36, green: 0.58, blue: 0.99, alpha: 1)
    static let blossom = UIColor(red: 0.98, green: 0.60, blue: 0.75, alpha: 1)
    static let stone = UIColor(red: 0.74, green: 0.74, blue: 0.74, alpha: 1)

    static func lighten(_ color: UIColor) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 1
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return UIColor(
            red: red + (1 - red) * 0.3,
            green: green + (1 - green) * 0.3,
            blue: blue + (1 - blue) * 0.3,
            alpha: 1
        )
    }

    static func duck(_ plumage: Plumage) -> UIColor {
        [yellow, UIColor(red: 0.24, green: 0.86, blue: 0.68, alpha: 1),
         UIColor(red: 0.98, green: 0.47, blue: 0.62, alpha: 1),
         UIColor(red: 0.27, green: 0.28, blue: 0.68, alpha: 1)][plumage.rawValue]
    }
}

@MainActor
final class ToyWorld {
    let scene = SCNScene()
    let camera = SCNNode()
    private var duck = SCNNode()
    private var laneNodes: [Int: SCNNode] = [:]
    private var movingNodes: [Int: [SCNNode]] = [:]
    private var coins: [Int: SCNNode] = [:]
    private var cameraRow: Double = 1.5
    private var cameraX: Double = 0
    private var lastSeed: UInt64?
    private var lastPlumage: Plumage?
    private var lastDirection: Direction = .forward
    private var impactProgress = 0.0
    private var facing: Float = 0
    private var wasAirborne = false
    private var landingSquash = 0.0
    private var ripples: [(node: SCNNode, x: Float)] = []
    private let contactShadow = SCNNode()
    private let impactRing = SCNNode()

    init() {
        scene.background.contents = ToyColor.sky
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 7.2
        camera.camera?.zFar = 70
        camera.camera?.wantsHDR = false
        scene.rootNode.addChildNode(camera)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 720
        ambient.light?.color = UIColor.white
        scene.rootNode.addChildNode(ambient)
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 620
        sun.light?.color = UIColor.white
        sun.light?.castsShadow = true
        sun.light?.shadowMode = .deferred
        sun.light?.shadowRadius = 0
        sun.light?.shadowSampleCount = 1
        sun.light?.shadowColor = UIColor(red: 0, green: 0.05, blue: 0.2, alpha: 0.30)
        sun.light?.orthographicScale = 20
        sun.light?.shadowMapSize = CGSize(width: 1024, height: 1024)
        sun.eulerAngles = SCNVector3(-Float.pi / 3, -Float.pi / 4, 0)
        scene.rootNode.addChildNode(sun)
        let plane = SCNBox(width: 0.62, height: 0.01, length: 0.62, chamferRadius: 0)
        let shadowMaterial = SCNMaterial()
        shadowMaterial.diffuse.contents = ToyColor.dark.withAlphaComponent(0.42)
        shadowMaterial.lightingModel = .constant
        shadowMaterial.writesToDepthBuffer = false
        plane.materials = [shadowMaterial]
        contactShadow.geometry = plane
        scene.rootNode.addChildNode(contactShadow)
        let ring = SCNTorus(ringRadius: 0.45, pipeRadius: 0.05)
        ring.ringSegmentCount = 8
        ring.pipeSegmentCount = 4
        ring.materials = [material(ToyColor.cream)]
        impactRing.geometry = ring
        impactRing.isHidden = true
        scene.rootNode.addChildNode(impactRing)
    }

    func face(_ direction: Direction) {
        lastDirection = direction
    }

    func update(_ game: GameRules, plumage: Plumage, delta: Double, reducedMotion: Bool) {
        if lastSeed != game.course.seed {
            laneNodes.values.forEach { $0.removeFromParentNode() }
            laneNodes.removeAll()
            movingNodes.removeAll()
            coins.removeAll()
            ripples.removeAll()
            lastSeed = game.course.seed
            cameraRow = 1.5
            cameraX = game.state == .ready ? 0 : -0.8
            lastDirection = .forward
            impactProgress = 0
        }
        if lastPlumage != plumage {
            duck.removeFromParentNode()
            duck = makeDuck(plumage)
            duck.scale = SCNVector3(1.2, 1.2, 1.2)
            scene.rootNode.addChildNode(duck)
            lastPlumage = plumage
        }
        let start = max(-5, game.furthest - 10)
        for row in start ... game.furthest + 22 where laneNodes[row] == nil {
            addLane(game.course.lane(row))
        }
        for row in Array(laneNodes.keys) where row < start {
            laneNodes.removeValue(forKey: row)?.removeFromParentNode()
            movingNodes.removeValue(forKey: row)
            coins.removeValue(forKey: row)
            ripples.removeAll { $0.node.parent == nil }
        }
        let time = game.time
        for (row, nodes) in movingNodes {
            let lane = game.course.lane(row)
            for (node, x) in zip(nodes, lane.centers(at: time)) {
                node.position.x = Float(x)
                if lane.kind == .river, !reducedMotion {
                    node.position.y = frame(time * 1.4 + x * 0.3, frames: 2) * 0.03
                }
            }
        }
        if !reducedMotion {
            for (index, ripple) in ripples.enumerated() {
                let drift = frame(time * 0.8 + Double(index) * 0.37, frames: 3)
                ripple.node.position.x = ripple.x + drift * 0.12
                ripple.node.isHidden = frame(time * 0.8 + Double(index) * 0.53, frames: 4) == 3
            }
        }
        for (row, node) in coins {
            node.isHidden = game.collectedRows.contains(row)
            let spin: [Float] = [1, 0.6, 0.25, 0.6]
            node.scale.x = reducedMotion ? 1 : spin[Int(frame(time * 1.6, frames: 4))]
            node.position.y = 0.46 + (reducedMotion ? 0 : frame(time * 3 + Double(row), frames: 2) * 0.05)
        }
        let target = max(1.5, game.visibleRow + 1.9)
        cameraRow += (target - cameraRow) * min(1, delta * 5)
        let targetX = game.state == .ready ? 0 : max(-3.4, min(2, game.visibleX * 0.8 - 0.8))
        cameraX += (targetX - cameraX) * min(1, delta * 9)
        camera.position = SCNVector3(Float(6.8 + cameraX), 12.5, Float(10 - cameraRow))
        camera.look(at: SCNVector3(Float(cameraX), 0, Float(-cameraRow)))
        let airborne = game.hop != nil
        if wasAirborne, !airborne {
            landingSquash = 1
        }
        wasAirborne = airborne
        landingSquash = max(0, landingSquash - delta / 0.14)
        let idle = game.state == .ready ? Double(frame(time * 1.3, frames: 2)) * 0.03 : 0
        let hopHeight = Double(frame(game.height / 0.48 * 0.999, frames: 4)) / 3 * 0.48
        duck.position = SCNVector3(
            Float(game.visibleX),
            Float(hopHeight + 0.10 + (reducedMotion ? 0 : idle)),
            Float(-game.visibleRow)
        )
        let stretch = reducedMotion ? 0 : hopHeight / 0.48 * 0.10 - (landingSquash > 0 ? 0.14 : 0)
        duck.scale = SCNVector3(
            1.2 * Float(1 - stretch * 0.5),
            1.2 * Float(1 + stretch),
            1.2 * Float(1 - stretch * 0.5)
        )
        let angle: Float = switch lastDirection {
        case .forward: 0
        case .backward: .pi
        case .left: .pi / 2
        case .right: -.pi / 2
        }
        let wanted = game.state == .ready ? Float.pi * 0.86 : angle
        var gap = (wanted - facing).truncatingRemainder(dividingBy: 2 * .pi)
        if gap > .pi {
            gap -= 2 * .pi
        }
        if gap < -.pi {
            gap += 2 * .pi
        }
        facing += gap
        duck.eulerAngles.y = facing
        let onWater = game.course.lane(game.row).kind == .river
        contactShadow.position = SCNVector3(Float(game.visibleX), onWater ? 0.235 : 0.005, Float(-game.visibleRow))
        impactRing.isHidden = game.state != .finished || game.endReason == "A well-earned rest"
        if game.state == .finished {
            impactProgress = min(1, impactProgress + delta / 0.6)
            let splash = game.endReason.contains("splash")
            let flight = reducedMotion ? 0 : impactProgress * 2.2 - impactProgress * impactProgress * 2.6
            duck.eulerAngles.z = reducedMotion || impactProgress > 0.25 ? .pi : 0
            duck.position.y = Float(splash ? -impactProgress * 0.5 : 0.62 + flight)
            impactRing.position = SCNVector3(Float(game.visibleX), 0.09, Float(-game.visibleRow))
            let scale = Float(reducedMotion ? 1 : 0.6 + Double(frame(impactProgress, frames: 4)) * 0.5)
            impactRing.scale = SCNVector3(scale, scale, scale)
            impactRing.isHidden = impactRing.isHidden || impactProgress > 0.7
        } else {
            duck.eulerAngles.z = 0
        }
    }

    /// Snaps a continuous phase into a small number of discrete animation frames.
    private func frame(_ phase: Double, frames: Int) -> Float {
        Float(Int(floor(phase * Double(frames))) % frames)
    }

    private func material(_ color: UIColor) -> SCNMaterial {
        let result = SCNMaterial()
        result.diffuse.contents = color
        result.lightingModel = .lambert
        return result
    }

    @discardableResult
    private func box(
        _ parent: SCNNode, _ width: CGFloat, _ height: CGFloat, _ length: CGFloat,
        _ color: UIColor, _ x: Float = 0, _ y: Float = 0, _ z: Float = 0, bevel _: CGFloat = 0
    ) -> SCNNode {
        let geometry = SCNBox(width: width, height: height, length: length, chamferRadius: 0)
        geometry.materials = [material(color)]
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(x, y, z)
        parent.addChildNode(node)
        return node
    }

    @discardableResult
    private func cylinder(
        _ parent: SCNNode, radius: CGFloat, height: CGFloat, color: UIColor,
        x: Float = 0, y: Float = 0, z: Float = 0
    ) -> SCNNode {
        let geometry = SCNCylinder(radius: radius, height: height)
        geometry.radialSegmentCount = 8
        geometry.materials = [material(color)]
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(x, y, z)
        parent.addChildNode(node)
        return node
    }

    private func addLane(_ lane: Lane) {
        let root = SCNNode()
        root.position.z = -Float(lane.row)
        scene.rootNode.addChildNode(root)
        laneNodes[lane.row] = root
        switch lane.kind {
        case .meadow:
            var random = SeededRandom(seed: UInt64(bitPattern: Int64(lane.row)) &* 2_654_435_761)
            let green = lane.row % 2 == 0 ? ToyColor.meadowLight : ToyColor.meadowDeep
            box(root, 18, 0.30, 1, green, 0, -0.18)
            for column in [-5, -4, 4, 5] {
                switch (lane.row + column) % 4 {
                case 0: tree(root, x: Float(column), z: 0.05, variant: random.value(3))
                case 2: bush(root, x: Float(column), z: Float(random.value(3)) * 0.12 - 0.15)
                default: flowers(root, x: Float(column), z: Float(lane.row % 3) * 0.12 - 0.15)
                }
            }
            for _ in 0 ..< 2 {
                let x = Float(random.value(64)) / 10 - 3.2
                let z = Float(random.value(6)) / 10 - 0.3
                tuft(root, x: x, z: z)
            }
            if random.value(4) == 0 {
                pebble(root, x: Float(random.value(60)) / 10 - 3, z: Float(random.value(5)) / 10 - 0.25)
            }
            if lane.row % 5 == 0 {
                for x in [-3.8, 3.8] {
                    for z in [-0.35, 0.35] {
                        box(root, 0.09, 0.48, 0.09, ToyColor.cream, Float(x), 0.20, Float(z))
                    }
                    box(root, 0.07, 0.08, 0.84, ToyColor.cream, Float(x), 0.21)
                    box(root, 0.07, 0.08, 0.84, ToyColor.cream, Float(x), 0.37)
                }
            }
        case .road:
            box(root, 18, 0.24, 1, ToyColor.asphalt, 0, -0.18)
            for z: Float in [-0.47, 0.47] {
                box(root, 18, 0.05, 0.07, ToyColor.curb, 0, -0.05, z, bevel: 0.01)
            }
            for x in -9 ... 9 {
                box(root, 0.30, 0.008, 0.045, UIColor(white: 0.86, alpha: 1), Float(x), -0.055, 0.38, bevel: 0)
            }
            if lane.row % 7 == 3 {
                for x in -9 ... 9 {
                    box(root, 0.55, 0.008, 0.8, UIColor(white: 0.88, alpha: 0.85), Float(x) + 0.5, -0.056, 0, bevel: 0)
                }
            }
            movingNodes[lane.row] = lane.centers(at: 0).enumerated().map { index, _ in
                let car = makeCar(index: index + lane.row)
                car.eulerAngles.y = lane.speed < 0 ? .pi : 0
                root.addChildNode(car)
                return car
            }
        case .river:
            var random = SeededRandom(seed: UInt64(bitPattern: Int64(lane.row)) &* 40503)
            box(root, 18, 0.20, 1, ToyColor.water, 0, -0.24)
            for z: Float in [-0.49, 0.49] {
                box(root, 18, 0.10, 0.10, ToyColor.sand, 0, -0.12, z, bevel: 0.02)
            }
            for index in -12 ... 12 {
                let ripple = box(
                    root,
                    0.42,
                    0.008,
                    0.018,
                    UIColor(red: 0.64, green: 0.89, blue: 0.83, alpha: 1),
                    Float(index) * 0.71,
                    -0.134,
                    Float(index % 3) * 0.21,
                    bevel: 0
                )
                ripples.append((ripple, Float(index) * 0.71))
            }
            for _ in 0 ..< 3 {
                let x = Float(random.value(70)) / 10 - 3.5
                let z = Float(random.value(5)) / 10 - 0.25
                lilyPad(root, x: x, z: z, bloom: random.value(3) == 0)
            }
            for x: Float in [-4.2, 4.3] {
                for offset: Float in [-0.1, 0.08, 0.2] {
                    box(root, 0.03, 0.42, 0.03, ToyColor.leafDeep, x + offset, 0.06, offset * 0.8, bevel: 0.01)
                    box(root, 0.05, 0.11, 0.05, ToyColor.bark, x + offset, 0.28, offset * 0.8, bevel: 0.02)
                }
            }
            movingNodes[lane.row] = lane.centers(at: 0).map { _ in
                let log = SCNNode()
                let wood = cylinder(
                    log,
                    radius: 0.20,
                    height: lane.objectLength,
                    color: UIColor(red: 0.58, green: 0.37, blue: 0.25, alpha: 1),
                    y: 0.03
                )
                wood.eulerAngles.z = .pi / 2
                for x in [-1.54, 1.54] {
                    let end = cylinder(log, radius: 0.16, height: 0.015, color: UIColor(
                        red: 0.85, green: 0.66, blue: 0.43, alpha: 1
                    ), x: Float(x), y: 0.03)
                    end.eulerAngles.z = .pi / 2
                }
                for x in [-0.8, 0.1, 0.9] {
                    box(
                        log,
                        0.24,
                        0.018,
                        0.045,
                        UIColor(red: 0.73, green: 0.50, blue: 0.31, alpha: 1),
                        Float(x),
                        0.22,
                        0.015
                    )
                }
                for x in [-1.1, 0.5] {
                    let band = cylinder(log, radius: 0.205, height: 0.05, color: UIColor(
                        red: 0.48, green: 0.30, blue: 0.20, alpha: 1
                    ), x: Float(x), y: 0.03)
                    band.eulerAngles.z = .pi / 2
                }
                root.addChildNode(log)
                return log
            }
        }
        if let column = lane.coinColumn {
            let coin = SCNNode()
            box(coin, 0.30, 0.38, 0.08, ToyColor.yellow)
            box(coin, 0.22, 0.30, 0.09, ToyColor.beak)
            box(coin, 0.06, 0.18, 0.10, ToyColor.yellow)
            coin.position = SCNVector3(Float(column), 0.46, 0)
            root.addChildNode(coin)
            coins[lane.row] = coin
        }
    }

    private func makeCar(index: Int) -> SCNNode {
        let car = SCNNode()
        let colors = [
            ToyColor.coral,
            ToyColor.cream,
            ToyColor.royal,
            UIColor(red: 0.15, green: 0.72, blue: 0.62, alpha: 1),
            UIColor(red: 0.62, green: 0.13, blue: 0.75, alpha: 1),
        ]
        let color = colors[abs(index) % colors.count]
        let van = abs(index) % 4 == 3
        let glass = UIColor(red: 0.24, green: 0.74, blue: 0.99, alpha: 1)
        if van {
            box(car, 1.35, 0.30, 0.61, color, 0, 0.21, bevel: 0.07)
            box(car, 1.05, 0.34, 0.56, color, -0.12, 0.50, bevel: 0.06)
            box(car, 0.16, 0.20, 0.57, glass, 0.42, 0.52, bevel: 0.02)
            box(car, 0.34, 0.16, 0.57, glass, -0.20, 0.53, bevel: 0.02)
            box(car, 1.0, 0.03, 0.42, ToyColor.dark, -0.12, 0.69, bevel: 0.01)
        } else {
            box(car, 1.35, 0.27, 0.61, color, 0, 0.20, bevel: 0.07)
            box(car, 0.66, 0.26, 0.51, color, -0.10, 0.44, bevel: 0.06)
            box(car, 0.20, 0.18, 0.52, glass, 0.15, 0.45, bevel: 0.02)
            box(car, 0.22, 0.16, 0.52, glass, -0.18, 0.45, bevel: 0.02)
            box(car, 0.62, 0.03, 0.30, ToyColor.lighten(color), -0.10, 0.575, bevel: 0.01)
        }
        box(car, 1.30, 0.03, 0.62, UIColor(red: 0.20, green: 0.28, blue: 0.29, alpha: 1), 0, 0.075, bevel: 0.01)
        box(car, 0.10, 0.05, 0.60, ToyColor.dark, 0.66, 0.16, bevel: 0.01)
        box(car, 0.10, 0.05, 0.60, ToyColor.dark, -0.66, 0.16, bevel: 0.01)
        for z: Float in [-0.18, 0.18] {
            let lamp = box(car, 0.08, 0.07, 0.13, ToyColor.cream, 0.67, 0.24, z)
            lamp.geometry?.firstMaterial?.emission.contents = UIColor(red: 0.6, green: 0.56, blue: 0.4, alpha: 1)
            let tail = box(car, 0.05, 0.06, 0.12, ToyColor.coral, -0.67, 0.24, z)
            tail.geometry?.firstMaterial?.emission.contents = UIColor(red: 0.45, green: 0.08, blue: 0.05, alpha: 1)
        }
        for x: Float in [-0.43, 0.43] {
            for z: Float in [-0.31, 0.31] {
                let tire = cylinder(car, radius: 0.14, height: 0.08, color: ToyColor.dark, x: x, y: 0.09, z: z)
                tire.eulerAngles.x = .pi / 2
                let hub = cylinder(car, radius: 0.06, height: 0.09, color: ToyColor.cream, x: x, y: 0.09, z: z)
                hub.eulerAngles.x = .pi / 2
            }
        }
        return car
    }

    private func tree(_ parent: SCNNode, x: Float, z: Float, variant: Int) {
        let trunk = UIColor(red: 0.62, green: 0.44, blue: 0.29, alpha: 1)
        switch variant {
        case 0:
            box(parent, 0.17, 0.57, 0.17, trunk, x, 0.22, z)
            box(parent, 0.82, 0.67, 0.75, ToyColor.leafDeep, x, 0.73, z, bevel: 0.12)
            box(parent, 0.58, 0.44, 0.54, ToyColor.leafLight, x - 0.07, 1.09, z - 0.04, bevel: 0.10)
        case 1:
            box(parent, 0.15, 0.5, 0.15, trunk, x, 0.2, z)
            sphere(parent, radius: 0.44, color: ToyColor.leafMid, x: x, y: 0.72, z: z)
            sphere(parent, radius: 0.30, color: ToyColor.leafLight, x: x - 0.18, y: 0.98, z: z - 0.1)
            sphere(parent, radius: 0.26, color: ToyColor.leafDeep, x: x + 0.24, y: 0.62, z: z + 0.18)
        default:
            box(parent, 0.14, 0.4, 0.14, trunk, x, 0.16, z)
            cone(parent, bottom: 0.52, height: 0.62, color: ToyColor.leafDeep, x: x, y: 0.62, z: z)
            cone(parent, bottom: 0.40, height: 0.52, color: ToyColor.leafMid, x: x, y: 1.0, z: z)
            cone(parent, bottom: 0.26, height: 0.42, color: ToyColor.leafLight, x: x, y: 1.34, z: z)
        }
    }

    private func bush(_ parent: SCNNode, x: Float, z: Float) {
        sphere(parent, radius: 0.27, color: ToyColor.leafMid, x: x, y: 0.16, z: z)
        sphere(parent, radius: 0.20, color: ToyColor.leafLight, x: x + 0.22, y: 0.12, z: z + 0.1)
        sphere(parent, radius: 0.17, color: ToyColor.leafDeep, x: x - 0.22, y: 0.1, z: z - 0.08)
        for offset: Float in [-0.1, 0.12] {
            sphere(parent, radius: 0.045, color: ToyColor.blossom, x: x + offset, y: 0.38, z: z + offset * 0.5)
        }
    }

    private func tuft(_ parent: SCNNode, x: Float, z: Float) {
        for offset: Float in [-0.05, 0, 0.05] {
            box(
                parent,
                0.035,
                0.07 + CGFloat(abs(offset)),
                0.035,
                ToyColor.leafDeep,
                x + offset,
                0.02,
                z + offset * 0.4,
                bevel: 0.01
            )
        }
    }

    private func pebble(_ parent: SCNNode, x: Float, z: Float) {
        let node = sphere(parent, radius: 0.13, color: ToyColor.leafMid, x: x, y: -0.02, z: z)
        node.scale = SCNVector3(1.4, 0.6, 1)
    }

    private func lilyPad(_ parent: SCNNode, x: Float, z: Float, bloom: Bool) {
        cylinder(parent, radius: 0.24, height: 0.03, color: UIColor(
            red: 0.47, green: 0.74, blue: 0.48, alpha: 1
        ), x: x, y: -0.125, z: z)
        box(parent, 0.05, 0.036, 0.16, ToyColor.water, x + 0.1, -0.125, z - 0.14, bevel: 0)
        if bloom {
            sphere(parent, radius: 0.07, color: ToyColor.blossom, x: x - 0.05, y: -0.06, z: z + 0.04)
            sphere(parent, radius: 0.035, color: ToyColor.yellow, x: x - 0.05, y: -0.01, z: z + 0.04)
        }
    }

    @discardableResult
    private func sphere(_ parent: SCNNode, radius: CGFloat, color: UIColor, x: Float, y: Float, z: Float) -> SCNNode {
        let geometry = SCNBox(width: radius * 2, height: radius * 2, length: radius * 2, chamferRadius: 0)
        geometry.materials = [material(color)]
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(x, y, z)
        parent.addChildNode(node)
        return node
    }

    private func cone(
        _ parent: SCNNode,
        bottom: CGFloat,
        height: CGFloat,
        color: UIColor,
        x: Float,
        y: Float,
        z: Float
    ) {
        for (step, width) in [bottom * 2, bottom * 1.3, bottom * 0.6].enumerated() {
            let slab = height / 3
            box(parent, width, slab, width, color, x, y - Float(height) / 2 + Float(slab) * (Float(step) + 0.5), z)
        }
    }

    private func flowers(_ parent: SCNNode, x: Float, z: Float) {
        for offset: Float in [-0.16, 0.13] {
            box(parent, 0.025, 0.17, 0.025, ToyColor.dark, x + offset, 0.06, z + offset)
            box(
                parent,
                0.15,
                0.055,
                0.15,
                offset > 0 ? ToyColor.cream : ToyColor.coral,
                x + offset,
                0.16,
                z + offset,
                bevel: 0.03
            )
            box(parent, 0.05, 0.06, 0.05, ToyColor.yellow, x + offset, 0.18, z + offset)
        }
    }

    private func makeDuck(_ plumage: Plumage) -> SCNNode {
        let root = SCNNode()
        let color = ToyColor.duck(plumage)
        let belly = ToyColor.lighten(color)
        box(root, 0.54, 0.40, 0.63, color, 0, 0.29, 0.02, bevel: 0.13)
        box(root, 0.40, 0.12, 0.46, belly, 0, 0.16, 0.04, bevel: 0.05)
        box(root, 0.42, 0.39, 0.42, color, 0, 0.59, -0.20, bevel: 0.11)
        box(root, 0.27, 0.075, 0.25, ToyColor.coral, 0, 0.51, -0.47, bevel: 0.03)
        box(root, 0.23, 0.05, 0.20, UIColor(red: 0.86, green: 0.32, blue: 0.26, alpha: 1), 0, 0.455, -0.45, bevel: 0.02)
        for x: Float in [-0.14, 0.14] {
            box(root, 0.062, 0.074, 0.035, ToyColor.dark, x, 0.65, -0.411, bevel: 0.016)
            box(root, 0.02, 0.022, 0.012, UIColor.white, x + 0.014, 0.668, -0.43, bevel: 0.005)
            box(root, 0.14, 0.075, 0.21, ToyColor.coral, x, 0.035, -0.03, bevel: 0.025)
            box(
                root,
                0.085,
                0.033,
                0.027,
                UIColor(red: 1, green: 0.61, blue: 0.40, alpha: 1),
                x,
                0.55,
                -0.413
            )
        }
        box(root, 0.11, 0.23, 0.36, color.withAlphaComponent(1), -0.29, 0.30, 0.05, bevel: 0.04)
        box(root, 0.11, 0.23, 0.36, color.withAlphaComponent(1), 0.29, 0.30, 0.05, bevel: 0.04)
        box(root, 0.20, 0.16, 0.18, color, 0, 0.38, 0.35, bevel: 0.04)
        if plumage == .midnight {
            box(root, 0.24, 0.08, 0.24, ToyColor.yellow, 0, 0.81, -0.20)
            for x: Float in [-0.08, 0, 0.08] {
                box(root, 0.04, 0.09, 0.04, ToyColor.yellow, x, 0.87, -0.20)
            }
        }
        return root
    }
}
