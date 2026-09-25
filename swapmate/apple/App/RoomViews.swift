import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var client: GameClient
  @Environment(\.colorScheme) private var scheme
  @State private var name = ""
  @State private var server = ""
  @State private var code = ""
  @State private var spectate = false
  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        let wide = geometry.size.width > 820
        let layout =
          wide
          ? AnyLayout(HStackLayout(alignment: .center, spacing: 36))
          : AnyLayout(VStackLayout(spacing: 24))
        layout {
          VStack(alignment: .leading, spacing: 16) {
            Text("TWO BOARDS. ONE TEAM.").font(.custom("Inter-SemiBold", size: 11)).tracking(3)
              .foregroundStyle(Palette(scheme).accent)
            Text("YOUR CAPTURE.\nTHEIR COMEBACK.").font(BrandFont.display(wide ? 64 : 44))
              .lineSpacing(-4)
              .fixedSize(horizontal: false, vertical: true)
            Text(
              "Fast chess, shared firepower. Every piece you take becomes your partner’s next move."
            )
            .foregroundStyle(Palette(scheme).muted).fixedSize(horizontal: false, vertical: true)
            ArenaIllustration()
            HStack {
              Label("2 vs 2", systemImage: "person.2.fill")
              Spacer()
              Label("Live bughouse", systemImage: "bolt.fill")
            }.font(BrandFont.body(12)).foregroundStyle(Palette(scheme).muted)
          }.frame(maxWidth: .infinity, alignment: .leading)
          Panel {
            VStack(alignment: .leading, spacing: 16) {
              Text("STEP INTO THE ARENA.").font(BrandFont.display(30))
              Text("Your name").font(BrandFont.body(12)).foregroundStyle(Palette(scheme).muted)
              TextField("Player name", text: $name).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("player-name")
              Text("Server").font(BrandFont.body(12)).foregroundStyle(Palette(scheme).muted)
              TextField("ws://localhost:8787/ws", text: $server).textFieldStyle(.roundedBorder)
                .autocorrectionDisabled().accessibilityIdentifier("server-url")
                #if os(iOS)
                  .textInputAutocapitalization(.never).keyboardType(.URL)
                #endif
              Button {
                enter(.create(nil, fillBots: false, code: nil))
              } label: {
                Label("Create a room", systemImage: "plus").frame(maxWidth: .infinity)
              }.buttonStyle(ArcadeButtonStyle(primary: true))
              Button {
                enter(.create(nil, fillBots: true, code: nil))
              } label: {
                Label("Play with bots", systemImage: "cpu").frame(maxWidth: .infinity)
              }
              Divider().overlay(Palette(scheme).outline)
              Text("HAVE A CODE?").font(.custom("Inter-SemiBold", size: 12)).tracking(2)
              HStack {
                TextField("4-letter code", text: $code).textFieldStyle(.roundedBorder)
                  .onChange(of: code) { _, value in
                    code = String(value.uppercased().filter(\.isLetter).prefix(4))
                  }
                  .onSubmit(join)
                Button("Join", action: join)
              }
              Toggle("Join as spectator", isOn: $spectate).font(BrandFont.body(12))
              Text(
                "Share your room code with three friends, or warm up with bots. Captures go straight to your partner’s reserve."
              )
              .font(BrandFont.body(12)).foregroundStyle(Palette(scheme).muted)
            }
          }.frame(maxWidth: wide ? 410 : .infinity)
        }.padding(24).frame(maxWidth: 1120).frame(maxWidth: .infinity)
        Text("Original Swapmate artwork · Barlow Condensed & Inter (SIL Open Font License)")
          .font(BrandFont.body(10)).foregroundStyle(Palette(scheme).muted).padding(.bottom, 24)
      }
    }
    .onAppear {
      name = client.name
      server = client.server
    }
    .disabled(client.status == .connecting)
  }
  private func enter(_ command: ClientCommand) {
    client.connect(url: server, name: name, entry: command)
  }
  private func join() {
    guard code.count == 4 else {
      client.error = "Enter the 4-letter room code."
      return
    }
    enter(.join(code, spectate: spectate))
  }
}

