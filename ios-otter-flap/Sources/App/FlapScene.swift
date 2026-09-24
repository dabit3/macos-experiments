import SpriteKit
import UIKit

@MainActor
final class FlapScene: SKScene {
    private weak var store: GameStore?
    private var world: FlapWorld?
    private var lastTime: TimeInterval?
    private var accumulator = 0.0
    private let step = 1.0 / 120
    private let backdrop = SKSpriteNode()
    private let mountainLayer = SKNode()
    private let forestLayer = SKNode()
    private let cloudLayer = SKNode()
    private let groundLayer = SKNode()
    private let logLayer = SKNode()
    private let otter = SKSpriteNode(texture: OtterArt.otterFrames[1])
    private let flash = SKSpriteNode(color: .white, size: .zero)
    private var logNodes: [SKNode] = []
    private var tileWidth: CGFloat = 0
    private var tilt: CGFloat = 0
    private var builtSize: CGSize = .zero
    /// UI-test pilot: `-autopilotScore N` flaps toward each gap until N points, then lets go.
    private let autopilotScore = UserDefaults.standard.integer(forKey: "autopilotScore")

    init(store: GameStore) {
        self.store = store
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        anchorPoint = .zero
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 1, size.height > 1, size != builtSize else { return }
        builtSize = size
        build()
        reset()
    }

    private func build() {
        removeAllChildren()
        let config = FlapConfig()
        tileWidth = ceil(size.width)

        backdrop.texture = OtterArt.sky(size)
        backdrop.size = size
        backdrop.anchorPoint = .zero
        backdrop.zPosition = -10
        addChild(backdrop)

        cloudLayer.removeAllChildren()
        cloudLayer.zPosition = -9
        for index in 0 ..< 4 {
            let cloud = SKSpriteNode(texture: OtterArt.cloud)
            cloud.setScale(0.6 + CGFloat(index % 3) * 0.25)
            cloud.alpha = 0.85
            cloud.position = CGPoint(x: CGFloat(index) * size.width / 3 + 40, y: size.height * (0.62 + CGFloat((index * 7) % 4) * 0.07))
            cloudLayer.addChild(cloud)
        }
        addChild(cloudLayer)

        tile(mountainLayer, texture: OtterArt.mountains(width: tileWidth), y: config.groundHeight + 40, z: -8)
        tile(forestLayer, texture: OtterArt.forest(width: tileWidth), y: config.groundHeight - 6, z: -7)

        logLayer.removeAllChildren()
        logNodes = []
        logLayer.zPosition = 0
        addChild(logLayer)

        tile(groundLayer, texture: OtterArt.ground(width: tileWidth, height: config.groundHeight + 40), y: 0, z: 1, anchorTop: config.groundHeight)

        otter.size = OtterArt.otterSize
        otter.zPosition = 5
        addChild(otter)

        flash.size = size
        flash.anchorPoint = .zero
        flash.alpha = 0
        flash.zPosition = 20
        addChild(flash)
    }

    private func tile(_ layer: SKNode, texture: SKTexture, y: CGFloat, z: CGFloat, anchorTop: CGFloat? = nil) {
        layer.removeAllChildren()
        layer.position = .zero
        layer.zPosition = z
        for index in 0 ..< 2 {
            let sprite = SKSpriteNode(texture: texture, size: CGSize(width: tileWidth + 1, height: texture.size().height))
            sprite.anchorPoint = anchorTop == nil ? .zero : CGPoint(x: 0, y: 1)
            sprite.position = CGPoint(x: CGFloat(index) * tileWidth, y: anchorTop ?? y)
            layer.addChild(sprite)
        }
        addChild(layer)
    }

    func reset() {
        let seed = UInt64(max(0, UserDefaults.standard.integer(forKey: "seed")))
        world = FlapWorld(width: Double(size.width), height: Double(size.height), seed: seed > 0 ? seed : .random(in: 1 ... .max))
        accumulator = 0
        lastTime = nil
        tilt = 0
        isPaused = false
        logNodes.forEach { $0.removeFromParent() }
        logNodes = []
        otter.removeAllActions()
        otter.texture = OtterArt.otterFrames[1]
        render()
    }

    func flap() {
        guard var world, world.flap() else { return }
        self.world = world
        store?.handle(.flapped)
        otter.removeAction(forKey: "flap")
        let frames = [OtterArt.otterFrames[0], OtterArt.otterFrames[1], OtterArt.otterFrames[2], OtterArt.otterFrames[1]]
        otter.run(.animate(with: frames, timePerFrame: 0.06), withKey: "flap")
    }

