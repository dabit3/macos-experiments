import Foundation

@MainActor final class RaceSession {
  let info: MatchStart, sim: RaceSim, localSlot: Int, online: Bool
  var input = InputBuffer()
  var ghost: Ghost?
  var recording: [Pose] = []
  var events: [Event] = []
  var paused = false
  var send: ((ClientMessage) -> Void)?
  var autopilot: Autopilot?
  private var bots: [Int: BotDriver] = [:]
  private var accumulator = 0.0, snapshotAge = 0.0
  private var previous: [Int: Pose] = [:], current: [Int: Pose] = [:], targets: [Int: Pose] = [:]
  private var history: [(Int, KartInput)] = []
  private var sequence = 0, lastSnapshot = -1
  var local: Racer? { sim.racer(localSlot) }
  init(info: MatchStart, slot: Int, online: Bool, skill: Double = 0.7) {
    self.info = info
    self.localSlot = slot
    self.online = online
    sim = RaceSim(
      track: Catalog.shared.track(info.trackId), racers: info.racers.map(Racer.init),
      seed: info.seed, laps: info.laps, mode: info.mode, battleSeconds: info.battleSeconds)
    let rng = Rng(info.seed + 99)
    for r in sim.racers {
      if r.slot != localSlot {
        bots[r.slot] = BotDriver(
          slot: r.slot, seed: info.seed, skill: clamp(skill - 0.15 + 0.3 * rng.nextDouble(), 0.2, 1)
        )
      }
      current[r.slot] = Pose(pos: r.pos, heading: r.heading)
    }
    previous = current
    targets = current
  }
  func advance(_ delta: Double) {
    if paused && !online { return }
    snapshotAge += delta
    accumulator += min(delta, 0.25)
    while accumulator >= tickDt {
      accumulator -= tickDt
      if let autopilot, let local { input.add(autopilot.drive(sim, local)) }
      let controls = paused ? KartInput() : input.consume()
      previous = current
      if online {
        sequence += 1
        send?(.input(sequence, controls))
        history.append((sequence, controls))
        if history.count > 120 { history.removeFirst(history.count - 120) }
        if snapshotAge < 0.5 { sim.predict(localSlot, controls) }
      } else {
        sim.step([localSlot: controls]) { [self] s, r in bots[r.slot]?.drive(s, r) ?? KartInput() }
        events += sim.events
        if sim.mode == .timeTrial && sim.phase == .racing, let local {
          recording.append(Pose(pos: local.pos, heading: local.heading))
        }
      }
      for r in sim.racers { current[r.slot] = Pose(pos: r.pos, heading: r.heading) }
    }
  }
  func apply(_ snapshot: Snapshot) {
    guard snapshot.tick > lastSnapshot else { return }
    lastSnapshot = snapshot.tick
    for r in sim.racers { previous[r.slot] = pose(r) }
    sim.apply(snapshot)
    for r in sim.racers { targets[r.slot] = Pose(pos: r.pos, heading: r.heading) }
    let ack = snapshot.ack[String(localSlot)] ?? sequence
    history.removeAll { $0.0 <= ack }
    for (_, controls) in history.suffix(8) { sim.predict(localSlot, controls) }
    for r in sim.racers { current[r.slot] = Pose(pos: r.pos, heading: r.heading) }
    snapshotAge = 0
    events += snapshot.events
  }
  func pose(_ r: Racer) -> Pose {
    let a = previous[r.slot] ?? Pose(pos: r.pos, heading: r.heading)
    let b = online && r.slot != localSlot ? targets[r.slot] ?? a : current[r.slot] ?? a
    let alpha = clamp(
      online && r.slot != localSlot ? snapshotAge / (2 * tickDt) : accumulator / tickDt, 0, 1)
    if a.pos.distance(b.pos) > 60 { return b }
    return Pose(
      pos: a.pos.interpolated(b.pos, alpha),
      heading: a.heading + wrap(b.heading - a.heading) * alpha)
  }
  var ghostPose: Pose? {
    guard let ghost, !ghost.frames.isEmpty else { return nil }
    return ghost.frames[min(ghost.frames.count - 1, max(0, sim.tick - 120))]
  }
}
