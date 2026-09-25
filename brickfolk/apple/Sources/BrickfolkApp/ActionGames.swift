import BrickfolkCore
import SwiftUI

struct ActionGameView: View {
  @EnvironmentObject private var client: Client
  @Environment(\.scenePhase) private var phase
  @Environment(\.colorScheme) private var scheme
  let experience: Experience
  @State private var keys: Set<String> = []
  @State private var joystick = CGSize.zero
  @FocusState private var focused: Bool
  private var spectating: Bool {
    switch client.frame {
    case .obby(let frame): return frame.players[client.myID] == nil
    case .tag(let frame): return frame.players[client.myID] == nil
    default: return false
    }
  }
  var body: some View {
    VStack(spacing: 0) {
      ZStack(alignment: .top) {
        TimelineView(.animation(minimumInterval: Double(client.config.frameIntervalMS) / 1000)) {
          timeline in
          Canvas { context, size in
            if let content = client.content {
              let alpha = min(
                1,
                max(
                  0, timeline.date.timeIntervalSince(client.frameReceivedAt) / client.frameInterval)
              )
              if experience == .obby {
                drawObby(context, size: size, content: content, alpha: alpha)
              } else {
                drawTag(context, size: size, content: content, alpha: alpha)
              }
            }
          }
        }
        .background(
          scheme == .dark
            ? Color(argb: experience == .obby ? 0xFF0E_1428 : 0xFF0B_1B2B)
            : Color(argb: experience == .obby ? 0xFF9C_C9FF : 0xFFCF_EFF8)
        )
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .focusable().focusEffectDisabled().focused($focused)
        .onKeyPress(phases: [.down, .up, .repeat]) { press in
          guard client.requestedSheet == nil, let key = keyName(press) else { return .ignored }
          if press.phase == .up { keys.remove(key) } else { keys.insert(key) }
          push()
          return .handled
        }
        VStack(spacing: 8) {
          Text(spectating ? "Spectating · join the next round" : status)
            .font(.custom("Inter-SemiBold", size: 13)).padding(10)
            .background(.ultraThinMaterial, in: Capsule())
          if let event = client.eventText {
            Text(event).font(.headline).padding(8).background(.ultraThinMaterial, in: Capsule())
          }
          if client.frame == nil { ProgressView("Waiting for live snapshots…").padding() }
        }.padding(14).allowsHitTesting(false)
      }.clipped().frame(maxHeight: .infinity)
      if !spectating {
        HStack {
          if experience == .obby {
            holdButton("arrow.left", key: "left", label: "Move left")
            holdButton("arrow.right", key: "right", label: "Move right")
            Spacer()
            holdButton("arrow.up", key: "jump", label: "Jump", color: .brick)
          } else {
            joystickView
            Spacer()
            Text("WASD / arrows to move\nTouch a frozen friend to thaw them")
              .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
          }
        }.padding(.horizontal, 20).padding(.vertical, 10).background(.regularMaterial)
      }
    }
    .onAppear { focused = true }
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(400))
        if !Task.isCancelled { push() }
      }
    }
    .onDisappear { release() }
    .onChange(of: phase) { _, phase in if phase != .active { release() } }
    .onChange(of: focused) { _, value in if !value { release() } }
    .onChange(of: client.requestedSheet) { _, sheet in
      if sheet != nil { release() } else { focused = true }
    }
  }
  private func holdButton(_ symbol: String, key: String, label: String, color: Color = .sky)
    -> some View
  {
    Image(systemName: symbol).font(.title2.bold()).foregroundStyle(.white)
      .frame(width: 66, height: 54)
      .background(
        color.opacity(keys.contains(key) ? 0.6 : 1), in: RoundedRectangle(cornerRadius: 16)
      )
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { _ in
          if !keys.contains(key) {
            keys.insert(key)
            push()
          }
        }.onEnded { _ in
          keys.remove(key)
          push()
        }
      )
      .accessibilityLabel(label).accessibilityAddTraits(.isButton)
      .accessibilityAction {
        keys.insert(key)
        push()
        Task {
          try? await Task.sleep(for: .milliseconds(200))
          keys.remove(key)
          push()
        }
      }
  }
  private var joystickView: some View {
    ZStack {
      Circle().fill(Color.sky.opacity(0.2))
      Image(systemName: "arrow.up.and.down.and.arrow.left.and.right").foregroundStyle(.secondary)
      Circle().fill(Color.sky).frame(width: 34, height: 34)
        .offset(x: joystick.width * 30, y: joystick.height * 30)
    }.frame(width: 96, height: 96)
      .contentShape(Circle())
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { value in
          let x = (value.location.x - 48) / 30
          let y = (value.location.y - 48) / 30
          let length = max(1, hypot(x, y))
          joystick = CGSize(width: x / length, height: y / length)
          push()
        }.onEnded { _ in
          joystick = .zero
          push()
        }
      )
      .accessibilityLabel("Movement joystick. Drag in the direction to run.")
  }
  private func release() {
    keys = []
    joystick = .zero
    push(force: true)
  }
  private func push(force: Bool = false) {
    guard !spectating, force || (client.requestedSheet == nil && phase == .active) else { return }
    guard !client.config.test || client.config.tour else { return }
    if experience == .obby {
      client.input(
        .obby(
          left: keys.contains("left"), right: keys.contains("right"),
          jump: keys.contains("jump") || keys.contains("up"), tick: client.frame?.tick))
    } else {
      var x =
        joystick.width != 0 || joystick.height != 0
        ? joystick.width : (keys.contains("right") ? 1.0 : 0) - (keys.contains("left") ? 1.0 : 0)
      var y =
        joystick.width != 0 || joystick.height != 0
        ? joystick.height : (keys.contains("down") ? 1.0 : 0) - (keys.contains("up") ? 1.0 : 0)
      let length = max(1, hypot(x, y))
      x /= length
      y /= length
      client.input(.tag(dx: x, dy: y))
    }
  }
  private func keyName(_ press: KeyPress) -> String? {
    switch press.key {
    case .leftArrow: return "left"
    case .rightArrow: return "right"
    case .upArrow: return "up"
    case .downArrow: return "down"
    case .space: return "jump"
    default:
      return ["a": "left", "d": "right", "w": "up", "s": "down"][press.characters.lowercased()]
    }
  }
  private var status: String {
    switch client.frame {
    case .obby(let frame):
      guard let player = frame.players[client.myID] else { return "Skyline Obby" }
      if let finish = player.finishTick {
        return "Summit reached · \(String(format: "%.1f", Double(finish) / 30))s"
      }
      return "Stage \(player.checkpoint + 1)/12 · \(player.deaths) falls"
    case .tag(let frame):
      if frame.intermission > 0 { return "Round \(frame.round) complete · next round soon" }
      let player = frame.players[client.myID]
      let role =
        player?.isTagger == true
        ? "You're IT!" : player?.frozen == true ? "Frozen · wait for a rescue" : "Run and rescue!"
      return "Round \(frame.round)/3 · \(frame.roundTicksLeft / 30)s · \(role)"
    default: return "Connecting to the world…"
    }
  }

  private func drawObby(_ ctx: GraphicsContext, size: CGSize, content: GameContent, alpha: Double) {
    guard case .obby(let frame) = client.frame else { return }
    let previous: ObbyFrame?
    if case .obby(let old) = client.previousFrame { previous = old } else { previous = nil }
    let focus = frame.players[client.myID] ?? frame.players.sorted { $0.key < $1.key }.first?.value
    let scale = min(62, max(24, size.height / 14))
    let cameraX = (focus?.x ?? 2) + min(4, size.width / scale * 0.2)
    let cameraY = max(0, focus?.y ?? 0) + 3
    func point(_ x: Double, _ y: Double) -> CGPoint {
      CGPoint(x: (x - cameraX) * scale + size.width / 2, y: size.height / 2 - (y - cameraY) * scale)
    }
    for index in -2...12 {
      let x = Double(index) * 120 - (cameraX * scale * 0.12).truncatingRemainder(dividingBy: 120)
      let height = CGFloat(80 + (index * index * 37) % 140)
      let bounds = CGRect(x: x, y: size.height - height, width: 82, height: height)
      ctx.fill(Path(roundedRect: bounds, cornerRadius: 6), with: .color(Color.sky.opacity(0.12)))
      for floor in 0..<4 {
        ctx.fill(
          Path(CGRect(x: x + 12, y: bounds.minY + 15 + Double(floor) * 22, width: 45, height: 7)),
          with: .color(.white.opacity(0.08)))
      }
    }
    for platform in content.obby.platforms {
      let top = point(platform.x, platform.y + platform.h)
      let bounds = CGRect(x: top.x, y: top.y, width: platform.w * scale, height: platform.h * scale)
      guard bounds.maxX >= 0 && bounds.minX <= size.width else { continue }
      let color: Color =
        platform.kind == "kill"
        ? .red : platform.kind == "finish" ? .sun : platform.kind == "checkpoint" ? .mint : .sky
      ctx.fill(
        Path(roundedRect: bounds, cornerRadius: 4),
        with: .linearGradient(
          Gradient(colors: [color, color.opacity(0.6)]),
          startPoint: bounds.origin, endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)))
      ctx.fill(
        Path(CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: 5)),
        with: .color(.white.opacity(0.32)))
      for stud in 0..<max(1, Int(platform.w)) {
        ctx.fill(
          Path(
            ellipseIn: CGRect(
              x: bounds.minX + Double(stud) * scale + scale * 0.25, y: bounds.minY + 9,
              width: scale * 0.4, height: 5)), with: .color(.white.opacity(0.18)))
      }
      if platform.kind == "checkpoint",
        let index = content.obby.checkpoints.firstIndex(where: {
          abs($0.x - (platform.x + 2)) < 0.01
        })
      {
        let flag = point(platform.x + 0.5, platform.y + platform.h + 2)
        ctx.fill(
          Path(CGRect(x: flag.x, y: flag.y, width: 3, height: scale * 2)), with: .color(.white))
        ctx.draw(
          Text("\(index + 1)").font(.system(size: 12, weight: .bold)).foregroundColor(.white),
          at: CGPoint(x: flag.x + 13, y: flag.y + 9))
      }
    }
    for (id, player) in frame.players.sorted(by: { $0.key < $1.key }) {
      let old = previous?.players[id]
      let position = blend(x: player.x, y: player.y, oldX: old?.x, oldY: old?.y, alpha: alpha)
      let feet = point(position.x, position.y)
      guard let member = client.room?.members.first(where: { $0.id == id }) else { continue }
      AvatarPainter.draw(
        ctx,
        rect: CGRect(
          x: feet.x - scale * 0.45, y: feet.y - scale * 1.6, width: scale * 0.9, height: scale * 1.6
        ),
        avatar: member.player.avatar, facingRight: player.facingRight, walk: player.x * 0.5)
      ctx.draw(
        Text(member.player.name).font(
          .system(size: 11, weight: id == client.myID ? .bold : .regular)
        ).foregroundColor(.white),
        at: CGPoint(x: feet.x, y: feet.y - scale * 2))
    }
  }

  private func drawTag(_ ctx: GraphicsContext, size: CGSize, content: GameContent, alpha: Double) {
    guard case .tag(let frame) = client.frame else { return }
    let previous: TagFrame?
    if case .tag(let old) = client.previousFrame { previous = old } else { previous = nil }
    let arena = content.tag
    let focus = frame.players[client.myID] ?? frame.players.sorted { $0.key < $1.key }.first?.value
    let viewport = ArenaViewport(
      width: size.width, height: size.height, playerX: focus?.x ?? 12, playerY: focus?.y ?? 8,
      arena: arena)
    let scale = viewport.scale
    func point(_ x: Double, _ y: Double) -> CGPoint {
      CGPoint(x: viewport.originX + x * scale, y: viewport.originY + y * scale)
    }
    let origin = point(0, 0)
    let floor = CGRect(
      x: origin.x, y: origin.y, width: arena.width * scale, height: arena.height * scale)
    ctx.fill(Path(roundedRect: floor, cornerRadius: 12), with: .color(Color.cyan.opacity(0.1)))
    ctx.stroke(
      Path(roundedRect: floor, cornerRadius: 12), with: .color(.cyan.opacity(0.5)), lineWidth: 5)
    for x in 1..<24 {
      var path = Path()
      path.move(to: point(Double(x), 0))
      path.addLine(to: point(Double(x), 16))
      ctx.stroke(path, with: .color(.cyan.opacity(0.1)), lineWidth: 1)
    }
    for y in 1..<16 {
      var path = Path()
      path.move(to: point(0, Double(y)))
      path.addLine(to: point(24, Double(y)))
      ctx.stroke(path, with: .color(.cyan.opacity(0.1)), lineWidth: 1)
    }
    for wall in arena.walls {
      let location = point(wall.x, wall.y)
      let rect = CGRect(x: location.x, y: location.y, width: wall.w * scale, height: wall.h * scale)
      ctx.fill(
        Path(roundedRect: rect.offsetBy(dx: 0, dy: 5), cornerRadius: 5),
        with: .color(.black.opacity(0.3)))
      ctx.fill(
        Path(roundedRect: rect, cornerRadius: 5),
        with: .linearGradient(
          Gradient(colors: [Color(argb: 0xFF6F_BBDE), Color(argb: 0xFF35_7498)]),
          startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
    }
    for (id, player) in frame.players.sorted(by: { $0.value.y < $1.value.y }) {
      guard let member = client.room?.members.first(where: { $0.id == id }) else { continue }
      let old = previous?.players[id]
      let location = blend(x: player.x, y: player.y, oldX: old?.x, oldY: old?.y, alpha: alpha)
      let feet = point(location.x, location.y)
      let ring = CGRect(
        x: feet.x - scale * 0.6, y: feet.y - scale * 0.4, width: scale * 1.2, height: scale * 0.65)
      ctx.fill(
        Path(ellipseIn: ring), with: .color((player.isTagger ? Color.red : .cyan).opacity(0.3)))
      if player.frozen {
        ctx.stroke(Path(ellipseIn: ring.insetBy(dx: -4, dy: -4)), with: .color(.cyan), lineWidth: 3)
        let bar = CGRect(
          x: feet.x - 20, y: feet.y + 13, width: 40 * min(1, Double(player.thawProgress) / 30),
          height: 4)
        ctx.fill(Path(bar), with: .color(.mint))
      }
      AvatarPainter.draw(
        ctx,
        rect: CGRect(
          x: feet.x - scale * 0.45, y: feet.y - scale * 1.45, width: scale * 0.9,
          height: scale * 1.5),
        avatar: member.player.avatar, facingRight: cos(player.facing) >= 0,
        walk: player.frozen ? 0 : (player.x + player.y) * 0.5, frozen: player.frozen)
      ctx.draw(
        Text(player.isTagger ? "IT · \(member.player.name)" : member.player.name)
          .font(.system(size: 11, weight: .bold)).foregroundColor(player.isTagger ? .red : .white),
        at: CGPoint(x: feet.x, y: feet.y - scale * 1.85))
    }
    if size.width < arena.width * scale + 128 {
      let mini = CGRect(x: size.width - 140, y: size.height - 94, width: 126, height: 84)
      ctx.fill(
        Path(roundedRect: mini.insetBy(dx: -5, dy: -5), cornerRadius: 8),
        with: .color(.ink.opacity(0.88)))
      for wall in arena.walls {
        ctx.fill(
          Path(
            CGRect(
              x: mini.minX + wall.x / arena.width * mini.width,
              y: mini.minY + wall.y / arena.height * mini.height,
              width: wall.w / arena.width * mini.width, height: wall.h / arena.height * mini.height)
          ), with: .color(.cyan.opacity(0.45)))
      }
      for (id, player) in frame.players {
        let dot = CGRect(
          x: mini.minX + player.x / arena.width * mini.width - 2.5,
          y: mini.minY + player.y / arena.height * mini.height - 2.5, width: 5, height: 5)
        ctx.fill(
          Path(ellipseIn: dot),
          with: .color(player.isTagger ? .red : player.frozen ? .cyan : .white))
        if id == client.myID {
          ctx.stroke(Path(ellipseIn: dot.insetBy(dx: -2, dy: -2)), with: .color(.sun), lineWidth: 1)
        }
      }
    }
  }
  private func blend(x: Double, y: Double, oldX: Double?, oldY: Double?, alpha: Double) -> CGPoint {
    guard let oldX, let oldY, abs(oldX - x) < 3, abs(oldY - y) < 3 else {
      return CGPoint(x: x, y: y)
    }
    return CGPoint(x: oldX + (x - oldX) * alpha, y: oldY + (y - oldY) * alpha)
  }
}
