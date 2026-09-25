import SpriteKit
import UIKit

final class GameScene: SKScene {
  weak var model: GameModel?
  var onFirstFrame: (() -> Void)?
  private var renderedFrames = 0
  private let world = SKNode()
  private let far = SKNode()
  private let mid = SKNode()
  private let sky = SKNode()
  private let player = SKNode()
  private let trail = SKNode()
  private let ground = 154.0
  private let anchor = 160.0
  private let ridgeSpan = 1520.0
  private var previousTime: TimeInterval = 0
  private var lastPhase = RunPhase.ready
  private var lastBeat = -1
  private var wasGrounded = true
  private var trailClock = 0.0
  private var reducedMotion = false
  private var pillars: [(base: SKSpriteNode, cap: SKShapeNode, height: Double)] = []
  private var speedLines: [SKSpriteNode] = []
  private var plates: [SKShapeNode] = []
  private var rings: [SKShapeNode] = []
  private var backdrop = SKSpriteNode()
  private var horizonGlow = SKSpriteNode()
  private var horizon = SKShapeNode()
  private let coral = UIColor(red: 1, green: 0.36, blue: 0.43, alpha: 1)
  private let cyan = UIColor(red: 0.35, green: 0.95, blue: 0.94, alpha: 1)
  private let violet = UIColor(red: 0.62, green: 0.42, blue: 1, alpha: 1)
  private var accent: UIColor { [cyan, violet, coral][(model?.selection ?? 0) % 3] }

  init(model: GameModel) {
    self.model = model
    super.init(size: CGSize(width: 760, height: 620))
    scaleMode = .aspectFit
    backgroundColor = UIColor(red: 0.035, green: 0.025, blue: 0.075, alpha: 1)
  }

  required init?(coder aDecoder: NSCoder) { nil }

  override func didMove(to view: SKView) {
    guard children.isEmpty, let model else { return }
    reducedMotion = UIAccessibility.isReduceMotionEnabled
    createSky()
    addChild(far)
    addChild(mid)
    createRidge()
    createPillars()
    createFloor()
    addChild(trail)
    addChild(world)
    createHazards(model.stage)
    createMarkers(model.stage)
    createPlayer()
    positionWorld()
  }

  private static func gradient(size: CGSize, colors: [UIColor]) -> SKTexture {
    let image = UIGraphicsImageRenderer(size: size).image { context in
      let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray,
        locations: nil)!
      context.cgContext.drawLinearGradient(
        gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
    }
    return SKTexture(image: image)
  }

  private func createSky() {
    backdrop = SKSpriteNode(
      texture: Self.gradient(
        size: CGSize(width: 8, height: 512),
        colors: [
          UIColor(red: 0.2, green: 0.1, blue: 0.4, alpha: 1),
          UIColor(red: 0.09, green: 0.05, blue: 0.19, alpha: 1),
          backgroundColor,
        ]))
    backdrop.anchorPoint = CGPoint(x: 0, y: 0)
    backdrop.position = CGPoint(x: 0, y: ground)
    backdrop.size = CGSize(width: 760, height: 1400)
    addChild(backdrop)
    addChild(sky)
    for index in 0..<40 {
      let star = SKShapeNode(circleOfRadius: index % 4 == 0 ? 2.4 : 1.4)
      star.fillColor =
        (index % 7 == 0 ? accent : .white).withAlphaComponent(0.3 + Double(index % 3) * 0.15)
      star.strokeColor = .clear
      star.name = "star.\(index)"
      star.position = CGPoint(x: (index * 137) % 800, y: 210 + (index * 91) % 390)
      sky.addChild(star)
      if !reducedMotion {
        star.run(
          .repeatForever(
            .sequence([
              .fadeAlpha(to: 0.3, duration: 1.4 + Double(index % 5) * 0.4),
              .fadeAlpha(to: 1, duration: 1.4 + Double(index % 3) * 0.5),
            ])))
      }
    }
    for (index, side) in [140.0, 205.0, 270.0, 335.0].enumerated() {
      let ring = SKShapeNode(rectOf: CGSize(width: side, height: side), cornerRadius: 22)
      ring.strokeColor = (index == 0 ? accent : violet).withAlphaComponent(index == 0 ? 0.42 : 0.1)
      ring.lineWidth = index == 0 ? 2.5 : 1
      ring.glowWidth = index == 0 ? 2 : 0
      ring.zRotation = .pi / 4
      ring.position = CGPoint(x: 560, y: 372)
      ring.name = "ring.\(index)"
      sky.addChild(ring)
      rings.append(ring)
      if !reducedMotion {
        ring.run(
          .repeatForever(
            .rotate(byAngle: index % 2 == 0 ? .pi * 2 : -.pi * 2, duration: 70 + Double(index) * 25)
          ))
      }
    }
    let core = SKShapeNode(rectOf: CGSize(width: 34, height: 34), cornerRadius: 8)
    core.fillColor = accent.withAlphaComponent(0.22)
    core.strokeColor = accent.withAlphaComponent(0.6)
    core.lineWidth = 1.5
    core.zRotation = .pi / 4
    core.position = CGPoint(x: 560, y: 372)
    sky.addChild(core)
    horizonGlow = SKSpriteNode(
      texture: Self.gradient(
        size: CGSize(width: 8, height: 256),
        colors: [
          accent.withAlphaComponent(0), accent.withAlphaComponent(0.08),
          accent.withAlphaComponent(0.3),
        ]))
    horizonGlow.anchorPoint = CGPoint(x: 0, y: 0)
    horizonGlow.size = CGSize(width: 760, height: 150)
    horizonGlow.position = CGPoint(x: 0, y: ground)
    horizonGlow.blendMode = .add
    addChild(horizonGlow)
  }