struct TeamHeading: View {
  @Environment(\.colorScheme) private var scheme
  let team: Team
  var body: some View {
    HStack {
      Image(systemName: team == .tidal ? "water.waves" : "flame.fill")
        .font(.title2).frame(width: 44, height: 44)
        .foregroundStyle(Palette(scheme).canvas)
        .background(Palette(scheme).team(team), in: RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading) {
        Text("TEAM \(team.rawValue)").font(BrandFont.body(10)).tracking(2)
        Text(team.label).font(BrandFont.display(27))
      }
    }.foregroundStyle(Palette(scheme).team(team))
  }
}

struct LobbyView: View {
  @EnvironmentObject private var client: GameClient
  @Environment(\.colorScheme) private var scheme
  let room: RoomState
  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text("ASSEMBLE YOUR DUO.").font(BrandFont.display(40))
          Text("Opposite colors. Same side.").foregroundStyle(Palette(scheme).muted)
          let layout =
            geometry.size.width > 860
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 20))
            : AnyLayout(VStackLayout(spacing: 20))
          layout {
            VStack(spacing: 16) {
              ForEach(Team.allCases) { team in
                Panel {
                  VStack(alignment: .leading, spacing: 12) {
                    TeamHeading(team: team)
                    ForEach(Seat.allCases.filter { $0.team == team }) { seat in seatRow(seat) }
                  }
                }
              }
              if client.mySeat != nil {
                Button(client.me?.ready == true ? "Not ready" : "Ready up") {
                  client.send(.ready(!(client.me?.ready ?? false)))
                }.buttonStyle(ArcadeButtonStyle(primary: true)).disabled(!client.online)
                Button("Move to spectators") { client.send(.seat(nil)) }.disabled(!client.online)
              }
            }.frame(maxWidth: .infinity)
            VStack(spacing: 16) {
              Panel {
                VStack(alignment: .leading, spacing: 12) {
                  Text("ROOM CODE").font(BrandFont.body(11)).tracking(2)
                  HStack {
                    Text(room.code).font(BrandFont.display(50)).tracking(6).textSelection(.enabled)
                    Spacer()
                    Button {
                      NativeClipboard.copy(room.code)
                      client.notice = "Room code copied."
                    } label: {
                      Image(systemName: "doc.on.doc")
                    }
                    .accessibilityLabel("Copy room code")
                  }
                  Text("Send this code to your crew.").foregroundStyle(Palette(scheme).muted)
                  Picker(
                    "Time control",
                    selection: Binding(
                      get: { room.timeControl }, set: { client.send(.timeControl($0)) })
                  ) {
                    ForEach(timeControls, id: \.self) { Text($0.label).tag($0) }
                  }.disabled(!client.isHost || !client.online)
                  if client.isHost {
                    Button("Start match") { client.send(.start) }
                      .buttonStyle(ArcadeButtonStyle(primary: true)).disabled(
                        !allReady || !client.online)
                  }
                  Text(
                    allReady ? "All seats are ready." : "Fill all four seats and ready up to begin."
                  )
                  .font(BrandFont.body(12)).foregroundStyle(Palette(scheme).muted)
                }
              }
              if !room.spectators.isEmpty {
                Panel {
                  VStack(alignment: .leading, spacing: 8) {
                    Text("SPECTATORS · \(room.spectators.count)").font(BrandFont.display(20))
                    ForEach(room.spectators) { Text($0.name).font(BrandFont.body(12)) }
                  }
                }
              }
              ChatPanel().frame(height: 340)
            }.frame(maxWidth: .infinity)
          }
        }.padding(24).frame(maxWidth: 1200).frame(maxWidth: .infinity)
      }
    }
  }
  private var timeControls: [TimeControl] {
    Array(Set(TimeControl.presets + [room.timeControl])).sorted {
      $0.initialMs == $1.initialMs ? $0.incrementMs < $1.incrementMs : $0.initialMs < $1.initialMs
    }
  }
  private var allReady: Bool {
    Seat.allCases.allSatisfy { seat in
      room.seated(seat).map { ($0.bot || $0.ready) && $0.connected } ?? false
    }
  }
  private func seatRow(_ seat: Seat) -> some View {
    let player = room.seated(seat)
    return HStack(spacing: 8) {
      PieceGlyph(piece: Piece(color: seat.color, kind: .king)).frame(width: 36, height: 40)
      VStack(alignment: .leading, spacing: 4) {
        Text(player?.name ?? "Open seat").font(.custom("Inter-SemiBold", size: 14))
        Text("\(seat.label)\(player?.id == client.playerID ? " · YOU" : "")").font(
          BrandFont.body(11)
        ).foregroundStyle(Palette(scheme).muted)
        if let player {
          Text(
            player.bot
              ? "BOT" : !player.connected ? "Disconnected" : player.ready ? "Ready" : "Waiting"
          )
          .font(BrandFont.body(10)).foregroundStyle(Palette(scheme).team(seat.team))
        }
      }
      Spacer(minLength: 0)
      if player == nil || player?.bot == true {
        if player == nil {
          Button("Sit") { client.send(.seat(seat)) }.disabled(!client.online)
        }
        if client.isHost {
          Button {
            client.send(.bot(seat, add: player == nil))
          } label: {
            Image(systemName: player == nil ? "cpu" : "minus.circle")
          }.accessibilityLabel(
            player == nil ? "Add bot to \(seat.label)" : "Remove bot from \(seat.label)"
          )
          .disabled(!client.online)
        }
      }
    }.padding(10).background(Palette(scheme).sunken, in: RoundedRectangle(cornerRadius: 12))
  }
}

