import Foundation

enum BloomColor: Int, CaseIterable, Codable {
  case gold, rose, iris

  var name: String {
    switch self {
    case .gold: return "Gold"
    case .rose: return "Rose"
    case .iris: return "Iris"
    }
  }

  var mark: String {
    switch self {
    case .gold: return "1"
    case .rose: return "2"
    case .iris: return "3"
    }
  }

  var next: BloomColor { BloomColor(rawValue: (rawValue + 1) % 3) ?? .gold }
}

struct GardenPoint: Equatable, Codable {
  var x: Double
  var y: Double

  func distance(to other: GardenPoint) -> Double {
    hypot(x - other.x, y - other.y)
  }

  func interpolated(to other: GardenPoint, amount: Double) -> GardenPoint {
    GardenPoint(x: x + (other.x - x) * amount, y: y + (other.y - y) * amount)
  }

  static let hive = GardenPoint(x: 0.5, y: 0.91)
}

struct Bloom: Identifiable {
  let id: Int
  let color: BloomColor
  let position: GardenPoint
  var cooldown: Double = 0
}

enum HazardKind { case web, wind }

struct Hazard: Identifiable {
  let id: Int
  let kind: HazardKind
  let position: GardenPoint
  let radius: Double
}

struct GardenMode: Equatable {
  let stage: Int
  let dailySeed: UInt64?

  static func meadow(_ stage: Int) -> GardenMode {
    GardenMode(stage: min(3, max(1, stage)), dailySeed: nil)
  }

  static func daily(on date: Date = Date()) -> GardenMode {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd"
    return GardenMode(stage: 3, dailySeed: UInt64(formatter.string(from: date)) ?? 1)
  }

  var isDaily: Bool { dailySeed != nil }
  var title: String {
    if isDaily { return "Daily garden" }
    return ["", "First light", "Rosewater trail", "The wild canopy"][stage]
  }
  var subtitle: String {
    if isDaily { return "ONE SEED · ENDLESS BLOOMS" }
    return "GARDEN 0\(stage) / 03"
  }
  var target: Int { isDaily ? 0 : [0, 100, 180, 240][stage] }
  var duration: Double { isDaily ? 90 : [0, 85, 95, 105][stage] }
}

struct SeededGarden {
  var state: UInt64

  mutating func next() -> Double {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Double(state >> 11) / Double(UInt64.max >> 11)
  }
}

enum FlightEvent: Equatable {
  case bloom, blossomWave
  case bank(Int)
  case web, wind, wrongColor, emptyHive, full, resting, missed
}

enum RoundEnd: Equatable {
  case blooming, timeout, tangled, dailyComplete
}

struct GardenRules {
  let mode: GardenMode
  var flowers: [Bloom]
  let hazards: [Hazard]
  var bee = GardenPoint.hive
  var expected = BloomColor.gold
  var pollen = 0
  var carriedScore = 0
  var score = 0
  var hearts = 3
  var timeRemaining: Double
  var totalBlooms = 0
  var longestChain = 0
  var waveCount = 0
  var route: [GardenPoint] = [.hive]
  var end: RoundEnd?
  static let capacity = 6

  init(mode: GardenMode) {
    self.mode = mode
    timeRemaining = mode.duration
    let positions: [(BloomColor, Double, Double)] = [
      (.gold, 0.22, 0.67), (.rose, 0.77, 0.68), (.iris, 0.50, 0.47),
      (.gold, 0.81, 0.36), (.rose, 0.19, 0.36), (.iris, 0.51, 0.16),
      (.gold, 0.22, 0.09), (.rose, 0.80, 0.10), (.iris, 0.48, 0.74),
    ]
    var random = SeededGarden(state: mode.dailySeed ?? 1)
    flowers = positions.enumerated().map { index, item in
      let jitterX = mode.isDaily ? (random.next() - 0.5) * 0.07 : 0
      let jitterY = mode.isDaily ? (random.next() - 0.5) * 0.04 : 0
      return Bloom(
        id: index, color: item.0,
        position: GardenPoint(x: item.1 + jitterX, y: item.2 + jitterY))
    }
    var obstacles = [
      Hazard(id: 0, kind: .web, position: GardenPoint(x: 0.87, y: 0.52), radius: 0.065)
    ]
    if mode.stage >= 2 {
      obstacles.append(
        Hazard(id: 1, kind: .wind, position: GardenPoint(x: 0.34, y: 0.52), radius: 0.073))
    }
    if mode.stage >= 3 {
      obstacles.append(
        Hazard(id: 2, kind: .web, position: GardenPoint(x: 0.40, y: 0.29), radius: 0.06))
    }
    hazards = obstacles
  }

