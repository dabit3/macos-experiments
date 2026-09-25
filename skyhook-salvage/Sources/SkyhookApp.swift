import Combine
import SwiftUI
import UIKit

@main
struct SkyhookApp: App {
  var body: some Scene {
    WindowGroup { HarborView() }
  }
}

struct SharePayload: Identifiable {
  let id = UUID()
  let image: UIImage
  let text: String
}

struct TutorialRequest: Identifiable {
  let id = UUID()
  let startsGame: Bool
  let practice: Bool
}

struct HarborView: View {
  @State private var game = GameModel()
  @State private var selectedContract = 0
  @State private var settingsShown = false
  @State private var tutorialRequest: TutorialRequest?
  @State private var sharePayload: SharePayload?
  @State private var feedback = Feedback()
  @AppStorage("tutorialSeen") private var tutorialSeen = false
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reducedMotion
  private let timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

  var body: some View {
    ZStack {
      HarborPalette.fog.ignoresSafeArea()
      if !game.isPlaying {
        home
      } else if game.phase == .finished {
        results
      } else {
        gameplay
      }
      if game.paused && game.isPlaying && game.phase != .finished {
        pauseOverlay
      }
    }
    .foregroundStyle(HarborPalette.ink)
    .onReceive(timer) { _ in game.tick(1.0 / 30) }
    .onChange(of: game.cueSerial) {
      if let cue = game.cue {
        feedback.play(cue, audio: game.audioEnabled, haptics: game.hapticsEnabled)
      }
    }
    .onChange(of: scenePhase) {
      if scenePhase != .active && game.isPlaying && game.phase != .finished { game.paused = true }
    }
    .sheet(isPresented: $settingsShown) { settings }
    .sheet(item: $tutorialRequest) { request in tutorial(request) }
    .sheet(item: $sharePayload) { payload in
      NativeShare(payload: payload)
        .presentationDetents([.medium, .large])
    }
    .preferredColorScheme(.light)
  }

