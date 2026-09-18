import LinkPresentation
import SwiftUI
import UIKit

struct GameView: View {
  let level: Level
  let home: () -> Void
  let next: () -> Void
  @State private var puzzle: PuzzleState
  @State private var sailing = false
  @State private var paused = false
  @State private var cursor = 0
  @State private var voyage: RouteResult?
  @State private var finished = false
  @State private var showHelp = false
  @State private var showReset = false
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  init(level: Level, home: @escaping () -> Void, next: @escaping () -> Void) {
    self.level = level
    self.home = home
    self.next = next
    _puzzle = State(initialValue: PuzzleState(level: level))
  }

  private var visited: [Cell] {
    guard let voyage, sailing || finished else { return puzzle.preview.cells }
    return Array(voyage.cells.prefix(cursor + 1))
  }
  private var collected: Int {
    guard sailing || finished else { return 0 }
    return puzzle.canals.filter { $0.hasStamp && visited.contains($0.cell) }.count
  }
  private var boat: Cell {
    guard let voyage, !voyage.cells.isEmpty, sailing || finished else { return level.start }
    return voyage.cells[min(cursor, voyage.cells.count - 1)]
  }
  private var boatHeading: Double {
    guard sailing, let voyage, cursor > 0, cursor < voyage.cells.count else { return 0 }
    let direction = voyage.cells[cursor - 1].direction(to: voyage.cells[cursor])
    switch direction {
    case .north: return -90
    case .east: return 0
    case .south: return 90
    case .west: return 180
    }
  }

