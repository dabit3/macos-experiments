import CoreText
import HearthCore
import ImageIO
import SwiftUI

#if canImport(UIKit)
  import UIKit
#else
  import AppKit
#endif

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
    for name in ["Outfit-Variable", "PixelifySans-Variable"] {
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
  static let surface = Color(red: 10 / 255, green: 37 / 255, blue: 51 / 255)
  static let gold = Color(red: 1, green: 204 / 255, blue: 117 / 255)
  static let cream = Color(red: 1, green: 244 / 255, blue: 220 / 255)
  static let teal = Color(red: 112 / 255, green: 226 / 255, blue: 196 / 255)
  static let muted = Color(red: 169 / 255, green: 197 / 255, blue: 205 / 255)
  static let danger = Color(red: 1, green: 128 / 255, blue: 112 / 255)
  static let line = Color.white.opacity(0.1)
  static func type(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .custom("Outfit", size: size, relativeTo: .body).weight(weight)
  }
  static func pixel(_ size: CGFloat) -> Font {
    .custom("PixelifySans-Regular", size: size, relativeTo: .title)
  }
  static func mono(_ size: CGFloat) -> Font { .system(size: size, design: .monospaced) }
}

struct HearthButton: ButtonStyle {
  enum Kind { case primary, secondary, quiet, danger }
  var kind: Kind = .secondary
  var compact = false
  var wide = false
  init(_ kind: Kind = .secondary, compact: Bool = false, wide: Bool = false) {
    self.kind = kind
    self.compact = compact
    self.wide = wide
  }
  init(primary: Bool) { kind = primary ? .primary : .secondary }
  func makeBody(configuration: Configuration) -> some View {
    HearthButtonBody(configuration: configuration, kind: kind, compact: compact, wide: wide)
  }
}

private struct HearthButtonBody: View {
  let configuration: ButtonStyleConfiguration
  let kind: HearthButton.Kind
  let compact: Bool
  let wide: Bool
  @Environment(\.isEnabled) private var enabled
  @State private var hovering = false
  var body: some View {
    let shape = RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous)
    configuration.label
      .font(Hearth.type(compact ? 14 : 16, .semibold))
      .lineLimit(1)
      .padding(.horizontal, compact ? 12 : 18)
      .frame(minHeight: compact ? 34 : 46)
      .frame(maxWidth: wide ? .infinity : nil)
      .foregroundStyle(foreground)
      .background(shape.fill(fill.opacity(configuration.isPressed ? 0.8 : hovering ? 0.92 : 1)))
      .overlay(shape.strokeBorder(border, lineWidth: 1))
      .overlay(
        shape.strokeBorder(Color.white.opacity(hovering && enabled ? 0.18 : 0), lineWidth: 1)
      )
      .contentShape(shape)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .opacity(enabled ? 1 : 0.4)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
      .onHover { hovering = $0 }
  }
  private var foreground: Color {
    switch kind {
    case .primary: Hearth.ink
    case .secondary: Hearth.cream
    case .quiet: Hearth.muted
    case .danger: Hearth.danger
    }
  }
  private var fill: Color {
    switch kind {
    case .primary: Hearth.gold
    case .secondary: Hearth.navy
    case .quiet: Color.white.opacity(0.001)
    case .danger: Hearth.danger.opacity(0.12)
    }
  }
  private var border: Color {
    switch kind {
    case .primary: Hearth.gold
    case .secondary: Hearth.teal.opacity(0.28)
    case .quiet: .clear
    case .danger: Hearth.danger.opacity(0.35)
    }
  }
}

struct IconButton: View {
  let symbol: String
  let label: String
  var prominent = false
  let action: () -> Void
  init(_ symbol: String, _ label: String, prominent: Bool = false, action: @escaping () -> Void) {
    self.symbol = symbol
    self.label = label
    self.prominent = prominent
    self.action = action
  }
  var body: some View {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
        .frame(width: 44, height: 44)
        .foregroundStyle(prominent ? Hearth.ink : Hearth.cream)
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(prominent ? Hearth.gold : Hearth.ink.opacity(0.72))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Hearth.line)
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .help(label)
  }
}

