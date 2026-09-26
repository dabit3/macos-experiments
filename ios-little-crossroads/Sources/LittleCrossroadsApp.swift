import SceneKit
import SwiftUI

@main
struct LittleCrossroadsApp: App {
    var body: some Scene {
        WindowGroup { CrossroadsView() }
    }
}

private enum Palette {
    static let ink = Color(uiColor: ToyColor.dark)
    static let navy = Color(uiColor: ToyColor.navy)
    static let royal = Color(uiColor: ToyColor.royal)
    static let sky = Color(uiColor: ToyColor.sky)
    static let white = Color(uiColor: ToyColor.cream)
    static let yellow = Color(uiColor: ToyColor.yellow)
    static let honey = Color(red: 0.72, green: 0.50, blue: 0.02)
    static let coral = Color(uiColor: ToyColor.coral)
    static let brick = Color(red: 0.55, green: 0.10, blue: 0.02)
    static let mint = Color(uiColor: ToyColor.mint)
    static let gray = Color(uiColor: ToyColor.curb)
    static let slate = Color(red: 0.36, green: 0.36, blue: 0.40)
    static let steel = Color(red: 0.16, green: 0.16, blue: 0.20)
    static let glass = Color(uiColor: ToyColor.dark).opacity(0.78)
}

private extension Font {
    static func body(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}

struct CrossroadsView: View {
    @StateObject private var store = GameStore()
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 380
            ZStack {
                NativeWorld(store: store).ignoresSafeArea()
                    .accessibilityLabel("Little Crossroads countryside")
                VStack(spacing: 0) {
                    if store.state == .ready {
                        titleHeader(compact: compact)
                    } else {
                        gameHeader
                    }
                    Spacer(minLength: 0)
                    if store.state == .ready {
                        startPanel(compact: compact)
                    } else if store.state == .playing {
                        controls(compact: compact)
                    }
                }
                .padding(.horizontal, compact ? 14 : 18)
                .padding(.top, 6)
                .padding(.bottom, 8)
                if store.state == .playing, let toast = store.toast {
                    Pop(reducedMotion: reducedMotion) {
                        PixelText(toast, scale: 4, color: Palette.yellow, shadow: Palette.brick)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Palette.glass)
                            .overlay(Rectangle().strokeBorder(Palette.yellow, lineWidth: 3))
                    }
                    .offset(y: -60)
                    .accessibilityIdentifier("toast")
                }
                if store.state == .paused {
                    pauseCard
                }
                if store.state == .finished, store.showResults {
                    resultCard
                }
            }
            .sheet(isPresented: $store.showWardrobe) { wardrobe }
            .sheet(isPresented: $store.showGuide) { guide }
            .onChange(of: phase) { _, new in
                if new != .active {
                    store.pause()
                }
            }
            .onChange(of: reducedMotion, initial: true) { _, value in store.reducedMotion = value }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Title

