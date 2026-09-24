import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var profile: PlayerProfile
    let result: MatchResult
    let onHome: () -> Void
    let onCards: () -> Void
    let onRematch: () -> Void
    @State private var revealed = false

    private var titleFill: LinearGradient {
        switch result.outcome {
        case .victory: return .goldText
        case .defeat: return .redText
        case .draw: return .whiteText
        }
    }

    private var duration: String {
        String(format: "%d:%02d", result.durationSeconds / 60, result.durationSeconds % 60)
    }

    private var subtitle: String {
        switch result.outcome {
        case .victory:
            return result.playerCrowns == 3 ? "Three-crown win in \(duration)" : "You took the lead in \(duration)"
        case .defeat:
            return result.enemyCrowns == 3 && result.playerCrowns == 0 && result.durationSeconds < Int(Arena.regulationSeconds)
                ? "The rival broke through in \(duration)"
                : "The rival edged it in \(duration)"
        case .draw:
            return "Dead even after \(duration)"
        }
    }

    private var previousLeague: League { League.forTrophies(max(0, profile.trophies - result.trophyDelta)) }

    var body: some View {
        ZStack {
            SceneryBackdrop(dim: result.outcome == .defeat ? 0.6 : 0.2)
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        RenderedImage(name: "emblem")
                            .saturation(result.outcome == .defeat ? 0.2 : 1)
                            .rotationEffect(.degrees(result.outcome == .defeat ? -12 : 0))
                            .frame(width: 150, height: 150)
                            .shadow(color: (result.outcome == .defeat ? Theme.enemy : Theme.accent).opacity(0.22), radius: 28)
                            .scaleEffect(revealed ? 1 : 0.4)
                            .opacity(revealed ? 1 : 0)
                            .padding(.top, 12)
                        VStack(spacing: 4) {
                            DisplayText(text: result.outcome.rawValue, size: 52, fill: titleFill)
                                .accessibilityIdentifier("resultTitle")
                            Text(subtitle)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.8), radius: 0, y: 1)
                                .accessibilityIdentifier("resultSubtitle")
                        }
                        .scaleEffect(revealed ? 1 : 1.6)
                        .opacity(revealed ? 1 : 0)

                        HStack(spacing: 30) {
                            crownColumn("You", result.playerCrowns, Theme.player)
                            Text("VS").font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(.white.opacity(0.5))
                            crownColumn("Rival", result.enemyCrowns, Theme.enemy)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .panel(cornerRadius: 22)

                        progressPanel
                        rewardsPanel
                        tipPanel
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 12)
                }

                VStack(spacing: 10) {
                    ChunkyButton(title: "REMATCH", icon: .swords, style: .gold, height: 58, fontSize: 24, action: onRematch)
                        .accessibilityIdentifier("rematchButton")
                    HStack(spacing: 10) {
                        ChunkyButton(title: "EDIT DECK", icon: .cards, style: .slate, height: 46, fontSize: 16, action: onCards)
                            .accessibilityIdentifier("editDeckButton")
                        ChunkyButton(title: "HOME", style: .slate, height: 46, fontSize: 16, action: onHome)
                            .accessibilityIdentifier("homeButton")
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 16)
                .background(
                    LinearGradient(colors: [Theme.background.opacity(0), Theme.background.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )
            }
        }
        .onAppear {
            ArcadeAudio.play(result.outcome == .victory ? .victory : (result.outcome == .defeat ? .defeat : .tap))
            withAnimation(.spring(duration: 0.6, bounce: 0.35)) { revealed = true }
        }
    }

    // MARK: Panels

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "League progress")
                Spacer()
                if previousLeague != profile.league {
                    Text(profile.league.minTrophies > previousLeague.minTrophies ? "PROMOTED!" : "DEMOTED")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(Art.outline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(profile.league.minTrophies > previousLeague.minTrophies ? Theme.accent : Theme.enemy))
                        .accessibilityIdentifier("leagueChange")
                }
            }
            LeagueBadge(trophies: profile.trophies)
        }
        .padding(12)
        .panel()
        .accessibilityIdentifier("progressPanel")
    }

    private var rewardsPanel: some View {
        VStack(spacing: 10) {
            rewardRow(.trophy, "Trophies", result.trophyDelta, total: profile.trophies)
            rewardRow(.coin, "Gold", result.goldDelta, total: profile.gold)
            if profile.streak >= 2 {
                HStack(spacing: 10) {
                    IconView(kind: .flame, size: 24)
                    Text("Win streak")
                    Spacer()
                    Text("\(profile.streak)")
                        .foregroundStyle(Theme.accent)
                        .monospacedDigit()
                    Text(profile.streak >= profile.bestStreak ? "BEST" : "best \(profile.bestStreak)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .accessibilityElement(children: .combine)
            }
        }
        .padding(14)
        .panel()
        .foregroundStyle(.white)
        .accessibilityIdentifier("rewardsPanel")
    }

    private var tipPanel: some View {
        HStack(alignment: .top, spacing: 10) {
            IconView(kind: .help, size: 22)
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: result.outcome == .defeat ? "Next time" : "Pro tip")
                Text(BattleTips.tip(for: result.outcome, seed: profile.matchesPlayed))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .panel(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tipPanel")
    }

    private func crownColumn(_ label: String, _ count: Int, _ color: Color) -> some View {
        VStack(spacing: 6) {
            CrownRow(count: count, color: color, size: 28)
            Text(label.uppercased()).font(.system(.caption, design: .rounded).weight(.black)).foregroundStyle(.white.opacity(0.75))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(count) crowns")
    }

    private func rewardRow(_ icon: IconKind, _ label: String, _ delta: Int, total: Int) -> some View {
        HStack(spacing: 10) {
            IconView(kind: icon, size: 24)
            Text(label)
            Spacer()
            Text(delta >= 0 ? "+\(delta)" : "\(delta)")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(delta > 0 ? Color(red: 0.45, green: 0.9, blue: 0.4) : (delta < 0 ? Theme.enemy : .white.opacity(0.6)))
                .monospacedDigit()
            Text("→ \(total)")
                .foregroundStyle(.white.opacity(0.55))
                .monospacedDigit()
                .frame(minWidth: 56, alignment: .trailing)
        }
        .font(.system(.subheadline, design: .rounded).weight(.bold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(delta >= 0 ? "plus" : "minus") \(abs(delta)), now \(total)")
    }
}
