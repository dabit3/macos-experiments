import Foundation

enum BoardID: String, Codable, CaseIterable, Identifiable {
  case a, b
  var id: String { rawValue }
  var label: String { rawValue.uppercased() }
  var other: Self { self == .a ? .b : .a }
}

enum Side: String, Codable, CaseIterable {
  case white = "w"
  case black = "b"
  var opposite: Self { self == .white ? .black : .white }
  var label: String { self == .white ? "White" : "Black" }
}

enum Team: String, Codable, CaseIterable, Identifiable {
  case tidal = "1"
  case ember = "2"
  var id: String { rawValue }
  var label: String { self == .tidal ? "TIDAL" : "EMBER" }
}

enum Seat: String, Codable, CaseIterable, Identifiable {
  case aw, ab, bw, bb
  var id: String { rawValue }
  var board: BoardID { self == .aw || self == .ab ? .a : .b }
  var color: Side { self == .aw || self == .bw ? .white : .black }
  var team: Team { self == .aw || self == .bb ? .tidal : .ember }
  var partner: Self {
    switch self {
    case .aw: return .bb
    case .ab: return .bw
    case .bw: return .ab
    case .bb: return .aw
    }
  }
  var opponent: Self { Self.at(board, color.opposite) }
  var label: String { "Board \(board.label) · \(color.label)" }
  static func at(_ board: BoardID, _ side: Side) -> Self {
    switch (board, side) {
    case (.a, .white): return .aw
    case (.a, .black): return .ab
    case (.b, .white): return .bw
    case (.b, .black): return .bb
    }
  }
}

enum PieceKind: String, Codable, CaseIterable, Identifiable {
  case pawn = "P"
  case knight = "N"
  case bishop = "B"
  case rook = "R"
  case queen = "Q"
  case king = "K"
  var id: String { rawValue }
  var label: String {
    switch self {
    case .pawn: return "Pawn"
    case .knight: return "Knight"
    case .bishop: return "Bishop"
    case .rook: return "Rook"
    case .queen: return "Queen"
    case .king: return "King"
    }
  }
  static let reserve: [Self] = [.pawn, .knight, .bishop, .rook, .queen]
  static let promotions: [Self] = [.queen, .rook, .bishop, .knight]
}

struct Piece: Equatable {
  let color: Side
  let kind: PieceKind
  var promoted = false
}

struct Square: Hashable, Codable, CustomStringConvertible {
  let index: Int
  var file: Int { index % 8 }
  var rank: Int { index / 8 }
  var description: String { "\(Array("abcdefgh")[file])\(rank + 1)" }
  init(_ index: Int) {
    precondition((0..<64).contains(index))
    self.index = index
  }
  init?(_ text: String) {
    let chars = Array(text)
    guard chars.count == 2, let f = Array("abcdefgh").firstIndex(of: chars[0]),
      let r = chars[1].wholeNumberValue, (1...8).contains(r)
    else { return nil }
    index = (r - 1) * 8 + f
  }
  init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer()
    guard let square = Square(try value.decode(String.self)) else {
      throw DecodingError.dataCorruptedError(in: value, debugDescription: "Invalid square")
    }
    self = square
  }
  func encode(to encoder: Encoder) throws {
    var value = encoder.singleValueContainer()
    try value.encode(description)
  }
}

struct Move: Codable, Hashable {
  var from: Square?
  let to: Square
  var promotion: PieceKind?
  var drop: PieceKind?
  var uci: String {
    if let drop { return "\(drop.rawValue)@\(to)" }
    return "\(from?.description ?? "")\(to)\(promotion?.rawValue.lowercased() ?? "")"
  }
  init(from: Square? = nil, to: Square, promotion: PieceKind? = nil, drop: PieceKind? = nil) {
    self.from = from
    self.to = to
    self.promotion = promotion
    self.drop = drop
  }
  init?(uci: String) {
    let chars = Array(uci)
    guard chars.count == 4 || chars.count == 5 else { return nil }
    guard let to = Square(String(chars[2...3])) else { return nil }
    if chars[1] == "@", chars.count == 4,
      let kind = PieceKind(rawValue: String(chars[0]).uppercased()),
      PieceKind.reserve.contains(kind)
    {
      self.init(to: to, drop: kind)
    } else {
      guard let from = Square(String(chars[0...1])) else { return nil }
      let promotion = chars.count == 5 ? PieceKind(rawValue: String(chars[4]).uppercased()) : nil
      if chars.count == 5 && !PieceKind.promotions.contains(where: { $0 == promotion }) {
        return nil
      }
      self.init(from: from, to: to, promotion: promotion)
    }
  }
}

