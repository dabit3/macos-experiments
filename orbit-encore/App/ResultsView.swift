import SwiftUI

struct ResultsView: View {
    @ObservedObject var client: GameClient
    @State private var revealed = false

    private var me: Player? { client.me }
    private var rival: Player? { client.rival }
    private var lead: Int { (me?.score ?? 0) - (rival?.score ?? 0) }
    private var outcome: (title: String, color: Color, icon: String) {
        lead == 0 ? ("Draw", Theme.cyan, "equal.circle.fill") :
            lead > 0 ? ("You win", Theme.gold, "crown.fill") : ("Rival wins", Theme.pink, "flag.checkered")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    hero
                    comparison
                    breakdown
                }.padding(.bottom, 16)
            }.scrollIndicators(.hidden)
            actions
        }
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) { revealed = true } }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("cosmic-bunny").resizable().scaledToFill().frame(height: 200).frame(maxWidth: .infinity).clipped().opacity(0.55)
            LinearGradient(colors: [Theme.ink.opacity(0.1), Theme.ink.opacity(0.7), Theme.ink], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Stage complete · match \(client.snapshot?.matchID ?? 0)", color: Theme.cyan)
                    HStack(spacing: 8) {
                        Image(systemName: outcome.icon).font(.system(size: 26, weight: .black))
                        Text(outcome.title).font(Theme.display(38))
                    }.foregroundStyle(outcome.color)
                    Text(lead == 0 ? "Identical scores on \(client.chart?.title ?? "")." :
                            "\(lead > 0 ? "Ahead" : "Behind") by \(Theme.score(abs(lead))) on \(client.chart?.title ?? "").")
                        .font(Theme.body(13)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(Theme.rank(for: me?.accuracy ?? 0)).font(Theme.display(40)).foregroundStyle(Theme.ink)
                    Text("RANK").font(.system(size: 8, weight: .black)).foregroundStyle(Theme.ink.opacity(0.7))
                }
                .frame(width: 78, height: 78)
                .background(LinearGradient(colors: [Theme.gold, Theme.pink], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .scaleEffect(revealed ? 1 : 0.4).opacity(revealed ? 1 : 0)
            }.padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(outcome.color.opacity(0.4), lineWidth: 1))
    }

    private var comparison: some View {
        Card(padding: 16) {
            VStack(spacing: 14) {
                HStack {
                    playerLabel(me, color: Theme.pink)
                    Spacer()
                    playerLabel(rival, color: Theme.cyan, trailing: true)
                }
                compareRow("Score", Theme.score(me?.score ?? 0), Theme.score(rival?.score ?? 0),
                           Double(me?.score ?? 0), Double(rival?.score ?? 0))
                compareRow("Achievement", String(format: "%.2f%%", me?.accuracy ?? 0), String(format: "%.2f%%", rival?.accuracy ?? 0),
                           me?.accuracy ?? 0, rival?.accuracy ?? 0)
                compareRow("Max combo", "\(me?.maxCombo ?? 0)", "\(rival?.maxCombo ?? 0)",
                           Double(me?.maxCombo ?? 0), Double(rival?.maxCombo ?? 0))
            }
        }
    }

    private func playerLabel(_ player: Player?, color: Color, trailing: Bool = false) -> some View {
        HStack(spacing: 8) {
            if trailing { Text(player?.name ?? "Rival").font(Theme.title(14)) }
            Avatar(name: player?.name, color: color, size: 30)
            if !trailing { Text(player?.name ?? "You").font(Theme.title(14)) }
        }
    }

    private func compareRow(_ label: String, _ mine: String, _ theirs: String, _ a: Double, _ b: Double) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(mine).font(Theme.mono(15)).foregroundStyle(a >= b ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
                Eyebrow(label)
                Spacer()
                Text(theirs).font(Theme.mono(15)).foregroundStyle(b >= a ? Theme.textPrimary : Theme.textSecondary)
            }
            GeometryReader { geo in
                let total = max(1, a + b)
                let share = revealed ? a / total : 0.5
                HStack(spacing: 2) {
                    Capsule().fill(Theme.pink).frame(width: max(0, geo.size.width * share - 1))
                    Capsule().fill(Theme.cyan)
                }
            }.frame(height: 5)
        }
    }

    private var breakdown: some View {
        Card(padding: 16) {
            VStack(spacing: 10) {
                HStack { Eyebrow("Judgments"); Spacer(); Eyebrow("You / Rival") }
                ForEach(["PERFECT", "GREAT", "GOOD", "MISS"], id: \.self) { grade in
                    let mine = me?.counts[grade] ?? 0
                    let theirs = rival?.counts[grade] ?? 0
                    let total = max(1, client.chart?.notes.count ?? 1)
                    HStack(spacing: 12) {
                        Text(grade).font(.system(size: 11, weight: .black)).foregroundStyle(Theme.grade(grade)).frame(width: 64, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.stroke)
                                Capsule().fill(Theme.grade(grade)).frame(width: geo.size.width * (revealed ? Double(mine) / Double(total) : 0))
                            }
                        }.frame(height: 6)
                        HStack(spacing: 3) {
                            Text("\(mine)").font(Theme.mono(14)).foregroundStyle(Theme.textPrimary)
                            Text("/ \(theirs)").font(Theme.mono(11, weight: .bold)).foregroundStyle(Theme.textTertiary)
                        }.frame(width: 62, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if rival?.ready == true && me?.ready != true {
                Label("\(rival?.name ?? "Rival") wants a rematch", systemImage: "hand.wave.fill")
                    .font(Theme.body(12, weight: .bold)).foregroundStyle(Theme.mint)
            }
            Button { client.rematch() } label: {
                HStack(spacing: 10) {
                    if me?.ready == true { ProgressView().tint(Theme.textTertiary) } else { Image(systemName: "arrow.clockwise") }
                    Text(me?.ready == true ? "Waiting for \(rival?.name ?? "rival")…" : "Rematch")
                }
            }
            .buttonStyle(PrimaryButtonStyle(color: Theme.cyan)).disabled(me?.ready == true)
            .accessibilityIdentifier("rematchButton")
            Button("Leave stage") { client.leave() }.buttonStyle(SecondaryButtonStyle(color: Theme.textSecondary))
        }
        .padding(.top, 12)
        .background(LinearGradient(colors: [Theme.ink.opacity(0), Theme.ink.opacity(0.9)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }
}