    private func titleHeader(compact: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                chip {
                    PixelText("BEST", scale: 2, color: Palette.gray, shadow: nil)
                    PixelText(pad(store.best), scale: 2, shadow: nil)
                }
                chip {
                    CoinMark()
                    PixelText(pad(store.bank), scale: 2, color: Palette.yellow, shadow: nil)
                }
                Spacer()
                soundButton
            }
            .frame(minHeight: 44)
            Spacer().frame(height: compact ? 26 : 44)
            VStack(spacing: 10) {
                PixelText("LITTLE", scale: 3, color: Palette.white, shadow: Palette.ink, alignment: .center)
                PixelText(
                    "CROSSROADS",
                    scale: compact ? 4 : 5,
                    color: Palette.yellow,
                    shadow: Palette.brick,
                    alignment: .center
                )
                .padding(.bottom, 4)
                CheckerStrip().frame(width: compact ? 168 : 216, height: 8)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 26)
            .background(Palette.glass)
            .overlay(Rectangle().strokeBorder(Palette.yellow, lineWidth: 3).padding(3))
            .overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: 3))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Little Crossroads")
        }
        .frame(maxWidth: .infinity)
    }

    private func startPanel(compact: Bool) -> some View {
        VStack(spacing: 12) {
            Blink(reducedMotion: reducedMotion) {
                PixelText("TAP START TO HOP", scale: 2, shadow: nil)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Palette.glass)
            }
            .frame(height: 30)
            Button { store.start() } label: {
                PixelText("START", scale: 4, color: Palette.ink, shadow: nil, alignment: .center)
                    .frame(maxWidth: .infinity).frame(height: 58)
            }
            .buttonStyle(BlockPress(fill: Palette.yellow, shade: Palette.honey))
            .accessibilityIdentifier("startGame")
            HStack(spacing: 10) {
                Button { store.showWardrobe = true } label: {
                    HStack(spacing: 8) {
                        DuckSpriteView(plumage: ToyColor.duck(store.selected)).frame(width: 22, height: 22)
                        PixelText("FLOCK", scale: 2, shadow: nil)
                    }
                    .frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(BlockPress(fill: Palette.royal, shade: Palette.navy, depth: 4))
                .accessibilityIdentifier("openWardrobe")
                Button { store.showGuide = true } label: {
                    PixelText("HOW TO PLAY", scale: 2, shadow: nil, alignment: .center)
                        .frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(BlockPress(fill: Palette.royal, shade: Palette.navy, depth: 4))
                .accessibilityIdentifier("openGuide")
            }
            if let next = store.nextUnlock {
                PixelText(
                    "NEXT: \(next.name) IN \(next.coins) \(next.coins == 1 ? "COIN" : "COINS")",
                    scale: 2,
                    color: Palette.gray,
                    shadow: nil
                )
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Palette.glass)
                .padding(.top, 2)
            }
        }
        .padding(.bottom, compact ? 2 : 10)
    }

    // MARK: Gameplay

    private var gameHeader: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top) {
                chip {
                    CoinMark()
                    PixelText(pad(store.runCoins, 2), scale: 3, color: Palette.yellow, shadow: nil)
                        .accessibilityIdentifier("coinValue")
                }
                .frame(height: 44)
                Spacer()
                Button { store.pause() } label: {
                    PauseMark().frame(width: 44, height: 44)
                }
                .buttonStyle(BlockPress(fill: Palette.slate, shade: Palette.steel, depth: 3))
                .accessibilityLabel("Pause game").accessibilityIdentifier("pauseGame")
            }
            .overlay(alignment: .top) {
                let beating = store.best > 0 && store.score > store.best
                VStack(spacing: 5) {
                    PixelText(pad(store.score), scale: 6, shadow: nil, alignment: .center)
                        .accessibilityIdentifier("scoreValue")
                    PixelText(
                        beating ? "NEW BEST" : "BEST \(pad(store.best))",
                        scale: 2,
                        color: beating ? Palette.yellow : Palette.gray,
                        shadow: nil
                    )
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Palette.glass)
                .overlay(Rectangle().strokeBorder(Palette.white.opacity(0.85), lineWidth: 2))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(store.score) hops, best \(store.best)")
            }
        }
        .padding(.top, 4)
    }

    private func controls(compact: Bool) -> some View {
        VStack(spacing: 14) {
            if store.showHints, !store.controlPad {
                HStack(spacing: 14) {
                    hint("^", "TAP")
                    hint("<", "SWIPE")
                    hint(">", "SWIPE")
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Palette.glass)
                .overlay(Rectangle().strokeBorder(Palette.white.opacity(0.7), lineWidth: 2))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tap to hop forward, swipe to steer")
            }
            if store.controlPad {
                HStack(alignment: .center) {
                    dpad(size: compact ? 46 : 52)
                    Spacer()
                    Button { store.move(.forward) } label: {
                        PixelText("A", scale: 5, color: Palette.white, shadow: Palette.brick)
                            .frame(width: compact ? 88 : 96, height: compact ? 88 : 96)
                    }
                    .buttonStyle(RoundPress())
                    .accessibilityLabel("Hop forward").accessibilityIdentifier("hopForward")
                }
                .padding(.horizontal, 6)
            } else {
                HStack {
                    Button { store.move(.backward) } label: {
                        PixelText("_", scale: 3, shadow: nil).frame(width: 52, height: 44)
                    }
                    .buttonStyle(BlockPress(fill: Palette.slate, shade: Palette.steel, depth: 3))
                    .accessibilityLabel("Step back").accessibilityIdentifier("hopBackward")
                    Spacer()
                }
            }
        }
        .padding(.bottom, 2)
    }

    private func hint(_ glyph: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            PixelText(glyph, scale: 2, color: Palette.yellow, shadow: nil)
            PixelText(label, scale: 2, shadow: nil)
        }
    }

    private func dpad(size: CGFloat) -> some View {
        let gap: CGFloat = 2
        return VStack(spacing: gap) {
            dpadKey("^", label: "Hop forward", id: "dpadUp", direction: .forward, size: size)
            HStack(spacing: gap) {
                dpadKey("<", label: "Hop left", id: "hopLeft", direction: .left, size: size)
                Rectangle().fill(Palette.steel).frame(width: size, height: size)
                    .overlay(Circle().fill(Palette.slate).padding(size * 0.3))
                dpadKey(">", label: "Hop right", id: "hopRight", direction: .right, size: size)
            }
            dpadKey("_", label: "Step back", id: "hopBackward", direction: .backward, size: size)
        }
        .accessibilityElement(children: .contain)
    }

    private func dpadKey(_ glyph: String, label: String, id: String, direction: Direction, size: CGFloat) -> some View {
        Button { store.move(direction) } label: {
            PixelText(glyph, scale: 3, shadow: nil).frame(width: size, height: size)
        }
        .buttonStyle(BlockPress(fill: Palette.slate, shade: Palette.steel, depth: 4))
        .accessibilityLabel(label).accessibilityIdentifier(id)
    }

    // MARK: Overlays

    private var pauseCard: some View {
        modal {
            VStack(spacing: 18) {
                PixelText("PAUSED", scale: 5, color: Palette.yellow, shadow: Palette.brick, alignment: .center)
                HStack {
                    PixelText("HOPS \(pad(store.score))", scale: 2)
                    Spacer()
                    PixelText("BEST \(pad(store.best))", scale: 2, color: Palette.gray)
                }
                Button { store.resume() } label: {
                    PixelText("> CONTINUE", scale: 3, color: Palette.ink, shadow: nil, alignment: .center)
                        .frame(maxWidth: .infinity).frame(height: 54)
                }
                .buttonStyle(BlockPress(fill: Palette.yellow, shade: Palette.honey))
                .accessibilityIdentifier("resumeGame")
                HStack(spacing: 10) {
                    toggleButton(store.sound ? "SOUND ON" : "SOUND OFF", on: store.sound) { store.sound.toggle() }
                        .accessibilityLabel(store.sound ? "Mute sound" : "Enable sound")
                    toggleButton(store.controlPad ? "PAD ON" : "PAD OFF", on: store.controlPad) {
                        store.controlPad.toggle()
                    }
                    .accessibilityLabel(store.controlPad ? "Hide control pad" : "Show control pad")
                    .accessibilityIdentifier("togglePad")
                }
                HStack(spacing: 10) {
                    smallButton("GUIDE") { store.showGuide = true }
                    smallButton("QUIT") { store.game.endRun() }
                        .accessibilityIdentifier("quitGame")
                }
            }
        }
    }

    private var resultCard: some View {
        modal {
            resultCardContent
        }
        .allowsHitTesting(store.resultsArmed)
    }

    private var resultCardContent: some View {
        VStack(spacing: 14) {
            PixelText(
                headline(store.reason),
                scale: 3,
                color: Palette.coral,
                shadow: Palette.brick,
                alignment: .center
            )
            HStack(alignment: .bottom, spacing: 16) {
                DuckSpriteView(plumage: ToyColor.duck(store.selected))
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    PixelText(store.newBest ? "NEW BEST!" : "HOPS", scale: 2, color: Palette.yellow)
                    PixelText(pad(store.score), scale: 7)
                        .accessibilityIdentifier("resultScore")
                }
            }
            HStack {
                PixelText(
                    "BEST \(pad(store.best))",
                    scale: 2,
                    color: store.newBest ? Palette.yellow : Palette.white
                )
                Spacer()
                HStack(spacing: 6) {
                    CoinMark()
                    PixelText("+\(pad(store.runCoins, 2))", scale: 2, color: Palette.yellow)
                }
            }
            if !store.unlockedNames.isEmpty {
                Blink(reducedMotion: reducedMotion) {
                    PixelText(
                        store.unlockedNames.count == 1
                            ? "\(store.unlockedNames[0].uppercased()) JOINED!"
                            : "\(store.unlockedNames.count) NEW DUCKS JOINED!",
                        scale: 2, color: Palette.mint
                    )
                }
                .frame(height: 20)
            } else if let next = store.nextUnlock {
                unlockMeter(next)
            }
            Button { store.start() } label: {
                PixelText("> PLAY AGAIN", scale: 3, color: Palette.ink, shadow: nil, alignment: .center)
                    .frame(maxWidth: .infinity).frame(height: 58)
            }
            .buttonStyle(BlockPress(fill: Palette.yellow, shade: Palette.honey))
            .accessibilityIdentifier("retryGame")
            HStack(spacing: 10) {
                smallButton("HOME") { store.home() }
                    .accessibilityIdentifier("goHome")
                ShareLink(
                    item: "I hopped \(store.score) rows in Little Crossroads! My personal best is \(store.best). Small hops. Big adventures."
                ) {
                    PixelText("SHARE", scale: 2, shadow: nil, alignment: .center)
                        .frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(BlockPress(fill: Palette.royal, shade: Palette.navy, depth: 4))
                smallButton("FLOCK") { store.showWardrobe = true }
            }
        }
    }

    private func unlockMeter(_ next: (name: String, coins: Int, hops: Int)) -> some View {
        let plumage = Plumage.allCases.first { $0.name.uppercased() == next.name } ?? .sunshine
        let progress = plumage.price == 0 ? 1 : Double(plumage.price - next.coins) / Double(plumage.price)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                PixelText("NEXT: \(next.name)", scale: 2, color: Palette.gray)
                Spacer()
                PixelText("\(next.coins) \(next.coins == 1 ? "COIN" : "COINS")", scale: 2, color: Palette.yellow)
            }
            Meter(progress: progress).frame(height: 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(next.name) unlocks in \(next.coins) coins or \(next.hops) hops")
    }

    private func headline(_ reason: String) -> String {
        if reason.contains("traffic") {
            return "BONKED BY TRAFFIC"
        }
        if reason.contains("splash") {
            return "SPLASH!"
        }
        if reason.contains("Swept") {
            return "SWEPT DOWNSTREAM"
        }
        return "TOOK A BREATHER"
    }

    private func doneButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PixelText("DONE", scale: 2, color: Palette.ink, shadow: nil, alignment: .center)
                .frame(width: 72, height: 32)
        }
        .buttonStyle(BlockPress(fill: Palette.yellow, shade: Palette.honey, depth: 3))
        .accessibilityLabel("Done")
    }

    private func smallButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PixelText(title, scale: 2, shadow: nil, alignment: .center)
                .frame(maxWidth: .infinity).frame(height: 44)
        }
        .buttonStyle(BlockPress(fill: Palette.royal, shade: Palette.navy, depth: 4))
    }

    private func toggleButton(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Rectangle().fill(on ? Palette.mint : Palette.steel).frame(width: 10, height: 10)
                    .overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: 2))
                PixelText(title, scale: 2, shadow: nil)
            }
            .frame(maxWidth: .infinity).frame(height: 44)
        }
        .buttonStyle(BlockPress(fill: Palette.slate, shade: Palette.steel, depth: 4))
    }

    private func chip<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) { content() }
            .padding(.horizontal, 10).frame(height: 36)
            .background(Palette.glass)
            .overlay(Rectangle().strokeBorder(Palette.white.opacity(0.85), lineWidth: 2))
    }

    private func modal<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Palette.ink.opacity(0.45).ignoresSafeArea()
            let card = content()
                .padding(22)
                .background(Palette.navy)
                .overlay(Rectangle().strokeBorder(Palette.white, lineWidth: 3).padding(3))
                .overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: 3))
                .background(Palette.ink.opacity(0.5).offset(x: 6, y: 6))
            Pop(reducedMotion: reducedMotion) { card }
                .padding(.horizontal, 20)
                .frame(maxWidth: 420)
        }
    }

    private var soundButton: some View {
        Button { store.sound.toggle() } label: {
            SpeakerMark(on: store.sound).frame(width: 44, height: 44)
        }
        .buttonStyle(BlockPress(fill: Palette.slate, shade: Palette.steel, depth: 3))
        .accessibilityLabel(store.sound ? "Mute sound" : "Enable sound")
        .accessibilityIdentifier("toggleSound")
    }

    private func pad(_ value: Int, _ digits: Int = 4) -> String {
        let text = String(value)
        return String(repeating: "0", count: max(0, digits - text.count)) + text
    }

    // MARK: Sheets

    private var wardrobe: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PixelText("MEET THE FLOCK", scale: 4, color: Palette.yellow, shadow: Palette.brick)
                    Text("Collect coins or set a new best to welcome new companions. Coins are never spent.")
                        .font(.body()).foregroundStyle(Palette.gray)
                    HStack(spacing: 10) {
                        chip {
                            CoinMark()
                            PixelText(pad(store.bank), scale: 2, color: Palette.yellow, shadow: nil)
                        }
                        chip {
                            PixelText("BEST", scale: 2, color: Palette.gray, shadow: nil)
                            PixelText(pad(store.best), scale: 2, shadow: nil)
                        }
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(Plumage.allCases) { duck in
                            let unlocked = duck.unlocked(coins: store.bank, best: store.best)
                            let chosen = store.selected == duck
                            Button {
                                if unlocked {
                                    store.selected = duck
                                }
                            } label: {
                                VStack(spacing: 10) {
                                    DuckSpriteView(plumage: ToyColor.duck(duck))
                                        .frame(width: 96, height: 96)
                                        .saturation(unlocked ? 1 : 0).opacity(unlocked ? 1 : 0.45)
                                    PixelText(duck.name, scale: 2, shadow: nil)
                                    if unlocked {
                                        PixelText(
                                            chosen ? "> SELECTED" : "SELECT",
                                            scale: 2,
                                            color: chosen ? Palette.yellow : Palette.gray,
                                            shadow: nil
                                        )
                                    } else {
                                        VStack(spacing: 6) {
                                            Meter(progress: min(
                                                1,
                                                max(
                                                    Double(store.bank) / Double(duck.price),
                                                    Double(store.best) / Double(duck.milestone)
                                                )
                                            ))
                                            .frame(height: 8).padding(.horizontal, 18)
                                            PixelText(
                                                "\(duck.price) COINS OR\n\(duck.milestone) HOPS",
                                                scale: 2,
                                                color: Palette.gray,
                                                shadow: nil,
                                                alignment: .center
                                            )
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(chosen ? Palette.royal : Palette.ink)
                                .overlay(Rectangle().strokeBorder(
                                    chosen ? Palette.yellow : Palette.white.opacity(unlocked ? 0.8 : 0.3),
                                    lineWidth: 3
                                ))
                            }
                            .disabled(!unlocked).buttonStyle(FlatPress())
                            .accessibilityIdentifier("plumage\(duck.rawValue)")
                        }
                    }
                }.padding(22).padding(.top, 44)
            }
            .background(Palette.navy)
            .overlay(alignment: .topTrailing) {
                doneButton { store.showWardrobe = false }.padding(.top, 16).padding(.trailing, 22)
            }
        }
    }

    private var guide: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PixelText("HOW TO PLAY", scale: 4, color: Palette.yellow, shadow: Palette.brick)
                    instruction(
                        "^",
                        title: "TAP TO HOP",
                        text: "Tap anywhere on the countryside to hop forward one row. Every row you reach is a point."
                    )
                    instruction(
                        "<",
                        title: "SWIPE TO STEER",
                        text: "Swipe left, right or down to sidestep or retreat. Cars never stop, so wait on the grass for a gap. There is no timer."
                    )
                    instruction(
                        "=",
                        title: "RIDE THE LOGS",
                        text: "Land on a floating log to cross water. It carries you sideways, so hop off before it reaches the edge."
                    )
                    instruction(
                        "*",
                        title: "GROW YOUR FLOCK",
                        text: "Coins and personal bests unlock three new companions, saved on this device. Prefer buttons? Turn on PAD from the pause menu."
                    )
                    Button { store.showGuide = false } label: {
                        PixelText("> GOT IT", scale: 3, color: Palette.ink, shadow: nil, alignment: .center)
                            .frame(maxWidth: .infinity).frame(height: 54)
                    }
                    .buttonStyle(BlockPress(fill: Palette.yellow, shade: Palette.honey))
                }.padding(22).padding(.top, 44)
            }
            .background(Palette.navy)
            .overlay(alignment: .topTrailing) {
                doneButton { store.showGuide = false }.padding(.top, 16).padding(.trailing, 22)
            }
        }
    }

    private func instruction(_ glyph: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            PixelText(glyph, scale: 3, color: Palette.ink, shadow: nil)
                .frame(width: 40, height: 40)
                .background(Palette.yellow)
                .overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: 3))
            VStack(alignment: .leading, spacing: 8) {
                PixelText(title, scale: 3)
                Text(text).font(.body()).foregroundStyle(Palette.gray).lineSpacing(3)
            }
        }
    }
}

