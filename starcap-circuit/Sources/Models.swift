import Foundation
import SwiftUI

struct Racer: Identifiable {
  let id: Int
  let name: String
  let subtitle: String
  let kart: String
  let color: Color
  let speed: Double
  let accel: Double
  let handling: Double
  static let all = [
    Racer(
      id: 0, name: "PIP", subtitle: "Cosmic squirrel", kart: "All-rounder",
      color: Color(red: 1, green: 0.29, blue: 0.38), speed: 4, accel: 4, handling: 4),
    Racer(
      id: 1, name: "MOCHI", subtitle: "Moonbeam bunny", kart: "Quick & nimble",
      color: Color(red: 0.25, green: 0.91, blue: 0.77), speed: 3, accel: 6, handling: 5),
    Racer(
      id: 2, name: "VOLT", subtitle: "Pocket robot", kart: "Top-speed brawler",
      color: Color(red: 1, green: 0.76, blue: 0.19), speed: 6, accel: 3, handling: 3),
  ]
}

enum Item {
  static let order = ["zap", "comet", "gum", "bubble"]
  static let names = ["zap": "ZAP BOLT", "comet": "COMET", "gum": "GUM DROP", "bubble": "BUBBLE"]
  static let symbols = [
    "zap": "bolt.fill", "comet": "flame.fill", "gum": "drop.fill", "bubble": "shield.fill",
  ]
  static let colors: [String: Color] = [
    "zap": Color(red: 1, green: 0.87, blue: 0.2), "comet": .orange,
    "gum": Color(red: 1, green: 0.4, blue: 0.75), "bubble": .cyan,
  ]
}

enum Turbo {
  static let thresholds = [0.65, 1.3, 2.0]
  static let names = ["SPARK", "BLAZE", "STARBURST"]
  static let colors: [Color] = [
    Color(red: 0.25, green: 0.7, blue: 1), .orange, Color(red: 1, green: 0.35, blue: 0.85),
  ]
  static func tier(_ charge: Double) -> Int {
    thresholds.lastIndex { charge >= $0 }.map { $0 + 1 } ?? 0
  }
}

struct KartState: Decodable, Identifiable {
  var id: String
  var name: String
  var racer: Int
  var connected: Bool
  var ready: Bool
  var x: Double
  var z: Double
  var heading: Double
  var speed: Double
  var index: Int
  var progress: Double
  var gate: Int
  var lap: Int
  var finish: Double
  var rank: Int
  var item: String
  var roulette: Double
  var boost: Double
  var stun: Double
  var shield: Double
  var charge: Double
  var drifting: Bool
  var seq: Int
  var pickups: Int
  var shots: Int
  var hits: Int
  var drifts: Int
  var distance: Double
}

struct RaceEvent: Decodable {
  var id: Int
  var kind: String
  var player: String
  var target: String?
  var item: String?
  var tier: Int?
}

struct Hazard: Decodable {
  var x: Double
  var z: Double
  var owner: String
  var ttl: Double
}

struct RaceState: Decodable {
  var code: String
  var phase: String
  var track: Int
  var race: Int
  var now: Double
  var startAt: Double
  var laps: Int
  var events: [RaceEvent]
  var hazards: [Hazard]
  var players: [KartState]
}

struct Envelope: Decodable {
  let type: String
  var id: String?
  var token: String?
  var message: String?
}

struct WireMessage: Encodable {
  var type: String
  var code: String?
  var name: String?
  var racer: Int?
  var track: Int?
  var token: String?
  var seq: Int?
  var steer: Double?
  var throttle: Double?
  var brake: Bool?
  var drift: Bool?
  var use: Bool?
}

enum Course {
  static let names = ["SUNPETAL SPEEDWAY", "NEON BONBON"]
  static let descriptions = [
    "Island breezes. Big smiles. Full throttle.",
    "Sugar-lit streets. Tight turns. Electric nights.",
  ]
  static let moods = ["SUNNY COAST • FLOWING BENDS", "NIGHT CITY • TIGHT HAIRPINS"]
  static let difficulty = [2, 3]
  static func point(_ track: Int, _ index: Double) -> (x: Double, z: Double) {
    let t = index / 240 * .pi * 2
    let r = track == 1 ? 61 + 12 * sin(3 * t) : 68 + 8 * sin(3 * t)
    return (sin(t) * r * 1.14, cos(t) * r)
  }
  static func heading(_ track: Int, _ index: Double) -> Double {
    let a = point(track, index)
    let b = point(track, index + 0.2)
    return atan2(b.x - a.x, b.z - a.z)
  }
}

