import SwiftUI

@main
struct PanicPantryApp: App {
  @State private var client = GameClient()
  init() { PantryStyle.registerFonts() }
  var body: some Scene {
    #if os(macOS)
      Window("Panic Pantry", id: "pantry") {
        RootView(client: client).frame(minWidth: 780, minHeight: 580)
      }
      .defaultSize(width: 1180, height: 820)
      .commands {
        CommandGroup(replacing: .help) {
          Button("How to play Panic Pantry") { client.showHelp = true }
        }
      }
    #else
      WindowGroup { RootView(client: client) }
    #endif
  }
}

struct RootView: View {
  @Bindable var client: GameClient
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.colorScheme) private var scheme
  @State private var launched = false
  var body: some View {
    ZStack {
      ArcadeBackground()
      VStack(spacing: 0) {
        if let error = client.error {
          HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(error).font(PantryStyle.font(13)).textSelection(.enabled)
            Spacer()
            Button("Dismiss") { client.error = nil }.buttonStyle(.plain)
          }
          .padding(12).foregroundStyle(.white).background(PantryStyle.paprikaDark)
          .accessibilityIdentifier("connection-error")
        }
        Group {
          switch client.screen {
          case "lobby": LobbyView(client: client)
          case "game": GameView(client: client)
          case "results": ResultsView(client: client)
          default: HomeView(client: client)
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      if client.room != nil && client.connection != .connected {
        Color.black.opacity(0.65).ignoresSafeArea()
        PantryCard {
          VStack(spacing: 16) {
            ProgressView()
            Text(client.connection == .failed ? "Connection lost" : "Reconnecting…")
              .font(PantryStyle.font(24, weight: "Black"))
            Text("Your chef's seat is reserved while the server is available.")
              .multilineTextAlignment(.center)
            HStack {
              Button("Retry now") {
                client.disconnect()
                client.connect()
              }.buttonStyle(ArcadeButtonStyle())
              Button("Leave") { client.leave() }.buttonStyle(
                ArcadeButtonStyle(color: PantryStyle.ink))
            }
          }
        }.frame(maxWidth: 420).padding(20)
      }
    }
    .font(PantryStyle.font())
    .foregroundStyle(scheme == .dark ? PantryStyle.cream : PantryStyle.ink)
    .tint(PantryStyle.paprika)
    .preferredColorScheme(client.theme == "dark" ? .dark : client.theme == "light" ? .light : nil)
    .sheet(isPresented: $client.showHelp) { HelpView() }
    .alert(
      "Resume storage",
      isPresented: Binding(get: { client.notice != nil }, set: { if !$0 { client.notice = nil } })
    ) {
      Button("OK") { client.notice = nil }
    } message: {
      Text(client.notice ?? "")
    }
    .onChange(of: scenePhase) { _, value in if value != .active { client.clearInput() } }
    .task {
      guard !launched else { return }
      launched = true
      let config = LaunchConfiguration()
      if config.automatic {
        client.connect(intent: config.room.map { .join(code: $0) } ?? .create(level: config.level))
      }
    }
  }
}

struct ThemeButton: View {
  @Bindable var client: GameClient
  @Environment(\.colorScheme) private var scheme
  var body: some View {
    Button {
      client.theme = scheme == .dark ? "light" : "dark"
    } label: {
      Image(systemName: scheme == .dark ? "sun.max.fill" : "moon.fill").frame(width: 32, height: 32)
    }.buttonStyle(.plain).help("Switch theme").accessibilityLabel("Switch theme")
  }
}

struct HomeView: View {
  @Bindable var client: GameClient
  @State private var code = LaunchConfiguration().room ?? ""
  @State private var serverVisible = false
  private var busy: Bool { client.connection == .connecting || client.connection == .reconnecting }
  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        HStack {
          Spacer()
          ThemeButton(client: client)
        }.padding(.horizontal, 20)
        let layout =
          geometry.size.width > 850
          ? AnyLayout(HStackLayout(spacing: 28)) : AnyLayout(VStackLayout(spacing: 24))
        layout {
          hero.frame(minHeight: geometry.size.width > 850 ? 550 : 330)
          PantryCard {
            VStack(alignment: .leading, spacing: 18) {
              Text("CLOCK IN.").font(PantryStyle.font(32, weight: "Black"))
              Text("Good food. Great chaos.").foregroundStyle(.secondary)
              TextField("Chef name", text: $client.name).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("chef-name")
              Button {
                client.connect(intent: .create(level: LaunchConfiguration().level))
              } label: {
                Label("Host a kitchen", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
              }.buttonStyle(ArcadeButtonStyle()).disabled(busy)
              HStack {
                Rectangle().frame(height: 1)
                Text("OR JOIN").font(PantryStyle.font(11))
                Rectangle().frame(height: 1)
              }.foregroundStyle(.secondary.opacity(0.4))
              HStack {
                TextField("CODE", text: $code).textFieldStyle(.roundedBorder)
                  .font(.custom("JetBrainsMono-Medium", size: 20))
                  .onChange(of: code) { _, value in
                    code = String(
                      value.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
                  }
                  .onSubmit { join() }
                  .accessibilityIdentifier("join-code")
                Button("Join") { join() }.buttonStyle(ArcadeButtonStyle(color: PantryStyle.basil))
                  .disabled(code.count < 4 || busy)
              }
              Button("How to play") { client.showHelp = true }
                .buttonStyle(ArcadeButtonStyle(color: PantryStyle.ink))
              DisclosureGroup("Server connection", isExpanded: $serverVisible) {
                VStack(alignment: .leading, spacing: 8) {
                  TextField("ws://host:8787/ws", text: $client.server).textFieldStyle(
                    .roundedBorder
                  )
                  .font(.custom("JetBrainsMono-Medium", size: 12))
                  .accessibilityIdentifier("server-url")
                  Text("For a physical device, enter the server computer's LAN address.")
                    .font(PantryStyle.font(12)).foregroundStyle(.secondary)
                  Button("Reconnect / resume") { client.connect() }.disabled(busy)
                }.padding(.top, 8)
              }
              if busy {
                HStack {
                  ProgressView().controlSize(.small)
                  Text(client.connection.rawValue.capitalized + "…").font(PantryStyle.font(12))
                  Spacer()
                  Button("Cancel") { client.disconnect() }
                }
              }
            }
          }.frame(maxWidth: 380)
        }
        .frame(maxWidth: 1160).padding(24).frame(maxWidth: .infinity)
      }
    }
  }
  private var hero: some View {
    ZStack(alignment: .bottomLeading) {
      GeometryReader { geometry in
        Image("arcade-kitchen").resizable().scaledToFill()
          .frame(width: geometry.size.width, height: geometry.size.height).clipped()
      }
      LinearGradient(
        colors: [PantryStyle.ink.opacity(0.8), .clear, PantryStyle.ink],
        startPoint: .top, endPoint: .bottom)
      VStack(alignment: .leading, spacing: 0) {
        Text("PANIC").foregroundStyle(PantryStyle.butter)
        Text("PANTRY").foregroundStyle(PantryStyle.cream)
        Spacer()
        Text("GOOD FOOD. GREAT CHAOS.").font(PantryStyle.font(20, weight: "Black"))
        Text("2–4 chefs  /  5 kitchens  /  One wild dinner rush")
          .font(PantryStyle.font(13)).padding(.top, 6)
        Text("iPHONE  ·  iPAD  ·  macOS").font(PantryStyle.font(12, weight: "ExtraBold"))
          .foregroundStyle(PantryStyle.butter).padding(.top, 12)
      }
      .font(PantryStyle.font(58, weight: "Black")).lineSpacing(-12)
      .shadow(color: PantryStyle.ink, radius: 0, x: 2, y: 4)
      .padding(26).foregroundStyle(PantryStyle.cream)
    }.clipShape(RoundedRectangle(cornerRadius: 28))
      .overlay(RoundedRectangle(cornerRadius: 28).stroke(PantryStyle.ink, lineWidth: 3))
  }
  private func join() {
    if code.count >= 4 && !busy { client.connect(intent: .join(code: code)) }
  }
}

