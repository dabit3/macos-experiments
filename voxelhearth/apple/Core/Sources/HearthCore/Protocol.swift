import Foundation

public struct ItemStack: Codable, Equatable, Sendable {
  public var id: Int
  public var count: Int
  public static let empty = ItemStack(id: 0, count: 0)
  public var isEmpty: Bool { id == 0 || count <= 0 }
  public init(id: Int, count: Int) {
    self.id = id
    self.count = count
  }
  public init(from decoder: Decoder) throws {
    var values = try decoder.unkeyedContainer()
    id = try values.decode(Int.self)
    count = try values.decode(Int.self)
  }
  public func encode(to encoder: Encoder) throws {
    var values = encoder.unkeyedContainer()
    try values.encode(id)
    try values.encode(count)
  }
}

public struct Player: Codable, Identifiable, Sendable {
  public var id: String
  public var name: String?
  public var platform: String?
  public var bot: Bool?
  public var connected: Bool?
  public var ready: Bool?
  public var score: Int?
  public var placed: Int?
  public var broken: Int?
  public var crafted: Int?
  public var kills: Int?
  public var deaths: Int?
  public var x: Double?
  public var y: Double?
  public var z: Double?
  public var yaw: Double?
  public var pitch: Double?
  public var held: Int?
  public var sneak: Bool?
  public var sleep: Bool?
  public var hp: Int?
}

public struct Mob: Codable, Identifiable, Sendable {
  public var id: Int
  public var kind: String
  public var x: Double
  public var y: Double
  public var z: Double
  public var yaw: Double
  public var hp: Int
  public var hurt: Bool
}

public struct RoomSummary: Codable, Identifiable, Sendable {
  public var id: String { code }
  public var code: String
  public var name: String
  public var mode: String
  public var phase: String
  public var players: Int
  public var humans: Int
}

public struct ChatLine: Codable, Sendable {
  public var tick: Int
  public var from: String
  public var text: String
  public var system: Bool
  public init(tick: Int, from: String, text: String, system: Bool) {
    self.tick = tick
    self.from = from
    self.text = text
    self.system = system
  }
}

public struct Kiln: Codable, Sendable {
  public var input: ItemStack
  public var fuel: ItemStack
  public var output: ItemStack
  public var burnLeft: Int
  public var burnTotal: Int
  public var cook: Int
  public var cookTotal: Int
}

public struct ServerMessage: Decodable, Sendable {
  public var t: String
  public var action: DriveAction?
  public var region: [Int]?
  public var code: String?
  public var msg: String?
  public var name: String?
  public var roomName: String?
  public var playerId: String?
  public var token: String?
  public var serverVersion: Int?
  public var testMode: Bool?
  public var tickHz: Int?
  public var rooms: [RoomSummary]?
  public var seed: Int?
  public var mode: String?
  public var phase: String?
  public var time: Int?
  public var freezeTime: Bool?
  public var spawnMobs: Bool?
  public var durationTicks: Int?
  public var matchEndTick: Int?
  public var tick: Int?
  public var you: String?
  public var host: String?
  public var spawn: [Int]?
  public var x: Double?
  public var y: Double?
  public var z: Double?
  public var yaw: Double?
  public var pitch: Double?
  public var players: [Player]?
  public var player: Player?
  public var mobs: [Mob]?
  public var chat: [ChatLine]?
  public var cx: Int?
  public var cz: Int?
  public var edits: [Int]?
  public var id: WireID?
  public var by: String?
  public var slots: [ItemStack]?
  public var selected: Int?
  public var hp: Int?
  public var food: Int?
  public var air: Int?
  public var score: Int?
  public var kind: String?
  public var pos: Int64?
  public var kiln: Kiln?
  public var text: String?
  public var from: String?
  public var system: Bool?
  public var results: [Player]?
  public var worldHash: String?
  public var chatHash: String?
  public var ts: Int64?
}

