import CoreText
import HearthCore
import ImageIO
import SwiftUI

@main struct HearthApp: App {
  @StateObject private var preferences: Preferences
  @StateObject private var session: Session
  @StateObject private var game: Game
  init() {
    let preferences = Preferences()
    let session: Session
    session = Session(preferences: preferences)
    _preferences = StateObject(wrappedValue: preferences)
    _session = StateObject(wrappedValue: session)
    _game = StateObject(wrappedValue: Game(session))
    for name in ["Outfit-Variable", "PixelifySans-Variable", "Fraunces-Variable"] {
      if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
      }
    }
  }
  var body: some Scene {
    WindowGroup {
      RootView(session: session, game: game)
        .environmentObject(preferences)
        .preferredColorScheme(
          preferences.theme == "system" ? nil : preferences.theme == "light" ? .light : .dark
        )
        .tint(Hearth.gold)
        #if os(macOS)
          .frame(minWidth: 700, minHeight: 500)
        #endif
    }
    #if os(macOS)
      .defaultSize(width: 1200, height: 780)
      .commands { CommandGroup(replacing: .newItem) {} }
    #endif
  }
}

enum Hearth {
  static let ink = Color(red: 7 / 255, green: 30 / 255, blue: 43 / 255)
  static let navy = Color(red: 16 / 255, green: 46 / 255, blue: 59 / 255)
  static let gold = Color(red: 1, green: 204 / 255, blue: 117 / 255)
  static let cream = Color(red: 1, green: 244 / 255, blue: 220 / 255)
  static let teal = Color(red: 112 / 255, green: 226 / 255, blue: 196 / 255)
  static let muted = Color(red: 169 / 255, green: 197 / 255, blue: 205 / 255)
  static func type(_ size: CGFloat) -> Font { .custom("Outfit", size: size, relativeTo: .body) }
  static func pixel(_ size: CGFloat) -> Font {
    .custom("PixelifySans-Regular", size: size, relativeTo: .title)
  }
}

struct HearthButton: ButtonStyle {
  var primary = false
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(Hearth.type(16).weight(.semibold))
      .padding(.horizontal, 16).padding(.vertical, 12)
      .foregroundStyle(primary ? Hearth.ink : Hearth.cream)
      .background(primary ? Hearth.gold : Hearth.navy)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8).stroke(
          primary ? Hearth.gold : Hearth.teal.opacity(0.4), lineWidth: 1)
      )
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .opacity(enabled ? 1 : 0.4)
  }
}

extension View {
  func panel() -> some View {
    padding(20).background(Hearth.ink.opacity(0.94))
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(Hearth.teal.opacity(0.3)))
  }
}

struct Backdrop: View {
  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Hearth.ink
        if let url = Bundle.main.url(forResource: "hearth-keyart", withExtension: "png"),
          let image = imageAt(url)
        {
          Image(decorative: image, scale: 1).resizable().scaledToFill()
            .frame(width: proxy.size.width, height: proxy.size.height).clipped()
        }
        LinearGradient(
          colors: [Hearth.ink.opacity(0.96), Hearth.ink.opacity(0.2), Hearth.ink.opacity(0.8)],
          startPoint: .leading, endPoint: .trailing)
      }
    }.ignoresSafeArea()
  }
  private func imageAt(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
  }
}

struct RootView: View {
  @ObservedObject var session: Session
  @ObservedObject var game: Game
  @EnvironmentObject var preferences: Preferences
  @Environment(\.scenePhase) private var scenePhase
  @State private var options = false
  var body: some View {
    ZStack {
      if session.code != nil && session.phase != "lobby" {
        GameScreen(session: session, game: game, options: $options)
      } else {
        Backdrop()
        if session.code == nil {
          HomeScreen(session: session, options: $options)
        } else {
          LobbyScreen(session: session, options: $options)
        }
      }
    }
    .font(Hearth.type(16)).foregroundStyle(Hearth.cream)
    .buttonStyle(HearthButton())
    .sheet(isPresented: $options) { SettingsScreen().environmentObject(preferences) }
    .alert(
      "VoxelHearth",
      isPresented: Binding(get: { session.error != nil }, set: { if !$0 { session.error = nil } })
    ) {
      Button("OK") { session.error = nil }
      if session.connection == .failed { Button("Reconnect") { session.connect() } }
    } message: {
      Text(session.error ?? "")
    }
    .task { if session.connection == .idle { session.connect() } }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active {
        game.resetInput()
        if session.phase == "playing" { game.paused = true }
      }
      if phase == .active && session.connection == .failed { session.connect() }
    }
  }
}

