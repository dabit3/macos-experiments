import SceneKit
import SwiftUI

@main
struct VoxelVanguardApp: App {
  var body: some Scene {
    WindowGroup {
      VanguardView()
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
  }
}

struct WorldView: UIViewRepresentable {
  let world: DungeonScene
  func makeUIView(context: Context) -> SCNView {
    let view = SCNView()
    view.scene = world.scene
    view.pointOfView = world.camera
    view.isPlaying = true
    view.rendersContinuously = true
    view.preferredFramesPerSecond = 60
    view.antialiasingMode = .multisampling4X
    view.backgroundColor = .black
    return view
  }
  func updateUIView(_ view: SCNView, context: Context) {}
}

let canvas = CGSize(width: 900, height: 420)

struct VanguardView: View {
  @StateObject private var game = GameClient()
  @State private var damageFlash = 0.0

  private var phase: String { game.state?.phase ?? "" }
  private var inMatch: Bool { game.state != nil && phase != "lobby" }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        WorldView(world: game.world).ignoresSafeArea()
        LinearGradient(
          colors: [.black.opacity(inMatch ? 0.55 : 0.7), .clear, .clear, .black.opacity(0.7)],
          startPoint: .top, endPoint: .bottom
        ).allowsHitTesting(false)
        if !inMatch {
          Palette.ink.opacity(0.35).allowsHitTesting(false)
        }
        RadialGradient(
          colors: [.clear, Palette.heart.opacity(0.75)], center: .center, startRadius: 120,
          endRadius: 520
        )
        .opacity(damageFlash).allowsHitTesting(false)
        ZStack {
          if game.state == nil {
            EntryView(game: game)
          } else if phase == "lobby" {
            LobbyView(game: game)
          } else {
            HUDView(game: game)
            if game.state?.paused == true || !game.connected { PauseView(game: game) }
            if ["victory", "defeat"].contains(phase) { ResultView(game: game) }
            if game.gearOpen { GearPickerView(game: game) }
            if game.menuOpen { MenuView(game: game) }
          }
        }
        .frame(width: canvas.width, height: canvas.height)
        .scaleEffect(min(geometry.size.width / canvas.width, geometry.size.height / canvas.height))
        .frame(width: geometry.size.width, height: geometry.size.height)
      }
      .animation(.easeOut(duration: 0.25), value: game.gearOpen)
      .animation(.easeOut(duration: 0.25), value: game.menuOpen)
      .onChange(of: game.damagePulse) {
        Haptics.heavy()
        damageFlash = 1
        withAnimation(.easeOut(duration: 0.6)) { damageFlash = 0 }
      }
    }
  }
}

// MARK: - Entry

struct EntryView: View {
  @ObservedObject var game: GameClient
  @State private var joining = false
  @State private var advanced = false

  private var busy: Bool { game.status.hasSuffix("…") && game.error.isEmpty }

  var body: some View {
    HStack(spacing: 48) {
      VStack(alignment: .leading, spacing: 10) {
        Eyebrow(text: "A COOPERATIVE DUNGEON EXPEDITION", size: 10)
        Text("VOXEL\nVANGUARD").font(Fonts.display(46)).lineSpacing(-8)
          .shadow(color: Palette.ink, radius: 0, x: 3, y: 4)
        RoundedRectangle(cornerRadius: 2).fill(Palette.gold).frame(width: 56, height: 4)
          .padding(.top, 4)
        Text(
          "Two heroes. Three seals. One ancient Warden.\nGather your party and restore the forest."
        )
        .font(Fonts.body(13)).foregroundStyle(.white.opacity(0.85)).lineSpacing(4)
        HStack(spacing: 8) {
          featurePill("network", "Real network co-op")
          featurePill("person.2.fill", "Guest play, no accounts")
        }.padding(.top, 14)
      }.frame(width: 390, alignment: .leading)

      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 0) {
          modeTab("CREATE ROOM", icon: "plus", selected: !joining) { joining = false }
          modeTab("JOIN ROOM", icon: "arrow.right.circle", selected: joining) { joining = true }
        }
        .padding(3).background(RoundedRectangle(cornerRadius: 10).fill(Palette.ink.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line))

        field("HERO NAME", text: $game.name, hint: "Aster")
        if joining {
          field("ROOM CODE", text: $game.room, hint: "GROVE", uppercase: true)
            .transition(.opacity)
        } else {
          Text("A fresh room code is created for you. Share it with your ally.")
            .font(Fonts.body(11)).foregroundStyle(Palette.muted).fixedSize(
              horizontal: false, vertical: true)
        }
        DisclosureGroup(isExpanded: $advanced) {
          field("SERVER ADDRESS", text: $game.address, hint: "ws://192.168.1.20:8791")
            .padding(.top, 6)
        } label: {
          HStack(spacing: 5) {
            Image(systemName: "server.rack")
            Text(advanced ? "SERVER" : "SERVER  ·  \(game.address)")
          }.font(Fonts.mono(9)).foregroundStyle(Palette.muted).lineLimit(1)
        }.tint(Palette.muted)

        Button {
          Haptics.tap()
          game.connect(create: !joining)
        } label: {
          HStack(spacing: 8) {
            if busy {
              ProgressView().tint(Palette.ink).scaleEffect(0.8)
            } else {
              Image(systemName: joining ? "arrow.right" : "flag.fill")
            }
            Text(joining ? "JOIN EXPEDITION" : "CREATE EXPEDITION")
          }
        }
        .buttonStyle(BlockButtonStyle(color: joining ? Palette.blue : Palette.gold))
        .disabled(busy || game.name.trimmingCharacters(in: .whitespaces).isEmpty)
        .accessibilityLabel(joining ? "Join room" : "Create room")

        HStack(spacing: 6) {
          Circle().fill(game.error.isEmpty ? Palette.green : Palette.ember).frame(
            width: 6, height: 6)
          Text(game.error.isEmpty ? game.status : game.error)
            .font(Fonts.mono(9)).foregroundStyle(game.error.isEmpty ? Palette.muted : Palette.ember)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(22).frame(width: 340)
      .blockPanel(stroke: Palette.gold.opacity(0.35), radius: 16)
    }
    .animation(.easeInOut(duration: 0.2), value: joining)
    .animation(.easeInOut(duration: 0.2), value: advanced)
    .onAppear { joining = !game.room.isEmpty }
  }

