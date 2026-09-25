import Foundation

public enum Experience: String, Codable, CaseIterable, Identifiable, Sendable {
  case obby, tycoon, tag
  public var id: String { rawValue }
  public var artwork: String {
    switch self {
    case .obby: return "skyline"
    case .tycoon: return "factory"
    case .tag: return "freeze"
    }
  }
}

public struct Avatar: Codable, Equatable, Sendable {
  public var headColor: UInt32 = 0xFFF5_C04A
  public var torsoColor: UInt32 = 0xFF3E_7BFA
  public var armColor: UInt32 = 0xFFF5_C04A
  public var legColor: UInt32 = 0xFF2F_9E5B
  public var face = "face_smile"
  public var hat = "hat_none"
  public var accessory = "acc_none"
  public init() {}
  public mutating func equip(_ item: CatalogItem) {
    switch item.slot {
    case .face: face = item.id
    case .hat: hat = item.id
    case .accessory: accessory = item.id
    }
  }
  public func equipped(_ item: CatalogItem) -> Bool {
    [face, hat, accessory].contains(item.id)
  }
}

public struct Player: Codable, Identifiable, Sendable {
  public let id, name: String
  public let avatar: Avatar
  public let platform: String
  public let isBot, online: Bool
}

public struct PlayerProfile: Codable, Identifiable, Sendable {
  public let id, name: String
  public let avatar: Avatar
  public let platform: String
  public let isBot, online: Bool
  public let pips: Int
  public let owned: Set<String>
  public let badges: [String]
  public let createdAt: Int64
  public let dailyStreak: Int
  public let lastDailyClaim: Int64?
  public let stats: [String: Int]
  private enum CodingKeys: String, CodingKey {
    case id, name, avatar, platform, isBot, online, pips, owned, badges, createdAt, dailyStreak,
      lastDailyClaim, stats
  }
  public init(from decoder: Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    id = try fields.decode(String.self, forKey: .id)
    name = try fields.decode(String.self, forKey: .name)
    avatar = try fields.decode(Avatar.self, forKey: .avatar)
    platform = try fields.decode(String.self, forKey: .platform)
    isBot = try fields.decode(Bool.self, forKey: .isBot)
    online = try fields.decode(Bool.self, forKey: .online)
    pips = try fields.decode(Int.self, forKey: .pips)
    owned = try fields.decodeIfPresent(Set<String>.self, forKey: .owned) ?? []
    badges = try fields.decode([String].self, forKey: .badges)
    createdAt = try fields.decode(Int64.self, forKey: .createdAt)
    dailyStreak = try fields.decode(Int.self, forKey: .dailyStreak)
    lastDailyClaim = try fields.decodeIfPresent(Int64.self, forKey: .lastDailyClaim)
    stats = try fields.decode([String: Int].self, forKey: .stats)
  }
}

public struct ChatMessage: Codable, Identifiable, Sendable {
  public let id: Int
  public let channel: ChatChannel
  public let from: Player
  public let text: String
  public let filtered: Bool
  public let timestamp: Int64
}

public enum ChatChannel: String, Codable, CaseIterable, Sendable {
  case global, party, room
}

public struct FriendsState: Codable, Sendable {
  public var friends: [Player] = []
  public var incoming: [Player] = []
  public var outgoing: [Player] = []
  public init() {}
}

public struct PartyState: Codable, Sendable {
  public let code, leaderId: String
  public let members: [Player]
  public let roomCode: String?
  public let experience: Experience?
}

public enum RoomPhase: String, Codable, Sendable {
  case lobby, countdown, playing, results
}

public struct RoomMember: Codable, Identifiable, Sendable {
  public let player: Player
  public let ready: Bool
  public var id: String { player.id }
}

public struct RoomState: Codable, Sendable {
  public let code: String
  public let experience: Experience
  public let phase: RoomPhase
  public let members: [RoomMember]
  public let seed, round: Int
  public let countdownEndsAt, matchEndsAt: Int64?
}

public struct RoomListing: Codable, Identifiable, Sendable {
  public let code: String
  public let players: Int
  public let phase: RoomPhase
  public var id: String { code }
}

public struct PlaceListing: Codable, Identifiable, Sendable {
  public let kind: Experience
  public let playing, visits, likes, dislikes: Int
  public let rooms: [RoomListing]
  public let myVote: Bool?
  public var id: Experience { kind }
}

public struct LeaderboardEntry: Codable, Identifiable, Sendable {
  public let rank: Int
  public let player: Player
  public let score: Int
  public let detail: String
  public let pipsEarned: Int
  public let badgesEarned: [String]
  public var id: String { player.id }
}

public struct MatchResults: Codable, Sendable {
  public let roomCode: String
  public let experience: Experience
  public let entries: [LeaderboardEntry]
  public let checksum: String
  public let durationMs: Int
  public var computedChecksum: String {
    var hash: Int64 = 7
    for entry in entries {
      let line = "\(entry.rank)|\(entry.player.name)|\(entry.score)|\(entry.detail)"
      for unit in line.utf16 { hash = (hash * 31 + Int64(unit)) % 1_000_000_007 }
    }
    return String(format: "%08llx", hash)
  }
}

