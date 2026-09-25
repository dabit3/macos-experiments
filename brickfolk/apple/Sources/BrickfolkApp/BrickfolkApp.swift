import BrickfolkCore
import SwiftUI

@main
struct BrickfolkApp: App {
  @StateObject private var client = Client()
  init() { BrandFonts.register() }
  var body: some Scene {
    WindowGroup {
      RootView().environmentObject(client)
        .preferredColorScheme(
          client.theme == "system" ? nil : client.theme == "light" ? .light : .dark
        )
        .font(.custom("Inter-Regular", size: 14))
        .tint(.sky)
        #if os(macOS)
          .frame(minWidth: 560, minHeight: 500)
        #endif
    }
    #if os(macOS)
      .defaultSize(width: 1220, height: 820)
    #endif
  }
}

struct RootView: View {
  @EnvironmentObject private var client: Client
  @Environment(\.colorScheme) private var scheme
  @Environment(\.scenePhase) private var phase
  var body: some View {
    VStack(spacing: 0) {
      if let error = client.error ?? client.contentError {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
          Text(error).font(.callout).textSelection(.enabled)
          Spacer(minLength: 4)
          Button {
            client.error = nil
          } label: {
            Image(systemName: "xmark")
          }
          .accessibilityLabel("Dismiss error")
        }
        .padding(12).foregroundStyle(.white).background(Color.red.opacity(0.8))
      }
      if client.me == nil {
        SignInView()
      } else if let room = client.room {
        RoomView(room: room)
      } else {
        HubView()
      }
      if client.me != nil && client.status != .connected {
        HStack {
          ProgressView().controlSize(.small)
          Text("\(client.status.rawValue) · your seat is held for 30 seconds")
          Button("Retry") { client.reconnect() }
          Button("Sign out") { client.signOut() }
        }.padding(10).font(.caption).background(.regularMaterial)
      }
      if client.config.phaseMarker {
        Text("BRICKFOLK \(client.room?.phase.rawValue ?? client.selectedTab)")
          .font(.system(size: 10, design: .monospaced)).padding(3)
      }
    }
    .background(scheme == .dark ? Color.ink : Color(argb: 0xFFF1_F3FC))
    .task { client.start() }
    .onChange(of: phase) { _, phase in
      #if os(iOS)
        if phase == .background { client.pause() }
        if phase == .active { client.resume() }
      #endif
    }
    .sheet(
      isPresented: Binding(
        get: { client.requestedSheet != nil }, set: { if !$0 { client.requestedSheet = nil } })
    ) {
      NavigationStack {
        ScrollView {
          if let error = client.error {
            Label(error, systemImage: "exclamationmark.triangle.fill")
              .font(.callout).foregroundStyle(.red).padding(.bottom, 12)
              .textSelection(.enabled)
          }
          switch client.requestedSheet {
          case "settings": SettingsView()
          case "daily": DailyView()
          case "profile":
            if let profile = client.viewedProfile {
              ProfileView(profile: profile)
            } else {
              ProgressView("Loading profile…").padding(60)
            }
          case "chat":
            ChatView(initialChannel: client.room == nil ? .global : .room).frame(minHeight: 400)
          default: EmptyView()
          }
        }
        .padding()
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { client.requestedSheet = nil }
          }
        }
      }
      .frame(minWidth: 300, idealWidth: 600, minHeight: 400, idealHeight: 660)
      .environmentObject(client)
    }
  }
}