  var body: some View {
    ZStack {
      NightPaper()
      GeometryReader { geometry in
        ScrollView {
          VStack(spacing: 10) {
            header
            HStack(alignment: .top) {
              VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "LETTER \(String(format: "%02d", level.id + 1))  /  10")
                Text(level.title).font(Ink.title(32)).tracking(-0.6)
                  .foregroundStyle(Ink.cream).minimumScaleFactor(0.75).lineLimit(1)
              }
              Spacer()
              VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%02d", puzzle.moves))
                  .font(Ink.title(34))
                  .foregroundStyle(Ink.cream).contentTransition(.numericText())
                Eyebrow(text: "MOVES")
              }
            }
            statusStrip
            board
              .frame(
                width: min(geometry.size.width - 36, max(290, geometry.size.height - 394), 440),
                height: min(geometry.size.width - 36, max(290, geometry.size.height - 394), 440)
              )
              .padding(.vertical, 5)
            instruction
            controls
            HStack {
              Image(systemName: "drop").font(.system(size: 12))
              Text(
                sailing
                  ? "Tide \(min(cursor + 1, level.tideLimit)) / \(level.tideLimit)"
                  : "Take your time. The tide can wait."
              )
              .font(Ink.italic(13))
              Spacer()
              Text("PAR \(puzzle.par)").font(.system(size: 9, weight: .medium)).tracking(1)
            }.foregroundStyle(Ink.muted)
            if sailing {
              ProgressView(value: Double(cursor + 1), total: Double(level.tideLimit))
                .tint(Ink.gold)
            }
          }
          .padding(.horizontal, 18)
          .padding(.top, 5)
          .padding(.bottom, 18)
          .frame(minHeight: geometry.size.height, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .clipped()
      }
      if paused {
        Ink.night.opacity(0.94).ignoresSafeArea()
        VStack(spacing: 24) {
          PaperBoat().frame(width: 110, height: 80)
          Eyebrow(text: "THE CITY HOLDS ITS BREATH")
          Text("A quiet moment").font(Ink.title(32)).foregroundStyle(Ink.cream)
          MainButton(title: "Keep sailing", icon: "play.fill") { paused = false }
            .accessibilityIdentifier("resume")
          Button("Return to planning") { returnToPlanning() }
            .foregroundStyle(Ink.paper).frame(minHeight: 44)
        }.padding(35)
      }
      if finished, let voyage {
        ResultView(
          level: level, puzzle: puzzle, voyage: voyage,
          retry: { returnToPlanning() },
          next: next, home: home
        ).modifier(BookArrival())
      }
    }
    .task(id: sailing) {
      guard sailing else { return }
      while !Task.isCancelled && sailing {
        try? await Task.sleep(for: .milliseconds(780))
        guard !Task.isCancelled, !paused, let voyage else { continue }
        if cursor + 1 < voyage.cells.count {
          withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.65)) { cursor += 1 }
          Feedback.tap()
        } else {
          if voyage.success {
            ProgressStore().save(level: level.id, moves: puzzle.moves)
            Feedback.tap(success: true)
          }
          finished = true
          sailing = false
        }
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active && sailing { paused = true }
    }
    .sheet(isPresented: $showHelp) { help.preferredColorScheme(.light) }
    .alert("Fold this route again?", isPresented: $showReset) {
      Button("Reset this letter", role: .destructive) {
        returnToPlanning()
        puzzle = PuzzleState(level: level)
      }
      Button("Keep planning", role: .cancel) {}
    } message: {
      Text("Your best delivery stays saved. This plan starts over.")
    }
  }

  private var header: some View {
    HStack {
      IconButton(icon: "arrow.left", label: "Back to home") { home() }
      Spacer()
      Eyebrow(text: level.district)
      Spacer()
      IconButton(icon: sailing ? "pause" : "questionmark", label: sailing ? "Pause" : "How to play")
      {
        if sailing { paused = true } else { showHelp = true }
      }
    }
  }

  private var statusStrip: some View {
    HStack {
      HStack(spacing: 6) {
        ForEach(0..<3) { index in
          PaperStamp(filled: index < collected).frame(width: 20, height: 25)
        }
        Text("\(collected)/3").font(.system(size: 10)).padding(.leading, 3)
          .foregroundStyle(Ink.paper)
      }.accessibilityElement(children: .ignore).accessibilityLabel(
        "\(collected) of 3 stamps collected")
      Spacer()
      HStack(spacing: 6) {
        Circle().fill(sailing ? Ink.gold : Ink.foam).frame(width: 5, height: 5)
        Text(sailing ? "SAILING" : (puzzle.preview.success ? "ROUTE CONNECTED" : "PAUSE & PLAN"))
          .font(.system(size: 9, weight: .medium))
          .tracking(1.3).foregroundStyle(Ink.foam)
      }
    }
    .padding(.top, 10).padding(.bottom, 2)
    .overlay(alignment: .top) { Rectangle().fill(Ink.muted.opacity(0.25)).frame(height: 0.5) }
  }

  private var board: some View {
    BoardView(
      level: level, canals: puzzle.canals, lit: Set(visited), boat: boat,
      collected: sailing || finished ? Set(visited) : [],
      interactive: !sailing && !finished,
      boatHeading: boatHeading,
      sparkling: sailing && puzzle.canals.contains { $0.cell == boat && $0.hasStamp },
      rotate: { cell in
        Feedback.tap()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { puzzle.rotate(cell) }
      },
      toggle: { cell in
        Feedback.tap()
        withAnimation { puzzle.toggleLock(cell) }
      })
  }

  private var instruction: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: sailing ? "wind" : "hand.tap")
        .font(.system(size: 16, weight: .light)).foregroundStyle(Ink.gold)
        .frame(width: 22).padding(.top, 3)
      Text(sailing ? "Follow your letter through the rain." : level.note)
        .font(.system(size: 12)).lineSpacing(4).foregroundStyle(Ink.paper)
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
    }.padding(.top, 7)
  }

  private var controls: some View {
    VStack(spacing: 10) {
      HStack(spacing: 0) {
        tool("arrow.uturn.backward", "Undo", disabled: !puzzle.canUndo || sailing) { puzzle.undo() }
        Rectangle().fill(Ink.muted.opacity(0.2)).frame(width: 0.5, height: 16)
        tool("arrow.counterclockwise", "Reset", disabled: sailing) { showReset = true }
        Rectangle().fill(Ink.muted.opacity(0.2)).frame(width: 0.5, height: 16)
        tool("sparkle", "Hint", disabled: sailing || puzzle.preview.success) { puzzle.hint() }
      }
      if sailing {
        MainButton(title: "Return to planning", icon: "stop.fill") { returnToPlanning() }
          .accessibilityIdentifier("stopSailing")
      } else {
        MainButton(title: "Release the boat", icon: "arrow.right") {
          Feedback.tap()
          voyage = puzzle.preview
          cursor = 0
          sailing = true
        }.accessibilityIdentifier("releaseBoat")
      }
    }
  }

  private func tool(_ icon: String, _ label: String, disabled: Bool, action: @escaping () -> Void)
    -> some View
  {
    Button {
      Feedback.tap()
      action()
    } label: {
      Label(label, systemImage: icon).font(.system(size: 12))
        .foregroundStyle(Ink.paper).frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(PaperPressStyle()).disabled(disabled).opacity(disabled ? 0.3 : 1)
    .accessibilityIdentifier(label.lowercased())
  }

  private func returnToPlanning() {
    sailing = false
    paused = false
    finished = false
    voyage = nil
    cursor = 0
  }

  private var help: some View {
    PaperSheet(
      title: "The art of delivery", subtitle: "Make a way for a small wonder.",
      closeLabel: "Got it"
    ) {
      showHelp = false
    } content: {
      VStack(alignment: .leading, spacing: 28) {
        helpRow(
          "hand.tap", "Turn the canals",
          "Tap a blue canal tile to rotate it clockwise. The pale water shows how far your connected route reaches."
        )
        helpRow(
          "envelope", "Collect all three stamps",
          "Golden postage stamps sit along the route. Sail through each, then reach the red postbox."
        )
        helpRow(
          "lock.open", "Open the locks",
          "Tap the brass latch in a lock tile’s corner. The separate latch opens and closes its red gate."
        )
        helpRow(
          "arrow.up", "Follow the currents",
          "White arrows are one way. Rotate these canals until the arrow points along your route."
        )
        helpRow(
          "sparkle", "A little help",
          "Hint fixes one tile. Three seals reward a delivery at par without hints; hints reduce your seal rating. Undo reverses your last move."
        )
      }
    }
  }

  private func helpRow(_ icon: String, _ title: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 15) {
      Image(systemName: icon).font(.system(size: 19, weight: .light))
        .foregroundStyle(Ink.red).frame(width: 36, height: 44)
        .background(StampShape().fill(Ink.paper))
      VStack(alignment: .leading, spacing: 6) {
        Text(title).font(Ink.title(22)).foregroundStyle(Ink.night)
        Text(text).font(.system(size: 13)).lineSpacing(5).foregroundStyle(Ink.blue)
      }
    }
  }
}

