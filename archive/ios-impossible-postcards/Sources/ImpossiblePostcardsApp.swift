import SwiftUI

@main
struct ImpossiblePostcardsApp: App {
    var body: some Scene {
        WindowGroup { PostcardsView() }
    }
}

struct PostcardsView: View {
    @StateObject private var game = GameModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var palette: PostcardPalette {
        .chapter(game.journal.chapter)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                SkyBackdrop(palette: palette, reduceMotion: reduceMotion)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.9), value: game.journal.chapter)
                Group {
                    switch game.page {
                    case .cover: cover(height: geometry.size.height)
                    case .collection: collection(height: geometry.size.height)
                    case .game: play(height: geometry.size.height)
                    case .result: result(height: geometry.size.height)
                    }
                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .offset(y: 10)))
                if game.paused {
                    pauseOverlay
                }
                if game.showingHint {
                    hintOverlay
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: game.page)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: game.paused)
            .foregroundStyle(PostcardPalette.ink)
        }
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                game.setPaused(true)
            }
        }
    }

    // MARK: Cover

    private func cover(height: Double) -> some View {
        let compact = height < 720
        return VStack(spacing: 0) {
            HStack {
                Eyebrow(text: "A POCKET-SIZED ESCAPE")
                Spacer()
                soundButton
            }
            .padding(.top, 6)
            .padding(.horizontal, 26)
            VStack(spacing: 10) {
                Ornament(color: palette.deep, width: 96)
                Text("Impossible\nPostcards")
                    .font(Typeface.display(compact ? 44 : 52))
                    .lineSpacing(-4)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Small worlds, turned until they make sense.")
                    .font(Typeface.italic(15))
                    .foregroundStyle(PostcardPalette.ink.opacity(0.7))
            }
            .padding(.top, compact ? 4 : 16)
            PostcardCard(palette: .chapter(0), tilt: -2.4) {
                PostcardWorld(chapter: Chapters.all[0], state: Chapters.all[0].initialState, drifting: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 22)
                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("N° 01").font(Typeface.display(19))
                            Eyebrow(text: "THE QUIET CROSSING", color: PostcardPalette.ink.opacity(0.6))
                        }
                        Spacer()
                        Stamp(numeral: "I", palette: .chapter(0), width: 42)
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        CancelLines(palette: .chapter(0)).frame(width: 80)
                        Spacer()
                        Text("35° N · 18° E")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(PostcardPalette.ink.opacity(0.55))
                    }
                }
                .padding(20)
                .allowsHitTesting(false)
            }
            .padding(.horizontal, 30)
            .padding(.top, compact ? 14 : 24)
            .padding(.bottom, compact ? 12 : 22)
            .frame(maxHeight: .infinity)
            .accessibilityHidden(true)
            HStack(spacing: 14) {
                instruction("hand.tap", title: "Tap to walk")
                instruction("arrow.trianglehead.2.clockwise.rotate.90", title: "Turn to connect")
                instruction("sun.max", title: "Wake the seals")
            }
            .padding(.bottom, compact ? 16 : 24)
            Button { game.start(game.journal.chapter, fresh: !game.canContinue) } label: {
                primaryLabel(game.canContinue ? "Continue the journey" : "Begin the journey")
            }
            .buttonStyle(PrimaryButtonStyle(palette: palette))
            .padding(.horizontal, 30)
            Button { game.showCollection() } label: {
                HStack(spacing: 10) {
                    Text("The collection")
                    progressDots
                }
            }
            .buttonStyle(TextLinkStyle())
            .padding(.top, 4)
            .padding(.bottom, 4)
        }
    }

    private var progressDots: some View {
        HStack(spacing: 5) {
            ForEach(Chapters.all) { chapter in
                Circle()
                    .fill(game.journal.best[chapter.id] == nil ? PostcardPalette.ink.opacity(0.18) : PostcardPalette
                        .goldDeep)
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityLabel("\(game.collected) of 4 postcards collected")
    }

    // MARK: Play

    private func play(height: Double) -> some View {
        let compact = height < 720
        return VStack(spacing: 0) {
            HStack {
                GlassButton(symbol: "square.grid.2x2", label: "Open collection", palette: palette) {
                    game.showCollection()
                }
                Spacer()
                Eyebrow(text: "POSTCARD \(roman(game.chapter.id)) OF IV")
                Spacer()
                GlassButton(symbol: "pause", label: "Pause journey", palette: palette) { game.setPaused(true) }
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
            VStack(spacing: 5) {
                Text(game.chapter.title)
                    .font(Typeface.display(compact ? 30 : 34))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Text(game.chapter.subtitle)
                    .font(Typeface.italic(14))
                    .foregroundStyle(PostcardPalette.ink.opacity(0.68))
            }
            .padding(.top, compact ? 10 : 14)
            .padding(.horizontal, 20)
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    Postmark(value: "\(game.state.moves)", caption: "MOVES", palette: palette, diameter: 58)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(game.state.moves) moves")
                    CancelLines(palette: palette).frame(width: 46)
                }
                Spacer()
                SealRow(lit: game.state.switches, total: game.totalSeals, palette: palette)
            }
            .padding(.horizontal, 30)
            .padding(.top, compact ? 12 : 18)
            PostcardWorld(
                chapter: game.chapter, state: game.state, interactive: true, movingTo: game.movingTo,
                rejectedTile: game.rejectedTile, feedbackTick: game.feedbackTick,
                focusedMechanism: game.focusedMechanism,
                onTile: { game.walk(to: $0, reduceMotion: reduceMotion) }
            )
            .id(game.chapter.id)
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 6)
            VStack(spacing: compact ? 10 : 14) {
                Text(game.message)
                    .font(Typeface.italic(16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PostcardPalette.ink.opacity(0.82))
                    .frame(height: 40)
                    .padding(.horizontal, 30)
                    .contentTransition(.opacity)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: game.message)
                    .accessibilityIdentifier("journeyMessage")
                HStack(spacing: 18) {
                    ForEach(game.chapter.mechanisms.indices, id: \.self) { index in
                        TurnDial(
                            mechanism: game.chapter.mechanisms[index],
                            orientation: game.state.orientations[index],
                            numeral: game.chapter.mechanisms.count > 1 ? (index == 0 ? "I" : "II") : nil,
                            enabled: game.chapter.canRotate(index, state: game.state),
                            occupied: game.chapter.mechanisms[index].center == (game.movingTo ?? game.state.tile),
                            busy: game.walking || game.turning,
                            palette: palette,
                            reduceMotion: reduceMotion
                        ) {
                            game.rotate(index, reduceMotion: reduceMotion)
                        }
                        .id("\(game.chapter.id)-\(index)")
                    }
                }
                HStack {
                    Button { game.showingHint = true } label: {
                        Label("A little guidance", systemImage: "sparkle")
                    }
                    .buttonStyle(QuietButtonStyle(palette: palette))
                    Spacer()
                    HStack(spacing: 14) {
                        footerFigure("\(game.optimum)", label: "PERFECT")
                        if let best = game.journal.best[game.chapter.id] {
                            footerFigure("\(best)", label: "BEST")
                        }
                    }
                }
                .padding(.horizontal, 26)
            }
            .padding(.bottom, 6)
        }
    }

    // MARK: Collection

    private func collection(height: Double) -> some View {
        VStack(spacing: 0) {
            HStack {
                GlassButton(symbol: "arrow.left", label: "Back to title", palette: palette) { game.page = .cover }
                Spacer()
                soundButton
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
            VStack(spacing: 8) {
                Eyebrow(text: "PLACES THAT STAY WITH YOU")
                Text("The collection").font(Typeface.display(40))
                Text("\(game.collected) of 4 postcards collected")
                    .font(Typeface.italic(14))
                    .foregroundStyle(PostcardPalette.ink.opacity(0.68))
            }
            .padding(.top, 10)
            .padding(.bottom, 18)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible())], spacing: 30) {
                    ForEach(Chapters.all) { chapter in
                        collectionCard(chapter)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: max(0, height - 300))
            }
            Text("Every journey is kept on this device.")
                .font(Typeface.italic(12))
                .foregroundStyle(PostcardPalette.ink.opacity(0.55))
                .padding(.bottom, 14)
        }
    }

    private func collectionCard(_ chapter: Chapter) -> some View {
        let chapterPalette = PostcardPalette.chapter(chapter.id)
        let best = game.journal.best[chapter.id]
        return Button { game.start(chapter.id) } label: {
            VStack(spacing: 10) {
                PostcardCard(palette: chapterPalette, tilt: chapter.id % 2 == 0 ? -1.4 : 1.4) {
                    LinearGradient(
                        colors: [chapterPalette.skyTop.opacity(0.55), .clear],
                        startPoint: .top, endPoint: .center
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .padding(10)
                    PostcardWorld(chapter: chapter, state: chapter.initialState)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 22)
                    VStack {
                        HStack {
                            Spacer()
                            Stamp(
                                numeral: roman(chapter.id),
                                palette: chapterPalette,
                                collected: best != nil,
                                width: 30
                            )
                        }
                        Spacer()
                        HStack(alignment: .bottom) {
                            if best != nil {
                                Postmark(value: "✓", caption: "COLLECTED", palette: chapterPalette, diameter: 50)
                                    .rotationEffect(.degrees(-14))
                                    .offset(x: -6, y: 6)
                            }
                            Spacer()
                            CancelLines(palette: chapterPalette).frame(width: 40)
                        }
                    }
                    .padding(12)
                }
                .aspectRatio(1.1, contentMode: .fit)
                VStack(spacing: 3) {
                    Text(chapter.title)
                        .font(Typeface.display(16))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(best.map { "Best \($0) moves" } ?? chapter.subtitle)
                        .font(Typeface.italic(12))
                        .foregroundStyle(PostcardPalette.ink.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Postcard \(roman(chapter.id)), \(chapter.title)")
        .accessibilityValue(best.map { "Collected, best \($0) moves" } ?? "Not yet collected")
    }

    // MARK: Result

    private func result(height: Double) -> some View {
        let compact = height < 720
        let perfect = game.state.moves == game.optimum
        return VStack(spacing: 0) {
            VStack(spacing: 8) {
                Eyebrow(text: "A MOMENT, COLLECTED")
                Text(game.chapter.id == 3 ? "A little closer to home." : "Wish you were here.")
                    .font(Typeface.display(compact ? 30 : 34))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.top, 14)
            .padding(.horizontal, 18)
            PostcardCard(palette: palette, tilt: 1.6) {
                PostcardWorld(chapter: game.chapter, state: game.state, drifting: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 22)
                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("N° 0\(game.chapter.id + 1)").font(Typeface.display(18))
                            Eyebrow(text: game.chapter.title.uppercased(), color: PostcardPalette.ink.opacity(0.6))
                        }
                        Spacer()
                        Stamp(numeral: roman(game.chapter.id), palette: palette, collected: true, width: 40)
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        Postmark(value: perfect ? "★" : "✓", caption: "COLLECTED", palette: palette, diameter: 66)
                            .rotationEffect(.degrees(-12))
                            .offset(x: -4, y: 4)
                        Spacer()
                        Text(perfect ? "A PERFECT ROUTE" : "\(game.state.moves) MOVES")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(PostcardPalette.ink.opacity(0.55))
                    }
                }
                .padding(18)
            }
            .padding(.horizontal, 28)
            .padding(.top, compact ? 14 : 22)
            .padding(.bottom, compact ? 12 : 20)
            .frame(maxHeight: .infinity)
            .accessibilityHidden(true)
            Text(game.chapter.letter)
                .font(Typeface.italic(compact ? 18 : 20))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, compact ? 14 : 20)
            HStack(spacing: 0) {
                resultMetric("\(game.state.moves)", label: "YOUR MOVES")
                Rectangle().fill(palette.deep.opacity(0.25)).frame(width: 4, height: 4).rotationEffect(.degrees(45))
                resultMetric("\(game.optimum)", label: "PERFECT")
                Rectangle().fill(palette.deep.opacity(0.25)).frame(width: 4, height: 4).rotationEffect(.degrees(45))
                resultMetric("\(game.journal.best[game.chapter.id] ?? game.state.moves)", label: "LOCAL BEST")
            }
            .padding(.horizontal, 24)
            Text(perfect ? "A perfect little journey." : "Another perspective might take fewer moves.")
                .font(Typeface.italic(13))
                .foregroundStyle(perfect ? PostcardPalette.goldDeep : palette.deep)
                .padding(.top, 10)
                .padding(.bottom, compact ? 14 : 22)
            Button {
                if game.chapter.id < 3 {
                    game.start(game.chapter.id + 1)
                } else {
                    game.showCollection()
                }
            } label: {
                primaryLabel(game.chapter.id < 3 ? "The next postcard" : "Return to the collection")
            }
            .buttonStyle(PrimaryButtonStyle(palette: palette))
            .padding(.horizontal, 30)
            HStack(spacing: 30) {
                Button("Try a quieter route") { game.start(game.chapter.id) }
                Button("The collection") { game.showCollection() }
            }
            .buttonStyle(TextLinkStyle())
            .padding(.bottom, 2)
        }
    }

    // MARK: Overlays

    private var pauseOverlay: some View {
        overlayCard {
            Ornament(color: palette.deep, width: 90).padding(.bottom, 4)
            Text("A quiet moment").font(Typeface.display(32))
            Text("Your place is kept. Stay a while.")
                .font(Typeface.italic(15))
                .foregroundStyle(PostcardPalette.ink.opacity(0.68))
                .padding(.bottom, 18)
            Button { game.setPaused(false) } label: { primaryLabel("Continue walking") }
                .buttonStyle(PrimaryButtonStyle(palette: palette))
            Button { game.toggleSound() } label: {
                Label(
                    game.journal.sound ? "Sound is on" : "Sound is off",
                    systemImage: game.journal.sound ? "speaker.wave.2" : "speaker.slash"
                )
            }
            .buttonStyle(QuietButtonStyle(palette: palette))
            .padding(.top, 6)
            Button("Start this postcard again") { game.start(game.chapter.id) }
                .buttonStyle(TextLinkStyle())
            Button("Return to the collection") { game.showCollection() }
                .buttonStyle(TextLinkStyle())
        }
    }

    private var hintOverlay: some View {
        overlayCard {
            Ornament(color: palette.deep, width: 90).padding(.bottom, 4)
            Text("A different perspective").font(Typeface.display(28))
            VStack(alignment: .leading, spacing: 16) {
                guidance(
                    "hand.tap",
                    title: "Walk",
                    detail: "Tap a landing. Your traveler takes the connected path, one step at a time."
                )
                guidance(
                    "arrow.clockwise",
                    title: "Turn",
                    detail: "Turn the dials to rotate the coloured bridges. You may ride on their round centres."
                )
                guidance(
                    "sun.max",
                    title: "Awaken",
                    detail: "Step on every sun seal, then walk through the glowing arch."
                )
            }
            .padding(.vertical, 16)
            Text(game.chapter.hint)
                .font(Typeface.italic(17))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.bottom, 14)
            Text("Each landing crossed and each quarter-turn count as one move. There is no timer.")
                .font(Typeface.italic(12))
                .multilineTextAlignment(.center)
                .foregroundStyle(PostcardPalette.ink.opacity(0.6))
                .padding(.bottom, 14)
            Button { game.showingHint = false } label: { primaryLabel("I see a way") }
                .buttonStyle(PrimaryButtonStyle(palette: palette))
        }
    }

    private func overlayCard(@ViewBuilder content: () -> some View) -> some View {
        ZStack {
            PostcardPalette.ink.opacity(0.32).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 8, content: content)
                    .padding(26)
                    .frame(maxWidth: 360)
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(LinearGradient(
                            colors: [PostcardPalette.ivory, PostcardPalette.paper],
                            startPoint: .top, endPoint: .bottom
                        ))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(palette.deep.opacity(0.3), lineWidth: 0.8)
                        .padding(8))
                    .shadow(color: PostcardPalette.ink.opacity(0.3), radius: 30, y: 16)
                    .padding(22)
            }
            .defaultScrollAnchor(.center)
        }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: Pieces

    private var soundButton: some View {
        GlassButton(
            symbol: game.journal.sound ? "speaker.wave.2" : "speaker.slash",
            label: game.journal.sound ? "Mute sound" : "Enable sound",
            palette: palette
        ) {
            game.toggleSound()
        }
    }

    private func primaryLabel(_ text: String) -> some View {
        HStack {
            Text(text)
            Spacer()
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 30)
                .background(Circle().fill(.white.opacity(0.14)))
        }
    }

    private func instruction(_ symbol: String, title: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .light))
                .frame(width: 40, height: 40)
                .background(Circle().fill(PostcardPalette.paper.opacity(0.6)))
                .overlay(Circle().strokeBorder(palette.deep.opacity(0.28), lineWidth: 0.8))
            Text(title).font(Typeface.italic(13))
        }
        .frame(width: 104)
    }

    private func resultMetric(_ value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(Typeface.display(32))
            Eyebrow(text: label)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func guidance(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .light))
                .frame(width: 34, height: 34)
                .background(Circle().fill(palette.mist.opacity(0.6)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Typeface.displayBold(15))
                Text(detail)
                    .font(Typeface.display(13.5))
                    .lineSpacing(3)
                    .foregroundStyle(PostcardPalette.ink.opacity(0.72))
            }
        }
    }

    private func footerFigure(_ value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Eyebrow(text: label)
            Text(value).font(Typeface.display(19))
        }
        .accessibilityElement(children: .combine)
    }

    private func roman(_ index: Int) -> String {
        ["I", "II", "III", "IV"][index]
    }
}
