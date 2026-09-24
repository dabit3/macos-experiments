import Combine
import Foundation
import UIKit

@MainActor
final class GameClient: ObservableObject {
  @Published var state: Snapshot?
  @Published var name = Launch.value("name") ?? "Aster"
  @Published var address = Launch.value("server") ?? "ws://127.0.0.1:8791"
  @Published var room = Launch.value("room") ?? ""
  @Published var identity = ""
  @Published var status = "LOCAL CO-OP • 2 HEROES"
  @Published var error = ""
  @Published var automation = Launch.has("automation")
  @Published var driverStep = "Awaiting expedition"
  @Published var connected = false
  @Published var gearOpen = false
  @Published var menuOpen = false
  @Published var notice: Notice?
  @Published var damagePulse = 0
  let world = DungeonScene()
  let sound = Soundscape()
  private var socket: URLSessionWebSocketTask?
  private var token = ""
  private var generation = 0
  private var sequence = 0
  private var move = (0.0, 0.0)
  private var held = Set<String>()
  private var ticker: Timer?
  private var frame = 0
  private var autoReadySent = false
  private var resultFrames = 0
  private var lastEvent = 0
  private var logHandle: FileHandle?

  var me: Hero? { state?.players.first { $0.id == identity } }
  var partner: Hero? { state?.players.first { $0.id != identity } }
  var nearChest: Loot? {
    guard let me, let state else { return nil }
    return state.loot.first {
      $0.kind == "chest" && hypot($0.x - me.x, $0.z - me.z) < 3
        && !($0.claimed ?? []).contains(identity)
    }
  }