struct ChatPanel: View {
  @EnvironmentObject private var client: GameClient
  @Environment(\.colorScheme) private var scheme
  @State private var text = ""
  @State private var scope = ChatScope.room
  var body: some View {
    Panel {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("CHAT").font(BrandFont.display(22))
          Spacer()
          Picker("Audience", selection: $scope) {
            Text("Room").tag(ChatScope.room)
            if client.mySeat != nil { Text("Team").tag(ChatScope.team) }
          }.labelsHidden().frame(maxWidth: 140)
        }
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
              if client.chats.isEmpty {
                Text("Say hello to the room.").foregroundStyle(Palette(scheme).muted)
              }
              ForEach(client.chats) { chat in
                VStack(alignment: .leading, spacing: 3) {
                  Text("\(chat.name)\(chat.scope == .team ? " · TEAM" : "")")
                    .font(.custom("Inter-SemiBold", size: 10))
                    .foregroundStyle(
                      chat.seat.map { Palette(scheme).team($0.team) } ?? Palette(scheme).muted)
                  Text(chat.display).font(BrandFont.body(12)).textSelection(.enabled)
                }.id(chat.id)
              }
            }.frame(maxWidth: .infinity, alignment: .leading)
          }.onChange(of: client.chats.count) { _, _ in
            if let id = client.chats.last?.id { proxy.scrollTo(id, anchor: .bottom) }
          }
        }
        if client.mySeat != nil {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
              ForEach(QuickChat.allCases) { quick in
                Button(quick.text) { client.send(.quick(quick, .team)) }
                  .buttonStyle(.bordered).font(BrandFont.body(10))
              }
            }
          }.disabled(!client.online)
        }
        HStack(spacing: 8) {
          TextField(scope == .team ? "Message your partner…" : "Message the room…", text: $text)
            .textFieldStyle(.roundedBorder).onSubmit(send)
            .onChange(of: text) { _, value in text = String(value.prefix(200)) }
          Button(action: send) { Image(systemName: "paperplane.fill") }
            .buttonStyle(.borderless).accessibilityLabel("Send message")
            .disabled(
              text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !client.online)
        }
      }
    }
    .onChange(of: client.mySeat) { _, seat in if seat == nil { scope = .room } }
  }
  private func send() {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    client.send(.chat(trimmed, scope))
    if client.online { text = "" }
  }
}
