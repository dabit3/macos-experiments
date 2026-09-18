import LinkPresentation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
  @StateObject private var game = GameModel()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reducedMotion
  @State private var settings = false
  @State private var sharePayload: SharePayload?
  @State private var shareFailed = false
  private let timer = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        TimelineView(.animation(minimumInterval: reducedMotion ? 1 : 1.0 / 30, paused: game.paused))
        { context in
          PondArt(
            time: context.date.timeIntervalSinceReferenceDate,
            celebration: game.elapsed - game.bloomTime < 4,
            reducedMotion: reducedMotion,
            atmosphereOnly: game.screen == .home || game.screen == .results)
        }
        .ignoresSafeArea()
        if game.screen == .playing || game.screen == .tutorial {
          VStack {
            LinearGradient(
              colors: [Ink.background, Ink.background.opacity(0.95), .clear],
              startPoint: .top, endPoint: .bottom
            )
            .frame(height: 290)
            Spacer()
          }
          .ignoresSafeArea()
          .allowsHitTesting(false)
        }
        switch game.screen {
        case .home: home(compact: geometry.size.height < 720)
        case .playing, .tutorial: playfield(size: geometry.size)
        case .results: results(compact: geometry.size.height < 720)
        }
        if game.paused && (game.screen == .playing || game.screen == .tutorial) { pauseOverlay }
      }
      .foregroundStyle(Ink.pearl)
      .onReceive(timer) { _ in game.tick() }
      .onChange(of: scenePhase) { _, phase in
        if phase != .active { game.pause() }
      }
      .sheet(isPresented: $settings) { settingsView }
      .sheet(item: $sharePayload) { payload in
        ShareSheet(payload: payload)
          .presentationDetents([.medium, .large])
      }
      .alert("Couldn’t prepare your moment", isPresented: $shareFailed) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Please try sharing again.")
      }
    }
  }

  private func home(compact: Bool) -> some View {
    VStack(spacing: 0) {
      HStack {
        RippleSeal()
        Text("SOUND & STILLNESS")
          .font(.system(size: 9, weight: .medium)).tracking(2).foregroundStyle(Ink.muted)
          .padding(.leading, 6)
        Spacer()
        iconButton("slider.horizontal.3", label: "Settings", id: "settings") { settings = true }
      }
      .padding(.top, compact ? 0 : 8)
      VStack(spacing: compact ? 2 : 5) {
        Text("Rippletone").font(Ink.display(compact ? 48 : 62)).tracking(-1.8)
        Text("Touch the water. Wake the music.")
          .font(Ink.italic(compact ? 14 : 16)).foregroundStyle(Ink.muted)
      }
      .padding(.top, compact ? 0 : 14)
      VStack(spacing: 0) {
        pondIllustration
        if !compact {
          Text("A STUDY IN THREE MOVEMENTS")
            .font(.system(size: 8, weight: .medium)).tracking(2.4)
            .foregroundStyle(Ink.muted).padding(.bottom, 12)
        }
      }
      .frame(minHeight: compact ? 100 : 170, maxHeight: .infinity)
      VStack(spacing: 0) {
        HStack(alignment: .firstTextBaseline) {
          Text("The nocturne collection").font(Ink.italic(compact ? 17 : 19))
          Spacer()
          HStack(spacing: 5) {
            ForEach(0..<3) { index in
              Circle().fill(index < game.clearedCount ? Ink.gold : Ink.gold.opacity(0.15))
                .frame(width: 4, height: 4)
            }
            Text("\(game.clearedCount)/3").font(.system(size: 9, design: .monospaced)).padding(
              .leading, 4)
          }
          .foregroundStyle(Ink.gold)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("\(game.clearedCount) of 3 compositions in bloom")
        }
        .padding(.bottom, compact ? 9 : 14)
        Rectangle().fill(Ink.gold.opacity(0.35)).frame(height: 0.5)
        ForEach(Composition.all) { song in
          Button {
            game.start(song)
          } label: {
            HStack(spacing: 13) {
              Text(["I", "II", "III"][song.id]).font(Ink.italic(17))
                .foregroundStyle(Ink.gold).frame(width: 23)
              VStack(alignment: .leading, spacing: 3) {
                Text(song.name).font(Ink.display(compact ? 22 : 25))
                Text(song.tempo).font(.system(size: 9)).tracking(0.8)
                  .foregroundStyle(Ink.muted)
              }
              Spacer()
              VStack(spacing: 4) {
                RhythmSignature(composition: song).frame(width: 39, height: 17)
                if let best = game.bestFor(song.id) {
                  Text("\(best.accuracy)%").font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Ink.muted)
                }
              }
              Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .light))
                .foregroundStyle(Ink.gold).padding(.leading, 8)
            }
            .frame(minHeight: compact ? 56 : 70)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Play \(song.name), \(song.tempo)")
          .accessibilityIdentifier("composition-\(song.id)")
          Rectangle().fill(Ink.jade.opacity(0.17)).frame(height: 0.5)
        }
      }
      Button {
        game.tutorial()
      } label: {
        HStack(spacing: 9) {
          Text("First time?").foregroundStyle(Ink.muted)
          Text("Find your rhythm")
          Image(systemName: "arrow.right").font(.system(size: 10))
        }
        .font(Ink.italic(15)).foregroundStyle(Ink.pearl)
        .frame(maxWidth: .infinity, minHeight: compact ? 44 : 54)
      }
      .accessibilityIdentifier("tutorial")
      HStack(spacing: 6) {
        Circle().fill(Ink.jade).frame(width: 4, height: 4)
        Text(game.forgiving ? "GENTLE TIMING" : "PRECISE TIMING")
        Text("·  HEADPHONES OPTIONAL")
      }
      .font(.system(size: 8, weight: .medium)).tracking(0.9).foregroundStyle(Ink.muted)
      .padding(.bottom, compact ? 8 : 14)
    }
    .padding(.horizontal, compact ? 25 : 31)
  }

  private var pondIllustration: some View {
    TimelineView(.animation(minimumInterval: reducedMotion ? 1 : 1.0 / 30)) { context in
      PondArt(
        time: context.date.timeIntervalSinceReferenceDate, hero: true,
        reducedMotion: reducedMotion, transparent: true)
    }
  }

  private func playfield(size: CGSize) -> some View {
    let tutorial = game.screen == .tutorial
    return VStack(spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 7) {
          eyebrow(
            tutorial ? "THE ART OF LISTENING" : "COMPOSITION 0\(game.engine.composition.id + 1)")
          Text(tutorial ? "Find your rhythm" : game.engine.composition.name)
            .font(Ink.display(32))
        }
        Spacer()
        iconButton("pause", label: "Pause", id: "pause") { game.pause() }
      }
      .padding(.top, 16)
      if !tutorial {
        HStack(alignment: .firstTextBaseline) {
          Text("\(game.engine.combo)").font(Ink.display(43))
            .contentTransition(.numericText())
          eyebrow("COMBO")
          Spacer()
          Text("Notes \(game.engine.judgements.count) / \(game.engine.composition.notes.count)")
            .font(.system(size: 12, design: .monospaced)).foregroundStyle(Ink.muted)
        }
        .padding(.top, 24)
        GeometryReader { proxy in
          Rectangle().fill(Ink.jade.opacity(0.18))
          Rectangle().fill(Ink.gold).frame(
            width: proxy.size.width * min(1, game.elapsed / game.engine.composition.duration))
        }
        .frame(height: 1).padding(.top, 9)
      } else {
        Text(
          game.tutorialStep >= 3
            ? "Three lilies. One quiet moment."
            : "An inner ring grows toward the gold edge.\nTap the lily as the two rings meet."
        )
        .font(.system(size: 15)).foregroundStyle(Ink.muted).lineSpacing(5)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading).padding(.top, 20)
      }
      GeometryReader { field in
        let points = [
          CGPoint(x: field.size.width * 0.25, y: field.size.height * 0.28),
          CGPoint(x: field.size.width * 0.76, y: field.size.height * 0.48),
          CGPoint(x: field.size.width * 0.35, y: field.size.height * 0.77),
        ]
        ZStack {
          ForEach(0..<3) { lane in
            let progress = noteProgress(lane: lane)
            LilyTarget(
              lane: lane, progress: progress, active: progress != nil,
              flash: game.elapsed - game.feedbackTime < 0.45 && game.feedbackLane == lane
                && (game.feedback == "Perfect" || game.feedback == "Lovely"),
              label: progress == nil ? "waiting" : "tap when ring meets edge"
            ) {
              game.tap(lane)
            }
            .position(points[lane])
            if tutorial && game.tutorialStep == lane {
              Text("Tap lily \(["I", "II", "III"][lane])")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Ink.gold)
                .position(x: points[lane].x, y: points[lane].y + 78)
                .allowsHitTesting(false)
            }
            if !tutorial && game.feedbackLane == lane && game.elapsed - game.feedbackTime < 0.9 {
              Text(game.feedback)
                .font(Ink.italic(17))
                .foregroundStyle(game.feedback == "Let it go" ? Ink.peach : Ink.gold)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Ink.background, in: Capsule())
                .position(x: points[lane].x, y: points[lane].y + 76)
                .allowsHitTesting(false)
            }
          }
          if game.elapsed - game.bloomTime < 4 && !tutorial {
            VStack(spacing: 7) {
              eyebrow("PERFECT PHRASE")
              Text("The pond awakens").font(Ink.italic(27))
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
              LinearGradient(
                colors: [Ink.background.opacity(0.96), Ink.background.opacity(0.90), .clear],
                startPoint: .top, endPoint: .bottom)
            )
            .position(x: field.size.width * 0.5, y: field.size.height * 0.06)
            .allowsHitTesting(false)
          }
        }
      }
      VStack(spacing: 12) {
        Text(statusText)
          .font(Ink.italic(25))
          .foregroundStyle(Ink.gold).frame(height: 30)
          .accessibilityIdentifier("timing-feedback")
        if tutorial {
          HStack(spacing: 6) {
            ForEach(0..<3) { index in
              Circle().fill(index < game.tutorialStep ? Ink.gold : Ink.muted.opacity(0.3)).frame(
                width: 5, height: 5)
            }
          }
          if game.tutorialStep >= 3 {
            primaryButton("Play First light", id: "tutorial-play") {
              game.start(Composition.all[0])
            }
          } else {
            Button("Skip practice") { game.start(Composition.all[0]) }
              .font(.system(size: 12)).foregroundStyle(Ink.muted)
              .frame(minHeight: 52).accessibilityIdentifier("tutorial-skip")
          }
        } else {
          eyebrow("TAP AS THE RINGS MEET")
          Text(
            "Bloom: 60% accuracy · catch 70% of notes"
          )
          .font(.system(size: 11)).foregroundStyle(Ink.muted)
        }
      }
      .padding(.bottom, 22)
    }
    .padding(.horizontal, 25)
  }

  private var statusText: String {
    if game.screen == .tutorial {
      if game.tutorialStep >= 3 { return "You’re ready" }
      return "Step \(game.tutorialStep + 1) of 3"
    }
    if game.elapsed < 1.2 { return "Let the water settle" }
    if game.elapsed - game.feedbackTime < 1.2 { return game.feedback }
    if game.elapsed > game.engine.composition.duration - 2 { return "A final ripple…" }
    return "Follow the gold"
  }

  private func noteProgress(lane: Int) -> Double? {
    if game.screen == .tutorial {
      guard game.tutorialStep < 3, lane == game.tutorialStep else { return nil }
      return min(1, game.elapsed / 1.8)
    }
    guard
      let note = game.engine.composition.notes.first(where: {
        $0.lane == lane && game.engine.judgements[$0.id] == nil
          && $0.time - game.elapsed <= game.engine.rules.approachTime
      })
    else { return nil }
    return min(1.1, 1 - (note.time - game.elapsed) / game.engine.rules.approachTime)
  }

  private func results(compact: Bool) -> some View {
    GeometryReader { geometry in
      ScrollView {
        resultContent(compact: compact)
          .frame(minHeight: geometry.size.height)
      }
      .scrollIndicators(.hidden)
    }
  }

  private func resultContent(compact: Bool) -> some View {
    VStack(spacing: 0) {
      HStack {
        eyebrow("A MOMENT, CAPTURED")
        Spacer()
        iconButton("xmark", label: "Return to pond", id: "results-home") { game.screen = .home }
      }
      .padding(.top, 8)
      if let result = game.result {
        VStack(spacing: 8) {
          Text(result.cleared ? "The pond is awake." : "Every ripple teaches.")
            .font(Ink.display(compact ? 31 : 38)).multilineTextAlignment(.center)
          Text("\(game.engine.composition.name)  /  \(result.forgiving ? "Gentle" : "Precise")")
            .font(.system(size: 11)).foregroundStyle(Ink.muted)
        }
        .padding(.top, compact ? 12 : 24)
        pondIllustration.frame(height: compact ? 144 : 255).padding(.vertical, compact ? 4 : 8)
        VStack(spacing: compact ? 13 : 18) {
          eyebrow(result.rank.uppercased())
          HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(result.accuracy)").font(Ink.display(compact ? 67 : 86))
            Text("%").font(Ink.italic(29)).foregroundStyle(Ink.gold)
          }
          .accessibilityElement(children: .ignore).accessibilityLabel(
            "\(result.accuracy) percent accuracy")
          Text("ACCURACY").font(.system(size: 10, weight: .medium)).tracking(1.5)
            .foregroundStyle(Ink.muted).padding(.top, -12)
          HStack {
            stat("\(result.perfect)", "PERFECT")
            Spacer()
            stat("\(result.good)", "LOVELY")
            Spacer()
            stat("\(result.missed)", "MISSED")
            Spacer()
            stat("\(result.maxCombo)", "BEST COMBO")
          }
          .padding(.top, 7)
          Rectangle().fill(Ink.gold.opacity(0.2)).frame(height: 0.5)
          Text(
            result.cleared
              ? "A composition in bloom. Return whenever you need a little quiet."
              : "Bloom with 60% accuracy and 70% of notes caught.\nThe water always gives you another chance."
          )
          .font(Ink.italic(14)).foregroundStyle(Ink.muted).lineSpacing(3).multilineTextAlignment(
            .center)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, compact ? 16 : 24)
        primaryButton(result.cleared ? "Play again" : "Try again", id: "replay") {
          game.start(game.engine.composition)
        }
        HStack {
          Button {
            share()
          } label: {
            Label("Share this moment", systemImage: "square.and.arrow.up")
              .font(.system(size: 12)).frame(maxWidth: .infinity, minHeight: 46)
          }
          .accessibilityIdentifier("share")
          Button {
            game.screen = .home
          } label: {
            Text("Compositions").font(.system(size: 12)).frame(maxWidth: .infinity, minHeight: 46)
          }
          .accessibilityIdentifier("compositions")
        }
        .foregroundStyle(Ink.gold)
      }
    }
    .padding(.horizontal, 23)
    .padding(.bottom, 10)
  }

  private var pauseOverlay: some View {
    ZStack {
      Ink.background.opacity(0.96).ignoresSafeArea()
      VStack(spacing: 25) {
        RippleSeal()
        eyebrow("A BREATH BETWEEN NOTES")
        Text("Still water").font(Ink.display(52))
        Text("Your rhythm will be here.").font(Ink.italic(18)).foregroundStyle(Ink.muted)
        primaryButton("Continue", id: "resume") { game.resume() }
        Button("Start over") {
          if game.screen == .tutorial {
            game.tutorial()
          } else {
            game.start(game.engine.composition)
          }
        }
        .accessibilityIdentifier("restart")
        .frame(minHeight: 44)
        Button("Return to pond") {
          game.paused = false
          game.screen = .home
        }
        .accessibilityIdentifier("pause-home").frame(minHeight: 44)
      }
      .foregroundStyle(Ink.gold).padding(35)
    }
  }

  private var settingsView: some View {
    NavigationStack {
      Form {
        Section("Your pond") {
          Toggle("Original plucked tones", isOn: $game.audio).accessibilityIdentifier(
            "audio-toggle")
          Toggle("Gentle haptics", isOn: $game.haptics).accessibilityIdentifier("haptics-toggle")
        }
        Section {
          Toggle("Gentle timing", isOn: $game.forgiving).accessibilityIdentifier("gentle-toggle")
        } header: {
          Text("Find your pace")
        } footer: {
          Text(
            "Gentle: ±0.85 seconds to catch a note. Precise: ±0.32 seconds. Best performances are saved separately. Four consecutive Perfect notes awaken a school of koi."
          )
        }
        Section("How to bloom") {
          Text(
            "Catch at least 70% of the notes with 60% accuracy. Perfect earns 100, Lovely earns 70, missed notes earn 0. Extra taps earn nothing. Visual rings provide every timing cue; sound is optional."
          )
          .font(.system(size: 14)).foregroundStyle(Ink.muted)
        }
        Section {
          Button("Practice the rings") {
            settings = false
            game.tutorial()
          }
          .accessibilityIdentifier("settings-tutorial")
        }
      }
      .tint(Ink.jade)
      .scrollContentBackground(.hidden)
      .background(Ink.background)
      .navigationTitle("Make it yours")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { settings = false }.accessibilityIdentifier("settings-done")
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  private func eyebrow(_ text: String) -> some View {
    Text(text).font(.system(size: 10, weight: .medium)).tracking(1.4).foregroundStyle(Ink.gold)
  }

  private func stat(_ value: String, _ title: String) -> some View {
    VStack(spacing: 7) {
      Text(value).font(Ink.display(25))
      Text(title).font(.system(size: 8, weight: .medium)).tracking(0.7).foregroundStyle(Ink.muted)
    }
  }

  private func primaryButton(_ title: String, id: String, action: @escaping () -> Void) -> some View
  {
    Button(action: action) {
      HStack {
        Spacer()
        Text(title).font(Ink.display(20))
        Spacer()
        Image(systemName: "arrow.right").font(.system(size: 14))
      }
      .foregroundStyle(Ink.background).padding(.horizontal, 20)
      .frame(minHeight: 52).background(Ink.pearl, in: Capsule())
    }
    .accessibilityIdentifier(id)
  }

  private func iconButton(_ symbol: String, label: String, id: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 16, weight: .light))
        .frame(width: 44, height: 44)
        .overlay(Circle().stroke(Ink.gold.opacity(0.3), lineWidth: 0.5))
    }
    .buttonStyle(.plain).foregroundStyle(Ink.gold)
    .accessibilityLabel(label).accessibilityIdentifier(id)
  }

  private var shareText: String {
    guard let result = game.result else { return "Rippletone — a moonlit rhythm ritual" }
    return
      "A moment on the Rippletone pond: \(result.accuracy)% accuracy, \(result.maxCombo) best combo in \(game.engine.composition.name) (\(result.forgiving ? "Gentle" : "Precise"))."
  }

  @MainActor private func share() {
    guard let result = game.result else { return }
    let renderer = ImageRenderer(
      content: PerformanceArtwork(performance: result, title: game.engine.composition.name))
    renderer.scale = 2
    if let image = renderer.uiImage, let data = image.pngData() {
      sharePayload = SharePayload(
        image: image, png: data,
        title: "Rippletone · \(game.engine.composition.name)",
        message: shareText,
        filename:
          "Rippletone-\(game.engine.composition.name.replacingOccurrences(of: " ", with: "-"))-\(result.forgiving ? "Gentle" : "Precise").png"
      )
    } else {
      shareFailed = true
    }
  }
}