  init() {
    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let url = directory.appendingPathComponent("vanguard-evidence.jsonl")
    FileManager.default.createFile(atPath: url.path, contents: nil)
    logHandle = try? FileHandle(forWritingTo: url)
    ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.pulse() }
    }
    if Launch.has("host") || Launch.has("join") {
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        connect(create: Launch.has("host"))
      }
    }
  }

  func connect(create: Bool, resuming: Bool = false) {
    guard let url = URL(string: address), ["ws", "wss"].contains(url.scheme), url.host != nil else {
      error = "Enter a WebSocket address, such as ws://192.168.1.20:8791"
      return
    }
    sound.start()
    generation += 1
    let current = generation
    socket?.cancel(with: .normalClosure, reason: nil)
    connected = false
    error = ""
    status = resuming ? "RECONNECTING…" : "CONNECTING…"
    let task = URLSession.shared.webSocketTask(with: url)
    socket = task
    task.resume()
    send(
      Command(
        type: "hello", name: name, code: room.uppercased(), create: create,
        resume: resuming ? token : nil))
    Task { @MainActor [weak self] in
      while let self, current == self.generation {
        do {
          let message = try await task.receive()
          guard current == self.generation else { return }
          let data: Data
          switch message {
          case .data(let raw): data = raw
          case .string(let text): data = Data(text.utf8)
          @unknown default: continue
          }
          self.receive(data)
        } catch {
          guard current == self.generation else { return }
          self.connected = false
          self.status = "CONNECTION LOST"
          self.error = "Connection lost. Tap reconnect to resume your hero."
          self.log("disconnected")
          return
        }
      }
    }
  }

  func reconnect() {
    guard !token.isEmpty else {
      connect(create: false)
      return
    }
    log("reconnect_requested")
    connect(create: false, resuming: true)
  }

  func leave() {
    send(Command(type: "leave"))
    generation += 1
    socket?.cancel(with: .normalClosure, reason: nil)
    token = ""
    identity = ""
    state = nil
    notice = nil
    menuOpen = false
    gearOpen = false
    connected = false
    autoReadySent = false
    status = "LOCAL CO-OP • 2 HEROES"
    error = ""
    move = (0, 0)
    held.removeAll()
  }

  func ready() {
    send(Command(type: "ready"))
    log("ready")
  }

  func movement(_ x: Double, _ y: Double) {
    move = (x * 0.8 + y * 0.6, -x * 0.6 + y * 0.8)
    if abs(x) + abs(y) > 0.2 { log("manual_joystick") }
  }

  func hold(_ action: String, down: Bool) {
    if down {
      held.insert(action)
      perform(action)
      log("manual_\(action)")
    } else {
      held.remove(action)
    }
  }

  func perform(_ action: String, choice: String? = nil) {
    guard connected, state?.phase == "playing" else { return }
    sequence += 1
    send(
      Command(type: "input", seq: sequence, x: move.0, z: move.1, action: action, choice: choice))
  }

  func equip(_ choice: String) {
    perform("equip", choice: choice)
    gearOpen = false
  }

  func toggleDriver() {
    automation.toggle()
    held.removeAll()
    move = (0, 0)
    log(automation ? "driver_enabled" : "driver_disabled")
  }

  private func receive(_ data: Data) {
    let decoder = JSONDecoder()
    guard let reply = try? decoder.decode(Reply.self, from: data) else { return }
    if reply.type == "welcome" {
      let newIdentity = reply.id ?? ""
      if newIdentity != identity {
        lastEvent = 0
        resultFrames = 0
      }
      identity = newIdentity
      token = reply.token ?? ""
      room = reply.code ?? room
      sequence = max(sequence, (reply.seq ?? 0) + 1)
      connected = true
      status = "ONLINE • ROOM \(room)"
      log("welcome")
    }
    if reply.type == "error" {
      error = reply.message ?? "Unable to join"
      status = "CHECK CONNECTION"
    }
    if reply.type == "state", let snapshot = try? decoder.decode(Snapshot.self, from: data) {
      let previousHP = me?.hp
      state = snapshot
      world.apply(snapshot, identity: identity)
      if let previousHP, let hp = me?.hp, hp < previousHP { damagePulse += 1 }
      for event in snapshot.events where event.id > lastEvent {
        sound.play(event.kind)
        lastEvent = max(lastEvent, event.id)
        if Notice.kinds.contains(event.kind) && !event.text.isEmpty {
          notice = Notice(id: event.id, kind: event.kind, text: event.text, tick: event.tick)
        }
      }
      if let notice, snapshot.tick - notice.tick > 50 { self.notice = nil }
      if snapshot.tick % 20 == 0 {
        let text = String(data: data, encoding: .utf8) ?? "{}"
        try? logHandle?.write(
          contentsOf: Data(("{\"client\":\"\(identity)\",\"state\":\(text)}\n").utf8))
      }
    }
  }

  private func send(_ command: Command) {
    guard let data = try? JSONEncoder().encode(command), let socket else { return }
    socket.send(.data(data)) { _ in }
  }

  private func pulse() {
    frame += 1
    guard connected, let state else { return }
    if automation { drive(state) }
    guard state.phase == "playing", !state.paused else { return }
    if !automation {
      for action in held { perform(action) }
    }
    perform("move")
  }

  private func drive(_ state: Snapshot) {
    guard let me else { return }
    if state.phase == "lobby" {
      driverStep = "1 / JOIN • Two distinct network peers"
      if state.players.count == 2 && !me.ready && !autoReadySent && frame % 20 == 0 {
        ready()
        autoReadySent = true
      }
      return
    }
    if ["victory", "defeat"].contains(state.phase) {
      resultFrames += 1
      driverStep = "5 / SHARED OUTCOME • Round \(state.round)"
      if Launch.has("autoRematch") && state.round == 1 && resultFrames >= 90 && !me.ready {
        ready()
      }
      return
    }
    resultFrames = 0
    guard state.phase == "playing", !state.paused, !me.down else {
      move = (0, 0)
      return
    }
    let stage = state.stage + (state.completedStages == state.stage ? 1 : 0)
    if let ally = partner, ally.down {
      driverStep = "REVIVE • Helping \(ally.name)"
      move = DungeonMap.direction(from: me, to: (ally.x, ally.z), stage: stage)
      if hypot(ally.x - me.x, ally.z - me.z) < 2.5 {
        move = (0, 0)
        perform("revive")
      }
      if me.hp < 55 { perform("heal") }
      return
    }
    if me.hp < 66 { perform("heal") }
    if me.charge == 100 { perform("artifact") }
    if let target = state.enemies.min(by: {
      hypot($0.x - me.x, $0.z - me.z) < hypot($1.x - me.x, $1.z - me.z)
    }) {
      driverStep = "3 / COMBAT • \(state.stage == 3 ? "Hollow Warden" : "Seal \(state.stage)")"
      let distance = hypot(target.x - me.x, target.z - me.z)
      move =
        distance > 1.9
        ? DungeonMap.direction(from: me, to: (target.x, target.z), stage: stage) : (0, 0)
      if target.telegraph > state.tick && distance < 5.8 {
        move = DungeonMap.normalized(me.x - target.x, me.z - target.z)
        perform("dodge")
        driverStep = "DODGE • Escaping the Warden's slam"
      } else {
        if frame % 2 == 0 { perform("melee") }
        if frame % 7 == me.slot * 3 { perform("ranged") }
        if frame % 63 == me.slot * 11 && distance > 3 { perform("dodge") }
      }
      return
    }
    if let chest = state.loot.first(where: {
      $0.kind == "chest" && !($0.claimed ?? []).contains(identity)
    }) {
      driverStep = "4 / LOOT • Choose an equipment card"
      move = DungeonMap.direction(from: me, to: (chest.x, chest.z), stage: stage)
      if hypot(chest.x - me.x, chest.z - me.z) < 2.7 {
        let choice = state.stage == 1 ? (me.slot == 0 ? "cleaver" : "ember") : "guardian"
        perform("equip", choice: choice)
      }
    } else if let gem = state.loot.first(where: {
      $0.kind == "gem" && hypot($0.x - me.x, $0.z - me.z) < 5
    }) {
      move = DungeonMap.direction(from: me, to: (gem.x, gem.z), stage: stage)
    } else {
      driverStep = "2 / TRAVERSE • Cross the suspended bridge"
      move = DungeonMap.direction(from: me, to: (Double(state.stage * 24 - 4), 0), stage: stage)
    }
  }

  private func log(_ event: String) {
    let line =
      "{\"time\":\(Date().timeIntervalSince1970),\"event\":\"\(event)\",\"peer\":\"\(identity)\",\"tick\":\(state?.tick ?? 0)}\n"
    try? logHandle?.write(contentsOf: Data(line.utf8))
  }
}
