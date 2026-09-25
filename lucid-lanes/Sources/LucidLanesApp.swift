import LinkPresentation
import SwiftUI
import UIKit

@main
struct LucidLanesApp: App {
    @StateObject private var model = GameModel()
    var body: some Scene {
        WindowGroup { ContentView(model: model).preferredColorScheme(.dark) }
    }
}

struct ContentView: View {
    @ObservedObject var model: GameModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showRooms = false
    @State private var showSettings = false
    @State private var sharePayload: SharePayload?
    @State private var shareFailed = false
    private let timer = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Dream.ink.ignoresSafeArea()
                if model.screen == "home" { home(compact: geometry.size.height < 700) }
                if model.screen == "play" { play(size: geometry.size) }
                if model.screen == "result" { result }
                if model.screen == "play" && model.tutorial { tutorial }
                if model.screen == "play" && model.paused && !model.tutorial { pause }
            }
        }
        .tint(Dream.mint)
        .foregroundStyle(Dream.cream)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .onReceive(timer) { model.tick($0, reduceMotion: reduceMotion) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && model.screen == "play" { model.paused = true }
        }
        .sheet(isPresented: $showRooms) { rooms }
        .sheet(isPresented: $showSettings) { settings }
        .sheet(item: $sharePayload) { payload in
            NativeShare(payload: payload).presentationDetents([.large])
        }
        .alert("Your dream couldn't be prepared", isPresented: $shareFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try sharing again.")
        }
    }

    private func home(compact: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 9) {
                    DecoEmblem().frame(width: 28, height: 28)
                    Text("THE DREAM HOTEL").font(Dream.label(10)).tracking(2)
                }
                Spacer()
                iconButton("slider.horizontal.3", label: "Settings", id: "settings") { showSettings = true }
            }
            .padding(.horizontal, 24)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: -9) {
                    Text("Lucid").font(Dream.display(compact ? 57 : 76)).italic().tracking(-3)
                    Text("LANES").font(.custom("AvenirNext-UltraLight", size: compact ? 27 : 33)).tracking(9)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text("BOWLING,").foregroundStyle(Dream.cream)
                    Text("SOMEWHERE ELSE.").foregroundStyle(Dream.muted)
                }
                .font(Dream.label(8)).tracking(1).padding(.bottom, 7)
            }
            .padding(.horizontal, 28).padding(.top, compact ? 0 : 6)
            LaneArtwork(model: model, hero: true)
                .overlay(alignment: .top) {
                    LinearGradient(colors: [Dream.ink, .clear], startPoint: .top, endPoint: .bottom).frame(height: 30)
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, Dream.ink], startPoint: .top, endPoint: .bottom).frame(height: 38)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 7) {
                        Circle().fill(Dream.mint).frame(width: 4, height: 4)
                        Text("EST. IN A DREAM  /  OPEN ALL NIGHT").font(Dream.label(8)).tracking(1.2)
                    }.foregroundStyle(Dream.lavender).padding(.horizontal, 28).padding(.bottom, 12)
                }
                .accessibilityHidden(true)
            VStack(spacing: compact ? 12 : 16) {
                HStack(alignment: .center) {
                    RoomKey(number: model.unlocked + 1).frame(width: 44, height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        eyebrow("YOUR ROOM IS READY")
                        Text(Lane.all[model.unlocked].name).font(Dream.display(25))
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        Text("\(model.best.filter { $0 > 0 }.count) / 8").font(Dream.label(12))
                        Text("VISITED").font(Dream.label(7)).tracking(1.2).foregroundStyle(Dream.muted)
                    }
                }
                primary("Enter the lanes", symbol: "arrow.up.right", id: "enter-lanes") {
                    model.start(lane: model.unlocked)
                }
                HStack(spacing: 20) {
                    secondary("Room directory", id: "rooms") { showRooms = true }
                    secondary("Practice", id: "practice") { model.start(lane: 0, practice: true) }
                }
            }
            .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 12)
        }
    }

    private func play(size: CGSize) -> some View {
        VStack(spacing: 0) {
            playHeader
            ZStack {
                LaneArtwork(model: model).accessibilityHidden(true)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 12)
                            .onChanged { value in
                                guard model.phase == "ready", !model.paused, !model.tutorial else { return }
                                model.dragging = true
                                model.aim = max(-1, min(1, value.translation.width / (size.width * 0.42)))
                                model.power = max(0.1, min(1, -value.translation.height / 210))
                            }
                            .onEnded { value in
                                if value.translation.height < -25 { model.launch() }
                                model.dragging = false
                            }
                    )
                    .accessibilityLabel("Bowling aim")
                    .accessibilityValue("\(Int(model.aim * 100)) percent \(model.aim < 0 ? "left" : "right")")
                    .accessibilityHint("Swipe up or down to adjust aim, then use the Bowl button")
                    .accessibilityAdjustableAction { direction in
                        guard model.phase == "ready" else { return }
                        model.aim = max(-1, min(1, model.aim + (direction == .increment ? 0.1 : -0.1)))
                    }
                    .accessibilityIdentifier("bowling-playfield")
            }
            .overlay(alignment: .top) {
                HStack {
                    Label(
                        model.lane.bumper ? "BANK SHOTS" : "OPEN GUTTERS",
                        systemImage: model.lane.bumper ? "arrow.triangle.branch" : "exclamationmark.circle")
                    Spacer()
                    Text("GOLD / \(model.lane.gold)")
                }.font(Dream.label(9)).tracking(1)
                    .foregroundStyle(Dream.lavender).padding(.horizontal, 24).padding(.top, 14)
                    .allowsHitTesting(false)
            }
            Text(model.dragging ? "POWER  \(Int(model.power * 100))%" : model.message.uppercased())
                .font(model.phase == "settling" ? Dream.display(27) : Dream.label(10))
                .tracking(model.phase == "settling" ? 2 : 1.5)
                .foregroundStyle(model.phase == "settling" ? Dream.peach : Dream.mint)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(Dream.velvet.opacity(0.35))
                .accessibilityIdentifier("shot-status").allowsHitTesting(false)
            playControls
        }
    }

    private var playHeader: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                RoomKey(number: model.selectedLane + 1).frame(width: 36, height: 45)
                VStack(alignment: .leading, spacing: 3) {
                    eyebrow(model.practice ? "PRACTICE / NO PRESSURE" : "THE DREAM HOTEL")
                    Text(model.lane.name).font(Dream.display(25))
                }
                Spacer(minLength: 0)
                iconButton("pause", label: "Pause", id: "pause") { model.paused = true }
            }
            HStack(spacing: 0) {
                ForEach(0..<3) { i in
                    VStack(spacing: 5) {
                        Text("FRAME 0\(i + 1)").font(Dream.label(8)).tracking(1)
                            .foregroundStyle(Dream.muted)
                        Text(model.game.symbols(for: i)).font(.system(size: 19, weight: .medium, design: .monospaced))
                            .foregroundStyle(i == model.game.frames.count - 1 ? Dream.mint : Dream.cream)
                    }.frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(i == model.game.frames.count - 1 ? Dream.velvet : .clear)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(i == model.game.frames.count - 1 ? Dream.mint : .clear).frame(height: 2)
                        }
                }
                VStack(spacing: 0) {
                    Text("\(model.game.score)").font(Dream.display(32)).contentTransition(.numericText())
                    Text("TOTAL").font(Dream.label(7)).tracking(1)
                }.foregroundStyle(Dream.ink).frame(maxWidth: .infinity, minHeight: 59)
                    .background(Dream.cream)
            }
            .overlay(Rectangle().stroke(Dream.lavender.opacity(0.18), lineWidth: 0.5))
        }
        .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 5)
    }

    private var playControls: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Text("SHOT CONTROL").font(Dream.label(8)).tracking(1.5)
                Rectangle().fill(Dream.lavender.opacity(0.18)).frame(height: 0.5)
                HStack(spacing: 2) {
                    ForEach(0..<12) { i in
                        Rectangle().fill(Double(i) < model.power * 12 ? Dream.peach : Dream.velvet).frame(
                            width: 4, height: 7)
                    }
                }.accessibilityLabel("Power \(Int(model.power * 100)) percent")
            }.foregroundStyle(Dream.muted)
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    HStack {
                        Text("CURVE").tracking(1)
                        Spacer()
                        Text(
                            model.curve < -0.05
                                ? "L \(Int(abs(model.curve) * 100))"
                                : model.curve > 0.05 ? "R \(Int(model.curve * 100))" : "STRAIGHT")
                    }.font(Dream.label(8)).foregroundStyle(Dream.lavender)
                    Slider(value: $model.curve, in: -1...1, step: 0.1)
                        .accessibilityLabel("Curve").accessibilityIdentifier("curve").disabled(model.phase != "ready")
                }
                Button {
                    model.curve = 0
                } label: {
                    Image(systemName: "scope").font(.system(size: 19)).frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Dream.lavender.opacity(0.25), lineWidth: 1))
                }
                .accessibilityLabel("Reset curve to straight").accessibilityIdentifier("curve-reset").disabled(
                    model.phase != "ready")
                Button {
                    model.launch()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "arrow.up").font(.system(size: 20, weight: .medium))
                        Text("BOWL").font(Dream.label(8)).tracking(1)
                    }.frame(width: 60, height: 60)
                        .foregroundStyle(Dream.ink)
                        .background(
                            LinearGradient(
                                colors: [Dream.cream, Dream.peach], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Circle()
                        )
                        .overlay(Circle().inset(by: 4).stroke(Dream.ink.opacity(0.2), lineWidth: 0.5))
                }
                .accessibilityLabel("Bowl with current aim and power").accessibilityIdentifier("bowl").disabled(
                    model.phase != "ready")
            }
            Text(
                model.phase == "ready" ? "Drag the lane to aim. Release to bowl." : "A little patience. A little magic."
            )
            .font(.custom("AvenirNext-Regular", size: 11)).foregroundStyle(Dream.muted)
        }
        .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 10)
    }

    private var result: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    eyebrow("THE DREAM HOTEL")
                    Spacer()
                    iconButton("xmark", label: "Return home", id: "result-home") { model.screen = "home" }
                }
                ResultCard(lane: model.lane, score: model.game.score, medal: model.medal, frames: model.game)
                Text(
                    model.medal == "NO MEDAL"
                        ? "The corridor has another dream for you." : "Some dreams are worth keeping."
                )
                .font(Dream.display(18)).italic().foregroundStyle(Dream.lavender)
                .multilineTextAlignment(.center)
                HStack {
                    Text(model.practice ? "PRACTICE COMPLETE" : "PERSONAL BEST")
                    Spacer()
                    Text(model.practice ? "TRY A CHALLENGE" : "\(model.best[model.selectedLane]) POINTS")
                }.font(.system(size: 9, weight: .medium)).tracking(1.2).foregroundStyle(Dream.muted)
                primary("Share this dream", symbol: "square.and.arrow.up", id: "share") {
                    let card = ResultCard(
                        lane: model.lane, score: model.game.score, medal: model.medal, frames: model.game
                    )
                    .frame(width: 390).padding(30).background(Dream.ink).environment(\.colorScheme, .dark)
                    let renderer = ImageRenderer(content: card)
                    renderer.scale = 3
                    if let image = renderer.uiImage {
                        sharePayload = SharePayload(
                            image: image,
                            text: "Lucid Lanes · \(model.lane.name) · \(model.game.score) points · \(model.medal)"
                        )
                    } else {
                        shareFailed = true
                    }
                }
                HStack(spacing: 12) {
                    secondary("Dream again", id: "replay") {
                        model.start(lane: model.selectedLane, practice: model.practice)
                    }
                    if !model.practice && model.medal != "NO MEDAL" && model.selectedLane < 7 {
                        secondary("Next room →", id: "next-room") { model.start(lane: model.selectedLane + 1) }
                    } else {
                        secondary("All rooms", id: "result-rooms") { showRooms = true }
                    }
                }
            }.padding(25)
        }.background(Dream.ink)
    }

    private var tutorial: some View {
        overlayPanel {
            VStack(alignment: .leading, spacing: 22) {
                eyebrow("A NOTE FROM THE CONCIERGE")
                DecoEmblem().frame(width: 44, height: 44)
                Text("Stay a little.\nRoll a dream.").font(Dream.display(37))
                tutorialRow(
                    "hand.draw", title: "Draw your line",
                    text: "Drag upward on the lane. Move left or right to aim; drag longer for power.")
                tutorialRow(
                    "arrow.turn.up.right", title: "Give it a curve",
                    text: "Set the curve before each roll. The dotted line shows your opening path.")
                tutorialRow(
                    "sparkle", title: "Three frames, ten pins",
                    text:
                        "Two rolls per frame. Strikes add your next two rolls; spares add the next. Earn bronze to open a room."
                )
                primary("I'm ready to dream", symbol: "arrow.up.right", id: "tutorial-done") { model.dismissTutorial() }
            }
        }
    }

    private var pause: some View {
        overlayPanel {
            VStack(alignment: .leading, spacing: 20) {
                eyebrow("DO NOT DISTURB")
                DecoEmblem().frame(width: 44, height: 44)
                Text("Dream on hold.").font(Dream.display(36))
                Text(model.lane.advice).font(.system(size: 15)).foregroundStyle(Dream.lavender)
                primary("Resume", symbol: "play", id: "resume") { model.paused = false }
                secondary("Restart three frames", id: "restart") {
                    model.start(lane: model.selectedLane, practice: model.practice)
                }
                secondary("Return to the lobby", id: "exit") {
                    model.screen = "home"
                    model.paused = false
                }
            }
        }
    }

    private var rooms: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("The room\ndirectory.").font(Dream.display(39)).padding(
                        .bottom, 12)
                    Text("Earn a bronze medal to unlock the next corridor.")
                        .font(.system(size: 12)).foregroundStyle(Dream.lavender).padding(.bottom, 28)
                    ForEach(Lane.all) { lane in
                        Button {
                            showRooms = false
                            model.start(lane: lane.id)
                        } label: {
                            HStack(spacing: 18) {
                                RoomKey(number: lane.id + 1).frame(width: 42, height: 55)
                                    .opacity(lane.id <= model.unlocked ? 1 : 0.35)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(lane.name).font(Dream.display(22))
                                    Text(lane.subtitle).font(.system(size: 11)).foregroundStyle(Dream.muted)
                                    if model.best[lane.id] > 0 {
                                        Text("\(lane.medal(score: model.best[lane.id])) · BEST \(model.best[lane.id])")
                                            .font(.system(size: 8, weight: .medium)).tracking(1).foregroundStyle(
                                                Dream.mint)
                                    }
                                }
                                Spacer()
                                Image(systemName: lane.id <= model.unlocked ? "arrow.up.right" : "lock")
                                    .font(.system(size: 14)).foregroundStyle(Dream.lavender)
                            }.padding(.vertical, 20).contentShape(Rectangle())
                        }
                        .disabled(lane.id > model.unlocked)
                        .accessibilityLabel(
                            "\(lane.name), \(lane.id <= model.unlocked ? "available" : "locked"), best \(model.best[lane.id])"
                        )
                        .accessibilityIdentifier("lane-\(lane.id)")
                        Rectangle().fill(Dream.lavender.opacity(0.17)).frame(height: 1)
                    }
                }.padding(25)
            }
            .background(Dream.ink)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showRooms = false }.accessibilityIdentifier("rooms-done")
                }
            }
        }.tint(Dream.mint).preferredColorScheme(.dark)
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("THE ATMOSPHERE") {
                    Toggle("Sound", isOn: $model.sound).accessibilityIdentifier("sound")
                    Toggle("Haptics", isOn: $model.haptics).accessibilityIdentifier("haptics")
                }
                Section("HOW TO PLAY") {
                    Text(
                        "Three frames use standard ten-pin scoring, including bonus rolls in the last frame. A perfect game is 90."
                    )
                    Text("Strike: 10 + next two rolls. Spare: 10 + next roll. Open frame: pins knocked down.")
                    Text(
                        "Aim by dragging upward. Set one curve per roll with the slider. The arrow button bowls with your current aim and power."
                    )
                    Button("Show the welcome lesson") {
                        showSettings = false
                        model.tutorial = true
                        model.start(lane: 0, practice: true)
                    }.accessibilityIdentifier("show-tutorial")
                }
                Section("YOUR STAY") {
                    Text("Progress stays on this device. No accounts, ads or online leaderboards.")
                    Text("Lucid Lanes · 1.0").foregroundStyle(Dream.muted)
                }
            }
            .navigationTitle("Room service")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSettings = false }.accessibilityIdentifier("settings-done")
                }
            }
        }.tint(Dream.mint).preferredColorScheme(.dark)
    }

    private func overlayPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Dream.ink.opacity(0.9).ignoresSafeArea()
            ScrollView {
                content().padding(28)
                    .background(
                        LinearGradient(
                            colors: [Dream.velvet, Dream.ink], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 3)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Dream.peach.opacity(0.4), lineWidth: 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 1).inset(by: 6).stroke(Dream.peach.opacity(0.12), lineWidth: 0.5)
                    )
                    .padding(22)
            }.defaultScrollAnchor(.center)
        }
    }

    private func tutorialRow(_ symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).foregroundStyle(Dream.peach).font(.system(size: 22)).frame(width: 27)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 16, weight: .medium))
                Text(text).font(.system(size: 12)).lineSpacing(3).foregroundStyle(Dream.lavender)
            }
        }
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text).font(Dream.label(8)).tracking(1.6).foregroundStyle(Dream.muted)
    }

    private func primary(_ title: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(Dream.label(15))
                Spacer()
                Image(systemName: symbol).font(.system(size: 17))
                    .frame(width: 32, height: 32).overlay(Circle().stroke(Dream.ink.opacity(0.22), lineWidth: 0.5))
            }.padding(.horizontal, 19).frame(minHeight: 58)
                .background(
                    LinearGradient(
                        colors: [Dream.cream, Dream.peach], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 3)
                )
                .overlay(RoundedRectangle(cornerRadius: 1).inset(by: 5).stroke(Dream.ink.opacity(0.18), lineWidth: 0.5))
                .foregroundStyle(Dream.ink)
        }.buttonStyle(PressStyle()).accessibilityIdentifier(id)
    }

    private func secondary(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(Dream.label(12))
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right").font(.system(size: 10))
            }.frame(maxWidth: .infinity, minHeight: 44)
                .overlay(alignment: .bottom) { Rectangle().fill(Dream.lavender.opacity(0.25)).frame(height: 0.5) }
                .contentShape(Rectangle())
        }.buttonStyle(PressStyle()).accessibilityIdentifier(id)
    }

    private func iconButton(_ symbol: String, label: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15)).frame(width: 44, height: 44)
                .contentShape(Circle())
                .overlay(Circle().stroke(Dream.lavender.opacity(0.2), lineWidth: 0.5))
        }
        .accessibilityLabel(label).accessibilityIdentifier(id)
    }
}