struct SignInView: View {
  @EnvironmentObject private var client: Client
  @State private var name = UserDefaults.standard.string(forKey: "session.name") ?? ""
  var body: some View {
    GeometryReader { bounds in
      ScrollView {
        VStack(spacing: 28) {
          BrickLogo().padding(.top, 30)
          Image("skyline").resizable().scaledToFill()
            .frame(height: min(260, bounds.size.height * 0.28)).clipped()
            .overlay(alignment: .bottomLeading) {
              Text("Small bricks.\nBig adventures.").font(.custom("Inter-ExtraBold", size: 32))
                .foregroundStyle(.white).shadow(radius: 10).padding(24)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
          Panel {
            VStack(alignment: .leading, spacing: 18) {
              Text("Welcome to Brickfolk").font(.custom("Inter-Bold", size: 24))
              Text("Pick a name, bring a friend, find your next favourite place.").foregroundStyle(
                .secondary)
              TextField("Player name", text: $name).textFieldStyle(.roundedBorder)
                .onSubmit(connect)
                .accessibilityIdentifier("signin.name")
              Text("3–16 characters · letters, numbers and underscores").font(.caption)
                .foregroundStyle(.secondary)
              DisclosureGroup("Server connection") {
                TextField("ws://localhost:8080/ws", text: $client.serverURL)
                  .textFieldStyle(.roundedBorder).padding(.top, 8)
                  .autocorrectionDisabled()
                  .accessibilityIdentifier("signin.server")
              }
              Button(action: connect) {
                HStack {
                  Text(client.status == .offline ? "Let's play" : client.status.rawValue)
                  Spacer()
                  Image(systemName: "arrow.right")
                }
              }.buttonStyle(BrickButtonStyle(color: .brick))
                .disabled(client.status == .connecting || client.status == .reconnecting)
                .accessibilityIdentifier("signin.connect")
              if client.status == .connecting || client.status == .reconnecting {
                Button("Cancel connection") { client.pause() }
              } else if client.hasLegacySession {
                Text(
                  "A previous Brickfolk session is saved on this device. Set the server above to the same server you used before, then restore it."
                )
                .font(.caption).foregroundStyle(.secondary)
                Button("Restore previous Apple session") { client.restorePreviousSession() }
              }
            }
          }
          Text("Your profile, Pips and collection stay with your saved session on this device.")
            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(22).frame(maxWidth: 560).frame(maxWidth: .infinity)
      }
    }
  }
  private func connect() { client.signIn(name: name) }
}

struct HubView: View {
  @EnvironmentObject private var client: Client
  private let tabs = [
    ("places", "Places", "square.grid.2x2.fill"), ("avatar", "Avatar", "person.crop.square"),
    ("social", "Friends", "person.2.fill"), ("profile", "Profile", "person.crop.circle"),
  ]
  var body: some View {
    GeometryReader { geometry in
      let wide = geometry.size.width >= 850
      HStack(spacing: 0) {
        if wide {
          VStack(alignment: .leading, spacing: 26) {
            BrickLogo().padding(.bottom, 24)
            ForEach(tabs, id: \.0) { tab in tabButton(tab, compact: false) }
            Spacer()
            Button {
              client.requestedSheet = "settings"
            } label: {
              Label("Settings", systemImage: "gearshape")
            }
            Text("Made of possibilities.").font(.caption).foregroundStyle(.secondary)
          }.padding(24).frame(width: 218).background(.primary.opacity(0.025))
        }
        VStack(spacing: 0) {
          HStack(spacing: 14) {
            if !wide { BrickLogo().scaleEffect(0.8, anchor: .leading).frame(width: 132) }
            Spacer(minLength: 0)
            Button {
              client.requestedSheet = "daily"
            } label: {
              Label("\(client.me?.pips ?? 0)", systemImage: "diamond.fill").foregroundStyle(
                Color.sun)
            }.help("Pips and daily reward")
            Button {
              client.requestedSheet = "chat"
            } label: {
              Image(systemName: "bubble.left.and.bubble.right")
            }
            .accessibilityLabel("Open chat")
            Button {
              client.requestedSheet = "settings"
            } label: {
              Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
          }.font(.title3).padding(20)
          Group {
            switch client.selectedTab {
            case "avatar": AvatarEditor()
            case "social": SocialView()
            case "profile":
              ScrollView { if let me = client.me { ProfileView(profile: me).padding(22) } }
            default: PlacesView()
            }
          }.frame(maxWidth: .infinity, maxHeight: .infinity)
          if !wide {
            HStack(spacing: 0) {
              ForEach(tabs, id: \.0) { tab in
                tabButton(tab, compact: true).frame(maxWidth: .infinity)
              }
            }.padding(.vertical, 10).background(.regularMaterial)
          }
        }
      }
    }
  }
  private func tabButton(_ tab: (String, String, String), compact: Bool) -> some View {
    Button {
      client.selectedTab = tab.0
    } label: {
      Group {
        if compact {
          VStack(spacing: 5) {
            Image(systemName: tab.2).font(.title3)
            Text(tab.1).font(.caption)
          }
        } else {
          Label(tab.1, systemImage: tab.2).font(.custom("Inter-SemiBold", size: 16))
        }
      }
      .foregroundStyle(client.selectedTab == tab.0 ? Color.sky : .secondary)
      .padding(compact ? 7 : 12)
      .background(
        client.selectedTab == tab.0 ? Color.sky.opacity(0.12) : .clear,
        in: RoundedRectangle(cornerRadius: 12))
    }.buttonStyle(.plain).accessibilityIdentifier("tab.\(tab.0)")
  }
}

struct PlacesView: View {
  @EnvironmentObject private var client: Client
  @State private var search = ""
  @State private var code = ""
  @State private var bots = 2
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        HStack {
          VStack(alignment: .leading, spacing: 6) {
            Text("Hey, \(client.me?.name ?? "builder").").font(.custom("Inter-ExtraBold", size: 28))
            Text("Where will you go today?").foregroundStyle(.secondary)
          }
          Spacer()
          if let avatar = client.me?.avatar { AvatarView(avatar: avatar, size: 68) }
        }
        HStack {
          Image(systemName: "magnifyingglass")
          TextField("Search places", text: $search).textFieldStyle(.plain)
          Text("\(client.onlineCount) online").font(.caption).foregroundStyle(.secondary)
        }.padding(14).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        if let party = client.party {
          Panel {
            VStack(alignment: .leading, spacing: 8) {
              Label(
                "Party \(party.code) · \(party.members.count) friends", systemImage: "person.2.fill"
              )
              .foregroundStyle(Color.mint)
              Text(
                client.isLeader
                  ? "Choose a place to bring your party along."
                  : "Your leader will launch the next adventure.")
              Button("Manage party") { client.selectedTab = "social" }
            }
          }
        }
        HStack {
          Text("Pick your next adventure").font(.custom("Inter-Bold", size: 22))
          Spacer()
          Button {
            client.send(.places)
          } label: {
            Image(systemName: "arrow.clockwise")
          }.help("Refresh places")
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 18)], spacing: 18) {
          ForEach(
            client.content?.places.filter {
              search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
            } ?? []
          ) { place in
            PlaceCard(place: place, listing: client.places.first { $0.kind == place.kind }) {
              client.placeSelection = place.kind
            }
          }
        }
        if !(client.content?.places.contains {
          search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
        } ?? false) {
          ContentUnavailableView.search(text: search)
        }
        Panel {
          VStack(alignment: .leading, spacing: 14) {
            Label("Got a room code?", systemImage: "ticket").font(.headline)
            HStack {
              TextField("ABCD", text: $code).textFieldStyle(.roundedBorder).onSubmit(join)
              Button("Join", action: join).buttonStyle(BrickButtonStyle())
                .disabled(code.trimmingCharacters(in: .whitespaces).count != 4)
            }
            Text("Jump into a friend's room. Late arrivals can spectate until the next round.")
              .font(.caption).foregroundStyle(.secondary)
          }
        }
      }.padding(22).frame(maxWidth: 1200).frame(maxWidth: .infinity)
    }
    .onAppear { bots = client.config.bots }
    .sheet(item: $client.placeSelection) { experience in
      NavigationStack {
        ScrollView {
          if let error = client.error {
            Label(error, systemImage: "exclamationmark.triangle.fill")
              .font(.callout).foregroundStyle(.red).padding()
          }
          if let place = client.content?.places.first(where: { $0.kind == experience }) {
            VStack(alignment: .leading, spacing: 20) {
              Image(place.kind.artwork).resizable().scaledToFill().frame(height: 210).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18))
              Text(place.name).font(.custom("Inter-ExtraBold", size: 28))
              Text(place.description)
              let listing = client.places.first { $0.kind == experience }
              HStack {
                Button {
                  client.send(.rate(experience, listing?.myVote == true ? nil : true))
                } label: {
                  Label(
                    "\(listing?.likes ?? 0)",
                    systemImage: listing?.myVote == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                }
                Button {
                  client.send(.rate(experience, listing?.myVote == false ? nil : false))
                } label: {
                  Label(
                    "\(listing?.dislikes ?? 0)",
                    systemImage: listing?.myVote == false
                      ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                }
                Spacer()
                Text("\(listing?.visits ?? 0) visits").foregroundStyle(.secondary)
              }
              Stepper("Bots: \(bots)", value: $bots, in: 0...7)
              Button(client.party != nil && client.isLeader ? "Play with party" : "Create room") {
                if client.party != nil && client.isLeader {
                  client.send(.partyLaunch(experience, bots: bots))
                } else {
                  client.send(.roomCreate(experience, bots: bots))
                }
                client.placeSelection = nil
              }.buttonStyle(BrickButtonStyle(color: Color(argb: place.accent)))
              Text("Open rooms").font(.headline)
              if listing?.rooms.isEmpty != false {
                Text("No rooms yet. Start one above.").foregroundStyle(.secondary)
              }
              ForEach(listing?.rooms ?? []) { room in
                HStack {
                  Text(room.code).font(.headline).textSelection(.enabled)
                  Text("\(room.players)/8 · \(room.phase.rawValue)").font(.caption)
                  Spacer()
                  Button("Join") {
                    client.send(.roomJoin(room.code))
                    client.placeSelection = nil
                  }
                  .disabled(room.players >= 8)
                }.padding(.vertical, 8)
              }
            }.padding(22)
          }
        }.toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { client.placeSelection = nil }
          }
        }
      }.frame(minWidth: 300, idealWidth: 600, minHeight: 480)
        .environmentObject(client)
    }
  }
  private func join() {
    client.send(.roomJoin(code.trimmingCharacters(in: .whitespacesAndNewlines)))
  }
}