// MARK: Design elements

/// A small pixel coin used wherever a coin count appears.
private struct CoinMark: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Palette.yellow)
            Rectangle().fill(Color(uiColor: ToyColor.beak)).padding(3)
            Rectangle().fill(Palette.yellow).frame(width: 3, height: 8)
        }
        .frame(width: 14, height: 16)
        .overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: 2))
        .accessibilityLabel("Coins")
    }
}

private struct PauseMark: View {
    var body: some View {
        HStack(spacing: 5) {
            Rectangle().fill(Palette.white).frame(width: 6, height: 18)
            Rectangle().fill(Palette.white).frame(width: 6, height: 18)
        }
        .accessibilityHidden(true)
    }
}

private struct SpeakerMark: View {
    let on: Bool
    var body: some View {
        Canvas { context, size in
            let unit = size.width / 11
            func cell(_ x: Int, _ y: Int, _ color: Color) {
                context.fill(
                    Path(CGRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit, width: unit, height: unit)),
                    with: .color(color)
                )
            }
            for y in 4 ... 6 {
                cell(2, y, Palette.white)
            }
            for y in 3 ... 7 {
                cell(3, y, Palette.white)
            }
            for y in 2 ... 8 {
                cell(4, y, Palette.white)
            }
            for y in 1 ... 9 {
                cell(5, y, Palette.white)
            }
            if on {
                for (x, ys) in [(7, 4 ... 6), (8, 3 ... 7), (9, 2 ... 8)] {
                    for y in ys where y == ys.lowerBound || y == ys.upperBound {
                        cell(x, y, Palette.yellow)
                    }
                }
            } else {
                for offset in 0 ... 3 {
                    cell(7 + offset, 3 + offset, Palette.coral)
                    cell(7 + offset, 7 - offset, Palette.coral)
                }
            }
        }
        .padding(8)
        .accessibilityHidden(true)
    }
}