struct Chip: View {
  let text: String
  var symbol: String?
  var tint = Hearth.muted
  init(_ text: String, symbol: String? = nil, tint: Color = Hearth.muted) {
    self.text = text
    self.symbol = symbol
    self.tint = tint
  }
  var body: some View {
    HStack(spacing: 5) {
      if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .bold)) }
      Text(text).font(Hearth.type(12, .semibold))
    }
    .padding(.horizontal, 8).padding(.vertical, 4)
    .foregroundStyle(tint)
    .background(Capsule().fill(tint.opacity(0.14)))
  }
}

struct ConnectionPill: View {
  @ObservedObject var session: Session
  var body: some View {
    HStack(spacing: 7) {
      if session.connection == .connecting || session.connection == .reconnecting {
        ProgressView().controlSize(.mini).tint(Hearth.gold)
      } else {
        Circle().fill(color).frame(width: 8, height: 8)
      }
      Text(label).font(Hearth.type(13, .medium))
    }
    .padding(.horizontal, 12).frame(height: 32)
    .foregroundStyle(Hearth.cream)
    .background(Capsule().fill(Hearth.ink.opacity(0.72)))
    .overlay(Capsule().strokeBorder(Hearth.line))
    .accessibilityElement(children: .combine)
  }
  private var label: String {
    switch session.connection {
    case .idle: "Not connected"
    case .connecting: "Connecting…"
    case .online: "Online"
    case .reconnecting: "Reconnecting…"
    case .failed: "Offline"
    }
  }
  private var color: Color {
    session.online ? Hearth.teal : session.connection == .failed ? Hearth.danger : Hearth.muted
  }
}

struct CardHeader<Trailing: View>: View {
  let title: String
  var detail: String?
  @ViewBuilder var trailing: Trailing
  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(title).font(Hearth.type(19, .semibold))
      if let detail { Text(detail).font(Hearth.type(14)).foregroundStyle(Hearth.muted) }
      Spacer(minLength: 8)
      trailing
    }
  }
}

extension CardHeader where Trailing == EmptyView {
  init(title: String, detail: String? = nil) {
    self.init(title: title, detail: detail) { EmptyView() }
  }
}

struct FieldLabel<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(Hearth.type(13, .medium)).foregroundStyle(Hearth.muted)
      content
    }
  }
}

struct Avatar: View {
  let name: String
  var bot = false
  var size: CGFloat = 36
  var body: some View {
    let hue = Double(name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 360 }) / 360
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        .fill(Color(hue: hue, saturation: 0.45, brightness: 0.5))
      if bot {
        Image(systemName: "cpu").font(.system(size: size * 0.42, weight: .semibold))
      } else {
        Text(String(name.prefix(1)).uppercased()).font(Hearth.pixel(size * 0.55))
      }
    }
    .foregroundStyle(Hearth.cream)
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

enum Clipboard {
  static func copy(_ text: String) {
    #if canImport(UIKit)
      UIPasteboard.general.string = text
    #else
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(text, forType: .string)
    #endif
  }
}

extension View {
  func panel(padding: CGFloat = 20) -> some View {
    self.padding(padding)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Hearth.surface.opacity(0.95))
      )
      .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Hearth.line))
      .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
  }
  func hearthField() -> some View {
    textFieldStyle(.plain)
      .font(Hearth.type(16))
      .foregroundStyle(Hearth.cream)
      .padding(.horizontal, 12)
      .frame(minHeight: 44)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Hearth.ink.opacity(0.8))
      )
      .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Hearth.line))
  }
}

func prompt(_ text: String) -> Text { Text(text).foregroundStyle(Hearth.muted.opacity(0.7)) }

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
          colors: [Hearth.ink.opacity(0.95), Hearth.ink.opacity(0.55), Hearth.ink.opacity(0.85)],
          startPoint: .leading, endPoint: .trailing)
        LinearGradient(
          colors: [.clear, Hearth.ink.opacity(0.9)], startPoint: .center, endPoint: .bottom)
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
            .transition(.opacity)
        } else {
          LobbyScreen(session: session, options: $options)
            .transition(.opacity)
        }
      }
    }
    .animation(.easeOut(duration: 0.2), value: session.code)
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

