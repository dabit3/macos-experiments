import CoreGraphics
import HearthCore
import SwiftUI
import simd

struct ChatPanel: View {
  @ObservedObject var session: Session
  var title = "Chat"
  @State private var draft = ""
  @FocusState private var editing: Bool
  private var canSend: Bool {
    !draft.trimmingCharacters(in: .whitespaces).isEmpty && session.online
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      CardHeader(title: title)
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(Array(session.chat.enumerated()), id: \.offset) { index, line in
              ChatLineView(line: line, mine: line.from == currentName).id(index)
            }
          }
          .padding(.vertical, 4)
        }
        .overlay {
          if session.chat.isEmpty {
            Text("No messages yet. Say hi to your party.")
              .font(Hearth.type(14)).foregroundStyle(Hearth.muted)
              .multilineTextAlignment(.center)
          }
        }
        .onChange(of: session.chat.count) { _, count in proxy.scrollTo(count - 1, anchor: .bottom)
        }
      }
      .frame(maxHeight: .infinity)
      HStack(spacing: 8) {
        TextField("", text: $draft, prompt: prompt("Message"))
          .hearthField()
          .focused($editing).onSubmit(send)
          .submitLabel(.send)
          .accessibilityIdentifier("chat-message")
        Button(action: send) {
          Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold))
            .frame(width: 44, height: 44)
            .foregroundStyle(Hearth.ink)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Hearth.gold))
            .opacity(canSend ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .accessibilityLabel("Send")
        .keyboardShortcut(.return, modifiers: [])
      }
    }
    .panel(padding: 16)
  }
  private var currentName: String {
    session.players.first { $0.id == session.playerID }?.name ?? ""
  }
  private func send() {
    session.chatSend(draft)
    draft = ""
    editing = true
  }
}

struct ChatLineView: View {
  let line: ChatLine
  var mine = false
  var body: some View {
    if line.system {
      Label(line.text, systemImage: "info.circle")
        .font(Hearth.type(13)).foregroundStyle(Hearth.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      VStack(alignment: .leading, spacing: 2) {
        Text(line.from).font(Hearth.type(12, .semibold))
          .foregroundStyle(mine ? Hearth.gold : Hearth.teal)
        Text(line.text).font(Hearth.type(15)).foregroundStyle(Hearth.cream)
          .textSelection(.enabled)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
    }
  }
}

struct SettingsScreen: View {
  @EnvironmentObject var preferences: Preferences
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      Form {
        Section("Look") {
          VStack(alignment: .leading) {
            LabeledContent("Sensitivity", value: String(format: "%.1f×", preferences.sensitivity))
            Slider(value: $preferences.sensitivity, in: 0.2...3) { Text("Look sensitivity") }
              .labelsHidden()
          }
          VStack(alignment: .leading) {
            LabeledContent("Field of view", value: "\(Int(preferences.fov))°")
            Slider(value: $preferences.fov, in: 50...110) { Text("Field of view") }
              .labelsHidden()
          }
          Toggle("Invert vertical look", isOn: $preferences.invertY)
          #if os(iOS)
            Toggle("Show touch controls", isOn: $preferences.touch)
          #endif
        }
        Section("Display") {
          Picker("Graphics quality", selection: $preferences.quality) {
            Text("Low").tag(0)
            Text("Balanced").tag(1)
            Text("High").tag(2)
          }
          Picker("Appearance", selection: $preferences.theme) {
            Text("System").tag("system")
            Text("Dark").tag("dark")
            Text("Light").tag("light")
          }
          Toggle("Show FPS and coordinates", isOn: $preferences.showFPS)
        }
        Section("Feedback") {
          Toggle("Sound", isOn: $preferences.sound)
          #if os(iOS)
            Toggle("Haptics", isOn: $preferences.haptics)
          #endif
        }
        #if os(iOS)
          Section("Touch") {
            binding("Move", "Left stick (camera relative)")
            binding("Look", "Drag the world")
            binding("Dig", "Hold Break, or hold still on a block")
            binding("Place / use", "Place")
            binding("Jump · Sneak · Sprint", "Hold the buttons")
          }
        #endif
        Section("Keyboard & mouse") {
          binding("Move", "W A S D")
          binding("Jump", "Space")
          binding("Sneak", "Shift")
          binding("Sprint", "Control or Command")
          binding("Dig", "Hold left click")
          binding("Place / use", "Right click")
          binding("Hotbar", "1 – 9 or scroll")
          binding("Inventory", "E")
          binding("Chat", "T")
          binding("Drop item", "Q")
          binding("Fly (creative)", "F")
          binding("Pause / release mouse", "Esc")
        }
      }
      .formStyle(.grouped)
      .navigationTitle("Settings")
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
    .foregroundStyle(Color.primary)
    .tint(.accentColor)
    #if os(macOS)
      .frame(width: 520, height: 640)
    #endif
  }
  private func binding(_ action: String, _ keys: String) -> some View {
    LabeledContent(action) {
      Text(keys).font(.system(size: 13, weight: .medium, design: .rounded))
    }
  }
}

struct VitalBar: View {
  let symbol: String
  let value: Int
  let maximum: Int
  let tint: Color
  let label: String
  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
        .frame(width: 14)
      ZStack(alignment: .leading) {
        Capsule().fill(Color.white.opacity(0.12))
        Capsule().fill(tint)
          .frame(width: 84 * CGFloat(max(0, min(value, maximum))) / CGFloat(max(1, maximum)))
      }
      .frame(width: 84, height: 7)
      Text("\(value)").font(Hearth.type(12, .semibold)).monospacedDigit()
        .frame(minWidth: 18, alignment: .trailing)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(label) \(value) of \(maximum)")
  }
}