  private func createRidge() {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: 0))
    let peaks: [(Double, Double)] = [
      (0, 40), (90, 120), (170, 70), (260, 165), (340, 95), (410, 140), (500, 60), (590, 185),
      (680, 110), (760, 150), (850, 75), (940, 130), (1030, 200), (1120, 90), (1210, 145),
      (1300, 65), (1400, 120), (1520, 40),
    ]
    for (x, y) in peaks { path.addLine(to: CGPoint(x: x, y: y)) }
    path.addLine(to: CGPoint(x: ridgeSpan, y: 0))
    path.closeSubpath()
    for copy in 0..<2 {
      let ridge = SKShapeNode(path: path)
      ridge.fillColor = UIColor(red: 0.075, green: 0.05, blue: 0.16, alpha: 1)
      ridge.strokeColor = violet.withAlphaComponent(0.22)
      ridge.lineWidth = 1.5
      ridge.position = CGPoint(x: Double(copy) * ridgeSpan, y: ground)
      ridge.name = "ridge.\(copy)"
      far.addChild(ridge)
    }
  }

  private func createPillars() {
    for index in 0..<18 {
      let height = Double(46 + (index * 47) % 150)
      let base = SKSpriteNode(
        color: UIColor(red: 0.12, green: 0.075, blue: 0.24, alpha: 0.9),
        size: CGSize(width: 26, height: 1))
      base.anchorPoint = CGPoint(x: 0.5, y: 0)
      base.position = CGPoint(x: Double(index) * 65, y: ground)
      base.yScale = height
      mid.addChild(base)
      let cap = SKShapeNode(rectOf: CGSize(width: 26, height: 2.5), cornerRadius: 1)
      cap.fillColor = accent.withAlphaComponent(index % 3 == 0 ? 0.85 : 0.4)
      cap.strokeColor = .clear
      cap.glowWidth = index % 3 == 0 ? 3 : 0
      cap.position = CGPoint(x: base.position.x, y: ground + height)
      mid.addChild(cap)
      pillars.append((base, cap, height))
    }
  }

  private func createFloor() {
    let floor = SKSpriteNode(
      texture: Self.gradient(
        size: CGSize(width: 8, height: 256),
        colors: [
          UIColor(red: 0.11, green: 0.07, blue: 0.21, alpha: 1),
          UIColor(red: 0.05, green: 0.035, blue: 0.1, alpha: 1),
          UIColor(red: 0.02, green: 0.015, blue: 0.045, alpha: 1),
        ]))
    floor.anchorPoint = CGPoint(x: 0, y: 0)
    floor.size = CGSize(width: 760, height: ground)
    addChild(floor)
    let sheen = SKSpriteNode(
      texture: Self.gradient(
        size: CGSize(width: 8, height: 128),
        colors: [accent.withAlphaComponent(0.22), accent.withAlphaComponent(0)]))
    sheen.anchorPoint = CGPoint(x: 0, y: 1)
    sheen.size = CGSize(width: 760, height: 60)
    sheen.position = CGPoint(x: 0, y: ground)
    sheen.blendMode = .add
    addChild(sheen)
    for index in 0...16 {
      let path = CGMutablePath()
      path.move(to: CGPoint(x: Double(index) * 76 - 228, y: 0))
      path.addLine(to: CGPoint(x: Double(index) * 47.5, y: ground))
      let line = SKShapeNode(path: path)
      line.strokeColor = accent.withAlphaComponent(0.09)
      addChild(line)
    }
    for index in 0..<7 {
      let line = SKSpriteNode(color: accent, size: CGSize(width: 760, height: 1))
      line.anchorPoint = CGPoint(x: 0, y: 0.5)
      line.alpha = 0.1
      line.name = "speed.\(index)"
      addChild(line)
      speedLines.append(line)
    }
    horizon = SKShapeNode(rect: CGRect(x: 0, y: ground - 1.2, width: 760, height: 2.4))
    horizon.fillColor = accent
    horizon.strokeColor = .clear
    horizon.glowWidth = 4
    addChild(horizon)
  }

  private func createHazards(_ stage: Stage) {
    var groupStart = 0.0
    var groupEnd = -1.0
    func closeGroup() {
      guard groupEnd > 0 else { return }
      let plate = SKShapeNode(
        rectOf: CGSize(width: groupEnd - groupStart + 10, height: 5), cornerRadius: 2.5)
      plate.fillColor = coral.withAlphaComponent(0.6)
      plate.strokeColor = .clear
      plate.glowWidth = 5
      plate.position = CGPoint(x: (groupStart + groupEnd) / 2, y: ground - 1)
      world.addChild(plate)
      plates.append(plate)
    }
    for obstacle in stage.obstacles {
      if obstacle.x - groupEnd > 1 {
        closeGroup()
        groupStart = obstacle.x
      }
      groupEnd = obstacle.x + obstacle.width
      let path = CGMutablePath()
      path.move(to: .zero)
      path.addLine(to: CGPoint(x: obstacle.width / 2, y: obstacle.height))
      path.addLine(to: CGPoint(x: obstacle.width, y: 0))
      path.closeSubpath()
      let shape = SKShapeNode(path: path)
      shape.fillColor = coral.withAlphaComponent(0.3)
      shape.strokeColor = coral
      shape.lineWidth = 3
      shape.glowWidth = 4
      shape.position = CGPoint(x: obstacle.x, y: ground)
      world.addChild(shape)
      let inner = CGMutablePath()
      inner.move(to: CGPoint(x: obstacle.width * 0.32, y: 4))
      inner.addLine(to: CGPoint(x: obstacle.width / 2, y: obstacle.height * 0.62))
      inner.addLine(to: CGPoint(x: obstacle.width * 0.68, y: 4))
      inner.closeSubpath()
      let core = SKShapeNode(path: inner)
      core.fillColor = UIColor.white.withAlphaComponent(0.55)
      core.strokeColor = .clear
      shape.addChild(core)
    }
    closeGroup()
  }

  private func createMarkers(_ stage: Stage) {
    for marker in stage.checkpoints {
      if model?.practice == true {
        let beam = SKSpriteNode(
          texture: Self.gradient(
            size: CGSize(width: 8, height: 256),
            colors: [cyan.withAlphaComponent(0), cyan.withAlphaComponent(0.55)]))
        beam.anchorPoint = CGPoint(x: 0.5, y: 0)
        beam.size = CGSize(width: 7, height: 210)
        beam.position = CGPoint(x: marker, y: ground)
        beam.blendMode = .add
        world.addChild(beam)
        let flag = SKShapeNode(rectOf: CGSize(width: 16, height: 16), cornerRadius: 3)
        flag.fillColor = cyan
        flag.strokeColor = UIColor.white.withAlphaComponent(0.8)
        flag.glowWidth = 5
        flag.zRotation = .pi / 4
        flag.position = CGPoint(x: marker, y: ground + 222)
        world.addChild(flag)
      } else {
        let line = SKShapeNode(rectOf: CGSize(width: 1, height: 160))
        line.fillColor = cyan.withAlphaComponent(0.1)
        line.strokeColor = .clear
        line.position = CGPoint(x: marker, y: ground + 80)
        world.addChild(line)
      }
    }
    let gate = SKNode()
    gate.position = CGPoint(x: stage.length, y: ground + 150)
    for (index, side) in [150.0, 215.0].enumerated() {
      let ring = SKShapeNode(rectOf: CGSize(width: side, height: side), cornerRadius: 18)
      ring.strokeColor = cyan.withAlphaComponent(index == 0 ? 0.5 : 0.18)
      ring.lineWidth = index == 0 ? 2 : 1
      ring.zRotation = .pi / 4
      gate.addChild(ring)
      if !reducedMotion {
        ring.run(.repeatForever(.rotate(byAngle: index == 0 ? .pi * 2 : -.pi * 2, duration: 30)))
      }
    }
    let beam = SKShapeNode(rectOf: CGSize(width: 8, height: 300), cornerRadius: 4)
    beam.fillColor = cyan
    beam.strokeColor = .white
    beam.glowWidth = 12
    gate.addChild(beam)
    world.addChild(gate)
  }

  private func createPlayer() {
    let aura = SKShapeNode(rectOf: CGSize(width: 52, height: 52), cornerRadius: 13)
    aura.strokeColor = cyan.withAlphaComponent(0.22)
    aura.lineWidth = 1.5
    aura.name = "aura"
    player.addChild(aura)
    let body = SKSpriteNode(
      texture: Self.gradient(
        size: CGSize(width: 8, height: 64),
        colors: [
          UIColor(red: 0.72, green: 1, blue: 0.98, alpha: 1), cyan,
          UIColor(red: 0.16, green: 0.7, blue: 0.85, alpha: 1),
        ]), size: CGSize(width: 42, height: 42))
    let mask = SKShapeNode(rectOf: CGSize(width: 42, height: 42), cornerRadius: 8)
    mask.fillColor = .white
    let crop = SKCropNode()
    crop.maskNode = mask
    crop.addChild(body)
    player.addChild(crop)
    let outline = SKShapeNode(rectOf: CGSize(width: 42, height: 42), cornerRadius: 8)
    outline.strokeColor = UIColor.white.withAlphaComponent(0.9)
    outline.lineWidth = 2
    outline.glowWidth = 5
    outline.fillColor = .clear
    player.addChild(outline)
    let core = SKShapeNode(rectOf: CGSize(width: 16, height: 16), cornerRadius: 4)
    core.fillColor = backgroundColor
    core.strokeColor = backgroundColor
    player.addChild(core)
    let pupil = SKShapeNode(rectOf: CGSize(width: 6, height: 6), cornerRadius: 1.5)
    pupil.fillColor = cyan
    pupil.strokeColor = .clear
    pupil.position = CGPoint(x: 2, y: 1)
    player.addChild(pupil)
    let glint = SKShapeNode(rectOf: CGSize(width: 6, height: 6), cornerRadius: 1.5)
    glint.fillColor = .white
    glint.strokeColor = .clear
    glint.position = CGPoint(x: -11, y: 11)
    player.addChild(glint)
    addChild(player)
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { model?.tap() }

  override func didChangeSize(_ oldSize: CGSize) {
    for index in 0..<40 {
      sky.childNode(withName: "star.\(index)")?.position.y =
        290 + Double((index * 91) % 390) / 390 * max(0, size.height - 320)
    }
  }

  override func didFinishUpdate() {
    renderedFrames += 1
    if renderedFrames == 3 {
      onFirstFrame?()
      onFirstFrame = nil
    }
  }

  override func update(_ currentTime: TimeInterval) {
    guard let model else { return }
    let dt = previousTime == 0 ? 0 : min(currentTime - previousTime, 0.1)
    previousTime = currentTime
    model.tick(dt)
    positionWorld()
    let running = model.engine.phase == .running
    let beatPosition = model.engine.x / model.stage.beatDistance
    let beat = Int(beatPosition.rounded(.down))
    let pulse = running ? pow(1 - beatPosition.truncatingRemainder(dividingBy: 1), 3) : 0
    animateWorld(pulse: pulse, x: model.engine.x)
    if running {
      if beat != lastBeat && !reducedMotion { emitBeat() }
      if !reducedMotion {
        trailClock += dt
        if trailClock > 0.03 {
          trailClock = 0
          addTrail()
        }
      }
      if !model.engine.grounded {
        player.zRotation -= dt * 4.5
      } else {
        player.zRotation = 0
        if !wasGrounded { land() }
      }
    }
    lastBeat = beat
    wasGrounded = model.engine.grounded
    if model.engine.phase == .crashed && lastPhase != .crashed { burst() }
    player.isHidden = model.engine.phase == .crashed
    lastPhase = model.engine.phase
  }

  private func positionWorld() {
    guard let model else { return }
    let x = model.engine.x
    world.position.x = anchor - x
    player.position = CGPoint(x: anchor, y: ground + 19 + model.engine.y)
    let ridgeShift = -(x * 0.05).truncatingRemainder(dividingBy: ridgeSpan)
    far.childNode(withName: "ridge.0")?.position.x = ridgeShift
    far.childNode(withName: "ridge.1")?.position.x = ridgeShift + ridgeSpan
    for (index, pillar) in pillars.enumerated() {
      let shift = (Double(index) * 65 - x * 0.14).truncatingRemainder(dividingBy: 1170)
      let position = shift + (x * 0.14 > Double(index) * 65 ? 1170 : 0)
      pillar.base.position.x = position
      pillar.cap.position.x = position
    }
  }

  private func animateWorld(pulse: Double, x: Double) {
    for (index, pillar) in pillars.enumerated() {
      let scale = 1 + pulse * (index % 3 == 0 ? 0.22 : 0.08)
      pillar.base.yScale = pillar.height * scale
      pillar.cap.position.y = ground + pillar.height * scale
    }
    for (index, line) in speedLines.enumerated() {
      let t = (Double(index) / 7 + x / 520).truncatingRemainder(dividingBy: 1)
      let depth = pow(t, 1.9)
      line.position = CGPoint(x: 0, y: ground - depth * ground)
      line.alpha = 0.03 + depth * 0.14
    }
    horizonGlow.alpha = 0.72 + pulse * 0.28
    horizon.alpha = 0.85 + pulse * 0.15
    for plate in plates { plate.alpha = 0.7 + pulse * 0.3 }
    rings.first?.alpha = 0.8 + pulse * 0.2
    player.childNode(withName: "aura")?.setScale(1 + pulse * 0.08)
  }

  private func emitBeat() {
    let ring = SKShapeNode(circleOfRadius: 26)
    ring.strokeColor = cyan.withAlphaComponent(0.45)
    ring.lineWidth = 1.5
    ring.position = player.position
    trail.addChild(ring)
    ring.run(
      .sequence([
        .group([.scale(to: 2.4, duration: 0.4), .fadeOut(withDuration: 0.4)]),
        .removeFromParent(),
      ]))
  }

  private func land() {
    guard !reducedMotion else { return }
    player.run(
      .sequence([
        .scaleX(to: 1.16, y: 0.84, duration: 0.05), .scaleX(to: 1, y: 1, duration: 0.12),
      ]))
    for index in 0..<4 {
      let dust = SKShapeNode(circleOfRadius: 2.5)
      dust.fillColor = cyan.withAlphaComponent(0.6)
      dust.strokeColor = .clear
      dust.position = CGPoint(x: player.position.x - 16 + Double(index) * 10, y: ground + 2)
      trail.addChild(dust)
      dust.run(
        .sequence([
          .group([
            .moveBy(x: -30 - Double(index) * 10, y: 8 + Double(index % 2) * 8, duration: 0.3),
            .fadeOut(withDuration: 0.3),
          ]), .removeFromParent(),
        ]))
    }
  }

  private func addTrail() {
    guard let model else { return }
    let node = SKShapeNode(rectOf: CGSize(width: 26, height: 26), cornerRadius: 5)
    node.fillColor = cyan.withAlphaComponent(0.26)
    node.strokeColor = .clear
    node.position = player.position
    node.zRotation = player.zRotation
    trail.addChild(node)
    node.run(
      .sequence([
        .group([
          .moveBy(x: -model.stage.speed * 0.32, y: 0, duration: 0.32),
          .fadeOut(withDuration: 0.32), .scale(to: 0.2, duration: 0.32),
        ]), .removeFromParent(),
      ]))
  }

  private func burst() {
    guard !reducedMotion else { return }
    let flash = SKShapeNode(circleOfRadius: 40)
    flash.fillColor = coral.withAlphaComponent(0.5)
    flash.strokeColor = .clear
    flash.position = player.position
    addChild(flash)
    flash.run(
      .sequence([
        .group([.scale(to: 3, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent(),
      ]))
    for index in 0..<14 {
      let shard = SKShapeNode(rectOf: CGSize(width: 9, height: 9), cornerRadius: 2)
      shard.fillColor = index % 2 == 0 ? coral : cyan
      shard.strokeColor = .clear
      shard.position = player.position
      addChild(shard)
      let angle = Double(index) * .pi / 7
      shard.run(
        .sequence([
          .group([
            .moveBy(x: cos(angle) * 105, y: sin(angle) * 105, duration: 0.5),
            .fadeOut(withDuration: 0.55), .rotate(byAngle: 2.4, duration: 0.55),
          ]), .removeFromParent(),
        ]))
    }
  }
}
