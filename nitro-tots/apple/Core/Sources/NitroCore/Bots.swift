import Foundation

final class BotDriver {
  let skill: Double
  private let rng: Rng
  private var bias = 0.0
  private var biasTicks = 0, itemHold = 0, lift = 0
  private var prevDrift = false
  init(slot: Int, seed: Int, skill: Double = 0.7) {
    self.skill = skill
    rng = Rng(seed * 7919 + slot * 104729 + 17)
  }
  func drive(_ sim: RaceSim, _ r: Racer) -> KartInput {
    if sim.phase == .countdown {
      return KartInput(throttle: 120 - sim.tick <= 14 + Int((skill * 8).rounded()) ? 1 : 0)
    }
    if sim.isBattle { return battle(sim, r) }
    if biasTicks <= 0 {
      biasTicks = 40 + rng.nextInt(60)
      bias =
        (rng.nextDouble() * 2 - 1) * sim.track.samples[r.nearest].width * (0.12 + 0.2 * (1 - skill))
    }
    biasTicks -= 1
    var avoid = 0.0
    let fwd = V2.angle(r.heading)
    func consider(_ p: V2, _ radius: Double) {
      let d = p - r.pos
      let lon = d.dot(fwd)
      let lat = d.cross(fwd)
      if lon > -4 && lon < 90 && abs(lat) < radius { avoid += (lat > 0 ? -1 : 1) * (2 - lon / 90) }
    }
    for h in sim.track.hazards where h.kind != .roller {
      consider(h.pos, h.kind == .pillar ? 15 : 11)
    }
    for m in sim.movingHazards { consider(m.pos, 12) }
    for d in sim.dropped { consider(d.pos, 9) }
    for p in sim.projectiles where p.kind == .orb { consider(p.pos, 9) }
    let lateral = bias + avoid * 14
    let curvature = Self.curvature(sim, r.nearest)
    let ahead = sim.lookAhead(r) + Int((skill * 3).rounded())
    let err = sim.lineError(r, bias: lateral, lookAhead: ahead)
    let wantsDrift =
      skill > 0.35 && abs(curvature) > 0.2 && r.speed > r.maxSpeed * 0.6
      && err.sign == curvature.sign
    var input = sim.lineInput(r, bias: lateral, lookAhead: ahead, drift: wantsDrift)
    if wantsDrift && r.driftDir == 0 && !prevDrift { input.steer = curvature > 0 ? 1 : -1 }
    if r.driftDir != 0 {
      input.drift = !(abs(curvature) < 0.08 || err * Double(r.driftDir) < -0.12)
    }
    prevDrift = input.drift
    if lift > 0 {
      lift -= 1
      input.throttle = 0.2
    } else if rng.nextInt(1000) < Int(((1 - skill) * 25).rounded()) {
      lift = 8 + rng.nextInt(10)
    }
    if let item = r.item {
      itemHold += 1
      let use: Bool
      switch item {
      case .turbo, .tripleTurbo: use = abs(curvature) < 0.12 && itemHold > 10
      case .rocket: use = itemHold > 15 && r.position > 1
      case .orb:
        use =
          itemHold > 12 && r.position > 1
          && sim.racers.contains {
            let d = $0.pos - r.pos
            return $0.slot != r.slot && d.dot(fwd) > 0 && d.dot(fwd) < 220 && abs(d.cross(fwd)) < 14
          }
      case .slick: use = itemHold > 30 + rng.nextInt(60)
      case .shield: use = itemHold > 40 || threat(sim, r)
      case .zap: use = itemHold > 20
      case .comet: use = itemHold > 5
      }
      if use {
        itemHold = 0
        input.item = true
      }
    } else {
      itemHold = 0
    }
    return input
  }
  private func battle(_ sim: RaceSim, _ r: Racer) -> KartInput {
    let target = sim.racers.filter { $0.slot != r.slot && $0.respawnTicks == 0 }.min {
      $0.pos.distance(r.pos) < $1.pos.distance(r.pos)
    }
    let best = target?.pos.distance(r.pos) ?? .infinity
    var goal = target?.pos ?? r.pos + .angle(r.heading, 50)
    if r.item == nil {
      goal = target?.pos ?? sim.track.samples[0].pos
      var distance = Double.infinity
      for i in sim.track.itemBoxes.indices where sim.itemBoxRespawn[i] == 0 {
        let d = sim.track.itemBoxes[i].distance(r.pos)
        if d < distance {
          distance = d
          goal = sim.track.itemBoxes[i]
        }
      }
    }
    let d = wrap((goal - r.pos).angle - r.heading)
    var input = KartInput(throttle: 1, steer: clamp(d * 2.5, -1, 1))
    if let item = r.item, target != nil {
      switch item {
      case .rocket, .orb: input.item = abs(d) < 0.35 && best < 160
      case .slick: input.item = best < 30
      case .shield: input.item = threat(sim, r) || rng.nextInt(100) < 2
      default: input.item = true
      }
    }
    return input
  }
  private func threat(_ sim: RaceSim, _ r: Racer) -> Bool {
    sim.projectiles.contains { $0.owner != r.slot && $0.pos.distance(r.pos) < 60 }
  }
  static func curvature(_ sim: RaceSim, _ nearest: Int) -> Double {
    let a = sim.track.samples[(nearest + sim.samplesFor(40)) % 512].tangent.angle
    let b = sim.track.samples[(nearest + sim.samplesFor(190)) % 512].tangent.angle
    return wrap(b - a)
  }
}
final class Autopilot {
  let lane: Double
  private var hold = 0
  init(lane: Double) { self.lane = lane }
  func drive(_ sim: RaceSim, _ r: Racer) -> KartInput {
    if sim.phase == .countdown { return KartInput(throttle: 120 - sim.tick <= 18 ? 1 : 0) }
    if sim.isBattle { return BotDriver(slot: r.slot, seed: 1, skill: 0.8).drive(sim, r) }
    var input = sim.lineInput(r, bias: lane, lookAhead: sim.lookAhead(r))
    let curve = BotDriver.curvature(sim, r.nearest)
    if abs(curve) > 0.25 && r.speed > r.maxSpeed * 0.6 {
      input.drift = true
      if r.driftDir == 0 { input.steer = curve > 0 ? 1 : -1 }
    }
    if r.item != nil {
      hold += 1
      if hold > 20 {
        hold = 0
        input.item = true
      }
    }
    return input
  }
}