struct GameScreen: View {
  @ObservedObject var session: Session
  @ObservedObject var game: Game
  @EnvironmentObject var preferences: Preferences
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Binding var options: Bool
  var body: some View {
    ZStack {
      Hearth.ink.ignoresSafeArea()
      NativeViewport(game: game).ignoresSafeArea()
      particleLayer.allowsHitTesting(false)
      if session.phase == "results" {
        ZStack {
          Hearth.ink.opacity(0.7).ignoresSafeArea()
          ResultsScreen(session: session)
        }
      } else {
        VStack(spacing: 10) {
          topBar
          Spacer()
          if !game.blocked { reticle }
          Spacer()
          if !game.blocked {
            if let line = session.chat.last {
              HStack {
                Text(line.system ? line.text : "\(line.from): \(line.text)")
                  .font(Hearth.type(13)).lineLimit(2)
                  .padding(.horizontal, 10).padding(.vertical, 6)
                  .background(Capsule().fill(Hearth.ink.opacity(0.6)))
                Spacer()
              }
              .allowsHitTesting(false)
            }
            #if os(iOS)
              if preferences.touch { TouchControls(game: game) }
            #endif
            hotbar
          }
        }
        .padding(12)
        if game.blocked {
          Hearth.ink.opacity(0.55).ignoresSafeArea().allowsHitTesting(false)
        }
        if session.hp <= 0 {
          VStack(spacing: 14) {
            Text("You died").font(Hearth.pixel(40)).foregroundStyle(Hearth.danger)
            Text("Score \(session.score)").font(Hearth.type(16)).foregroundStyle(Hearth.muted)
            Button("Respawn") { session.send(.respawn) }
              .buttonStyle(HearthButton(.primary, wide: true))
              .keyboardShortcut(.defaultAction)
          }
          .frame(width: 300).panel(padding: 24)
        } else if session.containerKind != nil {
          InventoryScreen(session: session)
        } else if game.chatting {
          VStack(spacing: 10) {
            HStack {
              Spacer()
              IconButton("xmark", "Close chat") { game.chatting = false }
            }
            ChatPanel(session: session)
          }
          .padding(16).frame(maxWidth: 560, maxHeight: 440)
        } else if game.paused {
          pauseMenu
        }
        if !session.online {
          VStack(spacing: 14) {
            if session.connection == .failed {
              Image(systemName: "wifi.slash").font(.system(size: 28)).foregroundStyle(Hearth.danger)
            } else {
              ProgressView().tint(Hearth.gold)
            }
            Text(session.connection == .failed ? "Connection lost" : "Reconnecting…")
              .font(Hearth.type(22, .semibold))
            Text("Your player and world resume as soon as the server is reachable.")
              .font(Hearth.type(14)).foregroundStyle(Hearth.muted).multilineTextAlignment(.center)
            Button("Try again") { session.connect() }.buttonStyle(HearthButton(wide: true))
          }
          .frame(maxWidth: 360).panel(padding: 24)
        }
        if let toast = session.toast {
          VStack {
            Spacer()
            Button {
              session.toast = nil
            } label: {
              Text(toast).font(Hearth.type(14, .medium))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(Hearth.surface.opacity(0.95)))
                .overlay(Capsule().strokeBorder(Hearth.gold.opacity(0.4)))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 110)
          }
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .task(id: toast) {
            try? await Task.sleep(for: .seconds(4))
            if session.toast == toast { session.toast = nil }
          }
        }
      }
    }
    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: game.paused)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: session.toast)
    .onChange(of: session.containerKind) { _, _ in game.resetInput() }
    .onChange(of: session.phase) { _, _ in
      game.resetInput()
      game.paused = false
      game.chatting = false
    }
  }
  private var reticle: some View {
    VStack(spacing: 8) {
      ZStack {
        Rectangle().frame(width: 18, height: 2)
        Rectangle().frame(width: 2, height: 18)
      }
      .foregroundStyle(Hearth.cream.opacity(0.9))
      .shadow(color: .black.opacity(0.8), radius: 1)
      .accessibilityHidden(true)
      if !game.targetName.isEmpty {
        Text(game.targetName).font(Hearth.type(13, .medium))
          .padding(.horizontal, 8).padding(.vertical, 3)
          .background(Capsule().fill(Hearth.ink.opacity(0.55)))
      }
      if game.progress > 0 {
        ZStack(alignment: .leading) {
          Capsule().fill(Color.white.opacity(0.2))
          Capsule().fill(Hearth.gold).frame(width: 80 * min(1, game.progress))
        }
        .frame(width: 80, height: 5)
      }
    }
  }
  private var pauseMenu: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        Text("Paused").font(Hearth.pixel(36)).foregroundStyle(Hearth.gold)
        Text("\(session.roomName) · \(session.code ?? "")").font(Hearth.type(14))
          .foregroundStyle(Hearth.muted)
          .padding(.bottom, 6)
        Button("Resume") { game.paused = false }
          .buttonStyle(HearthButton(.primary, wide: true))
          .keyboardShortcut(.defaultAction)
        Button {
          options = true
        } label: {
          Label("Settings", systemImage: "gearshape")
        }
        .buttonStyle(HearthButton(wide: true))
        if session.isHost {
          Text("Host").font(Hearth.type(13, .medium)).foregroundStyle(Hearth.muted)
            .padding(.top, 8)
          HStack(spacing: 8) {
            Button {
              setTime(1000)
            } label: {
              Label("Set dawn", systemImage: "sunrise.fill")
            }
            Button {
              setTime(14000)
            } label: {
              Label("Set night", systemImage: "moon.fill")
            }
          }
          .buttonStyle(HearthButton(compact: true, wide: true))
          Button("End game for everyone") { session.send(.endMatch) }
            .buttonStyle(HearthButton(.danger, wide: true))
        }
        Rectangle().fill(Hearth.line).frame(height: 1).padding(.vertical, 4)
        Button {
          session.leave()
        } label: {
          Label("Leave world", systemImage: "rectangle.portrait.and.arrow.right")
        }
        .buttonStyle(HearthButton(.quiet, wide: true))
      }
      .frame(width: 320)
      .panel(padding: 24)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 24)
    }
    .scrollBounceBehavior(.basedOnSize)
  }
  private func setTime(_ time: Int) {
    var m = ClientMessage(.setTime)
    m.time = time
    session.send(m)
  }
  private var topBar: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top) {
        vitals
        Spacer()
        controls
      }
      VStack(alignment: .leading) {
        HStack {
          vitals
          Spacer()
        }
        controls
      }
    }
  }
  private var vitals: some View {
    VStack(alignment: .leading, spacing: 6) {
      VStack(alignment: .leading, spacing: 5) {
        VitalBar(
          symbol: "heart.fill", value: session.hp, maximum: 20, tint: Hearth.danger, label: "Health"
        )
        VitalBar(
          symbol: "fork.knife", value: session.food, maximum: 20, tint: Hearth.gold, label: "Food")
        if session.air < 300 {
          VitalBar(
            symbol: "drop.fill", value: session.air / 20, maximum: 15, tint: Hearth.teal,
            label: "Air")
        }
      }
      .padding(.horizontal, 10).padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Hearth.ink.opacity(0.65)))
      HStack(spacing: 6) {
        if session.endTick > session.tick {
          let seconds = max(0, (session.endTick - session.tick) / 20)
          Chip(
            String(format: "%d:%02d", seconds / 60, seconds % 60), symbol: "timer",
            tint: Hearth.cream)
        }
        Chip("\(session.score)", symbol: "star.fill", tint: Hearth.gold)
      }
      if preferences.showFPS {
        Text("\(game.fps) FPS · \(game.positionLabel)").font(Hearth.mono(11))
          .padding(.horizontal, 6).padding(.vertical, 2)
          .background(Hearth.ink.opacity(0.6))
      }
    }
  }
  private var controls: some View {
    HStack(spacing: 6) {
      IconButton("backpack.fill", "Inventory") { session.containerKind = "inventory" }
      IconButton("bubble.left.fill", "Chat") {
        game.chatting.toggle()
        game.resetInput()
      }
      IconButton("pause.fill", "Pause") {
        game.paused.toggle()
        game.resetInput()
      }
    }
  }
  private var hotbar: some View {
    VStack(spacing: 6) {
      let held = session.inventory[session.selected]
      Text(held.isEmpty ? " " : Registry.shared.item(held.id).name)
        .font(Hearth.type(13, .semibold)).shadow(color: .black, radius: 2)
        .accessibilityHidden(true)
      GeometryReader { proxy in
        let size = min(52.0, (proxy.size.width - 40) / 9)
        HStack(spacing: 3) {
          ForEach(0..<9) { index in
            SlotView(
              stack: session.inventory[index], selected: session.selected == index, size: size
            ) { session.select(index) }
          }
        }
        .padding(4)
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Hearth.ink.opacity(0.6))
        )
        .frame(maxWidth: .infinity)
      }
      .frame(height: 60)
    }
  }
  private var particleLayer: some View {
    TimelineView(.animation) { _ in
      Canvas { context, size in
        let f = game.forward
        let r = SIMD3<Double>(cos(game.yaw), 0, -sin(game.yaw))
        let up = simd_cross(f, r)
        let factor = Double(size.height) / (2 * tan(preferences.fov * .pi / 360))
        for player in game.renderPlayers where player.id != session.playerID {
          let delta = SIMD3(player.x ?? 0, (player.y ?? 0) + 2.2, player.z ?? 0) - game.camera
          let depth = simd_dot(delta, f)
          guard depth > 0.1 && depth < 40 else { continue }
          let x = Double(size.width) / 2 + simd_dot(delta, r) * factor / depth
          let y = Double(size.height) / 2 - simd_dot(delta, up) * factor / depth
          let name = session.players.first { $0.id == player.id }?.name ?? "Wanderer"
          context.draw(
            Text(name).font(Hearth.type(12)).foregroundColor(Hearth.cream), at: CGPoint(x: x, y: y))
        }
        for particle in reduceMotion ? [] : game.particles {
          let delta = particle.position - game.camera
          let depth = simd_dot(delta, f)
          guard depth > 0.1 else { continue }
          let x = Double(size.width) / 2 + simd_dot(delta, r) * factor / depth
          let y = Double(size.height) / 2 - simd_dot(delta, up) * factor / depth
          let width = max(1, min(12, factor * 0.04 / depth))
          context.fill(
            Path(CGRect(x: x, y: y, width: width, height: width)),
            with: .color(Hearth.gold.opacity(particle.life)))
        }
      }
    }
  }
}

