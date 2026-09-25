import Foundation

struct Point: Equatable, Sendable {
  var x: Double
  var z: Double
  static func + (a: Point, b: Point) -> Point { Point(x: a.x + b.x, z: a.z + b.z) }
  static func - (a: Point, b: Point) -> Point { Point(x: a.x - b.x, z: a.z - b.z) }
  static func * (a: Point, b: Double) -> Point { Point(x: a.x * b, z: a.z * b) }
  var length: Double { hypot(x, z) }
  var heading: Double { atan2(x, z) }
}

func angleDifference(_ a: Double, _ b: Double) -> Double {
  atan2(sin(a - b), cos(a - b))
}

struct Projection {
  var point: Point
  var distance: Double
  var offset: Double
  var heading: Double
}

struct Circuit: Sendable {
  let width = 13.0
  let points: [Point]
  let distances: [Double]
  let length: Double

  init() {
    var samples: [Point] = []
    for i in 0...300 {
      let t = Double(i) / 300 * .pi * 2 - .pi / 2
      samples.append(Point(x: 54 * cos(t) + 7 * cos(2 * t), z: 38 * sin(t) + 5 * sin(3 * t)))
    }
    var cumulative = [0.0]
    for i in 1..<samples.count {
      cumulative.append(cumulative[i - 1] + (samples[i] - samples[i - 1]).length)
    }
    points = samples
    distances = cumulative
    length = cumulative.last!
  }

  func at(_ distance: Double, offset: Double = 0) -> (point: Point, heading: Double) {
    let d = (distance.truncatingRemainder(dividingBy: length) + length)
      .truncatingRemainder(dividingBy: length)
    let index = max(
      0, min(points.count - 2, (distances.firstIndex { $0 > d } ?? distances.count - 1) - 1))
    let span = distances[index + 1] - distances[index]
    let delta = points[index + 1] - points[index]
    let position = points[index] + delta * ((d - distances[index]) / span)
    let normal = Point(x: delta.z / span, z: -delta.x / span)
    return (position + normal * offset, delta.heading)
  }

  func project(_ p: Point) -> Projection {
    var best = Double.infinity
    var result = Projection(point: points[0], distance: 0, offset: 0, heading: 0)
    for i in 0..<points.count - 1 {
      let a = points[i]
      let delta = points[i + 1] - a
      let squared = delta.x * delta.x + delta.z * delta.z
      let t = max(0, min(1, ((p.x - a.x) * delta.x + (p.z - a.z) * delta.z) / squared))
      let foot = a + delta * t
      let gap = (p - foot).length
      if gap < best {
        best = gap
        let side = ((p.x - foot.x) * delta.z - (p.z - foot.z) * delta.x) >= 0 ? 1.0 : -1.0
        result = Projection(
          point: foot, distance: distances[i] + sqrt(squared) * t,
          offset: gap * side, heading: delta.heading)
      }
    }
    return result
  }
}

struct LapTracker {
  var previous: Double
  var progress = 0.0
  var nextGate = 1
  var laps = 0

  mutating func update(distance: Double, onTrack: Bool, circuitLength: Double) -> Bool {
    var delta = distance - previous
    if delta < -circuitLength / 2 { delta += circuitLength }
    if delta > circuitLength / 2 { delta -= circuitLength }
    previous = distance
    guard onTrack, abs(delta) < circuitLength / 16 else { return false }
    progress += delta
    let gate = Double(nextGate) * circuitLength / 12
    if progress >= gate {
      nextGate += 1
      if (nextGate - 1) % 12 == 0 {
        laps += 1
        return true
      }
    }
    return false
  }
}

struct Driver {
  var point: Point
  var heading: Double
  var speed = 0.0
  var tracker: LapTracker
  var boost = 0.0
  var driftCharge = 0.0
  var lapStart = 0.0
  var lapTimes: [Double] = []
  var finishTime: Double?
  var lastItemZone = -1
}

enum RaceMode: String, CaseIterable {
  case picnic = "Picnic Cup"
  case trial = "Time Trial"
}

struct RaceEngine {
  let circuit = Circuit()
  var drivers: [Driver] = []
  var elapsed = 0.0
  var mode: RaceMode = .picnic
  var steering = 0.0
  var drifting = false
  var hasItem = false
  var itemsCollected = 0
  var driftBoosts = 0
  var overtakes = 0
  var feedback = ""
  var feedbackRemaining = 0.0
  var offRoad = false
  var finished: Bool { drivers.first?.finishTime != nil }
  var player: Driver { drivers[0] }
  /// Driver indices from leader to last: finishers by time, then everyone else by progress.
  var standings: [Int] {
    drivers.indices.sorted { lhs, rhs in
      let a = drivers[lhs]
      let b = drivers[rhs]
      if let at = a.finishTime, let bt = b.finishTime { return at < bt }
      if a.finishTime != nil { return true }
      if b.finishTime != nil { return false }
      return a.tracker.progress > b.tracker.progress
    }
  }
  var position: Int {
    guard mode == .picnic else { return 1 }
    return 1
      + drivers.dropFirst().filter { rival in
        if let finish = rival.finishTime {
          return player.finishTime.map { finish < $0 } ?? true
        }
        if player.finishTime != nil { return false }
        return rival.tracker.progress > player.tracker.progress
      }.count
  }