  private var home: some View {
    GeometryReader { geometry in
      let contract = Contract.all[selectedContract]
      ScrollView {
        VStack(alignment: .leading, spacing: HarborSpacing.section) {
          HStack(spacing: 12) {
            HarborMark().frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
              Text("Skyhook Salvage").font(HarborType.heading)
              Text("Crane contracts · Port Marlow")
                .font(HarborType.caption).foregroundStyle(HarborPalette.muted)
            }
            Spacer(minLength: 0)
            iconButton("slider.horizontal.3", label: "Settings", id: "settings") {
              settingsShown = true
            }
          }
          GeometryReader { art in
            Image("HarborCover")
              .resizable().scaledToFill()
              .frame(width: art.size.width, height: art.size.height)
              .clipped()
          }
          .frame(height: min(240, max(160, geometry.size.height * 0.30)))
          .allowsHitTesting(false)
          .accessibilityLabel("Illustrated brass airship and rooftop crane above Port Marlow")
          HStack {
            Text("Contract \(selectedContract + 1) of \(Contract.all.count)")
              .font(HarborType.body).fontWeight(.semibold)
            Spacer()
            HStack(spacing: 0) {
              iconButton("chevron.left", label: "Previous contract", id: "previousContract") {
                selectedContract = max(0, selectedContract - 1)
              }.disabled(selectedContract == 0)
              iconButton("chevron.right", label: "Next unlocked contract", id: "nextContract") {
                selectedContract = min(game.unlocked, selectedContract + 1)
              }.disabled(selectedContract >= game.unlocked)
            }
          }
          .padding(.bottom, -HarborSpacing.row)
          VStack(alignment: .leading, spacing: HarborSpacing.row) {
            Text(contract.title).font(HarborType.heading)
            Text(
              "\(contract.cargo.count) cargo · \(Int(contract.seconds)) sec · \(Int(contract.cargo.reduce(0) { $0 + $1.weight })) t total"
            )
            .font(HarborType.caption).foregroundStyle(HarborPalette.muted)
            if geometry.size.height >= 750 {
              VStack(spacing: 0) {
                ForEach(Array(contract.cargo.enumerated()), id: \.offset) { _, cargo in
                  CargoRow(kind: cargo)
                }
              }
            } else {
              HStack(spacing: HarborSpacing.row) {
                ForEach(Array(contract.cargo.enumerated()), id: \.offset) { _, cargo in
                  Image(cargo.assetName).resizable().scaledToFit()
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .accessibilityLabel("\(cargo.title), \(Int(cargo.weight)) tonnes")
                }
              }
              .padding(.vertical, HarborSpacing.row)
              .overlay(alignment: .bottom) {
                Rectangle().fill(HarborPalette.rule).frame(height: 1)
              }
            }
            if selectedContract == game.unlocked && game.unlocked < Contract.all.count - 1 {
              Text("Clear this contract to open the next route.")
                .font(HarborType.caption).foregroundStyle(HarborPalette.muted)
            }
          }
        }
        .padding(.horizontal, HarborSpacing.page)
        .padding(.vertical, HarborSpacing.row)
      }
      .scrollIndicators(.hidden)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        VStack(spacing: 0) {
          primaryButton("Start contract", symbol: "arrow.right", id: "beginSalvage") {
            begin(practice: false)
          }
          HStack {
            Button("Practice dock") { begin(practice: true) }
              .font(HarborType.body).fontWeight(.semibold)
              .frame(minHeight: 44).accessibilityIdentifier("practiceDock")
            Spacer()
            Text("Best \(game.best.formatted())")
              .font(HarborType.caption).monospacedDigit().foregroundStyle(HarborPalette.muted)
          }
        }
        .padding(.horizontal, HarborSpacing.page)
        .padding(.top, HarborSpacing.row)
        .background(HarborPalette.fog)
      }
    }
  }

  private var gameplay: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 4) {
          Text(game.practice ? "Practice dock" : "Contract \(game.contract.id + 1)")
            .font(HarborType.caption).foregroundStyle(HarborPalette.muted)
          Text(game.score.formatted())
            .font(HarborType.readout).monospacedDigit()
            .contentTransition(.numericText())
            .accessibilityLabel("Score \(game.score)")
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 5) {
          Text(game.practice ? "No clock" : "\(Int(ceil(game.timeLeft)))s")
            .font(HarborType.heading).monospacedDigit()
            .foregroundStyle(game.timeLeft < 15 ? HarborPalette.orange : HarborPalette.ink)
          Text(game.practice ? "\(game.losses) missed lifts" : "\(3 - game.losses) misses left")
            .font(HarborType.caption)
            .foregroundStyle(HarborPalette.muted)
        }
        iconButton("pause", label: "Pause game", id: "pauseGame") { game.paused = true }
      }
      .padding(.horizontal, HarborSpacing.page)
      .padding(.vertical, HarborSpacing.row)
      HStack(spacing: 12) {
        Image(game.cargo.assetName).resizable().scaledToFit()
          .frame(width: 40, height: 36).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 3) {
          Text(game.cargo.title).font(HarborType.action)
          Text(
            "\(Int(game.cargo.weight)) t · \(game.stack.count) of \(game.contract.cargo.count) aboard"
          )
          .font(HarborType.caption).foregroundStyle(HarborPalette.muted)
        }
        Spacer()
      }
      .padding(.horizontal, HarborSpacing.page)
      .padding(.vertical, HarborSpacing.row)
      .background(HarborPalette.surface)
      .overlay(alignment: .top) { Rectangle().fill(HarborPalette.rule).frame(height: 1) }
      HarborCanvas(game: game, reducedMotion: reducedMotion)
        .frame(maxHeight: .infinity)
        .clipped()
      VStack(spacing: 4) {
        HStack(spacing: 9) {
          Image(systemName: game.onTarget ? "checkmark.circle.fill" : "scope")
            .font(HarborType.body)
            .foregroundStyle(game.onTarget ? HarborPalette.sage : HarborPalette.orange)
          Text(controlHint)
            .font(HarborType.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 42)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("gameHint")
        }
        HStack(spacing: 12) {
          Button {
            game.shift(-0.25)
          } label: {
            Image(systemName: "arrow.left").frame(width: 44, height: 44)
          }
          .accessibilityLabel("Trim crane left").accessibilityIdentifier("trimLeft")
          CraneTrim(value: $game.trim)
          Button {
            game.shift(0.25)
          } label: {
            Image(systemName: "arrow.right").frame(width: 44, height: 44)
          }
          .accessibilityLabel("Trim crane right").accessibilityIdentifier("trimRight")
        }
        .disabled(!game.actionable)
        primaryButton(
          game.buttonTitle, symbol: game.phase == .release ? "arrow.down.to.line" : "arrow.down",
          id: "craneAction"
        ) { game.act() }
        .disabled(!game.actionable)
      }
      .padding(.horizontal, HarborSpacing.page)
      .padding(.vertical, HarborSpacing.row)
    }
  }

  private var controlHint: String {
    switch game.phase {
    case .pickup:
      return game.onTarget
        ? "Hook aligned. Drop to collect."
        : "Move the hook above the left dock."
    case .release:
      return game.onTarget
        ? "Landing aligned. Release cargo."
        : "Center the guide on the stack below."
    default:
      return game.message
    }
  }

  private var results: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Cargo manifest").font(HarborType.action)
        Spacer()
        iconButton("xmark", label: "Return to harbor", id: "resultsHome") { game.home() }
      }
      .padding(.horizontal, HarborSpacing.page)
      ScrollView {
        ManifestCard(
          won: game.won, practice: game.practice, score: game.score, stack: game.stack,
          title: game.contract.title, reason: game.resultReason, condensed: true
        )
        .padding(HarborSpacing.page)
      }
      .scrollIndicators(.hidden)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        VStack(spacing: 0) {
          primaryButton(
            game.won && !game.practice && game.contract.id < 2 ? "Next contract" : "Try again",
            symbol: game.won && !game.practice && game.contract.id < 2
              ? "arrow.right" : "arrow.counterclockwise",
            id: "replay"
          ) {
            let next = game.won && !game.practice ? min(2, game.contract.id + 1) : game.contract.id
            selectedContract = next
            game.start(contract: next, practice: game.practice)
          }
          Button {
            shareManifest()
          } label: {
            Label("Share cargo manifest", systemImage: "square.and.arrow.up")
              .font(HarborType.body.weight(.semibold))
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .accessibilityIdentifier("shareManifest")
          Text(
            game.practice
              ? "Practice run · best score unchanged" : "Personal best \(game.best.formatted())"
          )
          .font(HarborType.caption).monospacedDigit().foregroundStyle(HarborPalette.muted)
        }
        .padding(.horizontal, HarborSpacing.page)
        .padding(.vertical, HarborSpacing.row)
        .background(HarborPalette.fog)
      }
    }
  }

  private var pauseOverlay: some View {
    ZStack {
      HarborPalette.ink.opacity(0.55).ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: HarborSpacing.section) {
          Text("Crane paused")
            .font(HarborType.title)
          Text("Your crane and harbor clock are paused.")
            .font(HarborType.body)
          primaryButton("Resume salvage", symbol: "play.fill", id: "resume") { game.paused = false }
          Button("Restart contract") {
            game.start(contract: game.contract.id, practice: game.practice)
          }
          .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("restart")
          Button("Return to harbor") { game.home() }
            .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("pauseHome")
        }
        .font(HarborType.action)
        .padding(HarborSpacing.page)
        .background(HarborPalette.surface, in: RoundedRectangle(cornerRadius: 12))
      }
      .fixedSize(horizontal: false, vertical: true)
      .padding(HarborSpacing.page)
    }
    .accessibilityAddTraits(.isModal)
  }

  private var settings: some View {
    NavigationStack {
      Form {
        Section("Sound and touch") {
          Toggle("Harbor sounds", isOn: $game.audioEnabled).accessibilityIdentifier("audioToggle")
          Toggle("Haptic feedback", isOn: $game.hapticsEnabled).accessibilityIdentifier(
            "hapticsToggle")
        }.listRowBackground(HarborPalette.surface)
        Section("Your logbook") {
          LabeledContent("Best manifest", value: game.best.formatted())
          LabeledContent("Contracts cleared", value: "\(game.completed)")
          LabeledContent("Routes unlocked", value: "\(game.unlocked + 1) / 3")
        }.listRowBackground(HarborPalette.surface)
        Section {
          Button("How to salvage") {
            settingsShown = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
              tutorialRequest = TutorialRequest(startsGame: false, practice: false)
            }
          }.accessibilityIdentifier("howToPlay")
        } footer: {
          Text(
            "Progress stays on this iPhone. Motion follows your system accessibility setting."
          )
        }
      }
      .scrollContentBackground(.hidden)
      .background(HarborPalette.fog)
      .tint(HarborPalette.ink)
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { settingsShown = false }.accessibilityIdentifier("settingsDone")
        }
      }
    }
    .presentationDetents([.large])
  }

  private func tutorial(_ request: TutorialRequest) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Your first lift").font(HarborType.title)
        LiftDiagram().aspectRatio(330.0 / 84.0, contentMode: .fit)
        tutorialStep("01", "Catch the treasure", "Tap Drop hook as it swings over the left dock.")
        tutorialStep(
          "02", "Make a soft landing",
          "Wait for the cargo to reach the ship, then release over the stack. The dashed line predicts your landing."
        )
        tutorialStep(
          "03", "Keep your balance",
          "Trim left or right to move the crane. Heavy cargo pulls harder. Keep the deck's bubble near the middle."
        )
        Text("Three missed lifts end a contract. Practice has no clock and unlimited missed lifts.")
          .font(HarborType.caption).foregroundStyle(HarborPalette.muted)
        primaryButton(
          request.startsGame ? "Let's salvage" : "Got it", symbol: "arrow.up.right",
          id: "tutorialContinue"
        ) {
          tutorialSeen = true
          tutorialRequest = nil
          if request.startsGame {
            game.start(contract: selectedContract, practice: request.practice)
          }
        }
      }
      .padding(HarborSpacing.page)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(HarborPalette.fog)
    .presentationDetents([.large])
  }

  private func tutorialStep(_ number: String, _ title: String, _ detail: String) -> some View {
    HStack(alignment: .top, spacing: 17) {
      Text(number).font(HarborType.heading).monospacedDigit().foregroundStyle(HarborPalette.muted)
      VStack(alignment: .leading, spacing: 5) {
        Text(title).font(HarborType.action)
        Text(detail).font(HarborType.body).lineSpacing(2)
      }
    }
  }

  private func begin(practice: Bool) {
    if !tutorialSeen {
      tutorialRequest = TutorialRequest(startsGame: true, practice: practice)
    } else {
      game.start(contract: selectedContract, practice: practice)
    }
  }

  private func shareManifest() {
    let renderer = ImageRenderer(
      content: ManifestCard(
        won: game.won, practice: game.practice, score: game.score, stack: game.stack,
        title: game.contract.title, reason: game.resultReason
      )
      .padding(28)
      .frame(width: 390)
      .background(HarborPalette.cream)
      .environment(\.colorScheme, .light)
    )
    renderer.scale = 3
    if let image = renderer.uiImage {
      sharePayload = SharePayload(
        image: image,
        text:
          "Skyhook Salvage — \(game.score) points, \(game.stack.count) treasures aboard. \(game.contract.title)."
      )
    }
  }
}

