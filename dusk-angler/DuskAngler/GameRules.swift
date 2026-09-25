import Foundation

enum Species: String, Codable, CaseIterable, Identifiable {
  case emberPerch, ribbonTrout, moonKoi, glassChar

  var id: String { rawValue }
  var name: String {
    switch self {
    case .emberPerch: return "Ember perch"
    case .ribbonTrout: return "Ribbon trout"
    case .moonKoi: return "Moonveil koi"
    case .glassChar: return "Glassfin char"
    }
  }
  var latin: String {
    switch self {
    case .emberPerch: return "Perca vespera"
    case .ribbonTrout: return "Salmo serica"
    case .moonKoi: return "Cyprinus lunaris"
    case .glassChar: return "Salvelinus vitrum"
    }
  }
  var rare: Bool { self == .moonKoi || self == .glassChar }
  var behavior: String {
    switch self {
    case .emberPerch: return "Steady pulls. A forgiving first catch."
    case .ribbonTrout: return "Quick runs. Rest before each surge."
    case .moonKoi: return "Long, powerful surges. Give it room."
    case .glassChar: return "Restless and elusive. Keep a gentle line."
    }
  }
  var baseLength: Int {
    switch self {
    case .emberPerch: return 24
    case .ribbonTrout: return 38
    case .moonKoi: return 62
    case .glassChar: return 46
    }
  }
  var surgeStrength: Double {
    switch self {
    case .emberPerch: return 0.20
    case .ribbonTrout: return 0.26
    case .moonKoi: return 0.29
    case .glassChar: return 0.24
    }
  }
}

enum Lake: String, Codable, CaseIterable, Identifiable {
  case amber, violet
  var id: String { rawValue }
  var name: String { self == .amber ? "Amber Lake" : "Violet Reach" }
  var subtitle: String { self == .amber ? "Where the last light lingers" : "Beyond the blue hour" }
  var species: [Species] {
    self == .amber ? [.emberPerch, .ribbonTrout, .moonKoi] : [.ribbonTrout, .glassChar, .moonKoi]
  }
}

struct CatchRecord: Codable, Identifiable {
  let id: UUID
  let species: Species
  let lake: Lake
  let length: Int
  let score: Int
  let date: Date
}

struct Progress: Codable {
  var catches: [CatchRecord] = []
  var bait = 0
  var best = 0
  var total = 0
  var tutorialSeen = false
  var violetUnlocked: Bool { total >= 3 }

  mutating func add(_ record: CatchRecord) {
    catches.append(record)
    if catches.count > 100 { catches.removeFirst() }
    bait += record.species.rare ? 2 : 1
    total += 1
    best = max(best, record.score)
  }
}

enum DuelOutcome: Equatable {
  case active, caught, snapped, escaped, timeout
}

struct Duel {
  var tension = 0.38
  var landed = 0.0
  var elapsed = 0.0
  var slack = 0.0
  var outcome = DuelOutcome.active
  let species: Species

  var cycle: Double { elapsed.truncatingRemainder(dividingBy: 7) }
  var surging: Bool { cycle >= 4.5 && cycle < 6.5 }
  var warning: Bool { cycle >= 3.2 && cycle < 4.5 }
  var secondsToSurge: Double {
    surging ? 0 : cycle < 4.5 ? 4.5 - cycle : 11.5 - cycle
  }
  var surgeRemaining: Double { surging ? 6.5 - cycle : 0 }
  static func surges(at time: Double) -> Bool {
    let cycle = time.truncatingRemainder(dividingBy: 7)
    return cycle >= 4.5 && cycle < 6.5
  }

  mutating func step(seconds: Double, reeling: Bool) {
    guard outcome == .active, seconds > 0 else { return }
    let dt = min(seconds, 0.1)
    elapsed += dt
    if reeling {
      tension += dt * (surging ? species.surgeStrength : 0.105)
      landed += dt * (surging ? 0.055 : 0.10)
    } else {
      tension -= dt * (surging ? 0.085 : 0.17)
      landed = max(0, landed - dt * 0.012)
    }
    tension = min(1, max(0.03, tension))
    slack = tension < 0.10 ? slack + dt : 0
    if tension >= 1 {
      outcome = .snapped
    } else if slack >= 5 {
      outcome = .escaped
    } else if elapsed >= 45 {
      outcome = .timeout
    } else if landed >= 1 {
      landed = 1
      outcome = .caught
    }
  }

  var score: Int { max(100, Int(1000 - elapsed * 9) + (species.rare ? 400 : 0)) }
}

enum Casting {
  static let positions: [(Double, Double)] = [(0.24, 0.29), (0.72, 0.50), (0.40, 0.75)]
  static func target(x: Double, y: Double) -> Int? {
    positions.indices.min {
      hypot(positions[$0].0 - x, positions[$0].1 - y)
        < hypot(positions[$1].0 - x, positions[$1].1 - y)
    }.flatMap {
      hypot(positions[$0].0 - x, positions[$0].1 - y) <= 0.17 ? $0 : nil
    }
  }
}
