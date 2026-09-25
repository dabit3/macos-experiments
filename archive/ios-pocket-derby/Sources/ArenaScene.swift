import SpriteKit
import UIKit

/// Pixel-art rooftop pitch. Every texture is painted at one art pixel per point
/// and magnified `P` times with nearest-neighbour filtering, so the arena, cars
/// and ball share one chunky 4-unit grid. Motion feedback is frame-stepped
/// (blinks, snaps, flicker) rather than eased.
final class ArenaScene: SKScene {
    /// Arena units per art pixel.
    static let P: CGFloat = 4

    weak var store: GameStore?
    private let arena = SKNode()
    private let blueCar = SKNode()
    private let orangeCar = SKNode()
    private let ballNode = SKNode()
    private var ballSprite = SKSpriteNode()
    private var ballFrames: [SKTexture] = []
    private var ballDistance = 0.0
    private var lastBall = Vector.zero
    private let ballShadow = SKSpriteNode()
    private let targetRing = SKNode()
    private let playerTag = SKNode()
    private var nets: [SKNode] = []
    private var lastTime = 0.0
    private var accumulator = 0.0
    private var lastGoalCount = 0
    private var trailTick = 0
    private var idleTime = 0.0

    private let ink = UIColor(hex: 0x0C0C1C)
    private let white = UIColor(hex: 0xFCFCFC)
    private let blue = UIColor(hex: 0x0058F8)
    private let blueLight = UIColor(hex: 0x3CBCFC)
    private let orange = UIColor(hex: 0xF83800)
    private let orangeLight = UIColor(hex: 0xF87858)
    private let yellow = UIColor(hex: 0xF8D800)
    private let amber = UIColor(hex: 0xFC9838)
    private let grey = UIColor(hex: 0xBCBCBC)
    private let greyDark = UIColor(hex: 0x7C7C7C)

