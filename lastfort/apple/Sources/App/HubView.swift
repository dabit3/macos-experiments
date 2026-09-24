import SwiftUI

enum HubTab: String, CaseIterable, Identifiable {
  case play, locker, pass, settings
  var id: String { rawValue }
  var title: String { rawValue.capitalized }
  var symbol: String {
    switch self {
    case .play: return "play.fill"
    case .locker: return "tshirt.fill"
    case .pass: return "star.fill"
    case .settings: return "gearshape.fill"
    }
  }
}

struct HubView: View {
  @EnvironmentObject private var profile: Profile
  @EnvironmentObject private var session: Session
  @Environment(\.horizontalSizeClass) private var sizeClass
  let catalogue: Catalogue
  @State private var tab = HubTab.play
  @State private var help = false
  private var compact: Bool { sizeClass == .compact }

  var body: some View {
    VStack(spacing: 0) {
      topBar
      Divider().overlay(Color.lfLine)
      ScrollView {
        Group {
          switch tab {
          case .locker: LockerView(catalogue: catalogue)
          case .pass: PassView(catalogue: catalogue)
          case .settings: SettingsView()
          case .play: LobbyView(catalogue: catalogue)
          }
        }
        .padding(compact ? 16 : 24)
        .frame(maxWidth: 1240).frame(maxWidth: .infinity)
        .animation(nil, value: tab)
      }
      .scrollIndicators(.hidden)
      if compact { tabBar }
    }
    .background(Color.lfBackground.ignoresSafeArea())
    .sheet(isPresented: $help, onDismiss: { profile.data.seenIntro = true }) {
      HelpView { help = false }
    }
    .onAppear { if !profile.data.seenIntro && !session.options.auto { help = true } }
  }