struct Wordmark: View {
  var size: CGFloat = 34
  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "flame.fill").font(.system(size: size * 0.7, weight: .bold))
      Text("VOXELHEARTH").font(Hearth.pixel(size)).lineLimit(1).minimumScaleFactor(0.6)
    }
    .foregroundStyle(Hearth.gold)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }
}

struct HomeScreen: View {
  @ObservedObject var session: Session
  @EnvironmentObject var preferences: Preferences
  @Binding var options: Bool
  @State private var joinCode = ""
  @State private var create = false
  @State private var serverOpen = false
  private var codeReady: Bool { joinCode.count == 5 }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        HStack(spacing: 10) {
          Wordmark()
          Spacer(minLength: 12)
          ConnectionPill(session: session)
          IconButton("gearshape.fill", "Settings") { options = true }
        }
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: 20) {
            playCard.frame(width: 380)
            worldsCard
          }
          VStack(spacing: 20) {
            playCard
            worldsCard
          }
        }
      }
      .padding(.horizontal, 24).padding(.vertical, 20)
      .frame(maxWidth: 1040)
      .frame(maxWidth: .infinity)
    }
    .scrollDismissesKeyboard(.interactively)
    .sheet(isPresented: $create) { RoomEditor(session: session, creating: true) }
    .onAppear { serverOpen = !session.online }
  }
  private var playCard: some View {
    VStack(alignment: .leading, spacing: 18) {
      CardHeader(title: "Play")
      FieldLabel(title: "Your name") {
        TextField("", text: $preferences.name, prompt: prompt("Wanderer"))
          .hearthField()
          .autocorrectionDisabled()
          .accessibilityIdentifier("player-name")
      }
      Button {
        create = true
      } label: {
        Label("Create a world", systemImage: "plus")
      }
      .buttonStyle(HearthButton(.primary, wide: true))
      .disabled(!session.online)
      .accessibilityIdentifier("create-world")
      HStack(spacing: 10) {
        Rectangle().fill(Hearth.line).frame(height: 1)
        Text("or join with a code").font(Hearth.type(13)).foregroundStyle(Hearth.muted)
          .fixedSize()
        Rectangle().fill(Hearth.line).frame(height: 1)
      }
      HStack(spacing: 10) {
        TextField("", text: $joinCode, prompt: prompt("ABCDE"))
          .hearthField()
          .font(Hearth.pixel(22))
          .autocorrectionDisabled()
          #if os(iOS)
            .textInputAutocapitalization(.characters)
          #endif
          .onChange(of: joinCode) { _, value in
            let clean = String(value.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(5))
            if clean != value { joinCode = clean }
          }
          .onSubmit { if codeReady && session.online { session.join(joinCode) } }
          .accessibilityLabel("Room code")
          .accessibilityIdentifier("join-code")
        Button("Join") { session.join(joinCode) }
          .disabled(!session.online || !codeReady)
          .accessibilityIdentifier("join")
      }
      if !session.online {
        Text("Connect to a server to create or join a world.")
          .font(Hearth.type(13)).foregroundStyle(Hearth.gold)
      }
      DisclosureGroup(isExpanded: $serverOpen) {
        VStack(alignment: .leading, spacing: 10) {
          TextField("", text: $preferences.server, prompt: prompt("ws://server:8787/ws"))
            .hearthField()
            .font(Hearth.mono(14))
            .autocorrectionDisabled()
            #if os(iOS)
              .textInputAutocapitalization(.never)
              .keyboardType(.URL)
            #endif
            .onSubmit { session.connect() }
            .accessibilityIdentifier("server-url")
          Button(session.online ? "Reconnect" : "Connect") { session.connect() }
            .buttonStyle(HearthButton(compact: true))
            .accessibilityIdentifier("connect")
        }
        .padding(.top, 10)
      } label: {
        HStack {
          Text("Server").font(Hearth.type(14, .medium))
          Spacer()
          Text(serverHost).font(Hearth.mono(12)).foregroundStyle(Hearth.muted).lineLimit(1)
        }
      }
      .tint(Hearth.muted)
    }
    .panel()
  }
  private var serverHost: String {
    URL(string: preferences.server).flatMap { url in
      url.host.map { host in url.port.map { "\(host):\($0)" } ?? host }
    } ?? preferences.server
  }
  private var worldsCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      CardHeader(
        title: "Open worlds", detail: session.rooms.isEmpty ? nil : "\(session.rooms.count)"
      ) {
        IconButton("arrow.clockwise", "Refresh worlds") { session.send(.listRooms) }
          .disabled(!session.online)
      }
      if session.rooms.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: session.online ? "globe.europe.africa" : "wifi.slash")
            .font(.system(size: 28)).foregroundStyle(Hearth.muted)
          Text(session.online ? "No open worlds" : "Not connected").font(Hearth.type(17, .semibold))
          Text(
            session.online
              ? "Create one, or ask a friend for their five-letter code."
              : "Check the server address, then connect."
          )
          .font(Hearth.type(14)).foregroundStyle(Hearth.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36)
      }
      VStack(spacing: 8) {
        ForEach(session.rooms) { room in
          Button {
            session.join(room.code)
          } label: {
            RoomRow(room: room)
          }
          .buttonStyle(.plain)
          .disabled(!session.online)
          .accessibilityLabel("Join \(room.name), \(room.players) players, code \(room.code)")
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel()
  }
}