/// A segmented pixel progress bar.
private struct Meter: View {
    let progress: Double
    var body: some View {
        GeometryReader { geometry in
            let segments = max(1, Int(geometry.size.width / 12))
            let filled = Int((Double(segments) * min(1, max(0, progress))).rounded(.down))
            HStack(spacing: 2) {
                ForEach(0 ..< segments, id: \.self) { index in
                    Rectangle().fill(index < filled ? Palette.mint : Palette.steel)
                }
            }
            .padding(2)
            .background(Palette.ink)
        }
    }
}

private struct CheckerStrip: View {
    var body: some View {
        Canvas { context, size in
            let unit = size.height / 2
            var column = 0
            var x: CGFloat = 0
            while x < size.width {
                for row in 0 ..< 2 where (row + column) % 2 == 0 {
                    context.fill(
                        Path(CGRect(x: x, y: CGFloat(row) * unit, width: unit, height: unit)),
                        with: .color(Palette.coral)
                    )
                }
                x += unit
                column += 1
            }
        }
        .accessibilityHidden(true)
    }
}

/// Frame-stepped entrance: three discrete scale steps, like a console pop-up window.
private struct Pop<Content: View>: View {
    let reducedMotion: Bool
    @ViewBuilder let content: () -> Content
    @State private var step = 3