  private var topBar: some View {
    HStack(spacing: 20) {
      Wordmark(size: compact ? 19 : 21)
      if !compact {
        HStack(spacing: 4) {
          ForEach(HubTab.allCases) { item in
            Button {
              tab = item
            } label: {
              Text(item.title).font(.lfBody(15, weight: .semibold))
                .foregroundStyle(tab == item ? Color.lfText : Color.lfMuted)
                .padding(.horizontal, 12).frame(height: 34)
                .background(
                  tab == item ? Color.lfPanel2 : .clear,
                  in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
              .accessibilityAddTraits(tab == item ? .isSelected : [])
          }
        }.padding(.leading, 8)
      }
      Spacer(minLength: 8)
      ConnectionBadge()
      if !compact {
        Button {
          tab = .pass
        } label: {
          HStack(spacing: 10) {
            if let outfit = catalogue.cosmetic(profile.data.loadout.o) {
              CosmeticArt(cosmetic: outfit).frame(width: 30, height: 30).padding(3)
                .background(Color.lfPanel2, in: RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 1) {
              Text(profile.data.name).font(.lfBody(14, weight: .semibold))
                .foregroundStyle(Color.lfText).lineLimit(1)
              Text("Tier \(min(11, profile.data.xp / 300)) · \(profile.data.xp) XP")
                .font(.lfLabel(11)).foregroundStyle(Color.lfMuted).monospacedDigit()
            }
          }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("Profile: \(profile.data.name)")
      }
      Button {
        help = true
      } label: {
        Image(systemName: "questionmark").font(.system(size: 13, weight: .bold))
          .frame(width: 34, height: 34)
          .foregroundStyle(Color.lfText)
          .background(Color.lfPanel2, in: Circle())
      }.buttonStyle(.plain).accessibilityLabel("How to play")
    }
    .padding(.horizontal, compact ? 16 : 24).frame(height: 62)
  }

  private var tabBar: some View {
    HStack {
      ForEach(HubTab.allCases) { item in
        Button {
          tab = item
        } label: {
          VStack(spacing: 4) {
            Image(systemName: item.symbol).font(.system(size: 18, weight: .semibold))
            Text(item.title).font(.lfLabel(11))
          }
          .foregroundStyle(tab == item ? Color.lfAccent : Color.lfMuted)
          .frame(maxWidth: .infinity).frame(height: 50)
          .contentShape(Rectangle())
        }.buttonStyle(.plain)
          .accessibilityAddTraits(tab == item ? .isSelected : [])
      }
    }
    .padding(.horizontal, 8)
    .background(Color.lfPanel.ignoresSafeArea(edges: .bottom))
    .overlay(alignment: .top) { Color.lfLine.frame(height: 1) }
  }
}

struct ConnectionBadge: View {
  @EnvironmentObject private var session: Session
  var body: some View {
    HStack(spacing: 7) {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(text).font(.lfLabel(12)).foregroundStyle(Color.lfMuted).monospacedDigit()
        .lineLimit(1)
    }
    .padding(.horizontal, 10).frame(height: 30)
    .inset(radius: 15)
    .accessibilityElement(children: .combine)
  }
  private var color: Color {
    switch session.connection {
    case .connected: return .lfHealth
    case .connecting, .reconnecting: return .lfAmber
    case .offline: return .lfDanger
    }
  }
  private var text: String {
    switch session.connection {
    case .connected: return "\(session.latency) ms"
    case .connecting: return "Connecting"
    case .reconnecting: return "Reconnecting"
    case .offline: return "Offline"
    }
  }
}

struct LobbyView: View {
  @Environment(\.horizontalSizeClass) private var sizeClass
  @EnvironmentObject private var session: Session
  @EnvironmentObject private var profile: Profile
  let catalogue: Catalogue
  @State private var mode: SquadMode = .squads
  @State private var code = ""
  @State private var seed = ""
  @State private var fast = false
  @State private var fill = 16
  @StateObject private var preview = IslandPreview(seed: 2026)
  private var compact: Bool { sizeClass == .compact }

  var body: some View {
    Group {
      if compact {
        VStack(alignment: .leading, spacing: 16) {
          hero.frame(height: 220)
          matchCard
          if let room = session.room { PartyCard(room: room, catalogue: catalogue, fill: fill) }
        }
      } else {
        HStack(alignment: .top, spacing: 20) {
          VStack(alignment: .leading, spacing: 20) {
            hero.frame(height: 340)
            if let room = session.room {
              PartyCard(room: room, catalogue: catalogue, fill: fill)
            } else {
              careerStrip
            }
          }
          matchCard.frame(width: 360)
        }
      }
    }
    .onAppear { if let room = session.room { preview.show(seed: room.seed) } }
    .onChange(of: session.room?.seed) { _, seed in preview.show(seed: seed ?? 2026) }
  }

  // MARK: Hero

  private var hero: some View {
    let room = session.room
    return ZStack(alignment: .bottomLeading) {
      IslandView(
        preview: preview, labels: room != nil && !compact, dim: room == nil ? 0.5 : 0.3,
        cover: true, labelClear: 0.42)
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0.35), .init(color: .lfInk.opacity(0.92), location: 1),
        ], startPoint: .top, endPoint: .bottom)
      HStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: 8) {
          if let room {
            Eyebrow("Room code", color: .lfInkMuted)
            HStack(spacing: 12) {
              Text(room.code).font(.lfDisplay(compact ? 40 : 52)).tracking(2)
                .foregroundStyle(Color.lfInkText).monospacedDigit()
                .textSelection(.enabled)
              ShareLink(item: room.code) {
                Label("Share", systemImage: "square.and.arrow.up").labelStyle(.iconOnly)
                  .font(.system(size: 15, weight: .semibold))
                  .frame(width: 36, height: 36)
                  .background(.white.opacity(0.14), in: Circle())
                  .foregroundStyle(.white)
              }.accessibilityLabel("Share room code")
            }
            Text(
              "\(room.mode.rawValue.capitalized) · \(room.players.count) of \(room.maxPlayers) players · Island \(room.seed)"
                + (room.fast ? " · Fast timers" : "")
            ).font(.lfBody(14, weight: .medium)).foregroundStyle(Color.lfInkMuted)
          } else {
            Eyebrow("Season 01 · First light", color: .lfInkMuted)
            Text("Drop in.").font(.lfDisplay(compact ? 40 : 54)).tracking(-0.5)
              .foregroundStyle(Color.lfInkText)
            Text("Sixteen players. One island. Build the last fort standing.")
              .font(.lfBody(15, weight: .medium)).foregroundStyle(Color.lfInkMuted)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer(minLength: 0)
        if !compact, room == nil, let outfit = catalogue.cosmetic(profile.data.loadout.o) {
          CosmeticArt(cosmetic: outfit).frame(width: 130, height: 200)
            .accessibilityHidden(true)
        }
      }
      .padding(compact ? 18 : 24)
    }
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.lfLine))
  }

  private var careerStrip: some View {
    let career = profile.data.career
    return VStack(alignment: .leading, spacing: 14) {
      HStack {
        SectionTitle("Career", detail: career.matches == 0 ? "Your first match starts here." : nil)
        Spacer()
        Text("Tier \(min(11, profile.data.xp / 300)) · \(profile.data.xp) XP")
          .font(.lfLabel(12)).foregroundStyle(Color.lfMuted)
      }
      HStack(spacing: 12) {
        StatCell(label: "Matches", value: "\(career.matches)")
        StatCell(label: "Wins", value: "\(career.wins)", color: .lfGold)
        StatCell(label: "Eliminations", value: "\(career.kills)")
        StatCell(
          label: "Best finish",
          value: career.bestPlacement == 0 ? "–" : "#\(career.bestPlacement)")
      }
    }.card(padding: 20)
  }

  // MARK: Match card

  private var matchCard: some View {
    VStack(alignment: .leading, spacing: 18) {
      if session.connection != .connected { connectionNotice }
      if let room = session.room {
        roomControls(room)
      } else {
        newMatch
      }
    }.card(padding: 20)
  }

  private var connectionNotice: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "wifi.exclamationmark").foregroundStyle(Color.lfAmber)
        Text(session.connection == .offline ? "Not connected" : "Connecting to server…")
          .font(.lfBody(15, weight: .semibold)).foregroundStyle(Color.lfText)
      }
      Text(profile.data.server).font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Color.lfMuted).lineLimit(1).truncationMode(.middle)
      Text(
        "Change the address in Settings. On a physical iPhone or iPad, use your Mac’s LAN address."
      )
      .font(.lfBody(13)).foregroundStyle(Color.lfMuted)
      .fixedSize(horizontal: false, vertical: true)
      Button(session.connection == .offline ? "Connect" : "Retry") { session.connect() }
        .buttonStyle(LFButtonStyle(role: .neutral, size: .compact))
    }
    .padding(14).inset(radius: 12)
  }

  private var newMatch: some View {
    VStack(alignment: .leading, spacing: 18) {
      SectionTitle("New match", detail: "Host a room and share the code.")
      VStack(alignment: .leading, spacing: 10) {
        Segmented(options: SquadMode.allCases, label: { $0.rawValue.capitalized }, selection: $mode)
        Text(mode.description).font(.lfBody(13)).foregroundStyle(Color.lfMuted)
          .contentTransition(.opacity)
      }
      Button {
        session.create(mode: mode, fast: fast, seed: Int(seed))
      } label: {
        Label("Create room", systemImage: "plus")
      }
      .buttonStyle(LFButtonStyle(role: .primary, size: .large, expand: true))
      .disabled(session.connection != .connected || (!seed.isEmpty && Int(seed) == nil))
      DisclosureGroup {
        VStack(alignment: .leading, spacing: 12) {
          Toggle("Fast storm and bus timers", isOn: $fast).font(.lfBody(14))
          TextField("Island seed (optional)", text: $seed)
            .textFieldStyle(.plain).font(.system(size: 14, design: .monospaced))
            .padding(10).inset(radius: 8)
          if !seed.isEmpty && Int(seed) == nil {
            Text("Seed must be a whole number.").font(.lfLabel(12)).foregroundStyle(Color.lfDanger)
          }
        }.padding(.top, 10)
      } label: {
        Text("Match options").font(.lfBody(14, weight: .semibold)).foregroundStyle(Color.lfMuted)
      }
      .tint(.lfMuted)
      Divider().overlay(Color.lfLine)
      VStack(alignment: .leading, spacing: 10) {
        Text("Join with a code").font(.lfBody(15, weight: .semibold)).foregroundStyle(Color.lfText)
        HStack(spacing: 8) {
          TextField("ABCDE", text: $code)
            .textFieldStyle(.plain)
            .font(.system(size: 18, weight: .semibold, design: .monospaced))
            .textCase(.uppercase)
            .autocorrectionDisabled()
            #if os(iOS)
              .textInputAutocapitalization(.characters)
            #endif
            .padding(.horizontal, 12).frame(height: 44).inset(radius: 10)
            .onSubmit { if canJoin { session.join(code) } }
          Button("Join") { session.join(code) }
            .buttonStyle(LFButtonStyle(role: .neutral)).disabled(!canJoin)
        }
      }
    }
  }
  private var canJoin: Bool {
    session.connection == .connected && code.trimmingCharacters(in: .whitespaces).count >= 4
  }

  @ViewBuilder private func roomControls(_ room: RoomState) -> some View {
    let me = room.players.first { $0.id == room.you }
    let ready = me?.ready == true
    let readyCount = room.players.filter(\.ready).count
    let host = room.players.first(where: \.host)
    SectionTitle(
      "Match setup",
      detail: session.isHost
        ? "You’re hosting. Start when your party is ready."
        : "\(host?.name ?? "The host") will start the match.")
    if session.isHost {
      VStack(alignment: .leading, spacing: 8) {
        Eyebrow("Mode")
        Segmented(
          options: SquadMode.allCases, label: { $0.rawValue.capitalized },
          selection: Binding(get: { room.mode }, set: { session.setMode($0) }))
      }
      VStack(alignment: .leading, spacing: 8) {
        Eyebrow("Lobby size")
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("\(fill) players").font(.lfBody(15, weight: .semibold))
              .foregroundStyle(Color.lfText).monospacedDigit()
            Text("\(max(0, fill - room.players.count)) bots fill the empty slots")
              .font(.lfLabel(12)).foregroundStyle(Color.lfMuted).monospacedDigit()
          }
          Spacer()
          Stepper("Lobby size", value: $fill, in: max(2, room.players.count)...room.maxPlayers)
            .labelsHidden()
        }.padding(12).inset(radius: 10)
      }
    } else {
      HStack(spacing: 10) {
        detail("Mode", room.mode.rawValue.capitalized)
        detail("Host", host?.name ?? "—")
      }
    }
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("\(readyCount) of \(room.players.count) ready").font(.lfBody(14, weight: .semibold))
          .foregroundStyle(Color.lfText).monospacedDigit()
        Spacer()
        if let countdown = room.countdownMs {
          Text("Starting in \(Int(ceil(Double(countdown) / 1000)))")
            .font(.lfBody(14, weight: .semibold)).foregroundStyle(Color.lfAccent).monospacedDigit()
            .contentTransition(.numericText())
        }
      }
      Meter(
        value: Double(readyCount), total: Double(max(1, room.players.count)),
        color: readyCount == room.players.count ? .lfHealth : .lfAccent)
    }
    VStack(spacing: 10) {
      if session.isHost {
        Button {
          session.start(fill: max(fill, room.players.count))
        } label: {
          Label(
            room.countdownMs == nil ? "Start match" : "Starting…",
            systemImage: room.countdownMs == nil ? "play.fill" : "hourglass")
        }
        .buttonStyle(LFButtonStyle(role: .primary, size: .large, expand: true))
        .disabled(room.countdownMs != nil || session.connection != .connected)
      }
      Button {
        session.ready(!ready)
      } label: {
        Label(ready ? "Ready" : "Ready up", systemImage: ready ? "checkmark" : "hand.thumbsup")
      }
      .buttonStyle(
        LFButtonStyle(
          role: ready ? .success : (session.isHost ? .neutral : .primary),
          size: session.isHost ? .regular : .large, expand: true)
      )
      .accessibilityValue(ready ? "You are ready" : "You are not ready")
      Button("Leave room") { session.leave() }
        .buttonStyle(LFButtonStyle(role: .destructive, expand: true))
    }
  }

  private func detail(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(label).font(.lfLabel(12)).foregroundStyle(Color.lfMuted)
      Text(value).font(.lfBody(15, weight: .semibold)).foregroundStyle(Color.lfText).lineLimit(1)
    }.frame(maxWidth: .infinity, alignment: .leading).padding(12).inset(radius: 10)
  }
}

