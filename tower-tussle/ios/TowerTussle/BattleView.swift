import SwiftUI

struct BattleView: View {
    @EnvironmentObject var profile: PlayerProfile
    @ObservedObject var engine: BattleEngine
    let onFinished: (MatchResult) -> Void
    let onQuit: () -> Void
    @State private var paused = false
    @State private var finishedHandled = false
    @State private var hover: Vec? = nil

    var body: some View {
        ZStack {
            SceneryBackdrop(dim: 0.55)
            VStack(spacing: 6) {
                hud
                GeometryReader { geo in
                    let scale = min(geo.size.width / Arena.width, geo.size.height / Arena.height)
                    let arenaSize = CGSize(width: Arena.width * scale, height: Arena.height * scale)
                    ZStack {
                        ArenaCanvas(engine: engine, scale: scale, hover: hover)
                            .frame(width: arenaSize.width, height: arenaSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Art.outline, lineWidth: 3))
                            .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
                            .contentShape(Rectangle())
                            .gesture(deployGesture(scale: scale))
                            .accessibilityIdentifier("arena")
                            .accessibilityLabel("Arena")
                            .accessibilityHint(engine.selectedCard == nil ? "Pick a card first" : "Tap your half to deploy \(engine.selectedCard?.name ?? "")")
                        if let text = engine.announcement {
                            Text(text)
                                .font(.system(.headline, design: .rounded).weight(.black))
                                .foregroundStyle(LinearGradient.goldText)
                                .shadow(color: .black, radius: 0, x: 1, y: 1)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 9)
                                .panel(cornerRadius: 22)
                                .transition(.scale.combined(with: .opacity))
                                .accessibilityIdentifier("announcement")
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                handBar
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)

            if paused { pauseMenu }
        }
        .onAppear {
            _ = RenderedArt.frames
            engine.start()
        }
        .onDisappear { engine.stop() }
        .onChange(of: engine.result?.outcome) { _, newValue in
            if newValue != nil, !finishedHandled, let r = engine.result {
                finishedHandled = true
                hover = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { onFinished(r) }
            }
        }
        .overlay {
            if let r = engine.result {
                VStack(spacing: 10) {
                    DisplayText(text: r.outcome.rawValue, size: 58,
                                fill: r.outcome == .victory ? .goldText : (r.outcome == .defeat ? .redText : .whiteText))
                    HStack(spacing: 14) {
                        CrownRow(count: r.playerCrowns, color: Theme.player, size: 24)
                        Text("vs").font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                        CrownRow(count: r.enemyCrowns, color: Theme.enemy, size: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .panel(cornerRadius: 20)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.35).ignoresSafeArea())
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.spring(duration: 0.4), value: r.outcome)
            }
        }
    }

    // MARK: HUD

    private var hud: some View {
        HStack(alignment: .center, spacing: 8) {
            IconButton(icon: .pause, label: "Pause", style: .slate, size: 40) { setPaused(true) }
                .accessibilityIdentifier("quitButton")
                .accessibilityHint("Opens the pause menu with resume, sound and surrender")

            Spacer(minLength: 0)
            VStack(spacing: 2) {
                HStack(spacing: 12) {
                    VStack(spacing: 1) {
                        SectionLabel(text: "Rival", color: Theme.enemy.opacity(0.9))
                        CrownRow(count: engine.crowns(for: .enemy), color: Theme.enemy)
                            .accessibilityIdentifier("enemyCrowns")
                    }
                    Text(timerText)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(engine.isOvertime ? LinearGradient.redText : (engine.isDoubleElixir ? LinearGradient(colors: [Color(red: 0.95, green: 0.65, blue: 1.0), Theme.elixir], startPoint: .top, endPoint: .bottom) : LinearGradient.whiteText))
                        .shadow(color: .black, radius: 0, x: 1, y: 1)
                        .frame(minWidth: 72)
                        .accessibilityIdentifier("timer")
                        .accessibilityLabel("\(engine.remainingSeconds) seconds left")
                    VStack(spacing: 1) {
                        SectionLabel(text: "You", color: Theme.player.opacity(0.9))
                        CrownRow(count: engine.crowns(for: .player), color: Theme.player)
                            .accessibilityIdentifier("playerCrowns")
                    }
                }
                if let phase = phaseText {
                    PhaseChip(text: phase.0, color: phase.1)
                        .accessibilityIdentifier("phaseChip")
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .panel(cornerRadius: 20)
            .layoutPriority(1)
            .animation(.spring(duration: 0.3), value: phaseText?.0)
            Spacer(minLength: 0)

            Color.clear.frame(width: 40, height: 40)
        }
        .foregroundStyle(.white)
        .padding(.top, 4)
    }

    private var phaseText: (String, Color)? {
        if engine.isOvertime { return ("OVERTIME · NEXT TOWER WINS", Theme.enemy) }
        if engine.isDoubleElixir { return ("2× ELIXIR", Theme.elixir) }
        return nil
    }

    private var timerText: String {
        let s = engine.remainingSeconds
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: Deploy

    private func deployGesture(scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard engine.selectedCard != nil, engine.result == nil else { return }
                hover = Vec(x: value.location.x / scale, y: value.location.y / scale)
            }
            .onEnded { value in
                hover = nil
                let before = engine.playerElixir
                engine.deployAtTap(Vec(x: value.location.x / scale, y: value.location.y / scale))
                if engine.playerElixir < before { ArcadeAudio.play(.deploy) }
            }
    }

    // MARK: Hand

    private var handBar: some View {
        VStack(spacing: 8) {
            deployHint
            HStack(alignment: .bottom, spacing: 8) {
                VStack(spacing: 2) {
                    Text("NEXT").font(.system(size: 9, weight: .black, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                    CardFrame(card: Cards.byId(engine.nextCard), showName: false, compact: true)
                        .frame(width: 46)
                        .accessibilityIdentifier("nextCard")
                        .accessibilityLabel("Next card \(Cards.byId(engine.nextCard).name)")
                }
                ForEach(Array(engine.hand.enumerated()), id: \.offset) { index, id in
                    let card = Cards.byId(id)
                    let selected = engine.selectedHandIndex == index
                    CardFrame(card: card, selected: selected, affordable: engine.canAfford(card))
                        .id("\(index)-\(id)")
                        .offset(y: selected ? -12 : 0)
                        .animation(.spring(duration: 0.2), value: selected)
                        .onTapGesture { ArcadeAudio.play(.tap); engine.selectHand(index) }
                        .accessibilityIdentifier("hand-\(index)")
                        .accessibilityLabel("\(card.name), \(card.cost) elixir\(selected ? ", selected" : "")")
                        .accessibilityHint(engine.canAfford(card) ? "Select, then tap the arena to deploy" : "Not enough elixir yet")
                        .accessibilityAddTraits(.isButton)
                }
            }
            ElixirBar(value: engine.playerElixir, max: Arena.maxElixir)
                .accessibilityIdentifier("elixirBar")
        }
        .padding(10)
        .panel(cornerRadius: 18)
    }

    @ViewBuilder
    private var deployHint: some View {
        HStack(spacing: 8) {
            if let card = engine.selectedCard {
                let short = Int(ceil(Double(card.cost) - engine.playerElixir))
                ElixirBadge(cost: card.cost, size: 18)
                Text(card.name.uppercased())
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Text("·").foregroundStyle(.white.opacity(0.4))
                if short > 0 {
                    Text("Need \(short) more elixir")
                        .foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.55))
                } else if card.kind == .spell {
                    Text("Tap anywhere, even on enemy towers")
                } else {
                    Text("Tap or drag on your half to deploy")
                }
            } else {
                Text(engine.isDoubleElixir ? "Elixir is doubled. Pick a card and push!" : "Pick a card, then tap the arena")
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity)
        .frame(height: 18)
        .animation(.easeOut(duration: 0.15), value: engine.selectedHandIndex)
        .accessibilityIdentifier("deployHint")
    }

    // MARK: Pause

    private var pauseMenu: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { setPaused(false) }
            VStack(spacing: 14) {
                DisplayText(text: "PAUSED", size: 40, fill: .whiteText)
                HStack(spacing: 14) {
                    CrownRow(count: engine.crowns(for: .player), color: Theme.player, size: 22)
                    Text(timerText)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    CrownRow(count: engine.crowns(for: .enemy), color: Theme.enemy, size: 22)
                }
                ChunkyButton(title: "RESUME", icon: .swords, style: .gold, height: 58, fontSize: 22) { setPaused(false) }
                    .accessibilityIdentifier("resumeButton")
                ChunkyButton(title: profile.soundEnabled ? "SOUND ON" : "SOUND OFF", icon: .sound(on: profile.soundEnabled), style: .slate, height: 48, fontSize: 17) {
                    profile.setSoundEnabled(!profile.soundEnabled)
                }
                .accessibilityIdentifier("pauseSoundButton")
                ChunkyButton(title: "SURRENDER", style: .red, height: 48, fontSize: 17) {
                    setPaused(false)
                    onQuit()
                }
                .accessibilityIdentifier("surrenderButton")
                Text("Surrendering counts as a 3-crown defeat.")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(22)
            .frame(maxWidth: 320)
            .panel(cornerRadius: 24)
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
        .accessibilityIdentifier("pauseMenu")
    }

    private func setPaused(_ value: Bool) {
        guard engine.result == nil else { return }
        withAnimation(.easeOut(duration: 0.2)) { paused = value }
        if value { engine.stop() } else { engine.start() }
    }
}
