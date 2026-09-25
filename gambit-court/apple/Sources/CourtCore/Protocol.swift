import Foundation

public enum Side: String, Codable, CaseIterable, Sendable {
    case white = "w", black = "b"
    public var opposite: Side {
        self == .white ? .black : .white
    }

    public var label: String {
        self == .white ? "White" : "Black"
    }
}

public struct TimeControl: Codable, Hashable, Sendable {
    public var initialMs: Int
    public var incrementMs: Int
    public init(initialMs: Int, incrementMs: Int) {
        self.initialMs = initialMs
        self.incrementMs = incrementMs
    }

    public static let standard = TimeControl(initialMs: 300_000, incrementMs: 3000)
    public static let unlimited = TimeControl(initialMs: 0, incrementMs: 0)
    public var isUnlimited: Bool {
        initialMs == 0 && incrementMs == 0
    }

    public static let presets = [(1, 0), (2, 1), (3, 0), (3, 2), (5, 0), (5, 3),
                                 (10, 0), (10, 5), (15, 10), (30, 0), (30, 20), (90, 30)]
        .map { TimeControl(initialMs: $0.0 * 60000, incrementMs: $0.1 * 1000) }
    public var label: String {
        if isUnlimited {
            return "∞"
        }
        let minutes = Double(initialMs) / 60000
        return "\(minutes.rounded() == minutes ? String(Int(minutes)) : String(format: "%.1f", minutes))+\(incrementMs / 1000)"
    }

    public var category: String {
        if isUnlimited {
            return "Unlimited"
        }
        let seconds = initialMs / 1000 + 40 * incrementMs / 1000
        return seconds < 180 ? "Bullet" : seconds < 600 ? "Blitz" : seconds < 1800 ? "Rapid" : "Classical"
    }
}

public struct Participant: Codable, Equatable, Sendable {
    public let clientId: String
    public let name: String
    public let platform: String
    public let connected: Bool
    public let isBot: Bool
    public let botLevel: Int?
}

public enum RoomStatus: String, Codable, Sendable { case waiting, playing, finished }
public enum Outcome: String, Codable, Sendable { case whiteWins, blackWins, draw }
public enum EndReason: String, Codable, Sendable {
    case checkmate, stalemate, resignation, timeout, agreement, threefoldRepetition
    case fiftyMoveRule, insufficientMaterial, abandonment
    public var label: String {
        switch self {
        case .threefoldRepetition: "Threefold repetition"
        case .fiftyMoveRule: "Fifty-move rule"
        case .insufficientMaterial: "Insufficient material"
        default: rawValue.capitalized
        }
    }
}

public struct GameResult: Codable, Equatable, Sendable {
    public let outcome: Outcome
    public let reason: EndReason
    public var score: String {
        outcome == .whiteWins ? "1-0" : outcome == .blackWins ? "0-1" : "1/2-1/2"
    }

    public var headline: String {
        outcome == .whiteWins ? "White wins" : outcome == .blackWins ? "Black wins" : "Draw"
    }

    public var winner: Side? {
        outcome == .whiteWins ? .white : outcome == .blackWins ? .black : nil
    }

    public var description: String {
        "\(headline) · \(reason.label)"
    }
}

public struct Offers: Codable, Equatable, Sendable {
    public let draw: Side?
    public let takeback: Side?
    public let rematch: Side?
}

public struct PlayedMove: Codable, Equatable, Sendable {
    public let uci: String
    public let san: String
    public let fen: String
    public init(uci: String, san: String, fen: String) {
        self.uci = uci
        self.san = san
        self.fen = fen
    }
}

public struct ClockState: Codable, Equatable, Sendable {
    public let whiteMs: Int
    public let blackMs: Int
    public let running: Side?
    public let asOfServerMs: Int
    public let frozen: Bool
    public func remaining(_ side: Side, serverNowMs: Int) -> Int {
        let base = side == .white ? whiteMs : blackMs
        return max(0, base - (running == side && !frozen ? max(0, serverNowMs - asOfServerMs) : 0))
    }

    public static func format(_ milliseconds: Int) -> String {
        let ms = max(0, milliseconds)
        let seconds = ms / 1000
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        }
        let base = String(format: "%d:%02d", seconds / 60, seconds % 60)
        return ms < 20000 ? "\(base).\(ms / 100 % 10)" : base
    }
}

