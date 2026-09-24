import SwiftUI

struct LobbyView: View {
    @ObservedObject var client: GameClient
    @State private var previewing = false
    @State private var copied = false

    private var rivalJoined: Bool { client.rival != nil }
    private var ready: Bool { client.me?.ready == true }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    roomCard
                    players
                    tracks
                }.padding(.bottom, 16)
            }.scrollIndicators(.hidden)
            readyBar
        }
        .onDisappear { stopPreview() }
    }

    private var roomCard: some View {
        Card(tint: Theme.gold, padding: 18) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Room code", color: Theme.gold)
                    Text(client.roomCode.map(String.init).joined(separator: " ")).font(Theme.mono(30)).foregroundStyle(Theme.textPrimary)
                        .accessibilityLabel("Room code \(client.roomCode)")
                    Text(rivalJoined ? "Your rival is here. Pick a track and get ready." : "Share this code so your rival can join.")
                        .font(Theme.body(12)).foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    Button {
                        UIPasteboard.general.string = client.roomCode
                        withAnimation { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { copied = false } }
                    } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }
                        .buttonStyle(IconButtonStyle()).accessibilityLabel("Copy room code")
                    ShareLink(item: "Join my Orbit Encore stage with code \(client.roomCode)") { Image(systemName: "square.and.arrow.up") }
                        .buttonStyle(IconButtonStyle()).accessibilityLabel("Share room code")
                }
            }
        }
    }

    private var players: some View {
        HStack(spacing: 10) {
            playerCard(client.me, title: "You", color: Theme.pink)
            Text("VS").font(Theme.display(14)).foregroundStyle(Theme.textTertiary)
            playerCard(client.rival, title: "Rival", color: Theme.cyan)
        }
    }

    private func playerCard(_ player: Player?, title: String, color: Color) -> some View {
        Card(tint: color, padding: 14) {
            HStack(spacing: 12) {
                Avatar(name: player?.name, color: color, size: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(title, color: color)
                    Text(player?.name ?? "Waiting…").font(Theme.title(16)).lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundStyle(player == nil ? Theme.textTertiary : Theme.textPrimary)
                    HStack(spacing: 5) {
                        StatusDot(color: player == nil ? Theme.textTertiary : player?.ready == true ? Theme.mint : color, pulsing: player == nil)
                        Text(player == nil ? "Open slot" : player?.ready == true ? "Ready" : player?.connected == true ? "In lobby" : "Reconnecting")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var tracks: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow("Track")
                Spacer()
                Chip(text: client.isHost ? "You pick" : "Host picks", color: client.isHost ? Theme.gold : Theme.textTertiary,
                     icon: client.isHost ? "crown.fill" : "lock.fill")
            }
            ForEach(client.charts) { chart in
                trackCard(chart)
            }
        }.padding(.top, 4)
    }

    private func trackCard(_ chart: Chart) -> some View {
        let selected = client.chart?.id == chart.id
        let accent = chart.id == "neon" ? Theme.pink : Theme.gold
        return Button {
            if client.isHost && !ready {
                stopPreview()
                client.select(chart)
            }
        } label: {
            Card(tint: Theme.cyan, selected: selected, padding: 12) {
                HStack(spacing: 12) {
                    Image("cosmic-bunny").resizable().scaledToFill().frame(width: 74, height: 74)
                        .hueRotation(.degrees(chart.id == "neon" ? 80 : 0)).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            Text("\(chart.level)").font(Theme.display(13)).foregroundStyle(Theme.ink)
                                .padding(.horizontal, 7).padding(.vertical, 2).background(accent, in: Capsule()).padding(5)
                        }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(chart.title).font(Theme.title(17)).foregroundStyle(Theme.textPrimary)
                        Text(chart.artist).font(Theme.body(11)).foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 6) {
                            Text(chart.difficulty.uppercased()).font(.system(size: 9, weight: .black)).foregroundStyle(accent)
                            difficultyPips(chart.level, color: accent)
                        }
                        Text("\(chart.bpm) BPM · \(chart.notes.count) notes · \(Int(chart.duration))s")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textTertiary)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 10) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20)).foregroundStyle(selected ? Theme.cyan : Theme.textTertiary)
                        if selected {
                            Button {
                                if previewing { stopPreview() } else {
                                    previewing = true
                                    _ = client.audio.play(song: chart.id, startAt: client.serverNow, now: client.serverNow)
                                }
                            } label: {
                                Image(systemName: previewing ? "stop.fill" : "play.fill").font(.system(size: 12, weight: .black))
                                    .foregroundStyle(Theme.ink).frame(width: 30, height: 30).background(Theme.cyan, in: Circle())
                            }.buttonStyle(.plain).accessibilityLabel(previewing ? "Stop preview" : "Preview track")
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(client.isHost && !ready ? "Selects this track" : "Only the host can change the track")
        .animation(.spring(response: 0.3), value: selected)
    }

    private func difficultyPips(_ level: Int, color: Color) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { index in
                Capsule().fill(index < level ? color : Theme.stroke).frame(width: 6, height: 3)
            }
        }
    }

    private var readyBar: some View {
        VStack(spacing: 10) {
            Button {
                stopPreview()
                client.ready()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: ready ? "checkmark.circle.fill" : "bolt.fill")
                    Text(ready ? "Ready · tap to cancel" : "I'm ready")
                }
            }
            .buttonStyle(PrimaryButtonStyle(color: ready ? Theme.mint : Theme.cyan))
            .disabled(!rivalJoined || !client.clockReady)
            .accessibilityIdentifier("readyButton")
            Text(hint).font(Theme.body(12)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                .frame(minHeight: 16)
            Button("Leave stage") { client.leave() }.font(Theme.body(13, weight: .bold)).foregroundStyle(Theme.textTertiary)
                .frame(height: 36)
        }
        .padding(.top, 12)
        .background(LinearGradient(colors: [Theme.ink.opacity(0), Theme.ink.opacity(0.9)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    private var hint: String {
        if !rivalJoined { return "Waiting for a second player to join with your code." }
        if !client.clockReady { return "Syncing clocks with the server…" }
        if ready && client.rival?.ready != true { return "Waiting for \(client.rival?.name ?? "your rival") to ready up." }
        if ready { return "Both ready — the countdown starts now." }
        if client.rival?.ready == true { return "\(client.rival?.name ?? "Rival") is ready. Your move." }
        return "Both players ready → shared five-second countdown."
    }

    private func stopPreview() {
        previewing = false
        client.audio.stop()
    }
}