  private func featurePill(_ icon: String, _ text: String) -> some View {
    HStack(spacing: 5) {
      Image(systemName: icon).font(.system(size: 9, weight: .bold))
      Text(text.uppercased()).font(Fonts.eyebrow(8)).tracking(1)
    }
    .foregroundStyle(Palette.muted).padding(.horizontal, 9).frame(height: 24)
    .background(Capsule().fill(.white.opacity(0.06))).overlay(Capsule().stroke(Palette.line))
  }

  private func modeTab(
    _ title: String, icon: String, selected: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: icon)
        Text(title)
      }
      .font(Fonts.mono(10)).tracking(0.8)
      .foregroundStyle(selected ? Palette.ink : Palette.muted)
      .frame(maxWidth: .infinity).frame(height: 34)
      .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Palette.gold : .clear))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func field(_ title: String, text: Binding<String>, hint: String, uppercase: Bool = false)
    -> some View
  {
    VStack(alignment: .leading, spacing: 5) {
      Eyebrow(text: title, color: Palette.muted, size: 8)
      TextField(hint, text: text)
        .font(.system(size: 14, weight: .semibold, design: .monospaced))
        .textInputAutocapitalization(uppercase ? .characters : .never).autocorrectionDisabled()
        .padding(.horizontal, 12).frame(height: 40).background(.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.14)))
        .accessibilityLabel(title)
    }
  }
}

// MARK: - Lobby

struct LobbyView: View {
  @ObservedObject var game: GameClient
  @State private var copied = false

  private var players: [Hero] { game.state?.players ?? [] }
  private var readyCount: Int { players.filter(\.ready).count }

  var body: some View {
    VStack(spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Eyebrow(text: "THE HOLLOWWOOD  ·  EXPEDITION LOBBY")
          Text(players.count < 2 ? "Waiting for your ally" : "Your party is assembled")
            .font(Fonts.display(26))
        }
        Spacer()
        Button {
          UIPasteboard.general.string = game.room
          Haptics.tap()
          copied = true
          Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copied = false
          }
        } label: {
          HStack(spacing: 10) {
            VStack(alignment: .trailing, spacing: 1) {
              Eyebrow(text: "ROOM CODE", color: Palette.muted, size: 8)
              Text(game.room).font(.system(size: 26, weight: .black, design: .monospaced))
                .tracking(4)
            }
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(copied ? Palette.green : Palette.muted).frame(width: 20)
          }
          .padding(.horizontal, 14).padding(.vertical, 8)
          .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.4)))
          .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(Palette.gold.opacity(0.5), lineWidth: 1.5))
        }
        .buttonStyle(.plain).accessibilityLabel("Copy room code \(game.room)")
      }

      HStack(spacing: 14) {
        ForEach(0..<2) { slot in
          slotCard(slot, hero: players.first { $0.slot == slot })
        }
      }

      HStack(spacing: 18) {
        tip("dpad.fill", "Joystick to move")
        tip("bolt.shield.fill", "Strike, shoot & dodge")
        tip("heart.circle.fill", "Hold revive beside a fallen hero")
        tip("shippingbox.fill", "Claim gear cards from caches")
      }

      HStack(spacing: 12) {
        Button {
          Haptics.tap()
          game.ready()
        } label: {
          HStack(spacing: 8) {
            Image(systemName: game.me?.ready == true ? "xmark" : "play.fill")
            Text(game.me?.ready == true ? "CANCEL READY" : "READY FOR EXPEDITION")
          }
        }
        .buttonStyle(BlockButtonStyle(color: Palette.gold, prominent: game.me?.ready != true))
        .frame(width: 300)
        Text("\(readyCount) / 2 READY").font(Fonts.mono(10)).foregroundStyle(Palette.muted)
        Spacer()
        Button("LEAVE ROOM") { game.leave() }.buttonStyle(QuietButtonStyle())
      }
      if game.automation { DriverBanner(step: game.driverStep) }
    }
    .padding(24).frame(width: 640)
    .blockPanel(radius: 16)
  }

  private func slotCard(_ slot: Int, hero: Hero?) -> some View {
    let color = Palette.slot(slot)
    return HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 8).fill(color.opacity(hero == nil ? 0.15 : 0.9))
        Image(systemName: slot == 0 ? "shield.lefthalf.filled" : "arrow.up.right")
          .font(.system(size: 20, weight: .black))
          .foregroundStyle(hero == nil ? color.opacity(0.6) : Palette.ink)
      }.frame(width: 44, height: 44)
      VStack(alignment: .leading, spacing: 3) {
        Eyebrow(
          text: "PLAYER \(slot + 1)\(hero?.id == game.identity ? "  ·  YOU" : "")", color: color,
          size: 8)
        Text(hero?.name ?? "Open seat").font(Fonts.label(16))
          .foregroundStyle(hero == nil ? Palette.muted : .white)
        Text(hero == nil ? "Share the room code" : hero?.ready == true ? "Ready" : "Not ready yet")
          .font(Fonts.body(11)).foregroundStyle(hero?.ready == true ? Palette.green : Palette.muted)
      }
      Spacer()
      if let hero {
        Image(systemName: hero.ready ? "checkmark.circle.fill" : "circle.dashed")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(hero.ready ? Palette.green : Palette.muted.opacity(0.6))
      } else {
        ProgressView().tint(Palette.muted)
      }
    }
    .padding(12).frame(width: 289, height: 70)
    .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(hero == nil ? 0.2 : 0.4)))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(
          hero == nil ? Palette.line : color.opacity(0.5),
          style: StrokeStyle(lineWidth: 1.5, dash: hero == nil ? [5, 4] : []))
    )
  }

  private func tip(_ icon: String, _ text: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon).foregroundStyle(Palette.gold)
      Text(text).foregroundStyle(.white.opacity(0.8))
    }.font(Fonts.body(10))
  }
}