struct ManifestCard: View {
  let won: Bool
  let practice: Bool
  let score: Int
  let stack: [StackedCargo]
  let title: String
  let reason: String
  var condensed = false

  var body: some View {
    VStack(alignment: .leading, spacing: HarborSpacing.section) {
      VStack(alignment: .leading, spacing: HarborSpacing.row) {
        Text(won ? (practice ? "Practice complete" : "Contract cleared") : "Contract ended")
          .font(HarborType.title)
          .foregroundStyle(won ? HarborPalette.ink : HarborPalette.orange)
        Text(title).font(HarborType.body)
        Text(won ? "All \(stack.count) cargo safely aboard." : reason)
          .font(HarborType.body).foregroundStyle(HarborPalette.muted)
      }
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 3) {
          Text(score.formatted()).font(HarborType.readout).monospacedDigit()
          Text(practice ? "Practice points" : "Salvage points").font(HarborType.caption)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 3) {
          Text("\(stack.reduce(0) { $0 + Int($1.kind.weight) }) t")
            .font(HarborType.readout).monospacedDigit()
          Text("\(stack.count) cargo aboard").font(HarborType.caption)
        }
      }
      Canvas { context, size in
        let deck = 30.0 + max(100, HarborArt.stackHeight(stack) * 0.72)
        let shipX = 175.0
        let scale = min(size.width / 350, size.height / (deck + 99))
        context.draw(
          Image("HarborBackdrop"), in: CGRect(origin: .zero, size: size))
        context.translateBy(x: (size.width - 350 * scale) / 2, y: 0)
        context.scaleBy(x: scale, y: scale)
        HarborArt.airship(&context, x: shipX, y: deck, clock: 0)
        var cargoY = 0.0
        for item in stack {
          var cargoContext = context
          cargoContext.translateBy(x: shipX, y: deck)
          cargoContext.scaleBy(x: 0.72, y: 0.72)
          cargoY -= item.kind.displayHeight
          HarborArt.cargo(
            &cargoContext, kind: item.kind, x: item.x - DockRules.shipX,
            y: cargoY)
        }
        HarborArt.balanceGauge(&context, x: shipX, y: deck + 16, balance: DockRules.balance(stack))
      }
      .aspectRatio(
        350.0 / (condensed ? 230 : 129 + max(100, HarborArt.stackHeight(stack) * 0.72)),
        contentMode: .fit
      )
      .accessibilityLabel("Cargo tower with \(stack.count) treasures on the Small Wonder")
      VStack(alignment: .leading, spacing: 0) {
        ForEach(stack) { item in
          CargoRow(kind: item.kind)
        }
        if stack.isEmpty {
          Text("No cargo aboard. Try again and catch your first lift.")
            .font(HarborType.body)
        }
      }
      Text("Skyhook Salvage · Port Marlow")
        .font(HarborType.caption).foregroundStyle(HarborPalette.muted)
    }
    .foregroundStyle(HarborPalette.ink)
  }
}

