import Combine
import Foundation

@MainActor
public final class CourtStore: ObservableObject {
    public let connection: CourtConnection
    public let clientId: String
    public let platform: String
    public let automation: Bool
    public var feedback: ((String) -> Void)?
    @Published public var name: String
    @Published public var endpoint: String
    @Published public var theme: String {
        didSet { defaults.set(theme, forKey: "theme") }
    }

    @Published public var sound: Bool {
        didSet { defaults.set(sound, forKey: "sound") }
    }

    @Published public var haptics: Bool {
        didSet { defaults.set(haptics, forKey: "haptics") }
    }

    @Published public var timeControl: TimeControl {
        didSet { defaults.set(try? JSONEncoder().encode(timeControl), forKey: "timeControl") }
    }

    @Published public var sidePreference: SidePreference {
        didSet { defaults.set(sidePreference.rawValue, forKey: "side") }
    }

    @Published public var botLevel: Int {
        didSet { defaults.set(botLevel, forKey: "botLevel") }
    }

    @Published public private(set) var rooms: [RoomListing] = []
    @Published public private(set) var online = 0
    @Published public private(set) var room: RoomSnapshot?
    @Published public private(set) var position = Position.initial
    @Published public private(set) var queue: QueueState?
    @Published public private(set) var selected: Int?
    @Published public private(set) var premove: Move?
    @Published public var promotion: Move?
    @Published public private(set) var viewPly: Int?
    @Published public private(set) var review: PGN?
    @Published public var flipped = false
    @Published public var resultsDismissed = false
    @Published public var notice: String?
    @Published public private(set) var pending: Intent?
    @Published public private(set) var revision = 0
    private var pendingTimeout: Task<Void, Never>?
    private var connectionChanges: AnyCancellable?
    private let defaults: UserDefaults
    private var followingRematch: String?
    private var roomReceivedMs = 0
    private var lowTimePlayed = false