struct DriverBanner: View {
  let step: String
  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "cpu").font(.system(size: 9, weight: .bold))
      Text("AUTOMATED INPUT  •  \(step)").font(Fonts.eyebrow(8)).tracking(1)
    }
    .foregroundStyle(Palette.gold).padding(.horizontal, 12).frame(height: 24)
    .background(Capsule().fill(Palette.ink.opacity(0.9)))
    .overlay(Capsule().stroke(Palette.gold.opacity(0.4)))
    .allowsHitTesting(false)
  }
}

// MARK: - HUD

struct HUDView: View {
  @ObservedObject var game: GameClient

  private var state: Snapshot? { game.state }
  private var tick: Int { state?.tick ?? 0 }
  private var stageName: String {
    ["MOSSGATE", "SUNDERED CRYPT", "WARDEN'S COURT"][min(2, max(0, (state?.stage ?? 1) - 1))]
  }

  var body: some View {
    ZStack {
      VStack(spacing: 0) {
        HStack(alignment: .top, spacing: 10) {
          if let me = game.me { HeroPanel(hero: me, local: true) }
          Spacer(minLength: 0)
          objective
          Spacer(minLength: 0)
          if let ally = game.partner {
            HeroPanel(hero: ally, local: false)
          } else {
            allyPlaceholder
          }
          menuButton
        }
        if let notice = game.notice { NoticeToast(notice: notice).padding(.top, 10) }
        Spacer()
        HStack(alignment: .bottom, spacing: 14) {
          VStack(spacing: 6) {
            Joystick { game.movement($0, $1) }
            Eyebrow(text: "MOVE", color: Palette.muted, size: 8)
          }
          Spacer(minLength: 0)
          loadout
          Spacer(minLength: 0)
          actions
        }
      }
      .padding(.horizontal, 22).padding(.vertical, 14)
      .animation(.spring(duration: 0.35), value: game.notice)
      if let me = game.me, me.down { downOverlay(me) }
      if game.automation {
        VStack {
          Spacer()
          DriverBanner(step: game.driverStep)
          Spacer().frame(height: 138)
        }
      }
    }
  }

  private var objective: some View {
    VStack(spacing: 6) {
      HStack(spacing: 8) {
        ForEach(1...3, id: \.self) { stage in
          let complete = (state?.completedStages ?? 0) >= stage
          let current = (state?.stage ?? 1) == stage && !complete
          Image(systemName: complete ? "diamond.fill" : "diamond")
            .font(.system(size: current ? 11 : 9, weight: .bold))
            .foregroundStyle(complete || current ? Palette.gold : Palette.muted.opacity(0.5))
        }
        Eyebrow(text: stageName, size: 9)
      }
      Text(state?.objective ?? "").font(Fonts.label(12)).lineLimit(1)
      if let boss = state?.enemies.first(where: { $0.kind == "boss" }) {
        VStack(spacing: 3) {
          HStack {
            Eyebrow(text: "THE HOLLOW WARDEN", color: Palette.ember, size: 8)
            Spacer()
            Text("\(boss.hp) / \(boss.maxHP)").font(Fonts.mono(8)).foregroundStyle(Palette.muted)
          }
          bar(Double(boss.hp) / Double(max(1, boss.maxHP)), colors: [Palette.ember, Palette.gold])
        }.padding(.top, 2)
      } else {
        StatChip(
          icon: "figure.fencing", value: "\(state?.enemies.count ?? 0) FOES REMAIN",
          color: (state?.enemies.isEmpty ?? true) ? Palette.green : Palette.muted)
      }
    }
    .padding(.horizontal, 16).padding(.vertical, 9).frame(width: 330)
    .blockPanel(opacity: 0.86, depth: 3)
  }

