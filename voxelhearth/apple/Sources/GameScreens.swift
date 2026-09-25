import CoreGraphics
import HearthCore
import SwiftUI
import simd

struct ChatPanel: View {
  @ObservedObject var session: Session
  @State private var draft = ""
  @FocusState private var editing: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Campfire chat").font(Hearth.type(22))
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(Array(session.chat.enumerated()), id: \.offset) { index, line in
              Text(line.system ? line.text : "\(line.from): \(line.text)")
                .font(Hearth.type(14)).foregroundStyle(line.system ? Hearth.muted : Hearth.cream)
                .frame(maxWidth: .infinity, alignment: .leading).id(index)
            }
          }
        }.onChange(of: session.chat.count) { _, count in proxy.scrollTo(count - 1, anchor: .bottom)
        }
      }
      HStack {
        TextField("Message your party…", text: $draft).textFieldStyle(.roundedBorder)
          .foregroundStyle(Color.primary)
          .focused($editing).onSubmit(send).accessibilityIdentifier("chat-message")
        Button("Send", action: send).disabled(
          draft.trimmingCharacters(in: .whitespaces).isEmpty || !session.online)
      }
    }.panel()
  }
  private func send() {
    session.chatSend(draft)
    draft = ""
    editing = true
  }
}

struct SettingsScreen: View {
  @EnvironmentObject var preferences: Preferences
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      Form {
        Section("Controls") {
          Slider(value: $preferences.sensitivity, in: 0.2...3) { Text("Look sensitivity") }
          Text("Sensitivity \(preferences.sensitivity, specifier: "%.1f")")
          Slider(value: $preferences.fov, in: 50...110) { Text("Field of view") }
          Text("Field of view \(Int(preferences.fov))°")
          Toggle("Invert vertical look", isOn: $preferences.invertY)
          Toggle("Show touch controls", isOn: $preferences.touch)
        }
        Section("Presentation") {
          Picker("Graphics quality", selection: $preferences.quality) {
            Text("Low").tag(0)
            Text("Balanced").tag(1)
            Text("High").tag(2)
          }
          Picker("Menu tint", selection: $preferences.theme) {
            Text("System").tag("system")
            Text("Night").tag("dark")
            Text("Day").tag("light")
          }
          Toggle("Sound", isOn: $preferences.sound)
          Toggle("Haptics", isOn: $preferences.haptics)
          Toggle("Show FPS and coordinates", isOn: $preferences.showFPS)
        }
        Section("Desktop") {
          Text(
            "Click the world to capture the mouse. WASD moves; Space jumps; Shift sneaks; Control or Command sprints. Hold left mouse to dig, right mouse to use/place. 1–9 or scroll selects a slot. E inventory, T chat, Q drop, F creative flight, Esc pause/release."
          )
        }
        Section("iPhone & iPad") {
          Text(
            "Left joystick moves relative to your camera. Drag the world to look; hold still to dig. Use the Jump, Sneak, Sprint, Break and Place buttons. Pin the device in either orientation; all menus remain scrollable."
          )
        }
      }
      .formStyle(.grouped)
      .navigationTitle("Settings")
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
    .foregroundStyle(Color.primary)
    .tint(.accentColor)
    #if os(macOS)
      .frame(width: 560, height: 620)
    #endif
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
        ResultsScreen(session: session)
      } else {
        VStack(spacing: 8) {
          topBar
          Spacer()
          if !game.blocked {
            Text("+").font(.system(size: 26, weight: .light)).shadow(color: .black, radius: 2)
            Text(game.targetName).font(Hearth.type(13)).shadow(color: .black, radius: 2)
            if game.progress > 0 { ProgressView(value: game.progress).frame(width: 90) }
          }
          Spacer()
          if !game.blocked {
            if let line = session.chat.last {
              Text(line.system ? line.text : "\(line.from): \(line.text)")
                .font(Hearth.type(12)).lineLimit(2).shadow(color: .black, radius: 2)
                .allowsHitTesting(false)
            }
            #if os(iOS)
              if preferences.touch { TouchControls(game: game) }
            #endif
            hotbar
          }
        }.padding(10)
        if session.hp <= 0 {
          VStack(spacing: 18) {
            Text("Your hearth awaits").font(Hearth.pixel(36))
            Text("You fell, but the adventure continues.")
            Button("Respawn") { session.send(.respawn) }.buttonStyle(HearthButton(primary: true))
          }.panel()
        } else if session.containerKind != nil {
          InventoryScreen(session: session)
        } else if game.chatting {
          VStack {
            Button("Close Chat") { game.chatting = false }
            ChatPanel(session: session)
          }.padding().frame(maxWidth: 560, maxHeight: 400)
        } else if game.paused {
          ScrollView {
            VStack(spacing: 16) {
              Text("Take a breath").font(Hearth.pixel(36))
              Text("The world keeps turning while you pause.").foregroundStyle(Hearth.muted)
              Button("Resume") { game.paused = false }.buttonStyle(HearthButton(primary: true))
              Button("Settings") { options = true }
              if session.isHost {
                HStack {
                  Button("Dawn") { setTime(1000) }
                  Button("Night") { setTime(14000) }
                }
                Button("Finish Session") { session.send(.endMatch) }
              }
              Button("Leave World") { session.leave() }
            }.frame(maxWidth: .infinity).panel()
          }.frame(maxWidth: 460, maxHeight: 440)
        }
        if !session.online {
          VStack(spacing: 16) {
            Text(session.connection.rawValue.capitalized).font(Hearth.type(24))
            Text("Your identity and world will resume when the server is reachable.")
            Button("Reconnect now") { session.connect() }
          }.panel().frame(maxWidth: 420)
        }
        if let toast = session.toast {
          VStack {
            Spacer()
            Button(toast) { session.toast = nil }.padding(.bottom, 95)
          }
          .task(id: toast) {
            try? await Task.sleep(for: .seconds(4))
            if session.toast == toast { session.toast = nil }
          }
        }
      }
    }
    .onChange(of: session.containerKind) { _, _ in game.resetInput() }
    .onChange(of: session.phase) { _, _ in
      game.resetInput()
      game.paused = false
      game.chatting = false
    }
  }
  private func setTime(_ time: Int) {
    var m = ClientMessage(.setTime)
    m.time = time
    session.send(m)
  }
  private var topBar: some View {
    ViewThatFits(in: .horizontal) {
      HStack {
        vitals
        Spacer()
        controls
      }
      VStack {
        HStack {
          vitals
          Spacer()
        }
        controls
      }
    }
  }
  private var vitals: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 12) {
        Label("\(session.hp)/20", systemImage: "heart.fill").foregroundStyle(.red)
        Label("\(session.food)/20", systemImage: "leaf.fill").foregroundStyle(Hearth.gold)
        if session.air < 300 {
          Label("\(session.air / 20)", systemImage: "drop.fill").foregroundStyle(Hearth.teal)
        }
      }.font(Hearth.type(15)).padding(8).background(Hearth.ink.opacity(0.8)).clipShape(
        RoundedRectangle(cornerRadius: 6))
      if session.endTick > session.tick {
        Text("Time \(max(0, (session.endTick - session.tick) / 20))s • Score \(session.score)")
      }
      if preferences.showFPS {
        Text("\(game.fps) FPS • \(game.positionLabel)").font(.system(size: 11, design: .monospaced))
      }
    }
  }
  private var controls: some View {
    HStack(spacing: 6) {
      Button {
        session.containerKind = "inventory"
      } label: {
        Image(systemName: "backpack.fill")
      }.accessibilityLabel("Inventory")
      Button {
        game.chatting.toggle()
        game.resetInput()
      } label: {
        Image(systemName: "bubble.left.fill")
      }.accessibilityLabel("Chat")
      Button {
        game.paused.toggle()
        game.resetInput()
      } label: {
        Image(systemName: "pause.fill")
      }.accessibilityLabel("Pause")
    }
  }
  private var hotbar: some View {
    GeometryReader { proxy in
      let size = min(54.0, (proxy.size.width - 24) / 9)
      HStack(spacing: 3) {
        ForEach(0..<9) { index in
          SlotView(stack: session.inventory[index], selected: session.selected == index, size: size)
          { session.select(index) }
        }
      }.frame(maxWidth: .infinity)
    }.frame(height: 58)
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
        Circle().fill(Hearth.ink.opacity(0.65)).frame(width: 108, height: 108)
        Circle().stroke(Hearth.teal.opacity(0.5), lineWidth: 2).frame(width: 108, height: 108)
        Circle().fill(Hearth.cream.opacity(0.6)).frame(width: 40, height: 40).offset(drag)
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
      VStack(alignment: .trailing, spacing: 6) {
        HStack(spacing: 4) {
          HoldControl("Sneak") { game.sneak = $0 }
          HoldControl("Sprint") { game.sprint = $0 }
          if game.session.mode == "creative" { Button("Fly") { game.toggleFly() } }
        }
        HStack(spacing: 4) {
          HoldControl("Break") { if $0 { game.startBreak() } else { game.breaking = false } }
          Button("Place") { game.use() }
          HoldControl("Jump") { game.jump = $0 }
        }
      }.buttonStyle(HearthButton())
    }
  }
}