    init(store: GameStore) {
        self.store = store
        super.init(size: CGSize(width: 1100, height: 480))
        scaleMode = .resizeFill
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(arena)
        buildRooftop()
        buildGoals()
        buildCar(blueCar, color: blue, light: blueLight, dark: UIColor(hex: 0x0000A8))
        buildCar(orangeCar, color: orange, light: orangeLight, dark: UIColor(hex: 0xA81000))
        buildBall()
        buildTarget()
        buildPlayerTag()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func didChangeSize(_: CGSize) {
        let scale = min(size.width / 1130, size.height / 490)
        arena.xScale = scale
        arena.yScale = scale
    }

    // MARK: - Rooftop

    private func buildRooftop() {
        let P = ArenaScene.P
        let slab = Paint.pixelSprite(width: 296, height: 148, pixel: P, z: 0) { px in
            let concrete = UIColor(hex: 0x8C8C8C)
            let seam = UIColor(hex: 0x7C7C7C)
            let side = UIColor(hex: 0x505050)
            let wall = UIColor(hex: 0x0000A8)
            let turf = UIColor(hex: 0x3CB43C)
            let turfDark = UIColor(hex: 0x2C982C)
            // Drop shadow, slab side and top face.
            px.fill(-136, -72, 282, 134, ink.withAlphaComponent(0.35))
            px.fill(-141, -69, 282, 136, ink)
            px.fill(-140, -68, 280, 8, side)
            px.fill(-140, -60, 280, 126, concrete)
            px.hline(-140, 139, 65, grey)
            px.vline(-140, -60, 65, grey)
            for x in stride(from: -120, through: 120, by: 20) {
                px.vline(x, -59, 64, seam)
            }
            for y in stride(from: -40, through: 60, by: 20) {
                px.hline(-139, 138, y, seam)
            }
            // Bumper wall with a light top ring.
            px.roundedFill(-117, -51, 234, 102, 23, ink)
            px.roundedFill(-116, -50, 232, 100, 22, wall)
            px.roundedFrame(-115, -49, 230, 98, 21, blueLight)
            // Team rails along the near and far walls.
            for y in [-50, 48] {
                px.fill(-100, y, 92, 2, blueLight)
                px.fill(8, y, 92, 2, orangeLight)
                px.fill(-101, y, 1, 2, ink)
                px.fill(-8, y, 1, 2, ink)
                px.fill(7, y, 1, 2, ink)
                px.fill(100, y, 1, 2, ink)
            }
            // Turf: mown checkerboard inside a dark kerb.
            px.roundedFill(-111, -45, 222, 90, 19, ink)
            px.checker(px.roundedPath(-110, -44, 220, 88, 18), cell: 11, turf, turfDark, origin: 0)
            // Chalk.
            px.roundedFrame(-105, -39, 210, 78, 14, white)
            px.vline(0, -38, 37, white)
            px.circleFrame(0, 0, 16, white)
            px.fill(-1, -1, 2, 2, white)
            for side in [-1, 1] {
                let boxX = side < 0 ? -105 : 75
                px.frame(boxX, -28, 31, 56, white)
                let smallX = side < 0 ? -105 : 93
                px.frame(smallX, -15, 13, 30, white)
                px.fill(side * 84 - 1, -1, 2, 2, white)
                // Corner floodlights on the slab.
                for sy in [-1, 1] {
                    let cx = side * 134, cy = sy < 0 ? -58 : 58
                    px.fill(cx - 3, cy - 3, 6, 6, ink)
                    px.fill(cx - 2, cy - 2, 4, 4, yellow)
                    px.fill(cx - 2, cy, 4, 2, white)
                }
            }
        }
        arena.addChild(slab)
        courtLabel("ROOFTOP 01 · POCKET ATHLETIC CLUB", at: CGPoint(x: 0, y: 232), color: white)
        courtLabel("◀ DEFEND", at: CGPoint(x: -260, y: -232), color: blueLight)
        courtLabel("SCORE ▶", at: CGPoint(x: 260, y: -232), color: orangeLight)
        let monogram = PixelFont.label("PD", pixel: 12, color: UIColor(hex: 0x58C858).withAlphaComponent(0.45))
        monogram.zPosition = 0.4
        arena.addChild(monogram)
    }

    private func courtLabel(_ text: String, at point: CGPoint, color: UIColor) {
        let node = PixelFont.label(text, pixel: 2, color: color, outline: ink)
        node.position = point
        node.zPosition = 0.6
        arena.addChild(node)
    }

    private func buildGoals() {
        let P = ArenaScene.P
        for side in [-1.0, 1.0] {
            let color = side < 0 ? blue : orange
            let light = side < 0 ? blueLight : orangeLight
            let goal = Paint.pixelSprite(width: 14, height: 48, pixel: P, z: 0.8) { px in
                px.fill(-7, -20, 13, 40, ink)
                for x in -6 ... 3 {
                    for y in -19 ... 18 where (x + y).isMultiple(of: 2) {
                        px.dot(x, y, greyDark)
                    }
                }
                px.fill(4, -20, 2, 40, color)
                px.fill(4, -20, 2, 3, light)
                px.fill(4, 17, 2, 3, light)
                px.fill(-7, 19, 6, 3, ink)
                px.fill(-7, -22, 6, 3, ink)
                px.fill(-6, 20, 4, 2, white)
                px.fill(-6, -22, 4, 2, white)
            }
            goal.position = CGPoint(x: side * 464, y: 0)
            goal.xScale = side
            arena.addChild(goal)
            nets.append(goal)
        }
    }

    // MARK: - Actors

    private func buildCar(_ car: SKNode, color: UIColor, light: UIColor, dark: UIColor) {
        let P = ArenaScene.P
        car.zPosition = 5
        let shadow = Paint.pixelSprite(width: 17, height: 12, pixel: P, z: -1) { px in
            px.roundedFill(-8, -6, 17, 12, 3, ink.withAlphaComponent(0.35))
        }
        shadow.position = CGPoint(x: P, y: -P * 1.5)
        car.addChild(shadow)
        let palette: [Character: UIColor] = [
            "k": ink, "b": color, "l": light, "d": dark,
            "w": blueLight, "W": white, "y": yellow, "r": UIColor(hex: 0xF83800)
        ]
        let body = Paint.spriteNode([
            "..kkkk.....kkkk..",
            "..kkkk.....kkkk..",
            ".kbbbbbbbbbbbbbk.",
            "kdllllkkkkkkllbyk",
            "rdbbbbkwwwwwkbbyk",
            "kdbbbbkwwwwWkbbbk",
            "kdbbbbkwwwwWkbbbk",
            "rdbbbbkwwwwwkbbyk",
            "kddddkkkkkkkddbyk",
            ".kbbbbbbbbbbbbbk.",
            "..kkkk.....kkkk..",
            "..kkkk.....kkkk.."
        ], palette: palette, pixel: P)
        car.addChild(body)
        arena.addChild(car)
    }

    private func buildBall() {
        let P = ArenaScene.P
        ballShadow.texture = Paint.pixelTexture(width: 9, height: 5) { px in
            px.roundedFill(-4, -2, 9, 5, 2, ink.withAlphaComponent(0.35))
        }
        ballShadow.size = CGSize(width: 9 * P, height: 5 * P)
        ballShadow.zPosition = 6
        arena.addChild(ballShadow)
        let palette: [Character: UIColor] = ["k": ink, "W": white, "g": greyDark]
        ballFrames = [
            Paint.spriteMap([
                "...kkk...",
                ".kkWWWkk.",
                ".kWWgWWk.",
                "kWWWWWgWk",
                "kWgWWWWWk",
                "kWWWWgWWk",
                ".kgWWWWk.",
                ".kkWWWkk.",
                "...kkk..."
            ], palette: palette),
            Paint.spriteMap([
                "...kkk...",
                ".kkWWWkk.",
                ".kWWWWgk.",
                "kWgWWWWWk",
                "kWWWWgWWk",
                "kWWgWWWWk",
                ".kWWWWgk.",
                ".kkWWWkk.",
                "...kkk..."
            ], palette: palette)
        ]
        ballSprite = SKSpriteNode(texture: ballFrames[0])
        ballSprite.size = CGSize(width: 9 * P, height: 9 * P)
        ballNode.zPosition = 7
        ballNode.addChild(ballSprite)
        arena.addChild(ballNode)
    }

    private func buildTarget() {
        let P = ArenaScene.P
        targetRing.zPosition = 1
        targetRing.isHidden = true
        let reticle = Paint.spriteNode([
            "kk.....kk",
            "kWk...kWk",
            ".k.....k.",
            ".........",
            "....y....",
            ".........",
            ".k.....k.",
            "kWk...kWk",
            "kk.....kk"
        ], palette: ["k": ink, "W": white, "y": yellow], pixel: P)
        targetRing.addChild(reticle)
        reticle.run(.repeatForever(.sequence([.wait(forDuration: 0.25), .hide(), .wait(forDuration: 0.12), .unhide()])))
        arena.addChild(targetRing)
    }

    private func buildPlayerTag() {
        let P = ArenaScene.P
        playerTag.zPosition = 8
        let arrow = Paint.spriteNode([
            "kkkkkkk",
            "kyyyyyk",
            ".kyyyk.",
            "..kyk..",
            "...k..."
        ], palette: ["k": ink, "y": yellow], pixel: P)
        playerTag.addChild(arrow)
        arrow.run(.repeatForever(.sequence([
            .wait(forDuration: 0.3), .moveBy(x: 0, y: -P, duration: 0),
            .wait(forDuration: 0.3), .moveBy(x: 0, y: P, duration: 0)
        ])))
        arena.addChild(playerTag)
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        if let bounds = view?.bounds.size, bounds.width > 0, bounds.height > 0, bounds != size {
            size = bounds
        }
        guard let store else { return }
        let delta = lastTime == 0 ? 0 : min(currentTime - lastTime, 0.05)
        lastTime = currentTime
        accumulator += delta
        while accumulator >= 1.0 / 120 {
            store.tick(1.0 / 120)
            accumulator -= 1.0 / 120
        }
        let engine = store.engine
        let P = ArenaScene.P
        if store.screen == .title {
            idleTime += store.reducedMotion ? 0 : delta
            blueCar.position = CGPoint(x: -128, y: -40)
            blueCar.zRotation = 0.35
            orangeCar.position = CGPoint(x: 168, y: 56)
            orangeCar.zRotation = .pi + 0.4
            let hop = Int(idleTime * 3).isMultiple(of: 2) ? P : 0
            place(ball: .zero, lift: hop)
            targetRing.isHidden = true
            playerTag.isHidden = true
            return
        }
        playerTag.isHidden = false
        playerTag.position = CGPoint(x: engine.player.position.x, y: engine.player.position.y + 40)
        blueCar.position = engine.player.position.point
        blueCar.zRotation = engine.player.heading
        orangeCar.position = engine.opponent.position.point
        orangeCar.zRotation = engine.opponent.heading
        place(ball: engine.ball.point, lift: 0)
        if !engine.paused {
            ballDistance += (engine.ball - lastBall).length
            if ballDistance > 26 {
                ballDistance = 0
                ballSprite.texture = ballSprite.texture === ballFrames[0] ? ballFrames[1] : ballFrames[0]
            }
        }
        lastBall = engine.ball
        targetRing.isHidden = engine.driveTarget == nil || engine.phase != .playing
        if let target = engine.driveTarget {
            targetRing.position = target.point
        }
        trailTick += 1
        if trailTick.isMultiple(of: 3), !engine.paused, !store.reducedMotion, engine.phase == .playing {
            trail(car: engine.player, color: blueLight)
            trail(car: engine.opponent, color: orangeLight)
        }
        let goals = engine.playerGoals + engine.opponentGoals
        if goals != lastGoalCount {
            lastGoalCount = goals
            if goals > 0 {
                celebrate(player: engine.lastScorerIsPlayer, reduced: store.reducedMotion)
            }
        }
    }

    private func place(ball point: CGPoint, lift: CGFloat) {
        ballNode.position = CGPoint(x: point.x, y: point.y + lift)
        ballShadow.position = CGPoint(x: point.x + ArenaScene.P, y: point.y - ArenaScene.P * 3)
    }

    private func trail(car: Car, color: UIColor) {
        guard car.velocity.length > 90 else { return }
        let P = ArenaScene.P
        let boosting = car.velocity.length > 235
        let node = SKSpriteNode(color: boosting ? white : color, size: CGSize(width: P * 2, height: P * 2))
        node.position = (car.position - Vector(x: cos(car.heading), y: sin(car.heading)) * 30).point
        node.zPosition = 2
        arena.addChild(node)
        node.run(.sequence([
            .wait(forDuration: 0.08),
            .run { node.color = boosting ? self.yellow : color },
            .wait(forDuration: 0.08),
            .run { node.color = boosting ? self.amber : color.darker },
            .wait(forDuration: 0.08),
            .removeFromParent()
        ]))
    }

    private func celebrate(player: Bool, reduced: Bool) {
        let P = ArenaScene.P
        let color = player ? blueLight : orangeLight
        let origin = CGPoint(x: player ? 450 : -450, y: 0)
        let flash = SKSpriteNode(color: white, size: CGSize(width: 1300, height: 700))
        flash.alpha = 0.85
        flash.zPosition = 9
        arena.addChild(flash)
        flash.run(.sequence([
            .wait(forDuration: 0.07), .hide(), .wait(forDuration: 0.07),
            .unhide(), .wait(forDuration: 0.05), .removeFromParent()
        ]))
        let net = nets[player ? 1 : 0]
        let side: CGFloat = player ? 1 : -1
        net.run(.sequence([
            .scaleX(to: side * 1.25, duration: 0), .wait(forDuration: 0.08),
            .scaleX(to: side * 0.9, duration: 0), .wait(forDuration: 0.08),
            .scaleX(to: side, duration: 0)
        ]))
        guard !reduced else { return }
        arena.run(.sequence([
            .moveBy(x: 0, y: P, duration: 0), .wait(forDuration: 0.05),
            .moveBy(x: P, y: -P * 2, duration: 0), .wait(forDuration: 0.05),
            .moveBy(x: -P, y: P, duration: 0)
        ]))
        for index in 0 ..< 28 {
            let tone = [white, yellow, color, amber][index % 4]
            let big = index.isMultiple(of: 3)
            let square = SKSpriteNode(
                color: tone,
                size: CGSize(width: big ? P * 3 : P * 2, height: big ? P * 3 : P * 2)
            )
            square.position = origin
            square.zPosition = 10
            arena.addChild(square)
            let angle = Double(index) * 2.399
            var vx = -Double(side) * (10 + abs(cos(angle)) * Double(30 + index % 5 * 8))
            var vy = sin(angle) * Double(28 + index % 4 * 10) + 18
            let step = SKAction.run {
                square.position.x += vx
                square.position.y += vy
                vy -= 7
                vx *= 0.94
            }
            square.run(.sequence([
                .repeat(.sequence([step, .wait(forDuration: 0.07)]), count: 11),
                .removeFromParent()
            ]))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        aim(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        aim(touches)
    }

    private func aim(_ touches: Set<UITouch>) {
        guard let store, store.screen == .match, !store.engine.paused,
              let touch = touches.first else { return }
        let point = touch.location(in: arena)
        store.engine.driveTarget = Vector(x: max(-417, min(417, point.x)), y: max(-151, min(151, point.y)))
    }
}

extension Vector {
    var point: CGPoint {
        CGPoint(x: x, y: y)
    }
}