  private var allyPlaceholder: some View {
    HStack(spacing: 8) {
      ProgressView().tint(Palette.muted).scaleEffect(0.7)
      Text("Ally reconnecting…").font(Fonts.body(11)).foregroundStyle(Palette.muted)
    }
    .padding(.horizontal, 12).frame(width: 200, height: 46)
    .blockPanel(opacity: 0.7, depth: 3)
  }

  private var menuButton: some View {
    Button {
      Haptics.tap()
      game.menuOpen = true
    } label: {
      VStack(spacing: 3) {
        Image(systemName: "line.3.horizontal").font(.system(size: 15, weight: .bold))
        Circle().fill(game.connected ? Palette.green : Palette.ember).frame(width: 5, height: 5)
      }
      .foregroundStyle(.white).frame(width: 40, height: 46)
      .blockPanel(opacity: 0.86, radius: 10, depth: 3)
    }
    .buttonStyle(.plain).accessibilityLabel("Expedition menu")
  }

  private var loadout: some View {
    let me = game.me
    return VStack(spacing: 8) {
      if game.nearChest != nil {
        Button {
          Haptics.success()
          game.gearOpen = true
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "shippingbox.fill")
            Text("OPEN CACHE  ·  CLAIM A GEAR CARD")
          }
          .font(Fonts.mono(10)).tracking(0.8).foregroundStyle(Palette.ink)
          .padding(.horizontal, 16).frame(height: 34)
          .background(Capsule().fill(Palette.gold))
          .shadow(color: Palette.gold.opacity(0.6), radius: 12)
        }
        .buttonStyle(.plain).accessibilityLabel("Claim gear")
        .transition(.scale.combined(with: .opacity))
      }
      HStack(spacing: 6) {
        loadoutCard("MELEE", item: me?.weapon ?? "iron", glyph: "sword", color: Palette.ember)
        loadoutCard("RANGED", item: me?.bow ?? "oak", glyph: "bow", color: Palette.violet)
        loadoutCard("ARMOR", item: me?.armor ?? "scout", glyph: "armor", color: Palette.blue)
      }
    }
    .animation(.spring(duration: 0.3), value: game.nearChest?.id)
  }

  private func loadoutCard(_ label: String, item: String, glyph: String, color: Color) -> some View
  {
    Button {
      Haptics.tap()
      game.gearOpen = true
    } label: {
      HStack(spacing: 7) {
        GearGlyph(kind: glyph, color: color).frame(width: 24, height: 24)
        VStack(alignment: .leading, spacing: 1) {
          Eyebrow(text: label, color: color, size: 7)
          Text(GearInfo.title(item)).font(Fonts.label(10)).foregroundStyle(.white).lineLimit(1)
        }
      }
      .padding(.horizontal, 9).frame(width: 118, height: 40, alignment: .leading)
      .blockPanel(opacity: 0.86, stroke: color.opacity(0.45), radius: 9, depth: 3)
    }
    .buttonStyle(.plain).accessibilityLabel("Inspect \(label.lowercased()) card")
  }

  private var actions: some View {
    let me = game.me
    let potion = max(0, ((me?.potion ?? 0) - tick + 19) / 20)
    let dodge = max(0, ((me?.dodge ?? 0) - tick + 19) / 20)
    let charge = me?.charge ?? 0
    return VStack(alignment: .trailing, spacing: 8) {
      HStack(spacing: 8) {
        ActionButton(
          label: "HEAL", icon: "cross.vial.fill", color: Palette.green, size: .small,
          cooldown: potion, hint: "+48"
        ) {
          game.hold("heal", down: $0)
        } perform: {
          game.perform("heal")
        }
        ActionButton(
          label: "REVIVE", icon: "heart.circle.fill", color: Palette.blue, size: .small,
          highlighted: game.partner?.down == true
        ) {
          game.hold("revive", down: $0)
        } perform: {
          game.perform("revive")
        }
        ActionButton(
          label: charge == 100 ? "RELIC!" : "RELIC", icon: "bolt.fill", color: Palette.violet,
          size: .small, progress: Double(charge) / 100, highlighted: charge == 100
        ) {
          game.hold("artifact", down: $0)
        } perform: {
          game.perform("artifact")
        }
      }
      HStack(alignment: .bottom, spacing: 8) {
        ActionButton(
          label: "DODGE", icon: "wind", color: Palette.gold, size: .medium, cooldown: dodge
        ) {
          game.hold("dodge", down: $0)
        } perform: {
          game.perform("dodge")
        }
        ActionButton(label: "RANGED", icon: "scope", color: Palette.violet, size: .medium) {
          game.hold("ranged", down: $0)
        } perform: {
          game.perform("ranged")
        }
        ActionButton(label: "MELEE", icon: "bolt.shield.fill", color: Palette.ember, size: .large) {
          game.hold("melee", down: $0)
        } perform: {
          game.perform("melee")
        }
      }
    }
  }

  private func bar(_ ratio: Double, colors: [Color]) -> some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(.black.opacity(0.6))
        Capsule().fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
          .frame(width: geo.size.width * max(0, min(1, ratio)))
          .animation(.easeOut(duration: 0.3), value: ratio)
      }
    }.frame(height: 7)
  }

  private func downOverlay(_ me: Hero) -> some View {
    VStack(spacing: 10) {
      Image(systemName: "heart.slash.fill").font(.system(size: 26)).foregroundStyle(Palette.ember)
      Text("YOU ARE DOWN").font(Fonts.display(24)).foregroundStyle(Palette.ember)
      Text(
        game.partner == nil
          ? "Wait for an ally to rejoin and revive you."
          : "\(game.partner?.name ?? "Your ally") can hold REVIVE beside you."
      ).font(Fonts.body(12)).foregroundStyle(.white.opacity(0.85))
      VStack(spacing: 4) {
        bar(me.revive, colors: [Palette.green, Palette.blue]).frame(width: 220)
        Eyebrow(text: "REVIVAL \(Int(me.revive * 100))%", color: Palette.muted, size: 8)
      }
    }
    .padding(24).frame(width: 320)
    .blockPanel(opacity: 0.94, stroke: Palette.ember.opacity(0.5), radius: 16)
    .allowsHitTesting(false)
  }
}

