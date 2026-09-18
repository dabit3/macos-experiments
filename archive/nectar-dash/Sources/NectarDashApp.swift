import SwiftUI
import UIKit

@main
struct NectarDashApp: App {
  var body: some Scene {
    WindowGroup {
      NectarRootView()
        .preferredColorScheme(.dark)
    }
  }
}

struct ShareHarvest: Identifiable {
  let id = UUID()
  let image: UIImage
  let text: String
}

struct NativeShareSheet: UIViewControllerRepresentable {
  let harvest: ShareHarvest

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(
      activityItems: [harvest.text, harvest.image], applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct NectarRootView: View {
  @StateObject private var store = GardenStore()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var harvest: ShareHarvest?

  private var artTime: Double { reduceMotion || store.calmMotion ? 0 : store.clock }

  var body: some View {
    ZStack {
      BotanicalBackdrop(time: artTime, lush: store.screen != .playing).ignoresSafeArea()
      switch store.screen {
      case .home:
        home
      case .playing:
        PlayGardenView(store: store, time: artTime)
      case .result:
        result
      }
      if store.showTutorial { tutorial }
      if store.paused && store.screen == .playing { pause }
    }
    .foregroundStyle(NectarPalette.cream)
    .tint(NectarPalette.honey)
    .sheet(isPresented: $store.showSettings) { settings }
    .sheet(item: $harvest) { NativeShareSheet(harvest: $0) }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active && store.screen == .playing { store.paused = true }
    }
  }

  private var home: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 720
      VStack(spacing: 0) {
        HStack {
          Image(systemName: "hexagon").font(.system(size: 18, weight: .light))
          Text("THE LITTLE GARDEN CO.").font(.system(size: 9, weight: .medium)).tracking(2)
          Spacer()
          iconButton("slider.horizontal.3", label: "Settings", id: "settings") {
            store.showSettings = true
          }
        }
        .foregroundStyle(NectarPalette.sage)
        .padding(.horizontal, 26)

        VStack(spacing: compact ? 5 : 9) {
          eyebrow("A SMALL FLIGHT. A WILD WORLD.")
          Text("Nectar Dash")
            .font(.system(size: compact ? 55 : 64, weight: .regular, design: .serif))
            .tracking(-3)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
          Text("Find your flow. Leave a little bloom.")
            .font(.system(size: 14)).foregroundStyle(NectarPalette.cream.opacity(0.70))
        }
        .padding(.top, compact ? 14 : 30)
        .padding(.horizontal, 16)

        HeroGarden(time: artTime)
          .frame(maxHeight: .infinity)
        HStack {
          Text("FLY · CHAIN · BLOOM").font(.system(size: 9, weight: .medium)).tracking(1.8)
          Spacer()
          HStack(spacing: 5) {
            Image(systemName: "sparkle")
            Text("Best  \(store.progress.bestScore)")
          }
          .font(.system(size: 12))
          .foregroundStyle(NectarPalette.sage)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 8)
        VStack(spacing: 14) {
          HStack {
            VStack(alignment: .leading, spacing: 6) {
              eyebrow(GardenMode.meadow(store.selectedStage).subtitle)
              Text(GardenMode.meadow(store.selectedStage).title)
                .font(.system(size: 24, weight: .regular, design: .serif))
            }
            Spacer()
            HStack(spacing: 4) {
              ForEach(1...3, id: \.self) { stage in
                Button {
                  store.selectedStage = stage
                } label: {
                  ZStack {
                    Circle().stroke(NectarPalette.sage.opacity(0.35), lineWidth: 1)
                    if stage > store.progress.unlockedStage {
                      Image(systemName: "lock.fill").font(.system(size: 11))
                    } else {
                      Text("\(stage)").font(.system(size: 13, weight: .medium))
                    }
                  }
                  .frame(width: 36, height: 36)
                  .foregroundStyle(
                    store.selectedStage == stage ? NectarPalette.ink : NectarPalette.sage
                  )
                  .background(
                    store.selectedStage == stage ? NectarPalette.honey : .clear, in: Circle()
                  )
                  .frame(width: 44, height: 44)
                }
                .disabled(stage > store.progress.unlockedStage)
                .accessibilityLabel(
                  "Garden \(stage), \(GardenMode.meadow(stage).title)\(stage > store.progress.unlockedStage ? ", locked" : "")"
                )
                .accessibilityIdentifier("garden-\(stage)")
              }
            }
          }
          primaryButton("Into the garden", symbol: "arrow.up.right", id: "start-garden") {
            store.start(.meadow(store.selectedStage))
          }
          HStack {
            Button {
              store.start(.daily())
            } label: {
              HStack(spacing: 8) {
                Image(systemName: "sun.max")
                Text("Daily garden")
                Image(systemName: "arrow.up.right").font(.system(size: 10))
              }
              .font(.system(size: 13))
              .frame(minHeight: 44)
            }
            .accessibilityIdentifier("daily-garden")
            Spacer()
            Button("How to fly") { store.showTutorial = true }
              .font(.system(size: 13))
              .frame(minHeight: 44)
              .accessibilityIdentifier("how-to-fly")
          }
          .foregroundStyle(NectarPalette.cream.opacity(0.8))
        }
        .padding(.horizontal, 26)
        .padding(.top, 14)
        .padding(.bottom, 8)
      }
    }
  }

  private var result: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 720
      let success = store.rules.end == .blooming
      VStack(spacing: compact ? 9 : 15) {
        HStack {
          eyebrow(store.rules.mode.title.uppercased())
          Spacer()
          iconButton("xmark", label: "Back to gardens", id: "result-home") { store.home() }
        }
        .padding(.horizontal, 26)
        Text(
          success
            ? "A garden, awakened."
            : store.rules.mode.isDaily ? "A day's little wonder." : "Every flight is a seed."
        )
        .font(.system(size: compact ? 30 : 36, weight: .regular, design: .serif))
        .tracking(-1)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 14)
        Text(
          success
            ? "Your honey is home. The next garden is waiting."
            : store.rules.end == .tangled
              ? "The webs won this time. A fresh flight awaits."
              : "The sun has set. Your banked honey is safe."
        )
        .font(.system(size: 12))
        .foregroundStyle(NectarPalette.sage)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        GardenSnapshot(rules: store.rules)
          .frame(maxHeight: .infinity)
          .padding(.horizontal, 24)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          Text("\(store.rules.score)")
            .font(.system(size: compact ? 56 : 70, weight: .regular, design: .serif))
            .contentTransition(.numericText())
          VStack(alignment: .leading, spacing: 4) {
            eyebrow("HONEY BANKED")
            Text(
              "Best \(store.rules.mode.isDaily ? store.progress.bestDaily : store.progress.bestScore)"
            )
            .font(.system(size: 12)).foregroundStyle(NectarPalette.sage)
          }
        }
        HStack(spacing: 0) {
          resultMetric("\(store.rules.totalBlooms)", label: "BLOOMS")
          Rectangle().fill(NectarPalette.sage.opacity(0.3)).frame(width: 1, height: 28)
          resultMetric("\(store.rules.longestChain)", label: "BEST CHAIN")
          Rectangle().fill(NectarPalette.sage.opacity(0.3)).frame(width: 1, height: 28)
          resultMetric("\(store.rules.waveCount)", label: "BLOOM WAVES")
        }
        .padding(.vertical, 6)
        VStack(spacing: 8) {
          primaryButton(
            success && store.rules.mode.stage < 3 ? "The next garden" : "Take another flight",
            symbol: "arrow.up.right", id: "play-again"
          ) {
            let mode =
              success && store.rules.mode.stage < 3
              ? GardenMode.meadow(store.rules.mode.stage + 1) : store.rules.mode
            store.start(mode)
          }
          Button {
            shareGarden()
          } label: {
            Label("Share your garden", systemImage: "square.and.arrow.up")
              .font(.system(size: 14))
              .frame(maxWidth: .infinity, minHeight: 48)
          }
          .accessibilityIdentifier("share-garden")
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 5)
      }
    }
  }

  private var tutorial: some View {
    modal {
      VStack(alignment: .leading, spacing: 22) {
        eyebrow("THE ART OF A LITTLE FLIGHT")
        Text("Follow the flowers.")
          .font(.system(size: 35, weight: .regular, design: .serif)).tracking(-1)
        HStack(spacing: 12) {
          ForEach(BloomColor.allCases, id: \.rawValue) { color in
            VStack(spacing: 8) {
              Canvas { context, size in
                BotanicalDrawing.flower(
                  in: context, at: CGPoint(x: size.width / 2, y: size.height / 2),
                  radius: 26, color: color)
              }
              .frame(height: 62)
              Text("\(color.mark)  \(color.name)").font(.system(size: 12, weight: .medium))
            }
            if color != .iris {
              Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(
                NectarPalette.sage)
            }
          }
        }
        tutorialLine(
          "hand.draw", title: "Trace your flight",
          text: "Draw from your bee to the next color. Tap a bloom for a direct flight.")
        tutorialLine(
          "sparkles", title: "Six blooms. One big wave.",
          text:
            "Repeat Gold → Rose → Iris. A chain of 3 doubles new pollen; 6 adds a +30 blossom bonus."
        )
        tutorialLine(
          "arrow.down.to.line", title: "Bring the honey home",
          text: "Tap the hive to bank. Webs cost a life and your pollen. Wind costs 5 seconds.")
        HStack(spacing: 12) {
          Canvas { context, size in
            BotanicalDrawing.hive(
              in: context, at: CGPoint(x: size.width / 2, y: size.height / 2), size: 29,
              ready: true)
          }
          .frame(width: 60, height: 44)
          Text("This is your hive.\nFind it at the foot of the garden.")
            .font(.system(size: 12)).foregroundStyle(NectarPalette.cream.opacity(0.88))
        }
        primaryButton(
          store.screen == .home ? "Lovely, let's fly" : "Ready to fly", symbol: "arrow.right",
          id: "tutorial-done"
        ) {
          store.dismissTutorial()
        }
      }
    }
  }

  private var pause: some View {
    modal {
      VStack(spacing: 20) {
        eyebrow("A MOMENT IN THE SHADE")
        Text("Catch your breath.")
          .font(.system(size: 34, weight: .regular, design: .serif))
        Text("Your garden will wait right here.")
          .font(.system(size: 14)).foregroundStyle(NectarPalette.sage)
        primaryButton("Keep flying", symbol: "play.fill", id: "resume") { store.paused = false }
        Button("Start this garden again") { store.start(store.rules.mode) }
          .frame(minHeight: 44).accessibilityIdentifier("restart")
        Button("Back to the gardens") { store.home() }
          .frame(minHeight: 44).accessibilityIdentifier("pause-home")
      }
    }
  }

  private var settings: some View {
    VStack(alignment: .leading, spacing: 25) {
      HStack {
        Text("A gentler garden").font(.system(size: 30, design: .serif))
        Spacer()
        iconButton("xmark", label: "Close settings", id: "close-settings") {
          store.showSettings = false
        }
      }
      Toggle("Haptic feedback", isOn: $store.haptics).accessibilityIdentifier("haptics-toggle")
      Toggle("Calm motion", isOn: $store.calmMotion).accessibilityIdentifier("motion-toggle")
      Text(
        "Calm motion stills drifting pollen and wing flutter. System Reduce Motion is also respected. Essential flight movement remains visible."
      )
      .font(.system(size: 13)).foregroundStyle(NectarPalette.sage)
      Text("An intentionally quiet world. No audio, accounts or connection needed.")
        .font(.system(size: 13)).foregroundStyle(NectarPalette.sage)
    }
    .padding(26)
    .foregroundStyle(NectarPalette.cream)
    .presentationDetents([.height(370)])
    .presentationDragIndicator(.visible)
    .presentationBackground(NectarPalette.ink)
  }

  private func tutorialLine(_ symbol: String, title: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: symbol).font(.system(size: 21, weight: .light)).frame(width: 27, height: 30)
        .foregroundStyle(NectarPalette.honey)
      VStack(alignment: .leading, spacing: 5) {
        Text(title).font(.system(size: 15, weight: .medium))
        Text(text).font(.system(size: 13)).foregroundStyle(NectarPalette.cream.opacity(0.78))
          .fixedSize(
            horizontal: false, vertical: true)
      }
    }
  }

  private func resultMetric(_ value: String, label: String) -> some View {
    VStack(spacing: 5) {
      Text(value).font(.system(size: 23, weight: .regular, design: .serif))
      Text(label).font(.system(size: 8, weight: .medium)).tracking(1.4).foregroundStyle(
        NectarPalette.sage)
    }
    .frame(maxWidth: .infinity)
  }

  private func modal<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    ZStack {
      NectarPalette.ink.opacity(0.83).ignoresSafeArea()
      ScrollView {
        content()
          .padding(26)
          .background {
            RoundedRectangle(cornerRadius: 28)
              .fill(NectarPalette.forest.gradient)
              .overlay(
                RoundedRectangle(cornerRadius: 28).stroke(
                  NectarPalette.sage.opacity(0.25), lineWidth: 1))
          }
          .padding(18)
      }
      .scrollBounceBehavior(.basedOnSize)
      .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityAddTraits(.isModal)
  }

  private func shareGarden() {
    let renderer = ImageRenderer(content: ShareGardenCard(rules: store.rules))
    renderer.scale = 3
    guard let image = renderer.uiImage else { return }
    harvest = ShareHarvest(
      image: image,
      text:
        "I brought home \(store.rules.score) honey in Nectar Dash's \(store.rules.mode.title), with a \(store.rules.longestChain)-bloom chain. A small flight. A wild world."
    )
  }
}

