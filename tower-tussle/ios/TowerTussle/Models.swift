import Foundation
import SwiftUI

enum Side: Int, Codable {
    case player = 0
    case enemy = 1

    var opposite: Side { self == .player ? .enemy : .player }
}

enum CardKind: String, Codable {
    case troop
    case spell
}

struct CardDef: Identifiable, Hashable {
    let id: String
    let name: String
    let cost: Int
    let kind: CardKind
    let emoji: String
    let count: Int
    let hp: Double
    let damage: Double
    let range: Double
    let hitSpeed: Double
    let speed: Double
    let flying: Bool
    let buildingsOnly: Bool
    let radius: Double
    let description: String

    static func troop(_ id: String, _ name: String, cost: Int, emoji: String, count: Int = 1,
                      hp: Double, damage: Double, range: Double, hitSpeed: Double, speed: Double,
                      flying: Bool = false, buildingsOnly: Bool = false, description: String) -> CardDef {
        CardDef(id: id, name: name, cost: cost, kind: .troop, emoji: emoji, count: count, hp: hp,
                damage: damage, range: range, hitSpeed: hitSpeed, speed: speed, flying: flying,
                buildingsOnly: buildingsOnly, radius: 0, description: description)
    }

    static func spell(_ id: String, _ name: String, cost: Int, emoji: String, damage: Double,
                      radius: Double, description: String) -> CardDef {
        CardDef(id: id, name: name, cost: cost, kind: .spell, emoji: emoji, count: 0, hp: 0,
                damage: damage, range: 0, hitSpeed: 0, speed: 0, flying: false, buildingsOnly: false,
                radius: radius, description: description)
    }
}

enum Cards {
    static let all: [CardDef] = [
        .troop("knight", "Knight", cost: 3, emoji: "🛡️", hp: 1400, damage: 160, range: 1.0, hitSpeed: 1.1, speed: 2.0,
               description: "A sturdy melee fighter. Good at soaking damage."),
        .troop("archers", "Archers", cost: 3, emoji: "🏹", count: 2, hp: 250, damage: 90, range: 5.0, hitSpeed: 1.0, speed: 2.0,
               description: "A pair of ranged shooters. Can hit flying troops."),
        .troop("giant", "Colossus", cost: 5, emoji: "🗿", hp: 3300, damage: 210, range: 1.0, hitSpeed: 1.5, speed: 1.3,
               buildingsOnly: true, description: "Slow, huge, and only interested in towers."),
        .troop("duelist", "Duelist", cost: 4, emoji: "⚔️", hp: 1100, damage: 550, range: 1.0, hitSpeed: 1.6, speed: 3.0,
               description: "Fast, and hits like a truck. Fragile in a crowd."),
        .troop("sharpshooter", "Sharpshooter", cost: 4, emoji: "🎯", hp: 600, damage: 180, range: 6.0, hitSpeed: 1.1, speed: 2.0,
               description: "Long range. Picks off troops before they arrive."),
        .troop("gremlins", "Gremlins", cost: 2, emoji: "👺", count: 3, hp: 170, damage: 100, range: 0.8, hitSpeed: 1.1, speed: 3.5,
               description: "Three very fast, very rude little fighters."),
        .troop("bones", "Bone Brigade", cost: 3, emoji: "💀", count: 6, hp: 70, damage: 70, range: 0.8, hitSpeed: 1.0, speed: 3.0,
               description: "Six skeletons. Overwhelms single targets, melts to spells."),
        .troop("whelp", "Whelp", cost: 4, emoji: "🐲", hp: 1000, damage: 130, range: 3.5, hitSpeed: 1.5, speed: 2.3,
               flying: true, description: "A baby dragon. Flies over the river; melee can't touch it."),
        .spell("meteor", "Meteor", cost: 4, emoji: "☄️", damage: 570, radius: 2.5,
               description: "Big area damage. Towers take 35%."),
        .spell("volley", "Volley", cost: 3, emoji: "🌧️", damage: 240, radius: 4.0,
               description: "Wide, light area damage. Clears swarms."),
    ]

