import SwiftUI

struct HubView: View {
  @EnvironmentObject private var profile: Profile
  @EnvironmentObject private var session: Session
  @Environment(\.colorScheme) private var colorScheme
  let catalogue: Catalogue
  @State private var tab = "Play"
  @State private var help = false
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 0) {
          Text("LASTFORT").font(.custom("Rajdhani-Bold", size: 32))
          Text("DROP. BUILD. OUTLAST.").font(.custom("Rajdhani-SemiBold", size: 11)).tracking(2)
            .foregroundStyle(Color.fortTeal)
        }
        Spacer()
        VStack(alignment: .trailing) {
          Text(profile.data.name).font(.custom("Rajdhani-Bold", size: 17))
          Text("TIER \(min(11, profile.data.xp / 300)) · \(profile.data.xp) XP")
            .font(.custom("Rajdhani-Medium", size: 12)).foregroundStyle(.secondary)
        }
        Button {
          help = true
        } label: {
          Image(systemName: "questionmark.circle").font(.title2)
        }
        .buttonStyle(.plain).padding(.leading, 8).accessibilityLabel("How to play")
      }.padding(16)
      Picker("Section", selection: $tab) {
        ForEach(["Play", "Locker", "Pass", "Settings"], id: \.self) { Text($0).tag($0) }
      }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.bottom, 12)
      Divider()
      ScrollView {
        Group {
          switch tab {
          case "Locker": LockerView(catalogue: catalogue)
          case "Pass": PassView(catalogue: catalogue)
          case "Settings": SettingsView()
          default: LobbyView(catalogue: catalogue)
          }
        }.padding(20).frame(maxWidth: 1400).frame(maxWidth: .infinity)
      }
      HStack {
        Circle().fill(session.connection == .connected ? Color.fortTeal : .fortEmber).frame(
          width: 7, height: 7)
        Text(session.connection.rawValue.capitalized)
        if session.connection == .connected { Text("· \(session.latency) ms") }
        Spacer()
        Text("ORIGINAL ISLAND · SEASON 01").font(.custom("Rajdhani-SemiBold", size: 11))
      }.font(.custom("Rajdhani-Medium", size: 13)).padding(12)
    }
    .background(colorScheme == .dark ? Color.fortBackground : Color(rgb: 0xF1F5F7))
    .sheet(isPresented: $help) {
      HelpView {
        help = false
        profile.data.seenIntro = true
      }
    }
    .onAppear { if !profile.data.seenIntro && !session.options.auto { help = true } }
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
  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: 5) {
          Text("THE ISLAND IS CALLING").font(.custom("Rajdhani-SemiBold", size: 14)).tracking(3)
            .foregroundStyle(Color.fortTeal).lineLimit(1).minimumScaleFactor(0.6)
          Text("MAKE YOUR\nLAST STAND.").font(.custom("Rajdhani-Bold", size: 43)).lineSpacing(-8)
            .lineLimit(2).minimumScaleFactor(0.6)
          Text("Loot the island. Raise your fort.\nBe the last squad standing.").font(
            .custom("Rajdhani-Medium", size: 18))
        }
        Spacer(minLength: 0)
        if sizeClass != .compact, let outfit = catalogue.cosmetic(profile.data.loadout.o) {
          CosmeticArt(cosmetic: outfit).frame(width: 140, height: 210)
        }
      }
      .padding(20).foregroundStyle(.white)
      .frame(maxWidth: .infinity, minHeight: 275, alignment: .bottomLeading)
      .background {
        Image("IslandKeyart").resizable().scaledToFill()
          .overlay(
            LinearGradient(colors: [.clear, .fortBackground], startPoint: .top, endPoint: .bottom))
      }
      .clipShape(RoundedRectangle(cornerRadius: 18))
      if let room = session.room {
        roomPanel(room)
      } else {
        Text("Choose your drop").font(.custom("Rajdhani-Bold", size: 30))
        Picker("Match mode", selection: $mode) {
          ForEach(SquadMode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }.pickerStyle(.segmented)
        Text(
          mode == .solo
            ? "Every scout for themselves."
            : mode == .duos
              ? "A partner. A plan. One last stand." : "Four scouts. One squad. Build together."
        )
        .foregroundStyle(.secondary)
        HStack {
          TextField("Room code", text: $code).textFieldStyle(.roundedBorder).frame(maxWidth: 180)
          Button("Join room") { session.join(code) }.buttonStyle(FortButtonStyle())
            .disabled(
              session.connection != .connected
                || code.trimmingCharacters(in: .whitespaces).count < 4)
        }
        DisclosureGroup("Match options") {
          VStack(alignment: .leading, spacing: 12) {
            Toggle("Fast storm and bus timers", isOn: $fast)
            TextField("Seed (optional integer)", text: $seed).textFieldStyle(.roundedBorder)
          }.padding(.top, 10)
        }
        Button("Create room") { session.create(mode: mode, fast: fast, seed: Int(seed)) }
          .buttonStyle(FortButtonStyle(primary: true)).disabled(
            session.connection != .connected || (!seed.isEmpty && Int(seed) == nil))
      }
      if session.connection != .connected {
        Button(session.connection == .offline ? "Connect to server" : "Retry connection") {
          session.connect()
        }.buttonStyle(FortButtonStyle())
        Text(
          "Set your server address in Settings. On a physical iPhone or iPad, use the Mac’s LAN address."
        ).foregroundStyle(.secondary)
      }
    }
  }
  @ViewBuilder private func roomPanel(_ room: RoomState) -> some View {
    HStack {
      VStack(alignment: .leading) {
        Text("ROOM \(room.code)").font(.custom("Rajdhani-Bold", size: 30))
        Text(
          "\(room.players.count)/\(room.maxPlayers) scouts · \(room.mode.rawValue.capitalized) · Seed \(room.seed)"
        ).foregroundStyle(.secondary)
      }
      Spacer()
      ShareLink(item: room.code) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel(
        "Share room code")
    }
    ForEach(room.players) { player in
      HStack {
        if let outfit = catalogue.cosmetic(player.ld.o) {
          CosmeticArt(cosmetic: outfit).frame(width: 50, height: 60)
        }
        VStack(alignment: .leading) {
          Text(player.name + (player.id == room.you ? " · You" : "")).font(
            .custom("Rajdhani-Bold", size: 21))
          Text(
            "\(player.platform.uppercased()) · TEAM \(player.team + 1)"
              + (player.host ? " · HOST" : "")
          ).font(.custom("Rajdhani-Medium", size: 13)).foregroundStyle(.secondary)
        }
        Spacer()
        Text(player.ready ? "READY" : "NOT READY").foregroundStyle(
          player.ready ? Color.fortTeal : .secondary)
      }.padding(10).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }
    if session.isHost {
      Picker("Mode", selection: Binding(get: { room.mode }, set: { session.setMode($0) })) {
        ForEach(SquadMode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
      }.pickerStyle(.segmented)
      Stepper(
        "Players including bots: \(fill)", value: $fill,
        in: max(2, room.players.count)...room.maxPlayers)
      Text("\(max(0, fill - room.players.count)) empty slots will be filled by server bots.")
        .foregroundStyle(.secondary)
    }
    if let countdown = room.countdownMs {
      Text("Launch in \(Int(ceil(Double(countdown) / 1000)))…").font(
        .custom("Rajdhani-Bold", size: 28)
      ).foregroundStyle(Color.fortEmber)
    }
    ViewThatFits {
      HStack { lobbyButtons(room) }
      VStack(alignment: .leading) { lobbyButtons(room) }
    }
  }
  @ViewBuilder private func lobbyButtons(_ room: RoomState) -> some View {
    let ready = room.players.first { $0.id == room.you }?.ready == true
    Button(ready ? "Unready" : "Ready up") { session.ready(!ready) }.buttonStyle(FortButtonStyle())
    if session.isHost {
      Button("Launch match") { session.start(fill: max(fill, room.players.count)) }
        .buttonStyle(FortButtonStyle(primary: true)).disabled(
          room.countdownMs != nil || session.connection != .connected)
    }
    Button("Leave room") { session.leave() }.buttonStyle(FortButtonStyle())
  }
}
struct HelpView: View {
  let close: () -> Void
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("WELCOME TO LASTFORT").font(.custom("Rajdhani-Bold", size: 32))
        Text(
          "Ride the bus, choose your landing, and search the island for weapons and supplies. Swing your pickaxe to harvest wood, stone and metal. Spend materials to build walls, floors, ramps and roofs."
        )
        Text(
          "Stay inside the storm eye. Your squad wins when every opposing squad is eliminated. After elimination, spectate a teammate or cycle to the next survivor."
        )
        Text("DESKTOP").font(.custom("Rajdhani-Bold", size: 23)).foregroundStyle(Color.fortTeal)
        Text(
          "WASD / arrows · Move\nShift · Sprint\nMouse · Aim   Left click · Fire / harvest / place\nRight click / E · Interact / open chest\nSpace · Drop from bus\n1–6 / wheel · Hotbar   R · Reload   G · Drop item\nQ · Build mode   Z/X/C/V · Wall/floor/ramp/roof\nM · Material   F · Cycle wall edit / rotate ramp\nB · Emote   T · Thank driver   Tab · Spectate next\nEsc · Match menu"
        )
        Text("IPHONE & IPAD").font(.custom("Rajdhani-Bold", size: 23)).foregroundStyle(
          Color.fortTeal)
        Text(
          "Left stick moves. Right stick aims and fires. Action buttons handle dropping, interacting, sprinting, using items, building and editing. Tap a hotbar slot to equip it. Tap the minimap for the full island. Rotate your device to fit your play style."
        )
        Button("Let’s drop") { close() }.buttonStyle(FortButtonStyle(primary: true))
      }.padding(24)
    }.font(.custom("Rajdhani-Medium", size: 18)).frame(idealWidth: 600, idealHeight: 680)
  }
}
