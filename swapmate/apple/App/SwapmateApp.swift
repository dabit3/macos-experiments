import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

@main
struct SwapmateApp: App {
  @StateObject private var client: GameClient
  private let configuration: AppConfiguration
  init() {
    BrandFont.register()
    let configuration = AppConfiguration()
    self.configuration = configuration
    _client = StateObject(wrappedValue: GameClient(configuration: configuration))
  }
  var body: some Scene {
    WindowGroup {
      RootView(configuration: configuration).environmentObject(client)
        #if os(macOS)
          .frame(minWidth: 620, minHeight: 580)
          .background(WindowConfiguration())
        #endif
    }
    #if os(macOS)
      .defaultSize(width: 1180, height: 820)
      .commands {
        CommandGroup(replacing: .newItem) {}
        CommandMenu("Match") {
          Button("Reconnect") { client.retry() }.keyboardShortcut(
            "r", modifiers: [.command, .shift])
          Button("Cancel selection / premove") { client.cancelPremove() }.keyboardShortcut(
            .escape, modifiers: [])
          Divider()
          Button("Toggle theme") { client.theme = client.theme == "light" ? "dark" : "light" }
          .keyboardShortcut("l", modifiers: [.command, .shift])
        }
      }
    #endif
  }
}

struct RootView: View {
  @EnvironmentObject private var client: GameClient
  @Environment(\.colorScheme) private var scheme
  @Environment(\.scenePhase) private var phase
  let configuration: AppConfiguration
  @State private var started = false
  @State private var confirmingLeave = false
  var body: some View {
    ZStack {
      ArcadeBackdrop()
      VStack(spacing: 0) {
        header
        if client.status == .reconnecting {
          Label(
            "Reconnecting — your seat is reserved briefly",
            systemImage: "arrow.triangle.2.circlepath"
          )
          .font(BrandFont.body(12)).padding(10).frame(maxWidth: .infinity)
          .background(Palette(scheme).accent.opacity(0.15))
        }
        if let error = client.error {
          banner(error, danger: true) { client.error = nil }
        }
        if let notice = client.notice {
          banner(notice, danger: false) { client.notice = nil }
        }
        if let room = client.room {
          if let game = client.game, game.result != nil {
            ResultsView(room: room, game: game)
          } else if room.phase == .lobby {
            LobbyView(room: room)
          } else if let game = client.game {
            GameView(room: room, game: game).id(game.gameId)
          } else {
            VStack {
              ProgressView()
              Text("Waiting for the server’s game snapshot…")
              Button("Reconnect") { client.retry() }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        } else {
          HomeView()
        }
      }
    }
    .font(BrandFont.body())
    .foregroundStyle(Palette(scheme).text)
    .tint(Palette(scheme).accent)
    .preferredColorScheme(client.theme == "system" ? nil : client.theme == "light" ? .light : .dark)
    .buttonStyle(ArcadeButtonStyle())
    .onAppear {
      guard !started else { return }
      started = true
      if configuration.autoConnect {
        client.connect(entry: configuration.initialCommand)
      }
    }
    .onChange(of: client.theme) { _, value in UserDefaults.standard.set(value, forKey: "theme") }
    .onKeyPress(.escape) {
      client.cancelPremove()
      return .handled
    }
    .onChange(of: phase) { _, value in
      if value == .active
        && (client.status == .reconnecting || (client.status == .offline && client.room != nil))
      {
        client.retry()
      }
    }
    .confirmationDialog(
      "Leave the match? Your team may lose by abandonment.", isPresented: $confirmingLeave
    ) {
      Button("Leave room", role: .destructive) { client.send(.leave) }
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      SwapmateMark().frame(width: 30, height: 30)
      Text("Swapmate").font(BrandFont.display(27)).lineLimit(1).minimumScaleFactor(0.7)
      if let code = client.room?.code {
        Text(code).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
      }
      Spacer(minLength: 4)
      HStack(spacing: 5) {
        Circle().fill(client.online ? Palette(scheme).team(.tidal) : Palette(scheme).danger).frame(
          width: 6, height: 6)
        Text(client.online ? "\(client.pingMs) ms" : client.status.rawValue.capitalized)
          .font(BrandFont.body(10)).lineLimit(1)
      }.accessibilityLabel(
        "Connection: \(client.status.rawValue), latency \(client.pingMs) milliseconds")
      Menu {
        Picker("Appearance", selection: $client.theme) {
          Text("Dark").tag("dark")
          Text("Light").tag("light")
          Text("System").tag("system")
        }
        Button("Reconnect") { client.retry() }
        if client.room != nil {
          Button("Leave room") {
            if client.game?.result == nil && client.room?.phase == .playing {
              confirmingLeave = true
            } else {
              client.send(.leave)
            }
          }
        }
        Button("Disconnect") { client.disconnect() }
        Button("Forget saved session", role: .destructive) { client.disconnect(forget: true) }
      } label: {
        Image(systemName: "gearshape").frame(width: 32, height: 32)
      }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Settings")
    }.padding(.horizontal, 18).padding(.vertical, 12)
  }

  private func banner(_ text: String, danger: Bool, dismiss: @escaping () -> Void) -> some View {
    HStack {
      Image(systemName: danger ? "exclamationmark.triangle.fill" : "info.circle")
      Text(text).font(BrandFont.body(12)).fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
      if !client.online {
        Button("Reconnect") { client.retry() }.buttonStyle(.borderless)
      }
      Button(action: dismiss) { Image(systemName: "xmark") }.buttonStyle(.borderless)
        .accessibilityLabel("Dismiss message")
    }.padding(12).background(
      (danger ? Palette(scheme).danger : Palette(scheme).accent).opacity(0.16))
  }
}

enum NativeClipboard {
  static func copy(_ text: String) {
    #if os(macOS)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(text, forType: .string)
    #else
      UIPasteboard.general.string = text
    #endif
  }
}

#if os(macOS)
  private struct WindowConfiguration: NSViewRepresentable {
    func makeNSView(context: Context) -> ConfiguredView { ConfiguredView() }
    func updateNSView(_ nsView: ConfiguredView, context: Context) {}
    final class ConfiguredView: NSView {
      private var configured = false
      override func viewDidMoveToWindow() {
        guard !configured, let window else { return }
        configured = true
        guard let spec = ProcessInfo.processInfo.environment["SWAPMATE_WINDOW"],
          let expression = try? NSRegularExpression(pattern: "^(\\d+)x(\\d+)\\+(\\d+)\\+(\\d+)$"),
          let match = expression.firstMatch(in: spec, range: NSRange(spec.startIndex..., in: spec))
        else { return }
        let values = (1...4).compactMap { index -> Double? in
          guard let range = Range(match.range(at: index), in: spec) else { return nil }
          return Double(spec[range])
        }
        guard values.count == 4 else { return }
        let screenHeight = window.screen?.frame.height ?? 900
        window.setFrame(
          CGRect(
            x: values[2], y: screenHeight - values[3] - values[1],
            width: max(620, values[0]), height: max(580, values[1])), display: true)
      }
    }
  }
#endif