struct CargoRow: View {
  let kind: CargoKind

  var body: some View {
    HStack(spacing: 12) {
      Image(kind.assetName).resizable().scaledToFit()
        .frame(width: 32, height: 28).accessibilityHidden(true)
      Text(kind.title)
      Spacer()
      Text("\(Int(kind.weight)) t").monospacedDigit()
    }
    .font(HarborType.body)
    .padding(.vertical, HarborSpacing.row)
    .overlay(alignment: .bottom) {
      Rectangle().fill(HarborPalette.rule).frame(height: 0.5)
    }
  }
}

struct LiftDiagram: View {
  var body: some View {
    Canvas { context, size in
      let scale = size.width / 330
      context.scaleBy(x: scale, y: scale)
      HarborArt.rounded(
        &context, rect: CGRect(x: 0, y: 0, width: 330, height: 84),
        radius: 2, color: HarborPalette.sky.opacity(0.55))
      HarborArt.cargo(&context, kind: .trunk, x: 53, y: 61 - CargoKind.trunk.displayHeight)
      HarborArt.line(
        &context, from: CGPoint(x: 16, y: 61), to: CGPoint(x: 90, y: 61),
        color: HarborPalette.ink, width: 3)
      HarborArt.cargo(&context, kind: .trunk, x: 166, y: 19)
      HarborArt.line(
        &context, from: CGPoint(x: 166, y: 2), to: CGPoint(x: 166, y: 19),
        color: HarborPalette.ink)
      HarborArt.cargo(&context, kind: .trunk, x: 277, y: 61 - CargoKind.trunk.displayHeight)
      HarborArt.line(
        &context, from: CGPoint(x: 235, y: 61), to: CGPoint(x: 318, y: 61),
        color: HarborPalette.ink, width: 3)
      for x in [107.0, 220.0] {
        HarborArt.label(&context, "→", x: x, y: 40, size: 17)
      }
      HarborArt.label(&context, "Catch", x: 53, y: 74, size: 11)
      HarborArt.label(&context, "Hoist", x: 166, y: 74, size: 11)
      HarborArt.label(&context, "Land", x: 277, y: 74, size: 11)
    }
    .accessibilityLabel("Catch cargo on the left dock, hoist across, then land on the ship")
  }
}