    static let defaultDeck = ["knight", "archers", "giant", "duelist", "sharpshooter", "gremlins", "meteor", "volley"]

    static func byId(_ id: String) -> CardDef {
        all.first { $0.id == id } ?? all[0]
    }
}

struct Vec: Equatable {
    var x: Double
    var y: Double

    static func - (a: Vec, b: Vec) -> Vec { Vec(x: a.x - b.x, y: a.y - b.y) }
    static func + (a: Vec, b: Vec) -> Vec { Vec(x: a.x + b.x, y: a.y + b.y) }
    static func * (a: Vec, s: Double) -> Vec { Vec(x: a.x * s, y: a.y * s) }
    var length: Double { (x * x + y * y).squareRoot() }
    func distance(to other: Vec) -> Double { (self - other).length }
    var normalized: Vec { length > 0.0001 ? self * (1 / length) : Vec(x: 0, y: 0) }
}

final class Unit: Identifiable {
    let id: Int
    let card: CardDef
    let side: Side
    var pos: Vec
    var hp: Double
    var attackCooldown: Double = 0
    var targetId: Int? = nil
    var laneX: Double = 3.5
    var hitFlash: Double = 0
    var walkPhase: Double = 0
    var facing: Double = 1
    var moving = false
    var attackAnim: Double = 0
    var spawnAge: Double = 0

    init(id: Int, card: CardDef, side: Side, pos: Vec) {
        self.id = id
        self.card = card
        self.side = side
        self.pos = pos
        self.hp = card.hp
    }

    var alive: Bool { hp > 0 }
    var radius: Double { card.count > 1 ? 0.35 : 0.5 }
}

enum TowerKind: String {
    case guardTower
    case keep

    var maxHp: Double { self == .keep ? 4000 : 2500 }
    var damage: Double { self == .keep ? 120 : 100 }
    var range: Double { self == .keep ? 7.0 : 7.5 }
    var hitSpeed: Double { self == .keep ? 1.0 : 0.8 }
    var radius: Double { self == .keep ? 1.3 : 1.0 }
    var name: String { self == .keep ? "Keep" : "Guard Tower" }
}

final class Tower: Identifiable {
    let id: Int
    let kind: TowerKind
    let side: Side
    let pos: Vec
    var hp: Double
    var attackCooldown: Double = 0
    var activated: Bool
    var hitFlash: Double = 0

    init(id: Int, kind: TowerKind, side: Side, pos: Vec) {
        self.id = id
        self.kind = kind
        self.side = side
        self.pos = pos
        self.hp = kind.maxHp
        self.activated = kind == .guardTower
    }

    var alive: Bool { hp > 0 }
}

enum EffectKind {
    case meteor
    case volley
    case towerFall
    case deploy

    /// Seconds after cast at which the spell lands and applies damage.
    var impactDelay: Double {
        switch self {
        case .meteor: return 0.55
        case .volley: return 0.4
        case .towerFall, .deploy: return 0
        }
    }

    var duration: Double {
        switch self {
        case .meteor: return 1.6
        case .volley: return 1.3
        case .towerFall: return 1.4
        case .deploy: return 0.6
        }
    }
}

struct SpellEffect: Identifiable {
    let id: Int
    let kind: EffectKind
    let pos: Vec
    let radius: Double
    let side: Side
    let damage: Double
    var ttl: Double
    var resolved: Bool

    init(id: Int, kind: EffectKind, pos: Vec, radius: Double, side: Side, damage: Double = 0) {
        self.id = id
        self.kind = kind
        self.pos = pos
        self.radius = radius
        self.side = side
        self.damage = damage
        self.ttl = kind.duration
        self.resolved = kind.impactDelay == 0
    }