    public init(clientId: String, endpoint: String, name: String? = nil, platform: String,
                automation: Bool = false, defaults: UserDefaults = .standard)
    {
        self.clientId = clientId; self.endpoint = endpoint; self.platform = platform
        self.automation = automation; self.defaults = defaults
        sidePreference = SidePreference(rawValue: defaults.string(forKey: "side") ?? "") ?? .random
        botLevel = (defaults.object(forKey: "botLevel") as? Int).flatMap { (1 ... 4).contains($0) ? $0 : nil } ?? 2
        self.name = name ?? defaults.string(forKey: "name") ?? "Guest \(Int.random(in: 10 ... 99))"
        theme = defaults.string(forKey: "theme") ?? "dark"
        sound = defaults.object(forKey: "sound") as? Bool ?? true
        haptics = defaults.object(forKey: "haptics") as? Bool ?? true
        timeControl = defaults.data(forKey: "timeControl").flatMap { try? JSONDecoder().decode(TimeControl.self, from: $0) } ?? .standard
        connection = CourtConnection()
        connection.onMessage = { [weak self] in self?.receive($0) }
        connection.onPhase = { [weak self] phase in
            if phase != .online {
                self?.cancelInput()
            }
        }
        connectionChanges = connection.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    public var ready: Bool {
        connection.phase == .online
    }

    public var busy: Bool {
        pending != nil
    }

    public var mySide: Side? {
        room?.side(of: clientId)
    }

    public var orientation: Side {
        flipped ? (mySide ?? .white).opposite : mySide ?? .white
    }

    public var moves: [PlayedMove] {
        review?.moves ?? room?.moves ?? []
    }

    public var startFen: String {
        review?.start.fen ?? room?.startFen ?? Position.startFen
    }

    public var displayedPly: Int {
        min(viewPly ?? moves.count, moves.count)
    }

    public var displayedPosition: Position {
        if viewPly == nil && review == nil {
            return position
        }
        let fen = displayedPly == 0 ? startFen : moves[displayedPly - 1].fen
        return (try? Position(fen: fen)) ?? position
    }

    public var lastMove: Move? {
        displayedPly > 0 ? Move(uci: moves[displayedPly - 1].uci) : nil
    }

    public var canInteract: Bool {
        ready && !busy && room?.status == .playing && mySide != nil && review == nil && viewPly == nil
    }

    public var myTurn: Bool {
        canInteract && room?.turn == mySide
    }

    public var showResults: Bool {
        room?.result != nil && !resultsDismissed && review == nil
    }

    public var legalTargets: Set<Int> {
        guard let selected, myTurn else { return [] }
        return Set(position.legalMoves(from: selected).map(\.to))
    }

    public var pgn: String {
        if let review {
            return review.text
        }
        let tc = room?.timeControl ?? timeControl
        let tags = ["White": room?.white?.name ?? "White", "Black": room?.black?.name ?? "Black",
                    "Result": room?.result?.score ?? "*", "TimeControl": "\(tc.initialMs / 1000)+\(tc.incrementMs / 1000)"]
        return PGN(start: (try? Position(fen: startFen)) ?? .initial, moves: moves, tags: tags).text
    }

    public func connect() {
        defaults.set(endpoint, forKey: "endpoint")
        connection.connect(endpoint: endpoint, clientId: clientId, name: name, platform: platform)
    }

    public func setName(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 24 else { notice = "Name must be 1–24 characters."; return }
        name = trimmed; defaults.set(name, forKey: "name"); connection.updateName(name)
        var message = ClientMessage(.setName); message.name = name
        send(message, waits: false)
    }

    public func create(bot: Bool = false, isPublic: Bool = true) {
        var message = ClientMessage(.createRoom)
        message.timeControl = timeControl; message.side = sidePreference
        message.isPublic = isPublic; message.botLevel = bot ? botLevel : nil
        send(message)
    }

    public func join(_ code: String, spectate: Bool = false) {
        let value = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard value.count == 6, value.allSatisfy(\.isLetterOrNumber) else { notice = "Enter a six-character table code."; return }
        var message = ClientMessage(.joinRoom); message.code = value; message.asSpectator = spectate
        send(message)
    }

    public func quickPair(bot: Bool = true) {
        var message = ClientMessage(.quickPair); message.timeControl = timeControl
        message.botLevel = bot ? botLevel : nil
        message.botAfterMs = 10000
        send(message)
    }

    public func action(_ intent: Intent) {
        var message = ClientMessage(intent)
        if intent == .addBot {
            message.botLevel = botLevel
        }
        send(message, waits: ![.listRooms, .setName].contains(intent))
    }

    private func finishPending() {
        pending = nil; pendingTimeout?.cancel(); pendingTimeout = nil
    }

    private func send(_ message: ClientMessage, waits: Bool = true) {
        guard ready else { notice = "You are offline. Reconnect before playing."; return }
        guard !waits || pending == nil else { return }
        if waits {
            pending = message.type
            pendingTimeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(12)) } catch { return }
                self?.notice = "No confirmation from the server. Reconnect to refresh the table."
                self?.finishPending()
            }
        }
        Task { [weak self] in
            guard let self else { return }
            if await !(connection.send(message)) {
                finishPending()
            }
        }
    }

    public func receive(_ message: ServerMessage) {
        revision += 1
        switch message {
        case let .welcome(welcome):
            name = welcome.name
            finishPending()
            if let room = welcome.room {
                apply(room)
            } else if room != nil {
                clearRoom(); notice = "Your seat expired while you were offline."
            }
            queue = nil
        case let .rooms(listing):
            rooms = listing.rooms; online = listing.online
            if pending == .listRooms {
                finishPending()
            }
        case let .room(snapshot): apply(snapshot)
        case let .queued(state): queue = state; finishPending()
        case .left: clearRoom(); queue = nil; finishPending()
        case let .error(error): notice = error.message; finishPending()
        case let .command(command):
            guard automation else { return }
            Task { await run(command) }
        case .pong, .unknown: break
        }
    }

    private func apply(_ next: RoomSnapshot) {
        guard room?.code != next.code || next.seq >= (room?.seq ?? -1) else { return }
        guard let nextPosition = try? Position(fen: next.fen) else {
            notice = "The server sent an invalid board position."; return
        }
        let previous = room
        if previous?.code != next.code {
            cancelInput(); flipped = false; viewPly = nil; resultsDismissed = false
            review = nil; followingRematch = nil; lowTimePlayed = false
        }
        if let old = previous, old.code == next.code {
            if old.result != nil, next.result == nil {
                viewPly = nil; flipped = false; resultsDismissed = false; lowTimePlayed = false
            }
            if next.result != nil, old.result == nil {
                feedback?("end"); resultsDismissed = false
            } else if next.moves.count > old.moves.count, let move = next.moves.last.flatMap({ Move(uci: $0.uci) }) {
                feedback?(nextPosition.inCheck ? "check" : position.isCapture(move) ? "capture" : "move")
            } else if next.moves.count < old.moves.count {
                feedback?("notify"); cancelInput()
            }
            if next.offers != old.offers {
                feedback?("notify")
            }
        } else {
            feedback?("notify")
        }
        room = next; position = nextPosition; queue = nil; roomReceivedMs = CourtConnection.nowMs
        finishPending()
        if let ply = viewPly {
            viewPly = min(ply, next.moves.count)
        }
        if next.status != .playing {
            cancelInput()
        } else if let premove, next.turn == mySide {
            self.premove = nil
            if nextPosition.legalMoves(from: premove.from).contains(premove) {
                submit(premove)
            } else {
                notice = "Premove cancelled: that move is no longer legal."
            }
        } else if let selected, nextPosition.board[selected]?.side != mySide {
            self.selected = nil
        }
        if let code = next.rematchRoom, code != followingRematch {
            followingRematch = code; join(code, spectate: mySide == nil)
        }
    }

    private func clearRoom() {
        room = nil; position = .initial; cancelInput(); viewPly = nil; resultsDismissed = false
    }

    public func cancelInput() {
        selected = nil; premove = nil; promotion = nil
    }

    public func tap(_ square: Int) {
        guard canInteract else { return }
        if let selected {
            if selected == square {
                self.selected = nil; return
            }
            if position.board[square]?.side != mySide {
                request(from: selected, to: square); return
            }
        }
        selected = position.board[square]?.side == mySide ? square : nil
    }

    public func request(from: Int, to: Int, promotion kind: PieceKind? = nil) {
        guard canInteract, from != to, position.board[from]?.side == mySide, position.board[to]?.side != mySide else { return }
        if position.requiresPromotion(from, to), kind == nil {
            promotion = Move(from, to); return
        }
        let move = Move(from, to, promotion: kind)
        if myTurn {
            guard position.legalMoves(from: from).contains(move) else { notice = "That move is not legal."; return }
            submit(move)
        } else {
            premove = move; selected = nil; feedback?("notify")
        }
    }

    private func submit(_ move: Move) {
        selected = nil; promotion = nil
        var message = ClientMessage(.move); message.uci = move.uci
        send(message)
    }

    public func view(_ ply: Int?) {
        viewPly = ply.map { max(0, min(moves.count, $0)) }
        cancelInput()
    }

    public func step(_ delta: Int) {
        let next = max(0, min(moves.count, displayedPly + delta))
        view(next == moves.count && review == nil ? nil : next)
    }

    public func importPGN(_ text: String) {
        guard room == nil, queue == nil else { notice = "Leave your table or queue before opening a review."; return }
        do {
            review = try PGN(text: text); viewPly = review?.moves.count
            notice = review?.warning; cancelInput()
        } catch { notice = error.localizedDescription }
    }

    public func closeReview() {
        review = nil; viewPly = nil; cancelInput()
    }

    public func clock(_ side: Side, at date: Date) -> Int {
        guard let room else { return timeControl.initialMs }
        let localMs = Int(date.timeIntervalSince1970 * 1000)
        let snapshotNow = room.clocks.asOfServerMs + max(0, localMs - roomReceivedMs)
        return room.clocks.remaining(side, serverNowMs: snapshotNow)
    }

    public func checkLowTime() {
        guard let side = mySide, room?.status == .playing, room?.turn == side,
              room?.timeControl.initialMs != 0, clock(side, at: Date()) < 20000, !lowTimePlayed else { return }
        lowTimePlayed = true; feedback?("lowtime")
    }
}

