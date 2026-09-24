import SwiftUI

@main
struct MidnightApp: App {
    @StateObject private var session = GameSession()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ClubView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
                .onReceive(session.timer) { session.tick($0) }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active && session.game != nil { session.setPaused(true) }
                }
        }
    }
}

struct ClubView: View {
    @EnvironmentObject private var session: GameSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showcase = Table()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let game = session.game {
                PlayView(game: game)
            } else {
                home
            }
            if session.paused && session.game?.finished == false {
                pauseOverlay.transition(.opacity)
            }
            if session.game?.finished == true {
                results.transition(.opacity)
            }
            if session.showRules {
                RulesSheet { session.showRules = false }.transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: session.paused)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: session.showRules)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: session.game?.finished)
        .tint(Theme.accent)
        .statusBarHidden()
    }

    // MARK: Home

    private var home: some View {
        ZStack {
            GeometryReader { geometry in
                TableView(table: showcase)
                    .frame(width: geometry.size.width * 1.05)
                    .drawingGroup()
                    .shadow(color: .black.opacity(0.6), radius: 30, y: 20)
                    .rotationEffect(.degrees(-12))
                    .offset(x: geometry.size.width * 0.34, y: geometry.size.height * 0.1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                LinearGradient(
                    stops: [
                        .init(color: Theme.background, location: 0.3),
                        .init(color: Theme.background.opacity(0.82), location: 0.55),
                        .init(color: Theme.background.opacity(0.35), location: 1),
                    ], startPoint: .leading, endPoint: .trailing)
                LinearGradient(
                    colors: [.clear, Theme.background.opacity(0.7)], startPoint: .center, endPoint: .bottom)
            }
            .ignoresSafeArea()

            HStack(alignment: .center, spacing: 40) {
                VStack(alignment: .leading, spacing: 0) {
                    BallBadge(number: 8, size: 34)
                    Spacer(minLength: 12)
                    Text("Midnight\nBilliards")
                        .font(.ui(42, .heavy))
                        .tracking(-1.2)
                        .lineSpacing(-2)
                        .foregroundStyle(Theme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(
                        "Real-physics pool. Play eight-ball against Avery or chase a high score against the clock."
                    )
                    .font(.ui(15))
                    .foregroundStyle(Theme.secondary)
                    .lineSpacing(2)
                    .frame(maxWidth: 330, alignment: .leading)
                    .padding(.top, 10)
                    Spacer(minLength: 14)
                    HStack(spacing: 10) {
                        stat(session.best.formatted(), "Best score")
                        stat("\(session.wins)", "Wins")
                        stat(session.totalPots.formatted(), "Balls potted")
                    }
                    Spacer(minLength: 14)
                    HStack(spacing: 8) {
                        chip("How to play", systemImage: "questionmark.circle") { session.showRules = true }
                        chip(
                            session.soundOn ? "Sound on" : "Sound off",
                            systemImage: session.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill"
                        ) { session.toggleSound() }
                        .accessibilityLabel(session.soundOn ? "Mute sound" : "Enable sound")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    modeCard(
                        title: "Play Avery", subtitle: "8-ball match", primary: true
                    ) { session.start(.match) }
                    .accessibilityIdentifier("startMatch")
                    modeCard(
                        title: "Challenge", subtitle: "3 min · beat your best", primary: false
                    ) { session.start(.challenge) }
                    .accessibilityIdentifier("startChallenge")
                }
                .frame(width: 320)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.ui(20, .bold)).monospacedDigit().foregroundStyle(Theme.primary)
            Text(label).font(.ui(12)).foregroundStyle(Theme.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 92, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke))
        .accessibilityElement(children: .combine)
    }

    private func chip(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.ui(13, .medium))
                .foregroundStyle(Theme.secondary)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Capsule().fill(.white.opacity(0.05)))
                .overlay(Capsule().strokeBorder(Theme.stroke))
                .frame(minHeight: 44)
        }
        .buttonStyle(PressStyle())
    }

    private func modeCard(
        title: String, subtitle: String, primary: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(primary ? Theme.onAccent.opacity(0.12) : .white.opacity(0.06))
                    if primary {
                        RackGlyph().frame(width: 38, height: 34)
                    } else {
                        TimerGlyph().frame(width: 34, height: 34)
                    }
                }
                .frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.ui(19, .bold)).tracking(-0.3)
                    Text(subtitle).font(.ui(13)).opacity(0.72)
                }
                .lineLimit(1)
                .fixedSize()
                Spacer(minLength: 4)
                Image(systemName: primary ? "play.fill" : "chevron.right")
                    .font(.ui(14, .bold))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(primary ? Theme.onAccent.opacity(0.14) : .white.opacity(0.08)))
            }
            .foregroundStyle(primary ? Theme.onAccent : Theme.primary)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background {
                if primary {
                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.accentFill)
                        .shadow(color: Theme.accent.opacity(0.3), radius: 20, y: 8)
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Theme.surface.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.stroke))
                }
            }
        }
        .buttonStyle(PressStyle())
    }

    // MARK: Overlays

    private var pauseOverlay: some View {
        Modal {
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paused").font(.ui(30, .bold)).tracking(-0.6).foregroundStyle(Theme.primary)
                    if let game = session.game {
                        Text(game.mode == .match ? "Eight-ball vs. Avery" : "Timed Challenge")
                            .font(.ui(15)).foregroundStyle(Theme.secondary)
                        Spacer(minLength: 12)
                        HStack(spacing: 10) {
                            if game.mode == .challenge {
                                SummaryStat(value: game.score.formatted(), label: "Score")
                                SummaryStat(value: clock(game.secondsRemaining), label: "Left")
                            } else {
                                SummaryStat(value: "\(game.remaining(for: 0).count)", label: "Your balls")
                                SummaryStat(value: "\(game.remaining(for: 1).count)", label: "Avery’s")
                            }
                            SummaryStat(value: "\(game.shots)", label: "Shots")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 8) {
                    Button {
                        session.setPaused(false)
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button("Restart") { if let mode = session.game?.mode { session.start(mode) } }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("How to play") { session.showRules = true }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Main menu") {
                        session.game = nil
                        session.paused = false
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .frame(width: 210)
            }
            .frame(height: 216)
        }
    }

    private var results: some View {
        Modal {
            if let game = session.game {
                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        if game.mode == .challenge && session.newBest {
                            Label("New personal best", systemImage: "star.fill")
                                .font(.ui(12, .semibold))
                                .foregroundStyle(Theme.onAccent)
                                .padding(.horizontal, 10)
                                .frame(height: 26)
                                .background(Capsule().fill(Theme.accentFill))
                        }
                        Text(game.resultTitle).font(.ui(30, .bold)).tracking(-0.6).foregroundStyle(
                            Theme.primary)
                        if game.mode == .challenge {
                            Text(game.score.formatted())
                                .font(.ui(58, .heavy))
                                .tracking(-1.5)
                                .monospacedDigit()
                                .foregroundStyle(Theme.accent)
                                .contentTransition(.numericText())
                            Text("points").font(.ui(14)).foregroundStyle(Theme.secondary).offset(y: -6)
                        } else {
                            Text(game.resultDetail).font(.ui(15)).foregroundStyle(Theme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        HStack(spacing: 10) {
                            if game.mode == .challenge {
                                SummaryStat(value: "\(game.pots)", label: "Potted")
                                SummaryStat(value: "\(game.shots)", label: "Shots")
                                SummaryStat(value: "\(game.longestStreak)", label: "Best streak")
                                SummaryStat(value: session.best.formatted(), label: "Personal best")
                            } else {
                                SummaryStat(value: "\(game.shots)", label: "Shots")
                                SummaryStat(value: "\(session.wins)", label: "Total wins")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 8) {
                        if game.mode == .match {
                            BallBadge(number: 8, size: 64).padding(.bottom, 14)
                        }
                        Spacer(minLength: 0)
                        Button {
                            session.start(game.mode)
                        } label: {
                            Label("Play again", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button("Main menu") { session.game = nil }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    .frame(width: 190)
                }
                .frame(height: 216)
            }
        }
    }

    private func clock(_ seconds: Double) -> String {
        let value = Int(ceil(max(0, seconds)))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

// MARK: Gameplay

struct PlayView: View {
    @EnvironmentObject private var session: GameSession
    let game: GameEngine

    var body: some View {
        VStack(spacing: 6) {
            hud
            HStack(spacing: 10) {
                VStack(spacing: 10) {
                    Button {
                        session.showSpin.toggle()
                    } label: {
                        VStack(spacing: 5) {
                            CueFace(spin: session.spin, size: 42)
                            Text(spinLabel).font(.ui(11, .semibold)).foregroundStyle(Theme.secondary)
                                .lineLimit(1).fixedSize()
                        }
                        .frame(width: 60, height: 70)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .disabled(!session.canAim)
                    .opacity(session.canAim ? 1 : 0.4)
                    .accessibilityLabel("Spin: \(spinLabel). Tap to change.")
                    .accessibilityIdentifier("spinControl")
                    FineAimWheel(angle: $session.angle, enabled: session.canAim)
                        .frame(width: 44)
                        .accessibilityIdentifier("aimAngle")
                    Text("Fine").font(.ui(11, .semibold)).foregroundStyle(Theme.tertiary)
                }
                .frame(width: 60)
                TableView(
                    table: game.table, angle: session.angle,
                    power: game.turn == 1 ? session.power : 0.12 + (session.pull ?? 0) * 0.88,
                    aiming: !game.shooting && !game.finished && !(game.ballInHand && game.turn == 1),
                    ballInHand: game.ballInHand, kitchen: game.kitchen,
                    calledPocket: game.calledPocket, requireCall: game.requiresCall,
                    onTouch: session.touchTable
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                PowerCue(
                    pull: $session.pull, lastPower: session.lastPower, enabled: session.canPull,
                    onShoot: session.strike
                )
                .frame(width: 60)
                .accessibilityIdentifier("shotPower")
            }
            .overlay(alignment: .topLeading) {
                if session.showSpin {
                    SpinPicker(spin: $session.spin) { session.showSpin = false }
                        .offset(x: 70)
                        .transition(.scale(scale: 0.92, anchor: .topLeading).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.16), value: session.showSpin)
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var spinLabel: String {
        session.spin == 0 ? "Center" : session.spin > 0 ? "Follow" : "Draw"
    }

    private var hud: some View {
        HStack(spacing: 12) {
            HUDButton(systemImage: "pause.fill", label: "Pause game") { session.setPaused(true) }
                .accessibilityIdentifier("pauseGame")
            if game.mode == .match {
                PlayerTag(
                    name: "You", group: game.humanGroup, remaining: game.remaining(for: 0),
                    active: game.turn == 0, alignment: .leading)
                statusPill
                PlayerTag(
                    name: "Avery", group: game.group(for: 1), remaining: game.remaining(for: 1),
                    active: game.turn == 1, alignment: .trailing)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(game.score.formatted())
                        .font(.ui(26, .heavy)).tracking(-0.6).monospacedDigit()
                        .foregroundStyle(Theme.primary)
                        .contentTransition(.numericText())
                    if game.streak > 1 {
                        Text("×\(min(5, game.streak))")
                            .font(.ui(13, .heavy))
                            .foregroundStyle(Theme.onAccent)
                            .padding(.horizontal, 7).frame(height: 20)
                            .background(Capsule().fill(Theme.accentFill))
                    }
                }
                .frame(minWidth: 130, alignment: .leading)
                .animation(.easeOut(duration: 0.25), value: game.score)
                statusPill
                timer
            }
            HUDButton(
                systemImage: session.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                label: session.soundOn ? "Mute sound" : "Enable sound"
            ) { session.toggleSound() }
        }
        .frame(height: 46)
    }

    private var statusPill: some View {
        VStack(spacing: 1) {
            Text(game.status)
                .font(.ui(15, .semibold))
                .foregroundStyle(Theme.primary)
            Text(game.detail)
                .font(.ui(12))
                .foregroundStyle(Theme.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("shotStatus")
    }

    private var timer: some View {
        let seconds = Int(ceil(game.secondsRemaining))
        let urgent = seconds <= 30
        return HStack(spacing: 10) {
            VStack(alignment: .trailing, spacing: 0) {
                Text("Best").font(.ui(11)).foregroundStyle(Theme.tertiary)
                Text(session.best.formatted()).font(.ui(13, .semibold)).monospacedDigit()
                    .foregroundStyle(Theme.secondary)
            }
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                .font(.ui(20, .bold)).monospacedDigit()
                .foregroundStyle(urgent ? Theme.hot : Theme.primary)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Capsule().fill(urgent ? Theme.hot.opacity(0.14) : .white.opacity(0.06)))
                .overlay(Capsule().strokeBorder(urgent ? Theme.hot.opacity(0.5) : Theme.stroke))
                .accessibilityIdentifier("challengeTimer")
        }
        .frame(minWidth: 130, alignment: .trailing)
    }
}

struct PlayerTag: View {
    let name: String
    let group: BallGroup?
    let remaining: [Int]
    let active: Bool
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            HStack(spacing: 6) {
                if alignment == .trailing { groupLabel }
                Text(name).font(.ui(14, .bold)).foregroundStyle(active ? Theme.primary : Theme.secondary)
                if alignment == .leading { groupLabel }
            }
            HStack(spacing: 3) {
                if group == nil {
                    ForEach(0..<7, id: \.self) { _ in
                        Circle().strokeBorder(Theme.tertiary.opacity(0.6), lineWidth: 1).frame(
                            width: 12, height: 12)
                    }
                } else if remaining.isEmpty {
                    BallBadge(number: 8, size: 14)
                    Text("Call a pocket").font(.ui(11, .semibold)).foregroundStyle(Theme.accent)
                } else {
                    ForEach(remaining, id: \.self) { BallBadge(number: $0, size: 14, plain: true) }
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 176, height: 46, alignment: alignment == .leading ? .leading : .trailing)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(active ? Color.white.opacity(0.08) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(active ? Theme.accent.opacity(0.7) : Theme.stroke, lineWidth: active ? 1.2 : 1)
        )
        .animation(.easeOut(duration: 0.2), value: active)
        .accessibilityElement(children: .combine)
    }

    private var groupLabel: some View {
        Text(group?.rawValue ?? "Open")
            .font(.ui(11, .medium))
            .foregroundStyle(Theme.tertiary)
    }
}

struct SummaryStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.ui(18, .bold)).monospacedDigit().foregroundStyle(Theme.primary)
            Text(label).font(.ui(11)).foregroundStyle(Theme.tertiary).lineLimit(1).fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.05)))
        .accessibilityElement(children: .combine)
    }
}

struct Modal<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            content
                .padding(24)
                .frame(maxWidth: 600)
                .panel(radius: 28)
                .padding(16)
        }
    }
}

struct RulesSheet: View {
    let onClose: () -> Void
    @State private var tab = 0

    var body: some View {
        Modal {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("How to play").font(.ui(24, .bold)).tracking(-0.4).foregroundStyle(Theme.primary)
                    Spacer()
                    HStack(spacing: 2) {
                        segment("Controls", 0)
                        segment("Eight-ball", 1)
                        segment("Challenge", 2)
                    }
                    .padding(3)
                    .background(Capsule().fill(.white.opacity(0.06)))
                    HUDButton(systemImage: "xmark", label: "Close rules", action: onClose)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.0)
                                    .font(.ui(14, .semibold))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Theme.accent.opacity(0.12)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.1).font(.ui(15, .semibold)).foregroundStyle(Theme.primary)
                                    Text(item.2).font(.ui(13)).foregroundStyle(Theme.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 200)
            }
        }
    }

    private func segment(_ title: String, _ index: Int) -> some View {
        Button {
            tab = index
        } label: {
            Text(title)
                .font(.ui(13, .semibold))
                .foregroundStyle(tab == index ? Theme.onAccent : Theme.secondary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    Capsule().fill(tab == index ? AnyShapeStyle(Theme.accentFill) : AnyShapeStyle(.clear)))
        }
        .buttonStyle(PressStyle())
    }

    private var items: [(String, String, String)] {
        switch tab {
        case 0:
            return [
                (
                    "hand.point.up.left", "Aim",
                    "Drag anywhere on the table. The dotted line shows where the cue ball meets its target; the gold line shows where that ball goes."
                ),
                ("dial.low", "Fine-tune", "Roll the wheel on the left for tiny adjustments."),
                (
                    "arrow.down.to.line", "Shoot",
                    "Pull the cue on the right down to set power, then let go. Slide back up to cancel."
                ),
                (
                    "circle.circle", "Spin",
                    "Tap the cue ball on the left. Follow keeps it rolling forward; draw pulls it back."
                ),
                ("hand.draw", "Ball in hand", "Drag the cue ball to a new spot, then shoot."),
            ]
        case 1:
            return [
                (
                    "circle.grid.3x3", "Claim a group",
                    "The table is open after the break. Your first legal pot decides solids or stripes."
                ),
                (
                    "arrow.triangle.turn.up.right.circle", "Keep your turn",
                    "Hit one of your balls first and pot it to shoot again."
                ),
                (
                    "exclamationmark.triangle", "Fouls",
                    "Scratching, hitting the wrong ball first, or no ball reaching a rail gives your opponent ball in hand."
                ),
                (
                    "8.circle", "Win",
                    "Clear your group, tap a pocket to call it, then sink the 8-ball there. Sinking it early or scratching on it loses."
                ),
            ]
        default:
            return [
                (
                    "timer", "Three minutes",
                    "Pot as many balls as you can. A shot in progress always finishes."
                ),
                ("flame", "Streaks", "Each pot is worth 100 × your streak, up to 5×. Missing resets it."),
                ("arrow.uturn.backward.circle", "Scratch", "Costs 50 points and gives you ball in hand."),
                ("sparkles", "Clear the rack", "+500 and a fresh rack."),
            ]
        }
    }
}

struct RackGlyph: View {
    var body: some View {
        Canvas { context, size in
            let radius = size.width / 8.4
            let colors = [8, 1, 9, 3, 11, 2]
            var index = 0
            for row in 0..<3 {
                for column in 0...row {
                    let x = size.width / 2 + (Double(column) - Double(row) / 2) * radius * 2.1
                    let y = radius + Double(row) * radius * 1.85
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(
                        Path(ellipseIn: rect), with: .color(Club.ballColor(colors[index % colors.count])))
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [.white.opacity(0.45), .clear, .black.opacity(0.35)]),
                            center: CGPoint(x: x - radius * 0.35, y: y - radius * 0.4), startRadius: 0,
                            endRadius: radius * 1.3))
                    index += 1
                }
            }
        }
    }
}

struct TimerGlyph: View {
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.14), lineWidth: 4)
            Circle().trim(from: 0, to: 0.7)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("3:00").font(.ui(9, .bold)).monospacedDigit().foregroundStyle(Theme.primary)
        }
    }
}