    var age: Double { kind.duration - ttl }
    var progress: Double { min(1, max(0, age / kind.duration)) }
    var landed: Bool { age >= kind.impactDelay }
}

enum ProjectileKind {
    case arrow
    case bolt
    case fireball
    case cannon
}

struct Projectile: Identifiable {
    let id: Int
    let kind: ProjectileKind
    let start: Vec
    var pos: Vec
    let target: Vec
    let side: Side
    var ttl: Double

    var progress: Double {
        let total = start.distance(to: target)
        return total < 0.001 ? 1 : min(1, start.distance(to: pos) / total)
    }
}

enum ParticleKind {
    case dust
    case spark
    case smoke
    case ember
    case debris
    case bone
    case leaf
    case glow
}

struct Particle: Identifiable {
    let id: Int
    let kind: ParticleKind
    var pos: Vec
    var vel: Vec
    var ttl: Double
    let maxTtl: Double
    let size: Double
    let color: Color
    var life: Double { max(0, min(1, ttl / maxTtl)) }
}

struct FloatingText: Identifiable {
    let id: Int
    var pos: Vec
    var amount: Double
    let side: Side
    let color: Color
    var ttl: Double
    let maxTtl: Double
    var text: String { "\(Int(amount))" }
    var life: Double { max(0, min(1, ttl / maxTtl)) }
    var age: Double { maxTtl - ttl }
}

enum MatchOutcome: String {
    case victory = "VICTORY"
    case defeat = "DEFEAT"
    case draw = "DRAW"
}

struct MatchResult {
    let outcome: MatchOutcome
    let playerCrowns: Int
    let enemyCrowns: Int
    let trophyDelta: Int
    let goldDelta: Int
    let durationSeconds: Int
}

/// Trophy tiers that give the player a sense of progression between battles.
struct League: Equatable {
    let name: String
    let minTrophies: Int
    let color: Color

    static let all: [League] = [
        League(name: "Sky Rookie", minTrophies: 0, color: Color(red: 0.55, green: 0.75, blue: 0.9)),
        League(name: "Cloud Squire", minTrophies: 60, color: Color(red: 0.45, green: 0.85, blue: 0.75)),
        League(name: "Storm Knight", minTrophies: 160, color: Color(red: 0.4, green: 0.65, blue: 1.0)),
        League(name: "Sun Champion", minTrophies: 320, color: Color(red: 1.0, green: 0.75, blue: 0.3)),
        League(name: "Star Legend", minTrophies: 560, color: Color(red: 0.95, green: 0.6, blue: 1.0)),
    ]

    static func forTrophies(_ trophies: Int) -> League {
        all.last { trophies >= $0.minTrophies } ?? all[0]
    }

    var next: League? {
        guard let i = League.all.firstIndex(of: self), i + 1 < League.all.count else { return nil }
        return League.all[i + 1]
    }

    /// 0...1 progress from this league's floor to the next league.
    func progress(trophies: Int) -> Double {
        guard let next else { return 1 }
        return min(1, max(0, Double(trophies - minTrophies) / Double(next.minTrophies - minTrophies)))
    }
}

enum BattleTips {
    static let afterDefeat = [
        "Wait for 10 elixir before starting a big push.",
        "Volley clears Bone Brigade and Gremlins in one cast.",
        "Drop the Colossus at the back so support catches up.",
        "Archers and Sharpshooter can shoot the flying Whelp.",
        "Defend on your side first: your towers help you fight.",
    ]
    static let afterVictory = [
        "Keep your average elixir under 4 for faster cycles.",
        "Meteor on a crowded bridge swings the whole match.",
        "A tower with low health is worth a Meteor at 35%.",
        "Double elixir starts in the last minute: go all in.",
    ]

    static func tip(for outcome: MatchOutcome, seed: Int) -> String {
        let pool = outcome == .defeat ? afterDefeat : afterVictory
        return pool[abs(seed) % pool.count]
    }
}