struct BoardView: View {
  let level: Level
  let canals: [Canal]
  let lit: Set<Cell>
  let boat: Cell
  let collected: Set<Cell>
  var interactive: Bool
  var boatHeading: Double = 0
  var sparkling = false
  var failure: Cell? = nil
  var rotate: (Cell) -> Void = { _ in }
  var toggle: (Cell) -> Void = { _ in }

  var body: some View {
    GeometryReader { geometry in
      let inset: CGFloat = 15
      let step = (geometry.size.width - inset * 2) / CGFloat(level.size)
      ZStack(alignment: .topLeading) {
        ForEach(0..<4) { layer in
          RoundedRectangle(cornerRadius: 5)
            .fill(
              Color(
                red: 0.55 + Double(layer) * 0.06, green: 0.55 + Double(layer) * 0.055,
                blue: 0.48 + Double(layer) * 0.05)
            )
            .offset(y: CGFloat(4 - layer) * 2)
        }
        RoundedRectangle(cornerRadius: 5).fill(
          LinearGradient(
            colors: [Ink.cream, Ink.paper], startPoint: .topLeading, endPoint: .bottomTrailing))
        RoundedRectangle(cornerRadius: 3).strokeBorder(Ink.blue.opacity(0.2), lineWidth: 0.6)
          .padding(6)
        ForEach(0..<level.size, id: \.self) { row in
          ForEach(0..<level.size, id: \.self) { col in
            let cell = Cell(row: row, col: col)
            tile(cell, side: step)
              .frame(width: step, height: step)
              .offset(x: inset + CGFloat(col) * step, y: inset + CGFloat(row) * step)
          }
        }
        PaperTexture()
        PaperBoat()
          .frame(width: step * 0.66, height: step * 0.48)
          .rotationEffect(.degrees(boatHeading))
          .shadow(color: Ink.night.opacity(0.3), radius: 4, y: 4)
          .offset(
            x: inset + CGFloat(boat.col) * step + step * 0.17,
            y: inset + CGFloat(boat.row) * step + step * 0.26
          )
          .allowsHitTesting(false)
        if sparkling {
          StampBurst()
            .id(boat)
            .frame(width: step, height: step)
            .offset(
              x: inset + CGFloat(boat.col) * step,
              y: inset + CGFloat(boat.row) * step
            )
            .allowsHitTesting(false)
        }
      }.compositingGroup().shadow(color: .black.opacity(0.17), radius: 10, y: 8)
    }
  }