struct TouchControls: View {
  @ObservedObject var game: Game
  @State private var drag = CGSize.zero
  var body: some View {
    HStack(alignment: .bottom) {
      ZStack {
        Circle().fill(Hearth.ink.opacity(0.5)).frame(width: 108, height: 108)
        Circle().strokeBorder(Hearth.cream.opacity(0.25), lineWidth: 2).frame(
          width: 108, height: 108)
        Circle().fill(Hearth.cream.opacity(drag == .zero ? 0.55 : 0.8)).frame(width: 44, height: 44)
          .shadow(color: .black.opacity(0.3), radius: 4)
          .offset(drag)
      }
      .accessibilityLabel("Movement joystick")
      .gesture(
        DragGesture(minimumDistance: 0).onChanged {
          let x = $0.location.x - 54
          let y = $0.location.y - 54
          let length = max(38, hypot(x, y))
          drag = CGSize(width: x / length * 38, height: y / length * 38)
          game.stick = SIMD2(drag.width / 38, -drag.height / 38)
        }.onEnded { _ in
          drag = .zero
          game.stick = .zero
        })
      Spacer(minLength: 10)
      VStack(alignment: .trailing, spacing: 8) {
        HStack(spacing: 8) {
          if game.session.mode == "creative" {
            Button {
              game.toggleFly()
            } label: {
              TouchButtonFace(title: "Fly", symbol: "airplane", active: game.body.flying)
            }
            .buttonStyle(.plain)
          }
          HoldControl("Sneak", symbol: "arrow.down.to.line") { game.sneak = $0 }
          HoldControl("Sprint", symbol: "hare.fill") { game.sprint = $0 }
        }
        HStack(spacing: 8) {
          HoldControl("Break", symbol: "hammer.fill") {
            if $0 { game.startBreak() } else { game.breaking = false }
          }
          Button {
            game.use()
          } label: {
            TouchButtonFace(title: "Place", symbol: "cube.fill")
          }
          .buttonStyle(.plain)
          HoldControl("Jump", symbol: "arrow.up", size: 72) { game.jump = $0 }
        }
      }
    }
  }
}

