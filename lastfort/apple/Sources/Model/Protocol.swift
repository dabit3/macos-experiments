import Foundation

enum SquadMode: String, Codable, CaseIterable { case solo, duos, squads }
enum LifeState: String, Codable { case inBus, dropping, alive, eliminated }
enum MatchPhase: String, Codable { case lobby, bus, playing, ended }
enum Piece: String, Codable, CaseIterable { case wall, floor, ramp, roof }
enum BuildingMaterial: String, Codable, CaseIterable {
  case wood, stone, metal
  var maxHP: Int { self == .wood ? 150 : self == .stone ? 300 : 500 }
  var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}
enum PieceEdit: String, Codable, CaseIterable { case none, door, window }
enum ResourceKind: String, Codable {
  case tree, rock, car
  var hp: Int { self == .tree ? 90 : self == .rock ? 120 : 110 }
  var radius: Double { self == .tree ? 1.4 : self == .rock ? 1.6 : 2.2 }
}
enum Rarity: String, Codable {
  case common, uncommon, rare, epic, legendary
  var rgb: UInt32 {
    switch self {
    case .common: return 0xB5B9C2
    case .uncommon: return 0x5FD068
    case .rare: return 0x3FA2FF
    case .epic: return 0xB86BFF
    case .legendary: return 0xFFB13D
    }
  }
}
enum CosmeticSlot: String, Codable, CaseIterable { case outfit, pickaxe, glider, banner }
struct Loadout: Codable, Equatable {
  var o = "outfit_recruit"
  var p = "pickaxe_splinter"
  var g = "glider_kite"
  var b = "banner_fort"
  subscript(slot: CosmeticSlot) -> String {
    get {
      switch slot {
      case .outfit: return o
      case .pickaxe: return p
      case .glider: return g
      case .banner: return b
      }
    }
    set {
      switch slot {
      case .outfit: o = newValue
      case .pickaxe: p = newValue
      case .glider: g = newValue
      case .banner: b = newValue
      }
    }
  }
}
struct Rules: Codable {
  var tickRate = 20
  var mapSize = 1000.0
  var tileSize = 4.0
  var islandRadius = 440.0
  var maxPlayers = 16
  var moveSpeed = 7.0
  var sprintMultiplier = 1.4
  var dropSpeed = 15.0
  var glideSpeed = 11.0
  var playerRadius = 0.6
  var maxHealth = 100
  var maxShield = 100
  var materialCap = 500
  var pieceCost = 10
  var harvestRange = 3.2
  var interactRange = 2.6
  var buildRange = 2.0
  var interestRadius = 90.0
  var busDuration = 24.0
  var dropDuration = 4.0
  var reconnectGrace = 60.0
  var busJumpGraceTicks = 40
  var stormPhases: [StormPhase] = []
  var dt: Double { 1 / Double(tickRate) }
}
struct StormPhase: Codable {
  let wait: Double
  let shrink: Double
  let radius: Double
  let dps: Double
}
enum WeaponKind: String, Codable {
  case pistol, smg, rifle, shotgun, sniper
  var label: String {
    switch self {
    case .pistol: return "Scrapper"
    case .smg: return "Hornet"
    case .rifle: return "Ridgeline"
    case .shotgun: return "Boomstick"
    case .sniper: return "Longshot"
    }
  }
  var ammo: String {
    switch self {
    case .pistol, .smg: return "light"
    case .rifle: return "medium"
    case .shotgun: return "shells"
    case .sniper: return "heavy"
    }
  }
}
enum ConsumableKind: String, Codable {
  case bandage, medkit, smallShield, bigShield
  var label: String {
    switch self {
    case .bandage: return "Wrap"
    case .medkit: return "Medkit"
    case .smallShield: return "Fizz"
    case .bigShield: return "Big Fizz"
    }
  }
}
struct Item: Codable, Equatable {
  enum Kind: String, Codable { case weapon, consumable, ammo, material }
  let t: Kind
  var w: WeaponKind?
  var r: Rarity?
  var c: ConsumableKind?
  var a: String?
  var m: BuildingMaterial?
  var n: Int
  var l: Int?
  var label: String {
    w?.label ?? c?.label ?? a.map { "\($0.capitalized) Ammo" } ?? m?.rawValue.capitalized ?? "Item"
  }
}
struct PlayerStats: Codable {
  var kills, damage, harvested, built, chests, shotsFired, shotsHit, survivedTicks, placement,
    xp: Int
}
struct Player: Codable, Identifiable {
  let id: Int
  let n: String
  let t: Int
  let b: Bool
  let p: String
  var s: LifeState
  var x, y, a, alt: Double
  var hp, sh, slot: Int
  var bm, mv, fire: Bool
  var ld: Loadout
  var k: Int
  var em, rl, us, con: Bool
  var mats: [Int]?
  var inv: [Item?]?
  var ammo: [String: Int]?
  var bp: Piece?
  var bmat: BuildingMaterial?
  var seq, spec: Int?
  var cd, rlt, ust: Double?
  var st: PlayerStats?
  var selectedItem: Item? {
    guard let inv, inv.indices.contains(slot) else { return nil }
    return inv[slot]
  }
}
struct Structure: Codable, Identifiable {
  let id, gx, gy: Int
  var p: Piece
  var m: BuildingMaterial
  var t, hp, max: Int
  var e: PieceEdit = .none
  var d = 0
  var b = 0
}
struct ResourceNode: Codable, Identifiable {
  let id: Int
  let k: ResourceKind
  let x, y: Double
  var hp: Int
  let max, v: Int
}
struct Chest: Codable, Identifiable {
  let id: Int
  let x, y: Double
  var o = false
}
struct Loot: Codable, Identifiable {
  let id: Int
  let x, y: Double
  let i: Item
}
struct NodeDelta: Codable { let id, hp: Int }
struct ChestDelta: Codable {
  let id: Int
  let o: Bool
}
struct Storm: Codable {
  let cx, cy, r, tx, ty, tr: Double
  let ph: Int
  let sh: Bool
  let rem, dps: Double
  let done: Bool
  func contains(_ x: Double, _ y: Double) -> Bool { hypot(x - cx, y - cy) <= r }
}
struct Bus: Codable {
  let x, y, x0, y0, x1, y1, t, rem: Double
}
struct MatchState: Codable {
  let phase: MatchPhase
  let tick, alive, teamsAlive: Int
  let bus: Bus?
  let storm: Storm
  let winner: Int?
}
struct Shot: Codable {
  let x, y: Double
  let h: Int
}
enum EventDetail: Codable {
  case shots([Shot])
  case structure(Structure)
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let shots = try? container.decode([Shot].self) {
      self = .shots(shots)
    } else {
      self = .structure(try container.decode(Structure.self))
    }
  }
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .shots(let shots): try container.encode(shots)
    case .structure(let value): try container.encode(value)
    }
  }
}
struct GameEvent: Codable {
  let e: String
  let tick: Int
  var p, by, d, g, id, team: Int?
  var x, y: Double?
  var sh: Bool?
  var w, m, reason, name: String?
  var s: EventDetail?
}
struct Snapshot: Codable {
  let tick: Int
  let match: MatchState
  let players: [Player]
  let structs: [Structure]
  let gone: [Int]
  let nodes: [NodeDelta]
  let chests: [ChestDelta]
  let loot: [Loot]
  let ev: [GameEvent]
}
struct RoomMember: Codable, Identifiable {
  let id: Int
  let name, platform: String
  let ready, host: Bool
  let ld: Loadout
  let team: Int
}
struct RoomState: Codable {
  let you: Int?
  let code: String
  let mode: SquadMode
  let fast: Bool
  let seed, maxPlayers: Int
  let players: [RoomMember]
  let phase: String
  let countdownMs: Int?
}
struct MatchStart: Codable {
  let code: String
  let seed: Int
  let mode: SquadMode
  let rules: Rules
  let tick: Int
  let players: [Player]
  let resume: Bool?
}
struct SummaryRow: Codable, Identifiable {
  let id: Int
  let name: String
  let team: Int
  let bot: Bool
  let platform: String
  let placement, kills, damage, harvested, built, chests, survived, xp: Int
}
struct MatchSummary: Codable {
  let seed: Int
  let mode: SquadMode
  let endTick, stormPhase: Int
  let winnerTeam: Int?
  let teams: Int
  let players: [SummaryRow]
  func jsonString() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(self), as: UTF8.self)
  }
}
enum ActionKind: String, Codable {
  case jump, select, buildMode, setPiece, setMaterial, place, edit
  case interact, use, drop, reload, emote, spectateNext, thank
}
struct GameAction: Codable, Equatable {
  let t: ActionKind
  var s: Int?
  var v: String?
  var gx, gy: Int?
  init(_ kind: ActionKind, slot: Int? = nil, value: String? = nil, gx: Int? = nil, gy: Int? = nil) {
    t = kind
    s = slot
    v = value
    self.gx = gx
    self.gy = gy
  }
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(t, forKey: .t)
    if let s, s != 0 { try container.encode(s, forKey: .s) }
    if let v, !v.isEmpty { try container.encode(v, forKey: .v) }
    try container.encodeIfPresent(gx, forKey: .gx)
    try container.encodeIfPresent(gy, forKey: .gy)
  }
}
struct InputFrame: Codable {
  enum CodingKeys: String, CodingKey { case seq, mx, my, aim, fire, sprint, act }
  var seq: Int
  var mx, my, aim: Double
  var fire, sprint: Bool
  var act: [GameAction]
  init(seq: Int, mx: Double, my: Double, aim: Double, fire: Bool, sprint: Bool, act: [GameAction]) {
    self.seq = seq
    self.mx = mx
    self.my = my
    self.aim = aim
    self.fire = fire
    self.sprint = sprint
    self.act = act
  }
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    seq = try container.decode(Int.self, forKey: .seq)
    mx = try container.decode(Double.self, forKey: .mx)
    my = try container.decode(Double.self, forKey: .my)
    aim = try container.decode(Double.self, forKey: .aim)
    fire = try container.decodeIfPresent(Bool.self, forKey: .fire) ?? false
    sprint = try container.decodeIfPresent(Bool.self, forKey: .sprint) ?? false
    act = try container.decodeIfPresent([GameAction].self, forKey: .act) ?? []
  }
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(seq, forKey: .seq)
    try container.encode(mx, forKey: .mx)
    try container.encode(my, forKey: .my)
    try container.encode(aim, forKey: .aim)
    if fire { try container.encode(true, forKey: .fire) }
    if sprint { try container.encode(true, forKey: .sprint) }
    if !act.isEmpty { try container.encode(act, forKey: .act) }
  }
}
struct ClientMessage: Codable {
  enum Kind: String, Codable {
    case hello, ping, createRoom, joinRoom, leaveRoom, ready, setLoadout, setMode
    case startMatch, returnToLobby, input, testControl
  }
  var t: Kind
  var v: Int?
  var name, platform, token: String?
  var ld: Loadout?
  var c: Int64?
  var mode: SquadMode?
  var fast: Bool?
  var seed: Int?
  var code: String?
  var ready: Bool?
  var fill, countdownMs: Int?
  var f: InputFrame?
  var op, id: String?
  var on: Bool?
  var n, every: Int?
  var digest, summary: String?
  var snapshots: Int?
  var test, screen: String?
  init(_ type: Kind) { t = type }
}
struct Welcome: Decodable {
  let v: Int
  let token, name: String
  let serverTime: Int64
  let warning: String?
}
struct ServerError: Decodable {
  let code: String
  let message: String?
}
struct Pong: Decodable {
  let c: Int64
  let serverTime: Int64
}
struct TestAck: Decodable {
  let id: String?
  let op: String
  let tick: Int?
  let summary: MatchSummary?
  let me: Player?
  let error: String?
}
enum ServerMessage: Decodable {
  case welcome(Welcome)
  case error(ServerError)
  case pong(Pong)
  case room(RoomState)
  case start(MatchStart)
  case you(Int)
  case snapshot(Snapshot)
  case end(MatchSummary)
  case ack(TestAck)
  case unknown(String)
  enum CodingKeys: String, CodingKey { case t, id, summary }
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .t)
    switch type {
    case "welcome": self = .welcome(try Welcome(from: decoder))
    case "error": self = .error(try ServerError(from: decoder))
    case "pong": self = .pong(try Pong(from: decoder))
    case "roomState": self = .room(try RoomState(from: decoder))
    case "matchStart": self = .start(try MatchStart(from: decoder))
    case "you": self = .you(try container.decode(Int.self, forKey: .id))
    case "snapshot": self = .snapshot(try Snapshot(from: decoder))
    case "matchEnd": self = .end(try container.decode(MatchSummary.self, forKey: .summary))
    case "testAck": self = .ack(try TestAck(from: decoder))
    default: self = .unknown(type)
    }
  }
}