struct RoomRow: View {
  let room: RoomSummary
  @State private var hovering = false
  var body: some View {
    HStack(spacing: 14) {
      Text(room.code).font(Hearth.pixel(18)).foregroundStyle(Hearth.gold)
        .frame(width: 80, height: 44)
        .background(RoundedRectangle(cornerRadius: 8).fill(Hearth.ink.opacity(0.8)))
      VStack(alignment: .leading, spacing: 5) {
        Text(room.name).font(Hearth.type(17, .semibold)).lineLimit(1)
        HStack(spacing: 6) {
          Chip(
            room.mode.capitalized,
            symbol: room.mode == "creative" ? "paintbrush.fill" : "shield.fill")
          Chip(phaseLabel, tint: room.phase == "lobby" ? Hearth.teal : Hearth.gold)
          Chip("\(room.players)", symbol: "person.2.fill")
        }
      }
      Spacer(minLength: 8)
      Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Hearth.muted)
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Hearth.navy.opacity(hovering ? 0.95 : 0.6))
    )
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
  }
  private var phaseLabel: String {
    switch room.phase {
    case "lobby": "In lobby"
    case "playing": "Playing"
    case "results": "Results"
    default: room.phase.capitalized
    }
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
          TextField("Name", text: $name)
          if creating {
            HStack {
              TextField("Seed", text: $seed).font(Hearth.mono(15))
              Button {
                seed = String(Int.random(in: 1...999_999))
              } label: {
                Image(systemName: "dice.fill")
              }
              .buttonStyle(.borderless)
              .accessibilityLabel("Random seed")
            }
          }
        }
        Section {
          Picker("Mode", selection: $mode) {
            Text("Survival").tag("survival")
            Text("Creative").tag("creative")
          }
          .pickerStyle(.segmented)
        } header: {
          Text("Mode")
        } footer: {
          Text(
            mode == "survival"
              ? "Gather resources, craft tools and survive the night."
              : "Every block available, instant building and flight."
          )
        }
        Section("Rules") {
          Stepper(value: $minutes, in: 0...200, step: 5) {
            LabeledContent("Length", value: minutes == 0 ? "No time limit" : "\(minutes) min")
          }
          Toggle("Creatures", isOn: $creatures)
          Toggle("Freeze time of day", isOn: $frozen)
        }
        if creating {
          Section {
            Stepper(value: $bots, in: 0...6) {
              LabeledContent("Bots", value: bots == 0 ? "None" : "\(bots)")
            }
          } header: {
            Text("Players")
          } footer: {
            Text("You can add or remove bots later from the lobby.")
          }
        }
      }
      .formStyle(.grouped)
      .navigationTitle(creating ? "New world" : "World settings")
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
          }
          .fontWeight(.semibold)
          .disabled(
            !session.online || name.trimmingCharacters(in: .whitespaces).isEmpty
              || (creating && Int(seed) == nil))
        }
      }
    }
    .foregroundStyle(Color.primary)
    .tint(.accentColor)
    #if os(macOS)
      .frame(width: 520, height: 560)
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
  @State private var copied = false
  private var me: Player? { session.players.first { $0.id == session.playerID } }
  private var humans: [Player] { session.players.filter { $0.bot != true } }
  private var readyCount: Int { humans.filter { $0.ready == true }.count }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack(spacing: 10) {
          Button {
            session.leave()
          } label: {
            Label("Leave", systemImage: "chevron.left")
          }
          .buttonStyle(HearthButton(.quiet, compact: true))
          Spacer()
          ConnectionPill(session: session)
          IconButton("gearshape.fill", "Settings") { options = true }
        }
        header
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: 20) {
            roster.frame(width: 420)
            ChatPanel(session: session).frame(minWidth: 320).frame(height: 400)
          }
          VStack(spacing: 20) {
            roster
            ChatPanel(session: session).frame(height: 320)
          }
        }
      }
      .padding(.horizontal, 24).padding(.vertical, 20)
      .frame(maxWidth: 1000)
      .frame(maxWidth: .infinity)
    }
    .scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom) { actionBar }
    .sheet(isPresented: $rules) { RoomEditor(session: session, creating: false) }
  }
  private var header: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .center, spacing: 24) {
        title
        Spacer()
        invite
      }
      VStack(alignment: .leading, spacing: 16) {
        title
        invite
      }
    }
  }
  private var title: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(session.roomName).font(Hearth.type(34, .bold)).lineLimit(2)
        .accessibilityAddTraits(.isHeader)
      HStack(spacing: 6) {
        Chip(
          session.mode.capitalized,
          symbol: session.mode == "creative" ? "paintbrush.fill" : "shield.fill")
        Chip(
          session.duration == 0 ? "No time limit" : "\(session.duration / 1200) min",
          symbol: "timer")
        if session.spawnMobs { Chip("Creatures", symbol: "pawprint.fill") }
        if session.freezeTime { Chip("Time frozen", symbol: "sun.max.fill") }
      }
    }
  }
  private var invite: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Invite code").font(Hearth.type(12, .medium)).foregroundStyle(Hearth.muted)
        Text(session.code ?? "").font(Hearth.pixel(32)).tracking(3).foregroundStyle(Hearth.gold)
          .textSelection(.enabled)
          .accessibilityLabel("Invite code \(session.code ?? "")")
      }
      IconButton(copied ? "checkmark" : "doc.on.doc", copied ? "Copied" : "Copy code") {
        Clipboard.copy(session.code ?? "")
        copied = true
      }
      .task(id: copied) {
        guard copied else { return }
        try? await Task.sleep(for: .seconds(1.5))
        copied = false
      }
      ShareLink(item: session.code ?? "") {
        Image(systemName: "square.and.arrow.up").font(.system(size: 16, weight: .semibold))
          .frame(width: 44, height: 44)
          .background(RoundedRectangle(cornerRadius: 10).fill(Hearth.ink.opacity(0.72)))
          .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Hearth.line))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Share code")
    }
    .padding(.leading, 16).padding(.trailing, 10).padding(.vertical, 10)
    .background(RoundedRectangle(cornerRadius: 14).fill(Hearth.surface.opacity(0.95)))
    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Hearth.gold.opacity(0.35)))
  }
  private var roster: some View {
    VStack(alignment: .leading, spacing: 12) {
      CardHeader(title: "Players", detail: "\(readyCount) of \(humans.count) ready")
      VStack(spacing: 6) {
        ForEach(session.players) { player in
          PlayerRow(
            player: player, host: player.id == session.host, you: player.id == session.playerID)
        }
      }
      if session.isHost {
        Rectangle().fill(Hearth.line).frame(height: 1)
        HStack(spacing: 8) {
          Button {
            session.send(.addBot)
          } label: {
            Label("Add bot", systemImage: "plus")
          }
          Button {
            session.send(.removeBot)
          } label: {
            Label("Remove bot", systemImage: "minus")
          }
          .disabled(!session.players.contains { $0.bot == true })
          Spacer(minLength: 0)
          Button {
            rules = true
          } label: {
            Label("Rules", systemImage: "slider.horizontal.3")
          }
        }
        .buttonStyle(HearthButton(compact: true))
        .disabled(!session.online)
      }
    }
    .panel()
  }
  private var actionBar: some View {
    let ready = me?.ready ?? false
    return HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(session.isHost ? "You're the host" : ready ? "You're ready" : "Get ready")
          .font(Hearth.type(15, .semibold))
        Text(
          session.isHost
            ? "Start whenever your party is set."
            : ready ? "Waiting for the host to start." : "Let the host know you're set."
        )
        .font(Hearth.type(13)).foregroundStyle(Hearth.muted)
      }
      Spacer(minLength: 8)
      Button {
        var message = ClientMessage(.ready)
        message.ready = !ready
        session.send(message)
        session.feedback.play("ready")
      } label: {
        Label(ready ? "Ready" : "Ready up", systemImage: ready ? "checkmark.circle.fill" : "circle")
      }
      .buttonStyle(HearthButton(session.isHost || ready ? .secondary : .primary))
      .disabled(!session.online)
      .accessibilityLabel(ready ? "Ready, tap to cancel" : "Ready up")
      if session.isHost {
        Button {
          session.send(.startMatch)
        } label: {
          Label("Start", systemImage: "play.fill")
        }
        .buttonStyle(HearthButton(.primary))
        .disabled(!session.online)
        .accessibilityIdentifier("start-match")
      }
    }
    .padding(.horizontal, 20).padding(.vertical, 12)
    .frame(maxWidth: 1000)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Hearth.surface.opacity(0.97))
        .shadow(color: .black.opacity(0.4), radius: 20, y: -4)
    )
    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Hearth.line))
    .padding(.horizontal, 16).padding(.bottom, 8)
  }
}