public struct RoomSnapshot: Codable, Equatable, Sendable {
    public let code: String
    public let seq: Int
    public let status: RoomStatus
    public let timeControl: TimeControl
    public let white: Participant?
    public let black: Participant?
    public let spectators: [Participant]
    public let hostClientId: String?
    public let startFen: String
    public let fen: String
    public let moves: [PlayedMove]
    public let turn: Side
    public let clocks: ClockState
    public let result: GameResult?
    public let offers: Offers
    public let rematchRoom: String?
    public let isPublic: Bool
    public func player(_ side: Side) -> Participant? {
        side == .white ? white : black
    }

    public func side(of clientId: String) -> Side? {
        white?.clientId == clientId ? .white : black?.clientId == clientId ? .black : nil
    }
}

public struct RoomListing: Codable, Equatable, Identifiable, Sendable {
    public var id: String {
        code
    }

    public let code: String
    public let hostName: String
    public let hostPlatform: String
    public let timeControl: TimeControl
    public let status: RoomStatus
    public let playerCount: Int
    public let spectatorCount: Int
    public let hasBot: Bool
}

public enum Intent: String, Codable, Sendable {
    case hello, ping, move, resign
    case setName = "set_name", listRooms = "list_rooms", createRoom = "create_room"
    case joinRoom = "join_room", quickPair = "quick_pair", cancelPair = "cancel_pair"
    case leaveRoom = "leave_room", addBot = "add_bot"
    case offerDraw = "offer_draw", acceptDraw = "accept_draw", declineDraw = "decline_draw"
    case offerTakeback = "offer_takeback", acceptTakeback = "accept_takeback", declineTakeback = "decline_takeback"
    case offerRematch = "offer_rematch", acceptRematch = "accept_rematch", declineRematch = "decline_rematch"
}

public enum SidePreference: String, Codable, CaseIterable, Sendable { case white, black, random }
public struct ClientMessage: Codable, Sendable {
    public var type: Intent
    public var clientId: String?
    public var name: String?
    public var platform: String?
    public var `protocol`: Int?
    public var timeControl: TimeControl?
    public var side: SidePreference?
    public var botLevel: Int?
    public var isPublic: Bool?
    public var code: String?
    public var asSpectator: Bool?
    public var botAfterMs: Int?
    public var uci: String?
    public var nonce: String?
    public init(_ type: Intent) {
        self.type = type
    }
}

public struct Welcome: Codable, Sendable {
    public let `protocol`: Int
    public let clientId: String
    public let name: String
    public let serverTimeMs: Int
    public let frozenClocks: Bool
    public let room: RoomSnapshot?
}

public struct RoomList: Codable, Sendable {
    public let rooms: [RoomListing]
    public let online: Int
}

public struct QueueState: Codable, Sendable {
    public let timeControl: TimeControl
    public let position: Int
    public let botAfterMs: Int?
}

public struct ServerError: Codable, Sendable {
    public let code: String
    public let message: String
    public let about: String?
    public let fatal: Bool?
}

public struct Pong: Codable, Sendable {
    public let nonce: String?
    public let serverTimeMs: Int
}

public struct AutomationCommand: Codable, Sendable {
    public let id: String
    public let action: String
    public let name: String?
    public let theme: String?
    public let timeControl: TimeControl?
    public let side: SidePreference?
    public let botLevel: Int?
    public let isPublic: Bool?
    public let code: String?
    public let asSpectator: Bool?
    public let bot: Bool?
    public let uci: String?
    public let ply: Int?
    public let pgn: String?
}

public enum ServerMessage: Decodable, Sendable {
    case welcome(Welcome), rooms(RoomList), room(RoomSnapshot), queued(QueueState)
    case left, error(ServerError), pong(Pong), command(AutomationCommand), unknown(String)
    private enum Keys: String, CodingKey { case type, room }
    public init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: Keys.self)
        let type = try box.decode(String.self, forKey: .type)
        switch type {
        case "welcome": self = try .welcome(Welcome(from: decoder))
        case "rooms": self = try .rooms(RoomList(from: decoder))
        case "room_state": self = try .room(box.decode(RoomSnapshot.self, forKey: .room))
        case "queued": self = try .queued(QueueState(from: decoder))
        case "left": self = .left
        case "error": self = try .error(ServerError(from: decoder))
        case "pong": self = try .pong(Pong(from: decoder))
        case "ui_command": self = try .command(AutomationCommand(from: decoder))
        default: self = .unknown(type)
        }
    }
}
