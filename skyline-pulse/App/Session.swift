import AVFoundation
import Foundation
import SwiftUI

@MainActor
final class Session: ObservableObject {
  @Published var state: RoomState?
  @Published var status = "OFFLINE"
  @Published var error = ""
  @Published var playerID = ""
  @Published var name = Launch.value("name") ?? "ARIA"
  @Published var address = Launch.value("server") ?? "ws://127.0.0.1:8769"
  @Published var roomCode = Launch.value("room") ?? ""
  @Published var selectedSong = "neon"
  @Published var rtt = 0.0
  @Published var clockReady = false
  @Published var guide = false
  @Published var timingOffset = UserDefaults.standard.double(forKey: "timingOffset")
  @Published var demo = Launch.has("autoplay")
  var scene: HighwayScene?
  var token: String?
  private var socket: URLSessionWebSocketTask?
  private var pingTask: Task<Void, Never>?
  private var receiveTask: Task<Void, Never>?
  private var reconnectTask: Task<Void, Never>?
  private var offset = 0.0
  private var bestRTT = Double.infinity
  private var seq = 0
  private var generation = 0
  private var shouldReconnect = false
  private var lastRound = 0
  private var music: AVAudioPlayer?
  private var musicScheduled = false
  private var autoReadyRound = -1
  private var pendingHostSong: String?
  private let epoch = Date().timeIntervalSince1970 * 1000
  private let uptime = ProcessInfo.processInfo.systemUptime * 1000
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  var localNow: Double { epoch + ProcessInfo.processInfo.systemUptime * 1000 - uptime }
  var serverNow: Double { localNow + offset }
  var songTime: Double { (serverNow - (state?.startAt ?? serverNow)) / 1000 }
  var chart: Chart? { Chart.all.first { $0.id == (state?.song ?? selectedSong) } }
  var me: Player? { state?.players.first { $0.id == playerID } }
  var opponent: Player? { state?.players.first { $0.id != playerID } }

  func connect(create: Bool, rejoin: Bool = false) {
    guard let url = URL(string: address), ["ws", "wss"].contains(url.scheme ?? ""),
      url.host != nil
    else {
      error = "Enter a WebSocket address, for example ws://192.168.1.10:8769"
      return
    }
    guard !name.trimmingCharacters(in: .whitespaces).isEmpty, name.count <= 20 else {
      error = "Choose a guest name with 1–20 characters."
      return
    }
    generation += 1
    let attempt = generation
    receiveTask?.cancel()
    pingTask?.cancel()
    socket?.cancel(with: .goingAway, reason: nil)
    if !rejoin {
      state = nil
      token = nil
      playerID = ""
      seq = 0
      lastRound = 0
      autoReadyRound = -1
      pendingHostSong = create ? selectedSong : nil
    }
    error = ""
    clockReady = false
    bestRTT = .infinity
    status = "CONNECTING"
    shouldReconnect = true
    let task = URLSession.shared.webSocketTask(with: url)
    socket = task
    task.resume()
    send(
      JoinMessage(
        name: name, create: create, room: roomCode.uppercased(), token: rejoin ? token : nil))
    receiveTask = Task { [weak self] in
      while !Task.isCancelled {
        do {
          let message = try await task.receive()
          guard let self, self.generation == attempt else { return }
          switch message {
          case .string(let text): self.receive(Data(text.utf8))
          case .data(let data): self.receive(data)
          @unknown default: break
          }
        } catch {
          guard let self, self.generation == attempt, !Task.isCancelled else { return }
          self.status = "RECONNECTING"
          self.music?.stop()
          self.musicScheduled = false
          if self.shouldReconnect && self.token != nil {
            self.reconnectTask = Task {
              try? await Task.sleep(for: .seconds(1))
              if !Task.isCancelled { self.connect(create: false, rejoin: true) }
            }
          } else {
            self.error = "Cannot connect. Start the server and check its address."
            self.status = "OFFLINE"
          }
          return
        }
      }
    }
    pingTask = Task {
      for _ in 0..<6 {
        if Task.isCancelled { return }
        send(ControlMessage(type: "ping", sent: localNow))
        try? await Task.sleep(for: .milliseconds(120))
      }
      while !Task.isCancelled {
        send(ControlMessage(type: "ping", sent: localNow))
        try? await Task.sleep(for: .seconds(2))
      }
    }
  }

