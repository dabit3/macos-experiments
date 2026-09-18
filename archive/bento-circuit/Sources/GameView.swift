import SwiftUI

struct BoardView: View {
  let lunch: Lunch
  let game: PackingGame
  let cellSize: CGFloat
  var selectedID: String?
  var ghost: (FoodPiece, Placement)?
  var onCell: ((Cell) -> Void)?
  var showLetters = true

  var body: some View {
    ZStack(alignment: .topLeading) {
      BentoFrame().padding(-16)
      if showLetters {
        ForEach(0..<lunch.height, id: \.self) { y in
          ForEach(0..<lunch.width, id: \.self) { x in
            let cell = Cell(x: x, y: y)
            Button {
              onCell?(cell)
            } label: {
              RoundedRectangle(cornerRadius: 3)
                .fill(
                  x >= lunch.divider
                    ? Color(red: 0.91, green: 0.83, blue: 0.65)
                    : Color(red: 0.81, green: 0.83, blue: 0.70)
                )
                .overlay {
                  Circle().fill(Palette.ink.opacity(0.20)).frame(width: 2, height: 2)
                }
                .padding(0.7)
            }
            .buttonStyle(.plain)
            .frame(width: cellSize, height: cellSize)
            .position(x: (CGFloat(x) + 0.5) * cellSize, y: (CGFloat(y) + 0.5) * cellSize)
            .accessibilityLabel(cellLabel(cell))
            .accessibilityIdentifier("Cell \(x + 1),\(y + 1)")
            .disabled(onCell == nil)
          }
        }
      } else {
        HStack(spacing: 4) {
          RoundedRectangle(cornerRadius: 4).fill(Palette.sage)
            .frame(width: CGFloat(lunch.divider) * cellSize - 2)
          RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.91, green: 0.83, blue: 0.65))
            .frame(width: CGFloat(lunch.width - lunch.divider) * cellSize - 2)
        }.frame(height: CGFloat(lunch.height) * cellSize)
      }
      ForEach(lunch.pieces) { piece in
        if let placement = game.placements[piece.id] {
          PolyominoArt(
            piece: piece, turns: placement.turns, cellSize: cellSize,
            selected: selectedID == piece.id, showLetter: showLetters, decorative: !showLetters
          )
          .offset(
            x: CGFloat(placement.anchor.x) * cellSize, y: CGFloat(placement.anchor.y) * cellSize
          )
          .allowsHitTesting(false)
        }
      }
      Rectangle().fill(Palette.ink.gradient)
        .frame(width: 5, height: CGFloat(lunch.height) * cellSize + 12)
        .overlay(Rectangle().fill(Palette.gold.opacity(0.6)).frame(width: 1), alignment: .leading)
        .offset(x: CGFloat(lunch.divider) * cellSize - 2.5, y: -6)
        .allowsHitTesting(false)
      if let (piece, placement) = ghost {
        let valid = game.problem(piece: piece, at: placement, lunch: lunch) == nil
        ForEach(piece.rotated(placement.turns), id: \.self) { cell in
          RoundedRectangle(cornerRadius: 8)
            .fill((valid ? Palette.ink : Palette.orange).opacity(0.22))
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(
                  valid ? Palette.ink : Palette.orange,
                  style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            )
            .frame(width: cellSize - 4, height: cellSize - 4)
            .offset(
              x: CGFloat(cell.x + placement.anchor.x) * cellSize + 2,
              y: CGFloat(cell.y + placement.anchor.y) * cellSize + 2)
        }
        .allowsHitTesting(false)
        if let marked = piece.rotated(placement.turns).first {
          Text(piece.id)
            .font(.system(size: max(10, cellSize * 0.24), weight: .bold, design: .monospaced))
            .foregroundStyle(Palette.paper)
            .padding(4).background(valid ? Palette.ink : Palette.orange, in: Circle())
            .offset(
              x: CGFloat(marked.x + placement.anchor.x) * cellSize + 3,
              y: CGFloat(marked.y + placement.anchor.y) * cellSize + 3
            )
            .allowsHitTesting(false)
        }
      }
    }
    .frame(width: CGFloat(lunch.width) * cellSize, height: CGFloat(lunch.height) * cellSize)
  }

  private func cellLabel(_ cell: Cell) -> String {
    let occupant = lunch.pieces.first { piece in
      guard let placement = game.placements[piece.id] else { return false }
      return game.cells(for: piece, at: placement).contains(cell)
    }
    return
      "Row \(cell.y + 1), column \(cell.x + 1), \(occupant.map { "\($0.ingredient.name) \($0.id)" } ?? "empty"), \(cell.x >= lunch.divider ? "fruit" : "savory")"
  }
}

