import SwiftUI
import UIKit

struct GameView: View {
  let puzzle: Puzzle
  @EnvironmentObject private var progress: Progress
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var parade: Parade
  @State private var paused = false
  @State private var tangled = false
  @State private var tutorial = false
  @State private var showingHint = false
  @State private var hintTask: Task<Void, Never>?
  @State private var lastTouched: Tile?
  @State private var notice = "Start at the flag. Follow the street lights."
  @State private var celebrationStart: Date?
  @State private var showingResult = false
  @State private var showClearConfirmation = false

  init(puzzle: Puzzle, restored: Parade?) {
    self.puzzle = puzzle
    _parade = State(initialValue: restored ?? Parade(puzzle: puzzle))
    if let restored, restored.route.count > 1 {
      _notice = State(initialValue: "Welcome back. Continue from the end of your ribbon.")
    }
  }

  private var colors: [LanternColor] { parade.collected(in: puzzle) }
  private var nextSteps: Set<Tile> {
    guard let head = parade.route.last, !parade.completed else { return [] }
    return Set(
      [
        Tile(x: head.x - 1, y: head.y), Tile(x: head.x + 1, y: head.y),
        Tile(x: head.x, y: head.y - 1), Tile(x: head.x, y: head.y + 1),
      ].filter {
        (0..<puzzle.size).contains($0.x) && (0..<puzzle.size).contains($0.y)
          && !parade.route.contains($0) && parade.rejection(for: $0, in: puzzle) == nil
      })
  }
  private var chapter: String {
    if puzzle.id.hasPrefix("daily") { return "Daily light · \(String(puzzle.id.dropFirst(6)))" }
    return
      "Town \(String(format: "%02d", (Towns.all.firstIndex { $0.id == puzzle.id } ?? 0) + 1)) of 12"
  }

  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 720
      ZStack {
        NightBackground()
        VStack(spacing: 0) {
          header
          ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
              VStack(spacing: 4) {
                Text(puzzle.title).font(TypeStyle.title(compact ? 36 : 44))
                  .foregroundStyle(Ink.cream).minimumScaleFactor(0.7).lineLimit(1)
                if !compact {
                  Text(puzzle.subtitle).font(TypeStyle.italic(16)).foregroundStyle(Ink.muted)
                }
              }.padding(.top, compact ? 8 : 18)
              collectionRow.padding(.top, compact ? 12 : 18)
              playableMap
                .frame(
                  width: min(geometry.size.width - 24, max(280, geometry.size.height * 0.45), 440)
                )
                .padding(.horizontal, -12)
                .padding(.top, compact ? 8 : 18)
              HStack(spacing: 7) {
                Image(
                  systemName: parade.completed
                    ? "sparkles" : "point.topleft.down.to.point.bottomright.curvepath"
                )
                .foregroundStyle(Ink.gold)
                Text(parade.completed ? "The town is coming to life…" : notice)
                  .foregroundStyle(Ink.cream)
              }
              .font(.system(size: 13)).multilineTextAlignment(.center)
              .frame(minHeight: compact ? 36 : 44)
              .accessibilityIdentifier("route-notice")
              .padding(.horizontal, 4).padding(.top, 8)
              HStack {
                Text("\(parade.route.count - 1)  STEPS")
                Spacer()
                Text("PAR  \(puzzle.par)")
              }.font(.system(size: 11, weight: .medium)).tracking(1).foregroundStyle(Ink.muted)
                .padding(.top, compact ? 2 : 8)
              FestivalRule().padding(.top, compact ? 8 : 14)
              if parade.completed {
                Label("The procession is on its way", systemImage: "sparkles")
                  .font(TypeStyle.italic(18)).foregroundStyle(Ink.gold).frame(
                    height: 54)
              } else {
                controls
              }
              HStack(spacing: 16) {
                Label("Start", systemImage: "flag.fill")
                Label("Gate", systemImage: "door.left.hand.closed")
                Label("Square", systemImage: "sparkles")
              }.font(.system(size: 10)).foregroundStyle(Ink.muted)
                .padding(.top, compact ? 10 : 18).padding(.bottom, compact ? 10 : 22)
            }.padding(.horizontal, 24)
          }.clipped()
        }.accessibilityHidden(tutorial || paused || tangled || showingResult)
        if tutorial { tutorialOverlay }
        if paused { pauseOverlay }
        if tangled { tangleOverlay }
        if showingResult {
          ResultView(puzzle: puzzle, parade: parade, replay: reset, home: { dismiss() })
            .transition(.opacity)
        }
      }
    }
    .onAppear {
      tutorial = !progress.hasLearned
      progress.save(parade)
      if parade.completed { showingResult = true }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active {
        progress.save(parade)
        if !parade.completed && !tutorial { paused = true }
      }
    }
    .onDisappear { hintTask?.cancel() }
    .confirmationDialog(
      "Clear this ribbon and begin again?", isPresented: $showClearConfirmation,
      titleVisibility: .visible
    ) {
      Button("Clear route", role: .destructive) { reset() }
    }
  }

  private var header: some View {
    HStack {
      Button {
        paused = true
      } label: {
        Image(systemName: "pause").font(.system(size: 16, weight: .light)).frame(
          width: 44, height: 44)
      }.accessibilityLabel("Pause parade").accessibilityIdentifier("pause")
      Spacer()
      Eyebrow(text: chapter)
      Spacer()
      Button {
        tutorial = true
      } label: {
        Image(systemName: "questionmark").font(TypeStyle.italic(22)).frame(width: 44, height: 44)
      }.accessibilityLabel("How to play").accessibilityIdentifier("help")
    }.padding(.horizontal, 24).padding(.top, 8)
  }

  private var collectionRow: some View {
    HStack(spacing: 0) {
      ForEach(LanternColor.allCases, id: \.rawValue) { color in
        HStack(spacing: 4) {
          ZStack {
            PaperLantern(color: color.ink, size: 18)
              .opacity(colors.contains(color) || colors.count == color.rawValue ? 1 : 0.4)
            Text(colors.contains(color) ? "✓" : "\(color.rawValue + 1)")
              .font(.system(size: 9, weight: .semibold)).foregroundStyle(Ink.night)
          }
          VStack(alignment: .leading, spacing: 2) {
            Text(color.name).font(TypeStyle.title(18))
              .foregroundStyle(Ink.cream)
            Text(
              colors.contains(color)
                ? "COLLECTED" : (colors.count == color.rawValue ? "NEXT LIGHT" : "THEN")
            )
            .font(.system(size: 10, weight: .medium)).tracking(0.4).foregroundStyle(
              colors.count == color.rawValue ? Ink.gold : Ink.muted)
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityElement(children: .combine)
      }
    }
  }

  private var playableMap: some View {
    GeometryReader { geometry in
      let geo = BoardGeometry(side: geometry.size.width, count: puzzle.size)
      ZStack {
        TimelineView(
          .animation(
            minimumInterval: 1.0 / 30,
            paused: celebrationStart == nil || reduceMotion || showingResult)
        ) { timeline in
          let elapsed = celebrationStart.map { timeline.date.timeIntervalSince($0) } ?? 0
          TownMap(
            puzzle: puzzle, route: parade.route, celebrating: parade.completed,
            procession: reduceMotion ? 1 : min(elapsed / 3.8, 1), hint: showingHint,
            nextSteps: nextSteps
          )
          .onChange(of: elapsed > 4.8) { _, done in
            if done { withAnimation { showingResult = true } }
          }
        }
        ForEach(0..<puzzle.size * puzzle.size, id: \.self) { index in
          let tile = Tile(x: index % puzzle.size, y: index / puzzle.size)
          if !puzzle.blocked.contains(tile) {
            Button {
              move(tile)
            } label: {
              Color.clear.contentShape(Rectangle())
            }
            .frame(
              width: max(44, min(geo.step * 0.85, 52)), height: max(44, min(geo.step * 0.85, 52))
            )
            .position(geo.point(tile))
            .accessibilityLabel(tileLabel(tile))
            .accessibilityIdentifier("tile-\(tile.x)-\(tile.y)")
            .disabled(paused || tutorial || tangled || parade.completed)
          }
        }
      }
      .highPriorityGesture(
        DragGesture(minimumDistance: 8)
          .onChanged { value in
            guard let tile = geo.tile(at: value.location), tile != lastTouched else { return }
            lastTouched = tile
            move(tile)
          }
          .onEnded { _ in lastTouched = nil }
      )
    }.aspectRatio(1, contentMode: .fit)
  }

  private var controls: some View {
    HStack(spacing: 10) {
      Button {
        parade.undo()
        notice = "One step back. Your ribbon is still together."
        progress.save(parade)
        progress.feedback()
      } label: {
        Label("Undo", systemImage: "arrow.uturn.backward")
      }.buttonStyle(GoldButtonStyle(secondary: true))
        .disabled(parade.route.count <= 1 || parade.completed)
        .accessibilityIdentifier("undo")
      Button {
        showClearConfirmation = true
      } label: {
        Label("Clear", systemImage: "arrow.counterclockwise")
      }.buttonStyle(GoldButtonStyle(secondary: true)).disabled(parade.completed)
        .accessibilityIdentifier("clear")
      Button {
        guard !showingHint else { return }
        parade.hints += 1
        showingHint = true
        notice = "A possible route, traced in starlight."
        progress.save(parade)
        hintTask?.cancel()
        hintTask = Task { @MainActor in
          try? await Task.sleep(for: .seconds(5))
          guard !Task.isCancelled else { return }
          showingHint = false
          if notice == "A possible route, traced in starlight." {
            notice =
              colors.count == 3
              ? "All three lights! Lead them to the festival square."
              : "Collect \(LanternColor.allCases[colors.count].name) next. Follow the glowing junctions."
          }
        }
      } label: {
        Label("Guide", systemImage: "lightbulb")
      }.buttonStyle(GoldButtonStyle(secondary: true)).disabled(parade.completed || showingHint)
        .accessibilityIdentifier("guide")
    }
  }

  private func tileLabel(_ tile: Tile) -> String {
    let prefix = "Street \(tile.x + 1), \(tile.y + 1)"
    if tile == puzzle.start { return "\(prefix), start flag" }
    if tile == puzzle.finish { return "\(prefix), festival square" }
    if let color = puzzle.lanterns[tile] {
      return "\(prefix), \(color.name) lantern, number \(color.rawValue + 1)"
    }
    if let color = puzzle.gates[tile] { return "\(prefix), \(color.name) gate" }
    if tile == parade.route.last { return "\(prefix), parade head" }
    if parade.route.contains(tile) { return "\(prefix), ribbon already here" }
    return prefix
  }

  private func move(_ tile: Tile) {
    guard !paused, !tutorial, !tangled, !showingResult else { return }
    let outcome = parade.move(to: tile, in: puzzle)
    switch outcome {
    case .ignored: return
    case .tangled:
      tangled = true
    case .rejected(let message):
      notice = message
    case .moved:
      progress.feedback()
      if let color = puzzle.lanterns[tile] {
        notice =
          "\(color.name) joins! \(colors.count == 3 ? "Bring every light to the square." : "The \(color.name) gate is open.")"
      } else if let color = puzzle.gates[tile] {
        notice = "Through the \(color.name) gate. The parade stays together."
      } else if colors.count == 3 {
        notice = "All three lights! Lead them to the festival square."
      } else {
        notice =
          "Collect \(LanternColor.allCases[colors.count].name) next. Gates open with matching light."
      }
    case .completed:
      showingHint = false
      celebrationStart = Date()
      progress.complete(parade, puzzle: puzzle)
      progress.feedback(success: true)
      if reduceMotion { showingResult = true }
    }
    progress.save(parade)
  }

  private func reset() {
    hintTask?.cancel()
    parade = Parade(puzzle: puzzle)
    paused = false
    tangled = false
    showingResult = false
    showingHint = false
    celebrationStart = nil
    lastTouched = nil
    notice = "A fresh ribbon. Start at the flag."
    progress.save(parade)
  }

  private func overlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    ZStack {
      Ink.night.opacity(0.85).ignoresSafeArea()
      VStack(spacing: 18, content: content)
        .padding(28).frame(maxWidth: 360)
        .background(Ink.panel, in: FestivalTicket())
        .overlay(FestivalTicket().stroke(Ink.rule, lineWidth: 0.8))
        .overlay(
          FestivalTicket().stroke(Ink.rule, lineWidth: 0.5).padding(5).allowsHitTesting(false)
        )
        .padding(22)
    }.accessibilityAddTraits(.isModal)
  }

  private var tutorialOverlay: some View {
    overlay {
      PaperLantern(size: 36)
      Eyebrow(text: "Carry the light")
      Text("One unbroken parade.")
        .font(TypeStyle.title(30)).foregroundStyle(Ink.cream)
      HStack(spacing: 8) {
        Image(systemName: "flag.fill")
        Image(systemName: "arrow.right")
        Image(systemName: "1.circle.fill")
        Image(systemName: "arrow.right")
        Image(systemName: "door.left.hand.open")
        Image(systemName: "arrow.right")
        Image(systemName: "sparkles")
      }.font(.system(size: 18)).foregroundStyle(Ink.gold).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 16) {
        tutorialLine("hand.draw", "Draw along the streets, or tap adjacent street junctions.")
        tutorialLine(
          "1.circle", "Collect Amber, Rose, then Jade. Each color opens its matching gate.")
        tutorialLine(
          "sparkles", "Reach the square. Never cross your own ribbon. Undo is always free.")
      }.padding(.vertical, 6)
      Button {
        progress.hasLearned = true
        tutorial = false
      } label: {
        Text("Let’s light the town")
      }
      .buttonStyle(GoldButtonStyle()).accessibilityIdentifier("tutorial-start")
    }
  }

  private func tutorialLine(_ symbol: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol).foregroundStyle(Ink.gold).frame(width: 20)
      Text(text).font(.system(size: 14)).foregroundStyle(Ink.cream).fixedSize(
        horizontal: false, vertical: true)
    }
  }

  private var pauseOverlay: some View {
    overlay {
      Eyebrow(text: "A moment of quiet")
      Text("Your lanterns can wait.").font(TypeStyle.title(30)).foregroundStyle(
        Ink.cream)
      Text("Your route is saved on this iPhone.").font(.subheadline).foregroundStyle(Ink.muted)
      Button("Resume parade") { paused = false }.buttonStyle(GoldButtonStyle())
        .accessibilityIdentifier("resume")
      Button("Restart town") { reset() }.buttonStyle(GoldButtonStyle(secondary: true))
        .accessibilityIdentifier("restart")
      Button("Return to the atlas") { dismiss() }.frame(minHeight: 44).accessibilityIdentifier(
        "return-home")
    }
  }

  private var tangleOverlay: some View {
    overlay {
      Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
        .font(.system(size: 34)).foregroundStyle(Ink.rose)
      Eyebrow(text: "A little tangle")
      Text("The ribbon crossed itself.").font(TypeStyle.title(30)).foregroundStyle(
        Ink.cream
      )
      .multilineTextAlignment(.center)
      Text("That step didn’t count. Take one step back and find another way through.")
        .font(.subheadline).foregroundStyle(Ink.muted).multilineTextAlignment(.center)
      Button("Untangle & undo") {
        parade.undo()
        tangled = false
        lastTouched = nil
        notice = "Room to breathe. Try another street."
        progress.save(parade)
      }.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("untangle")
      Button("Start a fresh ribbon") { reset() }.frame(minHeight: 44).accessibilityIdentifier(
        "tangle-restart")
    }
  }
}

