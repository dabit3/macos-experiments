import SpriteKit

/// An otter drawn entirely from SKShapeNodes — no image assets.
final class OtterNode: SKNode {

    private let bodyNode = SKNode()

    override init() {
        super.init()
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private func build() {
        let brown = SKColor(red: 0.45, green: 0.30, blue: 0.17, alpha: 1)
        let tan = SKColor(red: 0.82, green: 0.66, blue: 0.45, alpha: 1)

        // Tail — behind the body
        let tail = SKShapeNode(ellipseOf: CGSize(width: 34, height: 12))
        tail.fillColor = brown
        tail.strokeColor = .clear
        tail.position = CGPoint(x: -26, y: -6)
        tail.zRotation = -0.35
        bodyNode.addChild(tail)

        // Body
        let body = SKShapeNode(ellipseOf: CGSize(width: 44, height: 30))
        body.fillColor = brown
        body.strokeColor = .clear
        bodyNode.addChild(body)

        // Belly
        let belly = SKShapeNode(ellipseOf: CGSize(width: 30, height: 18))
        belly.fillColor = tan
        belly.strokeColor = .clear
        belly.position = CGPoint(x: 2, y: -5)
        bodyNode.addChild(belly)

        // Head
        let head = SKShapeNode(circleOfRadius: 14)
        head.fillColor = brown
        head.strokeColor = .clear
        head.position = CGPoint(x: 18, y: 10)
        bodyNode.addChild(head)

        // Muzzle
        let muzzle = SKShapeNode(ellipseOf: CGSize(width: 18, height: 12))
        muzzle.fillColor = tan
        muzzle.strokeColor = .clear
        muzzle.position = CGPoint(x: 27, y: 7)
        bodyNode.addChild(muzzle)

        // Ears
        for dx: CGFloat in [10, 22] {
            let ear = SKShapeNode(circleOfRadius: 4.5)
            ear.fillColor = brown
            ear.strokeColor = .clear
            ear.position = CGPoint(x: dx, y: 22)
            bodyNode.addChild(ear)
        }

        // Nose
        let nose = SKShapeNode(circleOfRadius: 2.6)
        nose.fillColor = .black
        nose.strokeColor = .clear
        nose.position = CGPoint(x: 34, y: 8)
        bodyNode.addChild(nose)

        // Eye + highlight
        let eye = SKShapeNode(circleOfRadius: 3)
        eye.fillColor = .black
        eye.strokeColor = .clear
        eye.position = CGPoint(x: 24, y: 14)
        bodyNode.addChild(eye)

        let glint = SKShapeNode(circleOfRadius: 1)
        glint.fillColor = .white
        glint.strokeColor = .clear
        glint.position = CGPoint(x: 25, y: 15)
        bodyNode.addChild(glint)

        // Whiskers
        let whiskerPath = CGMutablePath()
        whiskerPath.move(to: CGPoint(x: 32, y: 6))
        whiskerPath.addLine(to: CGPoint(x: 42, y: 8))
        whiskerPath.move(to: CGPoint(x: 32, y: 5))
        whiskerPath.addLine(to: CGPoint(x: 42, y: 3))
        whiskerPath.move(to: CGPoint(x: 32, y: 7))
        whiskerPath.addLine(to: CGPoint(x: 41, y: 12))
        let whiskers = SKShapeNode(path: whiskerPath)
        whiskers.strokeColor = SKColor(white: 1, alpha: 0.7)
        whiskers.lineWidth = 0.8
        bodyNode.addChild(whiskers)

        // Flipper feet
        for dx: CGFloat in [-4, 8] {
            let foot = SKShapeNode(ellipseOf: CGSize(width: 12, height: 6))
            foot.fillColor = brown
            foot.strokeColor = .clear
            foot.position = CGPoint(x: dx, y: -15)
            bodyNode.addChild(foot)
        }

        addChild(bodyNode)

        physicsBody = SKPhysicsBody(circleOfRadius: 18)
        physicsBody?.isDynamic = true
        physicsBody?.allowsRotation = false
    }

    /// Gentle idle bob used on the ready screen.
    func startBobbing() {
        let up = SKAction.moveBy(x: 0, y: 10, duration: 0.5)
        up.timingMode = .easeInEaseOut
        let down = up.reversed()
        run(.repeatForever(.sequence([up, down])), withKey: "bob")
    }

    func stopBobbing() {
        removeAction(forKey: "bob")
    }

    /// Quick squash-and-stretch on flap.
    func flapSquash() {
        let squash = SKAction.scaleX(to: 0.85, y: 1.15, duration: 0.08)
        let back = SKAction.scale(to: 1.0, duration: 0.12)
        run(.sequence([squash, back]))
    }
}