struct HomeScreen: View {
  @ObservedObject var session: Session
  @EnvironmentObject var preferences: Preferences
  @Binding var options: Bool
  @State private var joinCode = ""
  @State private var create = false
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        HStack {
          Label("VOXELHEARTH", systemImage: "flame.fill").font(Hearth.pixel(42)).foregroundStyle(
            Hearth.gold
          )
          .minimumScaleFactor(0.6).lineLimit(1)
          Spacer()
          Button {
            options = true
          } label: {
            Image(systemName: "gearshape.fill")
          }.accessibilityLabel("Settings")
        }
        Text("A WORLD WORTH BUILDING TOGETHER").tracking(2).foregroundStyle(Hearth.teal)
        Text("Gather. Craft. Explore. Make a home.").font(Hearth.type(24))
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: 20) {
            connectionForm.frame(width: 340)
            roomList.frame(minWidth: 300)
          }
          VStack(spacing: 20) {
            connectionForm
            roomList
          }
        }
        HStack {
          Text("NATIVE APPLE EDITION").font(Hearth.type(12)).tracking(2)
          Spacer()
          Text("Live multiplayer • Seeded worlds").font(Hearth.type(12))
        }.foregroundStyle(Hearth.muted)
      }.padding(24).frame(maxWidth: 1040)
    }
    .sheet(isPresented: $create) { RoomEditor(session: session, creating: true) }
  }
  private var connectionForm: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Your next adventure").font(Hearth.type(26))
      TextField("Player name", text: $preferences.name).textFieldStyle(.roundedBorder)
        .foregroundStyle(Color.primary)
        .accessibilityIdentifier("player-name")
      TextField("ws://server:8787/ws", text: $preferences.server).textFieldStyle(.roundedBorder)
        .foregroundStyle(Color.primary)
        .autocorrectionDisabled().accessibilityIdentifier("server-url")
      HStack {
        Circle().fill(session.online ? Hearth.teal : Hearth.gold).frame(width: 8, height: 8)
        Text(session.connection.rawValue.capitalized)
        Spacer()
        Button("Connect") { session.connect() }.accessibilityIdentifier("connect")
      }
      Button("Create World") { create = true }.buttonStyle(HearthButton(primary: true)).disabled(
        !session.online)
      Divider()
      HStack {
        TextField("5-letter code", text: $joinCode).textFieldStyle(.roundedBorder)
          .foregroundStyle(Color.primary)
          .autocorrectionDisabled().accessibilityIdentifier("join-code")
        Button("Join") { session.join(joinCode) }.disabled(
          !session.online || joinCode.trimmingCharacters(in: .whitespaces).count != 5)
      }
    }.panel()
  }
  private var roomList: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Open worlds").font(Hearth.type(26))
        Spacer()
        Button {
          session.send(.listRooms)
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .disabled(!session.online).accessibilityLabel("Refresh worlds")
      }
      if session.rooms.isEmpty {
        Text(
          session.online ? "No worlds yet. Light the first hearth." : "Connect to discover worlds."
        )
        .foregroundStyle(Hearth.muted).padding(.vertical, 24)
      }
      ForEach(session.rooms) { room in
        Button {
          session.join(room.code)
        } label: {
          HStack {
            VStack(alignment: .leading) {
              Text(room.name).font(Hearth.type(20))
              Text("\(room.mode.capitalized) • \(room.phase) • \(room.players) players").font(
                Hearth.type(13))
            }
            Spacer()
            Text(room.code).font(Hearth.pixel(20))
          }.frame(maxWidth: .infinity, alignment: .leading)
        }.disabled(!session.online)
      }
    }.frame(maxWidth: .infinity, alignment: .leading).panel()
  }
}

