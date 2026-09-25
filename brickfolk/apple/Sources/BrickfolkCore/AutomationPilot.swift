import Foundation

public struct SeededRNG {
  private var state: Int64
  public init(seed: Int) { state = Int64(abs(seed % 2_147_483_646) + 1) }
  public mutating func next(_ maximum: Int) -> Int {
    guard maximum > 0 else { return 0 }
    state = state * 48_271 % 2_147_483_647
    return Int(state - 1) % maximum
  }
  public mutating func unit() -> Double {
    state = state * 48_271 % 2_147_483_647
    return Double(state - 1) / 2_147_483_646
  }
}

public final class AutomationPilot {
  private var rng: SeededRNG
  private var schedule: [Int: (Int, Int, Int)] = [:]
  private var wanderTicks = 0
  private var wanderX = 0.0
  private var wanderY = 0.0
  private let hesitation: Int
  private var lastSecond = -1
  public init(name: String) {
    let seed = name.utf16.reduce(17) { ($0 &* 31 &+ Int($1)) & 0x7fff_ffff }
    rng = SeededRNG(seed: seed)
    hesitation = 2 + seed % 5
  }
  public func decide(frame: GameFrame, id: String, content: GameContent) -> Input? {
    switch frame {
    case .obby(let frame):
      guard let player = frame.players[id], player.finishTick == nil else { return nil }
      return plan(player, tick: frame.tick, course: content.obby)
    case .tag(let frame):
      guard let me = frame.players[id], !me.frozen else { return .tag(dx: 0, dy: 0) }
      let tagger = frame.players.values.first { $0.isTagger }
      func distance(_ other: TagPlayer) -> Double { hypot(other.x - me.x, other.y - me.y) }
      func toward(_ other: TagPlayer) -> Input {
        let length = max(0.000001, distance(other))
        return .tag(dx: (other.x - me.x) / length, dy: (other.y - me.y) / length)
      }
      if me.isTagger {
        if let target = frame.players.values.filter({ !$0.isTagger && !$0.frozen }).min(by: {
          distance($0) < distance($1)
        }) {
          return toward(target)
        }
        return .tag(dx: 0, dy: 0)
      }
      guard let tagger else { return .tag(dx: 0, dy: 0) }
      if distance(tagger) > 7 {
        if let friend = frame.players.values.filter({ !$0.isTagger && $0.frozen }).min(by: {
          distance($0) < distance($1)
        }) {
          return toward(friend)
        }
        if wanderTicks <= 0 {
          wanderTicks = 20 + rng.next(40)
          wanderX = -1 + rng.unit() * 2
          wanderY = -1 + rng.unit() * 2
        }
        wanderTicks -= 1
        return .tag(dx: wanderX, dy: wanderY)
      }
      let dx = me.x - tagger.x + (content.tag.width / 2 - me.x) * 0.15
      let dy = me.y - tagger.y + (content.tag.height / 2 - me.y) * 0.15
      let length = max(0.000001, hypot(dx, dy))
      return .tag(dx: dx / length, dy: dy / length)
    case .tycoon(let frame):
      let second = frame.ticksLeft / 30
      guard let plot = frame.plots[id], lastSecond != second else { return nil }
      lastSecond = second
      for upgrade in content.upgrades
      where !plot.upgrades.contains(upgrade.id) && plot.cash >= upgrade.cost {
        if Double(plot.income(content: content)) * (upgrade.multiplier - 1) * Double(second)
          > Double(upgrade.cost)
        {
          return .upgrade(upgrade.id)
        }
      }
      let free = plot.cells.indices.filter { plot.cells[$0] == nil }
      guard !free.isEmpty,
        let best = content.bricks.filter({ plot.cash >= $0.cost }).max(by: { $0.income < $1.income }
        )
      else { return nil }
      return .place(cell: free[rng.next(min(3, free.count))], item: best.id)
    }
  }
  private func scheduled(at tick: Int) -> (Int, Int, Int) {
    guard let key = schedule.keys.filter({ $0 <= tick }).max(), let value = schedule[key] else {
      return (0, -1, -1)
    }
    return value
  }
  private func plan(_ observed: ObbyPlayer, tick: Int, course: ObbyCourse) -> Input {
    guard observed.inputLag >= 0 else { return .plan(tick: tick, entries: [[tick, 0]]) }
    var player = PredictedObby(observed)
    let lag = min(90, observed.inputLag)
    for time in tick..<(tick + lag) {
      player.step(course, flags: scheduled(at: time).0, tick: time)
    }
    let start = tick + lag
    let memory = scheduled(at: start - 1)
    var checkpoint = memory.1
    var pauseUntil = memory.2
    var entries: [[Int]] = []
    var time = start
    while time < start + 60 && player.finishTick == nil {
      if player.checkpoint != checkpoint {
        checkpoint = player.checkpoint
        pauseUntil = time + hesitation
      }
      var flags = 0
      if time >= pauseUntil {
        flags = 2
        if player.grounded {
          let front = player.x + 0.4
          let standing = course.platforms.filter {
            $0.kind != "kill" && front > $0.x && player.x - 0.4 < $0.x + $0.w
              && abs(player.y - $0.y - $0.h) < 0.05
          }.max { $0.x + $0.w < $1.x + $1.w }
          var jump = false
          if let standing, standing.x + standing.w - front <= 0.35 {
            jump = !course.platforms.contains {
              $0.kind != "kill" && $0.x <= standing.x + standing.w + 0.05
                && $0.x + $0.w > standing.x + standing.w
                && abs($0.y + $0.h - standing.y - standing.h) < 0.05
            }
          }
          for platform in course.platforms {
            let ahead = platform.x - front
            if platform.kind == "kill" {
              if ahead >= -0.2 && ahead <= 1.1 && abs(platform.y - player.y) < 1 { jump = true }
            } else if platform.y + platform.h > player.y + 0.1
              && platform.y + platform.h <= player.y + 1.6 && ahead >= 0 && ahead <= 1.4
            {
              jump = true
            }
          }
          if jump { flags |= 4 }
        }
      }
      schedule[time] = (flags, checkpoint, pauseUntil)
      if entries.last?.last != flags { entries.append([time, flags]) }
      player.step(course, flags: flags, tick: time)
      time += 1
    }
    entries.append([time, 0])
    schedule[time] = (0, checkpoint, pauseUntil)
    schedule = schedule.filter { $0.key >= tick - 90 && $0.key <= time }
    return .plan(tick: tick, entries: entries)
  }
}

