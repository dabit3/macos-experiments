import SwiftUI

@main
struct OrbitEncoreApp: App {
    @StateObject private var client = GameClient()

    var body: some Scene {
        WindowGroup {
            ContentView(client: client)
                .preferredColorScheme(.dark)
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }
}

struct ContentView: View {
    @ObservedObject var client: GameClient
    @State private var showHelp = false
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Theme.backdrop.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    Group {
                        switch client.phase {
                        case "connect": ConnectView(client: client)
                        case "lobby": LobbyView(client: client)
                        case "results": ResultsView(client: client)
                        default: GameView(client: client, width: geometry.size.width)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .id(client.phase)
                }
                .padding(.horizontal, 18)
                .padding(.top, 2)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: client.phase)
                if !client.error.isEmpty {
                    VStack {
                        Spacer()
                        Toast(message: client.error) { client.error = "" }.padding()
                    }.transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35), value: client.error.isEmpty)
        }
        .sheet(isPresented: $showHelp) { HelpSheet(dismiss: { showHelp = false }) }
        .sheet(isPresented: $showSettings) { SettingsSheet(client: client, dismiss: { showSettings = false }) }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: -2) {
                Text("ORBIT").font(Theme.display(24)).tracking(3)
                Text("ENCORE").font(.system(size: 10, weight: .black, design: .rounded)).tracking(4).foregroundStyle(Theme.cyan)
            }
            Spacer()
            if client.phase != "connect" {
                HStack(spacing: 6) {
                    StatusDot(color: client.connected ? Theme.mint : Theme.pink, pulsing: !client.connected)
                    Text(client.connected ? "\(Int(client.clockRTT)) ms" : "Reconnecting")
                        .font(Theme.mono(11, weight: .bold)).foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 10).frame(height: 30)
                .background(Theme.surfaceRaised, in: Capsule())
                .accessibilityLabel(client.connected ? "Connected, \(Int(client.clockRTT)) millisecond latency" : "Reconnecting")
            }
            Button { showHelp = true } label: { Image(systemName: "questionmark") }
                .buttonStyle(IconButtonStyle()).accessibilityLabel("How to play")
            if client.phase != "playing" {
                Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(IconButtonStyle()).accessibilityLabel("Audio and connection settings")
            }
        }
        .padding(.bottom, 12)
    }
}

struct HelpSheet: View {
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("How to play").font(Theme.display(30))
                    Text("Notes travel from the center to the eight numbered targets on the rim. Touch the target as the note reaches it.")
                        .font(Theme.body(15)).foregroundStyle(Theme.textSecondary)
                    row("circle", Theme.pink, "Tap", "Pink rings. Touch the matching target on the beat.")
                    row("rectangle.portrait.fill", Theme.pink, "Hold", "Keep your finger down until the tail reaches the rim. Lifting early breaks it.")
                    row("star.fill", Theme.cyan, "Slide", "Tap the star, then trace the cyan arrows in order to the far end. Jumping ahead won't count.")
                    row("hand.raised.fingers.spread.fill", Theme.gold, "Each", "Gold pairs linked by a ring need two fingers at once.")
                    row("sparkles", Theme.gold, "Break", "Sparkling gold notes are worth five taps. Don't miss them.")
                    Card(padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow("Timing windows")
                            HStack(spacing: 10) {
                                window("Perfect", "±50 ms", Theme.gold)
                                window("Great", "±105 ms", Theme.cyan)
                                window("Good", "±160 ms", Theme.mint)
                            }
                            Text("Break ×5 · Slide ×3 · Hold ×2 · Tap ×1. A miss resets your combo. Highest score wins the battle.")
                                .font(Theme.body(12)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Card(padding: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow("Battling a rival")
                            Text("Host a stage, share the six-character code, and have your rival join from their phone. "
                                 + "When both tap Ready, the same song starts on a shared clock and you watch each other's scores live.")
                                .font(Theme.body(13)).foregroundStyle(Theme.textSecondary)
                            Text("Wired headphones give the tightest timing. Fine-tune audio delay in settings.")
                                .font(Theme.body(12)).foregroundStyle(Theme.textTertiary)
                        }
                    }
                }.padding(22)
            }
            .background(Theme.backdrop.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: dismiss).fontWeight(.bold) } }
        }.presentationDragIndicator(.visible)
    }

    private func row(_ icon: String, _ color: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 16, weight: .black)).foregroundStyle(color)
                .frame(width: 40, height: 40).background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.title(16))
                Text(detail).font(Theme.body(13)).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func window(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.mono(13)).foregroundStyle(color)
            Text(label.uppercased()).font(.system(size: 8, weight: .black)).foregroundStyle(Theme.textTertiary)
        }.frame(maxWidth: .infinity).padding(.vertical, 8).background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct SettingsSheet: View {
    @ObservedObject var client: GameClient
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Music volume", value: "\(Int(client.musicVolume * 100))%")
                    Slider(value: $client.musicVolume, in: 0...1).tint(Theme.cyan)
                    LabeledContent("Audio delay", value: "\(Int(client.audioOffset * 1000)) ms")
                    Slider(value: $client.audioOffset, in: -0.2...0.2, step: 0.005).tint(Theme.pink)
                    Button("Reset delay") { client.audioOffset = 0 }.disabled(client.audioOffset == 0)
                } header: { Text("Audio") } footer: {
                    Text("If notes feel early, increase the delay; if late, decrease it. Applies at the next song start; "
                         + "scoring and the shared clock are unchanged.")
                }
                Section {
                    LabeledContent("Server") { Text(client.serverAddress).font(.caption.monospaced()) }
                    LabeledContent("Status", value: client.connected ? "Connected" : "Offline")
                    LabeledContent("Clock RTT", value: "\(Int(client.clockRTT)) ms")
                    if client.connected {
                        Button("Reconnect this player") {
                            client.reconnect()
                            dismiss()
                        }
                    }
                } header: { Text("Connection") }
                Section("About") {
                    Text("Original art and music: Orbit Sound System. Reference-inspired arcade rhythm game, not affiliated with SEGA.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden).background(Theme.backdrop.ignoresSafeArea())
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: dismiss).fontWeight(.bold) } }
        }.presentationDragIndicator(.visible)
    }
}
