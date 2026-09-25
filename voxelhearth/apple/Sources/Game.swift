import Combine
import Foundation
import HearthCore
import simd

@MainActor final class Game: ObservableObject {
  let session: Session
  @Published var paused = false
  @Published var chatting = false
  @Published var targetName = ""
  @Published var progress = 0.0
  @Published var fps = 60
  @Published var positionLabel = ""
  var body = Body()
  var yaw = 0.0, pitch = 0.0
  var keys = Set<String>()
  var stick = SIMD2<Double>.zero
  var jump = false, sneak = false, sprint = false
  var breaking = false
  var target: RayHit?
  var damage: Float = 0
  var particles: [Particle] = []
  var renderPlayers: [Player] = []
  var renderMobs: [Mob] = []
  var animation = 0.0
  private var lastTarget: RayHit?
  private var cooldown = 0.0, networkTime = 0.0, uiTime = 0.0
  private var seq = 0
  private var unstuck = false
  private var spawn = SIMD3<Double>(0, 40, 0)
  private var footstep = 0.0
  var blocked: Bool {
    paused || chatting || session.containerKind != nil || session.hp <= 0
      || session.phase != "playing" || !session.online
  }
  var camera: SIMD3<Double> {
    let lowered = (sneak || keys.contains("shift")) && !body.flying
    let bob =
      body.onGround && hypot(body.vx, body.vz) > 0.5 && !lowered ? sin(animation * 11) * 0.03 : 0
    return SIMD3(body.x, body.y + (lowered ? 1.27 : 1.62) + bob, body.z)
  }
  var forward: SIMD3<Double> { SIMD3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) }
  init(_ session: Session) {
    self.session = session
    session.onDrive = { [weak self] action in
      guard let self else {
        var result = ClientReport()
        result.ok = false
        return result
      }
      return await self.drive(action)
    }
    session.onPosition = { [weak self] x, y, z, yaw, pitch in
      guard let self else { return }
      self.body = Body()
      self.body.x = x
      self.body.y = y
      self.body.z = z
      self.spawn = SIMD3(x, y, z)
      self.unstuck = false
      if let yaw { self.yaw = yaw }
      if let pitch { self.pitch = pitch }
      self.resetInput()
      self.paused = false
    }
    session.onEffect = { [weak self] message in
      guard let self else { return }
      if message.kind == "hurt" { self.damage = 1 }
      if ["break", "place"].contains(message.kind ?? ""), let x = message.x, let y = message.y,
        let z = message.z
      {
        for index in 0..<12 {
          self.particles.append(
            Particle(
              position: SIMD3(x + 0.5, y + 0.5, z + 0.5),
              velocity: SIMD3(
                sin(Double(index) * 2.4) * 1.8, Double(index % 4) + 1,
                cos(Double(index) * 2.4) * 1.8),
              life: 0.65))
        }
      }
    }
  }
  func resetInput() {
    keys.removeAll()
    stick = .zero
    breaking = false
    jump = false
    sneak = false
    sprint = false
  }
  func look(_ dx: Double, _ dy: Double) {
    guard !blocked else { return }
    yaw -= dx * 0.0025 * session.preferences.sensitivity
    pitch += dy * 0.0025 * session.preferences.sensitivity * (session.preferences.invertY ? 1 : -1)
    pitch = max(-1.54, min(1.54, pitch))
  }
  func key(_ key: String, down: Bool) {
    if !down {
      keys.remove(key)
      return
    }
    if key == "escape" {
      if session.containerKind != nil {
        session.closeInventory()
      } else if chatting {
        chatting = false
      } else {
        paused.toggle()
      }
      resetInput()
      return
    }
    guard !blocked else { return }
    if keys.contains(key) { return }
    keys.insert(key)
    if let slot = Int(key), (1...9).contains(slot) { session.select(slot - 1) }
    switch key {
    case "e":
      session.containerKind = "inventory"
      resetInput()
    case "t":
      chatting = true
      resetInput()
    case "q": drop()
    case "f": toggleFly()
    default: break
    }
  }
  func toggleFly() { if session.mode == "creative" { body.flying.toggle() } }
  func drop() {
    var message = ClientMessage(.dropItem)
    message.slot = session.selected
    message.count = 1
    session.send(message)
  }
  func startBreak() {
    guard !blocked else { return }
    breaking = true
  }
  private func aimedMob() -> Mob? {
    session.mobs.filter {
      let delta = SIMD3($0.x, $0.y + 0.8, $0.z) - camera
      let distance = simd_length(delta)
      return distance < 4 && distance > 0.01 && simd_dot(delta / distance, forward) > 0.92
        && distance < (target?.distance ?? 5.5)
    }.min {
      simd_distance(SIMD3($0.x, $0.y, $0.z), camera)
        < simd_distance(SIMD3($1.x, $1.y, $1.z), camera)
    }
  }
  func use() {
    guard !blocked else { return }
    if let t = target, Registry.shared.block(t.id).interactive && !(sneak || keys.contains("shift"))
    {
      session.send(.block(.interact, t.x, t.y, t.z))
      return
    }
    let held = session.inventory[session.selected]
    if Registry.shared.item(held.id).food > 0 {
      session.send(.eat)
      return
    }
    guard !held.isEmpty, held.id <= 33, let target else { return }
    let replace = Registry.shared.block(target.id).replaceable
    let x = target.x + (replace ? 0 : target.nx)
    let y = target.y + (replace ? 0 : target.ny)
    let z = target.z + (replace ? 0 : target.nz)
    guard (0..<64).contains(y) else { return }
    if Registry.shared.block(held.id).solid && Double(x + 1) > body.x - 0.3
      && Double(x) < body.x + 0.3 && Double(z + 1) > body.z - 0.3 && Double(z) < body.z + 0.3
      && Double(y + 1) > body.y && Double(y) < body.y + 1.8
    {
      return
    }
    var message = ClientMessage.block(.place, x, y, z)
    message.nx = target.nx
    message.ny = target.ny
    message.nz = target.nz
    session.send(message)
  }
  func update(_ elapsed: Double) {
    let dt = min(0.05, max(0.001, elapsed))
    animation += dt
    cooldown = max(0, cooldown - dt)
    damage = max(0, damage - Float(dt * 3))
    interpolate(dt)
    for index in particles.indices {
      particles[index].position += particles[index].velocity * dt
      particles[index].velocity.y -= dt * 8
      particles[index].life -= dt
    }
    particles.removeAll { $0.life <= 0 }
    guard let world = session.world else { return }
    if session.mode != "creative" { body.flying = false }
    if !blocked && world.loaded(Int(floor(body.x)), Int(floor(body.z))) {
      if !unstuck {
        for _ in 0..<60 {
          if !Physics.collides(world, body.x, body.y, body.z) { break }
          body.y += 1
        }
        unstuck = true
      }
      let sx = stick.x + (keys.contains("d") ? 1 : 0) - (keys.contains("a") ? 1 : 0)
      let fz = stick.y + (keys.contains("w") ? 1 : 0) - (keys.contains("s") ? 1 : 0)
      let direction = Physics.wish(strafe: sx, forward: fz, yaw: yaw)
      let isSneaking = sneak || keys.contains("shift")
      let isSprinting = sprint || keys.contains("control") || keys.contains("command")
      let speed =
        body.flying
        ? 10.5 : body.inWater ? 2.2 : isSneaking ? 1.3 : isSprinting && fz > 0 ? 5.6 : 4.3
      let oldX = body.x
      let oldZ = body.z
      let ledgeGuard = isSneaking && body.onGround && !body.flying
      Physics.step(
        &body, world: world, dt: dt, wishX: direction.x * speed, wishZ: direction.y * speed,
        jump: !body.flying && (jump || keys.contains(" ")),
        wishY: ((jump || keys.contains(" ")) ? 8.4 : 0) - (isSneaking ? 8.4 : 0))
      if ledgeGuard && !body.onGround && body.vy <= 0
        && !Physics.collides(world, body.x, body.y - 0.3, body.z)
      {
        body.x = oldX
        body.z = oldZ
        body.vx = 0
        body.vz = 0
        body.onGround = true
      }
      if body.y < -8 {
        body.x = spawn.x
        body.y = spawn.y
        body.z = spawn.z
        body.vy = 0
      }
      footstep += dt
      if footstep > 0.45 && body.onGround && hypot(body.vx, body.vz) > 0.5 {
        footstep = 0
        session.feedback.play(body.inWater ? "splash" : "dig")
      }
      target = Physics.raycast(world, origin: camera, direction: forward)
      networkTime += dt
      if networkTime >= 0.05 {
        networkTime = 0
        var message = ClientMessage(.move)
        message.x = body.x
        message.y = body.y
        message.z = body.z
        message.vx = body.vx
        message.vy = body.vy
        message.vz = body.vz
        message.yaw = yaw
        message.pitch = pitch
        message.ground = body.onGround
        message.sneak = isSneaking
        message.sprint = isSprinting
        message.fly = body.flying
        message.seq = seq
        seq += 1
        session.send(message)
      }
      if let mob = aimedMob(), breaking && cooldown == 0 {
        var attack = ClientMessage(.attack)
        attack.id = mob.id
        session.send(attack)
        cooldown = 0.3
        progress = 0
      } else if let t = target, breaking && cooldown == 0 {
        if lastTarget?.x != t.x || lastTarget?.y != t.y || lastTarget?.z != t.z { progress = 0 }
        lastTarget = t
        let seconds =
          session.mode == "creative"
          ? 0.12 : Registry.shared.breakSeconds(t.id, held: session.inventory[session.selected].id)
        if seconds > 0 {
          progress += dt / seconds
          if progress >= 1 {
            session.send(.block(.breakBlock, t.x, t.y, t.z))
            progress = 0
            cooldown = 0.18
          }
        }
      } else {
        progress = 0
      }
    } else {
      breaking = false
      progress = 0
    }
    uiTime += dt
    if uiTime >= 0.2 {
      uiTime = 0
      fps = Int(1 / max(elapsed, 0.001))
      targetName = target.map { Registry.shared.block($0.id).name } ?? ""
      positionLabel = "\(Int(body.x)), \(Int(body.y)), \(Int(body.z))"
    }
  }
  private func interpolate(_ dt: Double) {
    let amount = min(1, dt * 12)
    let previousPlayers = Dictionary(uniqueKeysWithValues: renderPlayers.map { ($0.id, $0) })
    renderPlayers = session.remotePlayers.map { player in
      guard let old = previousPlayers[player.id] else { return player }
      var next = player
      next.x = (old.x ?? 0) + ((player.x ?? 0) - (old.x ?? 0)) * amount
      next.y = (old.y ?? 0) + ((player.y ?? 0) - (old.y ?? 0)) * amount
      next.z = (old.z ?? 0) + ((player.z ?? 0) - (old.z ?? 0)) * amount
      return next
    }
    let previousMobs = Dictionary(uniqueKeysWithValues: renderMobs.map { ($0.id, $0) })
    renderMobs = session.mobs.map { mob in
      guard let old = previousMobs[mob.id] else { return mob }
      var next = mob
      next.x = old.x + (mob.x - old.x) * amount
      next.y = old.y + (mob.y - old.y) * amount
      next.z = old.z + (mob.z - old.z) * amount
      return next
    }
  }
}

