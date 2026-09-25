import Foundation

public enum ServerMessage: Decodable, Sendable {
  case welcome(Welcome)
  case pong(Int64)
  case error(ServerError)
  case playerUpdated(PlayerProfile)
  case daily(DailyResult)
  case friends(FriendsState)
  case party(PartyState?)
  case chat(ChatMessage)
  case places([PlaceListing], online: Int)
  case profile(PlayerProfile)
  case room(RoomState?, bots: Int, serverTime: Int64?)
  case game(GameFrame)
  case events([GameEvent])
  case results(MatchResults, endsAt: Int64?)
  case control(TestControl)
  case unknown(String)

  private enum CodingKeys: String, CodingKey {
    case type, player, party, message, places, online, profile, room, botCount
    case results, resultsEndsAt, serverTime, events
  }
  public init(from decoder: Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    let type = try fields.decode(String.self, forKey: .type)
    switch type {
    case "welcome": self = .welcome(try Welcome(from: decoder))
    case "pong": self = .pong(try fields.decode(Int64.self, forKey: .serverTime))
    case "error": self = .error(try ServerError(from: decoder))
    case "player.updated":
      self = .playerUpdated(try fields.decode(PlayerProfile.self, forKey: .player))
    case "daily.result": self = .daily(try DailyResult(from: decoder))
    case "friends.state": self = .friends(try FriendsState(from: decoder))
    case "party.state": self = .party(try fields.decodeIfPresent(PartyState.self, forKey: .party))
    case "chat.message": self = .chat(try fields.decode(ChatMessage.self, forKey: .message))
    case "places":
      self = .places(
        try fields.decode([PlaceListing].self, forKey: .places),
        online: try fields.decode(Int.self, forKey: .online))
    case "profile": self = .profile(try fields.decode(PlayerProfile.self, forKey: .profile))
    case "room.state":
      self = .room(
        try fields.decodeIfPresent(RoomState.self, forKey: .room),
        bots: try fields.decodeIfPresent(Int.self, forKey: .botCount) ?? 0,
        serverTime: try fields.decodeIfPresent(Int64.self, forKey: .serverTime))
    case "game.state": self = .game(try GameFrame(from: decoder))
    case "game.event": self = .events(try fields.decode([GameEvent].self, forKey: .events))
    case "game.results":
      self = .results(
        try fields.decode(MatchResults.self, forKey: .results),
        endsAt: try fields.decodeIfPresent(Int64.self, forKey: .resultsEndsAt))
    case "test.control": self = .control(try TestControl(from: decoder))
    default: self = .unknown(type)
    }
  }
}

public enum Input: Encodable, Sendable {
  case obby(left: Bool, right: Bool, jump: Bool, tick: Int?)
  case plan(tick: Int, entries: [[Int]])
  case tag(dx: Double, dy: Double)
  case place(cell: Int, item: String)
  case remove(cell: Int)
  case upgrade(String)
  private enum CodingKeys: String, CodingKey { case l, r, j, t, plan, dx, dy, a, cell, item }
  public func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .obby(let left, let right, let jump, let tick):
      try values.encode(left, forKey: .l)
      try values.encode(right, forKey: .r)
      try values.encode(jump, forKey: .j)
      try values.encodeIfPresent(tick, forKey: .t)
    case .plan(let tick, let entries):
      try values.encode(tick, forKey: .t)
      try values.encode(entries, forKey: .plan)
    case .tag(let dx, let dy):
      try values.encode((dx * 100).rounded() / 100, forKey: .dx)
      try values.encode((dy * 100).rounded() / 100, forKey: .dy)
    case .place(let cell, let item):
      try values.encode("place", forKey: .a)
      try values.encode(cell, forKey: .cell)
      try values.encode(item, forKey: .item)
    case .remove(let cell):
      try values.encode("remove", forKey: .a)
      try values.encode(cell, forKey: .cell)
    case .upgrade(let item):
      try values.encode("upgrade", forKey: .a)
      try values.encode(item, forKey: .item)
    }
  }
}

public struct TestReport: Encodable, Sendable {
  public var name, room, code, checksum, screen, experience: String?
  public var members, round: Int?
  public var entries: [LeaderboardEntry]?
  public var rendered: Bool?
  public init(
    name: String? = nil, room: String? = nil, code: String? = nil,
    checksum: String? = nil, screen: String? = nil, experience: String? = nil,
    members: Int? = nil, round: Int? = nil, entries: [LeaderboardEntry]? = nil
  ) {
    self.name = name
    self.room = room
    self.code = code
    self.checksum = checksum
    self.screen = screen
    self.experience = experience
    self.members = members
    self.round = round
    self.entries = entries
  }
}

public enum FriendAction: String, Sendable { case request, accept, decline, remove }

public enum Command: Encodable, Sendable {
  case hello(name: String?, token: String?, platform: String)
  case ping(Int64)
  case avatar(Avatar)
  case buy(String)
  case daily, places
  case rate(Experience, Bool?)
  case friend(FriendAction, String)
  case profile(String?)
  case partyCreate(String?)
  case partyJoin(String)
  case partyLeave
  case partyLaunch(Experience, bots: Int)
  case chat(ChatChannel, String)
  case roomCreate(Experience, bots: Int)
  case roomJoin(String)
  case roomLeave
  case ready(Bool)
  case input(Input)
  case report(String, TestReport)