struct PlaceCard: View {
  let place: PlaceInfo
  let listing: PlaceListing?
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 0) {
        Image(place.kind.artwork).resizable().scaledToFill().frame(height: 178).clipped()
          .overlay(alignment: .topLeading) {
            Text(
              place.kind == .obby
                ? "OBSTACLE COURSE" : place.kind == .tag ? "TEAM SURVIVAL" : "BUILD & EARN"
            )
            .font(.custom("Inter-Bold", size: 10)).tracking(1)
            .padding(9).background(.black.opacity(0.45), in: Capsule()).foregroundStyle(.white)
            .padding(14)
          }
        VStack(alignment: .leading, spacing: 9) {
          Text(place.name).font(.custom("Inter-Bold", size: 20))
          Text(place.tagline).font(.callout).foregroundStyle(.secondary)
          HStack {
            Circle().fill(Color.mint).frame(width: 7, height: 7)
            Text("\(listing?.playing ?? 0) playing").font(.caption)
            Spacer()
            Image(systemName: "arrow.up.right").foregroundStyle(Color(argb: place.accent))
          }.padding(.top, 5)
        }.padding(18)
      }.background(.primary.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.primary.opacity(0.07)))
    }.buttonStyle(.plain).accessibilityIdentifier("place.\(place.kind.rawValue)")
  }
}
