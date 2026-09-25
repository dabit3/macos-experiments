import SwiftUI

struct GameView: View {
    @ObservedObject var client: GameClient
    let width: CGFloat

    private var me: Player? { client.me }
    private var rival: Player? { client.rival }
    private var lead: Int { (me?.score ?? 0) - (rival?.score ?? 0) }

    var body: some View {
        VStack(spacing: 10) {
            versus
            ZStack {
                ArenaView(client: client)
                TimelineView(.animation(minimumInterval: 0.1)) { _ in
                    if client.songTime < 0 { countdown }
                }.allowsHitTesting(false)
                if !client.connected { disconnected }
            }
            .frame(width: width - 8, height: width - 8).padding(.horizontal, -14)
            stats
            progress
            Spacer(minLength: 0)
        }
    }

    private var versus: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                scoreBlock(me, color: Theme.pink, alignment: .leading)
                VStack(spacing: 3) {
                    Text(client.chart?.title ?? "").font(Theme.title(13)).lineLimit(1).minimumScaleFactor(0.7)
                    Text(leadText).font(.system(size: 9, weight: .black)).tracking(0.5)
                        .foregroundStyle(lead > 0 ? Theme.mint : lead < 0 ? Theme.pink : Theme.textTertiary)
                }.frame(maxWidth: .infinity)
                scoreBlock(rival, color: Theme.cyan, alignment: .trailing)
            }
            leadMeter
            if !client.automation.isEmpty {
                Chip(text: "Automated input · \(client.automation)", color: Theme.gold, icon: "cpu")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }

    private var leadText: String {
        if lead == 0 { return "TIED" }
        return (lead > 0 ? "+" : "−") + Theme.score(abs(lead)) + (lead > 0 ? " AHEAD" : " BEHIND")
    }

    private func scoreBlock(_ player: Player?, color: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(spacing: 5) {
                if alignment == .trailing { Text(player?.name ?? "Rival") }
                StatusDot(color: player?.connected == true ? color : Theme.textTertiary)
                if alignment == .leading { Text(player?.name ?? "You") }
            }.font(.system(size: 10, weight: .black)).foregroundStyle(color).lineLimit(1)
            Text(Theme.score(player?.score ?? 0)).font(Theme.mono(19)).monospacedDigit()
                .contentTransition(.numericText()).animation(.snappy(duration: 0.2), value: player?.score)
        }.frame(minWidth: 96, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var leadMeter: some View {
        GeometryReader { geo in
            let total = max(1, Double((me?.score ?? 0) + (rival?.score ?? 0)))
            let mine = rival == nil ? 1 : Double(me?.score ?? 0) / total
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.cyan.opacity(0.35))
                Capsule().fill(Theme.pink).frame(width: geo.size.width * (me?.score == 0 && rival?.score == 0 ? 0.5 : mine))
                    .animation(.snappy(duration: 0.3), value: mine)
            }
        }.frame(height: 5)
    }

    private var stats: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.2f%%", me?.accuracy ?? 0)).font(Theme.display(28)).foregroundStyle(Theme.cyan).monospacedDigit()
                Eyebrow("Achievement")
            }
            Spacer()
            HStack(spacing: 8) {
                ForEach(["PERFECT", "GREAT", "GOOD", "MISS"], id: \.self) { grade in
                    VStack(spacing: 2) {
                        Text("\(me?.counts[grade] ?? 0)").font(Theme.mono(13)).monospacedDigit().foregroundStyle(Theme.grade(grade))
                        Text(String(grade.prefix(1))).font(.system(size: 8, weight: .black)).foregroundStyle(Theme.textTertiary)
                    }.frame(minWidth: 22)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(me?.combo ?? 0)").font(Theme.display(34)).foregroundStyle(Theme.gold).monospacedDigit()
                    .contentTransition(.numericText()).animation(.snappy(duration: 0.15), value: me?.combo)
                Eyebrow("Combo")
            }
        }
    }

    private var progress: some View {
        TimelineView(.animation(minimumInterval: 0.2)) { _ in
            let duration = client.chart?.duration ?? 1
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.stroke)
                        Capsule().fill(LinearGradient(colors: [Theme.pink, Theme.gold], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * max(0, min(1, client.songTime / duration)))
                    }
                }.frame(height: 4)
                HStack {
                    Text(client.songTime < 0 ? "Synced start" : "Live score battle")
                    Spacer()
                    Text("\(max(0, Int(duration - client.songTime)))s left").monospacedDigit()
                }.font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var countdown: some View {
        let seconds = max(1, Int(ceil(-client.songTime)))
        return VStack(spacing: 4) {
            Eyebrow("Get ready", color: Theme.cyan)
            Text("\(seconds)").font(Theme.display(96)).foregroundStyle(Theme.gold).monospacedDigit()
                .contentTransition(.numericText(countsDown: true)).animation(.snappy, value: seconds)
            Text("\(me?.name ?? "You")  vs  \(rival?.name ?? "Rival")").font(Theme.title(13)).foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 30).padding(.vertical, 20)
        .background(Theme.ink.opacity(0.88), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.gold.opacity(0.4), lineWidth: 1))
    }

    private var disconnected: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.pink)
            Text("Connection lost").font(Theme.title(18))
            Text("Retrying automatically. Your rival keeps playing.").font(Theme.body(12)).foregroundStyle(Theme.textSecondary)
            Button("Reconnect now") { client.reconnect() }.buttonStyle(SecondaryButtonStyle(color: Theme.gold)).frame(width: 180)
        }
        .padding(24)
        .background(Theme.ink.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.pink.opacity(0.5), lineWidth: 1))
    }
}
