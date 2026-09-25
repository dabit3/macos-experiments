import Foundation

let tickDt = 1.0 / 30
let countdownTicks = 120
func driftTier(_ charge: Int) -> Int {
  charge >= 110 ? 3 : (charge >= 60 ? 2 : (charge >= 24 ? 1 : 0))
}
func pointsForPlace(_ place: Int) -> Int {
  (1...8).contains(place) ? [15, 12, 10, 9, 8, 7, 6, 5][place - 1] : 0
}

final class Racer: Identifiable {
  var profile: RacerProfile
  let stats: Stats
  var id: Int { profile.slot }
  var slot: Int { profile.slot }
  var pos = V2.zero
  var heading = 0.0, speed = 0.0
  var driftDir = 0, driftCharge = 0, hopTicks = 0, boostTicks = 0, boostTier = 0
  var boostMult = 1.0
  var airTicks = 0, spinTicks = 0, shieldTicks = 0, zapTicks = 0, cometTicks = 0, stallTicks = 0,
    slipTicks = 0
  var trickReady = false
  var throttleHeldTicks = 0, lap = 0, checkpoint = 0, nearest = 0, position = 1
  var surface = Surface.road
  var finished = false
  var finishTick = 0, lapStartTick = 0
  var lapTicks: [Int] = []
  var item: ItemKind?
  var itemCharges = 0, rouletteTicks = 0, wrongWayTicks = 0, balloons = 3, score = 0,
    respawnTicks = 0
  var prevItemButton = false, prevDrift = false
  var lastHitTick = -1000, bumpCooldown = 0
  var maxSpeed: Double { 74 + 38 * stats.speed }
  init(_ profile: RacerProfile) {
    self.profile = profile
    stats = Stats(profile.character, profile.kart)
  }
  func progress(_ track: Track) -> Double {
    Double(track.checkpoint(nearest) > checkpoint + 2 ? lap - 1 : lap) + Double(nearest) / 512
  }
  func apply(_ s: RacerWire) {
    pos = V2(x: s.x, y: s.y)
    heading = s.h
    speed = s.v
    lap = s.l
    checkpoint = s.c
    nearest = mod(s.n, 512)
    position = s.p
    driftDir = s.d
    driftCharge = s.dc
    boostTicks = s.b
    boostTier = s.bt
    boostMult = [1, 1.24, 1.3, 1.38, 1.75][min(4, max(0, boostTier))]
    airTicks = s.a
    spinTicks = s.sp
    shieldTicks = s.sh
    zapTicks = s.z
    cometTicks = s.cm
    stallTicks = s.st
    hopTicks = s.hp
    item = s.i
    itemCharges = s.ic
    rouletteTicks = s.ro
    finished = s.f == 1
    finishTick = s.ft
    lapTicks = s.lt
    lapStartTick = s.ls
    wrongWayTicks = s.ww
    balloons = s.bl
    score = s.sc
    respawnTicks = s.rs
    surface = Surface(rawValue: s.su) ?? .road
    prevItemButton = s.pi == 1
    prevDrift = s.pd == 1
    throttleHeldTicks = s.th
  }
}
final class Projectile {
  let id: Int, kind: ItemKind, owner: Int
  var pos: V2
  var heading, speed: Double
  var target: Int?
  var bounces = 0, life = 0, nearest = 0
  init(
    id: Int, kind: ItemKind, owner: Int, pos: V2, heading: Double, speed: Double, target: Int? = nil
  ) {
    self.id = id
    self.kind = kind
    self.owner = owner
    self.pos = pos
    self.heading = heading
    self.speed = speed
    self.target = target
  }
}
final class Drop {
  let id: Int, pos: V2, owner: Int
  var life = 0
  init(id: Int, pos: V2, owner: Int) {
    self.id = id
    self.pos = pos
    self.owner = owner
  }
}
final class MovingHazard {
  let def: Hazard
  var pos: V2
  var phase = 0.0
  init(_ def: Hazard) {
    self.def = def
    pos = def.pos
  }
}