  private func receive(_ data: Data) {
    guard let message = try? decoder.decode(ServerMessage.self, from: data) else { return }
    switch message.type {
    case "joined":
      playerID = message.id ?? ""
      token = message.token
      roomCode = message.room ?? roomCode
      status = "CONNECTED"
      if let song = pendingHostSong {
        send(ControlMessage(type: "song", song: song))
        pendingHostSong = nil
      }
      print("EVIDENCE joined id=\(playerID) room=\(roomCode)")
    case "error":
      error = message.message ?? "Connection error"
      if state == nil { status = "OFFLINE" }
    case "pong":
      if let sent = message.sent, let now = message.now {
        let elapsed = localNow - sent
        rtt = elapsed
        if elapsed < bestRTT {
          bestRTT = elapsed
          offset = now - (sent + localNow) / 2
        }
        clockReady = true
      }
    case "state":
      guard let incoming = try? decoder.decode(RoomState.self, from: data) else { return }
      state = incoming
      selectedSong = incoming.song
      if incoming.round != lastRound {
        lastRound = incoming.round
        seq = 0
        musicScheduled = false
        scene?.resetRound()
      }
      if incoming.phase == "playing" {
        scheduleMusic()
      } else {
        music?.stop()
        musicScheduled = false
      }
      if demo && incoming.phase == "lobby" && incoming.players.count == 2
        && autoReadyRound != incoming.round
      {
        autoReadyRound = incoming.round
        Task {
          try? await Task.sleep(for: .seconds(1))
          ready()
        }
      }
    default: break
    }
  }

  func send<T: Encodable>(_ message: T) {
    guard let data = try? encoder.encode(message), let text = String(data: data, encoding: .utf8)
    else { return }
    socket?.send(.string(text)) { _ in }
  }

  func ready() { send(ControlMessage(type: "ready", ready: !(me?.ready ?? false))) }
  func select(_ song: String) {
    selectedSong = song
    if state != nil { send(ControlMessage(type: "song", song: song)) }
  }

  func touch(pointer: String, action: String, x: Double, y: Double) {
    guard state?.phase == "playing", status == "CONNECTED" else { return }
    seq += 1
    send(
      TouchMessage(
        seq: seq, at: serverNow + timingOffset, pointer: pointer, action: action,
        x: min(16, max(0, x)), y: min(1, max(0, y))))
    if action == "down" { scene?.pulse(lane: x) }
  }

  func leave() {
    send(ControlMessage(type: "leave"))
    shouldReconnect = false
    reconnectTask?.cancel()
    pingTask?.cancel()
    receiveTask?.cancel()
    socket?.cancel(with: .normalClosure, reason: nil)
    generation += 1
    state = nil
    token = nil
    music?.stop()
    musicScheduled = false
    status = "OFFLINE"
  }

  func reconnect() { connect(create: false, rejoin: true) }

  func scheduleMusic() {
    guard !musicScheduled, clockReady, let chart,
      let url = Bundle.main.url(forResource: chart.id, withExtension: "m4a")
    else { return }
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback, mode: .default, options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)
      let player = try AVAudioPlayer(contentsOf: url)
      player.prepareToPlay()
      let remaining = -songTime
      if remaining > 0 {
        player.play(atTime: player.deviceCurrentTime + remaining)
      } else if songTime < chart.duration {
        player.currentTime = songTime
        player.play()
      }
      music = player
      musicScheduled = true
      print(
        "EVIDENCE audio scheduled room=\(roomCode) round=\(state?.round ?? 0) songTime=\(songTime) rtt=\(rtt)"
      )
    } catch { self.error = "Audio could not start: \(error.localizedDescription)" }
  }
}
