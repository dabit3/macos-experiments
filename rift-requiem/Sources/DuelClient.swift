import Foundation
import Combine

@MainActor
final class DuelClient: ObservableObject {
    @Published var state: MatchState?
    @Published var playerID = ""
    @Published var code = ""
    @Published var status = "LOCAL NETWORK / PROTOCOL 01"
    @Published var error = ""
    @Published var connected = false
    @Published var connecting = false
    @Published var retryAttempt = 0
    @Published var automated = Launch.automated
    @Published var driverStep = "WAITING FOR TWO DUELISTS"
    @Published var name = Launch.value("name") ?? "Guest"
    @Published var style = Launch.value("fighter") ?? "rook"
    @Published var address = Launch.value("server") ?? "ws://127.0.0.1:8787"
    @Published var roomCode = Launch.value("room") ?? ""
    private var socket: URLSessionWebSocketTask?
    private var token = ""
    private var sequence = 0
    private var generation = 0
    private var lastDriverTick = -1
    private var lastLogTick = -1
    private var lastRematch = -1
    private var automaticReady = false
    private var retryCount = 0
    private var sentMove = 0
    private var sentGuard = false
    private var outgoing: [ClientMessage] = []
    private var sending = false
    private var lastSnapshot = Date.distantPast

    var me: Duelist? { state?.players.first { $0.id == playerID } }

    func connect(rejoining: Bool = false) {
        guard let url = URL(string: address), ["ws", "wss"].contains(url.scheme ?? ""),
              url.host != nil else {
            error = "Enter a WebSocket address, such as ws://192.168.1.5:8787"
            return
        }
        if !rejoining {
            token = ""; state = nil; sequence = 0; automaticReady = false
            lastDriverTick = -1; lastLogTick = -1; lastRematch = -1
        }
        generation += 1
        let current = generation
        socket?.cancel(with: .goingAway, reason: nil)
        outgoing = []; sending = false
        error = ""
        connecting = true
        status = rejoining ? "RECONNECTING…" : "CONNECTING…"
        let task = URLSession.shared.webSocketTask(with: url)
        socket = task
        task.resume()
        send(ClientMessage(type: "join", name: name, style: style,
                           code: rejoining ? nil : roomCode, token: rejoining ? token : nil))
        Task {
            do {
                while current == generation {
                    let message = try await task.receive()
                    guard current == generation else { return }
                    let data: Data
                    switch message {
                    case .data(let bytes): data = bytes
                    case .string(let string): data = Data(string.utf8)
                    @unknown default: continue
                    }
                    receive(data)
                }
            } catch {
                guard current == generation else { return }
                connected = false
                connecting = false
                status = "CONNECTION LOST"
                if !token.isEmpty && retryCount < 8 {
                    retryCount += 1
                    retryAttempt = retryCount
                    try? await Task.sleep(for: .seconds(1))
                    guard current == generation else { return }
                    connect(rejoining: true)
                } else {
                    self.error = "Could not reach the duel server. Check its address and start the server."
                }
            }
        }
    }