  @ViewBuilder
  private func tile(_ cell: Cell, side: CGFloat) -> some View {
    if let canal = canals.first(where: { $0.cell == cell }) {
      let fixed = cell == level.start || cell == level.dock
      ZStack {
        Rectangle().fill(Ink.cream.opacity(0.8)).padding(0.7)
          .overlay(Rectangle().strokeBorder(Ink.blue.opacity(0.13), lineWidth: 0.5).padding(0.7))
        Button {
          rotate(cell)
        } label: {
          CanalDrawing(canal: canal, lit: lit.contains(cell))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(interactive && !fixed)
        .accessibilityHidden(!interactive || fixed)
        .accessibilityLabel("Canal row \(cell.row + 1) column \(cell.col + 1)")
        .accessibilityValue(
          canal.ports.map { String(describing: $0) }.joined(separator: " to ")
            + (canal.isCurrent ? ", one way" : "")
        )
        .accessibilityHint("Rotate clockwise")
        .accessibilityIdentifier("canal-\(cell.row)-\(cell.col)")
        if canal.hasStamp && !collected.contains(cell) {
          PaperStamp().frame(width: side * 0.28, height: side * 0.34)
            .rotationEffect(.degrees(-8))
            .shadow(color: Ink.night.opacity(0.2), radius: 1, x: 1, y: 2)
            .offset(x: side * 0.22, y: -side * 0.24)
            .allowsHitTesting(false)
        }
        if cell == level.dock {
          Postbox().frame(width: side * 0.3, height: side * 0.48)
            .offset(x: side * 0.19, y: -side * 0.16).allowsHitTesting(false)
        }
        if canal.isLock {
          VStack {
            HStack {
              Spacer(minLength: 0)
              Button {
                toggle(cell)
              } label: {
                Image(systemName: canal.open ? "lock.open" : "lock.fill")
                  .font(.system(size: 13, weight: .medium))
                  .foregroundStyle(Ink.night)
                  .frame(width: 26, height: 29)
                  .background(Ink.gold.gradient, in: RoundedRectangle(cornerRadius: 2))
                  .overlay(
                    RoundedRectangle(cornerRadius: 1).strokeBorder(
                      Ink.cream.opacity(0.65), lineWidth: 0.7
                    ).padding(2)
                  )
                  .shadow(color: Ink.night.opacity(0.2), radius: 1, x: 1, y: 2)
                  .frame(width: 44, height: 44)
                  .contentShape(Rectangle())
              }
              .buttonStyle(PaperPressStyle()).allowsHitTesting(interactive)
              .accessibilityHidden(!interactive)
              .accessibilityLabel(
                "\(canal.open ? "Close" : "Open") lock row \(cell.row + 1) column \(cell.col + 1)"
              )
              .accessibilityIdentifier("lock-\(cell.row)-\(cell.col)")
            }
            Spacer(minLength: 0)
          }
        }
        if cell == failure {
          RoundedRectangle(cornerRadius: 3).strokeBorder(Ink.red, lineWidth: 2)
            .allowsHitTesting(false)
          Image(systemName: "exclamationmark.circle.fill")
            .foregroundStyle(Ink.cream, Ink.red)
            .font(.system(size: 19))
            .offset(x: -side * 0.28, y: side * 0.28)
            .allowsHitTesting(false)
        }
      }
      .clipped()
    } else {
      Canvas { context, size in
        let scale = side / 82
        context.scaleBy(x: scale, y: scale)
        drawHouse(
          &context, x: 20, y: 67, width: CGFloat(25 + (cell.row + cell.col) % 3 * 5),
          height: CGFloat(28 + (cell.row * 3 + cell.col) % 3 * 9),
          red: (cell.row + cell.col) % 3 == 0)
        drawGarden(&context, x: 62, y: 67, variant: cell.row + cell.col)
      }.accessibilityHidden(true)
    }
  }
}

struct ResultView: View {
  let level: Level
  let puzzle: PuzzleState
  let voyage: RouteResult
  let retry: () -> Void
  let next: () -> Void
  let home: () -> Void
  @State private var shareImage: SharedPostcard?