struct ResultCard: View {
    let lane: Lane
    let score: Int
    let medal: String
    let frames: BowlingGame

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("LUCID LANES").font(Dream.label(10)).tracking(2)
                Spacer()
                Text("SCORE RECEIPT").font(Dream.label(7)).tracking(1)
            }.padding(.horizontal, 24).padding(.top, 24)
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    for i in 0..<64 {
                        let angle = Double(i) / 64 * .pi * 2
                        let inner = 91.0
                        let outer = i % 4 == 0 ? 112.0 : 105.0
                        var ray = Path()
                        ray.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                        ray.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                        context.stroke(ray, with: .color(Dream.ink.opacity(i % 4 == 0 ? 0.6 : 0.2)), lineWidth: 0.7)
                    }
                }
                Circle().stroke(Dream.ink.opacity(0.25), lineWidth: 0.5).frame(width: 173, height: 173)
                VStack(spacing: -3) {
                    Text(medal == "NO MEDAL" ? "KEEP DREAMING" : "\(medal) MEDAL").font(Dream.label(8)).tracking(1.6)
                    Text("\(score)").font(Dream.display(88)).tracking(-5)
                    Text("POINTS / 90").font(Dream.label(8)).tracking(2)
                }
            }.frame(height: 242)
            VStack(spacing: 7) {
                Text(lane.name).font(Dream.display(30))
                Text("ROOM \(String(format: "%02d", lane.id + 1))  ·  \(lane.subtitle.uppercased())")
                    .font(Dream.label(8)).tracking(0.6).opacity(0.7).multilineTextAlignment(.center)
            }.padding(.horizontal, 20).padding(.bottom, 22)
            Rectangle().fill(Dream.ink.opacity(0.25)).frame(height: 0.5).padding(.horizontal, 24)
            HStack {
                ForEach(0..<3) { i in
                    VStack(spacing: 6) {
                        Text("FRAME 0\(i + 1)").font(Dream.label(7)).tracking(1).opacity(0.6)
                        Text(frames.symbols(for: i)).font(.system(size: 18, weight: .medium, design: .monospaced))
                    }.frame(maxWidth: .infinity)
                }
            }.padding(.vertical, 18).padding(.horizontal, 12)
            if medal == "NO MEDAL" {
                Text("\(lane.bronze) points earns bronze. Stay for another round.")
                    .font(.system(size: 10)).padding(.bottom, 15)
            }
            HStack {
                Text("THE DREAM HOTEL").font(Dream.label(8)).tracking(1.7)
                Spacer()
                DecoEmblem().frame(width: 26, height: 26)
            }.foregroundStyle(Dream.cream).padding(.horizontal, 24).padding(.vertical, 13).background(Dream.velvet)
        }
        .foregroundStyle(Dream.ink)
        .background(Dream.cream)
        .clipShape(TicketShape())
        .overlay(TicketShape().stroke(Dream.peach.opacity(0.4), lineWidth: 0.5))
    }
}