struct PerformanceArtwork: View {
  let performance: Performance
  let title: String
  var body: some View {
    ZStack {
      PondArt(reducedMotion: true, atmosphereOnly: true)
      Rectangle().stroke(Ink.gold.opacity(0.35), lineWidth: 0.5).padding(18)
      VStack(spacing: 0) {
        Text("Rippletone").font(Ink.display(37)).tracking(-0.8)
        Text("A MOMENT ON THE MOONLIT POND").font(.system(size: 8)).tracking(2.2)
          .foregroundStyle(Ink.gold).padding(.top, 10)
        PondArt(hero: true, reducedMotion: true, transparent: true)
          .frame(height: 249).padding(.top, 8)
        Text(performance.rank).font(Ink.italic(28)).padding(.top, 7)
        VStack(spacing: 0) {
          HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(performance.accuracy)").font(Ink.display(80))
            Text("%").font(Ink.italic(30)).foregroundStyle(Ink.gold)
          }
          Text("ACCURACY").font(.system(size: 9, weight: .medium)).tracking(2).foregroundStyle(
            Ink.muted)
        }
        .padding(.top, 8)
        Text("\(title)  ·  \(performance.maxCombo) best combo").font(Ink.display(17)).padding(
          .top, 20)
        Text(performance.forgiving ? "GENTLE TIMING" : "PRECISE TIMING")
          .font(.system(size: 8)).tracking(2).foregroundStyle(Ink.gold).padding(.top, 9)
        HStack(spacing: 15) {
          Rectangle().fill(Ink.gold.opacity(0.3)).frame(width: 35, height: 0.5)
          RippleSeal()
          Rectangle().fill(Ink.gold.opacity(0.3)).frame(width: 35, height: 0.5)
        }.padding(.top, 22)
        Text("Touch the water. Wake the music.").font(Ink.italic(13))
          .foregroundStyle(Ink.muted).padding(.top, 14)
      }
      .padding(.vertical, 38)
    }
    .foregroundStyle(Ink.pearl)
    .frame(width: 400, height: 720)
  }
}

struct SharePayload: Identifiable {
  let id = UUID()
  let image: UIImage
  let png: Data
  let title: String
  let message: String
  let filename: String
}

struct ShareSheet: UIViewControllerRepresentable {
  let payload: SharePayload
  func makeUIViewController(context: Context) -> UIActivityViewController {
    let provider = NSItemProvider()
    provider.suggestedName = payload.filename
    provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all)
    { completion in
      completion(payload.png, nil)
      return nil
    }
    let configuration = UIActivityItemsConfiguration(itemProviders: [provider])
    let metadata = LPLinkMetadata()
    metadata.title = payload.title
    metadata.imageProvider = NSItemProvider(object: payload.image)
    configuration.metadataProvider = { key in
      switch key {
      case .title: return payload.title
      case .messageBody: return payload.message
      case .linkPresentationMetadata: return metadata
      default: return nil
      }
    }
    configuration.perItemMetadataProvider = { _, key in
      key == .linkPresentationMetadata ? metadata : nil
    }
    configuration.previewProvider = { _, _, _ in NSItemProvider(object: payload.image) }
    return UIActivityViewController(activityItemsConfiguration: configuration)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
