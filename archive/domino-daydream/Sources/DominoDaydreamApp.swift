import LinkPresentation
import SwiftUI
import UIKit

@main
struct DominoDaydreamApp: App {
  @StateObject private var store = GameStore()
  var body: some Scene {
    WindowGroup {
      ContentView(store: store)
        .preferredColorScheme(.dark)
    }
  }
}

struct ContentView: View {
  @ObservedObject var store: GameStore
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var playing = false
  @State private var showCollection = false
  @State private var showSettings = false
  @State private var showHelp = false
  @State private var showReset = false
  @State private var sharePayload: SharePayload?
  @State private var shareFailed = false

  var body: some View {
    ZStack {
      WorkshopBackground()
      if playing { game } else { home }
    }
    .tint(Palette.coral)
    .sheet(isPresented: $showCollection) { collection.preferredColorScheme(.light) }
    .sheet(isPresented: $showSettings) { settings.preferredColorScheme(.light) }
    .sheet(isPresented: $showHelp) { instructions.preferredColorScheme(.light) }
    .sheet(item: $sharePayload) { payload in
      ShareSheet(image: payload.image, text: payload.text).preferredColorScheme(.light)
    }
    .alert("Couldn’t create the board image", isPresented: $shareFailed) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Your result is saved. Try Share again.")
    }
    .confirmationDialog(
      "Clear your placed pieces?", isPresented: $showReset, titleVisibility: .visible
    ) {
      Button("Reset board", role: .destructive) { store.reset() }
    } message: {
      Text("Your best score stays safe. You can undo the reset.")
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active {
        store.pause()
        store.save()
      }
    }
  }

  private var home: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 720
      let puzzle = Puzzle.all[store.unlocked]
      VStack(spacing: compact ? 10 : 16) {
        HStack(spacing: 12) {
          DominoMark().frame(width: 25, height: 28).foregroundStyle(Palette.brass)
          Text("Domino Daydream").font(GameType.section)
          Spacer()
          iconButton("slider.horizontal.3", label: "Settings", id: "settings") {
            showSettings = true
          }
        }
        .foregroundStyle(Palette.cream)
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text("World \(puzzle.id + 1) of 8")
            Spacer()
            Text("\(puzzle.targets.count) bells to connect")
          }
          .font(GameType.label).foregroundStyle(Palette.muted)
          Text(puzzle.title).font(GameType.heading).foregroundStyle(Palette.cream)
            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, compact ? 0 : 6)
        TabletopView(
          puzzle: puzzle, pieces: previewPieces(for: puzzle),
          guides: true, labels: false, reduceMotion: reduceMotion, interactive: false
        )
        .frame(maxHeight: .infinity)
        .padding(.horizontal, -GameLayout.inset)
        .accessibilityLabel("Preview of \(puzzle.title), with your saved pieces")
        Text(puzzle.lesson)
          .font(GameType.body).foregroundStyle(Palette.muted)
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
        primaryButton(
          store.progress.drafts[String(puzzle.id)] == nil
            ? "Play world \(puzzle.id + 1)" : "Continue world \(puzzle.id + 1)",
          icon: "arrow.right", id: "begin"
        ) {
          start(store.unlocked)
        }
        VStack(spacing: 0) {
          navigationRow(
            "Choose a world", detail: "\(store.completed) of 8 completed", id: "collection"
          ) {
            showCollection = true
          }
          Rectangle().fill(Palette.separator).frame(height: 0.5)
          navigationRow(
            "Free build", detail: "An open table with unlimited pieces", id: "sandbox"
          ) {
            start(8)
          }
        }
        .padding(.bottom, 4)
      }
      .padding(.horizontal, GameLayout.inset)
    }
  }

  private var game: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 720
      VStack(spacing: 8) {
        HStack(spacing: 10) {
          iconButton("chevron.left", label: "Home", id: "home") {
            store.pause()
            store.save()
            playing = false
          }
          VStack(alignment: .leading, spacing: 3) {
            Text(store.puzzle.sandbox ? "Free build" : "World \(store.puzzle.id + 1) of 8")
              .font(GameType.caption).foregroundStyle(Palette.muted)
            Text(store.puzzle.title).font(GameType.section).foregroundStyle(Palette.cream)
              .lineLimit(2).fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          iconButton("questionmark", label: "How to play", id: "help") {
            store.pause()
            showHelp = true
          }
        }
        .foregroundStyle(Palette.cream)
        .frame(height: 66)
        HStack {
          HStack(spacing: 5) {
            ForEach(0..<store.puzzle.targets.count, id: \.self) { index in
              Image(systemName: index < store.bellsRung ? "bell.fill" : "bell")
                .foregroundStyle(index < store.bellsRung ? Palette.brass : Palette.muted)
            }
            Text("\(store.bellsRung) of \(store.puzzle.targets.count) bells").padding(.leading, 3)
          }
          Spacer()
          if store.best > 0 { Text("Best \(store.best)").monospacedDigit() }
        }
        .font(GameType.label).foregroundStyle(Palette.muted)
        .frame(height: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          "\(store.bellsRung) of \(store.puzzle.targets.count) bells rung. Best score \(store.best)"
        )
        TabletopView(
          puzzle: store.puzzle, pieces: store.allPieces, selected: store.selected,
          result: store.result, beat: store.beat, guides: store.guides,
          reduceMotion: reduceMotion, interactive: store.phase == .editing,
          tap: { cell in
            withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.65)) {
              store.tap(cell)
            }
          }
        )
        .frame(height: max(230, geometry.size.height - (compact ? 370 : 392)))
        .padding(.horizontal, -GameLayout.inset)
        .layoutPriority(1)
        if store.phase == .result {
          resultPanel
        } else if store.phase == .running || store.phase == .paused {
          playbackPanel
        } else {
          editingPanel(compact: compact)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, GameLayout.inset)
      .padding(.bottom, 10)
    }
  }

  private func editingPanel(compact: Bool) -> some View {
    VStack(spacing: compact ? 6 : 10) {
      HStack(alignment: .top, spacing: 8) {
        Text(store.message)
          .font(GameType.label).lineSpacing(2)
          .foregroundStyle(Palette.cream)
          .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("context-message")
      }
      HStack(spacing: 6) {
        ForEach(PieceKind.allCases) { kind in
          Button {
            store.choose(kind)
          } label: {
            VStack(spacing: 3) {
              HStack(alignment: .top, spacing: 5) {
                PieceGlyph(kind: kind).frame(width: 30, height: 24)
                Spacer(minLength: 0)
                Text(store.puzzle.sandbox ? "∞" : "\(store.remaining(kind))")
                  .font(GameType.label).monospacedDigit()
              }
              HStack(spacing: 2) {
                Text(kind.title).font(GameType.label)
                Spacer(minLength: 0)
                if store.tool == kind {
                  Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                }
              }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 60 : 66)
            .foregroundStyle(
              store.tool == kind
                ? Palette.ink : store.remaining(kind) == 0 ? Palette.muted : Palette.cream
            )
            .background(
              store.tool == kind ? Palette.cream : Palette.surface,
              in: RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
            )
          }
          .buttonStyle(.plain)
          .accessibilityLabel(
            "\(kind.title), \(store.puzzle.sandbox ? "unlimited" : "\(store.remaining(kind)) remaining")"
          )
          .accessibilityIdentifier("piece-\(kind.rawValue)")
          .accessibilityAddTraits(store.tool == kind ? .isSelected : [])
        }
      }
      HStack(spacing: 0) {
        toolButton("rotate.right", label: "Rotate", id: "rotate") { store.rotate() }
        toolButton("arrow.uturn.backward", label: "Undo", id: "undo", disabled: !store.canUndo) {
          store.undo()
        }
        toolButton(
          "eraser", label: "Lift", id: "erase",
          disabled: store.selected.flatMap { store.placed[$0] } == nil
        ) { store.erase() }
        toolButton("arrow.counterclockwise", label: "Reset", id: "reset") { showReset = true }
        if !store.puzzle.sandbox {
          toolButton("lightbulb", label: "Hint", id: "hint") { store.hint() }
        }
      }
      primaryButton("Start chain", icon: "play.fill", id: "trigger") { store.trigger() }
    }
  }

  private var playbackPanel: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(store.phase == .paused ? "Chain paused" : "Chain in motion")
        .font(GameType.section).foregroundStyle(Palette.cream)
      ProgressView(value: max(0, store.beat), total: Double(store.totalBeat) + 2)
        .tint(Palette.brass)
      Text(
        store.phase == .paused
          ? "Resume the chain, or return to editing."
          : "Following the route from the trigger to each bell."
      )
      .font(GameType.body).foregroundStyle(Palette.muted)
      HStack {
        secondaryButton("Edit board", icon: "arrow.uturn.backward", id: "edit-running") {
          store.editAgain()
        }
        secondaryButton(
          store.phase == .paused ? "Resume" : "Pause",
          icon: store.phase == .paused ? "play" : "pause", id: "pause"
        ) {
          if store.phase == .paused { store.resume() } else { store.pause() }
        }
      }
    }
    .padding(.vertical, 16)
  }

  private var resultPanel: some View {
    let won = store.result?.won == true
    return VStack(alignment: .leading, spacing: 12) {
      Rectangle().fill(Palette.separator).frame(height: 0.5)
      Label(
        won ? "All bells rung" : "Chain stopped", systemImage: won ? "checkmark" : "stop.circle"
      )
      .font(GameType.section).foregroundStyle(won ? Palette.success : Palette.failure)
      if !won {
        Text(
          store.firstFailure.flatMap { store.result?.failures[$0] }
            ?? "Connect every bell and try again."
        )
        .font(GameType.label).foregroundStyle(Palette.cream)
        .fixedSize(horizontal: false, vertical: true)
      }
      HStack {
        metric("\(store.result?.chainLength ?? 0)", caption: "Dominoes")
        Spacer()
        metric("\(store.currentScore)", caption: "Points")
        Spacer()
        metric(
          "\(store.result?.reached.count ?? 0)/\(store.puzzle.targets.count)", caption: "Bells")
      }
      HStack(spacing: 10) {
        secondaryButton(
          won ? "Replay" : "Edit board", icon: "arrow.uturn.backward", id: "replay"
        ) {
          store.editAgain()
        }
        if won {
          secondaryButton("Share", icon: "square.and.arrow.up", id: "share") {
            share()
          }
          .accessibilityLabel("Share finished board")
          if !store.puzzle.sandbox && store.puzzle.id < 7 {
            Button {
              start(store.puzzle.id + 1)
            } label: {
              Text("Next world")
                .font(GameType.label).frame(width: 105, height: GameLayout.controlHeight)
                .background(
                  Palette.coral, in: RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                )
                .foregroundStyle(Palette.ink)
            }
            .buttonStyle(WorkshopPressStyle())
            .accessibilityIdentifier("next")
          }
        }
      }
    }
    .padding(.top, 4)
    .accessibilityIdentifier(won ? "success-result" : "failure-result")
  }

  private var collection: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text("\(store.completed) of 8 worlds completed")
            .font(.body).foregroundStyle(.secondary).padding(.bottom, 16)
          ForEach(Puzzle.all.filter { !$0.sandbox }) { puzzle in
            let locked = puzzle.id > store.unlocked
            Button {
              showCollection = false
              start(puzzle.id)
            } label: {
              HStack(spacing: 17) {
                Text(String(format: "%02d", puzzle.id + 1))
                  .font(GameType.section).monospacedDigit().foregroundStyle(Palette.ink)
                VStack(alignment: .leading, spacing: 4) {
                  Text(puzzle.title).font(.headline)
                  Text(
                    locked ? "Complete world \(puzzle.id) to unlock" : progressCaption(puzzle)
                  )
                  .font(.subheadline).foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(
                  systemName: locked
                    ? "lock"
                    : store.progress.scores[String(puzzle.id)] == nil
                      ? "chevron.right" : "checkmark")
              }
              .frame(minHeight: 70)
              .foregroundStyle(Palette.ink)
              .padding(.vertical, 8)
            }
            .disabled(locked)
            .accessibilityIdentifier("world-\(puzzle.id)")
            Divider()
          }
        }
        .padding(GameLayout.inset)
      }
      .background(Palette.cream)
      .navigationTitle("Choose a world")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button("Done") { showCollection = false } }
      }
    }
  }

  private var settings: some View {
    NavigationStack {
      Form {
        Section("Sound and display") {
          Toggle("Sound effects", isOn: $store.sound).accessibilityIdentifier("sound-toggle")
          Toggle("Haptic feedback", isOn: $store.haptics).accessibilityIdentifier("haptics-toggle")
          Toggle("Placement guides", isOn: $store.guides).accessibilityIdentifier("guides-toggle")
        }
        Section {
          Text(
            "Scores and unfinished boards are saved on this iPhone."
          )
          Text(
            "Domino Daydream follows your system Reduce Motion preference. Audio and haptics depend on device settings."
          )
        }
        .font(.subheadline)
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button("Done") { showSettings = false } }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private var instructions: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Text("Connect the trigger to every bell.").font(.title3.weight(.semibold))
          Text(
            "Choose a piece from the tray, then tap a dotted socket. Tap it again to select it; Rotate turns its open edges clockwise."
          )
          ForEach(PieceKind.allCases) { kind in
            HStack(alignment: .top, spacing: 16) {
              PieceGlyph(kind: kind).frame(width: 34, height: 30).foregroundStyle(Palette.ink)
              VStack(alignment: .leading, spacing: 5) {
                Text(kind.title).bold()
                Text(pieceHelp(kind)).font(.subheadline).foregroundStyle(.secondary)
              }
            }
          }
          Text(
            "Ring every brass bell in one chain. A closed edge or an empty socket stops that branch. Hints cost 75 points; each retry after the first costs 25. Undo is free."
          )
          .font(.subheadline)
          Text(
            "Need a blueprint? Select a socket and tap Hint. It tells you the piece and how many clockwise quarter turns to make from its tray position."
          )
          .font(.subheadline)
        }
        .padding(GameLayout.inset)
      }
      .foregroundStyle(Palette.ink).background(Palette.cream)
      .navigationTitle("How to play")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Got it") { showHelp = false } } }
    }
  }

  private func pieceHelp(_ kind: PieceKind) -> String {
    switch kind {
    case .straight: "Carries the nudge straight across opposite edges."
    case .turn: "Bends the chain through a right angle."
    case .bridge: "Skips exactly one square. Place on the bank before the blue canal."
    case .fork: "Splits one incoming nudge into two outgoing chains."
    }
  }

  private func progressCaption(_ puzzle: Puzzle) -> String {
    if let score = store.progress.scores[String(puzzle.id)] {
      return "Best \(score) points · all bells rung"
    }
    return "\(puzzle.sockets.count) pieces to place · \(puzzle.targets.count) bells"
  }

  private func previewPieces(for puzzle: Puzzle) -> [Cell: Piece] {
    let draft = store.progress.drafts[String(puzzle.id)]
    let saved = puzzle.sockets.compactMap { cell -> (Cell, Piece)? in
      guard let piece = draft?.placed[cell.id] else { return nil }
      return (cell, piece)
    }
    return puzzle.fixed.merging(Dictionary(uniqueKeysWithValues: saved)) { fixed, _ in fixed }
  }

  private func start(_ index: Int) {
    store.load(index)
    playing = true
  }

  private func share() {
    sharePayload = SharePayload.make(
      puzzle: store.puzzle, pieces: store.allPieces, result: store.result, score: store.currentScore
    )
    shareFailed = sharePayload == nil
  }

  private func metric(_ value: String, caption: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value).font(GameType.number).foregroundStyle(Palette.cream)
      Text(caption).font(GameType.caption).foregroundStyle(Palette.muted)
    }
    .accessibilityElement(children: .combine)
  }

  private func iconButton(_ symbol: String, label: String, id: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 17, weight: .medium)).frame(
        width: 44, height: 44)
    }
    .buttonStyle(.plain).accessibilityLabel(label).accessibilityIdentifier(id)
  }

  private func toolButton(
    _ symbol: String, label: String, id: String, disabled: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Image(systemName: symbol).font(.system(size: 13))
        Text(label).font(GameType.caption)
      }
      .frame(maxWidth: .infinity, minHeight: 44)
      .foregroundStyle(disabled ? Palette.muted.opacity(0.6) : Palette.cream)
    }
    .buttonStyle(WorkshopPressStyle())
    .disabled(disabled).accessibilityLabel(label).accessibilityIdentifier(id)
  }

  private func primaryButton(
    _ title: String, icon: String, id: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Text(title).font(GameType.action)
        Spacer()
        Image(systemName: icon).font(.system(size: 15, weight: .semibold))
      }
      .foregroundStyle(Palette.ink).padding(.horizontal, 16)
      .frame(height: GameLayout.controlHeight)
      .background(
        Palette.coral, in: RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
      )
    }
    .buttonStyle(WorkshopPressStyle()).accessibilityIdentifier(id)
  }

  private func secondaryButton(
    _ title: String, icon: String, id: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: icon)
        .font(GameType.label)
        .frame(maxWidth: .infinity, minHeight: GameLayout.controlHeight)
        .foregroundStyle(Palette.cream)
    }
    .buttonStyle(WorkshopPressStyle()).accessibilityIdentifier(id)
  }

  private func navigationRow(
    _ title: String, detail: String, id: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(GameType.action).foregroundStyle(Palette.cream)
          Text(detail).font(GameType.caption).foregroundStyle(Palette.muted)
        }
        Spacer()
        Image(systemName: "chevron.right").font(GameType.label).foregroundStyle(Palette.muted)
      }
      .frame(minHeight: 62).contentShape(Rectangle())
    }
    .buttonStyle(WorkshopPressStyle()).accessibilityIdentifier(id)
  }
}

