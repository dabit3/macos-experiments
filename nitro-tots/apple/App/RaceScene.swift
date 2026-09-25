import SpriteKit
import SwiftUI

#if os(macOS)
  import AppKit
#endif

extension V2 { var point: CGPoint { CGPoint(x: x, y: -y) } }
extension UInt32 {
  var nativeColor: SKColor {
    SKColor(
      red: CGFloat((self >> 16) & 255) / 255, green: CGFloat((self >> 8) & 255) / 255,
      blue: CGFloat(self & 255) / 255, alpha: 1)
  }
  var color: Color {
    Color(
      red: Double((self >> 16) & 255) / 255, green: Double((self >> 8) & 255) / 255,
      blue: Double(self & 255) / 255)
  }
}
@MainActor final class RaceScene: SKScene {
  weak var model: AppModel?
  private let race: RaceSession
  private let world = SKNode(), cameraNode = SKCameraNode(), dynamic = SKNode()
  private var bodies: [Int: SKNode] = [:], labels: [Int: SKLabelNode] = [:]
  private var lastTime = 0.0, camHeading = 0.0
  private var first = true
  private var wasLookingBack = false
  init(model: AppModel, race: RaceSession) {
    self.model = model
    self.race = race
    super.init(size: CGSize(width: 1024, height: 768))
    scaleMode = .resizeFill
    backgroundColor = race.sim.track.theme.ground.nativeColor
    addChild(world)
    addChild(cameraNode)
    camera = cameraNode
    buildTrack()
    world.addChild(dynamic)
    dynamic.zPosition = 5
    for r in race.sim.racers {
      let node = SKNode()
      let shadow = SKShapeNode(ellipseOf: CGSize(width: 17, height: 10))
      shadow.fillColor = .black.withAlphaComponent(0.3)
      shadow.strokeColor = .clear
      shadow.position.y = -3
      node.addChild(shadow)
      let kart = SKSpriteNode(imageNamed: "kart-\(r.profile.kart).png")
      kart.name = "kart"
      kart.size = CGSize(width: 22, height: 26)
      node.addChild(kart)
      let driver = SKShapeNode(circleOfRadius: 4)
      driver.fillColor = Catalog.shared.character(r.profile.character).color.nativeColor
      driver.strokeColor = .white
      driver.position.y = -1
      node.addChild(driver)
      world.addChild(node)
      node.zPosition = 10
      bodies[r.slot] = node
      let label = SKLabelNode(fontNamed: "Nunito-ExtraBold")
      label.text = r.profile.name + (r.profile.bot ? " · BOT" : "")
      label.fontSize = r.slot == race.localSlot ? 7 : 6
      label.fontColor = r.slot == race.localSlot ? .yellow : .white
      label.zPosition = 30
      world.addChild(label)
      labels[r.slot] = label
    }
  }
  required init?(coder: NSCoder) { fatalError("Use init(model:race:)") }
  private func polygon(_ points: [V2], fill: SKColor, z: CGFloat = 0) {
    guard let first = points.first else { return }
    let path = CGMutablePath()
    path.move(to: first.point)
    for p in points.dropFirst() { path.addLine(to: p.point) }
    path.closeSubpath()
    let shape = SKShapeNode(path: path)
    shape.fillColor = fill
    shape.strokeColor = fill
    shape.lineWidth = 0.4
    shape.zPosition = z
    world.addChild(shape)
  }
  private func buildTrack() {
    let track = race.sim.track
    let theme = track.theme
    let tileName =
      track.id == "moss"
      ? "ground-moss"
      : track.id == "frost" ? "ground-ice" : track.id == "tin" ? "ground-asphalt" : "ground-sand"
    for x in stride(from: track.boundsMin.x - 500, through: track.boundsMax.x + 500, by: 250) {
      for y in stride(from: track.boundsMin.y - 500, through: track.boundsMax.y + 500, by: 250) {
        let tile = SKSpriteNode(imageNamed: "\(tileName).jpg")
        tile.size = CGSize(width: 251, height: 251)
        tile.position = V2(x: x, y: y).point
        tile.color = theme.ground.nativeColor
        tile.colorBlendFactor = 0.65
        tile.zPosition = -5
        world.addChild(tile)
      }
    }
    if track.isArena {
      let samples = stride(from: 0, to: track.samples.count, by: 4).map { track.samples[$0].pos }
      polygon(samples, fill: theme.road.nativeColor)
    }
    for shortcut in track.shortcuts {
      polygon(shortcut.polygon, fill: theme.shortcut.nativeColor, z: 0.2)
    }
    for i in track.samples.indices {
      let a = track.samples[i]
      let b = track.samples[(i + 1) % track.samples.count]
      func strip(_ width: Double, _ color: SKColor, _ z: CGFloat) {
        polygon(
          [
            a.pos + a.normal * (a.width / 2 + width), b.pos + b.normal * (b.width / 2 + width),
            b.pos - b.normal * (b.width / 2 + width), a.pos - a.normal * (a.width / 2 + width),
          ], fill: color, z: z)
      }
      strip(6, theme.roadEdge.nativeColor, 0.3)
      strip(3, (i / 5 % 2 == 0 ? theme.curbA : theme.curbB).nativeColor, 0.4)
      strip(0, theme.road.nativeColor, 0.5)
      if i % 9 < 4 && !track.isArena {
        polygon(
          [
            a.pos + a.normal * 0.65, b.pos + b.normal * 0.65, b.pos - b.normal * 0.65,
            a.pos - a.normal * 0.65,
          ],
          fill: .white.withAlphaComponent(0.22), z: 0.6)
      }
    }
    let start = track.samples[0]
    for i in 0..<12 {
      for j in 0..<2 {
        let across = start.normal * ((Double(i) - 5.5) * start.width / 12)
        let along = start.tangent * Double(j * 4)
        let p = start.pos + across + along
        let square = SKSpriteNode(
          color: (i + j) % 2 == 0 ? .white : .black,
          size: CGSize(width: 4, height: start.width / 12))
        square.position = p.point
        square.zRotation = -start.tangent.angle
        square.zPosition = 1
        world.addChild(square)
      }
    }
    for pad in track.boostPads + track.jumps {
      let node = SKShapeNode(rectOf: CGSize(width: pad.length, height: pad.width), cornerRadius: 2)
      node.fillColor =
        track.boostPads.contains(where: { $0.pos == pad.pos }) ? .systemYellow : .systemOrange
      node.strokeColor = .white
      node.position = pad.pos.point
      node.zRotation = -pad.angle
      node.zPosition = 1
      let chevron = SKLabelNode(text: "››")
      chevron.fontSize = 12
      chevron.fontColor = .black
      chevron.verticalAlignmentMode = .center
      node.addChild(chevron)
      world.addChild(node)
    }
    for h in track.hazards where h.kind != .roller {
      let node = SKShapeNode(
        ellipseOf: CGSize(width: h.kind == .pillar ? 16 : 22, height: h.kind == .pillar ? 16 : 15))
      node.fillColor = h.kind == .pillar ? .systemGray : .black.withAlphaComponent(0.75)
      node.strokeColor = h.kind == .pillar ? .white : .purple
      node.position = h.pos.point
      node.zPosition = 2
      world.addChild(node)
    }
    let prop =
      track.id == "moss"
      ? "forest"
      : track.id == "frost"
        ? "ice" : track.id == "tin" ? "tower" : track.id == "bowl" ? "grandstand" : "candy"
    let rng = Rng(4242)
    for i in stride(from: 0, to: track.samples.count, by: 9) {
      let sample = track.samples[i]
      for side in [-1.0, 1.0] {
        let p =
          sample.pos + sample.normal * side
          * (sample.width / 2 + track.grassMargin + 25 + rng.nextDouble() * 25)
        let nearest = track.samples[track.nearest(p)]
        if nearest.pos.distance(p) < nearest.width / 2 + track.grassMargin + 15 { continue }
        if track.shortcuts.contains(where: { $0.contains(p) }) { continue }
        let node = SKSpriteNode(imageNamed: "prop-\(prop).png")
        node.size = CGSize(width: 45, height: 45)
        node.position = p.point
        node.zPosition = 2
        world.addChild(node)
      }
    }
  }
  override func update(_ currentTime: TimeInterval) {
    guard let model else { return }
    let delta = lastTime == 0 ? 0 : min(0.1, currentTime - lastTime)
    lastTime = currentTime
    model.advance(delta)
    guard let me = race.local else { return }
    let pose = race.pose(me)
    let lookBack = race.input.current.lookBack
    let desired = pose.heading + (lookBack ? .pi : 0)
    let snap = first || wasLookingBack != lookBack || model.preferences.reduceMotion
    wasLookingBack = lookBack
    if snap {
      camHeading = desired
    } else {
      camHeading += wrap(desired - camHeading) * min(1, delta * 8)
    }
    if model.preferences.camera == "fixed" && !lookBack {
      cameraNode.zRotation = 0
    } else {
      cameraNode.zRotation = -camHeading - .pi / 2
    }
    let ahead = pose.pos + V2.angle(desired, 18 + abs(me.speed) * 0.18)
    let target = ahead.point
    if snap {
      cameraNode.position = target
      first = false
    } else {
      cameraNode.position.x += (target.x - cameraNode.position.x) * min(1, delta * 9)
      cameraNode.position.y += (target.y - cameraNode.position.y) * min(1, delta * 9)
    }
    let zoom = 240 / max(320, min(size.width, size.height))
    cameraNode.setScale(zoom * (model.preferences.reduceMotion ? 1 : 1 + abs(me.speed) / 1200))
    dynamic.removeAllChildren()
    for r in race.sim.racers {
      let p = race.pose(r)
      guard let body = bodies[r.slot] else { continue }
      body.position = p.pos.point
      body.zRotation = -p.heading - .pi / 2
      body.alpha = r.respawnTicks > 0 ? 0.25 : r.spinTicks > 0 && race.sim.tick % 4 < 2 ? 0.5 : 1
      body.setScale(r.zapTicks > 0 ? 0.65 : r.airTicks > 0 ? 1.2 : 1)
      labels[r.slot]?.position = CGPoint(
        x: p.pos.point.x - sin(cameraNode.zRotation) * 20,
        y: p.pos.point.y + cos(cameraNode.zRotation) * 20)
      labels[r.slot]?.zRotation = cameraNode.zRotation
      if r.shieldTicks > 0 || r.cometTicks > 0 {
        circle(p.pos, radius: 16, color: r.cometTicks > 0 ? .systemOrange : .cyan, alpha: 0.35)
      }
      if race.sim.isBattle {
        for i in 0..<r.balloons {
          circle(p.pos + V2(x: Double(i * 7 - 7), y: -20), radius: 3, color: .systemPink)
        }
      }
      if !model.preferences.reduceMotion && (r.boostTicks > 0 || r.driftDir != 0) {
        let color: SKColor =
          r.boostTicks > 0
          ? .systemOrange
          : r.driftCharge > 90 ? .systemPink : r.driftCharge > 54 ? .systemOrange : .cyan
        let particle = SKShapeNode(circleOfRadius: r.boostTicks > 0 ? 3 : 1.8)
        particle.fillColor = color
        particle.strokeColor = color
        particle.position = (p.pos - V2.angle(p.heading, 12)).point
        particle.zPosition = 4
        world.addChild(particle)
        particle.run(
          .sequence([
            .group([.fadeOut(withDuration: 0.25), .scale(to: 0.1, duration: 0.25)]),
            .removeFromParent(),
          ]))
      }
    }
    for (i, box) in race.sim.track.itemBoxes.enumerated() where race.sim.itemBoxRespawn[i] <= 0 {
      let node = SKShapeNode(rectOf: CGSize(width: 10, height: 10), cornerRadius: 2)
      node.fillColor = .systemPurple
      node.strokeColor = .white
      node.position = box.point
      node.zRotation = model.preferences.reduceMotion ? 0 : currentTime
      let label = SKLabelNode(text: "?")
      label.fontSize = 8
      label.verticalAlignmentMode = .center
      node.addChild(label)
      dynamic.addChild(node)
    }
    for p in race.sim.projectiles {
      circle(p.pos, radius: 4, color: p.kind == .rocket ? .systemRed : .cyan)
    }
    for d in race.sim.dropped { circle(d.pos, radius: 6, color: .systemPurple, alpha: 0.85) }
    for h in race.sim.movingHazards { circle(h.pos, radius: 9, color: .systemOrange) }
    if let ghost = race.ghostPose, race.sim.mode == .timeTrial {
      let node = SKSpriteNode(imageNamed: "kart-\(me.profile.kart).png")
      node.size = CGSize(width: 22, height: 26)
      node.position = ghost.pos.point
      node.zRotation = -ghost.heading - .pi / 2
      node.alpha = 0.3
      dynamic.addChild(node)
    }
    race.events.removeAll()
  }
  private func circle(_ p: V2, radius: CGFloat, color: SKColor, alpha: CGFloat = 1) {
    let node = SKShapeNode(circleOfRadius: radius)
    node.fillColor = color
    node.strokeColor = .white.withAlphaComponent(0.6)
    node.position = p.point
    node.alpha = alpha
    dynamic.addChild(node)
  }
  #if os(macOS)
    override func keyDown(with event: NSEvent) {
      if !event.isARepeat { model?.control(key(event), down: true) }
    }
    override func keyUp(with event: NSEvent) { model?.control(key(event), down: false) }
    override func flagsChanged(with event: NSEvent) {
      model?.control("shift", down: event.modifierFlags.contains(.shift))
      model?.control("control", down: event.modifierFlags.contains(.control))
      model?.control("option", down: event.modifierFlags.contains(.option))
    }
    private func key(_ event: NSEvent) -> String {
      switch event.keyCode {
      case 123: return "left"
      case 124: return "right"
      case 125: return "down"
      case 126: return "up"
      case 49: return "space"
      case 36: return "return"
      case 53: return "escape"
      default: return event.charactersIgnoringModifiers?.lowercased() ?? ""
      }
    }
  #endif
}