private extension Character {
    var isLetterOrNumber: Bool {
        isASCII && (isLetter || isNumber)
    }
}

public struct ClientReport: Encodable {
    public var type = "ui_report"
    public let id: String
    public var ok = true
    public var error: String?
    public var clientId: String
    public var platform: String
    public var name: String
    public var connection: String
    public var screen: String
    public var theme: String
    public var roomCode: String?
    public var status: String?
    public var seq: Int?
    public var fen: String
    public var liveFen: String?
    public var moves: [String]
    public var moveCount: Int
    public var turn: Side
    public var mySide: Side?
    public var isSpectator: Bool
    public var orientation: Side
    public var result: GameResult?
    public var score: String?
    public var clocks: ClockState?
    public var white: String?
    public var black: String?
    public var spectators: [String]?
    public var offers: Offers?
    public var premove: String?
    public var queued: Bool
    public var roomsListed: Int
    public var pgn: String?
}

extension CourtStore {
    public func report(id: String) -> ClientReport {
        ClientReport(id: id, clientId: clientId, platform: platform, name: name, connection: connection.phase.rawValue,
                     screen: showResults ? "results" : review != nil ? "review" : room != nil ? "game" : "lobby",
                     theme: theme, roomCode: room?.code, status: room?.status.rawValue, seq: room?.seq,
                     fen: displayedPosition.fen, liveFen: room?.fen, moves: moves.map(\.san), moveCount: moves.count,
                     turn: displayedPosition.turn, mySide: mySide, isSpectator: room != nil && mySide == nil,
                     orientation: orientation, result: room?.result, score: room?.result?.score, clocks: room?.clocks,
                     white: room?.white?.name, black: room?.black?.name, spectators: room?.spectators.map(\.name),
                     offers: room?.offers, premove: premove?.uci, queued: queue != nil, roomsListed: rooms.count)
    }

