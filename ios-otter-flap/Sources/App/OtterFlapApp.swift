import SpriteKit
import SwiftUI

func rounded(_ size: CGFloat, _ weight: Font.Weight = .black) -> Font {
    .system(size: size, weight: weight, design: .rounded)
}

let furColor = Color(uiColor: Palette.fur)
let outlineColor = Color(uiColor: Palette.outline)
let creamColor = Color(uiColor: Palette.cream)

@main
struct OtterFlapApp: App {
    @StateObject private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            GameView(store: store)
                .statusBarHidden()
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        store.pause()
                    }
                }
        }
    }
}

struct GameView: View {
    @ObservedObject var store: GameStore

    var body: some View {
        ZStack {
            SpriteView(scene: store.scene, preferredFramesPerSecond: 120, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
                .accessibilityLabel("River course. Tap anywhere to flap.")
                .accessibilityAddTraits(.allowsDirectInteraction)
                .accessibilityIdentifier("playfield")

            VStack {
                HStack {
                    Spacer()
                    Button(action: store.toggleSound) {
                        Image(systemName: store.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.22), in: Circle())
                    }
                    .accessibilityLabel(store.soundOn ? "Sound on" : "Sound off")
                    .accessibilityIdentifier("sound")
                }
                .padding(.horizontal, 18)
                Spacer()
            }

            if store.phase == .playing || store.phase == .falling {
                VStack {
                    OutlinedText(text: "\(store.score)", size: 64)
                        .padding(.top, 70)
                        .accessibilityIdentifier("score")
                        .accessibilityLabel("Score \(store.score)")
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            if store.phase == .ready {
                TitleCard(best: store.best)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if store.paused {
                VStack(spacing: 14) {
                    OutlinedText(text: "Paused", size: 44)
                    Text("Tap to keep paddling")
                        .font(rounded(18, .bold))
                        .foregroundStyle(.white)
                        .shadow(color: outlineColor, radius: 0, x: 0, y: 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.25))
                .allowsHitTesting(false)
                .accessibilityIdentifier("paused")
            }

            if store.showResults {
                ResultsCard(store: store)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.phase)
    }
}

struct OutlinedText: View {
    let text: String
    let size: CGFloat

    var body: some View {
        ZStack {
            ForEach(0 ..< 8, id: \.self) { index in
                let angle = Double(index) / 8 * 2 * .pi
                Text(text)
                    .font(rounded(size))
                    .foregroundStyle(outlineColor)
                    .offset(x: cos(angle) * size * 0.055, y: sin(angle) * size * 0.055 + size * 0.03)
            }
            Text(text)
                .font(rounded(size))
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

struct TitleCard: View {
    let best: Int

    var body: some View {
        VStack(spacing: 10) {
            OutlinedText(text: "Otter Flap", size: 52)
                .accessibilityIdentifier("title")
            Text("Paddle through the driftwood")
                .font(rounded(17, .bold))
                .foregroundStyle(outlineColor.opacity(0.85))
            Spacer().frame(height: 200)
            VStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 34))
                    .phaseAnimator([false, true]) { view, pressed in
                        view.scaleEffect(pressed ? 0.82 : 1).offset(y: pressed ? 4 : 0)
                    } animation: { _ in .easeInOut(duration: 0.45) }
                Text("Tap to flap")
                    .font(rounded(22))
            }
            .foregroundStyle(.white)
            .shadow(color: outlineColor, radius: 0, x: 0, y: 2)
            .accessibilityIdentifier("tapToFlap")
            if best > 0 {
                Text("Best \(best)")
                    .font(rounded(16, .heavy))
                    .foregroundStyle(creamColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(outlineColor.opacity(0.55), in: Capsule())
                    .padding(.top, 8)
                    .accessibilityIdentifier("titleBest")
            }
            Spacer()
        }
        .padding(.top, 150)
    }
}

struct ResultsCard: View {
    @ObservedObject var store: GameStore

    var body: some View {
        VStack(spacing: 18) {
            OutlinedText(text: "Splash!", size: 46)
            VStack(spacing: 14) {
                HStack(alignment: .center, spacing: 18) {
                    MedalView(medal: store.medal)
                    VStack(alignment: .trailing, spacing: 8) {
                        stat("Score", store.score, id: "finalScore")
                        stat("Best", store.best, id: "bestScore")
                    }
                }
                if store.newBest {
                    Text("New best!")
                        .font(rounded(15, .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.93, green: 0.36, blue: 0.3), in: Capsule())
                        .accessibilityIdentifier("newBest")
                }
            }
            .padding(20)
            .frame(width: 290)
            .background(creamColor, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(outlineColor, lineWidth: 3))

            Button(action: store.restart) {
                Label("Play again", systemImage: "arrow.clockwise")
                    .font(rounded(21))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.95, green: 0.55, blue: 0.2), in: Capsule())
                    .overlay(Capsule().stroke(outlineColor, lineWidth: 3))
            }
            .accessibilityIdentifier("playAgain")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.18))
    }

    private func stat(_ label: String, _ value: Int, id: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(label.uppercased())
                .font(rounded(12, .heavy))
                .foregroundStyle(Color(uiColor: Palette.barkDark).opacity(0.8))
            Text("\(value)")
                .font(rounded(32))
                .foregroundStyle(outlineColor)
                .accessibilityIdentifier(id)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MedalView: View {
    let medal: Medal?

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(fill)
                    .frame(width: 70, height: 70)
                    .overlay(Circle().stroke(outlineColor, lineWidth: 3))
                Image(systemName: medal == nil ? "drop.fill" : "star.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white.opacity(medal == nil ? 0.6 : 0.95))
            }
            Text(medal?.rawValue ?? "No medal")
                .font(rounded(12, .heavy))
                .foregroundStyle(outlineColor.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("medal")
    }

    private var fill: Color {
        switch medal {
        case .pebble: Color(red: 0.6, green: 0.6, blue: 0.62)
        case .shell: Color(red: 0.96, green: 0.62, blue: 0.56)
        case .pearl: Color(red: 0.78, green: 0.84, blue: 0.95)
        case .golden: Color(red: 0.98, green: 0.76, blue: 0.2)
        case nil: Color(uiColor: Palette.water).opacity(0.6)
        }
    }
}