struct DecoEmblem: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    for i in 0..<12 {
                        let angle = Double(i) / 12 * .pi * 2
                        var ray = Path()
                        ray.move(
                            to: CGPoint(
                                x: center.x + cos(angle) * size.width * 0.28,
                                y: center.y + sin(angle) * size.height * 0.28))
                        ray.addLine(
                            to: CGPoint(
                                x: center.x + cos(angle) * size.width * 0.49,
                                y: center.y + sin(angle) * size.height * 0.49))
                        context.stroke(ray, with: .color(Dream.peach), lineWidth: 0.7)
                    }
                }
                Text("L").font(Dream.display(geometry.size.width * 0.45)).foregroundStyle(Dream.peach)
            }
        }.accessibilityHidden(true)
    }
}

struct RoomKey: View {
    let number: Int
    var body: some View {
        VStack(spacing: 3) {
            Circle().stroke(Dream.peach.opacity(0.7), lineWidth: 1).frame(width: 4, height: 4)
            Text(String(format: "%02d", number)).font(Dream.display(23))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Dream.peach)
        .background(
            Dream.peach.opacity(0.06),
            in: UnevenRoundedRectangle(
                topLeadingRadius: 18, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 18)
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 18, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 18
            ).stroke(Dream.peach.opacity(0.5), lineWidth: 0.6)
        )
        .accessibilityLabel("Room \(number)")
    }
}

struct TicketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.maxY - 53
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: y - 6))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: y + 6), control1: CGPoint(x: rect.maxX - 8, y: y - 6),
            control2: CGPoint(x: rect.maxX - 8, y: y + 6))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: y + 6))
        path.addCurve(to: CGPoint(x: 0, y: y - 6), control1: CGPoint(x: 8, y: y + 6), control2: CGPoint(x: 8, y: y - 6))
        path.closeSubpath()
        return path
    }
}

struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let text: String
}

final class ShareImage: NSObject, UIActivityItemSource {
    let payload: SharePayload

    init(payload: SharePayload) {
        self.payload = payload
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        payload.image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        payload.image
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = payload.text
        metadata.imageProvider = NSItemProvider(object: payload.image)
        metadata.iconProvider = NSItemProvider(object: payload.image)
        return metadata
    }
}

struct NativeShare: UIViewControllerRepresentable {
    let payload: SharePayload
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [ShareImage(payload: payload), payload.text], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