struct ResultCard: View {
  let puzzle: Puzzle
  let pieces: [Cell: Piece]
  let result: ChainResult?
  let score: Int
  let artwork: UIImage
  var body: some View {
    ZStack {
      Palette.cream
      VStack(spacing: 12) {
        HStack {
          DominoMark().frame(width: 35, height: 35)
          Spacer()
          Text(
            puzzle.sandbox
              ? "Free build\nFinished route" : "World \(puzzle.id + 1) of 8\nFinished route"
          )
          .font(GameType.label)
          .multilineTextAlignment(.trailing)
        }
        Rectangle().fill(Palette.ink.opacity(0.25)).frame(height: 0.7)
        Text("Domino Daydream").font(GameType.heading)
          .frame(maxWidth: .infinity, alignment: .leading)
        Image(uiImage: artwork).resizable().scaledToFit().frame(width: 510, height: 490)
        Text(puzzle.title).font(GameType.title)
        HStack {
          cardMetric("\(result?.chainLength ?? 0)", label: "Dominoes")
          Spacer()
          cardMetric("\(score)", label: "Points")
          Spacer()
          cardMetric("\(result?.reached.count ?? 0)", label: "Bells rung")
        }
        .padding(.horizontal, 25)
        Rectangle().fill(Palette.ink.opacity(0.25)).frame(height: 0.7)
      }
      .foregroundStyle(Palette.ink)
      .padding(36)
    }
  }