    var body: some View {
        content()
            .scaleEffect(reducedMotion ? 1 : [0.6, 0.85, 1.05, 1][step], anchor: .center)
            .onAppear {
                guard !reducedMotion else { return }
                step = 0
                for index in 1 ... 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 * Double(index)) {
                        step = index
                    }
                }
            }
    }
}

private struct Blink<Content: View>: View {
    let reducedMotion: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.45)) { timeline in
            let on = reducedMotion || Int(timeline.date.timeIntervalSinceReferenceDate / 0.45) % 2 == 0
            content().opacity(on ? 1 : 0)
        }
    }
}

private struct FlatPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct BlockPress: ButtonStyle {
    let fill: Color
    let shade: Color
    var depth: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Palette.white)
            .background(fill)
            .overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: 3))
            .offset(y: configuration.isPressed ? depth : 0)
            .background(alignment: .bottom) {
                Rectangle().fill(shade).overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: 3))
                    .offset(y: depth)
            }
            .padding(.bottom, depth)
    }
}

private struct RoundPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Circle().fill(Palette.coral))
            .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3))
            .offset(y: configuration.isPressed ? 5 : 0)
            .background(Circle().fill(Palette.brick).overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3))
                .offset(y: 5))
            .padding(.bottom, 5)
    }
}

private struct NativeWorld: UIViewRepresentable {
    let store: GameStore
    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = store.world.scene
        view.pointOfView = store.world.camera
        view.antialiasingMode = .none
        view.contentScaleFactor = 1.5
        view.layer.magnificationFilter = .nearest
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        view.backgroundColor = ToyColor.sky
        view.addGestureRecognizer(UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.tap)
        ))
        for direction: UISwipeGestureRecognizer.Direction in [.up, .down, .left, .right] {
            let swipe = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swipe(_:)))
            swipe.direction = direction
            view.addGestureRecognizer(swipe)
        }
        return view
    }

    func updateUIView(_: SCNView, context _: Context) {}

    @MainActor
    final class Coordinator: NSObject {
        let store: GameStore
        init(store: GameStore) {
            self.store = store
        }

        @objc func tap() {
            store.move(.forward)
        }

        @objc func swipe(_ gesture: UISwipeGestureRecognizer) {
            switch gesture.direction {
            case .up: store.move(.forward)
            case .down: store.move(.backward)
            case .left: store.move(.left)
            default: store.move(.right)
            }
        }
    }
}