struct TimeControl: Codable, Hashable {
  let initialMs: Int
  let incrementMs: Int
  static let presets = [
    Self(initialMs: 60_000, incrementMs: 0), Self(initialMs: 180_000, incrementMs: 0),
    Self(initialMs: 180_000, incrementMs: 2_000), Self(initialMs: 300_000, incrementMs: 0),
    Self(initialMs: 300_000, incrementMs: 3_000),
  ]
  var label: String { "\(initialMs / 60_000)+\(incrementMs / 1_000)" }
}

struct PlayerInfo: Codable, Identifiable {
  let id: String
  let name: String
  let seat: Seat?
  let ready: Bool
  let bot: Bool
  let connected: Bool
  let platform: String
}

enum RoomPhase: String, Codable { case lobby, playing, finished }

struct RoomState: Codable {
  let code: String
  let phase: RoomPhase
  let host: String
  let timeControl: TimeControl
  let players: [PlayerInfo]
  let spectators: [PlayerInfo]
  let rematchVotes: [String]
  func seated(_ seat: Seat) -> PlayerInfo? { players.first { $0.seat == seat } }
  func player(_ id: String?) -> PlayerInfo? { (players + spectators).first { $0.id == id } }
}

struct BoardClock: Codable {
  let w: Int
  let b: Int
  let running: Side?
  func remaining(_ color: Side, sampledAt: Int64, now: Int64) -> Int {
    max(0, (color == .white ? w : b) - (running == color ? max(0, Int(now - sampledAt)) : 0))
  }
}

struct BoardSnapshot: Codable {
  let id: BoardID
  let fen: String
  let clock: BoardClock
  let lastMove: Move?
  let inCheck: Bool
}

struct Boards: Codable {
  let a: BoardSnapshot
  let b: BoardSnapshot
  subscript(_ board: BoardID) -> BoardSnapshot { board == .a ? a : b }
}

enum ResultReason: String, Codable {
  case checkmate, timeout, resignation, stalemate, repetition, agreement, abandonment
}

struct MatchResult: Codable {
  let winner: Team?
  let reason: ResultReason
  let board: BoardID?
  let loser: Seat?
  var score: String { winner == .tidal ? "1–0" : winner == .ember ? "0–1" : "½–½" }
}

struct MatchMove: Codable, Identifiable {
  let seq: Int
  let board: BoardID
  let color: Side
  let number: Int
  let move: Move
  let san: String
  let clockMs: Int
  let captured: PieceKind?
  var id: Int { seq }
  var notation: String { "\(number)\(color == .white ? board.label : board.id). \(san)" }
}

struct GameState: Codable {
  let gameId: String
  let boards: Boards
  let moves: [MatchMove]
  let result: MatchResult?
  let serverTime: Int64
  let premove: Move?
  let drawOffers: [Seat]
  let bpgn: String?
}

enum QuickChat: String, Codable, CaseIterable, Identifiable {
  case needPawn = "need_p"
  case needKnight = "need_n"
  case needBishop = "need_b"
  case needRook = "need_r"
  case needQueen = "need_q"
  case noQueen = "no_q"
  case sit, go, trades, mating, help, gg, thanks, sorry
  var id: String { rawValue }
  var text: String {
    switch self {
    case .needPawn: return "Need a pawn!"
    case .needKnight: return "Need a knight!"
    case .needBishop: return "Need a bishop!"
    case .needRook: return "Need a rook!"
    case .needQueen: return "Need a queen!"
    case .noQueen: return "Don't give up your queen"
    case .sit: return "Sit! Don't move"
    case .go: return "Go go go!"
    case .trades: return "Trade everything"
    case .mating: return "I'm mating soon"
    case .help: return "Help, I'm getting mated"
    case .gg: return "Good game"
    case .thanks: return "Thanks!"
    case .sorry: return "Sorry!"
    }
  }
}

enum ChatScope: String, Codable { case room, team }

struct ChatMessage: Codable, Identifiable {
  let from: String
  let name: String
  let seat: Seat?
  let ts: Int64
  let scope: ChatScope
  let quick: QuickChat?
  let text: String?
  var display: String { quick?.text ?? text ?? "" }
  var id: String { "\(from):\(ts):\(scope):\(display)" }
}

struct GameEvent: Codable {
  enum Kind: String, Codable { case move, drop, pass, start, finish }
  let kind: Kind
  let board: BoardID?
  let seat: Seat?
  let move: Move?
  let san: String?
  let captured: PieceKind?
  let toBoard: BoardID?
  let toColor: Side?
}

struct Welcome: Decodable {
  let v: Int
  let playerId: String
  let resumeToken: String
  let room: String?
  let serverTime: Int64
  let testMode: Bool
}