struct HeroPanel: View {
  let hero: Hero
  let local: Bool
  var body: some View {
    let color = Palette.slot(hero.slot)
    HStack(spacing: 10) {
      RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 4)
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 6) {
          Text("P\(hero.slot + 1)").font(Fonts.mono(9)).foregroundStyle(color)
          Text(hero.name.uppercased()).font(Fonts.mono(11)).lineLimit(1)
          Spacer()
          Text(local ? "YOU" : hero.connected ? "ALLY" : "AWAY")
            .font(Fonts.eyebrow(7)).tracking(1)
            .foregroundStyle(hero.connected ? Palette.muted : Palette.ember)
        }
        HStack(spacing: 6) {
          HeartRow(hp: hero.hp, maxHP: hero.maxHP, size: 15)
          Text("\(hero.hp)").font(Fonts.mono(10)).foregroundStyle(.white)
            .contentTransition(.numericText())
            .animation(.default, value: hero.hp)
        }
        HStack(spacing: 6) {
          StatChip(icon: "diamond.fill", value: "\(hero.gems)", color: Palette.green)
          StatChip(icon: "star.fill", value: hero.score.formatted(), color: Palette.gold)
          if hero.down { StatChip(icon: "heart.slash", value: "DOWN", color: Palette.ember) }
        }
      }
    }
    .padding(.vertical, 8).padding(.horizontal, 9).frame(width: 200)
    .fixedSize(horizontal: false, vertical: true)
    .blockPanel(opacity: 0.86, depth: 3)
    .opacity(hero.connected ? 1 : 0.7)
  }
}

struct NoticeToast: View {
  let notice: Notice
  private var color: Color {
    switch notice.kind {
    case "warning", "down": return Palette.ember
    case "clear", "artifact": return Palette.gold
    case "equip": return Palette.violet
    default: return Palette.blue
    }
  }
  private var icon: String {
    switch notice.kind {
    case "warning": return "exclamationmark.triangle.fill"
    case "down": return "heart.slash.fill"
    case "clear": return "seal.fill"
    case "artifact": return "bolt.fill"
    case "equip": return "shippingbox.fill"
    default: return "flag.fill"
    }
  }
  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: icon).font(.system(size: 11, weight: .bold))
      Text(notice.text.uppercased()).font(Fonts.mono(11)).tracking(1.5)
    }
    .foregroundStyle(color).padding(.horizontal, 16).frame(height: 32)
    .background(Capsule().fill(Palette.ink.opacity(0.9)))
    .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1.5))
    .shadow(color: color.opacity(0.35), radius: 12)
    .id(notice.id)
    .transition(.move(edge: .top).combined(with: .opacity))
    .allowsHitTesting(false)
  }
}

struct ActionButton: View {
  enum Size { case small, medium, large }
  let label: String
  let icon: String
  let color: Color
  let size: Size
  var cooldown = 0
  var progress: Double? = nil
  var highlighted = false
  var hint: String? = nil
  let hold: (Bool) -> Void
  let perform: () -> Void
  @GestureState private var pressed = false

  private var dimension: CGSize {
    switch size {
    case .small: return CGSize(width: 66, height: 40)
    case .medium: return CGSize(width: 66, height: 66)
    case .large: return CGSize(width: 88, height: 88)
    }
  }
  private var radius: CGFloat { size == .small ? 10 : size == .medium ? 14 : 18 }
  private var ready: Bool { cooldown == 0 }

  var body: some View {
    let face = ready ? color : color.opacity(0.35)
    ZStack {
      RoundedRectangle(cornerRadius: radius).fill(Palette.ink.opacity(0.9)).offset(
        y: pressed ? 0 : 4)
      RoundedRectangle(cornerRadius: radius).fill(
        highlighted ? color.opacity(0.9) : Palette.panel.opacity(0.92))
      if let progress, !highlighted {
        RoundedRectangle(cornerRadius: radius).fill(color.opacity(0.25))
          .mask(alignment: .bottom) { Rectangle().frame(height: dimension.height * progress) }
      }
      if !ready {
        RoundedRectangle(cornerRadius: radius).fill(.black.opacity(0.5))
      }
      content(face: highlighted ? Palette.ink : face)
    }
    .frame(width: dimension.width, height: dimension.height)
    .overlay(
      RoundedRectangle(cornerRadius: radius)
        .stroke(ready ? color.opacity(highlighted ? 0 : 0.75) : color.opacity(0.2), lineWidth: 2)
    )
    .shadow(color: highlighted ? color.opacity(0.7) : .clear, radius: 10)
    .offset(y: pressed ? 4 : 0)
    .scaleEffect(pressed ? 0.97 : 1)
    .animation(.spring(duration: 0.12), value: pressed)
    .animation(.easeInOut(duration: 0.2), value: highlighted)
    .contentShape(Rectangle())
    .gesture(DragGesture(minimumDistance: 0).updating($pressed) { _, state, _ in state = true })
    .onChange(of: pressed) {
      if pressed { Haptics.tap() }
      hold(pressed)
    }
    .accessibilityLabel(label.capitalized)
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { perform() }
  }