    override func touchesBegan(_: Set<UITouch>, with _: UIEvent?) {
        store?.tap()
    }

    override func update(_ currentTime: TimeInterval) {
        guard var world else { return }
        let delta = min(0.05, currentTime - (lastTime ?? currentTime))
        lastTime = currentTime
        accumulator += delta
        var events: [FlapEvent] = []
        while accumulator >= step {
            events += world.step(step)
            accumulator -= step
        }
        self.world = world
        if world.phase == .playing, world.score < autopilotScore {
            let target = world.logs.first { !$0.scored }?.gapCenter ?? world.height / 2
            if world.otterY < target - 25, world.velocity < 0 {
                flap()
            }
        }
        let scrolling = world.phase == .ready || world.phase == .playing
        if scrolling {
            scrollBackdrop(delta)
        }
        for event in events {
            if event == .crashed {
                crashEffects()
            }
            store?.handle(event)
        }
        store?.sync(phase: world.phase, score: world.score)
        render()
    }

    private func scrollBackdrop(_ delta: Double) {
        let speed = CGFloat(FlapConfig().scrollSpeed * delta)
        shift(mountainLayer, by: speed * 0.12)
        shift(forestLayer, by: speed * 0.35)
        shift(groundLayer, by: speed)
        for cloud in cloudLayer.children {
            cloud.position.x -= speed * 0.06
            if cloud.position.x < -80 {
                cloud.position.x = size.width + 80
            }
        }
    }

    private func shift(_ layer: SKNode, by amount: CGFloat) {
        layer.position.x -= amount
        if layer.position.x <= -tileWidth {
            layer.position.x += tileWidth
        }
    }

    private func render() {
        guard let world else { return }
        let bob = world.phase == .ready ? sin(world.readyTime * 5) * 7 : 0
        otter.position = CGPoint(x: world.otterX, y: world.otterY + bob)
        let target: CGFloat = switch world.phase {
        case .ready: 0
        case .over: -0.25
        case .playing, .falling: CGFloat(max(-1.3, min(0.45, world.velocity / 900)))
        }
        tilt += (target - tilt) * (target > tilt ? 0.5 : 0.12)
        otter.zRotation = tilt
        if world.phase == .ready, otter.action(forKey: "flap") == nil, Int(world.readyTime * 6) % 5 == 0 {
            flapIdle()
        }

        while logNodes.count < world.logs.count {
            let node = makeLogNode()
            logLayer.addChild(node)
            logNodes.append(node)
        }
        while logNodes.count > world.logs.count {
            logNodes.removeFirst().removeFromParent()
        }
        for (node, log) in zip(logNodes, world.logs) {
            node.position.x = CGFloat(log.x)
            node.childNode(withName: "bottom")?.position.y = CGFloat(log.gapBottom)
            node.childNode(withName: "top")?.position.y = CGFloat(log.gapTop)
        }
    }

    private func flapIdle() {
        let frames = [OtterArt.otterFrames[0], OtterArt.otterFrames[1], OtterArt.otterFrames[2], OtterArt.otterFrames[1]]
        otter.run(.animate(with: frames, timePerFrame: 0.09), withKey: "flap")
    }

    private func makeLogNode() -> SKNode {
        let node = SKNode()
        for (name, flip) in [("bottom", false), ("top", true)] {
            let half = SKNode()
            half.name = name
            let body = SKSpriteNode(texture: OtterArt.logBody)
            body.anchorPoint = CGPoint(x: 0.5, y: 1)
            body.position = .zero
            let cap = SKSpriteNode(texture: OtterArt.logCap)
            cap.anchorPoint = CGPoint(x: 0.5, y: 1)
            cap.position = CGPoint(x: 0, y: 6)
            half.addChild(body)
            half.addChild(cap)
            half.yScale = flip ? -1 : 1
            node.addChild(half)
        }
        return node
    }

    private func crashEffects() {
        flash.removeAllActions()
        flash.alpha = 0.8
        flash.run(.fadeOut(withDuration: 0.25))
        let shake = SKAction.sequence((0 ..< 6).map { index in
            .moveBy(x: index % 2 == 0 ? 7 : -7, y: 0, duration: 0.03)
        })
        logLayer.run(shake)
        otter.removeAction(forKey: "flap")
        otter.texture = OtterArt.otterFrames[2]
    }
}