struct NativeShare: UIViewControllerRepresentable {
  let payload: SharePayload
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(
      activityItems: [payload.image, payload.text], applicationActivities: nil)
  }
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

func primaryButton(
  _ title: String, symbol: String, id: String, action: @escaping () -> Void
) -> some View {
  Button(action: action) {
    HStack {
      Text(title)
      Spacer()
      Image(systemName: symbol).font(HarborType.body.weight(.semibold))
    }
    .font(HarborType.action)
    .padding(.horizontal, HarborSpacing.section)
    .padding(.vertical, HarborSpacing.row)
    .frame(maxWidth: .infinity, minHeight: 54)
    .foregroundStyle(HarborPalette.surface)
    .background(HarborPalette.ink, in: RoundedRectangle(cornerRadius: 8))
  }
  .buttonStyle(HarborButtonStyle())
  .accessibilityIdentifier(id)
}

func iconButton(
  _ symbol: String, label: String, id: String, action: @escaping () -> Void
) -> some View {
  Button(action: action) {
    Image(systemName: symbol).font(HarborType.body.weight(.semibold))
      .frame(width: 44, height: 44)
  }
  .buttonStyle(HarborButtonStyle())
  .accessibilityLabel(label)
  .accessibilityIdentifier(id)
}

struct HarborButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  @Environment(\.accessibilityReduceMotion) private var reducedMotion
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
      .scaleEffect(configuration.isPressed && !reducedMotion ? 0.98 : 1)
  }
}