public enum WireID: Decodable, Sendable {
  case number(Int)
  case player(String)
  public var number: Int? {
    if case .number(let id) = self { return id }
    return nil
  }
  public var player: String? {
    if case .player(let id) = self { return id }
    return nil
  }
  public init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer()
    if let number = try? value.decode(Int.self) {
      self = .number(number)
    } else {
      self = .player(try value.decode(String.self))
    }
  }
}

public enum Intent: String, Codable, Sendable {
  case hello, ping, move, interact, craft, eat, attack, sleep, chat, ready, give, respawn
  case breakBlock = "break"
  case place = "place"
  case listRooms = "list_rooms"
  case createRoom = "create_room"
  case joinRoom = "join_room"
  case leaveRoom = "leave_room"
  case startMatch = "start_match"
  case endMatch = "end_match"
  case backToLobby = "back_to_lobby"
  case addBot = "add_bot"
  case removeBot = "remove_bot"
  case roomSettings = "room_settings"
  case setMode = "set_mode"
  case setTime = "set_time"
  case renameRoom = "rename_room"
  case selectSlot = "select_slot"
  case moveItem = "move_item"
  case kilnPut = "kiln_put"
  case chestPut = "chest_put"
  case dropItem = "drop_item"
  case closeUI = "close_ui"
  case requestChunks = "request_chunks"
}

public struct ClientMessage: Codable, Sendable {
  public var t: Intent
  public var name: String?
  public var platform: String?
  public var token: String?
  public var version: Int?
  public var code: String?
  public var mode: String?
  public var seed: Int?
  public var durationTicks: Int?
  public var freezeTime: Bool?
  public var spawnMobs: Bool?
  public var bots: Int?
  public var startTime: Int?
  public var value: Bool?
  public var ready: Bool?
  public var time: Int?
  public var x: Double?
  public var y: Double?
  public var z: Double?
  public var vx: Double?
  public var vy: Double?
  public var vz: Double?
  public var yaw: Double?
  public var pitch: Double?
  public var ground: Bool?
  public var sneak: Bool?
  public var sprint: Bool?
  public var fly: Bool?
  public var seq: Int?
  public var nx: Int?
  public var ny: Int?
  public var nz: Int?
  public var slot: Int?
  public var from: Int?
  public var to: Int?
  public var count: Int?
  public var grid: [Int]?
  public var n: Int?
  public var id: Int?
  public var text: String?
  public var kslot: String?
  public var cslot: Int?
  public var toChest: Bool?
  public var ts: Int64?
  public init(_ t: Intent) { self.t = t }
  public static func block(_ intent: Intent, _ x: Int, _ y: Int, _ z: Int) -> Self {
    var message = Self(intent)
    message.x = Double(x)
    message.y = Double(y)
    message.z = Double(z)
    return message
  }
}

public enum ServerAddress {
  public static func parse(_ value: String) -> URL? {
    guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
      ["ws", "wss"].contains(url.scheme?.lowercased() ?? ""),
      let host = url.host, !host.isEmpty, url.user == nil, url.password == nil
    else { return nil }
    return url
  }
}

public struct LaunchConfiguration {
  public var server: String?
  public var name: String?
  public var join: String?
  public var create: Bool
  public var test: Bool
  public init(
    arguments: [String] = ProcessInfo.processInfo.arguments,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) {
    var values = environment
    for (index, argument) in arguments.enumerated() {
      let trimmed = argument.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
      let pair = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
      guard let first = pair.first else { continue }
      let key = first.uppercased().replacingOccurrences(of: "-", with: "_")
      let canonical = key.hasPrefix("VH_") ? key : "VH_" + key
      guard ["VH_SERVER", "VH_NAME", "VH_JOIN", "VH_CREATE", "VH_TEST"].contains(canonical) else {
        continue
      }
      values[canonical] =
        pair.count == 2
        ? pair[1]
        : (index + 1 < arguments.count && !arguments[index + 1].hasPrefix("-")
          ? arguments[index + 1] : "1")
    }
    server = values["VH_SERVER"]
    name = values["VH_NAME"]
    join = values["VH_JOIN"]
    create = ["1", "true"].contains(values["VH_CREATE"] ?? "")
    test = ["1", "true"].contains(values["VH_TEST"] ?? "")
  }
}