struct ResultView: View {
  let puzzle: Puzzle
  let parade: Parade
  let replay: () -> Void
  let home: () -> Void
  @EnvironmentObject private var progress: Progress
  @State private var share: SharePayload?
  @State private var shareError = false
  private var advice: String {
    if parade.stars(in: puzzle) == 3 { return "A perfect ribbon. A radiant square." }
    if parade.hints > 0 { return "Try again without a guide to earn a brighter star." }
    if parade.mistakes > 0 { return "Try a route without missteps for three stars." }
    return "Try reaching the square in \(puzzle.par) steps or fewer."
  }

  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 720
      ZStack {
        NightBackground()
        ScrollView(showsIndicators: false) {
          VStack(spacing: compact ? 12 : 16) {
            Eyebrow(text: "One unbroken ribbon").padding(.top, compact ? 16 : 20)
            Text("A town aglow.")
              .font(TypeStyle.italic(compact ? 38 : 44)).tracking(-0.5)
              .foregroundStyle(Ink.cream)
            VStack(spacing: compact ? 8 : 12) {
              HStack {
                Text("LANTERN PARADE").font(.system(size: 8, weight: .medium)).tracking(2)
                Spacer()
                Text("NIGHT ATLAS").font(.system(size: 8)).tracking(1)
              }.foregroundStyle(Ink.night.opacity(0.6))
              Text(puzzle.title).font(TypeStyle.title(30)).foregroundStyle(Ink.night)
              TownMap(puzzle: puzzle, route: parade.route, celebrating: true, procession: 0.8)
                .frame(
                  width: min(
                    geometry.size.width - 76, geometry.size.height * (compact ? 0.33 : 0.38)))
              Stars(count: parade.stars(in: puzzle), onPaper: true).font(.system(size: 14))
              HStack(spacing: 0) {
                resultStat("\(parade.route.count - 1)", "STEPS")
                resultStat("\(parade.mistakes)", parade.mistakes == 1 ? "MISSTEP" : "MISSTEPS")
                resultStat("\(parade.hints)", parade.hints == 1 ? "GUIDE" : "GUIDES")
              }.padding(.bottom, 4)
            }.padding(16).background(Ink.cream, in: FestivalTicket())
              .overlay(
                FestivalTicket().stroke(Ink.gold.opacity(0.3), lineWidth: 0.5).padding(5)
                  .allowsHitTesting(false))
            Text(advice)
              .font(.system(size: 12)).foregroundStyle(Ink.muted).multilineTextAlignment(.center)
            Button {
              createShare()
            } label: {
              Label("Keep a little of the night", systemImage: "square.and.arrow.up")
            }.buttonStyle(GoldButtonStyle()).accessibilityLabel("Share your lantern poster")
              .accessibilityIdentifier(
                "share-result")
            HStack(spacing: 12) {
              Button("Parade again", action: replay).buttonStyle(GoldButtonStyle(secondary: true))
                .accessibilityIdentifier("replay")
              Button("Explore towns", action: home).buttonStyle(GoldButtonStyle(secondary: true))
                .accessibilityIdentifier("result-home")
            }
            Text("BEST  \(progress.best[puzzle.id] ?? 0) / 3   ·   SAVED ON THIS IPHONE")
              .font(.system(size: 9)).tracking(1).foregroundStyle(Ink.muted)
          }.padding(.horizontal, 24).padding(.bottom, 24)
        }.clipped()
      }
    }
    .sheet(item: $share) { payload in
      PosterPreview(image: payload.image, title: puzzle.title)
    }
    .alert("Couldn’t prepare the poster", isPresented: $shareError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Please try sharing again.")
    }
  }

  private func resultStat(_ value: String, _ label: String) -> some View {
    VStack(spacing: 3) {
      Text(value).font(TypeStyle.title(25))
      Text(label).font(.system(size: 10, weight: .medium)).tracking(0.8)
    }.foregroundStyle(Ink.night.opacity(0.8)).frame(maxWidth: .infinity)
  }

  @MainActor
  private func createShare() {
    let renderer = ImageRenderer(content: PosterView(puzzle: puzzle, parade: parade))
    renderer.scale = 2
    guard let image = renderer.uiImage else {
      shareError = true
      return
    }
    share = SharePayload(image: image)
  }
}