struct LobbyView: View {
  @Bindable var client: GameClient
  @State private var copied = false
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        ViewThatFits(in: .horizontal) {
          HStack {
            heading
            Spacer()
            actions
          }
          VStack(alignment: .leading) {
            heading
            actions
          }
        }
        PantryCard {
          VStack(alignment: .leading, spacing: 16) {
            Text("THE CREW").font(PantryStyle.font(15, weight: "Black"))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 245))], spacing: 12) {
              ForEach(0..<4) { slot in playerRow(slot) }
            }
            if client.isHost {
              HStack {
                Button("Add bot") { client.send(.room(.addBot)) }
                  .disabled((client.room?.players.count ?? 0) >= 4)
                Button("Remove bot") { client.send(.room(.removeBot)) }
                  .disabled(!(client.room?.players.contains(where: \.bot) ?? false))
              }.buttonStyle(ArcadeButtonStyle(color: PantryStyle.basil))
            }
          }
        }
        Text("CHOOSE YOUR KITCHEN").font(PantryStyle.font(20, weight: "Black"))
        ScrollView(.horizontal) {
          HStack(spacing: 16) {
            ForEach(client.levels) { level in
              Button {
                client.send(.setLevel(level.id))
              } label: {
                VStack(alignment: .leading, spacing: 8) {
                  KitchenCanvas(level: level).frame(height: 140)
                    .background(Color(hex: level.accent).opacity(0.15))
                  Text(level.name).font(PantryStyle.font(16, weight: "Black"))
                  Text(level.tagline).font(PantryStyle.font(12))
                  Stars(count: client.bestStars[level.id] ?? 0)
                }
                .padding(12).frame(width: 224)
                .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                  RoundedRectangle(cornerRadius: 18)
                    .stroke(
                      client.room?.level == level.id ? PantryStyle.paprika : .clear, lineWidth: 3))
              }.buttonStyle(.plain).disabled(!client.isHost)
            }
          }.padding(4)
        }
        if let level = client.level {
          PantryCard {
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                Text(level.name).font(PantryStyle.font(26, weight: "Black"))
                Spacer()
                Label(
                  "\(level.roundSeconds / 60):\(String(format: "%02d", level.roundSeconds % 60))",
                  systemImage: "timer")
              }
              Text(level.gimmick).foregroundStyle(.secondary)
              ViewThatFits(in: .horizontal) {
                HStack {
                  menu(level)
                  Spacer()
                  thresholds(level)
                }
                VStack(alignment: .leading, spacing: 12) {
                  menu(level)
                  thresholds(level)
                }
              }
            }
          }
        }
        ViewThatFits(in: .horizontal) {
          HStack {
            readyButtons
            Spacer()
            Text("Everyone ready? Let's cook!").foregroundStyle(.secondary)
          }
          VStack { readyButtons }
        }
      }.padding(24).frame(maxWidth: 1120).frame(maxWidth: .infinity)
    }
  }
  private var heading: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text("KITCHEN \(client.room?.code ?? "")").font(PantryStyle.font(32, weight: "Black"))
      Button(copied ? "Copied!" : "Copy room code") {
        PlatformActions.copy(client.room?.code ?? "")
        copied = true
      }.buttonStyle(.plain).foregroundStyle(PantryStyle.basil)
    }
  }
  private var actions: some View {
    HStack {
      Text("\(client.rtt) ms").font(.custom("JetBrainsMono-Medium", size: 12))
      Button {
        client.showHelp = true
      } label: {
        Image(systemName: "questionmark.circle").frame(width: 32, height: 32)
      }
      .buttonStyle(.plain).accessibilityLabel("How to play")
      ThemeButton(client: client)
      Button("Leave") { client.leave() }.buttonStyle(ArcadeButtonStyle(color: PantryStyle.ink))
    }
  }
  private var readyButtons: some View {
    HStack {
      Button(client.ready ? "Not ready" : "Ready!") { client.send(.ready(!client.ready)) }
        .buttonStyle(ArcadeButtonStyle(color: client.ready ? PantryStyle.ink : PantryStyle.basil))
      if client.isHost {
        Button("Start cooking") { client.send(.room(.start)) }
          .buttonStyle(ArcadeButtonStyle()).disabled(!client.canStart)
      } else {
        Text("Waiting for the host").font(PantryStyle.font(13))
      }
    }
  }
  private func playerRow(_ slot: Int) -> some View {
    let player = client.room?.players.first { $0.slot == slot }
    return HStack {
      ChefPortrait(slot: slot, bot: player?.bot ?? false).frame(width: 45, height: 65)
        .opacity(player == nil ? 0.25 : 1)
      VStack(alignment: .leading) {
        Text(player.map { $0.name + ($0.id == client.playerID ? " (you)" : "") } ?? "Open seat")
          .font(PantryStyle.font(16, weight: "ExtraBold"))
        Text(
          player.map { $0.bot ? "Server bot" : ($0.connected ? $0.platform : "Reconnecting…") }
            ?? "Invite a friend"
        )
        .font(PantryStyle.font(12)).foregroundStyle(.secondary)
      }
      Spacer()
      if let player {
        if player.id == client.room?.hostId {
          Image(systemName: "crown.fill").foregroundStyle(PantryStyle.butter)
        }
        Image(systemName: player.ready ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(player.ready ? PantryStyle.basil : .gray)
          .accessibilityLabel(player.ready ? "Ready" : "Not ready")
      }
    }
    .padding(12).background(
      PantryStyle.chefs[slot].opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
  }
  private func menu(_ level: Level) -> some View {
    HStack {
      ForEach(level.menu, id: \.self) { dish in
        Label(dish.label, systemImage: dish.cooked ? "flame" : "leaf").font(PantryStyle.font(12))
      }
    }
  }
  private func thresholds(_ level: Level) -> some View {
    HStack {
      ForEach(
        Array(level.thresholds(players: client.room?.players.count ?? 1).enumerated()), id: \.offset
      ) { index, value in
        VStack {
          Stars(count: index + 1, size: 12)
          Text("\(value)").font(PantryStyle.font(12))
        }
      }
    }
  }
}
