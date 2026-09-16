import SwiftUI

struct ScoreboardView: View {
  @EnvironmentObject private var store: GameStore
  @State private var newName = ""
  @State private var showReset = false

  var body: some View {
    ZStack {
      CircuitBackground()
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("SCOREBOARD")
            .font(.system(size: 30, weight: .black))
            .tracking(2)
            .foregroundStyle(Theme.green)
          Text("THE BENCHMARK LEADERBOARD")
            .font(.monoStat(11))
            .foregroundStyle(Theme.muted)
          VStack(spacing: 8) {
            ForEach(Array(store.state.leaderboard.enumerated()), id: \.element.id) { rank, player in
              HStack(spacing: 10) {
                Button {
                  store.selectPlayer(player.id)
                } label: {
                  HStack {
                    Text(String(format: "%02d", rank + 1)).font(.monoStat(13)).foregroundStyle(
                      Theme.green)
                    VStack(alignment: .leading) {
                      Text(player.name.uppercased()).font(.system(size: 15, weight: .black))
                      Text(player.id == store.currentPlayer.id ? "CURRENT PLAYER" : "READY")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text("\(player.wins)").font(
                      .system(size: 25, weight: .black, design: .monospaced)
                    ).foregroundStyle(Theme.green)
                    Text("WINS").font(.system(size: 9, weight: .bold, design: .monospaced))
                      .foregroundStyle(Theme.muted)
                  }
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if store.state.players.count > 1 {
                  Button(role: .destructive) {
                    store.removePlayer(id: player.id)
                  } label: {
                    Image(systemName: "xmark.circle.fill")
                      .foregroundStyle(Theme.muted)
                  }
                  .buttonStyle(.plain)
                  .accessibilityLabel("Remove \(player.name)")
                }
              }
              .padding(14)
              .background(
                player.id == store.currentPlayer.id ? Theme.green.opacity(0.14) : Theme.panel
              )
              .clipShape(RoundedRectangle(cornerRadius: 9))
              .contextMenu {
                if store.state.players.count > 1 {
                  Button("Remove", role: .destructive) {
                    store.removePlayer(id: player.id)
                  }
                }
              }
            }
          }
          HStack {
            TextField("PLAYER NAME", text: $newName)
              .textInputAutocapitalization(.words)
              .padding(13)
              .background(Theme.panel)
              .clipShape(RoundedRectangle(cornerRadius: 8))
            Button("ADD") {
              store.addPlayer(name: newName)
              newName = ""
            }
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(Theme.black)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Theme.green)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(
              store.state.players.count >= GameState.maxPlayers
                || newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .opacity(store.state.players.count >= GameState.maxPlayers ? 0.4 : 1)
          }
          Button("NEW ROUND FOR EVERYONE") { store.newRound() }
            .buttonStyle(GlowButtonStyle(filled: true))
          Button("RESET SCORES", role: .destructive) { showReset = true }
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .padding(20)
      }
    }
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .confirmationDialog("Reset all wins?", isPresented: $showReset, titleVisibility: .visible) {
      Button("Reset scores", role: .destructive) { store.resetScores() }
      Button("Cancel", role: .cancel) {}
    }
  }
}