struct PosterView: View {
  let puzzle: Puzzle
  let parade: Parade
  var body: some View {
    ZStack {
      Ink.cream
      Rectangle().stroke(Ink.night.opacity(0.4), lineWidth: 0.7).padding(18)
      Rectangle().stroke(Ink.night.opacity(0.15), lineWidth: 0.5).padding(23)
      VStack(spacing: 0) {
        HStack {
          Text("THE MIDNIGHT FESTIVAL")
          Spacer()
          Text(
            puzzle.id.hasPrefix("daily")
              ? "DAILY LIGHT"
              : "ROUTE № \(String(format: "%02d", (Towns.all.firstIndex { $0.id == puzzle.id } ?? 0) + 1))"
          )
        }.font(.system(size: 10, weight: .medium)).tracking(1.6).padding(.bottom, 26)
        Text("Lantern Parade").font(TypeStyle.title(57)).tracking(-2)
        Text("A little light, beautifully led.").font(TypeStyle.italic(24))
          .padding(.top, 3).padding(.bottom, 27)
        TownMap(puzzle: puzzle, route: parade.route, celebrating: true, procession: 0.8)
          .frame(width: 440, height: 440)
        Text(puzzle.title).font(TypeStyle.title(35)).padding(.top, 25)
        Stars(count: parade.stars(in: puzzle), onPaper: true).font(.system(size: 16))
          .padding(.top, 12)
        Text("\(parade.route.count - 1) steps  ·  One unbroken ribbon")
          .font(.system(size: 16)).tracking(0.5).padding(.top, 18)
        Spacer(minLength: 20)
        HStack {
          Rectangle().fill(Ink.night.opacity(0.3)).frame(height: 0.5)
          Text("A TOWN, ILLUMINATED").font(.system(size: 11)).tracking(1.5).fixedSize()
          Rectangle().fill(Ink.night.opacity(0.3)).frame(height: 0.5)
        }
      }.foregroundStyle(Ink.night).padding(50)
    }.frame(width: 540, height: 860).environment(\.colorScheme, .dark)
  }
}

struct SharePayload: Identifiable {
  let id = UUID()
  let image: UIImage
}

struct PosterPreview: View {
  let image: UIImage
  let title: String
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ZStack {
        Ink.night.ignoresSafeArea()
        VStack(spacing: 18) {
          Image(uiImage: image).resizable().scaledToFit()
            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
            .accessibilityLabel(
              "Lantern Parade poster showing the completed route through \(title)")
          ShareLink(
            item: Image(uiImage: image),
            subject: Text("Lantern Parade · \(title)"),
            message: Text("I brought \(title) to life. One ribbon. A thousand little lights."),
            preview: SharePreview("Lantern Parade · \(title)", image: Image(uiImage: image))
          ) {
            Label("Share poster", systemImage: "square.and.arrow.up")
          }.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("share-poster")
        }.padding(24)
      }
      .navigationTitle("Your festival poster").navigationBarTitleDisplayMode(.inline)
      .toolbar { Button("Done") { dismiss() }.accessibilityIdentifier("close-poster") }
    }
  }
}