    private func receive(_ data: Data) {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return }
        if envelope.type == "welcome" {
            playerID = envelope.id ?? ""
            token = envelope.token ?? ""
            code = envelope.code ?? ""
            sequence = max(sequence, (envelope.seq ?? -1) + 1)
            connected = true
            connecting = false
            retryCount = 0
            retryAttempt = 0
            status = "CONNECTED / \(String(playerID.prefix(8)))"
        } else if envelope.type == "error" {
            connecting = false
            error = envelope.message ?? "Protocol error"
        } else if envelope.type == "state",
                  let next = try? JSONDecoder().decode(MatchState.self, from: data) {
            state = next
            lastSnapshot = Date()
            if automated { drive(next) }
            if Launch.value("evidence") == "1", next.tick >= lastLogTick + 2 {
                lastLogTick = next.tick
                let documents = URL.documentsDirectory
                try? data.write(to: documents.appending(path: "state.json"), options: .atomic)
                let log = documents.appending(path: "network.jsonl")
                if !FileManager.default.fileExists(atPath: log.path) {
                    FileManager.default.createFile(atPath: log.path, contents: nil)
                }
                if let file = try? FileHandle(forWritingTo: log) {
                    defer { try? file.close() }
                    _ = try? file.seekToEnd()
                    try? file.write(contentsOf: data + Data([10]))
                }
            }
        }
    }

    private func send(_ message: ClientMessage) {
        outgoing.append(message)
        guard !sending else { return }
        sending = true
        let current = generation
        Task {
            while !outgoing.isEmpty && current == generation {
                let next = outgoing.removeFirst()
                guard let data = try? JSONEncoder().encode(next),
                      let text = String(data: data, encoding: .utf8) else { continue }
                do { try await socket?.send(.string(text)) } catch { break }
            }
            if current == generation { sending = false }
        }
    }

    func action(_ action: String, value: Int = 0) {
        sequence += 1
        send(ClientMessage(type: "input", seq: sequence, action: action, value: value))
    }

    func ready() { send(ClientMessage(type: "ready")) }
    func rematch() { send(ClientMessage(type: "rematch")) }

    func leave() {
        generation += 1
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil; state = nil; token = ""; connected = false; connecting = false
        outgoing = []; sending = false; retryCount = 0
    }

    func reconnect() { connect(rejoining: true) }

    func open(_ url: URL) {
        guard url.scheme == "riftrequiem", let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let values = Dictionary(parts.queryItems?.map { ($0.name, $0.value ?? "") } ?? [], uniquingKeysWith: { _, new in new })
        if url.host == "join" {
            if let server = values["server"] { address = server }
            if let room = values["room"] { roomCode = room }
            connect()
        } else if url.host == "auto" {
            automated = values["enabled"] == "1"
            if !automated { action("move"); action("guard"); sentMove = 0; sentGuard = false }
        }
    }

    private func drive(_ next: MatchState) {
        guard let own = next.players.first(where: { $0.id == playerID }) else { return }
        if next.phase == "lobby" && next.players.count == 2 && !automaticReady {
            automaticReady = true; ready()
        }
        if next.phase == "result" {
            driverStep = "MATCH RESULT RECEIVED • REMATCH IN 5s"
            if lastRematch != next.matches {
                lastRematch = next.matches
                Task {
                    try? await Task.sleep(for: .seconds(5))
                    if automated { rematch() }
                }
            }
            return
        }
        guard next.phase == "fight", !next.paused, next.tick >= lastDriverTick + 9,
              let other = next.players.first(where: { $0.id != playerID }) else { return }
        lastDriverTick = next.tick
        let elapsed = 60 - next.seconds
        let cycle = Int(elapsed * 6)
        let distance = abs(own.x - other.x)
        let direction = own.x < other.x ? 1 : -1
        let moving = distance > 125 ? direction : 0
        if moving != sentMove { action("move", value: moving); sentMove = moving }
        let guarding = elapsed < 12 && own.slot == 1 && cycle % 28 < 7
        if guarding != sentGuard { action("guard", value: guarding ? 1 : 0); sentGuard = guarding }
        if elapsed < 10 {
            driverStep = "AIR DASH / GUARD / PROJECTILES"
            if cycle % 30 == 4 { action("jump") }
            if cycle % 30 == 7 { action("dash") }
            if cycle % 12 == 0 { action("special") }
            if cycle % 18 == 10 { action("slash") }
        } else {
            driverStep = "WEAPON PRESSURE / REQUIEM CANCEL"
            if own.attack.isEmpty {
                if own.slot == 0 {
                    action(distance < 195 ? (cycle % 3 == 0 ? "heavy" : "slash") : "special")
                } else if cycle % 7 == 0 {
                    action(distance < 190 ? "heavy" : "special")
                }
            } else if own.meter >= 50 && own.frame > 18 && cycle % 5 == 0 {
                action("cancel")
            }
        }
    }
}