private struct PredictedObby {
  var x, y, vx, vy: Double
  var checkpoint, respawnUntilTick: Int
  var grounded: Bool
  var finishTick: Int?
  init(_ state: ObbyPlayer) {
    x = state.x
    y = state.y
    vx = state.vx
    vy = state.vy
    checkpoint = state.checkpoint
    respawnUntilTick = state.respawnUntilTick
    grounded = state.grounded
    finishTick = state.finishTick
  }
  func overlaps(_ rect: WorldRect) -> Bool {
    x + 0.4 > rect.x && x - 0.4 < rect.x + rect.w && y + 1.6 > rect.y && y < rect.y + rect.h
  }
  mutating func step(_ course: ObbyCourse, flags: Int, tick: Int) {
    guard finishTick == nil, tick >= respawnUntilTick else { return }
    vx = Double((flags & 2 != 0 ? 1 : 0) - (flags & 1 != 0 ? 1 : 0)) * 6
    if flags & 4 != 0 && grounded {
      vy = 11
      grounded = false
    }
    x += vx / 30
    for rect in course.platforms where rect.kind != "kill" {
      if overlaps(rect) {
        if vx > 0 { x = rect.x - 0.401 } else if vx < 0 { x = rect.x + rect.w + 0.401 }
        vx = 0
      }
    }
    let last = course.platforms.last
    x = min((last.map { $0.x + $0.w } ?? course.finishX) + 4, max(-2, x))
    vy = max(-25, vy - 1)
    y += vy / 30
    grounded = false
    var checkpointIndex = -1
    for rect in course.platforms {
      if rect.kind == "checkpoint" { checkpointIndex += 1 }
      if rect.kind == "kill" { continue }
      if overlaps(rect) {
        if vy <= 0 && y - vy / 30 >= rect.y + rect.h - 0.05 {
          y = rect.y + rect.h
          vy = 0
          grounded = true
          if rect.kind == "finish" {
            finishTick = tick
            vx = 0
            return
          }
          if rect.kind == "checkpoint" { checkpoint = max(checkpoint, checkpointIndex) }
        } else if vy > 0 {
          y = rect.y - 1.601
          vy = 0
        }
      }
    }
    if y < -6 || course.platforms.contains(where: { $0.kind == "kill" && overlaps($0) }) {
      x = course.checkpoints[checkpoint].x
      y = course.checkpoints[checkpoint].y
      vx = 0
      vy = 0
      grounded = true
      respawnUntilTick = tick + 18
    }
  }
}