extension SquadMode {
  var description: String {
    switch self {
    case .solo: return "Every player for themselves."
    case .duos: return "Teams of two. Bots pair up too."
    case .squads: return "Teams of four. Build and hold together."
    }
  }
}

struct PartyCard: View {
  @EnvironmentObject private var session: Session
  let room: RoomState
  let catalogue: Catalogue
  let fill: Int
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        SectionTitle("Party")
        Spacer()
        Text("\(room.players.count) of \(room.maxPlayers)").font(.lfLabel(13))
          .foregroundStyle(Color.lfMuted).monospacedDigit()
      }
      VStack(spacing: 6) {
        ForEach(room.players) { player in
          MemberRow(player: player, isYou: player.id == room.you, catalogue: catalogue)
        }
      }
      let bots = max(0, (session.isHost ? fill : room.maxPlayers) - room.players.count)
      HStack(spacing: 10) {
        Image(systemName: "person.badge.plus").foregroundStyle(Color.lfMuted)
        Text(
          bots > 0
            ? "Share the room code to add players. Up to \(bots) bots fill the remaining slots."
            : "Lobby is full."
        ).font(.lfBody(13)).foregroundStyle(Color.lfMuted)
      }.padding(.top, 2)
    }.card(padding: 20)
  }
}

struct MemberRow: View {
  let player: RoomMember
  let isYou: Bool
  let catalogue: Catalogue
  var body: some View {
    HStack(spacing: 12) {
      Group {
        if let outfit = catalogue.cosmetic(player.ld.o) {
          CosmeticArt(cosmetic: outfit).padding(4)
        } else {
          Image(systemName: "person.fill").foregroundStyle(Color.lfMuted)
        }
      }
      .frame(width: 44, height: 44)
      .background(Color.lfPanel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(player.name).font(.lfBody(15, weight: .semibold)).foregroundStyle(Color.lfText)
            .lineLimit(1)
          if isYou { Pill(text: "You", color: .lfAccent) }
          if player.host { Pill(text: "Host") }
        }
        HStack(spacing: 6) {
          PlatformIcon(platform: player.platform)
          Text("Team \(player.team + 1)")
        }.font(.lfLabel(12)).foregroundStyle(Color.lfMuted)
      }
      Spacer()
      HStack(spacing: 6) {
        Image(systemName: player.ready ? "checkmark.circle.fill" : "circle.dashed")
        Text(player.ready ? "Ready" : "Not ready")
      }
      .font(.lfLabel(13))
      .foregroundStyle(player.ready ? Color.lfHealth : Color.lfMuted)
    }
    .padding(10)
    .background(
      isYou ? Color.lfAccent.opacity(0.08) : Color.lfPanel2,
      in: RoundedRectangle(cornerRadius: 12, style: .continuous)
    )
    .accessibilityElement(children: .combine)
  }
}