func eyebrow(_ text: String) -> some View {
  Text(text).font(.system(size: 9, weight: .medium)).tracking(2).foregroundStyle(NectarPalette.sage)
}

func iconButton(_ symbol: String, label: String, id: String, action: @escaping () -> Void)
  -> some View
{
  Button(action: action) {
    Image(systemName: symbol).font(.system(size: 18, weight: .regular))
      .frame(width: 44, height: 44)
      .contentShape(Rectangle())
  }
  .accessibilityLabel(label)
  .accessibilityIdentifier(id)
}

func primaryButton(_ title: String, symbol: String, id: String, action: @escaping () -> Void)
  -> some View
{
  Button(action: action) {
    HStack {
      Text(title).font(.system(size: 16, weight: .semibold))
      Spacer()
      Image(systemName: symbol).font(.system(size: 17, weight: .medium))
    }
    .foregroundStyle(NectarPalette.ink)
    .padding(.horizontal, 21)
    .frame(minHeight: 56)
    .background(
      LinearGradient(
        colors: [Color(red: 0.98, green: 0.83, blue: 0.49), NectarPalette.honey],
        startPoint: .topLeading, endPoint: .bottomTrailing),
      in: RoundedRectangle(cornerRadius: 18))
  }
  .accessibilityIdentifier(id)
}