  @ViewBuilder
  private func content(face: Color) -> some View {
    switch size {
    case .small:
      HStack(spacing: 5) {
        Image(systemName: icon).font(.system(size: 13, weight: .bold))
        VStack(alignment: .leading, spacing: 0) {
          Text(ready ? label : "\(cooldown)s").font(Fonts.mono(9))
          if let hint, ready {
            Text(hint).font(Fonts.eyebrow(7)).foregroundStyle(face.opacity(0.7))
          }
        }
      }.foregroundStyle(face)
    default:
      VStack(spacing: 4) {
        Image(systemName: icon).font(.system(size: size == .large ? 30 : 22, weight: .bold))
        Text(ready ? label : "\(cooldown)s").font(Fonts.mono(size == .large ? 10 : 9))
      }.foregroundStyle(face)
    }
  }
}

// MARK: - Gear picker

struct GearPickerView: View {
  @ObservedObject var game: GameClient

  private var canEquip: Bool { game.nearChest != nil }

  var body: some View {
    ZStack {
      Palette.ink.opacity(0.55).onTapGesture { game.gearOpen = false }
      VStack(spacing: 14) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: canEquip ? "CACHE OPEN  ·  ONE CARD PER HERO" : "YOUR LOADOUT")
            Text("The Reliquary").font(Fonts.display(24))
            Text(
              canEquip
                ? "Choose one card. It replaces the gear in that slot for the rest of the run."
                : "Cards unlock at the cache that appears after each seal is broken."
            ).font(Fonts.body(11)).foregroundStyle(Palette.muted)
          }
          Spacer()
          Button {
            game.gearOpen = false
          } label: {
            Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(
              width: 40, height: 40)
          }
          .buttonStyle(QuietButtonStyle(color: .white)).accessibilityLabel("Close")
        }
        HStack(alignment: .top, spacing: 14) {
          ForEach(["weapon", "bow", "armor"], id: \.self) { slot in
            VStack(spacing: 8) {
              slotHeader(slot)
              HStack(spacing: 8) {
                ForEach(GearInfo.catalogue.filter { $0.slot == slot }, id: \.choice) { gear in
                  choiceCard(gear, equipped: equipped(slot) == gear.choice)
                }
              }
            }
          }
        }
        if game.automation { DriverBanner(step: game.driverStep) }
      }
      .padding(22).frame(width: 780)
      .blockPanel(opacity: 0.97, stroke: Palette.gold.opacity(0.6), radius: 18)
    }
  }

  private func equipped(_ slot: String) -> String {
    switch slot {
    case "weapon": return game.me?.weapon ?? "iron"
    case "bow": return game.me?.bow ?? "oak"
    default: return game.me?.armor ?? "scout"
    }
  }

  private func slotHeader(_ slot: String) -> some View {
    let label = slot == "weapon" ? "MELEE" : slot == "bow" ? "RANGED" : "ARMOR"
    return HStack(spacing: 6) {
      Eyebrow(text: label, color: Palette.muted, size: 8)
      Text("·").foregroundStyle(Palette.muted)
      Text(GearInfo.title(equipped(slot))).font(Fonts.label(10)).foregroundStyle(.white)
    }
  }

  private func choiceCard(_ gear: GearInfo, equipped: Bool) -> some View {
    Button {
      Haptics.success()
      game.equip(gear.choice)
    } label: {
      VStack(spacing: 8) {
        HStack {
          Eyebrow(
            text: equipped ? "EQUIPPED" : "RARE", color: equipped ? Palette.green : gear.color,
            size: 7)
          Spacer()
          if equipped {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundStyle(
              Palette.green)
          }
        }
        GearGlyph(kind: gear.glyph, color: gear.color).frame(width: 44, height: 44)
          .padding(8).background(RoundedRectangle(cornerRadius: 10).fill(gear.color.opacity(0.12)))
        Text(gear.title.uppercased()).font(Fonts.mono(10)).foregroundStyle(.white)
          .multilineTextAlignment(.center).lineLimit(1).minimumScaleFactor(0.8)
        VStack(spacing: 2) {
          ForEach(gear.stats, id: \.self) { stat in
            Text(stat).font(Fonts.body(10)).foregroundStyle(Palette.muted)
          }
        }
        Spacer(minLength: 0)
        Text(equipped ? "IN USE" : canEquip ? "EQUIP" : "LOCKED")
          .font(Fonts.mono(9)).tracking(1)
          .foregroundStyle(canEquip && !equipped ? Palette.ink : gear.color)
          .frame(maxWidth: .infinity).frame(height: 28)
          .background(
            RoundedRectangle(cornerRadius: 7)
              .fill(canEquip && !equipped ? gear.color : gear.color.opacity(0.12)))
      }
      .padding(10).frame(width: 138, height: 208)
      .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.35)))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(
            equipped ? Palette.green.opacity(0.7) : gear.color.opacity(canEquip ? 0.7 : 0.3),
            lineWidth: 1.5)
      )
      .opacity(canEquip || equipped ? 1 : 0.65)
    }
    .buttonStyle(.plain)
    .disabled(!canEquip || equipped)
    .accessibilityLabel("Equip \(gear.title)")
  }
}