extension Game {
  func drive(_ action: DriveAction) async -> ClientReport {
    var report = ClientReport()
    func screen() -> String {
      session.code == nil ? "home" : session.phase == "playing" ? "game" : session.phase
    }
    switch action.t {
    case "screen": report.screen = screen()
    case "wait_screen", "wait_game", "wait_ready":
      let wanted = action.t == "wait_screen" ? action.screen ?? "" : "game"
      let deadline = Date().addingTimeInterval(20)
      while Date() < deadline {
        if screen() == wanted
          && (wanted != "game" || session.world?.loaded(Int(body.x), Int(body.z)) == true)
        {
          break
        }
        try? await Task.sleep(for: .milliseconds(40))
      }
      report.screen = screen()
      report.ok =
        screen() == wanted
        && (wanted != "game" || session.world?.loaded(Int(body.x), Int(body.z)) == true)
    case "state":
      report.x = body.x
      report.y = body.y
      report.z = body.z
      report.yaw = yaw
      report.pitch = pitch
      report.phase = session.phase
      report.hp = session.hp
      report.food = session.food
      report.score = session.score
      report.selected = session.selected
      report.held = session.inventory[session.selected]
      report.players = session.players.count
      report.worldHash = session.world?.editsHash
      report.chatHash = Fingerprint.chat(session.chat)
      report.ready = session.world?.loaded(Int(body.x), Int(body.z))
      report.spawnReady = report.ready
      report.ground = body.onGround
      report.chunks = session.world?.chunks.count
    case "block":
      report.block = session.world?.peek(Int(action.x ?? 0), Int(action.y ?? 0), Int(action.z ?? 0))
    case "look":
      yaw = action.yaw ?? yaw
      pitch = max(-1.55, min(1.55, action.pitch ?? pitch))
    case "look_at", "place", "break", "place_at":
      let x = Int(action.x ?? 0)
      let y = Int(action.y ?? 0)
      let z = Int(action.z ?? 0)
      let delta = SIMD3(Double(x) + 0.5, Double(y) + 0.5, Double(z) + 0.5) - camera
      yaw = atan2(delta.x, delta.z)
      pitch = atan2(delta.y, hypot(delta.x, delta.z))
      if let world = session.world {
        target = Physics.raycast(world, origin: camera, direction: forward)
      }
      if action.t == "place" { use() }
      if action.t == "place_at" {
        var message = ClientMessage.block(.place, x, y, z)
        message.nx = action.nx ?? 0
        message.ny = action.ny ?? 1
        message.nz = action.nz ?? 0
        session.send(message)
      }
      if action.t == "break" { startBreak() }
      if action.t == "place_at" || action.t == "break" {
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline
          && ((session.world?.peek(x, y, z) ?? 0) == 0) != (action.t == "break")
        {
          try? await Task.sleep(for: .milliseconds(40))
        }
        breaking = false
        report.ok = ((session.world?.peek(x, y, z) ?? 0) == 0) == (action.t == "break")
      }
    case "teleport":
      body.x = action.x ?? body.x
      body.y = action.y ?? body.y
      body.z = action.z ?? body.z
      body.vx = 0
      body.vy = 0
      body.vz = 0
      unstuck = false
    case "walk":
      let key = ["back": "s", "left": "a", "right": "d"][action.dir ?? ""] ?? "w"
      keys.insert(key)
      jump = action.jump == true
      try? await Task.sleep(for: .seconds(max(0, min(10, action.seconds ?? 0.5))))
      keys.remove(key)
      jump = false
      report.x = body.x
      report.y = body.y
      report.z = body.z
    case "set_theme": session.preferences.theme = action.theme ?? "dark"
    case "set_touch": session.preferences.touch = action.on ?? true
    case "open_inventory": session.containerKind = "inventory"
    case "close_overlay":
      session.closeInventory()
      paused = false
      chatting = false
    case "pause":
      paused = action.on ?? !paused
      resetInput()
    case "toggle_chat":
      chatting = action.open ?? !chatting
      resetInput()
    case "chat_log": report.lines = session.chat
    case "results":
      report.results = session.results
      report.worldHash = session.worldHash
      report.chatHash = session.chatHash
    case "drop_connection":
      session.dropConnection()
      let deadline = Date().addingTimeInterval(20)
      while !session.online && Date() < deadline { try? await Task.sleep(for: .milliseconds(100)) }
      report.ok = session.online
    case "leave_room": session.leave()
    case "select_slot": session.select(action.slot ?? 0)
    default:
      if let data = try? JSONEncoder().encode(action),
        let message = try? JSONDecoder().decode(ClientMessage.self, from: data)
      {
        session.send(message)
      } else {
        report.ok = false
        report.error = "Unsupported native drive action: \(action.t)"
      }
    }
    return report
  }
}

struct Particle {
  var position: SIMD3<Double>
  var velocity: SIMD3<Double>
  var life: Double
}