struct HoldControl: View {
  let title: String
  let action: (Bool) -> Void
  init(_ title: String, action: @escaping (Bool) -> Void) {
    self.title = title
    self.action = action
  }
  var body: some View {
    Text(title).font(Hearth.type(14)).padding(12).background(Hearth.ink.opacity(0.8)).clipShape(
      RoundedRectangle(cornerRadius: 8)
    )
    .accessibilityAddTraits(.isButton).accessibilityAction {
      action(true)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { action(false) }
    }
    .gesture(
      DragGesture(minimumDistance: 0).onChanged { _ in action(true) }.onEnded { _ in action(false) }
    )
    .onDisappear { action(false) }
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
  var action: () -> Void
  var body: some View {
    Button(action: action) {
      ZStack(alignment: .bottomTrailing) {
        Rectangle().fill(selected ? Hearth.gold.opacity(0.25) : Hearth.navy.opacity(0.9))
        if !stack.isEmpty, let tile = ItemArt.tile(stack.id) {
          Image(decorative: tile, scale: 1).resizable().interpolation(.none).padding(6)
          if stack.count > 1 {
            Text("\(stack.count)").font(.system(size: 12, weight: .bold, design: .monospaced))
              .padding(3).shadow(color: .black, radius: 2)
          }
        }
      }.frame(width: size, height: size)
        .overlay(
          Rectangle().stroke(
            selected ? Hearth.gold : Hearth.muted.opacity(0.3), lineWidth: selected ? 3 : 1))
    }.buttonStyle(.plain)
      .accessibilityLabel(
        stack.isEmpty ? "Empty slot" : "\(Registry.shared.item(stack.id).name), \(stack.count)"
      )
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
  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Text((session.containerKind ?? "inventory").capitalized).font(Hearth.pixel(30))
            Spacer()
            Button("Close") { session.closeInventory() }
          }
          Text(
            "Select an inventory slot, then another to move or merge. Select again to clear. Tap a crafting square to add its item."
          )
          .foregroundStyle(Hearth.muted).font(Hearth.type(13))
          LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 9), spacing: 3
          ) {
            ForEach(0..<36) { index in
              SlotView(
                stack: session.inventory[index], selected: picked == index,
                size: min(50, (proxy.size.width - 82) / 9)
              ) {
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
            }
          }
          if let picked {
            VStack(alignment: .leading) {
              Text(Registry.shared.item(session.inventory[picked].id).name)
              Stepper(
                transferCount == 0 ? "Transfer entire stack" : "Transfer \(transferCount)",
                value: $transferCount, in: 0...64)
              HStack {
                Button("Drop one") {
                  var m = ClientMessage(.dropItem)
                  m.slot = picked
                  m.count = 1
                  session.send(m)
                }
                Button("Drop stack") {
                  var m = ClientMessage(.dropItem)
                  m.slot = picked
                  m.count = session.inventory[picked].count
                  session.send(m)
                }
              }
            }
          }
          if session.containerKind == "chest" {
            chestPanel
          } else if session.containerKind == "kiln" {
            kilnPanel
          } else {
            craftingPanel
          }
          if session.mode == "creative" { creativePanel }
        }.panel().padding(12)
      }
    }.frame(maxWidth: 820, maxHeight: 720)
  }
  private var chestPanel: some View {
    VStack(alignment: .leading) {
      Text("Chest • tap to transfer \(picked == nil ? "to your inventory" : "the selected stack")")
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))]) {
        ForEach(session.chest.indices, id: \.self) { index in
          SlotView(stack: session.chest[index]) {
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
    VStack(alignment: .leading) {
      Text("Kiln • select inventory then input/fuel; without a selection, tap to take back")
      HStack {
        kilnSlot("input", session.kiln?.input ?? .empty)
        kilnSlot("fuel", session.kiln?.fuel ?? .empty)
        kilnSlot("output", session.kiln?.output ?? .empty)
      }
      if let kiln = session.kiln {
        ProgressView("Smelting", value: Double(kiln.cook), total: Double(max(1, kiln.cookTotal)))
        ProgressView("Fuel", value: Double(kiln.burnLeft), total: Double(max(1, kiln.burnTotal)))
      }
    }
  }
  private func kilnSlot(_ key: String, _ stack: ItemStack) -> some View {
    VStack {
      Text(key.capitalized)
      SlotView(stack: stack) {
        var message = ClientMessage(.kilnPut)
        message.kslot = key
        message.slot = picked ?? -1
        message.count = transferCount == 0 ? nil : transferCount
        session.send(message)
        picked = nil
      }
    }
  }
  private var craftingPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(n == 3 ? "Workbench · 3 × 3" : "Hand crafting · 2 × 2").font(Hearth.type(24))
      HStack {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: n)) {
          ForEach(0..<(n * n), id: \.self) { index in
            SlotView(stack: ItemStack(id: grid[index], count: grid[index] == 0 ? 0 : 1), size: 44) {
              grid[index] = picked.map { session.inventory[$0].id } ?? 0
              recipe = nil
            }
          }
        }.frame(width: CGFloat(n * 48))
        VStack(alignment: .leading) {
          Stepper("Craft \(craftCount)×", value: $craftCount, in: 1...64)
          Button("Craft") {
            var message = ClientMessage(.craft)
            message.grid = Array(grid.prefix(n * n))
            message.n = n
            message.count = craftCount
            session.send(message)
          }.buttonStyle(HearthButton(primary: true))
          Button("Clear grid") {
            grid = Array(repeating: 0, count: 9)
            recipe = nil
          }
        }
      }
      Text("Recipe book").font(Hearth.type(22))
      ForEach(Registry.shared.recipes) { r in
        Button {
          grid = r.grid(n) + Array(repeating: 0, count: 9 - n * n)
          recipe = r.id
        } label: {
          HStack {
            if let image = ItemArt.tile(r.result.id) {
              Image(decorative: image, scale: 1).resizable().interpolation(.none).frame(
                width: 28, height: 28)
            }
            Text("\(r.name) ×\(r.result.count)")
            Spacer()
            Text(
              r.gridNeeded > n
                ? "Needs workbench"
                : session.mode == "creative" || r.affordable(in: session.inventory)
                  ? "Available" : "Need ingredients"
            )
            .font(Hearth.type(12)).foregroundStyle(Hearth.muted)
          }
        }.disabled(r.gridNeeded > n).buttonStyle(HearthButton(primary: recipe == r.id))
      }
    }
  }
  private var creativePanel: some View {
    VStack(alignment: .leading) {
      Text("Creative palette").font(Hearth.type(24))
      TextField("Search blocks and items", text: $search).textFieldStyle(.roundedBorder)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))]) {
        ForEach(
          Registry.shared.items.values.filter {
            $0.id > 0 && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
          }.sorted { $0.id < $1.id }
        ) { item in
          SlotView(stack: ItemStack(id: item.id, count: item.maxStack)) {
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
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("A hearth to remember").font(Hearth.pixel(40)).foregroundStyle(Hearth.gold)
        Text(session.roomName).font(Hearth.type(24))
        ForEach(
          Array(
            (session.results.isEmpty
              ? session.players.sorted { ($0.score ?? 0) > ($1.score ?? 0) } : session.results)
              .enumerated()), id: \.element.id
        ) { index, player in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text("#\(index + 1)  \(player.name ?? "Wanderer")")
              Spacer()
              Text("\(player.score ?? 0) points").foregroundStyle(Hearth.gold)
            }.font(Hearth.type(22))
            Text(
              "Built \(player.placed ?? 0) • Mined \(player.broken ?? 0) • Crafted \(player.crafted ?? 0) • Kills \(player.kills ?? 0) • Deaths \(player.deaths ?? 0)"
            )
            .font(Hearth.type(13)).foregroundStyle(Hearth.muted)
          }
        }
        if !session.worldHash.isEmpty {
          Text("World \(session.worldHash) • Chat \(session.chatHash)").font(
            .system(size: 12, design: .monospaced)
          ).textSelection(.enabled)
        }
        ChatPanel(session: session).frame(height: 250)
        HStack {
          if session.isHost {
            Button("Back to Lobby") { session.send(.backToLobby) }.buttonStyle(
              HearthButton(primary: true))
          }
          Button("Leave World") { session.leave() }
        }
      }.panel().padding(20).frame(maxWidth: 820)
    }
  }
}
