import Foundation

struct V2: Equatable {
  var x: Double = 0
  var y: Double = 0
  static let zero = V2()
  static func + (lhs: V2, rhs: V2) -> V2 { V2(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
  static func - (lhs: V2, rhs: V2) -> V2 { V2(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
  static func * (lhs: V2, rhs: Double) -> V2 { V2(x: lhs.x * rhs, y: lhs.y * rhs) }
  var length: Double { sqrt(x * x + y * y) }
  var normalized: V2 { length > 0.001 ? self * (1 / length) : .zero }
}

struct SeededRandom {
  var state: UInt64
  mutating func next() -> Double {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Double(state >> 11) / Double(UInt64.max >> 11)
  }
}

enum Upgrade: String, CaseIterable, Identifiable {
  case lantern, orbit, nova, haste, vitality, magnet
  var id: String { rawValue }
  var title: String {
    switch self {
    case .lantern: return "Golden volley"
    case .orbit: return "Moonpetal orbit"
    case .nova: return "Dawn bell"
    case .haste: return "Windswept"
    case .vitality: return "Wildheart"
    case .magnet: return "Gem whisper"
    }
  }
  var symbol: String {
    switch self {
    case .lantern: return "sparkles"
    case .orbit: return "moonphase.waning.crescent"
    case .nova: return "sun.max"
    case .haste: return "wind"
    case .vitality: return "heart"
    case .magnet: return "diamond"
    }
  }
  func detail(after rank: Int) -> String {
    let next = rank + 1
    switch self {
    case .lantern:
      return "\(min(7, next + 1)) bolts per volley · \(18 + next * 5) damage each."
    case .orbit:
      return "\(min(5, next + 1)) circling blades · \(12 + next * 5) damage per strike."
    case .nova:
      return
        "\(30 + next * 15) area damage every \(String(format: "%.1f", max(1.8, 5 - Double(next) * 0.4))) seconds."
    case .haste: return "Move 12% faster. Your lantern fires 10% sooner."
    case .vitality: return "Restore 35 health and grow your maximum by 15."
    case .magnet: return "\(63 + next * 24) reach · \(next * 10)% bonus light from gems."
    }
  }
}

enum RunPhase: Equatable { case playing, choosing, paused, victory, defeat }
enum EnemyKind: Int { case shade, moth, thorn, boss }

enum DefeatCause {
  case thorns, shade, moth, thorn, boss, dawn, ended
  var advice: String {
    switch self {
    case .thorns: return "Caught in a thorn bloom.\nLeave the rose ring before its countdown ends."
    case .shade:
      return "A wandering shade caught your light.\nKeep circling and gather the gems behind you."
    case .moth: return "A dusk moth caught your light.\nMake space when the violet wings approach."
    case .thorn:
      return "An ancient thorn caught your light.\nKeep your distance from the heavy guardians."
    case .boss:
      return "The Hollow Gardener caught your light.\nCircle the crown and let your weapons work."
    case .dawn:
      return
        "Dawn arrived, but the Gardener still stood.\nFollow the golden arrow and finish the fight."
    case .ended: return "You set down the lantern.\nThe garden will wait for your return."
    }
  }
}

struct Enemy: Identifiable {
  let id: Int
  var position: V2
  var health: Double
  let maxHealth: Double
  let kind: EnemyKind
  var flash: Double = 0
  var radius: Double { kind == .boss ? 37 : kind == .thorn ? 18 : 13 }
}

struct Bolt: Identifiable {
  let id: Int
  var position: V2
  var velocity: V2
  var life: Double = 1.8
}

struct Pickup: Identifiable {
  let id: Int
  var position: V2
  var value: Double
  let healing: Bool
}

struct Spark: Identifiable {
  let id: Int
  var position: V2
  var life: Double = 0.5
  let mint: Bool
}

struct ThornBloom: Identifiable {
  let id: Int
  let position: V2
  var age: Double = 0
  static let warning: Double = 1.6
  static let lifetime: Double = 4.8
  static let radius: Double = 58
}

struct Cell: Hashable {
  let x: Int
  let y: Int
  init(_ position: V2) {
    x = Int(floor(position.x / 70))
    y = Int(floor(position.y / 70))
  }
  init(x: Int, y: Int) {
    self.x = x
    self.y = y
  }
}

struct GameModel {
  var phase = RunPhase.playing
  var player = V2.zero
  var movement = V2.zero
  var elapsed: Double = 0
  var health: Double = 100
  var maxHealth: Double = 100
  var kills = 0
  var level = 1
  var experience: Double = 0
  var choices: [Upgrade] = []
  var upgrades: [Upgrade: Int] = [:]
  var enemies: [Enemy] = []
  var bolts: [Bolt] = []
  var pickups: [Pickup] = []
  var sparks: [Spark] = []
  var blooms: [ThornBloom] = []
  var bossSpawned = false
  var bossDefeated = false
  var novaFlash: Double = 0
  var hurtFlash: Double = 0
  var shotsFired = 0
  var defeatCause: DefeatCause?
  private(set) var nextGiftIn: Double = 0
  private var random: SeededRandom
  private var nextID = 0
  private var spawnClock: Double = 0
  private var attackClock: Double = 0
  private var novaClock: Double = 4
  private var contactClock: Double = 0
  private var orbitClock: Double = 0
  private var bloomClock: Double = 45
  private var lastDamage: DefeatCause?
  static let duration: Double = 300
  static let boundary: Double = 1100
  var neededExperience: Double { Double(10 + level * 6 + level * level) }
  var speed: Double { 145 * (1 + Double(rank(.haste)) * 0.12) }
  var magnetRadius: Double { 63 + Double(rank(.magnet)) * 24 }
  var orbitCount: Int { rank(.orbit) == 0 ? 0 : min(5, rank(.orbit) + 1) }
  var orbitRadius: Double { 70 + Double(rank(.orbit)) * 7 }
  var stage: String {
    elapsed < 60
      ? "The waking garden"
      : elapsed < 150
        ? "A thousand whispers"
        : elapsed < 240 ? "The thorns gather" : "The Hollow Gardener"
  }
  var timeText: String {
    String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60)
  }

  init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
    random = SeededRandom(state: seed)
  }
  func rank(_ upgrade: Upgrade) -> Int { upgrades[upgrade, default: 0] }
  mutating func identifier() -> Int {
    nextID += 1
    return nextID
  }
  mutating func pause() {
    if phase == .playing {
      phase = .paused
      movement = .zero
    }
  }
  mutating func resume() {
    if phase == .paused { phase = .playing }
  }
  mutating func choose(_ upgrade: Upgrade) {
    guard phase == .choosing, choices.contains(upgrade) else { return }
    upgrades[upgrade, default: 0] += 1
    if upgrade == .vitality {
      maxHealth += 15
      health = min(maxHealth, health + 35)
    }
    phase = .playing
    choices = []
    nextGiftIn = 8
  }
  mutating func checkLevel() {
    guard phase == .playing, nextGiftIn <= 0, experience >= neededExperience else { return }
    experience -= neededExperience
    level += 1
    phase = .choosing
    movement = .zero
    var pool = Upgrade.allCases
    choices = []
    for _ in 0..<3 {
      let index = min(pool.count - 1, Int(random.next() * Double(pool.count)))
      choices.append(pool.remove(at: index))
    }
  }
  mutating func tick(_ delta: Double) {
    guard phase == .playing else { return }
    let dt = min(0.05, max(0, delta))
    elapsed += dt
    nextGiftIn = max(0, nextGiftIn - dt)
    player = player + movement.normalized * min(1, movement.length) * (speed * dt)
    player.x = min(Self.boundary, max(-Self.boundary, player.x))
    player.y = min(Self.boundary, max(-Self.boundary, player.y))
    hurtFlash = max(0, hurtFlash - dt)
    novaFlash = max(0, novaFlash - dt)
    contactClock = max(0, contactClock - dt)
    spawnClock -= dt
    if spawnClock <= 0 {
      spawnClock = max(0.22, 1.15 - elapsed / 300)
      let count = elapsed < 70 ? 1 : elapsed < 170 ? 2 : 3
      for _ in 0..<count where enemies.count < 140 { spawnEnemy() }
    }
    if elapsed >= 240 && !bossSpawned {
      bossSpawned = true
      spawnEnemy(kind: .boss)
    }
    bloomClock -= dt
    if bloomClock <= 0 {
      bloomClock = elapsed >= 240 ? 4.5 : elapsed >= 150 ? 7 : 10
      blooms.append(ThornBloom(id: identifier(), position: player))
    }
    for index in blooms.indices {
      blooms[index].age += dt
      if blooms[index].age >= ThornBloom.warning
        && (blooms[index].position - player).length < ThornBloom.radius
        && contactClock <= 0
      {
        health -= 16
        lastDamage = .thorns
        contactClock = 0.8
        hurtFlash = 0.4
      }
    }
    blooms.removeAll { $0.age >= ThornBloom.lifetime }
    for index in enemies.indices {
      let kind = enemies[index].kind
      let enemySpeed: Double =
        kind == .moth ? 85 : kind == .boss ? 52 : kind == .thorn ? 35 : 44
      let direction = (player - enemies[index].position).normalized
      enemies[index].position = enemies[index].position + direction * (enemySpeed * dt)
      enemies[index].flash = max(0, enemies[index].flash - dt)
      if (enemies[index].position - player).length < enemies[index].radius + 12
        && contactClock <= 0
      {
        health -= kind == .boss ? 22 : kind == .thorn ? 15 : 10
        switch kind {
        case .shade: lastDamage = .shade
        case .moth: lastDamage = .moth
        case .thorn: lastDamage = .thorn
        case .boss: lastDamage = .boss
        }
        hurtFlash = 0.4
        contactClock = 0.8
        enemies[index].position = enemies[index].position - direction * 32
      }
    }
    attackClock -= dt
    if attackClock <= 0 {
      attackClock = max(0.19, 0.65 * pow(0.9, Double(rank(.haste))))
      fireVolley()
    }
    var grid: [Cell: [Int]] = [:]
    for index in enemies.indices { grid[Cell(enemies[index].position), default: []].append(index) }
    for index in bolts.indices {
      bolts[index].position = bolts[index].position + bolts[index].velocity * dt
      bolts[index].life -= dt
      let cell = Cell(bolts[index].position)
      var hit = false
      for x in -1...1 {
        for y in -1...1 {
          for enemyIndex in grid[Cell(x: cell.x + x, y: cell.y + y), default: []] {
            if !hit && enemies[enemyIndex].health > 0
              && (enemies[enemyIndex].position - bolts[index].position).length
                < enemies[enemyIndex].radius + 9
            {
              enemies[enemyIndex].health -= 18 + Double(rank(.lantern)) * 5
              enemies[enemyIndex].flash = 0.12
              bolts[index].life = 0
              hit = true
            }
          }
        }
      }
    }
    bolts.removeAll { $0.life <= 0 }
    orbitClock -= dt
    if orbitCount > 0 && orbitClock <= 0 {
      orbitClock = 0.22
      for orb in 0..<orbitCount {
        let angle = elapsed * 2.4 + Double(orb) * 2 * .pi / Double(orbitCount)
        let position = player + V2(x: cos(angle), y: sin(angle)) * orbitRadius
        for index in enemies.indices
        where (enemies[index].position - position).length < enemies[index].radius + 19 {
          enemies[index].health -= 12 + Double(rank(.orbit)) * 5
          enemies[index].flash = 0.12
        }
      }
    }
    novaClock -= dt
    if rank(.nova) > 0 && novaClock <= 0 {
      novaClock = max(1.8, 5 - Double(rank(.nova)) * 0.4)
      novaFlash = 0.6
      for index in enemies.indices
      where (enemies[index].position - player).length < 180 + Double(rank(.nova)) * 15 {
        enemies[index].health -= 30 + Double(rank(.nova)) * 15
        enemies[index].flash = 0.18
      }
    }
    let defeated = enemies.filter { $0.health <= 0 }
    enemies.removeAll {
      $0.health <= 0 || ($0.kind != .boss && ($0.position - player).length > 900)
    }
    for enemy in defeated {
      kills += 1
      if enemy.kind == .boss { bossDefeated = true }
      let heal = kills % 17 == 0
      let value: Double = enemy.kind == .thorn ? 5 : enemy.kind == .boss ? 50 : 3
      pickups.append(
        Pickup(id: identifier(), position: enemy.position, value: value, healing: false))
      if heal {
        pickups.append(
          Pickup(id: identifier(), position: enemy.position + V2(x: 12), value: 22, healing: true))
      }
      sparks.append(Spark(id: identifier(), position: enemy.position, mint: false))
    }
    for index in pickups.indices {
      let distance = (pickups[index].position - player).length
      if distance < magnetRadius {
        pickups[index].position =
          pickups[index].position + (player - pickups[index].position).normalized * (340 * dt)
      }
      if distance < 19 {
        if pickups[index].healing {
          health = min(maxHealth, health + pickups[index].value)
        } else {
          experience += pickups[index].value * (1 + Double(rank(.magnet)) * 0.1)
        }
        pickups[index].value = 0
      }
    }
    pickups.removeAll { $0.value == 0 }
    if pickups.count > 300 {
      let overflow = pickups.removeFirst()
      if let nearest = pickups.indices.min(by: {
        (pickups[$0].position - overflow.position).length
          < (pickups[$1].position - overflow.position).length
      }), !overflow.healing, !pickups[nearest].healing {
        pickups[nearest].value += overflow.value
      }
    }
    for index in sparks.indices { sparks[index].life -= dt }
    sparks.removeAll { $0.life <= 0 }
    if health <= 0 {
      health = 0
      defeatCause = lastDamage
      phase = .defeat
    } else if elapsed >= Self.duration {
      elapsed = Self.duration
      phase = bossDefeated ? .victory : .defeat
      if !bossDefeated { defeatCause = .dawn }
    } else {
      checkLevel()
    }
  }
  mutating func spawnEnemy(kind forcedKind: EnemyKind? = nil) {
    let angle = random.next() * .pi * 2
    let distance = 360 + random.next() * 130
    let roll = random.next()
    let kind =
      forcedKind
      ?? (elapsed > 120 && roll < 0.24 ? .thorn : elapsed > 40 && roll < 0.4 ? .moth : .shade)
    let hp: Double =
      kind == .boss ? 760 : kind == .thorn ? 75 : kind == .moth ? 22 : 28 + elapsed * 0.04
    enemies.append(
      Enemy(
        id: identifier(), position: player + V2(x: cos(angle), y: sin(angle)) * distance,
        health: hp, maxHealth: hp, kind: kind))
  }
  mutating func fireVolley() {
    let targets = enemies.filter { ($0.position - player).length < 480 && $0.health > 0 }
      .sorted { ($0.position - player).length < ($1.position - player).length }
    guard !targets.isEmpty else { return }
    for shot in 0..<min(7, 1 + rank(.lantern)) {
      let target = targets[shot % targets.count]
      let direction = (target.position - player).normalized
      bolts.append(Bolt(id: identifier(), position: player, velocity: direction * 380))
      shotsFired += 1
    }
  }
}
