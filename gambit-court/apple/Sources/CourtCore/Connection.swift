import Combine
import Foundation

public enum ConnectionPhase: String, Sendable { case connecting, online, reconnecting, offline }

@MainActor
public final class CourtConnection: ObservableObject {
    @Published public private(set) var phase = ConnectionPhase.offline
    @Published public private(set) var error: String?
    @Published public private(set) var rttMs = 0
    public private(set) var serverOffsetMs = 0
    public var onMessage: ((ServerMessage) -> Void)?
    public var onPhase: ((ConnectionPhase) -> Void)?
    private var socket: URLSessionWebSocketTask?
    private var receiver: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var retry: Task<Void, Never>?
    private var generation = 0
    private var failures = 0
    private var stopped = true
    private var lastPongMs = 0
    private var url: URL?
    private var hello = ClientMessage(.hello)
    private let session: URLSession
    public static var nowMs: Int {
        Int(Date().timeIntervalSince1970 * 1000)
    }

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 86400
        session = URLSession(configuration: config)
    }

    public static func endpoint(_ text: String) -> URL? {
        guard let components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["ws", "wss"].contains(components.scheme?.lowercased() ?? ""), let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil, components.fragment == nil else { return nil }
        return components.url
    }

    public func connect(endpoint: String, clientId: String, name: String, platform: String) {
        stop()
        guard let valid = Self.endpoint(endpoint), !clientId.isEmpty, clientId.count <= 64 else {
            error = "Enter a ws:// or wss:// server URL and a valid client identity."
            return
        }
        url = valid; failures = 0; stopped = false; error = nil
        hello = ClientMessage(.hello)
        hello.clientId = clientId; hello.name = name; hello.platform = platform; hello.protocol = 1
        open()
    }

    public func updateName(_ name: String) {
        hello.name = name
    }

    private func setPhase(_ phase: ConnectionPhase) {
        self.phase = phase; onPhase?(phase)
    }

    private func open() {
        guard !stopped, let url else { return }
        generation += 1
        let current = generation
        let task = session.webSocketTask(with: url)
        task.maximumMessageSize = 4_000_000
        socket = task
        setPhase(failures == 0 ? .connecting : .reconnecting)
        task.resume()
        receiver = Task { [weak self] in
            guard let self else { return }
            do {
                try await task.send(.string(String(decoding: JSONEncoder().encode(hello), as: UTF8.self)))
                while !Task.isCancelled, current == generation {
                    let frame = try await task.receive()
                    let data: Data
                    switch frame {
                    case let .string(text): data = Data(text.utf8)
                    case let .data(bytes): data = bytes
                    @unknown default: continue
                    }
                    guard data.count <= 4_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
                    let message = try JSONDecoder().decode(ServerMessage.self, from: data)
                    guard current == generation else { return }
                    switch message {
                    case let .welcome(welcome):
                        guard welcome.protocol == 1 else {
                            error = "Server protocol \(welcome.protocol) is unsupported."; stop(); return
                        }
                        serverOffsetMs = welcome.serverTimeMs - Self.nowMs
                        lastPongMs = Self.nowMs
                        failures = 0; error = nil; setPhase(.online)
                    case let .pong(pong):
                        lastPongMs = Self.nowMs
                        if let nonce = pong.nonce.flatMap(Int.init) {
                            rttMs = max(0, Self.nowMs - nonce)
                            serverOffsetMs = pong.serverTimeMs - (nonce + rttMs / 2)
                        }
                    case let .error(serverError):
                        error = serverError.message
                        if serverError.fatal == true {
                            stop()
                        }
                    default: break
                    }
                    onMessage?(message)
                }
            } catch {
                failed(error, generation: current)
            }
        }
        heartbeat = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(15))
                guard let self, current == generation else { return }
                if phase != .online {
                    failed(URLError(.timedOut), generation: current); return
                }
                while !Task.isCancelled, current == generation {
                    if Self.nowMs - lastPongMs > 30000 {
                        failed(URLError(.timedOut), generation: current); return
                    }
                    var ping = ClientMessage(.ping); ping.nonce = String(Self.nowMs)
                    await send(ping)
                    try await Task.sleep(for: .seconds(10))
                }
            } catch {
                self?.failed(error, generation: current)
            }
        }
    }

    private func cancelTransport() {
        generation += 1
        receiver?.cancel(); receiver = nil
        heartbeat?.cancel(); heartbeat = nil
        socket?.cancel(with: .goingAway, reason: nil); socket = nil
    }

    private func failed(_ failure: Error, generation current: Int) {
        guard current == generation, !stopped else { return }
        cancelTransport()
        error = "Connection interrupted: \(failure.localizedDescription)"
        failures += 1
        guard failures <= 6 else {
            stopped = true; setPhase(.offline)
            error = "Cannot reach the server. Check its address, then reconnect."
            return
        }
        setPhase(.reconnecting)
        retry?.cancel()
        let delay = min(16, 1 << (failures - 1))
        retry = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self, !stopped else { return }
            retry = nil; open()
        }
    }

    public func stop() {
        stopped = true
        retry?.cancel(); retry = nil
        cancelTransport(); setPhase(.offline)
    }

    @discardableResult
    public func send(_ message: some Encodable) async -> Bool {
        guard phase == .online, let socket else { error = "You are offline. Reconnect before playing."; return false }
        let current = generation
        do {
            try await socket.send(.string(String(decoding: JSONEncoder().encode(message), as: UTF8.self)))
            return true
        } catch { failed(error, generation: current); return false }
    }
}
