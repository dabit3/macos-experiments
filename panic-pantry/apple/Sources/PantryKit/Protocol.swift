import Foundation

struct ChefInput: Codable, Equatable {
  var dx: Double = 0
  var dy: Double = 0
  var interact: Bool = false
  var action: Bool = false
  var dash: Bool = false
  var emote: Int?
  var targetX: Int?
  var targetY: Int?
  enum CodingKeys: String, CodingKey {
    case dx, dy
    case interact = "i"
    case action = "a"
    case dash = "d"
    case emote = "e"
    case targetX = "tx"
    case targetY = "ty"
  }
  init(
    dx: Double = 0, dy: Double = 0, interact: Bool = false, action: Bool = false,
    dash: Bool = false, emote: Int? = nil, targetX: Int? = nil, targetY: Int? = nil
  ) {
    self.dx = dx
    self.dy = dy
    self.interact = interact
    self.action = action
    self.dash = dash
    self.emote = emote
    self.targetX = targetX
    self.targetY = targetY
  }
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    dx = min(1, max(-1, try c.decodeIfPresent(Double.self, forKey: .dx) ?? 0))
    dy = min(1, max(-1, try c.decodeIfPresent(Double.self, forKey: .dy) ?? 0))
    interact = try c.decodeIfPresent(Bool.self, forKey: .interact) ?? false
    action = try c.decodeIfPresent(Bool.self, forKey: .action) ?? false
    dash = try c.decodeIfPresent(Bool.self, forKey: .dash) ?? false
    emote = try c.decodeIfPresent(Int.self, forKey: .emote)
    targetX = try c.decodeIfPresent(Int.self, forKey: .targetX)
    targetY = try c.decodeIfPresent(Int.self, forKey: .targetY)
  }
  var held: ChefInput { ChefInput(dx: dx, dy: dy, action: action) }
}

enum RoomAction: String {
  case leave = "room.leave"
  case addBot = "room.addBot"
  case removeBot = "room.removeBot"
  case
    start = "room.start"
  case rematch = "room.rematch"
}

struct ClientReport: Encodable {
  let platform, screen, phase: String
  let code: String?
  let tick, score, stars: Int?
  let results: Results?
  let resultsMatch: Int?
  let lastError: String?
  let rtt: Int
}

enum ClientMessage: Encodable {
  case hello(name: String, platform: String, token: String?)
  case ping(Int64)
  case create(level: String?)
  case join(code: String)
  case ready(Bool)
  case setLevel(String)
  case room(RoomAction)
  case input(ChefInput)
  case report(ClientReport)

  private enum Keys: String, CodingKey {
    case type, name, platform, token, `protocol`, t, level, code, ready
  }
  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    switch self {
    case .hello(let name, let platform, let token):
      try c.encode("hello", forKey: .type)
      try c.encode(1, forKey: .protocol)
      try c.encode(name, forKey: .name)
      try c.encode(platform, forKey: .platform)
      try c.encodeIfPresent(token, forKey: .token)
    case .ping(let time):
      try c.encode("ping", forKey: .type)
      try c.encode(time, forKey: .t)
    case .create(let level):
      try c.encode("room.create", forKey: .type)
      try c.encodeIfPresent(level, forKey: .level)
    case .join(let code):
      try c.encode("room.join", forKey: .type)
      try c.encode(code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), forKey: .code)
    case .ready(let ready):
      try c.encode("room.ready", forKey: .type)
      try c.encode(ready, forKey: .ready)
    case .setLevel(let level):
      try c.encode("room.setLevel", forKey: .type)
      try c.encode(level, forKey: .level)
    case .room(let action): try c.encode(action.rawValue, forKey: .type)
    case .input(let input):
      try c.encode("input", forKey: .type)
      try input.encode(to: encoder)
    case .report(let report):
      try c.encode("test.report", forKey: .type)
      try report.encode(to: encoder)
    }
  }
}

struct Welcome: Decodable {
  let playerId, token, name: String
  let `protocol`: Int
  let resumed: Bool
  let tickSeconds: Double
  let levels: [LevelSummary]
}

struct LevelSummary: Decodable {
  let id, name, tagline, gimmick: String
  let roundSeconds: Int
  let menu: [Dish]
  let tutorial: Bool
}

struct ScriptStep: Decodable {
  let input: ChefInput
  let ticks: Int
  private enum Keys: String, CodingKey { case ticks }
  init(from decoder: Decoder) throws {
    input = try ChefInput(from: decoder)
    ticks = max(
      1, try decoder.container(keyedBy: Keys.self).decodeIfPresent(Int.self, forKey: .ticks) ?? 1)
  }
}

struct TestCommand: Decodable {
  let cmd: String
  let ready: Bool?
  let level, code, name, server, mode: String?
  let index: Int?
}

enum ServerMessage: Decodable {
  case welcome(Welcome)
  case room(Room?)
  case snapshot(code: String, Snapshot)
  case results(code: String, match: Int, Results)
  case pong(Int64)
  case error(code: String, message: String)
  case testInput([ScriptStep])
  case testCommand(TestCommand)
  case unknown(String)
  private enum Keys: String, CodingKey {
    case type, room, code, state, results, match, t, message, steps
  }
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: Keys.self)
    let type = try c.decode(String.self, forKey: .type)
    switch type {
    case "welcome": self = .welcome(try Welcome(from: decoder))
    case "room.state": self = .room(try c.decodeIfPresent(Room.self, forKey: .room))
    case "game.snapshot":
      self = .snapshot(
        code: try c.decode(String.self, forKey: .code),
        try c.decode(Snapshot.self, forKey: .state))
    case "game.results":
      self = .results(
        code: try c.decode(String.self, forKey: .code),
        match: try c.decode(Int.self, forKey: .match),
        try c.decode(Results.self, forKey: .results))
    case "pong": self = .pong(try c.decode(Int64.self, forKey: .t))
    case "error":
      self = .error(
        code: try c.decode(String.self, forKey: .code),
        message: try c.decode(String.self, forKey: .message))
    case "test.input": self = .testInput(try c.decode([ScriptStep].self, forKey: .steps))
    case "test.command": self = .testCommand(try TestCommand(from: decoder))
    default: self = .unknown(type)
    }
  }
}