public struct DailyResult: Codable, Sendable {
  public let claimed: Bool
  public let reward, streak: Int
  public let nextClaimAt: Int64
  public let badges: [String]?
}

public struct ServerError: Codable, Error, LocalizedError, Sendable {
  public let code, message: String
  public let inReplyTo: String?
  public var errorDescription: String? { message }
}

public struct GameEvent: Codable, Sendable {
  public let kind: String
  public let player, by: String?
  public let value: Int?
  public let swept: Bool?
}

public struct TestControl: Codable, Sendable {
  public let cmd: String
  public let platform, screen: String?
}

public struct Welcome: Codable, Sendable {
  public let protocolVersion: Int
  public let player: PlayerProfile
  public let token: String
  public let serverTime: Int64
  public let testMode: Bool
  public let roomCode, partyCode: String?
}

public struct ObbyPlayer: Decodable, Sendable {
  public let x, y, vx, vy: Double
  public let flags, checkpoint, deaths: Int
  public let finishTick: Int?
  public let respawnUntilTick, inputLag: Int
  public var grounded: Bool { flags & 1 != 0 }
  public var facingRight: Bool { flags & 2 != 0 }
  public init(from decoder: Decoder) throws {
    var values = try decoder.unkeyedContainer()
    x = try values.decode(Double.self)
    y = try values.decode(Double.self)
    vx = try values.decode(Double.self)
    vy = try values.decode(Double.self)
    flags = try values.decode(Int.self)
    checkpoint = try values.decode(Int.self)
    deaths = try values.decode(Int.self)
    finishTick = try values.decodeIfPresent(Int.self)
    respawnUntilTick = values.isAtEnd ? 0 : try values.decodeIfPresent(Int.self) ?? 0
    inputLag = values.isAtEnd ? -1 : try values.decodeIfPresent(Int.self) ?? -1
  }
}

public struct TagPlayer: Decodable, Sendable {
  public let x, y: Double
  public let flags, thawProgress, freezes, thaws, timesFrozen, roundScore, totalScore: Int
  public let facing: Double
  public var isTagger: Bool { flags & 1 != 0 }
  public var frozen: Bool { flags & 2 != 0 }
  public init(from decoder: Decoder) throws {
    var values = try decoder.unkeyedContainer()
    x = try values.decode(Double.self)
    y = try values.decode(Double.self)
    flags = try values.decode(Int.self)
    thawProgress = try values.decode(Int.self)
    freezes = try values.decode(Int.self)
    thaws = try values.decode(Int.self)
    timesFrozen = try values.decode(Int.self)
    roundScore = try values.decode(Int.self)
    totalScore = try values.decode(Int.self)
    facing = try values.decode(Double.self)
  }
}

public struct TycoonPlot: Codable, Sendable {
  public let cells: [String?]
  public let upgrades: Set<String>
  public let cash, earned, bricksPlaced: Int
  public func income(content: GameContent) -> Int {
    var base = 0
    for (index, item) in cells.enumerated() {
      base += content.bricks.first { $0.id == item }?.income ?? 0
      if item == "conveyor" {
        let neighbours = [
          index % 6 > 0 ? index - 1 : -1,
          index % 6 < 5 ? index + 1 : -1,
          index - 6, index + 6,
        ]
        base += neighbours.filter { cells.indices.contains($0) && cells[$0] == "dropper" }.count
      }
    }
    let multiplier = content.upgrades.filter { upgrades.contains($0.id) }
      .reduce(1.0) { $0 * $1.multiplier }
    return Int((Double(base) * multiplier).rounded(.down))
  }
}

public struct ObbyFrame: Decodable, Sendable {
  public let tick, ticksLeft: Int
  public let players: [String: ObbyPlayer]
}
public struct TagFrame: Decodable, Sendable {
  public let tick, ticksLeft, round, roundTicksLeft, intermission: Int
  public let players: [String: TagPlayer]
}
public struct TycoonFrame: Decodable, Sendable {
  public let tick, ticksLeft: Int
  public let plots: [String: TycoonPlot]
  public let earned: [String: Int]
}

public enum GameFrame: Decodable, Sendable {
  case obby(ObbyFrame)
  case tag(TagFrame)
  case tycoon(TycoonFrame)
  private enum CodingKeys: String, CodingKey { case plots, round }
  public init(from decoder: Decoder) throws {
    let keys = try decoder.container(keyedBy: CodingKeys.self)
    if keys.contains(.plots) {
      self = .tycoon(try TycoonFrame(from: decoder))
    } else if keys.contains(.round) {
      self = .tag(try TagFrame(from: decoder))
    } else {
      self = .obby(try ObbyFrame(from: decoder))
    }
  }
  public var tick: Int {
    switch self {
    case .obby(let frame): return frame.tick
    case .tag(let frame): return frame.tick
    case .tycoon(let frame): return frame.tick
    }
  }
}
