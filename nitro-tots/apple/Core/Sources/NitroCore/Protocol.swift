import Foundation

enum GameMode: String, Codable { case race, timeTrial, battle }
enum RacePhase: String, Codable { case countdown, racing, finished }
enum ItemKind: String, Codable, CaseIterable {
  case turbo, tripleTurbo, rocket, orb, slick, shield, zap, comet
  var label: String {
    switch self {
    case .turbo: return "Turbo Can"
    case .tripleTurbo: return "Triple Turbo"
    case .rocket: return "Homing Rocket"
    case .orb: return "Bouncy Orb"
    case .slick: return "Syrup Slick"
    case .shield: return "Bubble Shield"
    case .zap: return "Thunder Zap"
    case .comet: return "Comet Ride"
    }
  }
}
struct KartInput: Equatable {
  var throttle = 0.0, steer = 0.0
  var drift = false, item = false, lookBack = false
}
struct InputBuffer {
  private(set) var current = KartInput()
  mutating func add(_ input: KartInput) {
    let pending = current.item
    current = input
    current.item = input.item || pending
  }
  mutating func consume() -> KartInput {
    let input = current
    current.item = false
    return input
  }
}
struct RoomSettings: Codable, Equatable {
  var mode: GameMode = .race
  var cupId = "sugar", trackId = "sprinkle"
  var laps = 3, maxPlayers = 8, minPlayers = 2
  var fillBots = true
  var botSkill = 0.7
  var grandPrix = true
  var battleSeconds = 120
}
struct RacerProfile: Codable, Identifiable, Equatable {
  var slot: Int
  var playerId, name, character, kart: String
  var bot: Bool
  var platform: String
  var id: Int { slot }
}
struct Player: Codable, Identifiable {
  let id, name, character, kart, platform: String
  let ready, connected, host, bot: Bool
  let slot: Int
}
struct RaceResult: Codable, Identifiable, Equatable {
  let slot: Int
  let name, character, kart: String
  let bot: Bool
  let platform: String
  let place, finishTick: Int
  let lapTicks: [Int]
  let points, score: Int
  var id: Int { slot }
  var raceTicks: Int { max(0, finishTick - 120) }
}
struct Standing: Codable, Identifiable, Equatable {
  let slot: Int
  let name, character, kart: String
  let bot: Bool
  let platform: String
  var points: Int
  var places: [Int]
  var id: Int { slot }
}
func standings(_ races: [[RaceResult]]) -> [Standing] {
  var map: [Int: Standing] = [:]
  for race in races {
    for r in race {
      let old = map[r.slot]
      map[r.slot] = Standing(
        slot: r.slot, name: r.name, character: r.character, kart: r.kart,
        bot: r.bot, platform: r.platform, points: (old?.points ?? 0) + r.points,
        places: (old?.places ?? []) + [r.place])
    }
  }
  return map.values.sorted {
    if $0.points != $1.points { return $0.points > $1.points }
    if $0.places.min() != $1.places.min() { return ($0.places.min() ?? 9) < ($1.places.min() ?? 9) }
    return $0.slot < $1.slot
  }
}
struct Room: Decodable {
  let code, hostId, status: String
  let settings: RoomSettings
  let players: [Player]
  let raceIndex, totalRaces: Int
  let standings: [Standing]
}
struct MatchStart: Codable {
  let code: String?
  let raceIndex, totalRaces: Int
  let trackId: String
  let seed, laps: Int
  let mode: GameMode
  let battleSeconds, tick: Int
  let racers: [RacerProfile]
}
struct Event: Codable, Equatable {
  let e: String
  var r: Int? = nil
  var o: Int? = nil
  var v: Int? = nil
  var k: ItemKind? = nil
}
struct RacerWire: Codable {
  let s: Int
  let x, y, h, v: Double
  let l, c, n, p, d, dc, b, bt, a, sp, sh, z, cm, st, hp: Int
  let i: ItemKind?
  let ic, ro, f, ft: Int
  let lt: [Int]
  let ls, ww, bl, sc, rs, su, pi, pd, th: Int
}
struct ProjectileWire: Codable {
  let id: Int
  let k: ItemKind
  let o: Int
  let x, y, h: Double
}
struct DropWire: Codable {
  let id: Int
  let x, y: Double
  let o: Int
}
struct Snapshot: Codable {
  let tick: Int
  let phase: RacePhase
  let racers: [RacerWire]
  let proj: [ProjectileWire]
  let drop: [DropWire]
  let boxes: [Int]
  let mov: [V2]
  let events: [Event]
  let ack: [String: Int]
  let left: Int
}
struct Welcome: Decodable {
  let playerId, token: String
  let v: Int
  let resumed: Bool?
}
struct ServerError: Decodable { let code, message: String }
struct RaceOutcome: Decodable {
  let trackId: String
  let raceIndex: Int
  let results: [RaceResult]
  let standings: [Standing]
  let isLast: Bool
}
struct RaceHistory: Codable {
  let trackId: String
  let results: [RaceResult]
}
struct MatchOutcome: Decodable {
  let standings: [Standing]
  let hash: String
  let races: [RaceHistory]
}
struct Pong: Decodable { let t: Double }
struct PlayerLeft: Decodable { let playerId: String }
enum ServerMessage: Decodable {
  case welcome(Welcome)
  case error(ServerError)
  case room(Room)
  case start(MatchStart)
  case snapshot(Snapshot)
  case raceFinished(RaceOutcome)
  case matchOver(MatchOutcome)
  case pong(Pong)
  case playerLeft(PlayerLeft)
  case unknown
  private enum CodingKeys: String, CodingKey { case type }
  init(from decoder: Decoder) throws {
    let type = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .type)
    switch type {
    case "welcome": self = .welcome(try Welcome(from: decoder))
    case "error": self = .error(try ServerError(from: decoder))
    case "room_state": self = .room(try Room(from: decoder))
    case "match_start": self = .start(try MatchStart(from: decoder))
    case "snapshot": self = .snapshot(try Snapshot(from: decoder))
    case "race_finished": self = .raceFinished(try RaceOutcome(from: decoder))
    case "match_over": self = .matchOver(try MatchOutcome(from: decoder))
    case "pong": self = .pong(try Pong(from: decoder))
    case "player_left": self = .playerLeft(try PlayerLeft(from: decoder))
    default: self = .unknown
    }
  }
}
enum ClientMessage: Encodable {
  case hello(name: String, character: String, kart: String, platform: String)
  case resume(playerId: String, token: String)
  case profile(name: String, character: String, kart: String)
  case create(RoomSettings, code: String? = nil)
  case join(String)
  case leave
  case ready(Bool)
  case settings(RoomSettings)
  case start, next
  case input(Int, KartInput)
  case ping(Double)
  case report(hash: String, standings: [Standing], lastTick: Int, frames: Int)
  private enum CodingKeys: String, CodingKey {
    case type, v, name, character, kart, platform, playerId, token, settings, code, ready, tick, t,
      s, d, i, b, hash, standings, phase, lastTick, frames
  }
  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .hello(let name, let character, let kart, let platform):
      try c.encode("hello", forKey: .type)
      try c.encode(1, forKey: .v)
      try c.encode(name, forKey: .name)
      try c.encode(character, forKey: .character)
      try c.encode(kart, forKey: .kart)
      try c.encode(platform, forKey: .platform)
    case .resume(let playerId, let token):
      try c.encode("resume", forKey: .type)
      try c.encode(playerId, forKey: .playerId)
      try c.encode(token, forKey: .token)
    case .profile(let name, let character, let kart):
      try c.encode("update_profile", forKey: .type)
      try c.encode(name, forKey: .name)
      try c.encode(character, forKey: .character)
      try c.encode(kart, forKey: .kart)
    case .create(let settings, let code):
      try c.encode("create_room", forKey: .type)
      try c.encode(settings, forKey: .settings)
      try c.encodeIfPresent(code, forKey: .code)
    case .join(let code):
      try c.encode("join_room", forKey: .type)
      try c.encode(code.uppercased().trimmingCharacters(in: .whitespaces), forKey: .code)
    case .leave: try c.encode("leave_room", forKey: .type)
    case .ready(let value):
      try c.encode("set_ready", forKey: .type)
      try c.encode(value, forKey: .ready)
    case .settings(let value):
      try c.encode("update_settings", forKey: .type)
      try c.encode(value, forKey: .settings)
    case .start: try c.encode("start_match", forKey: .type)
    case .next: try c.encode("next_race", forKey: .type)
    case .input(let tick, let input):
      try c.encode("input", forKey: .type)
      try c.encode(tick, forKey: .tick)
      try c.encode((clamp(input.throttle, -1, 1) * 100).rounded() / 100, forKey: .t)
      try c.encode((clamp(input.steer, -1, 1) * 100).rounded() / 100, forKey: .s)
      if input.drift { try c.encode(1, forKey: .d) }
      if input.item { try c.encode(1, forKey: .i) }
      if input.lookBack { try c.encode(1, forKey: .b) }
    case .ping(let time):
      try c.encode("ping", forKey: .type)
      try c.encode(time, forKey: .t)
    case .report(let hash, let standings, let lastTick, let frames):
      try c.encode("test_report", forKey: .type)
      try c.encode(hash, forKey: .hash)
      try c.encode("matchOver", forKey: .phase)
      try c.encode(standings, forKey: .standings)
      try c.encode(lastTick, forKey: .lastTick)
      try c.encode(frames, forKey: .frames)
    }
  }
}