  private var hintSummary: String {
    "\(puzzle.hints) \(puzzle.hints == 1 ? "hint" : "hints")"
  }

  var body: some View {
    ZStack {
      NightPaper()
      ScrollView {
        VStack(spacing: 16) {
          HStack {
            Eyebrow(text: voyage.success ? "DELIVERY CONFIRMED" : "A LETTER STILL ON ITS WAY")
            Spacer()
            IconButton(icon: "xmark", label: "Close result") { retry() }
          }
          Text(voyage.success ? "A little wonder,\ndelivered." : "Even paper boats\nmiss a turn.")
            .font(Ink.italic(37)).tracking(-0.7)
            .foregroundStyle(Ink.cream).multilineTextAlignment(.center)
            .accessibilityIdentifier("resultTitle")
          if voyage.success {
            Postcard(level: level, puzzle: puzzle)
              .rotationEffect(.degrees(-1.5))
              .padding(.horizontal, 6).padding(.vertical, 7)
            HStack(spacing: 8) {
              ForEach(0..<3) { index in
                Image(systemName: "rosette")
                  .font(.system(size: 19, weight: .light))
                  .foregroundStyle(index < puzzle.rating ? Ink.gold : Ink.muted.opacity(0.25))
              }
              Text("\(puzzle.moves) moves · \(hintSummary)")
                .font(.system(size: 11)).foregroundStyle(Ink.paper)
            }.accessibilityLabel(
              "\(puzzle.rating) of 3 seals, \(puzzle.moves) moves, \(hintSummary)")
            MainButton(title: level.id == 9 ? "Back to the collection" : "The next letter") {
              if level.id == 9 { home() } else { next() }
            }.accessibilityIdentifier("nextLetter")
            HStack {
              Button {
                retry()
              } label: {
                Label("Sail again", systemImage: "arrow.counterclockwise")
              }.accessibilityIdentifier("replay")
              Spacer()
              Button {
                let renderer = ImageRenderer(
                  content: Postcard(level: level, puzzle: puzzle).frame(width: 380).padding(20)
                    .background(Ink.paper))
                renderer.scale = 3
                if let image = renderer.uiImage {
                  shareImage = SharedPostcard(image: image)
                }
              } label: {
                Label("Send postcard", systemImage: "square.and.arrow.up")
              }.accessibilityIdentifier("sharePostcard")
            }.font(.system(size: 13, weight: .medium)).foregroundStyle(Ink.paper)
              .frame(minHeight: 44)
          } else {
            BoardView(
              level: level, canals: puzzle.canals, lit: Set(voyage.cells),
              boat: voyage.cells.last ?? level.start, collected: voyage.stamps, interactive: false,
              failure: voyage.cells.last
            )
            .aspectRatio(1, contentMode: .fit).padding(.horizontal, 18)
            Text(voyage.problem?.message ?? "")
              .font(.system(size: 15)).lineSpacing(5)
              .foregroundStyle(Ink.paper).multilineTextAlignment(.center)
            MainButton(title: "Return to planning", icon: "arrow.uturn.backward", action: retry)
              .accessibilityIdentifier("retry")
          }
          Button("The letter collection", action: home)
            .font(.system(size: 12)).foregroundStyle(Ink.muted)
            .frame(minHeight: 44).accessibilityIdentifier("resultHome")
        }.padding(.horizontal, 24).padding(.bottom, 20).padding(.top, 4)
      }.scrollIndicators(.hidden).clipped()
    }
    .sheet(item: $shareImage) { item in
      ActivitySheet(
        image: item.image,
        text: "A little wonder, delivered. \(level.title) — \(puzzle.moves) moves in Paper Current."
      ).preferredColorScheme(.light)
    }
  }
}

struct Postcard: View {
  let level: Level
  let puzzle: PuzzleState
  var body: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack {
        VStack(alignment: .leading, spacing: 5) {
          Eyebrow(text: "A LETTER FROM", color: Ink.blue)
          Text(level.title).font(Ink.italic(27)).foregroundStyle(Ink.night)
            .minimumScaleFactor(0.7).lineLimit(1)
        }
        Spacer()
        PostalSeal(number: String(format: "%02d", level.id + 1), color: Ink.red)
          .rotationEffect(.degrees(12))
      }
      BoardView(
        level: level, canals: puzzle.canals, lit: Set(level.route), boat: level.dock,
        collected: Set(level.route), interactive: false
      )
      .aspectRatio(1, contentMode: .fit)
      .padding(.bottom, 5)
      PostalRule(color: Ink.blue)
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Paper Current").font(Ink.title(15)).foregroundStyle(Ink.night)
          Text("DELIVERED BY PAPER BOAT").font(.system(size: 6, weight: .medium))
            .tracking(1.3).foregroundStyle(Ink.blue)
        }
        Spacer()
        Text("\(puzzle.moves) moves · 3/3 stamps").font(.system(size: 9))
          .foregroundStyle(Ink.red)
      }.padding(.top, 3)
    }
    .padding(16).background(Ink.cream)
    .overlay(Rectangle().strokeBorder(Ink.blue.opacity(0.14), lineWidth: 0.5).padding(5))
    .overlay(PaperTexture())
    .shadow(color: .black.opacity(0.2), radius: 12, y: 10)
  }
}

struct SharedPostcard: Identifiable {
  let id = UUID()
  let image: UIImage
}

struct ActivitySheet: UIViewControllerRepresentable {
  let image: UIImage
  let text: String
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(
      activityItems: [PostcardActivityItem(image: image, text: text)], applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

final class PostcardActivityItem: NSObject, UIActivityItemSource {
  let image: UIImage
  let text: String

  init(image: UIImage, text: String) {
    self.image = image
    self.text = text
  }
  func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController)
    -> Any
  {
    image
  }
  func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    image
  }
  func activityViewController(
    _ activityViewController: UIActivityViewController,
    subjectForActivityType activityType: UIActivity.ActivityType?
  ) -> String {
    text
  }
  func activityViewControllerLinkMetadata(
    _ activityViewController: UIActivityViewController
  ) -> LPLinkMetadata? {
    let metadata = LPLinkMetadata()
    metadata.title = text
    metadata.imageProvider = NSItemProvider(object: image)
    metadata.iconProvider = NSItemProvider(object: image)
    return metadata
  }
}