struct RoomEditor: View {
  @ObservedObject var session: Session
  let creating: Bool
  @Environment(\.dismiss) private var dismiss
  @State private var name = "Our Hearth"
  @State private var seed = "424242"
  @State private var mode = "survival"
  @State private var bots = 0
  @State private var minutes = 0
  @State private var frozen = false
  @State private var creatures = true
  var body: some View {
    NavigationStack {
      Form {
        Section("World") {
          TextField("World name", text: $name)
          if creating { TextField("Seed", text: $seed) }
          Picker("Mode", selection: $mode) {
            Text("Survival").tag("survival")
            Text("Creative").tag("creative")
          }
          Stepper(
            minutes == 0 ? "Free play" : "\(minutes) minute match", value: $minutes, in: 0...200,
            step: 5)
          if creating { Stepper("\(bots) bots", value: $bots, in: 0...6) }
          Toggle("Creatures", isOn: $creatures)
          Toggle("Freeze day / night", isOn: $frozen)
        }
        Section {
          Text(
            "Survival: gather resources, craft tools and survive the night. Creative: every block, instant building and flight."
          )
        }
      }
      .formStyle(.grouped)
      .navigationTitle(creating ? "Create World" : "World Settings")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(creating ? "Create" : "Save") {
            var message = ClientMessage(creating ? .createRoom : .roomSettings)
            message.name = name
            message.mode = mode
            message.durationTicks = minutes * 60 * 20
            message.freezeTime = frozen
            message.spawnMobs = creatures
            if creating {
              message.seed = Int(seed)
              message.bots = bots
            }
            session.send(message)
            dismiss()
          }.disabled(
            !session.online || name.trimmingCharacters(in: .whitespaces).isEmpty
              || (creating && Int(seed) == nil))
        }
      }
    }
    .foregroundStyle(Color.primary)
    .tint(.accentColor)
    #if os(macOS)
      .frame(width: 560, height: 620)
    #endif
    .onAppear {
      if !creating {
        name = session.roomName
        mode = session.mode
        frozen = session.freezeTime
        creatures = session.spawnMobs
        minutes = session.duration / 1200
      }
    }
  }
}

struct LobbyScreen: View {
  @ObservedObject var session: Session
  @Binding var options: Bool
  @State private var rules = false
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          Button("Leave") { session.leave() }
          Spacer()
          Button("Settings") { options = true }
        }
        Text(session.roomName).font(Hearth.pixel(42))
        HStack {
          Text("INVITE YOUR FRIENDS").font(Hearth.type(12)).tracking(2)
          Text(session.code ?? "").font(Hearth.pixel(30)).foregroundStyle(Hearth.gold)
            .textSelection(.enabled)
          ShareLink(item: session.code ?? "") { Image(systemName: "square.and.arrow.up") }
        }
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: 20) {
            roster.frame(width: 360)
            ChatPanel(session: session).frame(width: 360, height: 340)
          }
          VStack(spacing: 20) {
            roster
            ChatPanel(session: session).frame(height: 280)
          }
        }
        HStack {
          Button(
            (session.players.first { $0.id == session.playerID }?.ready ?? false)
              ? "Not Ready" : "Ready"
          ) {
            var message = ClientMessage(.ready)
            message.ready = !(session.players.first { $0.id == session.playerID }?.ready ?? false)
            session.send(message)
            session.feedback.play("ready")
          }.disabled(!session.online)
          if session.isHost {
            Button("Start Exploring") { session.send(.startMatch) }.buttonStyle(
              HearthButton(primary: true)
            ).disabled(!session.online)
          }
        }
        Text(
          session.isHost
            ? "You are the host. Start whenever your party is ready."
            : "Waiting for the host to begin."
        )
        .foregroundStyle(Hearth.muted)
      }.padding(24).frame(maxWidth: 920)
    }.sheet(isPresented: $rules) { RoomEditor(session: session, creating: false) }
  }
  private var roster: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Around the hearth").font(Hearth.type(25))
      ForEach(session.players) { player in
        HStack {
          Image(systemName: player.bot == true ? "cpu" : "person.fill").foregroundStyle(Hearth.teal)
          VStack(alignment: .leading) {
            Text(player.name ?? "Wanderer")
            Text(
              "\(player.platform ?? "")\(player.id == session.host ? " • HOST" : "")\(player.id == session.playerID ? " • YOU" : "")"
            )
            .font(Hearth.type(11)).foregroundStyle(Hearth.muted)
          }
          Spacer()
          Text(player.connected == false ? "Offline" : player.ready == true ? "Ready" : "Preparing")
            .font(Hearth.type(12)).foregroundStyle(
              player.ready == true ? Hearth.teal : Hearth.muted)
        }
      }
      Divider()
      Text(
        "\(session.mode.capitalized) • \(session.duration == 0 ? "Free play" : "\(session.duration / 1200) minutes")"
      )
      if session.isHost {
        HStack {
          Button("+ Bot") { session.send(.addBot) }
          Button("− Bot") { session.send(.removeBot) }.disabled(
            !session.players.contains { $0.bot == true })
        }
        Button("World Settings") { rules = true }
      }
    }.panel()
  }
}
