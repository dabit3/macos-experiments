import SwiftUI

struct ContentView: View {
    @StateObject private var game = GameStore()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var share: SharePayload?
    @State private var confirmQuit = false
    private let clock = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x193D2F), GardenPalette.night, Color(hex: 0x102B23)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()
            switch game.screen {
            case .home: home
            case .playing: playing
            case .holeResult: holeResult
            case .courseResult: courseResult
            }
            if game.paused { pauseOverlay }
            if game.showTutorial { tutorialOverlay }
        }
        .foregroundStyle(GardenPalette.cream)
        .preferredColorScheme(.dark)
        .tint(GardenPalette.cream)
        .onReceive(clock) { _ in game.tick() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && game.screen == .playing {
                game.aim = .zero
                game.paused = true
            }
        }
        .sheet(isPresented: $game.showSettings) { settings }
        .sheet(isPresented: $game.showPractice) { practicePicker }
        .sheet(item: $share) { payload in ShareSheet(payload: payload) }
        .alert("Leave this garden?", isPresented: $confirmQuit) {
            Button("Keep playing", role: .cancel) {}
            Button("Leave course", role: .destructive) { game.goHome() }
        } message: {
            Text("This round will end. Your saved best score stays.")
        }
    }

    private var home: some View {
        VStack(spacing: 0) {
            HStack {
                eyebrow("A POCKET GARDEN")
                Spacer()
                iconButton("slider.horizontal.3", label: "Settings", id: "home.settings") {
                    game.showSettings = true
                }
            }
            .padding(.horizontal, 27)
            .padding(.top, 4)
            VStack(spacing: 5) {
                Text("Mossball")
                    .font(.system(size: 62, weight: .regular, design: .serif))
                    .tracking(-3)
                    .minimumScaleFactor(0.65)
                Text("A little golf. A little wild.")
                    .font(.system(size: 15))
                    .foregroundStyle(GardenPalette.muted)
            }
            .padding(.top, 10)
            GardenCanvas(
                simulation: GolfSimulation(hole: Hole.course[8]),
                reducedMotion: reduceMotion, decorative: true
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            VStack(spacing: 15) {
                HStack(spacing: 12) {
                    Rectangle().fill(GardenPalette.muted.opacity(0.22)).frame(height: 1)
                    eyebrow("THE OVERGROWN NINE").fixedSize()
                    Rectangle().fill(GardenPalette.muted.opacity(0.22)).frame(height: 1)
                }
                primaryButton("Enter the garden", icon: "arrow.up.right", id: "home.start") {
                    game.start()
                }
                Button {
                    game.showPractice = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "leaf")
                        Text("Wander & practice")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("home.practice")
                HStack {
                    Text("9 HOLES  /  PAR \(Hole.totalPar)")
                    Spacer()
                    Text(game.best.map { "BEST  \($0)" } ?? "TAKE YOUR TIME")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(GardenPalette.muted)
            }
            .padding(.horizontal, 29)
            .padding(.bottom, 16)
        }
    }

    private var playing: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 7) {
                    eyebrow(
                        game.practice
                            ? "PRACTICE  /  \(String(format: "%02d", game.hole.number))"
                            : "HOLE \(String(format: "%02d", game.hole.number))  /  09")
                    Text(game.hole.name)
                        .font(.system(size: 28, weight: .regular, design: .serif))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                Spacer()
                VStack(spacing: 3) {
                    Text("\(game.simulation.strokes)")
                        .font(.system(size: 33, weight: .light, design: .serif))
                        .contentTransition(.numericText())
                    Text("STROKES").font(.system(size: 8, weight: .semibold)).tracking(1.3)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(game.simulation.strokes) \(game.strokeNoun)")
                .accessibilityIdentifier("game.strokes")
                iconButton("pause", label: "Pause game", id: "game.pause") { game.paused = true }
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 25)
            .padding(.top, 12)
            HStack {
                Text("PAR \(game.hole.par)")
                Spacer()
                Text(game.practice ? "NO STROKE LIMIT" : "ROUND  \(game.total + game.simulation.strokes)")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(GardenPalette.muted)
            .padding(.horizontal, 28)
            .padding(.top, 16)
            GardenCanvas(
                simulation: game.simulation,
                aim: game.aim.length > 0 ? game.aim : game.practice && game.canShoot ? game.practicePull : .zero,
                bloom: game.bloom, reducedMotion: reduceMotion,
                onDrag: { pull in if game.canShoot { game.aim = pull } },
                onRelease: { pull in game.shoot(pull) }
            )
            .padding(.vertical, 6)
            VStack(spacing: 10) {
                if game.practice {
                    practiceControls
                } else {
                    HStack(spacing: 5) {
                        ForEach(0..<9, id: \.self) { index in
                            Capsule()
                                .fill(index <= game.holeIndex ? GardenPalette.gold : GardenPalette.muted.opacity(0.19))
                                .frame(height: 3)
                        }
                    }
                    .padding(.horizontal, 70)
                    .padding(.bottom, 6)
                    Text(game.message.isEmpty ? playHint : game.message)
                        .font(.system(size: 13, weight: game.message.isEmpty ? .regular : .semibold))
                        .foregroundStyle(game.message.isEmpty ? GardenPalette.cream : GardenPalette.gold)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 35)
                        .padding(.horizontal, 6)
                        .background(
                            game.message.isEmpty ? .clear : GardenPalette.gold.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .accessibilityIdentifier("game.hint")
                    if game.aim.length > 0 {
                        powerMeter
                    } else {
                        Text(game.hole.subtitle)
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(GardenPalette.muted)
                    }
                    Button("How to play") { game.showTutorial = true }
                        .font(.system(size: 11))
                        .foregroundStyle(GardenPalette.muted)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("game.help")
                }
            }
            .padding(.horizontal, 27)
            .padding(.bottom, 7)
        }
    }

    private var playHint: String {
        if game.simulation.sunk { return "Watch the garden bloom." }
        if game.simulation.moving { return "Let it roll." }
        if game.aim.length > 0 {
            return game.hole.water.isEmpty
                ? "Follow the dots. Release to putt." : "× means water ahead. Time your release."
        }
        if game.hole.lily { return "Cross on the moving lily. Water costs +1." }
        if game.hole.gate { return "Time your shot through the moving gate." }
        if !game.hole.mushrooms.isEmpty { return "Mushrooms bounce. Use the dotted preview." }
        if !game.hole.water.isEmpty { return "Keep out of the pond. Water costs +1." }
        return "Drag back anywhere. Release to putt."
    }

    private var powerMeter: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                Capsule()
                    .fill(
                        Double(index) < min(game.aim.length, 135) / 135 * 20
                            ? GardenPalette.gold : GardenPalette.muted.opacity(0.2)
                    )
                    .frame(width: 4, height: 8)
            }
            Text("\(Int(min(game.aim.length, 135) / 135 * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .frame(width: 33)
        }
    }

    private var practiceControls: some View {
        VStack(spacing: 5) {
            Text(game.message.isEmpty ? practiceHint : game.message)
                .font(.system(size: 12, weight: game.message.isEmpty ? .regular : .semibold))
                .foregroundStyle(game.message.isEmpty ? GardenPalette.cream : GardenPalette.gold)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 34)
                .padding(.horizontal, 6)
                .background(
                    game.message.isEmpty ? .clear : GardenPalette.gold.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 12) {
                iconButton("rotate.left", label: "Aim 5 degrees left", id: "practice.aimLeft") {
                    game.practiceAngle -= 5
                }
                VStack(spacing: 0) {
                    Text(
                        "POWER  \(Int(min(game.aim.length > 0 ? game.aim.length : game.practicePower, 135) / 135 * 100))%"
                    )
                    .font(.system(size: 9, design: .monospaced)).tracking(1)
                    Slider(value: $game.practicePower, in: 5...135)
                        .tint(GardenPalette.gold)
                        .accessibilityLabel("Shot power")
                        .accessibilityIdentifier("practice.power")
                }
                iconButton("rotate.right", label: "Aim 5 degrees right", id: "practice.aimRight") {
                    game.practiceAngle += 5
                }
                Button("Putt") { game.shoot(game.practicePull) }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GardenPalette.ink)
                    .frame(width: 65, height: 45)
                    .background(GardenPalette.cream, in: Capsule())
                    .disabled(!game.canShoot)
                    .opacity(game.canShoot ? 1 : 0.4)
                    .accessibilityIdentifier("practice.putt")
            }
            .disabled(!game.canShoot)
            Text("Or drag to aim · \(game.gentle ? "generous" : "standard") cup")
                .font(.system(size: 10))
                .foregroundStyle(GardenPalette.muted)
        }
    }

    private var practiceHint: String {
        guard game.canShoot else { return playHint }
        if game.hole.lily {
            return "Time the lily crossing. × means water ahead."
        }
        if game.hole.gate {
            return "Wait for the gate. A gold ring predicts a sink."
        }
        if !game.hole.mushrooms.isEmpty {
            return "Bank off a mushroom. Follow the dotted path."
        }
        if !game.hole.water.isEmpty {
            return "Avoid the pond. × means water ahead."
        }
        return "Aim with the buttons, set power, then Putt."
    }

    private var holeResult: some View {
        VStack(spacing: 0) {
            eyebrow("HOLE \(String(format: "%02d", game.hole.number))  /  \(game.hole.name.uppercased())")
                .padding(.top, 24)
            Text(game.resultTitle)
                .font(.system(size: 35, weight: .regular, design: .serif))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(.top, 14)
                .padding(.horizontal, 23)
            Text(game.resultLabel)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2.5)
                .foregroundStyle(GardenPalette.gold)
                .padding(.top, 15)
            GardenCanvas(
                simulation: game.simulation, bloom: game.simulation.sunk ? 1 : 0,
                reducedMotion: reduceMotion, decorative: true
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            VStack(spacing: 13) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(game.simulation.strokes)").font(.system(size: 56, weight: .light, design: .serif))
                    Text(game.strokeNoun).font(.system(size: 16, design: .serif)).foregroundStyle(GardenPalette.muted)
                    Text(" /  par \(game.hole.par)").font(.system(size: 16, design: .serif)).foregroundStyle(
                        GardenPalette.muted)
                }
                if !game.simulation.sunk {
                    Text("Eight strokes, one overgrown path. The next hole awaits.")
                        .font(.system(size: 12)).foregroundStyle(GardenPalette.muted)
                        .multilineTextAlignment(.center)
                }
                primaryButton(
                    game.practice ? "Play this hole again" : game.holeIndex == 8 ? "See your scorecard" : "Next garden",
                    icon: "arrow.right", id: "result.next"
                ) { game.nextHole() }
                HStack {
                    Button {
                        share = ScorecardRenderer.hole(game: game)
                    } label: {
                        Label("Share moment", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("result.share")
                    Spacer()
                    Button(game.practice ? "Choose hole" : "Home") {
                        if game.practice {
                            game.showPractice = true
                        } else {
                            confirmQuit = true
                        }
                    }
                    .accessibilityIdentifier("result.home")
                }
                .font(.system(size: 13))
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
        }
        .accessibilityIdentifier("result.hole")
    }

    private var courseResult: some View {
        ScrollView {
            VStack(spacing: 18) {
                eyebrow("THE OVERGROWN NINE · COMPLETE").padding(.top, 25)
                Text("Well wandered.")
                    .font(.system(size: 43, weight: .regular, design: .serif))
                Text(
                    game.record.finished
                        ? "Nine gardens. One lovely little journey." : "Some paths stayed wild. Come grow again."
                )
                .font(.system(size: 13)).foregroundStyle(GardenPalette.muted)
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text("\(game.total)").font(.system(size: 77, weight: .light, design: .serif))
                    Text("strokes").font(.system(size: 19, design: .serif))
                }
                Text(game.record.caption.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2).foregroundStyle(GardenPalette.gold)
                scoreRows
                primaryButton("Share your scorecard", icon: "square.and.arrow.up", id: "course.share") {
                    share = ScorecardRenderer.course(record: game.record)
                }
                Button("Another wander") { game.start() }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .accessibilityIdentifier("course.replay")
                Button("Back to the garden") { game.goHome() }
                    .font(.system(size: 13)).foregroundStyle(GardenPalette.muted)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("course.home")
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
        }
        .accessibilityIdentifier("result.course")
    }

    private var scoreRows: some View {
        VStack(spacing: 0) {
            HStack {
                Text("GARDEN")
                Spacer()
                Text("PAR").frame(width: 38)
                Text("YOU").frame(width: 38)
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(1.5).foregroundStyle(GardenPalette.muted)
            .padding(.bottom, 9)
            ForEach(Array(Hole.course.enumerated()), id: \.offset) { index, hole in
                HStack {
                    Text(String(format: "%02d", hole.number))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(GardenPalette.muted)
                        .frame(width: 22, alignment: .leading)
                    Text(hole.name).font(.system(size: 14, design: .serif))
                    Spacer()
                    Text("\(hole.par)").foregroundStyle(GardenPalette.muted).frame(width: 38)
                    Text(index < game.scores.count ? "\(game.scores[index])\(game.completed[index] ? "" : "×")" : "—")
                        .foregroundStyle(GardenPalette.gold).frame(width: 38)
                }
                .font(.system(size: 13, design: .monospaced))
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) { Divider().overlay(GardenPalette.muted.opacity(0.12)) }
            }
            if !game.record.finished {
                Text("× Stroke limit reached. Finish all cups to set a best.")
                    .font(.system(size: 10)).foregroundStyle(GardenPalette.muted)
                    .padding(.top, 12)
            }
        }
        .padding(.vertical, 12)
    }

    private var pauseOverlay: some View {
        overlay {
            eyebrow("A MOMENT OF STILLNESS")
            Text("Take a breath.").font(.system(size: 38, design: .serif))
            Text("The garden can wait.").foregroundStyle(GardenPalette.muted)
                .padding(.bottom, 16)
            primaryButton("Keep playing", icon: "play", id: "pause.resume") { game.paused = false }
            Button("Restart this hole") { game.loadHole() }
                .frame(minHeight: 44).accessibilityIdentifier("pause.restart")
            Button("Settings") { game.showSettings = true }
                .frame(minHeight: 44).accessibilityIdentifier("pause.settings")
            Button("Leave course") { confirmQuit = true }
                .foregroundStyle(GardenPalette.muted)
                .frame(minHeight: 44).accessibilityIdentifier("pause.quit")
        }
    }

    private var tutorialOverlay: some View {
        overlay {
            eyebrow("YOUR FIRST LITTLE PUTT")
            Text("Pull back.\nLet it wander.")
                .font(.system(size: 39, weight: .regular, design: .serif))
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
            tutorialDiagram
            Text("Drag back anywhere in the garden to aim.\nPull farther for more power. Release to putt.")
                .font(.system(size: 15)).multilineTextAlignment(.center).lineSpacing(5)
            Text(
                "The dots predict your path. Stone and mushrooms bounce; water adds one stroke. After 8 strokes, the next garden opens."
            )
            .font(.system(size: 13)).foregroundStyle(GardenPalette.muted)
            .multilineTextAlignment(.center).lineSpacing(4)
            .padding(.vertical, 10)
            primaryButton("Let's play", icon: "arrow.right", id: "tutorial.dismiss") {
                game.dismissTutorial()
            }
            Text("Prefer buttons? Try Wander & practice from home.")
                .font(.system(size: 11)).foregroundStyle(GardenPalette.muted)
                .multilineTextAlignment(.center)
        }
    }

    private var tutorialDiagram: some View {
        HStack(spacing: 20) {
            VStack(spacing: 5) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(GardenPalette.gold)
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(GardenPalette.cream.opacity(0.55)).frame(width: 3, height: 3)
                }
                Circle().fill(GardenPalette.cream).frame(width: 15, height: 15)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 3)
                Image(systemName: "arrow.down")
                    .font(.system(size: 26, weight: .ultraLight))
                    .foregroundStyle(GardenPalette.gold)
                Image(systemName: "hand.draw")
                    .font(.system(size: 23, weight: .light))
            }
            VStack(alignment: .leading, spacing: 49) {
                Text("BALL GOES UP")
                Text("YOU PULL DOWN")
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(GardenPalette.muted)
        }
        .padding(.vertical, 10)
        .accessibilityLabel("To shoot toward the cup above the ball, drag your finger downward.")
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("Garden comforts") {
                    Toggle("Sound effects", isOn: $game.sound).accessibilityIdentifier("settings.sound")
                    Toggle("Haptic feedback", isOn: $game.haptics).accessibilityIdentifier("settings.haptics")
                    Toggle("Generous cups in practice", isOn: $game.gentle)
                        .accessibilityIdentifier("settings.gentle")
                        .onChange(of: game.gentle) { _, value in
                            if game.practice { game.simulation.gentle = value }
                        }
                }
                Section {
                    Text(
                        "Practice has no stroke limit and offers aim buttons and a power slider. Course rounds always use standard cups."
                    )
                    Text(
                        "Water returns your ball to its previous lie and adds one penalty stroke. Finish all nine cups to record a best."
                    )
                    Text(
                        "Reduced Motion follows your device setting. Moving gates and lilies remain active because they are part of the course."
                    )
                }
                .font(.system(size: 13))
                Section("On this device") {
                    LabeledContent("Best complete course", value: game.best.map { "\($0) strokes" } ?? "Still growing")
                    LabeledContent("Rounds played", value: "\(game.rounds)")
                }
            }
            .tint(GardenPalette.gold)
            .navigationTitle("Little comforts")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { game.showSettings = false }.accessibilityIdentifier("settings.done")
                }
            }
        }
    }

    private var practicePicker: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Wander freely.")
                        .font(.system(size: 37, design: .serif))
                        .padding(.top, 15)
                    Text("Nine places to slow down. No stroke limit.\nDrag to putt, or use the aim buttons.")
                        .font(.system(size: 14)).foregroundStyle(GardenPalette.muted)
                        .lineSpacing(4).padding(.top, 10).padding(.bottom, 25)
                    ForEach(Array(Hole.course.enumerated()), id: \.offset) { index, hole in
                        Button {
                            game.start(practice: index)
                        } label: {
                            HStack(spacing: 17) {
                                Text(String(format: "%02d", hole.number))
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundStyle(GardenPalette.gold)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(hole.name).font(.system(size: 22, design: .serif))
                                    Text(hole.subtitle).font(.system(size: 11)).foregroundStyle(GardenPalette.muted)
                                }
                                Spacer()
                                Text("PAR \(hole.par)").font(.system(size: 9, design: .monospaced))
                            }
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(GardenPalette.cream)
                        .accessibilityLabel("Practice hole \(hole.number), \(hole.name), par \(hole.par)")
                        .accessibilityIdentifier("practice.hole.\(hole.number)")
                        Divider().overlay(GardenPalette.muted.opacity(0.2))
                    }
                }
                .padding(.horizontal, 25)
            }
            .background(GardenPalette.night)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { game.showPractice = false }.accessibilityIdentifier("practice.done")
                }
            }
        }
    }

    private func overlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            GardenPalette.night.opacity(0.96).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14, content: content)
                    .padding(.horizontal, 31).padding(.vertical, 45)
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.center)
        }
        .accessibilityAddTraits(.isModal)
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(2.2)
            .foregroundStyle(GardenPalette.muted)
    }

    private func iconButton(_ symbol: String, label: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .regular))
                .frame(width: 44, height: 44)
                .background(GardenPalette.cream.opacity(0.05), in: Circle())
                .overlay(Circle().strokeBorder(GardenPalette.cream.opacity(0.12), lineWidth: 1))
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private func primaryButton(_ title: String, icon: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: icon).font(.system(size: 16))
            }
            .foregroundStyle(GardenPalette.ink)
            .padding(.horizontal, 23)
            .frame(maxWidth: .infinity, minHeight: 57)
            .background(GardenPalette.cream, in: RoundedRectangle(cornerRadius: 18))
        }
        .accessibilityIdentifier(id)
    }
}