func wrappedAngle(_ value: Double) -> Double { atan2(sin(value), cos(value)) }

@MainActor
final class RaceClient: ObservableObject {
  @Published var state: RaceState?
  @Published var status = "Choose your racer. Invite a friend."
  @Published var connected = false
  @Published var playerID = ""
  @Published var address = "ws://127.0.0.1:8791"
  @Published var name = "Guest"
  @Published var code = "STAR"
  @Published var racer = 0
  @Published var track = 0
  @Published var autoDrive = false
  @Published var steer = 0.0
  @Published var throttle = false
  @Published var brake = false
  @Published var drift = false
  @Published var muted = false
  @Published var toast = ""
  @Published var toastTint = Color.orange
  @Published var clock = Date.timeIntervalSinceReferenceDate
  let world = RaceWorld()
  let audio = RaceAudio()
  private var socket: URLSessionWebSocketTask?
  private var timer: Timer?
  private var token = ""
  private var tokenRoom = ""
  private var sequence = 0
  private var generation = 0
  private var eventID = 0
  private var nextUse = 0.0
  private var lastPhase = ""
  private var stateAt = Date.timeIntervalSinceReferenceDate
  private var toastUntil = 0.0
  private let autoReady: Bool
  var me: KartState? { state?.players.first { $0.id == playerID } }
  var racing: Bool { state?.phase == "racing" || state?.phase == "countdown" }
  var serverNow: Double {
    (state?.now ?? 0) + (Date.timeIntervalSinceReferenceDate - stateAt) * 1000
  }
  var countdown: Int { max(0, Int(ceil(((state?.startAt ?? 0) - serverNow) / 1000))) }

