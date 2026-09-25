import SwiftUI

@main
struct TinyTectonicsApp: App {
  var body: some Scene {
    WindowGroup {
      ExpeditionView()
        .preferredColorScheme(.dark)
    }
  }
}

private enum Destination {
  case home, atlas, play
}

struct ExpeditionView: View {
  @StateObject private var game = GameStore()
  @State private var destination = Destination.home
  @State private var settings = false
  @State private var restartConfirmation = false
  @State private var shareImage: SharedLandscape?
  @State private var shareFailure = false
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private let clock = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

  var body: some View {
    ZStack {
      GalleryBackground()
      VStack(spacing: 0) {
        switch destination {
        case .home: home
        case .atlas: atlas
        case .play: play
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 10)
      .padding(.bottom, 12)
    }
    .foregroundStyle(Earth.paper)
    .font(.system(.body))
    .buttonStyle(PressedArtifact())
    .tint(Earth.brass)
    .sheet(isPresented: $settings) { settingsSheet }
    .sheet(item: $shareImage) { item in
      NativeShare(landscape: item)
        .presentationDetents([.medium, .large])
    }
    .alert("Could not prepare the landscape card", isPresented: $shareFailure) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Please try sharing again.")
    }
    .confirmationDialog(
      "Reset this landscape?", isPresented: $restartConfirmation, titleVisibility: .visible
    ) {
      Button("Reset landscape", role: .destructive) { game.reset() }
      Button("Keep shaping", role: .cancel) {}
    } message: {
      Text("Your current moves will be cleared. Completed landscapes stay saved.")
    }
    .onReceive(clock) { _ in game.tick(1.0 / 30) }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active, game.phase == .running { game.togglePause() }
    }
  }

  private var home: some View {
    VStack(spacing: 0) {
      HStack {
        ContourEmblem().frame(width: 36, height: 36)
        VStack(alignment: .leading, spacing: 4) {
          eyebrow("THE POCKET WORLD")
          Text("A study in balance")
            .font(.custom("Georgia-Italic", size: 12))
            .foregroundStyle(Earth.brass)
        }
        Spacer()
        iconButton("slider.horizontal.3", label: "Settings", id: "settings") { settings = true }
      }
      VStack(spacing: 7) {
        Text("T I N Y")
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .tracking(5)
          .foregroundStyle(Earth.brass)
        Text("Tectonics")
          .font(.custom("Georgia", size: 53))
          .tracking(-2.5)
          .minimumScaleFactor(0.7)
          .lineLimit(1)
        Text("Small shifts. Extraordinary worlds.")
          .font(.custom("Georgia-Italic", size: 15))
          .foregroundStyle(Earth.muted)
      }
      .padding(.top, 25)
      .frame(maxWidth: .infinity)
      Diorama(
        level: Landscape.all[3], heights: [4, 3, 3, 2, 2, 1, 0], travel: 1.5,
        presentation: true
      )
      .frame(maxHeight: .infinity)
      .padding(.horizontal, -16)
      .accessibilityLabel("A miniature terracotta landscape above a turquoise river")
      VStack(spacing: 16) {
        HStack {
          VStack(alignment: .leading, spacing: 8) {
            eyebrow("YOUR COLLECTION")
            HStack(spacing: 5) {
              ForEach(0..<10) { index in
                Capsule().fill(index < game.completed ? Earth.brass : Earth.paper.opacity(0.14))
                  .frame(width: 14, height: 3)
              }
            }
            .accessibilityHidden(true)
          }
          Spacer()
          Text(String(format: "%02d", game.completed))
            .font(.custom("Georgia", size: 30))
          Text("/ 10").font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Earth.muted).padding(.top, 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(game.completed) of 10 landscapes restored")
        primaryButton(
          game.completed == 0 ? "Begin expedition" : "Continue expedition", symbol: "arrow.right",
          id: "begin"
        ) {
          game.load(game.unlocked)
          destination = .play
        }
        Button {
          destination = .atlas
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "square.grid.2x2").foregroundStyle(Earth.brass)
            Text("Explore the collection")
          }
          .font(.system(size: 13, weight: .medium))
          .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityIdentifier("collection")
      }
    }
  }

  private var atlas: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        iconButton("arrow.left", label: "Back to home", id: "back-home") { destination = .home }
        Spacer()
        eyebrow("\(game.completed) / 10 RESTORED")
      }
      Text("Collected worlds.").font(.custom("Georgia", size: 32))
      Text("Ten landscapes. One gentle descent.")
        .font(.system(size: 15))
        .foregroundStyle(Earth.muted)
      ScrollView {
        VStack(spacing: 0) {
          ForEach(Landscape.all) { level in
            let accessible = level.id <= game.unlocked
            Button {
              game.load(level.id)
              destination = .play
            } label: {
              HStack(spacing: 12) {
                Diorama(level: level, heights: level.initial, presentation: true)
                  .frame(width: 98, height: 105)
                  .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 8) {
                  Text(String(format: "LANDSCAPE %02d", level.id + 1))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.5).foregroundStyle(Earth.brass)
                  Text(level.name).font(.custom("Georgia", size: 19))
                    .multilineTextAlignment(.leading)
                  Text(level.region).font(.system(size: 9, weight: .medium)).tracking(1.1)
                    .foregroundStyle(Earth.muted)
                  if let stars = game.best["\(level.id)"] {
                    HStack(spacing: 4) {
                      ForEach(0..<3) { index in
                        Image(systemName: "diamond.fill")
                          .foregroundStyle(index < stars ? Earth.brass : Earth.muted.opacity(0.3))
                      }
                    }
                    .font(.system(size: 7))
                  }
                }
                Spacer()
                Image(systemName: accessible ? "arrow.up.right" : "lock")
                  .font(.system(size: 13, weight: .light)).foregroundStyle(Earth.brass)
              }
              .padding(.vertical, 12)
              .contentShape(Rectangle())
            }
            .disabled(!accessible)
            .opacity(accessible ? 1 : 0.6)
            .accessibilityLabel(
              "\(level.name), \(accessible ? "play landscape" : "locked, complete previous landscape")"
            )
            .accessibilityIdentifier("landscape-\(level.id + 1)")
            Rectangle().fill(Earth.brass.opacity(0.17)).frame(height: 1)
          }
        }
      }
      .scrollIndicators(.hidden)
    }
  }

  private var play: some View {
    VStack(spacing: 0) {
      HStack {
        iconButton("arrow.left", label: "Leave puzzle for collection", id: "leave-puzzle") {
          if game.phase == .running { game.togglePause() }
          destination = .atlas
        }
        Spacer()
        VStack(spacing: 3) {
          eyebrow("TINY TECTONICS")
          Text(game.level.region)
            .font(.system(size: 9, design: .monospaced)).tracking(1.2)
            .foregroundStyle(Earth.brass)
        }
        Spacer()
        iconButton("slider.horizontal.3", label: "Settings", id: "settings") {
          if game.phase == .running { game.togglePause() }
          settings = true
        }
      }
      .padding(.bottom, 12)
      HStack(alignment: .firstTextBaseline) {
        Text(game.level.name)
          .font(.custom("Georgia", size: 31))
          .minimumScaleFactor(0.7)
          .lineLimit(1)
        Spacer(minLength: 8)
        Text(String(format: "%02d", game.levelIndex + 1))
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .foregroundStyle(Earth.brass)
          .padding(10)
          .overlay(Circle().strokeBorder(Earth.brass.opacity(0.35), lineWidth: 1))
      }
      .padding(.bottom, 7)
      HStack {
        HStack(spacing: 7) {
          ForEach(0..<game.level.budget, id: \.self) { index in
            RoundedRectangle(cornerRadius: 1)
              .fill(index < game.remaining ? Earth.brass : Earth.paper.opacity(0.12))
              .frame(width: 4, height: 12)
          }
          Text("\(game.remaining) moves left").padding(.leading, 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(game.remaining) moves left")
        Spacer()
        Label("\(game.collected) / \(game.level.fossils.count) amber", systemImage: "diamond")
      }
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(Earth.muted)
      .padding(.bottom, 14)
      Rectangle().fill(Earth.brass.opacity(0.24)).frame(height: 1)

      if game.phase == .won {
        success
      } else {
        Text(instruction)
          .font(.system(size: 13, weight: .regular))
          .foregroundStyle(Earth.muted)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity, minHeight: 46)
          .padding(.top, 6)
        Diorama(
          level: game.level, heights: game.heights,
          selected: game.phase == .editing ? game.selected : nil,
          travel: game.travel, running: game.phase != .editing,
          onSelect: game.phase == .editing
            ? { index in
              game.selected = index
              game.feedback()
            } : nil
        )
        .frame(maxHeight: .infinity)
        .padding(.horizontal, -22)
        if game.phase == .failed {
          failure
        } else if game.phase == .editing {
          editor
        } else {
          simulationControls
        }
      }
    }
  }

  private var instruction: String {
    if game.phase == .failed { return "Every landscape takes a little practice." }
    if game.phase == .paused { return "Expedition paused. Your explorer is safe." }
    if game.phase == .running { return "Following gravity. Collecting little treasures." }
    if game.levelIndex == 0, game.moves == 0 {
      return "Start here: lift plate 2 once.\nThe explorer rolls level or down one layer."
    }
    if game.remaining == 0 { return "No moves left. Try your route, or undo a shift." }
    return "Tap a plate, then lift or lower.\nKeep each step level or one layer down."
  }

  private var editor: some View {
    VStack(spacing: 12) {
      HStack(spacing: 5) {
        Image(systemName: "circle.fill").font(.system(size: 5))
        Text("IVORY EXPLORER")
        Spacer()
        Image(systemName: "diamond.fill").foregroundStyle(Earth.gold)
        Text("AMBER")
        Spacer()
        Image(systemName: "circle").foregroundStyle(Earth.teal)
        Text("EXIT")
      }
      .font(.system(size: 10, weight: .medium, design: .monospaced))
      .tracking(0.3)
      .foregroundStyle(Earth.paper.opacity(0.8))
      .padding(.horizontal, 8)
      .padding(.bottom, 2)
      HStack(spacing: 12) {
        adjustButton(delta: -1)
        VStack(spacing: 6) {
          Text("PLATE \(String(format: "%02d", game.selected + 1))")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(1.4).foregroundStyle(Earth.muted)
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(game.heights[game.selected])")
              .font(.custom("Georgia", size: 31))
              .contentTransition(.numericText())
            Text(game.level.fixed.contains(game.selected) ? "anchored" : "elevation")
              .font(.system(size: 12)).foregroundStyle(Earth.paper.opacity(0.8))
          }
          HStack(spacing: 4) {
            ForEach(0...5, id: \.self) { height in
              Capsule()
                .fill(
                  height <= game.heights[game.selected] ? Earth.teal : Earth.paper.opacity(0.12)
                )
                .frame(width: 10, height: 2)
            }
          }
          .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        adjustButton(delta: 1)
      }
      .padding(.vertical, 15)
      .padding(.horizontal, 12)
      .modifier(InstrumentSurface())
      HStack(spacing: 12) {
        iconButton("arrow.uturn.backward", label: "Undo last terrain shift", id: "undo") {
          withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { game.undo() }
        }
        .disabled(!game.canUndo)
        .opacity(game.canUndo ? 1 : 0.35)
        primaryButton("Let it roll", symbol: "play.fill", id: "simulate") { game.simulate() }
        iconButton("arrow.counterclockwise", label: "Reset landscape", id: "reset") {
          restartConfirmation = true
        }
      }
      Text(
        "Best route: \(game.level.par) \(game.level.par == 1 ? "shift" : "shifts") · Ends are anchored"
      )
      .font(.system(size: 11, weight: .regular))
      .foregroundStyle(Earth.muted)
    }
  }

  private var simulationControls: some View {
    VStack(spacing: 15) {
      HStack {
        eyebrow(game.phase == .paused ? "PAUSED" : "THE EXPLORER IS ON ITS WAY")
        Spacer()
        Text("\(min(Int(game.travel) + 1, game.heights.count)) / \(game.heights.count)")
          .font(.system(size: 13, weight: .medium, design: .monospaced))
      }
      ProgressView(
        value: min(game.travel, Double(game.heights.count - 1)),
        total: Double(game.heights.count - 1)
      )
      .tint(Earth.teal)
      primaryButton(
        game.phase == .paused ? "Resume journey" : "Pause journey",
        symbol: game.phase == .paused ? "play.fill" : "pause.fill", id: "pause-resume"
      ) {
        game.togglePause()
      }
      Button("Return to shaping") { game.editAgain() }
        .font(.system(size: 14, weight: .semibold))
        .frame(minHeight: 44)
        .accessibilityIdentifier("return-to-shaping")
    }
    .padding(.bottom, 12)
  }

  private var failure: some View {
    VStack(spacing: 12) {
      Text(game.outcome.fault?.title ?? "Try another route.")
        .font(.custom("Georgia", size: 28))
      Text("Between plates \(game.outcome.reached + 1) and \(game.outcome.reached + 2)")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Earth.copper)
      Text(game.outcome.fault?.explanation ?? "")
        .font(.system(size: 14))
        .multilineTextAlignment(.center)
        .foregroundStyle(Earth.muted)
        .fixedSize(horizontal: false, vertical: true)
      primaryButton("Keep shaping", symbol: "arrow.uturn.backward", id: "retry") {
        game.editAgain()
      }
      Button("Reset landscape") { game.reset() }
        .font(.system(size: 13, weight: .semibold))
        .frame(minHeight: 44)
        .accessibilityIdentifier("failure-reset")
    }
  }

  private var success: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Image(systemName: "checkmark.seal").foregroundStyle(Earth.brass)
        eyebrow("ADDED TO YOUR COLLECTION")
      }
      .padding(.top, 22)
      Diorama(
        level: game.level, heights: game.heights, travel: Double(game.heights.count - 1),
        running: true, celebration: true, presentation: true
      )
      .frame(maxHeight: .infinity)
      .padding(.horizontal, -10)
      VStack(spacing: 10) {
        HStack(spacing: 12) {
          ForEach(0..<3) { index in
            Medal(filled: index < game.stars)
              .offset(y: index == 1 ? -5 : 0)
          }
        }
        .accessibilityLabel("\(game.stars) of 3 stars")
        Text(game.levelIndex == 9 ? "A world in balance." : "Beautifully balanced.")
          .font(.custom("Georgia-Italic", size: 28))
          .minimumScaleFactor(0.7)
          .lineLimit(1)
        Text(
          "\(game.moves) \(game.moves == 1 ? "shift" : "shifts")  ·  \(game.level.fossils.count) amber found  ·  \(game.stars == 3 ? "Perfect route" : "Landscape saved")"
        )
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Earth.brass)
        .padding(.bottom, 10)
        primaryButton(
          game.levelIndex == 9 ? "View your collection" : "Next landscape", symbol: "arrow.right",
          id: "next-landscape"
        ) {
          if game.levelIndex == 9 { destination = .atlas } else { game.load(game.levelIndex + 1) }
        }
        HStack(spacing: 12) {
          Button {
            game.reset()
          } label: {
            Label("Play again", systemImage: "arrow.counterclockwise")
              .frame(maxWidth: .infinity, minHeight: 48)
          }
          .accessibilityIdentifier("play-again")
          Button {
            share()
          } label: {
            Label("Share landscape", systemImage: "square.and.arrow.up")
              .frame(maxWidth: .infinity, minHeight: 48)
          }
          .accessibilityIdentifier("share-landscape")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Earth.muted)
      }
    }
  }

  private var settingsSheet: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          ContourEmblem().frame(width: 58, height: 46)
          Text("A quieter kind of play.")
            .font(.custom("Georgia", size: 29))
          Toggle("Haptic feedback", isOn: $game.haptics)
            .tint(Earth.teal)
            .accessibilityIdentifier("haptics")
          Divider()
          Text("HOW THE WORLD WORKS").font(.system(size: 11, weight: .bold)).tracking(1.5)
          Text(
            "Tap a numbered plate. Lift or lower it one layer at a time. The ivory explorer rolls forward along the pale trail, on level ground or down a single layer."
          )
          Text(
            "Dotted copper links mark unsafe slopes. Anchored plates cannot move. Undo returns a move; retrying a simulation costs nothing."
          )
          Text(
            "Restore a landscape within its move limit to unlock the next. Match the best route for three stars. Your collection saves on this iPhone."
          )
          Spacer()
          Text(
            "No audio. Just a little space to think.\nFollows your iPhone’s Reduce Motion setting."
          )
          .font(.system(size: 12))
          .foregroundStyle(Earth.muted)
        }
        .padding(26)
      }
      .font(.system(size: 15))
      .foregroundStyle(Earth.paper)
      .background(GalleryBackground())
      .navigationTitle("Field guide")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { settings = false }.accessibilityIdentifier("settings-done")
        }
      }
    }
  }

  private func share() {
    let renderer = ImageRenderer(
      content: LandscapeCard(
        level: game.level, heights: game.heights, moves: game.moves, stars: game.stars))
    renderer.scale = 2
    if let image = renderer.uiImage {
      do {
        shareImage = try SharedLandscape(image: image, title: game.level.name)
      } catch {
        shareFailure = true
      }
    } else {
      shareFailure = true
    }
  }

  private func adjustButton(delta: Int) -> some View {
    Button {
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { game.adjust(delta) }
    } label: {
      VStack(spacing: 6) {
        Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
          .font(.system(size: 21, weight: .light))
        Text(delta > 0 ? "LIFT" : "LOWER")
          .font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(0.8)
      }
      .frame(width: 65, height: 70)
      .background(
        LinearGradient(
          colors: [Earth.paper.opacity(0.08), Earth.paper.opacity(0.01)],
          startPoint: .topLeading, endPoint: .bottomTrailing),
        in: RoundedRectangle(cornerRadius: 16)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .strokeBorder(Earth.brass.opacity(game.canAdjust(delta) ? 0.3 : 0.06), lineWidth: 1)
      )
      .foregroundStyle(game.canAdjust(delta) ? Earth.brass : Earth.muted.opacity(0.3))
    }
    .disabled(!game.canAdjust(delta))
    .accessibilityLabel(
      delta > 0 ? "Lift selected plate one layer" : "Lower selected plate one layer"
    )
    .accessibilityIdentifier(delta > 0 ? "lift" : "lower")
  }

  private func iconButton(_ symbol: String, label: String, id: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 16, weight: .regular))
        .frame(width: 44, height: 44)
        .background(Earth.paper.opacity(0.035), in: Circle())
        .overlay(Circle().strokeBorder(Earth.paper.opacity(0.09), lineWidth: 1))
        .contentShape(Circle())
    }
    .accessibilityLabel(label)
    .accessibilityIdentifier(id)
  }

  private func primaryButton(
    _ title: String, symbol: String, id: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        Text(title).font(.system(size: 15, weight: .semibold))
        Spacer()
        Rectangle().fill(Earth.ink.opacity(0.2)).frame(width: 1, height: 20)
          .padding(.horizontal, 10)
        Image(systemName: symbol).font(.system(size: 14, weight: .medium))
      }
      .padding(.horizontal, 22)
      .frame(maxWidth: .infinity, minHeight: 57)
      .background(
        LinearGradient(
          colors: [Color(hex: 0xE8CCA0), Earth.brass, Color(hex: 0xBC945E)],
          startPoint: .topLeading, endPoint: .bottomTrailing),
        in: RoundedRectangle(cornerRadius: 16)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .strokeBorder(Earth.paper.opacity(0.5), lineWidth: 1)
      )
      .foregroundStyle(Earth.ink)
      .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }
    .accessibilityIdentifier(id)
  }

  private func eyebrow(_ title: String) -> some View {
    Text(title).font(.system(size: 9, weight: .medium, design: .monospaced))
      .tracking(1.4).foregroundStyle(Earth.muted)
  }
}