struct TouchButtonFace: View {
  let title: String
  let symbol: String
  var size: CGFloat = 60
  var active = false
  var body: some View {
    VStack(spacing: 2) {
      Image(systemName: symbol).font(.system(size: size * 0.3, weight: .bold))
      Text(title).font(Hearth.type(11, .semibold))
    }
    .frame(width: size, height: size)
    .foregroundStyle(active ? Hearth.ink : Hearth.cream)
    .background(Circle().fill(active ? Hearth.gold : Hearth.ink.opacity(0.6)))
    .overlay(Circle().strokeBorder(Hearth.cream.opacity(active ? 0 : 0.22), lineWidth: 1.5))
    .contentShape(Circle())
  }
}

struct HoldControl: View {
  let title: String
  let symbol: String
  let size: CGFloat
  let action: (Bool) -> Void
  @State private var held = false
  init(_ title: String, symbol: String, size: CGFloat = 60, action: @escaping (Bool) -> Void) {
    self.title = title
    self.symbol = symbol
    self.size = size
    self.action = action
  }
  var body: some View {
    TouchButtonFace(title: title, symbol: symbol, size: size, active: held)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(title)
      .accessibilityAddTraits(.isButton).accessibilityAction {
        action(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { action(false) }
      }
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { _ in
          held = true
          action(true)
        }.onEnded { _ in
          held = false
          action(false)
        }
      )
      .onDisappear {
        held = false
        action(false)
      }
  }
}