  init() {
    let args = ProcessInfo.processInfo.arguments
    func value(_ flag: String) -> String? {
      guard let i = args.firstIndex(of: flag), args.indices.contains(i + 1) else { return nil }
      return args[i + 1]
    }
    autoReady = args.contains("-autoready")
    autoDrive = args.contains("-autodrive")
    name = value("-name") ?? "Guest"
    code = value("-room") ?? "STAR"
    address = value("-server") ?? "ws://127.0.0.1:8791"
    racer = min(2, max(0, Int(value("-racer") ?? "0") ?? 0))
    track = min(1, max(0, Int(value("-track") ?? "0") ?? 0))
    world.build(track: track)
    timer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.frame() }
    }
    if args.contains("-autojoin") {
      Task {
        try? await Task.sleep(for: .milliseconds(700))
        join()
      }
    }
  }

  func join() {
    guard let url = URL(string: address), ["ws", "wss"].contains(url.scheme?.lowercased() ?? ""),
      url.host != nil
    else {
      status = "Enter a ws:// or wss:// server address."
      return
    }
    let room = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard room.range(of: "^[A-Z0-9]{4,8}$", options: .regularExpression) != nil else {
      status = "Room code needs 4–8 letters or numbers."
      return
    }
    code = room
    if tokenRoom != code {
      token = ""
      playerID = ""
      tokenRoom = code
    }
    generation += 1
    let current = generation
    socket?.cancel(with: .goingAway, reason: nil)
    connected = false
    status = "Connecting to the starting grid…"
    let task = URLSession.shared.webSocketTask(with: url)
    socket = task
    task.resume()
    send(
      WireMessage(type: "join", code: code, name: name, racer: racer, track: track, token: token))
    Task {
      do {
        while current == generation {
          let message = try await task.receive()
          let data: Data
          switch message {
          case .data(let bytes): data = bytes
          case .string(let text): data = Data(text.utf8)
          @unknown default: continue
          }
          guard current == generation else { return }
          receive(data)
        }
      } catch {
        if current == generation {
          connected = false
          status = "Connection lost. Check the server, then reconnect."
        }
      }
    }
  }

  func leave() {
    generation += 1
    socket?.cancel(with: .normalClosure, reason: nil)
    socket = nil
    connected = false
    state = nil
    token = ""
    playerID = ""
    throttle = false
    steer = 0
    brake = false
    drift = false
    status = "Choose your racer. Invite a friend."
  }

  func ready() {
    send(WireMessage(type: "ready"))
    audio.effect("ready")
  }
  func rematch() { send(WireMessage(type: "rematch")) }
  func item() { transmit(use: true) }
  func setTrack(_ selection: Int) {
    track = selection
    world.build(track: selection)
  }
  func toggleMute() {
    muted.toggle()
    audio.setMuted(muted)
  }

  private func send(_ value: WireMessage) {
    guard let data = try? JSONEncoder().encode(value),
      let text = String(data: data, encoding: .utf8)
    else { return }
    socket?.send(.string(text)) { _ in }
  }

  private func receive(_ data: Data) {
    guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return }
    if envelope.type == "welcome", let id = envelope.id, let newToken = envelope.token {
      playerID = id
      token = newToken
      connected = true
      status = "Connected • room \(code)"
      audio.start()
    }
    if envelope.type == "error" {
      status = envelope.message ?? "Server error"
      connected = false
    }
    guard envelope.type == "state", let next = try? JSONDecoder().decode(RaceState.self, from: data)
    else { return }
    state = next
    stateAt = Date.timeIntervalSinceReferenceDate
    if world.track != next.track { world.build(track: next.track) }
    if let mine = me { sequence = max(sequence, mine.seq + 1) }
    if next.phase != lastPhase {
      lastPhase = next.phase
      if next.phase == "countdown" { audio.effect("ready") }
      if next.phase == "racing" {
        audio.effect("boost")
        audio.effect("go")
      }
      if next.phase == "results" { audio.effect("win") }
    }
    for event in next.events where event.id > eventID {
      eventID = event.id
      if event.player == playerID || event.target == playerID {
        switch event.kind {
        case "pickup":
          audio.effect("pickup")
          showToast("ITEM GET!", tint: .purple)
        case "zap":
          audio.effect("zap")
          world.flash(target: event.target ?? "")
          showToast(
            event.player == playerID ? "DIRECT HIT!" : "ZAPPED!",
            tint: event.player == playerID ? .orange : .red)
        case "drift":
          audio.effect("boost")
          let tier = max(1, min(3, event.tier ?? 1))
          showToast("\(Turbo.names[tier - 1]) TURBO!", tint: Turbo.colors[tier - 1])
        case "rocket":
          audio.effect("boost")
          showToast("ROCKET START!", tint: .orange)
        case "stall":
          audio.effect("zap")
          showToast("ENGINE STALL!", tint: .gray)
        case "dash":
          audio.effect("dash")
        case "gumHit":
          audio.effect("zap")
          showToast("STUCK IN GUM!", tint: .pink)
        case "finish":
          audio.effect("win")
          showToast("FINISH!")
        default: break
        }
      }
    }
    if autoReady && next.phase == "lobby", let mine = me, !mine.ready { ready() }
  }

  private func showToast(_ text: String, tint: Color = .orange) {
    toast = text
    toastTint = tint
    toastUntil = Date.timeIntervalSinceReferenceDate + 1.8
  }

  private func frame() {
    clock = Date.timeIntervalSinceReferenceDate
    if clock > toastUntil { toast = "" }
    world.update(state: state, playerID: playerID, time: clock)
    if connected && racing {
      var use = false
      if autoDrive, let p = me, let state {
        let target = Course.point(state.track, Double(p.index) + 9)
        let error = wrappedAngle(atan2(target.x - p.x, target.z - p.z) - p.heading)
        steer = max(-1, min(1, error * 2.7))
        throttle = true
        brake = false
        drift = abs(error) > 0.12 && Int(serverNow / 1400) % 3 != 0
        if !p.item.isEmpty && p.roulette <= 0 && clock > nextUse {
          use = true
          nextUse = clock + 1.4
        }
      }
      transmit(use: use)
    }
  }

  private func transmit(use: Bool) {
    sequence += 1
    send(
      WireMessage(
        type: "input", seq: sequence, steer: steer, throttle: throttle ? 1 : 0, brake: brake,
        drift: drift, use: use))
  }
}