// MARK: - Result

struct ResultView: View {
  @ObservedObject var game: GameClient

  private var victory: Bool { game.state?.phase == "victory" }
  private var players: [Hero] { (game.state?.players ?? []).sorted { $0.slot < $1.slot } }
  private var topScore: Int { players.map(\.score).max() ?? 0 }
  private var readyCount: Int { players.filter(\.ready).count }

  var body: some View {
    ZStack {
      Palette.ink.opacity(0.5)
      VStack(spacing: 16) {
        VStack(spacing: 6) {
          Eyebrow(
            text: "EXPEDITION \(game.state?.round ?? 1)  ·  \(victory ? "COMPLETE" : "FAILED")",
            color: victory ? Palette.gold : Palette.ember)
          Text(victory ? "Hollowwood Restored" : "The Vanguard Falls").font(Fonts.display(32))
            .foregroundStyle(victory ? Palette.gold : .white)
          Text(
            victory
              ? "Three seals broken. The Warden defeated. Together."
              : "No hero is left behind. Regroup and try again."
          ).font(Fonts.body(12)).foregroundStyle(Palette.muted)
        }
        HStack(spacing: 14) {
          ForEach(players) { hero in resultCard(hero) }
        }
        HStack(spacing: 12) {
          Button {
            Haptics.tap()
            game.ready()
          } label: {
            HStack(spacing: 8) {
              Image(systemName: game.me?.ready == true ? "xmark" : "arrow.clockwise")
              Text(game.me?.ready == true ? "CANCEL REMATCH" : "REMATCH")
            }
          }
          .buttonStyle(BlockButtonStyle(color: Palette.gold, prominent: game.me?.ready != true))
          .frame(width: 240)
          Text("\(readyCount) / 2 READY").font(Fonts.mono(10)).foregroundStyle(Palette.muted)
          Spacer()
          Button("LEAVE EXPEDITION") { game.leave() }.buttonStyle(QuietButtonStyle())
        }
        if game.automation { DriverBanner(step: game.driverStep) }
      }
      .padding(24).frame(width: 620)
      .blockPanel(
        opacity: 0.97, stroke: (victory ? Palette.gold : Palette.ember).opacity(0.6), radius: 18)
    }
  }

  private func resultCard(_ hero: Hero) -> some View {
    let color = Palette.slot(hero.slot)
    let mvp = hero.score == topScore && players.count > 1
    return VStack(alignment: .leading, spacing: 8) {
      HStack {
        Eyebrow(
          text: "P\(hero.slot + 1)  ·  \(hero.id == game.identity ? "YOU" : "ALLY")", color: color,
          size: 8)
        Spacer()
        if mvp {
          Text("TOP SCORE").font(Fonts.eyebrow(7)).tracking(1).foregroundStyle(Palette.ink)
            .padding(.horizontal, 6).frame(height: 16).background(Capsule().fill(Palette.gold))
        }
      }
      Text(hero.name).font(Fonts.label(16))
      Text(hero.score.formatted()).font(Fonts.display(30)).foregroundStyle(color)
      HStack(spacing: 6) {
        StatChip(icon: "figure.fencing", value: "\(hero.kills)", color: Palette.ember)
        StatChip(icon: "diamond.fill", value: "\(hero.gems)", color: Palette.green)
        StatChip(icon: "scope", value: "\(hero.stats.hits)", color: Palette.violet)
        StatChip(icon: "shippingbox.fill", value: "\(hero.stats.equipment)", color: Palette.gold)
        StatChip(icon: "heart.circle.fill", value: "\(hero.stats.revive)", color: Palette.blue)
      }
      HStack(spacing: 5) {
        Image(systemName: hero.ready ? "checkmark.circle.fill" : "circle.dashed")
        Text(hero.ready ? "Ready for rematch" : "Deciding…")
      }.font(Fonts.body(10)).foregroundStyle(hero.ready ? Palette.green : Palette.muted)
    }
    .padding(14).frame(width: 279, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.35)))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.45), lineWidth: 1.5))
  }
}

// MARK: - Pause and menu