  private func cardMetric(_ value: String, label: String) -> some View {
    VStack(spacing: 3) {
      Text(value).font(GameType.number)
      Text(label).font(GameType.label)
    }
  }
}

struct ShareSheet: UIViewControllerRepresentable {
  let image: UIImage
  let text: String
  func makeUIViewController(context: Context) -> UIActivityViewController {
    let configuration = UIActivityItemsConfiguration(objects: [image])
    let metadata = LPLinkMetadata()
    metadata.title = text
    metadata.imageProvider = NSItemProvider(object: image)
    configuration.metadataProvider = { key in
      switch key {
      case .title, .messageBody: return text
      case .linkPresentationMetadata: return metadata
      default: return nil
      }
    }
    configuration.previewProvider = { _, _, _ in NSItemProvider(object: image) }
    return UIActivityViewController(activityItemsConfiguration: configuration)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct SharePayload: Identifiable {
  let id = UUID()
  let image: UIImage
  let text: String

  @MainActor
  static func make(puzzle: Puzzle, pieces: [Cell: Piece], result: ChainResult?, score: Int)
    -> SharePayload?
  {
    let diorama = Diorama(puzzle: puzzle, labels: false)
    diorama.update(
      pieces: pieces, selected: nil, result: result, beat: 1000,
      guides: false, reduceMotion: true)
    let artwork = diorama.snapshot(size: CGSize(width: 1020, height: 980))
    let renderer = ImageRenderer(
      content: ResultCard(
        puzzle: puzzle, pieces: pieces, result: result, score: score, artwork: artwork
      )
      .frame(width: 600, height: 860))
    renderer.scale = 2
    guard let image = renderer.uiImage else { return nil }
    return SharePayload(
      image: image,
      text:
        "\(puzzle.title): \(result?.chainLength ?? 0) dominoes · \(score) points in Domino Daydream."
    )
  }
}