struct Pong: Decodable {
  let t: Int64
  let serverTime: Int64
}
struct ServerError: Decodable, Error {
  let code: String
  let message: String
  let ref: String?
}

enum ServerMessage: Decodable {
  case welcome(Welcome)
  case pong(Pong)
  case room(RoomState?)
  case game(GameState)
  case event(GameEvent)
  case chat(ChatMessage)
  case error(ServerError)
  case test(TestCommand)
  private enum Keys: String, CodingKey { case type, room, game, event, message }
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: Keys.self)
    switch try c.decode(String.self, forKey: .type) {
    case "welcome": self = .welcome(try Welcome(from: decoder))
    case "pong": self = .pong(try Pong(from: decoder))
    case "room.state": self = .room(try c.decodeIfPresent(RoomState.self, forKey: .room))
    case "game.state": self = .game(try c.decode(GameState.self, forKey: .game))
    case "game.event": self = .event(try c.decode(GameEvent.self, forKey: .event))
    case "chat.message": self = .chat(try c.decode(ChatMessage.self, forKey: .message))
    case "error": self = .error(try ServerError(from: decoder))
    case "test.command": self = .test(try TestCommand(from: decoder))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type, in: c, debugDescription: "Unknown server message")
    }
  }
}

enum DrawAction: String, Encodable { case offer, accept, decline }
enum ClientCommand: Encodable {
  case hello(name: String, platform: String, resumeToken: String?, testId: String?)
  case ping(Int64)
  case create(TimeControl?, fillBots: Bool, code: String?)
  case join(String, spectate: Bool)
  case leave
  case seat(Seat?)
  case bot(Seat, add: Bool)
  case ready(Bool)
  case start
  case timeControl(TimeControl)
  case rematch
  case move(Move)
  case premove(Move?)
  case resign
  case draw(DrawAction)
  case chat(String, ChatScope)
  case quick(QuickChat, ChatScope)
  private enum Keys: String, CodingKey {
    case type, v, name, platform, resumeToken, testId, t, timeControl, fillBots, code
    case spectate, seat, add, ready, move, action, text, scope, quick
  }
  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    func type(_ value: String) throws { try c.encode(value, forKey: .type) }
    switch self {
    case .hello(let name, let platform, let token, let testId):
      try type("hello")
      try c.encode(1, forKey: .v)
      try c.encode(name, forKey: .name)
      try c.encode(platform, forKey: .platform)
      try c.encodeIfPresent(token, forKey: .resumeToken)
      try c.encodeIfPresent(testId, forKey: .testId)
    case .ping(let t):
      try type("ping")
      try c.encode(t, forKey: .t)
    case .create(let tc, let bots, let code):
      try type("room.create")
      try c.encodeIfPresent(tc, forKey: .timeControl)
      try c.encode(bots, forKey: .fillBots)
      try c.encodeIfPresent(code, forKey: .code)
    case .join(let code, let spectate):
      try type("room.join")
      try c.encode(code, forKey: .code)
      try c.encode(spectate, forKey: .spectate)
    case .leave: try type("room.leave")
    case .seat(let seat):
      try type("room.seat")
      try c.encode(seat, forKey: .seat)
    case .bot(let seat, let add):
      try type("room.bot")
      try c.encode(seat, forKey: .seat)
      try c.encode(add, forKey: .add)
    case .ready(let ready):
      try type("room.ready")
      try c.encode(ready, forKey: .ready)
    case .start: try type("room.start")
    case .timeControl(let tc):
      try type("room.timeControl")
      try c.encode(tc, forKey: .timeControl)
    case .rematch: try type("room.rematch")
    case .move(let move):
      try type("game.move")
      try c.encode(move, forKey: .move)
    case .premove(let move):
      try type("game.premove")
      try c.encode(move, forKey: .move)
    case .resign: try type("game.resign")
    case .draw(let action):
      try type("game.draw")
      try c.encode(action, forKey: .action)
    case .chat(let text, let scope):
      try type("chat.send")
      try c.encode(text, forKey: .text)
      try c.encode(scope, forKey: .scope)
    case .quick(let quick, let scope):
      try type("chat.send")
      try c.encode(quick, forKey: .quick)
      try c.encode(scope, forKey: .scope)
    }
  }
}

struct TestCommand: Decodable {
  let id: String
  let cmd: String
  let code: String?
  let fillBots: Bool?
  let timeControl: TimeControl?
  let spectate: Bool?
  let seat: Seat?
  let add: Bool?
  let ready: Bool?
  let uci: String?
  let text: String?
  let action: String?
  let mode: String?
  let phase: RoomPhase?
  let moves: Int?
  let over: Bool?
  let timeoutMs: Int?
}
