import SpriteKit
import SwiftUI

@main
struct PocketDerbyApp: App {
    @StateObject private var store = GameStore()
    var body: some Scene {
        WindowGroup {
            DerbyView(store: store)
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}

struct DerbyView: View {
    @ObservedObject var store: GameStore
    @State private var scene: ArenaScene?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PixelSkyline()
                if let scene {
                    if store.screen == .title {
                        TitleScreen(store: store, scene: scene, compact: geometry.size.height < 400)
                    } else {
                        MatchScreen(store: store, scene: scene)
                    }
                }
                if store.engine.paused, store.screen == .match {
                    PausePanel(store: store)
                }
                if store.screen == .results {
                    ResultsPanel(store: store)
                }
                if store.showHelp {
                    HelpPanel(store: store)
                }
            }
            .foregroundStyle(Theme.white)
            .animation(nil, value: store.screen)
            .animation(nil, value: store.showHelp)
            .animation(nil, value: store.engine.paused)
            .onAppear {
                store.reducedMotion = reducedMotion
                scene = ArenaScene(store: store)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    store.pause()
                }
            }
            .onChange(of: reducedMotion) { _, value in store.reducedMotion = value }
        }
    }
}

// MARK: - Title

private struct TitleScreen: View {
    @ObservedObject var store: GameStore
    let scene: ArenaScene
    let compact: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: compact ? 10 : 14) {
                    PixelText("★ ROOFTOP SERIES ★", px: 2, color: Theme.yellow, outline: Theme.ink)
                    Wordmark(px: compact ? 5 : 7)
                    PixelText(
                        "TOY CARS. ROOFTOP FOOTBALL.\n90 FRANTIC SECONDS.",
                        px: 2,
                        color: Theme.white,
                        outline: Theme.ink
                    )
                    Blink(reduced: store.reducedMotion) { on in
                        PixelText("1P  PUSH KICK OFF", px: 2, color: Theme.yellow, outline: Theme.ink)
                            .opacity(on ? 1 : 0)
                    }
                    Button(action: store.start) {
                        HStack(spacing: 14) {
                            PixelText("\(PixelFont.play) KICK OFF", px: 3, color: Theme.ink)
                            Spacer(minLength: 0)
                            PixelText("90 SEC", px: 2, color: Theme.ink)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .fixedSize()
                    }
                    .buttonStyle(PixelButtonStyle())
                    .accessibilityIdentifier("play")
                    HStack(spacing: 12) {
                        Button { store.showHelp = true } label: {
                            PixelText("? HOW TO PLAY", px: 2, color: Theme.ink)
                                .padding(.horizontal, 12).frame(height: 40)
                        }
                        .buttonStyle(PixelButtonStyle(face: Theme.sky, shade: Theme.blue))
                        SoundButton(store: store)
                    }
                }
                .fixedSize()
                VStack(spacing: 8) {
                    HStack {
                        PixelText("ROOFTOP 01", px: 2, color: Theme.white, outline: Theme.ink)
                        Spacer()
                        Blink(interval: 0.7, reduced: store.reducedMotion) { on in
                            PixelText("● CPU READY", px: 2, color: on ? Theme.yellow : Theme.white, outline: Theme.ink)
                        }
                    }
                    .padding(.horizontal, 24)
                    ArenaView(scene: scene)
                        .allowsHitTesting(false)
                        .frame(maxHeight: compact ? 190 : 230)
                    HStack(spacing: 12) {
                        StatChip(title: "WINS", value: "\(store.record.wins)")
                        StatChip(title: "BEST", value: difference(store.record.bestDifference))
                        StatChip(title: "PLAYED", value: "\(store.record.played)")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 4)
            PixelText(
                "2026 POCKET ATHLETIC CLUB · NO CARTRIDGE REQUIRED",
                px: 2,
                color: Theme.skyPale,
                outline: Theme.ink
            )
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

private struct Wordmark: View {
    let px: CGFloat
    var body: some View {
        VStack(alignment: .leading, spacing: -px) {
            PixelText("POCKET", px: px, color: Theme.white, bottom: Theme.sky, outline: Theme.ink, shadow: Theme.ink)
            PixelText("DERBY", px: px, color: Theme.yellow, bottom: Theme.orange, outline: Theme.ink, shadow: Theme.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Match

private struct MatchScreen: View {
    @ObservedObject var store: GameStore
    let scene: ArenaScene
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                PixelText("POCKET DERBY", px: 2, color: Theme.white, outline: Theme.ink)
                Spacer()
                Scoreboard(store: store)
                Spacer()
                Button(action: store.pause) {
                    PixelText(String(PixelFont.pause), px: 3, color: Theme.ink).frame(width: 44, height: 40)
                }
                .buttonStyle(PixelButtonStyle(face: Theme.sky, shade: Theme.blue))
                .accessibilityLabel("Pause match").accessibilityIdentifier("pause")
            }
            .padding(.horizontal, 22)
            .frame(height: 52)
            ZStack {
                ArenaView(scene: scene)
                    .accessibilityLabel("Arena. Tap a location to drive there.")
                    .accessibilityIdentifier("arena")
                if store.engine.phase == .kickoff {
                    Callout(
                        headline: store.engine.phaseTime > 1.2 ? "READY?" : "GO!",
                        caption: "1P IS BLUE · SCORE IN THE RIGHT GOAL",
                        top: Theme.white,
                        bottom: Theme.sky,
                        reduced: store.reducedMotion
                    )
                }
                if store.engine.phase == .goal {
                    Callout(
                        headline: store.engine.lastScorerIsPlayer ? "GOAL!" : "CPU GOAL",
                        caption: store.engine.lastScorerIsPlayer ? "1P SCORES!" : "CPU RED SCORES",
                        top: store.engine.lastScorerIsPlayer ? Theme.yellow : Theme.redLight,
                        bottom: store.engine.lastScorerIsPlayer ? Theme.orange : Theme.red,
                        reduced: store.reducedMotion
                    )
                }
            }
            .animation(nil, value: store.engine.phase)
            ControlDeck(store: store)
        }
        .padding(.bottom, 4)
    }
}

private struct Callout: View {
    let headline: String
    let caption: String
    let top: Color
    let bottom: Color
    let reduced: Bool
    var body: some View {
        VStack(spacing: 10) {
            Blink(interval: 0.12, reduced: reduced) { on in
                PixelText(
                    headline,
                    px: 7,
                    color: on ? top : Theme.white,
                    bottom: on ? bottom : top,
                    outline: Theme.ink,
                    shadow: Theme.ink,
                    center: true
                )
                .offset(y: on ? 0 : -Theme.px)
            }
            PixelText(caption, px: 2, color: Theme.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .pixelPanel()
        }
        .allowsHitTesting(false)
    }
}

private struct Scoreboard: View {
    @ObservedObject var store: GameStore
    var body: some View {
        let closing = store.engine.remaining < 15
        HStack(spacing: 10) {
            TeamBadge(color: Theme.blue, light: Theme.blueLight, letter: "1P")
            PixelText("\(store.engine.playerGoals)", px: 4, color: Theme.blueLight)
            VStack(spacing: 4) {
                Blink(interval: 0.5, reduced: store.reducedMotion || !closing) { on in
                    PixelText(timeLabel, px: 3, color: closing && on ? Theme.redLight : Theme.white)
                }
                HStack(spacing: 2) {
                    ForEach(0 ..< 18, id: \.self) { index in
                        Rectangle()
                            .fill(store.engine
                                .remaining > Double(index) * 5 ? (closing ? Theme.redLight : Theme.yellow) : Theme.ink)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            PixelText("\(store.engine.opponentGoals)", px: 4, color: Theme.redLight)
            TeamBadge(color: Theme.red, light: Theme.redLight, letter: "CPU")
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .pixelPanel()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Score: you \(store.engine.playerGoals), CPU \(store.engine.opponentGoals). \(timeLabel) remaining."
        )
        .accessibilityIdentifier("scoreboard")
    }

    private var timeLabel: String {
        let seconds = Int(ceil(store.engine.remaining))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct ControlDeck: View {
    @ObservedObject var store: GameStore
    var body: some View {
        HStack(spacing: 16) {
            Joystick(store: store).frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 6) {
                PixelText("STEER", px: 2, color: Theme.yellow, outline: Theme.ink)
                PixelText("DRAG PAD OR\nTAP THE PITCH", px: 2, color: Theme.white, outline: Theme.ink)
            }
            Spacer(minLength: 0)
            Button { store.engine.brake() } label: {
                VStack(spacing: 6) {
                    PixelText(String(PixelFont.down), px: 3, color: Theme.ink)
                    PixelText(store.engine.brakeRemaining > 0 ? "STOP!" : "BRAKE", px: 2, color: Theme.ink)
                }
                .frame(width: 76, height: 60)
            }
            .buttonStyle(PixelButtonStyle(
                face: store.engine.brakeRemaining > 0 ? Theme.white : Theme.grey,
                shade: Theme.greyDark
            ))
            .accessibilityLabel("Brake").accessibilityIdentifier("brake")
            Button { store.engine.burst() } label: {
                HStack(spacing: 12) {
                    PixelText(String(PixelFont.bolt), px: 4, color: Theme.ink)
                    VStack(alignment: .leading, spacing: 6) {
                        PixelText("BOOST", px: 3, color: Theme.ink)
                        HStack(spacing: 3) {
                            ForEach(0 ..< 6, id: \.self) { index in
                                Rectangle()
                                    .fill(store.engine.player.boost * 6 > Double(index) + 0.5 ? Theme.ink : Theme.ink
                                        .opacity(0.25))
                                    .frame(width: 12, height: 6)
                            }
                        }
                    }
                }
                .frame(width: 164, height: 60)
            }
            .buttonStyle(PixelButtonStyle(
                face: store.engine.player.boost > 0.12 ? Theme.yellow : Theme.grey,
                shade: store.engine.player.boost > 0.12 ? Theme.orange : Theme.greyDark
            ))
            .accessibilityLabel("Boost").accessibilityIdentifier("boost")
        }
        .padding(.horizontal, 26)
        .frame(height: 84)
    }
}

// MARK: - Panels

private struct PausePanel: View {
    @ObservedObject var store: GameStore
    var body: some View {
        Modal {
            VStack(spacing: 18) {
                PixelText(
                    "PAUSE",
                    px: 6,
                    color: Theme.yellow,
                    bottom: Theme.orange,
                    outline: Theme.ink,
                    shadow: Theme.ink
                )
                Blink(reduced: store.reducedMotion) { on in
                    PixelText("MATCH ON HOLD", px: 2, color: Theme.white).opacity(on ? 1 : 0.35)
                }
                HStack(spacing: 14) {
                    ActionButton("\(PixelFont.play) RESUME", run: store.resume)
                    ActionButton("? HOW TO PLAY", face: Theme.sky, shade: Theme.blue) { store.showHelp = true }
                }
                HStack(spacing: 14) {
                    SoundButton(store: store)
                    ActionButton("QUIT TO TITLE", face: Theme.grey, shade: Theme.greyDark, run: store.home)
                }
            }
            .frame(width: 420)
        }
    }
}

private struct ResultsPanel: View {
    @ObservedObject var store: GameStore
    var body: some View {
        let win = store.engine.playerGoals > store.engine.opponentGoals
        let draw = store.engine.playerGoals == store.engine.opponentGoals
        Modal {
            VStack(spacing: 10) {
                PixelText("FULL TIME · ROOFTOP 01", px: 2, color: Theme.grey)
                Blink(interval: 0.25, reduced: store.reducedMotion || !win) { on in
                    PixelText(
                        win ? "YOU WIN!" : draw ? "DRAW GAME" : "YOU LOSE",
                        px: 5,
                        color: win ? (on ? Theme.yellow : Theme.white) : draw ? Theme.white : Theme.redLight,
                        bottom: win ? (on ? Theme.orange : Theme.yellow) : draw ? Theme.sky : Theme.red,
                        outline: Theme.ink,
                        shadow: Theme.ink
                    )
                }
                HStack(alignment: .center, spacing: 22) {
                    ScoreColumn(color: Theme.blue, light: Theme.blueLight, goals: store.engine.playerGoals, name: "1P")
                    PixelText("-", px: 5, color: Theme.grey)
                    ScoreColumn(color: Theme.red, light: Theme.redLight, goals: store.engine.opponentGoals, name: "CPU")
                }
                PixelText(
                    win ? "THE ROOFTOP IS YOURS." : draw ? "EVEN MATCH. RUN IT BACK." : "FIND THE ANGLE. TRY AGAIN.",
                    px: 2,
                    color: Theme.white
                )
                HStack(spacing: 12) {
                    StatChip(title: "BEST", value: difference(store.record.bestDifference))
                    StatChip(title: "WINS", value: "\(store.record.wins)")
                    StatChip(title: "PLAYED", value: "\(store.record.played)")
                }
                HStack(spacing: 14) {
                    ActionButton("\(PixelFont.play) REMATCH", run: store.start)
                    ActionButton("TITLE", face: Theme.grey, shade: Theme.greyDark, run: store.home)
                }
            }
            .frame(width: 480)
        }
    }
}

private struct ScoreColumn: View {
    let color: Color
    let light: Color
    let goals: Int
    let name: String
    var body: some View {
        HStack(spacing: 14) {
            if name == "1P" {
                TeamBadge(color: color, light: light, letter: name, px: 3)
            }
            PixelText("\(goals)", px: 6, color: light, outline: Theme.ink, shadow: Theme.ink)
            if name != "1P" {
                TeamBadge(color: color, light: light, letter: name, px: 3)
            }
        }
    }
}

private struct HelpPanel: View {
    @ObservedObject var store: GameStore
    var body: some View {
        Modal {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom) {
                    PixelText(
                        "HOW TO PLAY",
                        px: 4,
                        color: Theme.yellow,
                        bottom: Theme.orange,
                        outline: Theme.ink,
                        shadow: Theme.ink
                    )
                    Spacer()
                    PixelText("ROOKIE MANUAL", px: 2, color: Theme.grey)
                }
                HelpItem(
                    icon: PixelFont.pad, tint: Theme.sky, title: "STEER",
                    text: "DRAG PAD OR TAP PITCH TO GO THERE."
                )
                HelpItem(
                    icon: PixelFont.bolt, tint: Theme.yellow, title: "BOOST",
                    text: "TAP TO BURST. REFILLS WHILE DRIVING."
                )
                HelpItem(
                    icon: PixelFont.ball, tint: Theme.redLight, title: "SCORE",
                    text: "BUMP THE BALL INTO THE RIGHT GOAL."
                )
                HStack {
                    PixelText("YOU ARE BLUE. GET BEHIND THE BALL!", px: 2, color: Theme.blueLight)
                    Spacer()
                    ActionButton("\(PixelFont.check) GOT IT") { store.showHelp = false }
                        .frame(width: 140)
                }
            }
            .frame(width: 600)
        }
    }
}

private struct HelpItem: View {
    let icon: Character
    let tint: Color
    let title: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            PixelText(String(icon), px: 3, color: Theme.ink)
                .frame(width: 36, height: 36)
                .background(tint)
                .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: Theme.px))
            PixelText(title, px: 2, color: tint).frame(width: 66, alignment: .leading)
            PixelText(text, px: 2, color: Theme.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Modal<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ZStack {
            Theme.ink.opacity(0.72).ignoresSafeArea()
            content.padding(18)
                .pixelPanel()
                .padding(16)
        }
    }
}

private struct ActionButton: View {
    let title: String
    var face = Theme.yellow
    var shade = Theme.orange
    let run: () -> Void
    init(_ title: String, face: Color = Theme.yellow, shade: Color = Theme.orange, run: @escaping () -> Void) {
        self.title = title
        self.face = face
        self.shade = shade
        self.run = run
    }

    var body: some View {
        Button(action: run) {
            PixelText(title, px: 2, color: Theme.ink)
                .frame(maxWidth: .infinity).frame(height: 44)
        }
        .buttonStyle(PixelButtonStyle(face: face, shade: shade))
    }
}

private struct SoundButton: View {
    @ObservedObject var store: GameStore
    var body: some View {
        Button(action: store.toggleSound) {
            PixelText("\(PixelFont.note) SOUND \(store.sound ? "ON" : "OFF")", px: 2, color: Theme.ink)
                .padding(.horizontal, 12).frame(height: 40)
        }
        .buttonStyle(PixelButtonStyle(face: Theme.grey, shade: Theme.greyDark))
        .accessibilityLabel(store.sound ? "Sound on" : "Sound off")
        .accessibilityIdentifier("sound")
    }
}

private struct StatChip: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            PixelText(value, px: 3, color: Theme.white)
            PixelText(title, px: 2, color: Theme.yellow)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(minWidth: 96, alignment: .leading)
        .pixelPanel()
    }
}

private func difference(_ value: Int?) -> String {
    guard let value else { return "-" }
    return value > 0 ? "+\(value)" : "\(value)"
}

/// Analog stick dressed as a console D-pad; the knob snaps around the cross.
private struct Joystick: View {
    @ObservedObject var store: GameStore
    @State private var knob = CGSize.zero
    var body: some View {
        ZStack {
            Rectangle().fill(Theme.ink).frame(width: 32, height: 80)
            Rectangle().fill(Theme.ink).frame(width: 80, height: 32)
            Rectangle().fill(Theme.grey).frame(width: 24, height: 72)
            Rectangle().fill(Theme.grey).frame(width: 72, height: 24)
            PixelText(String(PixelFont.up), px: 2, color: Theme.greyDark).offset(y: -26)
            PixelText(String(PixelFont.down), px: 2, color: Theme.greyDark).offset(y: 26)
            PixelText(String(PixelFont.back), px: 2, color: Theme.greyDark).offset(x: -26)
            PixelText(String(PixelFont.play), px: 2, color: Theme.greyDark).offset(x: 26)
            Rectangle().fill(knob == .zero ? Theme.greyDark : Theme.yellow)
                .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: Theme.px))
                .overlay(alignment: .top) { Theme.white.frame(height: Theme.px).padding(Theme.px) }
                .frame(width: 24, height: 24)
                .offset(knob)
        }
        .frame(width: 80, height: 80)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            let vector = Vector(x: value.translation.width, y: -value.translation.height)
            let normalized = vector.length > 28 ? vector.unit : vector / 28
            knob = CGSize(width: (normalized.x * 24 / 4).rounded() * 4, height: (-normalized.y * 24 / 4).rounded() * 4)
            store.engine.driveTarget = nil
            store.engine.steering = normalized
        }.onEnded { _ in
            knob = .zero
            store.engine.steering = .zero
        })
        .accessibilityLabel("Steering joystick. Drag in the direction you want to drive.")
        .accessibilityIdentifier("joystick")
    }
}

private struct ArenaView: UIViewRepresentable {
    let scene: ArenaScene

    func makeUIView(context _: Context) -> SKView {
        let view = SKView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ uiView: SKView, context _: Context) {
        if uiView.scene !== scene {
            uiView.presentScene(scene)
        }
    }
}