    private func run(_ command: AutomationCommand) async {
        let before = revision
        var localError: String?
        switch command.action {
        case "state", "settle": break
        case "set_name": setName(command.name ?? "")
        case "set_theme": theme = command.theme == "light" ? "light" : "dark"
        case "create_room":
            if let tc = command.timeControl {
                timeControl = tc
            }
            sidePreference = command.side ?? .white
            if let level = command.botLevel {
                botLevel = level
            }
            create(bot: command.botLevel != nil, isPublic: command.isPublic ?? true)
        case "join_room": join(command.code ?? "", spectate: command.asSpectator ?? false)
        case "quick_pair": quickPair(bot: command.bot ?? false)
        case "move", "premove":
            if let move = Move(uci: command.uci ?? "") {
                if command.action == "move" {
                    let deadline = Date().addingTimeInterval(6)
                    while !myTurn, Date() < deadline {
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                }
                if canInteract {
                    request(from: move.from, to: move.to, promotion: move.promotion)
                } else {
                    localError = "Cannot move in the current state."
                }
            } else {
                localError = "Invalid UCI move."
            }
        case "flip": flipped.toggle()
        case "view_ply": view(command.ply)
        case "dismiss_results": resultsDismissed = true
        case "export_pgn": break
        case "import_pgn": importPGN(command.pgn ?? "")
        case "close_review": closeReview()
        case "drop_connection": break
        default:
            if let intent = Intent(rawValue: command.action), intent != .hello {
                action(intent)
            } else {
                localError = "Unknown action: \(command.action)"
            }
        }
        let deadline = Date().addingTimeInterval(10)
        while pending != nil, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(30))
        }
        var report = report(id: command.id)
        if command.action == "export_pgn" {
            report.pgn = pgn
        }
        if let error = localError ?? (revision > before ? notice : nil) {
            report.ok = false; report.error = error
        }
        await connection.send(report)
        if command.action == "drop_connection" {
            connect()
        }
    }
}