final class RaceSim {
  let track: Track, racers: [Racer], rng: Rng
  let laps: Int, mode: GameMode, battleSeconds: Int
  var tick = 0, firstFinishTick = -1
  var phase = RacePhase.countdown
  var projectiles: [Projectile] = []
  var dropped: [Drop] = []
  var itemBoxRespawn: [Int]
  var movingHazards: [MovingHazard]
  var events: [Event] = []
  var results: [RaceResult]?
  private var nextId = 1
  var isBattle: Bool { mode == .battle }
  var battleTicksLeft: Int { max(0, 120 + battleSeconds * 30 - tick) }
  init(
    track: Track, racers: [Racer], seed: Int, laps: Int = 3, mode: GameMode = .race,
    battleSeconds: Int = 120
  ) {
    self.track = track
    self.racers = racers
    self.rng = Rng(seed)
    self.laps = laps
    self.mode = mode
    self.battleSeconds = battleSeconds
    itemBoxRespawn = Array(repeating: 0, count: track.itemBoxes.count)
    movingHazards = track.hazards.filter { $0.kind == .roller }.map(MovingHazard.init)
    for r in racers {
      r.pos = track.startGrid[mod(r.slot, track.startGrid.count)]
      if track.isArena { r.pos = track.samples[r.slot * 512 / racers.count].pos }
      r.nearest = track.nearest(r.pos)
      r.heading = track.samples[r.nearest].tangent.angle
    }
  }
  func racer(_ slot: Int) -> Racer? { racers.first { $0.slot == slot } }
  func emit(
    _ type: String, _ r: Racer? = nil, other: Int? = nil, value: Int? = nil, item: ItemKind? = nil
  ) {
    events.append(Event(e: type, r: r?.slot, o: other, v: value, k: item))
  }
  func step(_ inputs: [Int: KartInput], bot: (RaceSim, Racer) -> KartInput) {
    events.removeAll(keepingCapacity: true)
    if phase == .finished {
      tick += 1
      return
    }
    if phase == .countdown && tick >= 120 {
      phase = .racing
      emit("go")
      for r in racers {
        r.lapStartTick = tick
        if r.throttleHeldTicks > 0 && r.throttleHeldTicks <= 45 {
          boost(r, 30, 1.3, 1)
          emit("rocketStart", r)
        } else if r.throttleHeldTicks > 45 {
          r.stallTicks = 24
          emit("stall", r)
        }
      }
    }
    for r in racers {
      stepRacer(
        r,
        r.profile.bot || r.profile.playerId.isEmpty ? bot(self, r) : inputs[r.slot] ?? KartInput())
    }
    collisions()
    stepProjectiles()
    stepHazards()
    updatePositions()
    checkFinish()
    tick += 1
  }
  func predict(_ slot: Int, _ input: KartInput) {
    events.removeAll(keepingCapacity: true)
    guard let r = racer(slot), phase != .finished else {
      tick += 1
      return
    }
    if phase == .countdown && tick >= 120 {
      phase = .racing
      r.lapStartTick = tick
    }
    stepRacer(r, input)
    collisions()
    tick += 1
  }
  private func stepRacer(_ r: Racer, _ input: KartInput) {
    if phase == .countdown {
      r.throttleHeldTicks = input.throttle > 0.5 ? r.throttleHeldTicks + 1 : 0
      r.speed = 0
      return
    }
    r.boostTicks = max(0, r.boostTicks - 1)
    if r.boostTicks == 0 {
      r.boostMult = 1
      r.boostTier = 0
    }
    r.shieldTicks = max(0, r.shieldTicks - 1)
    r.zapTicks = max(0, r.zapTicks - 1)
    r.spinTicks = max(0, r.spinTicks - 1)
    r.stallTicks = max(0, r.stallTicks - 1)
    r.hopTicks = max(0, r.hopTicks - 1)
    r.bumpCooldown = max(0, r.bumpCooldown - 1)
    if r.rouletteTicks > 0 {
      r.rouletteTicks -= 1
      if r.rouletteTicks == 0 { awardItem(r) }
    }
    if r.respawnTicks > 0 {
      r.respawnTicks -= 1
      r.speed = 0
      if r.respawnTicks == 0 {
        r.balloons = 3
        emit("respawn", r)
      }
      return
    }
    if r.finished {
      r.heading = turn(r.heading, track.samples[r.nearest].tangent.angle, 2.5 * tickDt)
      r.speed = max(0, r.speed - 40 * tickDt)
      r.pos = r.pos + .angle(r.heading, r.speed * tickDt)
      r.nearest = track.nearest(r.pos, r.nearest)
      return
    }
    var effective = input
    if r.cometTicks > 0 {
      r.cometTicks -= 1
      effective = lineInput(r, lookAhead: lookAhead(r) + 4)
      r.boostTicks = 2
      r.boostMult = 1.75
      r.boostTier = 4
      if r.cometTicks == 0 {
        r.boostTicks = 20
        r.boostMult = 1.3
        r.boostTier = 2
        emit("cometEnd", r)
      }
    }
    if input.item && !r.prevItemButton { useItem(r, input.lookBack) }
    r.prevItemButton = input.item
    let controllable = r.spinTicks == 0 && r.stallTicks == 0
    let surfaceMult = r.surface == .offroad && r.boostTicks == 0 && r.cometTicks == 0 ? 0.55 : 1.0
    let maxSpeed =
      r.maxSpeed * surfaceMult * (r.zapTicks > 0 ? 0.7 : 1) * (r.boostTicks > 0 ? r.boostMult : 1)
    let accel = 34 + 46 * r.stats.accel
    if !controllable {
      r.speed =
        r.spinTicks > 0
        ? max(min(r.speed, 22), r.speed - 80 * tickDt) : max(0, r.speed - 80 * tickDt)
      if r.spinTicks > 0 { r.heading += 10 * tickDt }
    } else {
      let throttle = clamp(effective.throttle, -1, 1)
      if throttle > 0 {
        if r.speed < maxSpeed {
          r.speed = min(maxSpeed, r.speed + accel * throttle * tickDt * (r.boostTicks > 0 ? 3 : 1))
        } else {
          r.speed = max(maxSpeed, r.speed - 60 * tickDt)
        }
      } else if throttle < 0 {
        r.speed = r.speed > 0 ? max(0, r.speed - 95 * tickDt) : max(-24, r.speed - 30 * tickDt)
      } else {
        r.speed = r.speed > 0 ? max(0, r.speed - 28 * tickDt) : min(0, r.speed + 28 * tickDt)
      }
      if r.surface == .offroad && r.speed > maxSpeed {
        r.speed = max(maxSpeed, r.speed - 120 * tickDt)
      }
    }
    if controllable && r.airTicks == 0 {
      let steer = clamp(effective.steer, -1, 1)
      let baseRate = 2 + 1.6 * r.stats.handling
      let speedRatio = clamp(abs(r.speed) / r.maxSpeed, 0, 1.4)
      let grip = min(1, abs(r.speed) / 18) * (1 - 0.3 * min(1, speedRatio))
      let wantsDrift = effective.drift && r.speed > r.maxSpeed * 0.45
      if effective.drift && !r.prevDrift && r.speed > 10 { r.hopTicks = 8 }
      if r.driftDir == 0 && wantsDrift && abs(steer) > 0.25 && effective.drift
        && (!r.prevDrift || r.hopTicks > 0)
      {
        r.driftDir = steer > 0 ? 1 : -1
        r.driftCharge = 0
        emit("driftStart", r)
      }
      if r.driftDir != 0 {
        if !wantsDrift {
          releaseDrift(r)
        } else {
          let into = steer * Double(r.driftDir)
          r.heading +=
            Double(r.driftDir) * baseRate * grip
            * (0.55 + 0.95 * max(0, into) + 0.25 * clamp(into, -1, 0)) * tickDt
          r.driftCharge += into > 0.3 ? 2 : 1
          if [24, 60, 110].contains(r.driftCharge) {
            emit("driftTier", r, value: driftTier(r.driftCharge))
          }
        }
      } else {
        r.heading += steer * baseRate * grip * (r.speed >= 0 ? 1 : -1) * tickDt
      }
      r.prevDrift = effective.drift
    } else if r.airTicks > 0 {
      if effective.drift && !r.prevDrift {
        r.trickReady = true
        emit("trick", r)
      }
      r.prevDrift = effective.drift
    }
    r.pos = r.pos + .angle(r.heading - Double(r.driftDir) * 0.2, r.speed * tickDt)
    if r.airTicks > 0 {
      r.airTicks -= 1
      if r.airTicks == 0 {
        if r.trickReady {
          boost(r, 24, 1.28, 2)
          emit("trickLand", r)
        }
        r.trickReady = false
        emit("land", r)
      }
    }
    r.nearest = track.nearest(r.pos, r.nearest)
    r.surface = track.surface(r.pos, r.nearest)
    if r.surface == .wall { hitWall(r) }
    if r.airTicks == 0 {
      for pad in track.boostPads where pad.contains(r.pos) {
        if r.boostTier < 2 || r.boostTicks < 10 {
          boost(r, 30, 1.35, 2)
          emit("pad", r)
        }
        break
      }
      for jump in track.jumps where jump.contains(r.pos) && r.speed > 30 {
        r.airTicks = 18
        r.trickReady = false
        r.driftDir = 0
        r.driftCharge = 0
        emit("jump", r)
        break
      }
      for i in track.itemBoxes.indices where itemBoxRespawn[i] == 0 {
        if track.itemBoxes[i].distance(r.pos) < 6.5 && r.item == nil && r.rouletteTicks == 0 {
          itemBoxRespawn[i] = 90
          r.rouletteTicks = 40
          emit("pickup", r, value: i)
        }
      }
      let vulnerable = r.spinTicks == 0 && r.cometTicks == 0 && tick - r.lastHitTick > 90
      for h in track.hazards {
        if h.kind == .oilSlick && h.pos.distance(r.pos) < 6 && vulnerable {
          spinOut(r, -1, .slick)
        } else if h.kind == .pillar {
          let d = r.pos - h.pos
          if d.length < 9 {
            r.pos = h.pos + d.normalized * 9.2
            r.heading += V2.angle(r.heading).cross(d) >= 0 ? 0.25 : -0.25
            r.speed *= 0.6
            r.driftDir = 0
            emit("bump", r)
          }
        }
      }
      for m in movingHazards where m.pos.distance(r.pos) < 8 && vulnerable {
        spinOut(r, -1, .slick)
      }
      for d in dropped
      where d.pos.distance(r.pos) < 6 && vulnerable && (d.owner != r.slot || d.life > 20) {
        if r.shieldTicks > 0 {
          r.shieldTicks = 0
          emit("shieldPop", r)
        } else if r.spinTicks == 0 {
          spinOut(r, d.owner, .slick)
        }
        d.life = -1
      }
    }
    dropped.removeAll { $0.life < 0 }
    var slip = false
    for o in racers where o.slot != r.slot {
      let d = o.pos - r.pos
      let fwd = V2.angle(r.heading)
      let lon = d.dot(fwd)
      if lon > 4 && lon < 38 && abs(d.cross(fwd)) < 6 && r.speed > r.maxSpeed * 0.7 {
        slip = true
        break
      }
    }
    if slip {
      r.slipTicks += 1
      if r.slipTicks == 36 {
        boost(r, 24, 1.18, 1)
        emit("slipstream", r)
        r.slipTicks = 0
      }
    } else {
      r.slipTicks = 0
    }
    updateLap(r)
  }
  func boost(_ r: Racer, _ ticks: Int, _ mult: Double, _ tier: Int) {
    if r.boostTicks > 0 && r.boostMult > mult {
      r.boostTicks = max(r.boostTicks, ticks)
      return
    }
    r.boostTicks = max(r.boostTicks, ticks)
    r.boostMult = mult
    r.boostTier = tier
  }
  private func releaseDrift(_ r: Racer) {
    let tier = driftTier(r.driftCharge)
    if tier > 0 {
      boost(r, [0, 16, 30, 46][tier], [1, 1.24, 1.3, 1.38][tier], tier)
      emit("miniTurbo", r, value: tier)
    }
    r.driftDir = 0
    r.driftCharge = 0
  }
  private func hitWall(_ r: Racer) {
    let s = track.samples[r.nearest]
    let lat = track.lateral(r.pos, r.nearest)
    let limit = s.width / 2 + (track.isArena ? 0 : track.grassMargin) - 0.5
    let side = lat > 0 ? 1.0 : -1.0
    r.pos = r.pos + s.normal * ((limit - 1.5) * side - lat)
    let into = clamp(V2.angle(r.heading).dot(s.normal * side), 0, 1)
    if into > 0 {
      let along = s.tangent * (V2.angle(r.heading).dot(s.tangent) >= 0 ? 1 : -1)
      r.heading = turn(r.heading, along.angle, asin(into) + 0.02)
    }
    if into > 0.3 && r.speed > 20 { emit("wall", r) }
    r.speed *= 1 - 0.6 * into
    r.driftDir = 0
    r.driftCharge = 0
  }
  private func spinOut(_ r: Racer, _ owner: Int, _ cause: ItemKind) {
    if r.shieldTicks > 0 {
      r.shieldTicks = 0
      emit("shieldPop", r)
      return
    }
    r.spinTicks = 36
    r.driftDir = 0
    r.driftCharge = 0
    r.boostTicks = 0
    r.boostMult = 1
    r.speed *= 0.4
    r.lastHitTick = tick
    r.rouletteTicks = 0
    emit("hit", r, other: owner, item: cause)
    if isBattle && r.balloons > 0 {
      r.balloons -= 1
      if let attacker = racer(owner), attacker.slot != r.slot {
        attacker.score += 1
        emit("score", attacker, other: r.slot, value: attacker.score)
      }
      if r.balloons == 0 {
        r.respawnTicks = 90
        r.item = nil
        r.itemCharges = 0
        emit("knockout", r, other: owner)
      }
    }
  }
  private func updateLap(_ r: Racer) {
    if track.isArena { return }
    let sector = track.checkpoint(r.nearest)
    r.wrongWayTicks =
      V2.angle(r.heading).dot(track.samples[r.nearest].tangent) < -0.3 && r.speed > 5
      ? r.wrongWayTicks + 1 : 0
    let crossed = sector == 0 && (r.checkpoint == 5 || r.checkpoint == 4) && r.nearest < 64
    if !crossed && (sector == (r.checkpoint + 1) % 6 || sector == (r.checkpoint + 2) % 6)
      && sector != 0
    {
      r.checkpoint = sector
    }
    if crossed {
      r.checkpoint = 0
      r.lap += 1
      r.lapTicks.append(tick - r.lapStartTick)
      r.lapStartTick = tick
      if r.lap >= laps && !r.finished {
        r.finished = true
        r.finishTick = tick
        if firstFinishTick < 0 { firstFinishTick = tick }
        emit("finish", r, value: tick)
      } else if !r.finished {
        emit("lap", r, value: r.lap)
      }
    }
  }
  private func awardItem(_ r: Racer) {
    let odds = [
      [0, 0, 0, 30, 40, 30, 0, 0], [20, 0, 25, 30, 10, 15, 0, 0], [20, 0, 30, 30, 10, 10, 0, 0],
      [30, 15, 30, 10, 0, 10, 5, 0], [30, 15, 30, 10, 0, 10, 5, 0], [20, 30, 20, 0, 0, 0, 15, 15],
      [20, 30, 20, 0, 0, 0, 15, 15], [0, 25, 15, 0, 0, 0, 25, 35],
    ]
    let row =
      racers.count <= 1
      ? 0 : min(7, max(0, Int((Double(r.position - 1) * 7 / Double(racers.count - 1)).rounded())))
    r.item = ItemKind.allCases[rng.weighted(isBattle ? [15, 5, 30, 30, 10, 10, 0, 0] : odds[row])]
    r.itemCharges = r.item == .tripleTurbo ? 3 : 1
    emit("item", r, item: r.item)
  }
  private func useItem(_ r: Racer, _ back: Bool) {
    guard let kind = r.item, r.spinTicks == 0, r.respawnTicks == 0 else { return }
    emit("use", r, item: kind)
    switch kind {
    case .turbo, .tripleTurbo:
      boost(r, 40, 1.4, 3)
      if kind == .tripleTurbo { r.itemCharges -= 1 }
      if kind == .turbo || r.itemCharges <= 0 { r.item = nil }
    case .rocket, .orb:
      let candidates = racers.filter {
        $0.slot != r.slot && !$0.finished
          && (back ? $0.position > r.position : $0.position < r.position)
      }
      let target = candidates.sorted {
        back ? $0.position < $1.position : $0.position > $1.position
      }.first
      let dir = r.heading + (back ? .pi : 0)
      let p = Projectile(
        id: nextId, kind: kind, owner: r.slot, pos: r.pos + .angle(dir, 8), heading: dir,
        speed: r.maxSpeed * (kind == .rocket ? 1.55 : 1.4),
        target: kind == .rocket ? target?.slot : nil)
      p.nearest = r.nearest
      projectiles.append(p)
      nextId += 1
      r.item = nil
    case .slick:
      dropped.append(
        Drop(
          id: nextId, pos: r.pos + .angle(r.heading + (back ? 0 : .pi), back ? 60 : 9),
          owner: r.slot))
      nextId += 1
      r.item = nil
    case .shield:
      r.shieldTicks = 240
      r.item = nil
    case .zap:
      for o in racers where o.slot != r.slot && !o.finished && o.cometTicks == 0 {
        if o.shieldTicks > 0 {
          o.shieldTicks = 0
          emit("shieldPop", o)
          continue
        }
        spinOut(o, r.slot, .zap)
        o.zapTicks = 120
        if o.item != nil && rng.nextInt(2) == 0 { o.item = nil }
      }
      r.item = nil
    case .comet:
      r.cometTicks = 105
      r.spinTicks = 0
      r.driftDir = 0
      r.item = nil
    }
  }
  private func stepProjectiles() {
    for p in projectiles {
      p.life += 1
      if p.kind == .rocket {
        if let target = p.target.flatMap(racer), !target.finished {
          p.heading = turn(p.heading, (target.pos - p.pos).angle, 3.2 * tickDt)
        } else {
          p.nearest = track.nearest(p.pos, p.nearest)
          p.heading = turn(
            p.heading, (track.samples[(p.nearest + 10) % 512].pos - p.pos).angle, 3 * tickDt)
        }
        if p.life > 270 { p.life = -1 }
      } else if p.life > 300 {
        p.life = -1
      }
      if p.life < 0 { continue }
      p.pos = p.pos + .angle(p.heading, p.speed * tickDt)
      p.nearest = track.nearest(p.pos, p.nearest)
      if track.surface(p.pos, p.nearest) == .wall {
        if p.kind == .orb && p.bounces < 6 {
          let s = track.samples[p.nearest]
          let lat = track.lateral(p.pos, p.nearest)
          let limit = s.width / 2 + (track.isArena ? 0 : track.grassMargin) - 1
          p.pos = s.pos + s.normal * (limit * (lat > 0 ? 1 : -1))
          let v = V2.angle(p.heading)
          p.heading = (v - s.normal * (2 * v.dot(s.normal))).angle
          p.bounces += 1
          emit("orbBounce", racer(p.owner))
        } else {
          p.life = -1
          emit("projectileGone", racer(p.owner), item: p.kind)
          continue
        }
      }
      for r in racers {
        if r.finished || r.respawnTicks > 0 || (r.slot == p.owner && p.life < 12)
          || tick - r.lastHitTick < 30 || r.cometTicks > 0
        {
          continue
        }
        if r.pos.distance(p.pos) < 7 {
          spinOut(r, p.owner, p.kind)
          p.life = -1
          break
        }
      }
    }
    projectiles.removeAll { $0.life < 0 }
    for i in itemBoxRespawn.indices { itemBoxRespawn[i] = max(0, itemBoxRespawn[i] - 1) }
    for d in dropped { d.life += 1 }
  }
  private func stepHazards() {
    for m in movingHazards {
      m.phase += tickDt * 1.1
      m.pos = m.def.pos + V2.angle(m.def.angle).normal * (sin(m.phase) * m.def.range)
    }
  }
  private func collisions() {
    for i in racers.indices {
      let a = racers[i]
      if a.respawnTicks > 0 || a.airTicks > 0 { continue }
      for j in (i + 1)..<racers.count {
        let b = racers[j]
        if b.respawnTicks > 0 || b.airTicks > 0 { continue }
        let d = b.pos - a.pos
        let dist = d.length
        if dist < 8.4 && dist > 0.001 {
          let overlap = 8.4 - dist
          let n = d * (1 / dist)
          let ma = a.stats.mass + (a.cometTicks > 0 ? 3 : 0)
          let mb = b.stats.mass + (b.cometTicks > 0 ? 3 : 0)
          let total = ma + mb
          a.pos = a.pos - n * (overlap * mb / total)
          b.pos = b.pos + n * (overlap * ma / total)
          let avg = (a.speed + b.speed) / 2
          a.speed = lerp(a.speed, avg, 0.35 * (mb / total) * 2)
          b.speed = lerp(b.speed, avg, 0.35 * (ma / total) * 2)
          if a.cometTicks > 0 && b.cometTicks == 0 { spinOut(b, a.slot, .orb) }
          if b.cometTicks > 0 && a.cometTicks == 0 { spinOut(a, b.slot, .orb) }
          if a.bumpCooldown == 0 && b.bumpCooldown == 0 {
            emit("bump", a, other: b.slot)
            a.bumpCooldown = 10
            b.bumpCooldown = 10
          }
        }
      }
    }
  }
  func ordered() -> [Racer] {
    racers.sorted {
      if isBattle {
        if $0.score != $1.score { return $0.score > $1.score }
        if $0.balloons != $1.balloons { return $0.balloons > $1.balloons }
      } else {
        if $0.finished && $1.finished { return $0.finishTick < $1.finishTick }
        if $0.finished != $1.finished { return $0.finished }
        if $0.progress(track) != $1.progress(track) {
          return $0.progress(track) > $1.progress(track)
        }
      }
      return $0.slot < $1.slot
    }
  }
  private func updatePositions() { for (i, r) in ordered().enumerated() { r.position = i + 1 } }
  private func checkFinish() {
    guard phase == .racing else { return }
    if isBattle {
      if battleTicksLeft == 0 { finish() }
      return
    }
    let humans = racers.filter { !$0.profile.bot && !$0.profile.playerId.isEmpty }
    let done = (humans.isEmpty ? racers : humans).allSatisfy(\.finished)
    let timeUp = firstFinishTick >= 0 && tick - firstFinishTick > 900
    let botsClose = racers.filter { !$0.finished }.allSatisfy { $0.lap >= laps - 1 }
    if racers.allSatisfy(\.finished) || (done && (timeUp || botsClose)) || timeUp { finish() }
  }
  private func finish() {
    phase = .finished
    var lastFinish = racers.filter(\.finished).reduce(tick) { max($0, $1.finishTick) }
    results = ordered().enumerated().map { i, r in
      if !r.finished { lastFinish += 30 }
      return RaceResult(
        slot: r.slot, name: r.profile.name, character: r.profile.character, kart: r.profile.kart,
        bot: r.profile.bot, platform: r.profile.platform, place: i + 1,
        finishTick: r.finished ? r.finishTick : lastFinish,
        lapTicks: r.lapTicks, points: pointsForPlace(i + 1), score: r.score)
    }
    emit("raceOver")
  }
  func samplesFor(_ distance: Double) -> Int {
    max(3, Int((distance / (track.length / 512)).rounded()))
  }
  func lookAhead(_ r: Racer) -> Int { samplesFor(clamp(0.8 * abs(r.speed) + 30, 50, 120)) }
  func lineError(_ r: Racer, bias: Double = 0, lookAhead: Int = 16) -> Double {
    let s = track.samples[(r.nearest + lookAhead) % 512]
    return wrap((s.pos + s.normal * bias - r.pos).angle - (r.heading - Double(r.driftDir) * 0.2))
  }
  func lineInput(_ r: Racer, bias: Double = 0, lookAhead: Int = 16, drift: Bool = false)
    -> KartInput
  {
    KartInput(
      throttle: 1, steer: clamp(lineError(r, bias: bias, lookAhead: lookAhead) * 2.2, -1, 1),
      drift: drift)
  }
  func apply(_ s: Snapshot) {
    tick = s.tick
    phase = s.phase
    for state in s.racers { racer(state.s)?.apply(state) }
    projectiles = s.proj.map {
      Projectile(
        id: $0.id, kind: $0.k, owner: $0.o, pos: V2(x: $0.x, y: $0.y), heading: $0.h, speed: 0)
    }
    dropped = s.drop.map { Drop(id: $0.id, pos: V2(x: $0.x, y: $0.y), owner: $0.o) }
    let gone = Set(s.boxes)
    for i in itemBoxRespawn.indices { itemBoxRespawn[i] = gone.contains(i) ? 1 : 0 }
    for i in 0..<min(s.mov.count, movingHazards.count) { movingHazards[i].pos = s.mov[i] }
    events = s.events
  }
}
