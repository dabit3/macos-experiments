import SwiftUI

struct HomeView: View {
    @EnvironmentObject var profile: PlayerProfile
    let onBattle: () -> Void
    let onCards: () -> Void
    @State private var floating = false
    @State private var showHelp = false

    var body: some View {
        ZStack {
            SceneryBackdrop()
            VStack(spacing: 0) {
                topBar

                VStack(spacing: -8) {
                    Text("THE SKY IS YOUR BATTLEFIELD")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(.cyan.opacity(0.8))
                        .padding(.bottom, 14)
                    DisplayText(text: "TOWER", size: 46, fill: .whiteText)
                    DisplayText(text: "TUSSLE", size: 56, fill: .goldText)
                }
                .padding(.top, 14)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tower Tussle")

                GeometryReader { geo in
                    RenderedImage(name: "hero")
                        .frame(width: geo.size.width + 18, height: geo.size.height + 22)
                        .offset(x: -9, y: floating ? -6 : 2)
                        .shadow(color: .cyan.opacity(0.15), radius: 24, y: 10)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 4)

                VStack(spacing: 10) {
                    DeckStrip(deck: profile.deck, averageElixir: profile.averageElixir, action: onCards)

                    ChunkyButton(title: "BATTLE", icon: .swords, style: .gold, height: 64, fontSize: 26, action: onBattle)
                        .accessibilityIdentifier("battleButton")
                        .accessibilityHint("Start a three minute match against the sky rival")

                    HStack(spacing: 10) {
                        ChunkyButton(title: "CARDS", icon: .cards, style: .slate, height: 46, fontSize: 17, action: onCards)
                            .accessibilityIdentifier("cardsButton")
                        recordChip
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { floating = true }
            if !profile.hasSeenTutorial { showHelp = true }
        }
        .sheet(isPresented: $showHelp, onDismiss: { profile.markTutorialSeen() }) {
            HowToPlaySheet { showHelp = false }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            LeagueBadge(trophies: profile.trophies, compact: true)
                .frame(maxWidth: .infinity)
            StatPill(icon: .coin, value: "\(profile.gold)", label: "Gold")
                .frame(width: 104)
            IconButton(icon: .sound(on: profile.soundEnabled), label: profile.soundEnabled ? "Mute sound" : "Unmute sound") {
                profile.setSoundEnabled(!profile.soundEnabled)
            }
            .accessibilityIdentifier("soundButton")
            IconButton(icon: .help, label: "How to play", style: .blue) { showHelp = true }
                .accessibilityIdentifier("helpButton")
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var recordChip: some View {
        VStack(spacing: 2) {
            if profile.matchesPlayed == 0 {
                Text("FIRST BATTLE")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Text("Win to earn trophies")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                HStack(spacing: 4) {
                    Text("\(profile.wins)W")
                        .foregroundStyle(Color(red: 0.55, green: 0.95, blue: 0.55))
                    Text("·").foregroundStyle(.white.opacity(0.4))
                    Text("\(profile.losses)L")
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.5))
                    Text("·").foregroundStyle(.white.opacity(0.4))
                    Text("\(profile.draws)D")
                        .foregroundStyle(.white.opacity(0.8))
                }
                .font(.system(size: 13, weight: .black, design: .rounded))
                .monospacedDigit()
                HStack(spacing: 3) {
                    if profile.streak >= 2 {
                        IconView(kind: .flame, size: 12)
                        Text("\(profile.streak) win streak")
                    } else {
                        Text("\(winRate)% win rate")
                    }
                }
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .panel(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recordChip")
    }

    private var winRate: Int {
        Int((Double(profile.wins) / Double(max(profile.matchesPlayed, 1)) * 100).rounded())
    }
}