struct GameView: View {
  let lunch: Lunch
  let store: LunchStore
  let home: () -> Void
  let next: () -> Void
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var game: PackingGame
  @State private var selectedID: String?
  @State private var turns = 0
  @State private var boardFrame = CGRect.zero
  @State private var dragAnchor: Cell?
  @State private var guide = false
  @State private var message = "Every good thing has its place."
  @State private var tutorial = false
  @State private var paused = false
  @State private var result = false
  @State private var resetConfirmation = false
  @State private var ribbon = false

  init(lunch: Lunch, store: LunchStore, home: @escaping () -> Void, next: @escaping () -> Void) {
    self.lunch = lunch
    self.store = store
    self.home = home
    self.next = next
    _game = State(initialValue: store.game(for: lunch))
  }

  private var selected: FoodPiece? { lunch.pieces.first { $0.id == selectedID } }
  private var ghost: (FoodPiece, Placement)? {
    guard let selected else { return nil }
    if guide { return (selected, Placement(anchor: selected.solution, turns: 0)) }
    if let dragAnchor { return (selected, Placement(anchor: dragAnchor, turns: turns)) }
    return nil
  }

  var body: some View {
    GeometryReader { geometry in
      let cellSize = min((geometry.size.width - 64) / CGFloat(lunch.width), 77)
      ScrollView {
        VStack(spacing: 20) {
          header
          HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
              MicroLabel(
                text: lunch.isDaily
                  ? "THE DAILY PARCEL"
                  : "THE LOCAL LINE / LUNCH \(String(format: "%02d", lunch.number))")
              Text(lunch.title).font(.system(size: 34, weight: .regular, design: .serif))
                .tracking(-1.1).minimumScaleFactor(0.7).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(spacing: 2) {
              Text(String(format: "%02d", lunch.par)).font(
                .system(size: 27, weight: .regular, design: .serif))
              MicroLabel(text: "PIECES", color: Palette.orange)
            }.foregroundStyle(Palette.orange)
          }
          HStack {
            Text("01 / SAVORY").frame(width: cellSize * CGFloat(lunch.divider))
            Text("02 / FRUIT").frame(width: cellSize * 2)
          }
          .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.2)
          .foregroundStyle(Palette.muted).padding(.bottom, -8)
          BoardView(
            lunch: lunch, game: game, cellSize: cellSize, selectedID: selectedID, ghost: ghost
          ) { cell in
            tapCell(cell)
          }
          .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
          } action: { frame in
            boardFrame = frame
          }
          .overlay {
            if ribbon {
              ParcelRibbon()
                .transition(.scale(scale: 0.05).combined(with: .opacity))
                .allowsHitTesting(false)
            }
          }
          .padding(.vertical, 15)
          status
          tray(cellSize: cellSize, compact: geometry.size.width < 390)
          controls
          Text("Tap a piece, then where its letter should go. Or drag to fit.")
            .font(.system(size: 11)).foregroundStyle(Palette.muted)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 20)
        .frame(maxWidth: 550).frame(maxWidth: .infinity)
      }
      .scrollDisabled(dragAnchor != nil)
    }
    .foregroundStyle(Palette.ink)
    .onAppear { tutorial = !store.learned }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active {
        store.save(game)
        if !game.isComplete(lunch) && !tutorial { paused = true }
      }
    }
    .sheet(isPresented: $tutorial) {
      TutorialView {
        store.learned = true
        tutorial = false
      }.interactiveDismissDisabled()
    }
    .sheet(isPresented: $paused) { pauseSheet }
    .sheet(isPresented: $result) {
      ResultView(lunch: lunch, game: game, best: store.best[lunch.id] ?? 0) {
        result = false
        reset()
      } next: {
        result = false
        next()
      } home: {
        result = false
        home()
      }
      .interactiveDismissDisabled()
    }
    .confirmationDialog(
      "Repack this lunch?", isPresented: $resetConfirmation, titleVisibility: .visible
    ) {
      Button("Repack from the beginning", role: .destructive) { reset() }
    } message: {
      Text("Your best rating stays safe.")
    }
  }

  private var header: some View {
    HStack {
      IconButton(symbol: "arrow.left", label: "Back to journey") {
        store.save(game)
        home()
      }
      Spacer()
      HStack(spacing: 10) {
        let remaining = max(0, lunch.moveLimit - game.moves)
        Text(String(format: "%02d", remaining))
          .font(.system(size: 24, weight: .regular, design: .serif))
        Rectangle().fill(Palette.cream.opacity(0.25)).frame(width: 1, height: 23)
        Text("\(remaining == 1 ? "MOVE" : "MOVES")\nLEFT")
          .font(.system(size: 8, weight: .semibold, design: .monospaced)).tracking(1.8)
      }
      .foregroundStyle(Palette.cream)
      .padding(.horizontal, 17).frame(height: 45)
      .background(
        game.isFailed(lunch) ? Palette.orange : Palette.ink, in: RoundedRectangle(cornerRadius: 5)
      )
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(max(0, lunch.moveLimit - game.moves)) moves left")
      Spacer()
      IconButton(symbol: "pause", label: "Pause") { paused = true }
    }
  }

  private var status: some View {
    VStack(spacing: 8) {
      HStack(spacing: 5) {
        ForEach(lunch.pieces) { piece in
          Rectangle().fill(game.placements[piece.id] == nil ? Palette.line : Palette.orange)
            .frame(height: 2)
        }
      }
      if game.isFailed(lunch) {
        VStack(spacing: 7) {
          Text("The train is leaving.").font(.system(size: 22, design: .serif))
          Text("No moves left. Undo your last placement or repack.")
            .font(.system(size: 12)).multilineTextAlignment(.center)
        }
        .foregroundStyle(Palette.orange).accessibilityIdentifier("Out of moves")
      } else {
        Text(game.isComplete(lunch) ? "A perfect fit. Tying your parcel…" : message)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(Palette.muted)
          .multilineTextAlignment(.center).frame(minHeight: 30)
          .accessibilityIdentifier("Packing status")
      }
    }
  }

  private func tray(cellSize: CGFloat, compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("THE INGREDIENT TRAY").font(.system(size: 9, weight: .bold, design: .monospaced))
          .tracking(1.4)
        Spacer()
        Text("\(game.placements.count) / \(lunch.pieces.count) PACKED")
          .font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(
            Palette.muted)
      }
      let columns = lunch.pieces.count == 4 ? 2 : (lunch.pieces.count > 8 ? 4 : 3)
      let artHeight: CGFloat = columns == 2 ? 68 : 54
      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: columns), spacing: 8
      ) {
        ForEach(lunch.pieces) { piece in
          let placed = game.placements[piece.id] != nil
          let displayTurns =
            selectedID == piece.id
            ? turns : (game.placements[piece.id]?.turns ?? lunch.initialTurns)
          let shape = piece.rotated(displayTurns)
          let shapeWidth = CGFloat((shape.map(\.x).max() ?? 0) + 1)
          let shapeHeight = CGFloat((shape.map(\.y).max() ?? 0) + 1)
          Button {
            select(piece)
          } label: {
            VStack(spacing: 3) {
              ZStack {
                PolyominoArt(
                  piece: piece, turns: displayTurns,
                  cellSize: min(
                    columns == 2 ? 34 : 25, artHeight / shapeHeight,
                    (columns == 2 ? 110 : (compact ? 65 : 76)) / shapeWidth),
                  showLetter: !placed
                )
                .opacity(placed ? 0.35 : 1)
                if placed {
                  Image(systemName: "checkmark.circle.fill").font(.system(size: 20))
                    .foregroundStyle(Palette.ink).background(Palette.paper, in: Circle())
                }
              }.frame(height: artHeight + 1)
              Text("\(piece.id) · \(piece.ingredient.name)")
                .font(.system(size: columns == 2 ? 12 : 10, weight: .medium, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity).frame(height: artHeight + 26)
            .background(
              selectedID == piece.id ? Palette.cream : Palette.cream.opacity(0.5),
              in: RoundedRectangle(cornerRadius: 5)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 5)
                .stroke(
                  selectedID == piece.id ? Palette.orange : Palette.line,
                  lineWidth: selectedID == piece.id ? 1.5 : 0.7)
            )
            .overlay(alignment: .leading) {
              if selectedID == piece.id {
                RoundedRectangle(cornerRadius: 2).fill(Palette.orange).frame(width: 3, height: 30)
                  .padding(.leading, 5)
              }
            }
          }
          .buttonStyle(.plain)
          .disabled(game.isComplete(lunch) || game.isFailed(lunch))
          .accessibilityLabel(
            "\(piece.ingredient.name) piece \(piece.id), \(placed ? "packed, select to move" : "select to pack")"
          )
          .accessibilityIdentifier("Piece \(piece.id)")
          .simultaneousGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
              .onChanged { value in
                guard !game.isFailed(lunch), !game.isComplete(lunch), !boardFrame.isEmpty else {
                  return
                }
                if selectedID != piece.id { select(piece) }
                guide = false
                let shape = piece.rotated(turns)
                let width = (shape.map(\.x).max() ?? 0) + 1
                let height = (shape.map(\.y).max() ?? 0) + 1
                dragAnchor = Cell(
                  x: Int(floor((value.location.x - boardFrame.minX) / cellSize)) - width / 2,
                  y: Int(floor((value.location.y - boardFrame.minY) / cellSize)) - height / 2
                )
              }
              .onEnded { _ in
                if let dragAnchor { place(piece, anchor: dragAnchor) }
                dragAnchor = nil
              }
          )
        }
      }
    }
  }

  private var controls: some View {
    HStack(spacing: 0) {
      control("arrow.uturn.backward", "Undo") {
        game.undo()
        selectedID = nil
        guide = false
        message = "One step back. A fresh possibility."
        store.save(game)
      }.disabled(game.history.isEmpty || game.isComplete(lunch))
      control("rotate.right", "Rotate") {
        guard selected != nil else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) { turns = (turns + 1) % 4 }
        guide = false
        store.feedback()
      }.disabled(selected == nil || game.isFailed(lunch) || game.isComplete(lunch))
      control("sparkle", "Guide") {
        if selected == nil { selectedID = lunch.pieces.first { game.placements[$0.id] == nil }?.id }
        turns = 0
        guide = true
        game.usedGuide = true
        message = "Dotted squares show a fit. Guided lunches earn one star."
        store.save(game)
      }.disabled(game.isFailed(lunch) || game.isComplete(lunch))
      control("arrow.counterclockwise", "Repack") { resetConfirmation = true }
    }
    .padding(5)
    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 9))
    .overlay(
      RoundedRectangle(cornerRadius: 6).stroke(Palette.gold.opacity(0.4), lineWidth: 0.7).padding(3)
    )
  }

  private func control(_ symbol: String, _ name: String, action: @escaping () -> Void) -> some View
  {
    Button(action: action) {
      VStack(spacing: 5) {
        Image(systemName: symbol).font(.system(size: 18, weight: .medium))
        Text(name).font(.system(size: 10, weight: .medium))
      }
      .frame(maxWidth: .infinity).frame(height: 57)
    }
    .buttonStyle(ControlKey()).accessibilityLabel(name).accessibilityIdentifier(name)
  }

  private var pauseSheet: some View {
    VStack(spacing: 22) {
      Capsule().fill(Palette.line).frame(width: 35, height: 4).padding(.top, 12)
      PackingSeal(title: "REST", subtitle: "A WHILE")
      Text("Take a little breather.").font(.system(size: 30, design: .serif))
      Text("Your lunch will be right here.").font(.system(size: 14)).foregroundStyle(Palette.muted)
      Button("Keep packing") { paused = false }.buttonStyle(PrimaryButton())
        .accessibilityIdentifier("Resume")
      Button("How to pack") {
        paused = false
        tutorial = true
      }.font(.system(size: 14))
      Button("Back to the journey") {
        store.save(game)
        paused = false
        home()
      }.font(.system(size: 14))
      Spacer()
    }
    .padding(.horizontal, 28).background(Palette.paper).foregroundStyle(Palette.ink)
    .presentationDetents([.height(390)])
  }

  private func select(_ piece: FoodPiece) {
    selectedID = piece.id
    turns = game.placements[piece.id]?.turns ?? lunch.initialTurns
    guide = false
    message = "\(piece.ingredient.name) \(piece.id): tap where its letter should go."
    store.feedback()
  }

  private func tapCell(_ cell: Cell) {
    if let selected {
      place(selected, anchor: selected.anchor(placingMarkedCellAt: cell, turns: turns))
    } else if let piece = lunch.pieces.first(where: { piece in
      guard let placement = game.placements[piece.id] else { return false }
      return game.cells(for: piece, at: placement).contains(cell)
    }) {
      select(piece)
    } else {
      message = "Choose an ingredient below first."
    }
  }

  private func place(_ piece: FoodPiece, anchor: Cell) {
    let placement = Placement(anchor: anchor, turns: turns)
    if let problem = game.place(piece, at: placement, lunch: lunch) {
      message = problem
      store.feedback(success: false)
    } else {
      selectedID = nil
      guide = false
      message =
        ["Neatly tucked in.", "A little closer to lunch.", "Room for something lovely."][
          game.moves % 3]
      store.feedback()
      store.save(game)
      if game.isComplete(lunch) {
        store.finish(game, lunch: lunch)
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7)) {
          ribbon = true
        }
        Task { @MainActor in
          try? await Task.sleep(for: .seconds(reduceMotion ? 0.2 : 1.1))
          if game.isComplete(lunch) { result = true }
        }
      }
    }
  }

  private func reset() {
    game = PackingGame(lunch: lunch)
    selectedID = nil
    dragAnchor = nil
    guide = false
    ribbon = false
    message = "A fresh box. A new arrangement."
    store.save(game)
  }
}