enum ItemArt {
  static let image: CGImage? = {
    guard let url = Bundle.main.url(forResource: "atlas", withExtension: "rgba"),
      let data = try? Data(contentsOf: url), let provider = CGDataProvider(data: data as CFData)
    else { return nil }
    return CGImage(
      width: 256, height: 80, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 1024,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
  }()
  static func tile(_ id: Int) -> CGImage? {
    let tile = Registry.shared.item(id).tile
    return image?.cropping(
      to: CGRect(x: (tile % 16) * 16, y: (tile / 16) * 16, width: 16, height: 16))
  }
}

struct SlotView: View {
  let stack: ItemStack
  var selected = false
  var size: CGFloat = 50
  var dimmed = false
  var action: () -> Void
  @State private var hovering = false
  var body: some View {
    Button(action: action) {
      ZStack(alignment: .bottomTrailing) {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(selected ? Hearth.gold.opacity(0.22) : Hearth.navy.opacity(hovering ? 1 : 0.85))
        if !stack.isEmpty, let tile = ItemArt.tile(stack.id) {
          Image(decorative: tile, scale: 1).resizable().interpolation(.none)
            .padding(size * 0.14)
            .opacity(dimmed ? 0.45 : 1)
          if stack.count > 1 {
            Text("\(stack.count)").font(Hearth.type(max(10, size * 0.24), .bold)).monospacedDigit()
              .padding(.horizontal, 4).padding(.bottom, 2)
              .shadow(color: .black, radius: 1.5)
          }
        }
      }
      .frame(width: size, height: size)
      .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(
          selected ? Hearth.gold : Color.white.opacity(hovering ? 0.25 : 0.08),
          lineWidth: selected ? 2.5 : 1)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    .accessibilityLabel(
      stack.isEmpty ? "Empty slot" : "\(Registry.shared.item(stack.id).name), \(stack.count)"
    )
    .accessibilityAddTraits(selected ? .isSelected : [])
    .help(stack.isEmpty ? "Empty" : Registry.shared.item(stack.id).name)
  }
}

struct InventoryScreen: View {
  @ObservedObject var session: Session
  @State private var picked: Int?
  @State private var recipe: String?
  @State private var grid = [Int](repeating: 0, count: 9)
  @State private var craftCount = 1
  @State private var search = ""
  @State private var transferCount = 0
  private var n: Int { session.containerKind == "workbench" ? 3 : 2 }
  private var title: String {
    switch session.containerKind {
    case "workbench": "Workbench"
    case "chest": "Chest"
    case "kiln": "Kiln"
    default: "Inventory"
    }
  }
  var body: some View {
    GeometryReader { proxy in
      let slot = min(50, (proxy.size.width - 100) / 9)
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          HStack(alignment: .center) {
            Text(title).font(Hearth.pixel(30)).foregroundStyle(Hearth.gold)
            Spacer()
            IconButton("xmark", "Close") { session.closeInventory() }
              .keyboardShortcut(.cancelAction)
          }
          if session.containerKind == "chest" {
            chestPanel(slot)
          } else if session.containerKind == "kiln" {
            kilnPanel
          } else {
            craftingPanel
          }
          backpack(slot)
          if session.mode == "creative" { creativePanel(slot) }
        }
        .panel(padding: 20)
        .padding(12)
      }
    }
    .frame(maxWidth: 820, maxHeight: 760)
  }
  private func backpack(_ slot: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      CardHeader(title: "Backpack") {
        Text(hint).font(Hearth.type(13)).foregroundStyle(Hearth.muted).lineLimit(2)
          .multilineTextAlignment(.trailing)
      }
      slotGrid(9..<36, slot)
      Text("Hotbar").font(Hearth.type(12, .medium)).foregroundStyle(Hearth.muted).padding(.top, 2)
      slotGrid(0..<9, slot)
      if let picked { pickedBar(picked) }
    }
  }
  private var hint: String {
    guard let picked else { return "Select a slot to move or drop it." }
    let item = session.inventory[picked]
    return item.isEmpty
      ? "Select a filled slot to move into it."
      : "Select another slot to move \(Registry.shared.item(item.id).name)."
  }
  private func slotGrid(_ range: Range<Int>, _ slot: CGFloat) -> some View {
    HStack(spacing: 4) {
      ForEach(range, id: \.self) { index in
        SlotView(stack: session.inventory[index], selected: picked == index, size: slot) {
          tap(index)
        }
      }
    }
  }
  private func tap(_ index: Int) {
    if let from = picked, from != index {
      var m = ClientMessage(.moveItem)
      m.from = from
      m.to = index
      m.count = transferCount == 0 ? nil : transferCount
      session.send(m)
      picked = nil
    } else {
      picked = picked == index ? nil : index
    }
  }
  private func pickedBar(_ picked: Int) -> some View {
    let stack = session.inventory[picked]
    return ViewThatFits(in: .horizontal) {
      HStack(spacing: 10) { pickedContent(picked, stack) }
      VStack(alignment: .leading, spacing: 10) { pickedContent(picked, stack) }
    }
    .padding(12)
    .background(RoundedRectangle(cornerRadius: 12).fill(Hearth.gold.opacity(0.08)))
    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Hearth.gold.opacity(0.3)))
  }
  @ViewBuilder private func pickedContent(_ picked: Int, _ stack: ItemStack) -> some View {
    Text(stack.isEmpty ? "Empty slot" : Registry.shared.item(stack.id).name)
      .font(Hearth.type(15, .semibold))
    Stepper(
      transferCount == 0 ? "Move all" : "Move \(transferCount)", value: $transferCount, in: 0...64
    )
    .font(Hearth.type(14)).fixedSize()
    Spacer(minLength: 0)
    HStack(spacing: 8) {
      Button("Drop 1") {
        var m = ClientMessage(.dropItem)
        m.slot = picked
        m.count = 1
        session.send(m)
      }
      Button("Drop all") {
        var m = ClientMessage(.dropItem)
        m.slot = picked
        m.count = stack.count
        session.send(m)
      }
      Button("Deselect") { self.picked = nil }.buttonStyle(HearthButton(.quiet, compact: true))
    }
    .buttonStyle(HearthButton(compact: true))
    .disabled(stack.isEmpty)
  }
  private func chestPanel(_ slot: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      CardHeader(
        title: "Storage",
        detail: picked == nil ? "Tap a stack to take it" : "Tap a slot to store your selection")
      LazyVGrid(columns: Array(repeating: GridItem(.fixed(slot), spacing: 4), count: 9), spacing: 4)
      {
        ForEach(session.chest.indices, id: \.self) { index in
          SlotView(stack: session.chest[index], size: slot) {
            var message = ClientMessage(.chestPut)
            message.toChest = picked != nil
            message.slot = picked ?? -1
            message.cslot = index
            message.count = transferCount == 0 ? nil : transferCount
            session.send(message)
            picked = nil
          }
        }
      }
    }
  }
  private var kilnPanel: some View {
    VStack(alignment: .leading, spacing: 14) {
      CardHeader(
        title: "Smelting",
        detail: picked == nil ? "Tap a slot to take it back" : "Tap Input or Fuel to add")
      HStack(alignment: .center, spacing: 16) {
        VStack(spacing: 10) {
          kilnSlot("input", "Input", session.kiln?.input ?? .empty)
          kilnSlot("fuel", "Fuel", session.kiln?.fuel ?? .empty)
        }
        VStack(spacing: 10) {
          Image(systemName: "arrow.right").font(.system(size: 22, weight: .bold))
          Image(systemName: "flame.fill").foregroundStyle(Hearth.gold)
            .opacity((session.kiln?.burnLeft ?? 0) > 0 ? 1 : 0.3)
        }
        .foregroundStyle(Hearth.muted)
        kilnSlot("output", "Output", session.kiln?.output ?? .empty)
        if let kiln = session.kiln {
          VStack(alignment: .leading, spacing: 10) {
            ProgressView(
              "Progress", value: Double(kiln.cook), total: Double(max(1, kiln.cookTotal))
            )
            .tint(Hearth.gold)
            ProgressView(
              "Fuel", value: Double(kiln.burnLeft), total: Double(max(1, kiln.burnTotal))
            )
            .tint(Hearth.danger)
          }
          .font(Hearth.type(13)).frame(maxWidth: 220)
        }
      }
    }
  }
  private func kilnSlot(_ key: String, _ label: String, _ stack: ItemStack) -> some View {
    VStack(spacing: 4) {
      SlotView(stack: stack, size: 52) {
        var message = ClientMessage(.kilnPut)
        message.kslot = key
        message.slot = picked ?? -1
        message.count = transferCount == 0 ? nil : transferCount
        session.send(message)
        picked = nil
      }
      Text(label).font(Hearth.type(12)).foregroundStyle(Hearth.muted)
    }
  }
  private var selectedRecipe: Recipe? { Registry.shared.recipes.first { $0.id == recipe } }
  private var craftingPanel: some View {
    VStack(alignment: .leading, spacing: 14) {
      CardHeader(title: "Crafting", detail: n == 3 ? "3 × 3" : "2 × 2")
      HStack(alignment: .center, spacing: 16) {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(46), spacing: 4), count: n), spacing: 4)
        {
          ForEach(0..<(n * n), id: \.self) { index in
            SlotView(stack: ItemStack(id: grid[index], count: grid[index] == 0 ? 0 : 1), size: 46) {
              grid[index] = picked.map { session.inventory[$0].id } ?? 0
              recipe = nil
            }
          }
        }
        .frame(width: CGFloat(n * 50))
        Image(systemName: "arrow.right").font(.system(size: 20, weight: .bold))
          .foregroundStyle(Hearth.muted)
        SlotView(
          stack: selectedRecipe?.result ?? .empty, size: 56, dimmed: selectedRecipe == nil
        ) {}
        .disabled(true)
        VStack(alignment: .leading, spacing: 8) {
          Stepper("× \(craftCount)", value: $craftCount, in: 1...64).font(Hearth.type(14))
            .fixedSize()
          HStack(spacing: 8) {
            Button("Craft") {
              var message = ClientMessage(.craft)
              message.grid = Array(grid.prefix(n * n))
              message.n = n
              message.count = craftCount
              session.send(message)
            }
            .buttonStyle(HearthButton(.primary, compact: true))
            .disabled(grid.prefix(n * n).allSatisfy { $0 == 0 })
            Button("Clear") {
              grid = Array(repeating: 0, count: 9)
              recipe = nil
            }
            .buttonStyle(HearthButton(.quiet, compact: true))
          }
        }
      }
      DisclosureGroup("Recipes") {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 6)], spacing: 6) {
          ForEach(Registry.shared.recipes) { r in recipeRow(r) }
        }
        .padding(.top, 8)
      }
      .font(Hearth.type(15, .semibold))
      .tint(Hearth.muted)
    }
  }
  private func recipeRow(_ r: Recipe) -> some View {
    let locked = r.gridNeeded > n
    let ready = session.mode == "creative" || r.affordable(in: session.inventory)
    return Button {
      grid = r.grid(n) + Array(repeating: 0, count: 9 - n * n)
      recipe = r.id
    } label: {
      HStack(spacing: 10) {
        if let image = ItemArt.tile(r.result.id) {
          Image(decorative: image, scale: 1).resizable().interpolation(.none)
            .frame(width: 26, height: 26)
        }
        VStack(alignment: .leading, spacing: 1) {
          Text(r.result.count > 1 ? "\(r.name) × \(r.result.count)" : r.name)
            .font(Hearth.type(14, .medium)).lineLimit(1)
          Text(locked ? "Needs workbench" : ready ? "Ready to craft" : "Missing ingredients")
            .font(Hearth.type(11))
            .foregroundStyle(locked ? Hearth.muted : ready ? Hearth.teal : Hearth.muted)
        }
        Spacer(minLength: 0)
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(recipe == r.id ? Hearth.gold.opacity(0.18) : Hearth.navy.opacity(0.6))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(recipe == r.id ? Hearth.gold.opacity(0.6) : .clear)
      )
      .contentShape(Rectangle())
      .opacity(locked ? 0.5 : 1)
    }
    .buttonStyle(.plain)
    .disabled(locked)
  }
  private func creativePanel(_ slot: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      CardHeader(title: "All items", detail: "Tap to add a full stack")
      TextField("", text: $search, prompt: prompt("Search blocks and items")).hearthField()
      LazyVGrid(columns: [GridItem(.adaptive(minimum: slot), spacing: 4)], spacing: 4) {
        ForEach(
          Registry.shared.items.values.filter {
            $0.id > 0 && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
          }.sorted { $0.id < $1.id }
        ) { item in
          SlotView(stack: ItemStack(id: item.id, count: item.maxStack), size: slot) {
            var message = ClientMessage(.give)
            message.id = item.id
            message.count = item.maxStack
            message.slot = picked ?? session.selected
            session.send(message)
          }
        }
      }
    }
  }
}