struct PlayerRow: View {
  let player: Player
  let host: Bool
  let you: Bool
  var body: some View {
    let name = player.name ?? "Wanderer"
    HStack(spacing: 12) {
      Avatar(name: name, bot: player.bot == true)
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(name).font(Hearth.type(16, .semibold)).lineLimit(1)
          if you { Chip("You", tint: Hearth.gold) }
          if host { Chip("Host", symbol: "crown.fill", tint: Hearth.gold) }
        }
        Label(platformName, systemImage: platformSymbol).font(Hearth.type(12))
          .foregroundStyle(Hearth.muted)
      }
      Spacer(minLength: 6)
      status
    }
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(you ? Hearth.gold.opacity(0.07) : Hearth.navy.opacity(0.45))
    )
    .accessibilityElement(children: .combine)
  }
  @ViewBuilder private var status: some View {
    if player.connected == false {
      Chip("Offline", symbol: "wifi.slash", tint: Hearth.danger)
    } else if player.ready == true || player.bot == true {
      Chip("Ready", symbol: "checkmark", tint: Hearth.teal)
    } else {
      Chip("Not ready", tint: Hearth.muted)
    }
  }
  private var platformName: String {
    if player.bot == true { return "Bot" }
    switch player.platform?.lowercased() ?? "" {
    case "macos": return "Mac"
    case "ios": return "iOS"
    case "": return "Player"
    default: return player.platform ?? "Player"
    }
  }
  private var platformSymbol: String {
    if player.bot == true { return "cpu" }
    switch player.platform?.lowercased() ?? "" {
    case "macos": return "laptopcomputer"
    case "ios": return "iphone"
    default: return "person.fill"
    }
  }
}