  private enum CodingKeys: String, CodingKey {
    case type, protocolVersion, name, token, platform, nonce, avatar, item, place, up
    case player, code, experience, bots, channel, text, ready, data, phase, payload
  }
  public func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    let type: String
    switch self {
    case .hello(let name, let token, let platform):
      type = "hello"
      try values.encode(1, forKey: .protocolVersion)
      try values.encodeIfPresent(name, forKey: .name)
      try values.encodeIfPresent(token, forKey: .token)
      try values.encode(platform, forKey: .platform)
    case .ping(let nonce):
      type = "ping"
      try values.encode(nonce, forKey: .nonce)
    case .avatar(let avatar):
      type = "avatar.update"
      try values.encode(avatar, forKey: .avatar)
    case .buy(let item):
      type = "shop.buy"
      try values.encode(item, forKey: .item)
    case .daily: type = "daily.claim"
    case .places: type = "places.list"
    case .rate(let place, let vote):
      type = "place.rate"
      try values.encode(place, forKey: .place)
      try values.encode(vote, forKey: .up)
    case .friend(let action, let player):
      type = "friends.\(action.rawValue)"
      try values.encode(player, forKey: .player)
    case .profile(let player):
      type = "profile.get"
      try values.encodeIfPresent(player, forKey: .player)
    case .partyCreate(let code):
      type = "party.create"
      try values.encodeIfPresent(code, forKey: .code)
    case .partyJoin(let code):
      type = "party.join"
      try values.encode(code.uppercased(), forKey: .code)
    case .partyLeave: type = "party.leave"
    case .partyLaunch(let experience, let bots):
      type = "party.launch"
      try values.encode(experience, forKey: .experience)
      try values.encode(bots, forKey: .bots)
    case .chat(let channel, let text):
      type = "chat.send"
      try values.encode(channel, forKey: .channel)
      try values.encode(text, forKey: .text)
    case .roomCreate(let experience, let bots):
      type = "room.create"
      try values.encode(experience, forKey: .experience)
      try values.encode(bots, forKey: .bots)
    case .roomJoin(let code):
      type = "room.join"
      try values.encode(code.uppercased(), forKey: .code)
    case .roomLeave: type = "room.leave"
    case .ready(let ready):
      type = "room.ready"
      try values.encode(ready, forKey: .ready)
    case .input(let input):
      type = "input"
      try values.encode(input, forKey: .data)
    case .report(let phase, let payload):
      type = "test.report"
      try values.encode(phase, forKey: .phase)
      try values.encode(payload, forKey: .payload)
    }
    try values.encode(type, forKey: .type)
  }
  public func data() throws -> Data { try JSONEncoder().encode(self) }
}

public enum Endpoint {
  public static func validated(_ value: String) throws -> URL {
    guard
      let components = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
      ["ws", "wss"].contains(components.scheme?.lowercased() ?? ""),
      let host = components.host, !host.isEmpty,
      components.user == nil, components.password == nil,
      components.fragment == nil, let url = components.url
    else {
      throw URLError(.badURL)
    }
    return url
  }
}

public struct LaunchConfig: Sendable {
  public let server, name, party, theme: String?
  public let test, host, tour, phaseMarker, autoReady: Bool
  public let players, bots, frameIntervalMS: Int
  public let experience: Experience
  public init(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    arguments: [String] = ProcessInfo.processInfo.arguments
  ) {
    var values = environment
    var index = 1
    while index < arguments.count {
      let arg = arguments[index]
      if arg.hasPrefix("--brickfolk-") {
        let pieces = String(arg.dropFirst(12)).split(separator: "=", maxSplits: 1).map(String.init)
        guard let argumentName = pieces.first, !argumentName.isEmpty else {
          index += 1
          continue
        }
        let key = "BRICKFOLK_" + argumentName.replacingOccurrences(of: "-", with: "_").uppercased()
        if pieces.count == 2 {
          values[key] = pieces[1]
        } else if index + 1 < arguments.count && !arguments[index + 1].hasPrefix("--") {
          index += 1
          values[key] = arguments[index]
        } else {
          values[key] = "true"
        }
      }
      index += 1
    }
    func bool(_ key: String, fallback: Bool = false) -> Bool {
      guard let value = values["BRICKFOLK_" + key] else { return fallback }
      return ["true", "1", "yes"].contains(value.lowercased())
    }
    server = values["BRICKFOLK_SERVER"]
    name = values["BRICKFOLK_NAME"]
    party = values["BRICKFOLK_PARTY"]
    theme = values["BRICKFOLK_THEME"]
    test = bool("TEST")
    host = bool("HOST")
    tour = bool("TOUR")
    phaseMarker = bool("PHASE_MARKER")
    autoReady = bool("AUTO_READY", fallback: true)
    players = min(8, max(1, Int(values["BRICKFOLK_PLAYERS"] ?? "") ?? 4))
    bots = min(7, max(0, Int(values["BRICKFOLK_BOTS"] ?? "") ?? 2))
    frameIntervalMS = min(1000, max(8, Int(values["BRICKFOLK_FRAME_INTERVAL_MS"] ?? "") ?? 16))
    experience = Experience(rawValue: values["BRICKFOLK_EXPERIENCE"] ?? "") ?? .obby
  }
}