struct TutorialView: View {
  let done: () -> Void
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        HStack {
          CircuitMark()
          Spacer()
          MicroLabel(text: "THE ART OF PACKING", color: Palette.orange)
        }
        Text("Everything\nhas its place.").font(.system(size: 43, weight: .regular, design: .serif))
          .tracking(-1.5).fixedSize(horizontal: false, vertical: true)
        HStack {
          Spacer()
          PolyominoArt(piece: LunchBook.all[0].pieces[1], cellSize: 50, showLetter: true)
          Image(systemName: "arrow.right").padding(20).foregroundStyle(Palette.orange)
          PolyominoArt(
            piece: LunchBook.all[0].pieces[1], cellSize: 50, selected: true, showLetter: true
          )
          .padding(9).background(Palette.sage.opacity(0.3), in: RoundedRectangle(cornerRadius: 9))
          Spacer()
        }
        Perforation()
        instruction(
          "01", "Choose, turn, tuck.",
          "Tap an ingredient, rotate if needed, then tap where its letter-marked square should go. Or drag it into the box."
        )
        instruction(
          "02", "Sweet stays separate.",
          "Savory food on the left. Fruit on the right. Fill every square without crossing the divider."
        )
        instruction(
          "03", "Make every move count.",
          "Each placement uses a move. A perfect lunch places every piece once. Undo is free; Guide earns one star."
        )
        Button("Let’s pack") { done() }.buttonStyle(PrimaryButton()).accessibilityIdentifier(
          "Finish tutorial")
      }
      .padding(28)
    }
    .frame(maxHeight: .infinity).background(Palette.paper).foregroundStyle(Palette.ink)
  }

  private func instruction(_ number: String, _ title: String, _ body: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Text(number).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(
        Palette.orange
      )
      .padding(.top, 4)
      VStack(alignment: .leading, spacing: 5) {
        Text(title).font(.system(size: 18, weight: .semibold, design: .serif))
        Text(body).font(.system(size: 14)).foregroundStyle(Palette.muted).fixedSize(
          horizontal: false, vertical: true)
      }
    }
  }
}
