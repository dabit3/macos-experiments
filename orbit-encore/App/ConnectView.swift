import SwiftUI

struct ConnectView: View {
    @ObservedObject var client: GameClient
    @State private var joining = false
    @State private var showServer = false
    @FocusState private var codeFocused: Bool

    private var canConnect: Bool {
        !client.connecting && !client.guestName.trimmingCharacters(in: .whitespaces).isEmpty && (!joining || client.roomCode.count == 6)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                Card(padding: 18) {
                    VStack(alignment: .leading, spacing: 18) {
                        Field(label: "Stage name", text: $client.guestName, placeholder: "How rivals will see you", id: "guestName")
                        modePicker
                        if joining {
                            Field(label: "Room code", text: $client.roomCode, placeholder: "ABC123", id: "roomCode",
                                  icon: "number", monospaced: true, uppercase: true)
                                .focused($codeFocused)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            Label("You'll get a six-character code to share with your rival.", systemImage: "info.circle")
                                .font(Theme.body(12)).foregroundStyle(Theme.textSecondary)
                        }
                        Button { client.connect() } label: {
                            HStack(spacing: 10) {
                                if client.connecting { ProgressView().tint(Theme.ink) }
                                Text(client.connecting ? "Connecting…" : joining ? "Join the stage" : "Host a stage")
                                if !client.connecting { Image(systemName: "arrow.right") }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(color: joining ? Theme.pink : Theme.cyan))
                        .disabled(!canConnect)
                        .accessibilityIdentifier("connectButton")
                    }
                }
                server
                Text(client.status).font(Theme.body(12)).foregroundStyle(Theme.textTertiary).multilineTextAlignment(.center)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            joining = !client.roomCode.isEmpty
            showServer = client.serverAddress != "ws://127.0.0.1:8788"
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("cosmic-bunny").resizable().scaledToFill().frame(height: 210).frame(maxWidth: .infinity).clipped()
            LinearGradient(colors: [.clear, Theme.ink.opacity(0.35), Theme.ink], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Two phones · one beat", color: Theme.cyan)
                Text("Circular rhythm battles").font(Theme.display(26)).lineLimit(2).minimumScaleFactor(0.8)
                HStack(spacing: 8) {
                    Chip(text: "8 targets", color: Theme.pink, icon: "circle.grid.cross")
                    Chip(text: "Live rival", color: Theme.cyan, icon: "bolt.fill")
                    Chip(text: "Original music", color: Theme.gold, icon: "music.note")
                }
            }.padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.pink.opacity(0.35), lineWidth: 1))
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            modeButton("Host", icon: "plus.circle.fill", active: !joining) {
                joining = false
                client.roomCode = ""
            }
            modeButton("Join with code", icon: "link", active: joining) {
                joining = true
                codeFocused = true
            }
        }
        .padding(4)
        .background(Theme.ink.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: joining)
    }

    private func modeButton(_ title: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(active ? Theme.ink : Theme.textSecondary)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(active ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }.buttonStyle(.plain)
    }

    private var server: some View {
        VStack(spacing: 12) {
            Button { withAnimation(.spring(response: 0.3)) { showServer.toggle() } } label: {
                HStack {
                    Image(systemName: "network").foregroundStyle(Theme.textTertiary)
                    Text("Server").font(Theme.body(13, weight: .bold)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(client.serverAddress.replacingOccurrences(of: "ws://", with: "")).font(Theme.mono(12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textTertiary)
                        .rotationEffect(.degrees(showServer ? 180 : 0))
                }.padding(.horizontal, 16).frame(height: 46)
            }.buttonStyle(.plain)
            if showServer {
                VStack(alignment: .leading, spacing: 10) {
                    Field(label: "Address", text: $client.serverAddress, placeholder: "ws://192.168.1.10:8788", id: "serverAddress",
                          icon: "server.rack", monospaced: true)
                    Text("Both phones must reach the same server. On a LAN, use your Mac's address on port 8788.")
                        .font(Theme.body(12)).foregroundStyle(Theme.textTertiary)
                }.padding(.horizontal, 16).padding(.bottom, 16)
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }
}