struct HelpView: View {
  let close: () -> Void
  private let desktop: [(String, String)] = [
    ("W A S D", "Move"), ("Shift", "Sprint"), ("Mouse", "Aim"),
    ("Click", "Fire · harvest · place"), ("E / right click", "Interact · open chest"),
    ("Space", "Drop from the bus"), ("1–6 / wheel", "Hotbar"), ("R", "Reload"),
    ("G", "Drop item"), ("Q", "Build mode"), ("Z X C V", "Wall · floor · ramp · roof"),
    ("M", "Material"), ("F", "Edit wall · rotate ramp"), ("B", "Emote"),
    ("T", "Thank the driver"), ("Tab", "Spectate next"), ("Esc", "Match menu"),
  ]
  private let touch: [(String, String)] = [
    ("Left stick", "Move"), ("Right stick", "Aim · push further to fire"),
    ("Jump", "Drop from the bus · jump"), ("Interact", "Open chest · pick up"),
    ("Sprint", "Toggle sprint"), ("Build", "Switch between combat and building"),
    ("Wall · Floor · Ramp · Roof", "Choose a piece, then Place"),
    ("Materials", "Tap to cycle wood, stone, metal"), ("Hotbar", "Tap a slot to equip"),
    ("Minimap", "Tap for the full island"),
  ]
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        HStack(alignment: .top) {
          SectionTitle("How to play", detail: "Drop, loot, build, outlast.")
          Spacer()
          Button {
            close()
          } label: {
            Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
              .frame(width: 32, height: 32).background(Color.lfPanel2, in: Circle())
          }.buttonStyle(.plain).accessibilityLabel("Close")
        }
        VStack(alignment: .leading, spacing: 12) {
          step(
            1, "Ride the bus and pick a landing.",
            "Steer while you fall. Land near buildings for chests.")
          step(
            2, "Loot and harvest.",
            "Weapons, shields and ammo come from chests and the ground. Swing your pickaxe at trees, rocks and cars for materials."
          )
          step(
            3, "Build and stay in the eye.",
            "Walls, floors, ramps and roofs cost materials. The storm shrinks in phases and hurts more each time."
          )
          step(
            4, "Be the last team standing.",
            "Eliminated players spectate their squad, then the survivors.")
        }
        #if os(iOS)
          table("Touch controls", touch, monospaced: false)
          table("Playing with a keyboard", desktop, monospaced: true)
        #else
          table("Keyboard and mouse", desktop, monospaced: true)
        #endif
        Button("Let’s drop") { close() }
          .buttonStyle(LFButtonStyle(role: .primary, size: .large, expand: true))
      }.padding(24)
    }
    .background(Color.lfBackground)
    .frame(idealWidth: 560, idealHeight: 720)
  }
  private func table(_ title: String, _ rows: [(String, String)], monospaced: Bool) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Eyebrow(title)
      VStack(spacing: 0) {
        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
          HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(row.0)
              .font(
                monospaced
                  ? .system(size: 12, weight: .semibold, design: .monospaced)
                  : .lfBody(13, weight: .semibold)
              )
              .foregroundStyle(Color.lfText)
              .padding(.horizontal, 8).padding(.vertical, 5)
              .background(Color.lfPanel2, in: RoundedRectangle(cornerRadius: 6))
              .frame(width: 150, alignment: .leading)
            Text(row.1).font(.lfBody(14)).foregroundStyle(Color.lfText)
            Spacer(minLength: 0)
          }.padding(.vertical, 6)
          if index < rows.count - 1 { Divider().overlay(Color.lfLine) }
        }
      }
    }
  }
  private func step(_ number: Int, _ title: String, _ detail: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Text("\(number)").font(.lfDigits(14)).foregroundStyle(.white)
        .frame(width: 26, height: 26).background(Color.lfAccent, in: Circle())
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.lfBody(15, weight: .semibold)).foregroundStyle(Color.lfText)
        Text(detail).font(.lfBody(14)).foregroundStyle(Color.lfMuted)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