struct ResultsScreen: View {
  @ObservedObject var session: Session
  private var ranking: [Player] {
    session.results.isEmpty
      ? session.players.sorted { ($0.score ?? 0) > ($1.score ?? 0) } : session.results
  }
  private var myRank: Int? { ranking.firstIndex { $0.id == session.playerID }.map { $0 + 1 } }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Game over · \(session.roomName)").font(Hearth.type(14, .medium))
            .foregroundStyle(Hearth.muted)
          Text(myRank.map { $0 == 1 ? "You won" : "You placed \(ordinal($0))" } ?? "Results")
            .font(Hearth.pixel(40)).foregroundStyle(Hearth.gold)
            .accessibilityAddTraits(.isHeader)
        }
        VStack(spacing: 8) {
          ForEach(Array(ranking.enumerated()), id: \.element.id) { index, player in
            resultRow(index + 1, player)
          }
        }
        ChatPanel(session: session).frame(height: 240)
        if !session.worldHash.isEmpty {
          DisclosureGroup("Verification") {
            VStack(alignment: .leading, spacing: 4) {
              LabeledContent("World", value: session.worldHash)
              LabeledContent("Chat", value: session.chatHash)
            }
            .font(Hearth.mono(12)).textSelection(.enabled).padding(.top, 6)
          }
          .font(Hearth.type(14, .medium)).tint(Hearth.muted).foregroundStyle(Hearth.muted)
        }
        HStack(spacing: 10) {
          if session.isHost {
            Button("Back to lobby") { session.send(.backToLobby) }
              .buttonStyle(HearthButton(.primary))
              .keyboardShortcut(.defaultAction)
          } else {
            Text("Waiting for the host to return to the lobby.")
              .font(Hearth.type(14)).foregroundStyle(Hearth.muted)
          }
          Spacer()
          Button("Leave world") { session.leave() }.buttonStyle(HearthButton(.quiet))
        }
      }
      .frame(maxWidth: 720)
      .panel(padding: 24)
      .padding(20)
      .frame(maxWidth: .infinity)
    }
  }
  private func ordinal(_ n: Int) -> String {
    switch n {
    case 2: "2nd"
    case 3: "3rd"
    default: "\(n)th"
    }
  }
  private func resultRow(_ rank: Int, _ player: Player) -> some View {
    let you = player.id == session.playerID
    let medal: Color =
      rank == 1
      ? Hearth.gold
      : rank == 2 ? Hearth.cream.opacity(0.8) : rank == 3 ? Color.orange : Hearth.muted
    return HStack(spacing: 12) {
      Text("\(rank)").font(Hearth.pixel(22)).foregroundStyle(rank <= 3 ? Hearth.ink : Hearth.cream)
        .frame(width: 36, height: 36)
        .background(RoundedRectangle(cornerRadius: 8).fill(rank <= 3 ? medal : Hearth.navy))
      Avatar(name: player.name ?? "Wanderer", bot: player.bot == true, size: 32)
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(player.name ?? "Wanderer").font(Hearth.type(16, .semibold)).lineLimit(1)
          if you { Chip("You", tint: Hearth.gold) }
        }
        HStack(spacing: 12) {
          stat("square.stack.3d.up.fill", player.placed, "built")
          stat("hammer.fill", player.broken, "mined")
          stat("wrench.and.screwdriver.fill", player.crafted, "crafted")
          stat("bolt.fill", player.kills, "defeated")
          stat("heart.slash.fill", player.deaths, "deaths")
        }
      }
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 0) {
        Text("\(player.score ?? 0)").font(Hearth.type(24, .bold)).monospacedDigit()
          .foregroundStyle(rank == 1 ? Hearth.gold : Hearth.cream)
        Text("points").font(Hearth.type(11)).foregroundStyle(Hearth.muted)
      }
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(you ? Hearth.gold.opacity(0.08) : Hearth.navy.opacity(0.5))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(you ? Hearth.gold.opacity(0.35) : .clear)
    )
    .accessibilityElement(children: .combine)
  }
  private func stat(_ symbol: String, _ value: Int?, _ label: String) -> some View {
    Label("\(value ?? 0)", systemImage: symbol).font(Hearth.type(12)).monospacedDigit()
      .foregroundStyle(Hearth.muted)
      .labelStyle(.titleAndIcon)
      .accessibilityLabel("\(value ?? 0) \(label)")
      .help(label.capitalized)
  }
}