struct HarborMark: View {
  var body: some View {
    Canvas { context, size in
      context.scaleBy(x: size.width / 40, y: size.height / 40)
      context.stroke(
        Path(ellipseIn: CGRect(x: 1, y: 1, width: 38, height: 38)),
        with: .color(HarborPalette.brass), lineWidth: 0.7)
      context.stroke(
        Path(ellipseIn: CGRect(x: 4, y: 4, width: 32, height: 32)),
        with: .color(HarborPalette.brass.opacity(0.4)), lineWidth: 0.5)
      var hook = Path()
      hook.move(to: CGPoint(x: 20, y: 9))
      hook.addLine(to: CGPoint(x: 20, y: 21))
      hook.addCurve(
        to: CGPoint(x: 28, y: 25),
        control1: CGPoint(x: 8, y: 22), control2: CGPoint(x: 20, y: 39))
      context.stroke(
        hook, with: .color(HarborPalette.ink), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
      HarborArt.line(
        &context, from: CGPoint(x: 15, y: 13), to: CGPoint(x: 25, y: 13),
        color: HarborPalette.brass, width: 1)
    }
    .accessibilityHidden(true)
  }
}

struct CraneTrim: View {
  @Binding var value: Double

  var body: some View {
    GeometryReader { geometry in
      let track = max(1, geometry.size.width - 24)
      let position = 12 + (value + 1) / 2 * track
      ZStack(alignment: .leading) {
        Canvas { context, size in
          HarborArt.line(
            &context, from: CGPoint(x: 12, y: 24), to: CGPoint(x: size.width - 12, y: 24),
            color: HarborPalette.brass, width: 1)
          for index in 0...20 {
            let x = 12 + Double(index) / 20 * track
            let height = index % 5 == 0 ? 12.0 : 6.0
            HarborArt.line(
              &context, from: CGPoint(x: x, y: 24 - height / 2),
              to: CGPoint(x: x, y: 24 + height / 2),
              color: HarborPalette.brass.opacity(0.65), width: 0.7)
          }
        }
        Circle().fill(HarborPalette.paper)
          .overlay(Circle().strokeBorder(HarborPalette.brass, lineWidth: 1))
          .overlay(Rectangle().fill(HarborPalette.orange).frame(width: 2, height: 10))
          .frame(width: 24, height: 24)
          .offset(x: position - 12, y: 2)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { drag in value = max(-1, min(1, (drag.location.x - 12) / track * 2 - 1)) })
    }
    .frame(height: 44)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Crane trim")
    .accessibilityIdentifier("craneTrim")
    .accessibilityValue("\(Int(value * 100)) percent")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: value = min(1, value + 0.1)
      case .decrement: value = max(-1, value - 0.1)
      @unknown default: break
      }
    }
  }
}