struct PauseView: View {
  @ObservedObject var game: GameClient
  var body: some View {
    ZStack {
      Palette.ink.opacity(0.45)
      VStack(spacing: 12) {
        Image(systemName: game.connected ? "person.2.wave.2.fill" : "wifi.exclamationmark")
          .font(.system(size: 26)).foregroundStyle(game.connected ? Palette.blue : Palette.ember)
        Text(game.connected ? "Waiting for your ally" : "Connection interrupted")
          .font(Fonts.display(22))
        Text(
          game.connected
            ? "The dungeon is paused until \(game.partner?.name ?? "your ally") returns. Your hero and loot are safe."
            : "The dungeon is paused. Reconnect to resume your hero exactly where you left off."
        ).font(Fonts.body(12)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        HStack(spacing: 10) {
          if !game.connected {
            Button {
              game.reconnect()
            } label: {
              Label("RECONNECT", systemImage: "arrow.clockwise")
            }.buttonStyle(BlockButtonStyle(color: Palette.blue)).frame(width: 200)
          }
          Button("LEAVE EXPEDITION") { game.leave() }.buttonStyle(QuietButtonStyle())
        }
      }
      .padding(28).frame(width: 400)
      .blockPanel(stroke: (game.connected ? Palette.blue : Palette.ember).opacity(0.5), radius: 18)
    }
  }
}

struct MenuView: View {
  @ObservedObject var game: GameClient
  var body: some View {
    ZStack {
      Palette.ink.opacity(0.45).onTapGesture { game.menuOpen = false }
      VStack(spacing: 14) {
        HStack {
          VStack(alignment: .leading, spacing: 3) {
            Eyebrow(text: "EXPEDITION MENU")
            Text("Room \(game.room)").font(Fonts.display(22))
          }
          Spacer()
          Button {
            game.menuOpen = false
          } label: {
            Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(
              width: 40, height: 40)
          }.buttonStyle(QuietButtonStyle(color: .white)).accessibilityLabel("Close")
        }
        VStack(spacing: 0) {
          row(
            "Connection", value: game.connected ? "Live" : "Offline",
            color: game.connected ? Palette.green : Palette.ember)
          Divider().overlay(Palette.line)
          row("Server", value: game.address, color: .white)
          Divider().overlay(Palette.line)
          row(
            "Hero",
            value: "P\((game.me?.slot ?? 0) + 1)  ·  \(game.name)  ·  \(game.identity.prefix(6))",
            color: .white)
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line))
        if Launch.has("automation") {
          Toggle(isOn: Binding(get: { game.automation }, set: { _ in game.toggleDriver() })) {
            VStack(alignment: .leading, spacing: 2) {
              Text("Automated input driver").font(Fonts.label(12))
              Text("Labelled test driver that plays through the normal input path.")
                .font(Fonts.body(10)).foregroundStyle(Palette.muted)
            }
          }
          .tint(Palette.gold).padding(.horizontal, 12).frame(height: 52)
          .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.35)))
          .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line))
          .accessibilityLabel(game.automation ? "AUTO DRIVER: ON" : "AUTO DRIVER: OFF")
        }
        HStack(spacing: 10) {
          Button {
            game.menuOpen = false
            game.reconnect()
          } label: {
            Label("RECONNECT", systemImage: "arrow.clockwise")
          }.buttonStyle(BlockButtonStyle(color: Palette.blue, prominent: false))
          Button {
            game.leave()
          } label: {
            Label("EXIT EXPEDITION", systemImage: "rectangle.portrait.and.arrow.right")
          }.buttonStyle(BlockButtonStyle(color: Palette.ember, prominent: false))
            .accessibilityLabel("Exit")
        }
      }
      .padding(22).frame(width: 440)
      .blockPanel(opacity: 0.97, radius: 18)
    }
  }

  private func row(_ title: String, value: String, color: Color) -> some View {
    HStack {
      Text(title.uppercased()).font(Fonts.eyebrow(8)).tracking(1).foregroundStyle(Palette.muted)
      Spacer()
      Text(value).font(Fonts.mono(10)).foregroundStyle(color).lineLimit(1)
    }.padding(.horizontal, 12).frame(height: 34)
  }
}

// MARK: - Joystick

struct Joystick: View {
  let changed: (Double, Double) -> Void
  @State private var offset = CGSize.zero
  @State private var active = false
  private let radius: CGFloat = 60
  private let travel: CGFloat = 40

  var body: some View {
    ZStack {
      Circle().fill(Palette.ink.opacity(active ? 0.7 : 0.5))
      Circle().stroke(.white.opacity(active ? 0.4 : 0.22), lineWidth: 2)
      Circle().stroke(.white.opacity(0.06), lineWidth: 16).padding(14)
      ForEach(0..<4) { index in
        Image(systemName: "chevron.up").font(.system(size: 9, weight: .black))
          .foregroundStyle(.white.opacity(0.35)).offset(y: -radius + 12)
          .rotationEffect(.degrees(Double(index) * 90))
      }
      Circle()
        .fill(
          LinearGradient(
            colors: [Color(white: 0.5), Color(white: 0.2)], startPoint: .topLeading,
            endPoint: .bottomTrailing)
        )
        .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
        .frame(width: 48, height: 48).offset(offset)
        .animation(.spring(duration: 0.15), value: active)
    }
    .frame(width: radius * 2, height: radius * 2).contentShape(Circle())
    .gesture(
      DragGesture(minimumDistance: 0).onChanged { value in
        active = true
        let dx = value.location.x - radius
        let dy = value.location.y - radius
        let distance = max(1, hypot(dx, dy) / travel)
        offset = CGSize(width: dx / distance, height: dy / distance)
        changed(Double(offset.width / travel), Double(offset.height / travel))
      }.onEnded { _ in
        active = false
        withAnimation(.spring(duration: 0.2)) { offset = .zero }
        changed(0, 0)
      }
    )
    .accessibilityLabel("Movement joystick")
  }
}