  var multiplier: Int { pollen >= 3 ? 2 : 1 }
  var windActive: Bool { Int(mode.duration - timeRemaining) % 9 < 5 }
  var windChangeIn: Int {
    let phase = (mode.duration - timeRemaining).truncatingRemainder(dividingBy: 9)
    return Int(ceil((windActive ? 5 : 9) - phase))
  }

  mutating func tick(_ delta: Double) {
    guard end == nil, delta > 0 else { return }
    timeRemaining = max(0, timeRemaining - delta)
    for index in flowers.indices {
      flowers[index].cooldown = max(0, flowers[index].cooldown - delta)
    }
    if timeRemaining == 0 {
      end = mode.isDaily ? .dailyComplete : .timeout
    }
  }

  static func distance(from point: GardenPoint, toSegment a: GardenPoint, _ b: GardenPoint)
    -> Double
  {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let lengthSquared = dx * dx + dy * dy
    guard lengthSquared > 0 else { return point.distance(to: a) }
    let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared))
    return point.distance(to: a.interpolated(to: b, amount: t))
  }

  static func touches(_ hazard: Hazard, along path: [GardenPoint]) -> Bool {
    zip(path, path.dropFirst()).contains { a, b in
      distance(from: hazard.position, toSegment: a, b) < hazard.radius
    }
  }

  mutating func fly(along path: [GardenPoint]) -> FlightEvent {
    guard end == nil, let destination = path.last, path.count >= 2 else { return .missed }
    let actualPath = [bee] + path.dropFirst()
    route.append(contentsOf: actualPath.dropFirst())
    if route.count > 250 { route.removeFirst(route.count - 250) }
    bee = destination
    if hazards.contains(where: { $0.kind == .web && Self.touches($0, along: actualPath) }) {
      hearts -= 1
      pollen = 0
      carriedScore = 0
      bee = .hive
      expected = .gold
      route.append(.hive)
      if hearts == 0 { end = .tangled }
      return .web
    }
    if windActive
      && hazards.contains(where: { $0.kind == .wind && Self.touches($0, along: actualPath) })
    {
      tick(5)
      return .wind
    }
    if destination.distance(to: .hive) < 0.10 {
      bee = .hive
      guard pollen > 0 else { return .emptyHive }
      let banked = carriedScore
      score += banked
      carriedScore = 0
      pollen = 0
      expected = .gold
      if !mode.isDaily && score >= mode.target { end = .blooming }
      return .bank(banked)
    }
    guard
      let index = flowers.indices.min(by: {
        flowers[$0].position.distance(to: destination)
          < flowers[$1].position.distance(to: destination)
      }), flowers[index].position.distance(to: destination) < 0.105
    else { return .missed }
    bee = flowers[index].position
    guard pollen < Self.capacity else { return .full }
    guard flowers[index].cooldown == 0 else { return .resting }
    guard flowers[index].color == expected else {
      tick(3)
      return .wrongColor
    }
    pollen += 1
    carriedScore += pollen > 3 ? 20 : 10
    totalBlooms += 1
    longestChain = max(longestChain, pollen)
    flowers[index].cooldown = 9
    expected = expected.next
    if pollen == Self.capacity {
      carriedScore += 30
      waveCount += 1
      return .blossomWave
    }
    return .bloom
  }
}

struct GardenProgress: Codable, Equatable {
  var unlockedStage = 1
  var bestScore = 0
  var bestDaily = 0
  var completed: [Int] = []

  mutating func record(_ rules: GardenRules) {
    if rules.mode.isDaily {
      bestDaily = max(bestDaily, rules.score)
    } else {
      bestScore = max(bestScore, rules.score)
      if rules.end == .blooming {
        if !completed.contains(rules.mode.stage) { completed.append(rules.mode.stage) }
        unlockedStage = max(unlockedStage, min(3, rules.mode.stage + 1))
      }
    }
  }

  static func load(from defaults: UserDefaults) -> GardenProgress {
    guard let data = defaults.data(forKey: "nectar.progress"),
      let progress = try? JSONDecoder().decode(GardenProgress.self, from: data)
    else { return GardenProgress() }
    return progress
  }

  func save(to defaults: UserDefaults) {
    if let data = try? JSONEncoder().encode(self) {
      defaults.set(data, forKey: "nectar.progress")
    }
  }
}
