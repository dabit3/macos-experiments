import SpriteKit

final class GameScene: SKScene, SKPhysicsContactDelegate {

    private enum Category {
        static let otter: UInt32 = 1
        static let pipe: UInt32 = 2
        static let ground: UInt32 = 4
        static let score: UInt32 = 8
    }

    private enum State {
        case ready, playing, gameOver
    }

    private let pipeSpeed: CGFloat = 150
    private let pipeInterval: TimeInterval = 1.4
    private let pipeGap: CGFloat = 170
    private let pipeWidth: CGFloat = 64
    private let flapVelocity: CGFloat = 420
    private let groundHeight: CGFloat = 90

    private var state: State = .ready
    private var score = 0
    private var best = 0
    private var lastUpdate: TimeInterval = 0
    private var timeSincePipe: TimeInterval = 0
    private var gameOverTime: TimeInterval = 0

    private let worldNode = SKNode()      // pipes + clouds, scrolled world
    private var pipes: [SKNode] = []
    private var clouds: [SKNode] = []
    private var groundTiles: [SKShapeNode] = []

    private let otter = OtterNode()
    private let scoreLabel = SKLabelNode()
    private let titleLabel = SKLabelNode()
    private let hintLabel = SKLabelNode()
    private let gameOverLabel = SKLabelNode()
    private let bestLabel = SKLabelNode()
    private let flash = SKSpriteNode(color: .white, size: .zero)

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -11.8)
        physicsWorld.contactDelegate = self
        best = UserDefaults.standard.integer(forKey: "otterflap.best")

        addChild(worldNode)
        buildBackground()
        buildGround()
        buildOtter()
        buildUI()
        showReady()
    }

    // MARK: - Setup

    private func roundedFont(_ size: CGFloat) -> String {
        let base = UIFont.systemFont(ofSize: size, weight: .bold)
        if let rounded = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: size).fontName
        }
        return base.fontName
    }

    private func buildBackground() {
        // Sky gradient baked into a texture
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 256))
        let image = renderer.image { ctx in
            let colors = [
                UIColor(red: 0.35, green: 0.72, blue: 0.95, alpha: 1).cgColor,
                UIColor(red: 0.72, green: 0.90, blue: 0.98, alpha: 1).cgColor
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 256),
                    end: CGPoint(x: 0, y: 0),
                    options: [])
            }
        }
        let sky = SKSpriteNode(texture: SKTexture(image: image), size: size)
        sky.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sky.zPosition = -10
        addChild(sky)

        // Drifting clouds
        for i in 0..<4 {
            let cloud = makeCloud()
            cloud.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: size.height * CGFloat.random(in: 0.55...0.9))
            cloud.alpha = 0.8
            cloud.zPosition = -5
            cloud.userData = ["speed": CGFloat.random(in: 12...30)]
            worldNode.addChild(cloud)
            clouds.append(cloud)
            cloud.position.x += CGFloat(i) * 40
        }
    }

    private func makeCloud() -> SKNode {
        let cloud = SKNode()
        for (dx, dy, r): (CGFloat, CGFloat, CGFloat) in
            [(-18, 0, 12), (0, 5, 16), (18, 0, 12), (4, -4, 11)] {
            let puff = SKShapeNode(circleOfRadius: r)
            puff.fillColor = .white
            puff.strokeColor = .clear
            puff.position = CGPoint(x: dx, y: dy)
            cloud.addChild(puff)
        }
        return cloud
    }

    private func buildGround() {
        let groundColor = SKColor(red: 0.76, green: 0.60, blue: 0.42, alpha: 1)
        for i in 0..<2 {
            let tile = SKShapeNode(rectOf: CGSize(width: size.width + 4, height: groundHeight))
            tile.fillColor = groundColor
            tile.strokeColor = .clear
            tile.position = CGPoint(x: CGFloat(i) * (size.width + 2) + size.width / 2,
                                    y: groundHeight / 2)
            tile.zPosition = 5
            addChild(tile)
            groundTiles.append(tile)

            // grass strip on top
            let grass = SKShapeNode(rectOf: CGSize(width: size.width + 4, height: 8))
            grass.fillColor = SKColor(red: 0.35, green: 0.62, blue: 0.32, alpha: 1)
            grass.strokeColor = .clear
            grass.position = CGPoint(x: 0, y: groundHeight / 2 - 4)
            tile.addChild(grass)
        }

        let groundBody = SKNode()
        groundBody.position = CGPoint(x: size.width / 2, y: groundHeight)
        groundBody.physicsBody = SKPhysicsBody(
            rectangleOf: CGSize(width: size.width * 2, height: 2))
        groundBody.physicsBody?.isDynamic = false
        groundBody.physicsBody?.categoryBitMask = Category.ground
        addChild(groundBody)
    }

    private func buildOtter() {
        otter.position = CGPoint(x: size.width * 0.35, y: size.height * 0.55)
        otter.zPosition = 10
        let body = otter.physicsBody
        body?.categoryBitMask = Category.otter
        body?.contactTestBitMask = Category.pipe | Category.ground | Category.score
        body?.collisionBitMask = Category.pipe | Category.ground
        body?.isDynamic = false
        addChild(otter)
        otter.startBobbing()
    }

    private func buildUI() {
        scoreLabel.fontName = roundedFont(44)
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height - 120)
        scoreLabel.zPosition = 20
        scoreLabel.text = "0"
        scoreLabel.verticalAlignmentMode = .top
        addStroke(scoreLabel)
        addChild(scoreLabel)

        titleLabel.fontName = roundedFont(40)
        titleLabel.fontColor = SKColor(red: 0.25, green: 0.42, blue: 0.55, alpha: 1)
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        titleLabel.zPosition = 20
        titleLabel.text = "OtterFlap"
        addChild(titleLabel)

        hintLabel.fontName = roundedFont(22)
        hintLabel.fontColor = .darkGray
        hintLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.42)
        hintLabel.zPosition = 20
        addChild(hintLabel)

        gameOverLabel.fontName = roundedFont(38)
        gameOverLabel.fontColor = SKColor(red: 0.8, green: 0.25, blue: 0.2, alpha: 1)
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.66)
        gameOverLabel.zPosition = 20
        gameOverLabel.text = "Game Over"
        addStroke(gameOverLabel)
        addChild(gameOverLabel)

        bestLabel.fontName = roundedFont(20)
        bestLabel.fontColor = .darkGray
        bestLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.58)
        bestLabel.zPosition = 20
        addChild(bestLabel)

        flash.size = size
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 30
        flash.alpha = 0
        addChild(flash)
    }

    private func addStroke(_ label: SKLabelNode) {
        // subtle shadow behind light labels for readability
        let shadow = SKLabelNode(text: label.text)
        shadow.fontName = label.fontName
        shadow.fontSize = label.fontSize
        shadow.fontColor = SKColor(white: 0, alpha: 0.3)
        shadow.position = CGPoint(x: 0, y: -3)
        shadow.zPosition = -1
        shadow.verticalAlignmentMode = label.verticalAlignmentMode
        shadow.name = "shadow"
        label.addChild(shadow)
    }

    // MARK: - State

    private func showReady() {
        state = .ready
        score = 0
        scoreLabel.text = "0"
        (scoreLabel.childNode(withName: "shadow") as? SKLabelNode)?.text = "0"
        titleLabel.isHidden = false
        hintLabel.text = "Tap to start"
        hintLabel.isHidden = false
        gameOverLabel.isHidden = true
        bestLabel.isHidden = true
    }

    private func startGame() {
        state = .playing
        titleLabel.isHidden = true
        hintLabel.isHidden = true
        otter.stopBobbing()
        otter.physicsBody?.isDynamic = true
        timeSincePipe = pipeInterval // spawn first pipe immediately-ish
        flap()
    }

    private func flap() {
        otter.physicsBody?.velocity = CGVector(dx: 0, dy: flapVelocity)
        otter.flapSquash()
        otter.run(.rotate(toAngle: 0.35, duration: 0.12, shortestUnitArc: true))
    }

    private func endGame() {
        guard state == .playing else { return }
        state = .gameOver
        gameOverTime = 0
        flash.run(.sequence([
            .fadeAlpha(to: 0.8, duration: 0.05),
            .fadeAlpha(to: 0, duration: 0.4)
        ]))
        if score > best {
            best = score
            UserDefaults.standard.set(best, forKey: "otterflap.best")
        }
        gameOverLabel.isHidden = false
        bestLabel.text = "Score \(score)   Best \(best)"
        bestLabel.isHidden = false
        hintLabel.text = "Tap to try again"
        hintLabel.isHidden = true
    }

    private func reset() {
        for pipe in pipes { pipe.removeFromParent() }
        pipes.removeAll()
        otter.physicsBody?.isDynamic = false
        otter.physicsBody?.velocity = .zero
        otter.position = CGPoint(x: size.width * 0.35, y: size.height * 0.55)
        otter.zRotation = 0
        otter.startBobbing()
        showReady()
    }

    // MARK: - Pipes

    private func spawnPipe() {
        let margin: CGFloat = 90
        let minCenter = groundHeight + pipeGap / 2 + margin
        let maxCenter = size.height - pipeGap / 2 - margin - 40
        let gapCenter = CGFloat.random(in: minCenter...maxCenter)

        let pipe = SKNode()
        pipe.position = CGPoint(x: size.width + pipeWidth, y: 0)
        pipe.zPosition = 4

        let kelp = SKColor(red: 0.30, green: 0.55, blue: 0.35, alpha: 1)
        let kelpDark = SKColor(red: 0.22, green: 0.44, blue: 0.28, alpha: 1)

        let bottomTop = gapCenter - pipeGap / 2
        let topBottom = gapCenter + pipeGap / 2

        let bottomHeight = bottomTop
        let bottom = SKShapeNode(rectOf: CGSize(width: pipeWidth, height: bottomHeight))
        bottom.fillColor = kelp
        bottom.strokeColor = kelpDark
        bottom.lineWidth = 3
        bottom.position = CGPoint(x: 0, y: bottomHeight / 2)
        bottom.physicsBody = SKPhysicsBody(
            rectangleOf: CGSize(width: pipeWidth, height: bottomHeight))
        bottom.physicsBody?.isDynamic = false
        bottom.physicsBody?.categoryBitMask = Category.pipe
        pipe.addChild(bottom)

        let topHeight = size.height - topBottom
        let top = SKShapeNode(rectOf: CGSize(width: pipeWidth, height: topHeight))
        top.fillColor = kelp
        top.strokeColor = kelpDark
        top.lineWidth = 3
        top.position = CGPoint(x: 0, y: topBottom + topHeight / 2)
        top.physicsBody = SKPhysicsBody(
            rectangleOf: CGSize(width: pipeWidth, height: topHeight))
        top.physicsBody?.isDynamic = false
        top.physicsBody?.categoryBitMask = Category.pipe
        pipe.addChild(top)

        // Scoring sensor in the gap
        let sensor = SKNode()
        sensor.position = CGPoint(x: 0, y: gapCenter)
        sensor.physicsBody = SKPhysicsBody(
            rectangleOf: CGSize(width: 4, height: pipeGap))
        sensor.physicsBody?.isDynamic = false
        sensor.physicsBody?.categoryBitMask = Category.score
        sensor.physicsBody?.collisionBitMask = 0
        pipe.addChild(sensor)

        worldNode.addChild(pipe)
        pipes.append(pipe)
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch state {
        case .ready:
            startGame()
        case .playing:
            flap()
        case .gameOver:
            if gameOverTime > 0.5 {
                reset()
            }
        }
    }

    // MARK: - Physics

    func didBegin(_ contact: SKPhysicsContact) {
        let mask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        if mask == Category.otter | Category.score {
            // remove sensor so it only counts once
            let sensor = contact.bodyA.categoryBitMask == Category.score
                ? contact.bodyA.node : contact.bodyB.node
            sensor?.removeFromParent()
            score += 1
            scoreLabel.text = "\(score)"
            (scoreLabel.childNode(withName: "shadow") as? SKLabelNode)?.text = "\(score)"
        } else if mask == Category.otter | Category.pipe
                    || mask == Category.otter | Category.ground {
            endGame()
        }
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 20)
        lastUpdate = currentTime
        if state == .gameOver {
            gameOverTime += dt
            if gameOverTime > 0.5 { hintLabel.isHidden = false }
        }

        // Clouds always drift
        for cloud in clouds {
            let speed = (cloud.userData?["speed"] as? CGFloat) ?? 15
            cloud.position.x -= speed * dt
            if cloud.position.x < -60 {
                cloud.position.x = size.width + 60
                cloud.position.y = size.height * CGFloat.random(in: 0.55...0.9)
            }
        }

        guard state != .gameOver else { return }

        // Scroll ground
        for tile in groundTiles {
            tile.position.x -= pipeSpeed * dt
            if tile.position.x <= -size.width / 2 {
                tile.position.x += (size.width + 2) * 2
            }
        }

        if state == .playing {
            // Spawn and move pipes
            timeSincePipe += dt
            if timeSincePipe >= pipeInterval {
                timeSincePipe = 0
                spawnPipe()
            }
            var offscreen: [Int] = []
            for (i, pipe) in pipes.enumerated() {
                pipe.position.x -= pipeSpeed * dt
                if pipe.position.x < -pipeWidth * 2 { offscreen.append(i) }
            }
            for i in offscreen.reversed() {
                pipes[i].removeFromParent()
                pipes.remove(at: i)
            }

            // Ceiling clamp
            if otter.position.y > size.height - 30 {
                otter.position.y = size.height - 30
                otter.physicsBody?.velocity.dy = min(otter.physicsBody?.velocity.dy ?? 0, 0)
            }

            // Tilt otter with velocity
            if let vy = otter.physicsBody?.velocity.dy {
                let target: CGFloat = vy > 0 ? 0.35 : max(-1.4, vy / 600)
                otter.zRotation += (target - otter.zRotation) * 0.15
            }
        }
    }
}