  init(mode: RaceMode = .picnic) {
    self.mode = mode
    for index in 0..<(mode == .picnic ? 4 : 1) {
      let distance = 1.0 + Double(3 - index) * 2
      let start = circuit.at(distance, offset: index % 2 == 0 ? -1.8 : 1.8)
      drivers.append(
        Driver(
          point: start.point, heading: start.heading,
          tracker: LapTracker(previous: distance)))
    }
  }

  mutating func useItem() {
    guard hasItem, !finished else { return }
    hasItem = false
    drivers[0].boost = 2.4
    notify("LEMONADE RUSH!")
  }

  mutating func releaseDrift() {
    guard !drivers.isEmpty else { return }
    if drivers[0].driftCharge >= 0.65 {
      drivers[0].boost = max(drivers[0].boost, min(2.2, drivers[0].driftCharge))
      driftBoosts += 1
      notify("SWEET DRIFT!")
    } else {
      notify("HOLD IT LONGER!")
    }
    drivers[0].driftCharge = 0
    drifting = false
  }

  mutating func notify(_ text: String) {
    feedback = text
    feedbackRemaining = 1.8
  }

  mutating func step(_ step: Double) {
    guard !finished else { return }
    let dt = max(0, min(step, 1.0 / 30))
    let oldPosition = position
    elapsed += dt
    feedbackRemaining = max(0, feedbackRemaining - dt)
    for index in drivers.indices {
      guard drivers[index].finishTime == nil else { continue }
      var driver = drivers[index]
      let projection = circuit.project(driver.point)
      let isPlayer = index == 0
      let lookAhead = circuit.at(
        projection.distance + 10,
        offset: isPlayer ? projection.offset * 0.35 : Double(index - 2) * 1.5)
      let desired = (lookAhead.point - driver.point).heading
      let turn: Double
      if isPlayer {
        let assist = max(-0.70, min(0.70, angleDifference(desired, driver.heading) * 1.7))
        turn = assist - steering * (drifting ? 1.65 : 1.30)
      } else {
        turn = max(-1.6, min(1.6, angleDifference(desired, driver.heading) * 3.2))
      }
      driver.heading += turn * dt * min(1, driver.speed / 7)
      driver.boost = max(0, driver.boost - dt)
      let offRoad = abs(projection.offset) > circuit.width / 2 - 0.5
      var targetSpeed = isPlayer ? 17.4 : 17.0 + Double(index) * 0.30
      if driver.boost > 0 { targetSpeed = 26 }
      if offRoad { targetSpeed = 8 }
      if isPlayer { self.offRoad = offRoad }
      if isPlayer && drifting {
        targetSpeed *= 0.90
        if abs(turn) > 0.12 && !offRoad && driver.speed > 10 {
          driver.driftCharge = min(2.2, driver.driftCharge + dt)
        }
      }
      driver.speed += (targetSpeed - driver.speed) * min(1, dt * 2)
      let forward = Point(x: sin(driver.heading), z: cos(driver.heading))
      driver.point = driver.point + forward * (driver.speed * dt)
      let updated = circuit.project(driver.point)
      if abs(updated.offset) > circuit.width / 2 + 1 {
        let side = updated.offset > 0 ? 1.0 : -1.0
        let normal = Point(x: cos(updated.heading), z: -sin(updated.heading))
        driver.point = updated.point + normal * (side * (circuit.width / 2 + 1))
        driver.speed *= 0.92
        driver.heading += angleDifference(updated.heading, driver.heading) * min(1, dt * 3)
      }
      let lap = driver.tracker.update(
        distance: updated.distance, onTrack: abs(updated.offset) <= circuit.width / 2 + 1.5,
        circuitLength: circuit.length)
      if lap {
        driver.lapTimes.append(elapsed - driver.lapStart)
        driver.lapStart = elapsed
        if driver.tracker.laps >= 3 {
          driver.finishTime = elapsed
        } else if isPlayer {
          notify(driver.tracker.laps == 2 ? "FINAL LAP!" : "LAP 2!")
        }
      }
      if isPlayer {
        let zone = Int(updated.distance / (circuit.length / 3))
        let fraction = updated.distance.truncatingRemainder(dividingBy: circuit.length / 3)
        let uniqueZone = driver.tracker.laps * 3 + zone
        if fraction > 35 && fraction < 42 && abs(updated.offset) < 5.5
          && uniqueZone != driver.lastItemZone
        {
          driver.lastItemZone = uniqueZone
          if !hasItem {
            hasItem = true
            itemsCollected += 1
            notify("GOT LEMONADE!")
          }
        }
      }
      drivers[index] = driver
    }
    for index in drivers.indices.dropFirst() {
      let gap = drivers[0].point - drivers[index].point
      if gap.length < 1.6 && gap.length > 0.01 {
        let nudge = gap * ((1.6 - gap.length) * 0.5 / gap.length)
        drivers[0].point = drivers[0].point + nudge
        drivers[index].point = drivers[index].point - nudge
        drivers[0].speed *= 0.985
      }
    }
    if position < oldPosition {
      overtakes += oldPosition - position
      notify(position == 1 ? "YOU LEAD!" : "OVERTAKE!")
    }
  }
}
