import SwiftUI

@main
struct TidepoolApp: App {
  @StateObject private var game = GameStore()
  var body: some Scene {
    WindowGroup {
      TidepoolView(game: game)
        .preferredColorScheme(.light)
    }
  }
}

struct TidepoolView: View {
  @ObservedObject var game: GameStore
  @State private var inspecting: Creature?
  @State private var showLevels = false
  @State private var confirmReset = false
  @State private var boardFrame = CGRect.zero
  @State private var dragged: Creature?
  @State private var dragPoint = CGPoint.zero
  @State private var dragSource: Int?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        LinearGradient(
          colors: [Ink.sand, Color(red: 0.87, green: 0.94, blue: 0.87), Ink.sand],
          startPoint: .topLeading, endPoint: .bottomTrailing
        ).ignoresSafeArea()
        ScrollView(showsIndicators: false) {
          VStack(spacing: 9) {
            header
            levelHeading
            healthBar
            pool(side: min(geometry.size.width - 36, max(240, geometry.size.height - 455), 340))
            status
            residents
            actions
            Text("A SMALL WORLD WORTH RESTORING")
              .font(.system(size: 9, weight: .semibold, design: .rounded))
              .tracking(2.2).foregroundStyle(Ink.muted.opacity(0.7))
              .padding(.bottom, 4)
          }
          .padding(.horizontal, 18)
          .padding(.top, 6)
          .frame(maxWidth: 440)
          .frame(maxWidth: .infinity)
        }
        .scrollDisabled(dragged != nil)
        if let dragged {
          CreatureArt(creature: dragged)
            .frame(width: 84, height: 84)
            .shadow(color: Ink.deep.opacity(0.35), radius: 8, y: 10)
            .position(dragPoint).allowsHitTesting(false)
        }
      }
      .coordinateSpace(name: "play")
      .sheet(item: $inspecting) { creature in inspector(creature) }
      .sheet(isPresented: $showLevels) { levelMap }
      .confirmationDialog(
        "Start this pool again?", isPresented: $confirmReset, titleVisibility: .visible
      ) {
        Button("Reset this pool", role: .destructive) { game.reset() }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("Your unlocked shores stay saved. You can undo a reset.")
      }
    }
    .tint(Ink.teal)
  }

  private var header: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 1) {
        Text("THE SHORELINE JOURNAL").font(.system(size: 9, weight: .bold)).tracking(2)
          .foregroundStyle(Ink.muted)
        Text("Tidepool").font(.system(size: 34, weight: .regular, design: .serif))
          .foregroundStyle(Ink.deep)
      }
      Spacer()
      Button {
        showLevels = true
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "map")
          Text("Shores").font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 14).frame(height: 42)
        .background(.white.opacity(0.6), in: Capsule())
        .overlay(Capsule().strokeBorder(Ink.deep.opacity(0.12)))
      }
      .accessibilityIdentifier("shores")
      .accessibilityLabel("Choose a shore")
    }
  }

  private var levelHeading: some View {
    HStack(alignment: .top, spacing: 12) {
      Text(String(format: "%02d", game.level.id + 1))
        .font(.system(size: 34, weight: .light, design: .serif))
        .foregroundStyle(Ink.teal.opacity(0.65))
      VStack(alignment: .leading, spacing: 3) {
        Text(game.level.title)
          .font(.system(size: 23, weight: .medium, design: .serif)).foregroundStyle(Ink.deep)
        Text(game.level.subtitle).font(.system(size: 12)).foregroundStyle(Ink.muted)
      }
      Spacer(minLength: 0)
      VStack(spacing: 4) {
        HStack(spacing: 4) {
          ForEach(0..<5) { index in
            Circle().fill(
              game.progress.completed.contains(index) ? Ink.teal : Ink.teal.opacity(0.18)
            )
            .frame(width: 5, height: 5)
          }
        }
        Text("\(game.progress.completed.count) / 5")
          .font(.system(size: 10, weight: .medium)).foregroundStyle(Ink.muted)
      }.padding(.top, 8)
    }
  }

  private var healthBar: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("ECOSYSTEM", systemImage: "leaf")
          .font(.system(size: 9, weight: .bold)).tracking(1.2)
        Spacer()
        Text("\(game.healthyCount) / \(game.level.inhabitants.count) thriving")
          .font(.system(size: 11, weight: .semibold))
      }.foregroundStyle(Ink.teal)
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(Ink.teal.opacity(0.1))
          Capsule().fill(Ink.teal)
            .frame(
              width: proxy.size.width * CGFloat(game.healthyCount)
                / CGFloat(game.level.inhabitants.count))
        }
      }.frame(height: 4)
      Text(game.level.goal).font(.system(size: 11, weight: .medium))
        .foregroundStyle(Ink.deep).fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 14).padding(.vertical, 11)
    .background(.white.opacity(0.57), in: RoundedRectangle(cornerRadius: 17))
  }

  private func pool(side: CGFloat) -> some View {
    VStack(spacing: 8) {
      HStack(spacing: 14) {
        habitatKey("Rock", color: Color(red: 0.40, green: 0.65, blue: 0.58))
        habitatKey("Sand", color: Color(red: 0.86, green: 0.76, blue: 0.53))
        habitatKey("Water", color: Color(red: 0.22, green: 0.73, blue: 0.74))
        Spacer()
        Text("BESIDE = ↑ ↓ ← →").font(.system(size: 8, weight: .bold)).foregroundStyle(Ink.muted)
      }.padding(.horizontal, 5)
      ZStack {
        RoundedRectangle(cornerRadius: 41)
          .fill(Color(red: 0.79, green: 0.78, blue: 0.60))
          .shadow(color: Ink.deep.opacity(0.17), radius: 16, x: 0, y: 9)
        RoundedRectangle(cornerRadius: 35)
          .fill(
            LinearGradient(
              colors: [
                Color(red: 0.19, green: 0.65, blue: 0.63),
                Color(red: 0.12, green: 0.49, blue: 0.50),
              ],
              startPoint: .topLeading, endPoint: .bottomTrailing)
          ).padding(6)
        let cellSize = (side - 36) / 4
        VStack(spacing: 4) {
          ForEach(0..<4) { row in
            HStack(spacing: 4) {
              ForEach(0..<4) { column in
                cell(row * 4 + column, size: cellSize)
              }
            }
          }
        }
        .onGeometryChange(for: CGRect.self) { proxy in
          proxy.frame(in: .named("play"))
        } action: { frame in
          boardFrame = frame
        }
        WaterLight().clipShape(RoundedRectangle(cornerRadius: 35)).padding(7)
        if game.restored {
          Image(systemName: "sparkle")
            .font(.system(size: 20)).foregroundStyle(.white.opacity(0.8))
            .position(x: side - 18, y: 16).accessibilityHidden(true)
        }
      }.frame(width: side, height: side)
    }
  }

  private func habitatKey(_ title: String, color: Color) -> some View {
    HStack(spacing: 4) {
      Circle().fill(color).frame(width: 6, height: 6)
      Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(Ink.muted)
    }
  }

  private func cell(_ index: Int, size: CGFloat) -> some View {
    let habitat = game.level.terrain[index]
    let resident = game.board.first { $0.cell == index }
    let healthy = resident.map { Puzzle.healthy($0, board: game.board, level: game.level) } ?? false
    let highlighted = game.hintedCell == index
    return ZStack {
      RoundedRectangle(cornerRadius: habitat == .rock ? 23 : 15)
        .fill(terrainColor(habitat))
        .overlay {
          RoundedRectangle(cornerRadius: habitat == .rock ? 23 : 15)
            .strokeBorder(.white.opacity(habitat == .water ? 0.10 : 0.27), lineWidth: 1)
        }
      if habitat != .water {
        Canvas { context, canvasSize in
          for dot in 0..<8 {
            let x = CGFloat((dot * 19 + index * 3 + 9) % 60) / 60 * canvasSize.width
            let y = CGFloat((dot * 23 + index * 7 + 4) % 60) / 60 * canvasSize.height
            context.fill(
              Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 1.5)),
              with: .color(Ink.deep.opacity(0.12)))
          }
        }.allowsHitTesting(false)
      }
      if let resident {
        CreatureArt(creature: resident.creature, animated: game.restored)
          .frame(width: size - 4, height: size - 4)
          .opacity(dragSource == index ? 0.25 : 1)
        VStack {
          Spacer()
          HStack {
            Spacer()
            Image(systemName: healthy ? "checkmark" : "ellipsis")
              .font(.system(size: 8, weight: .bold))
              .foregroundStyle(healthy ? .white : Ink.deep)
              .frame(width: 15, height: 15)
              .background(healthy ? Ink.teal : Ink.sand, in: Circle())
          }
        }.padding(4)
      } else {
        Text(habitat == .water ? "≈" : habitat.rawValue)
          .font(.system(size: habitat == .water ? 22 : 9, weight: .medium, design: .serif))
          .foregroundStyle(Ink.deep.opacity(0.38))
      }
      if highlighted {
        RoundedRectangle(cornerRadius: 19).strokeBorder(
          Ink.sand, style: StrokeStyle(lineWidth: 3, dash: [5, 3]))
      }
    }
    .frame(width: size, height: size)
    .contentShape(Rectangle())
    .onTapGesture {
      if let selected = game.selected {
        game.place(selected, at: index)
      } else if let resident {
        inspecting = resident.creature
      } else {
        game.announce("This is \(habitat.rawValue). Drag a resident here, or select one first.")
      }
    }
    .highPriorityGesture(dragGesture(creature: resident?.creature, source: index))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "Row \(index / 4 + 1), column \(index % 4 + 1), \(habitat.rawValue)"
        + (resident.map {
          ", \($0.creature.name), \(healthy ? "thriving" : "waiting for neighbors")"
        } ?? ", empty")
    )
    .accessibilityIdentifier("cell-\(index)")
    .accessibilityAddTraits(.isButton)
  }

  private func terrainColor(_ habitat: Habitat) -> Color {
    switch habitat {
    case .rock: Color(red: 0.49, green: 0.68, blue: 0.57)
    case .sand: Color(red: 0.87, green: 0.79, blue: 0.57)
    case .water: Color(red: 0.28, green: 0.74, blue: 0.72).opacity(0.52)
    }
  }

  private var status: some View {
    HStack(spacing: 10) {
      Image(
        systemName: game.restored
          ? "seal.fill" : (game.isError ? "arrow.uturn.backward" : "water.waves")
      )
      .font(.system(size: 17)).foregroundStyle(game.isError ? Ink.coral : Ink.teal)
      VStack(alignment: .leading, spacing: 2) {
        if game.restored {
          Text("Balance restored").font(.system(size: 15, weight: .semibold, design: .serif))
        }
        Text(game.saveWarning ?? game.message)
          .font(.system(size: 11, weight: .medium)).fixedSize(horizontal: false, vertical: true)
          .foregroundStyle(game.isError ? Ink.coral : Ink.muted)
      }
      Spacer(minLength: 0)
      if game.restored {
        Button {
          if game.level.id < 4 { game.switchLevel(game.level.id + 1) } else { showLevels = true }
        } label: {
          Image(systemName: "arrow.right").font(.system(size: 17, weight: .medium))
            .frame(width: 42, height: 42).background(Ink.teal, in: Circle()).foregroundStyle(.white)
        }
        .accessibilityLabel(game.level.id < 4 ? "Next shore" : "View completed shores")
        .accessibilityIdentifier("next-shore")
      }
    }
    .foregroundStyle(Ink.deep)
    .frame(minHeight: 36)
    .padding(.horizontal, 6)
    .accessibilityIdentifier("pool-status")
  }

  private var residents: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("YOUR RESIDENTS").font(.system(size: 9, weight: .bold)).tracking(1.6)
        Spacer()
        Text("DRAG TO PLACE · TAP TO INSPECT").font(.system(size: 8, weight: .medium)).tracking(0.5)
      }.foregroundStyle(Ink.muted)
      HStack(spacing: 7) {
        ForEach(Creature.allCases.filter { game.level.inhabitants.contains($0) }) { creature in
          let count = game.remaining(creature)
          VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
              CreatureArt(creature: creature).frame(height: 57)
              Text("\(count)").font(.system(size: 9, weight: .bold))
                .frame(width: 16, height: 16)
                .background(Ink.teal.opacity(0.1), in: Circle()).padding(3)
            }
            Text(creature.name).font(.system(size: 10, weight: .semibold)).lineLimit(1)
              .minimumScaleFactor(0.75)
            Text(creature.habitat.rawValue).font(.system(size: 8)).foregroundStyle(Ink.muted)
              .padding(.top, 2)
          }
          .padding(.bottom, 7)
          .frame(maxWidth: .infinity)
          .background(
            .white.opacity(count > 0 ? 0.74 : 0.24), in: RoundedRectangle(cornerRadius: 15)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 15)
              .strokeBorder(
                game.selected == creature ? Ink.teal : Ink.deep.opacity(0.08),
                lineWidth: game.selected == creature ? 2 : 1)
          }
          .opacity(count > 0 ? 1 : 0.48)
          .contentShape(Rectangle())
          .onTapGesture { inspecting = creature }
          .highPriorityGesture(dragGesture(creature: count > 0 ? creature : nil, source: nil))
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(
            "\(creature.name), \(count) remaining. Tap to inspect, drag to \(creature.habitat.rawValue)."
          )
          .accessibilityIdentifier("resident-\(creature.rawValue)")
          .accessibilityAddTraits(.isButton)
        }
      }.foregroundStyle(Ink.deep)
    }
  }

  private var actions: some View {
    HStack(spacing: 10) {
      action("Undo", symbol: "arrow.uturn.backward", disabled: !game.canUndo) { game.undo() }
      action("Hint", symbol: "sparkle") { game.hint() }
      action("Reset", symbol: "arrow.counterclockwise") { confirmReset = true }
    }
  }

  private func action(
    _ title: String, symbol: String, disabled: Bool = false, perform: @escaping () -> Void
  ) -> some View {
    Button(action: perform) {
      Label(title, systemImage: symbol).font(.system(size: 12, weight: .semibold))
        .frame(maxWidth: .infinity).frame(height: 42)
        .background(title == "Hint" ? Ink.teal : .white.opacity(0.5), in: Capsule())
        .foregroundStyle(title == "Hint" ? .white : Ink.deep)
    }
    .disabled(disabled).opacity(disabled ? 0.35 : 1)
    .accessibilityIdentifier(title.lowercased())
  }

  private func dragGesture(creature: Creature?, source: Int?) -> some Gesture {
    DragGesture(minimumDistance: 8, coordinateSpace: .named("play"))
      .onChanged { value in
        guard let creature else { return }
        dragged = creature
        dragSource = source
        dragPoint = value.location
      }
      .onEnded { value in
        defer {
          dragged = nil
          dragSource = nil
        }
        guard let creature else { return }
        guard boardFrame.contains(value.location) else {
          game.announce("Drop inside the pool to place a resident.", error: true)
          return
        }
        let column = Int((value.location.x - boardFrame.minX) / boardFrame.width * 4)
        let row = Int((value.location.y - boardFrame.minY) / boardFrame.height * 4)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
          game.place(creature, at: row * 4 + column, movingFrom: source)
        }
      }
  }

  private func inspector(_ creature: Creature) -> some View {
    VStack(spacing: 16) {
      Capsule().fill(Ink.muted.opacity(0.25)).frame(width: 30, height: 4).padding(.top, 12)
      HStack(spacing: 20) {
        CreatureArt(creature: creature, animated: true)
          .frame(width: 108, height: 108)
          .background(Ink.teal.opacity(0.09), in: Circle())
        VStack(alignment: .leading, spacing: 6) {
          Text("FIELD NOTE").font(.system(size: 9, weight: .bold)).tracking(2).foregroundStyle(
            Ink.teal)
          Text(creature.name).font(.system(size: 29, design: .serif)).foregroundStyle(Ink.deep)
          Text("\(creature.habitat.title) resident").font(.system(size: 12)).foregroundStyle(
            Ink.muted)
        }
        Spacer(minLength: 0)
      }
      Text(creature.journal).font(.system(size: 14)).foregroundStyle(Ink.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
      Text(creature.rule + " Neighbors share an edge, never a corner.")
        .font(.system(size: 14, weight: .medium)).foregroundStyle(Ink.deep)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
      Button {
        if game.remaining(creature) > 0 {
          game.selected = creature
          game.announce(
            "Tap a \(creature.habitat.rawValue) space, or drag \(creature.name.lowercased()) from the tray."
          )
        }
        inspecting = nil
      } label: {
        Text(
          game.remaining(creature) > 0 ? "Select \(creature.name.lowercased())" : "Back to the pool"
        )
        .font(.system(size: 15, weight: .semibold))
        .frame(maxWidth: .infinity).frame(height: 48)
        .background(Ink.teal, in: Capsule()).foregroundStyle(.white)
      }.accessibilityIdentifier("select-resident")
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 24)
    .presentationDetents([.height(415)])
    .presentationDragIndicator(.hidden)
    .presentationBackground(Ink.sand)
  }

  private var levelMap: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Five shores.\nOne living coastline.")
            .font(.system(size: 32, design: .serif)).foregroundStyle(Ink.deep)
          Text(
            "Restore each pool to discover the next. Your residents and unlocked shores are saved on this device."
          )
          .font(.system(size: 13)).foregroundStyle(Ink.muted)
          ForEach(PoolLevel.all) { level in
            let locked = level.id > game.unlocked
            let complete = game.progress.completed.contains(level.id)
            Button {
              game.switchLevel(level.id)
              showLevels = false
            } label: {
              HStack(spacing: 14) {
                CreatureArt(creature: Creature.allCases[level.id])
                  .frame(width: 60, height: 60)
                  .background(Ink.teal.opacity(0.08), in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                  Text("SHORE \(String(format: "%02d", level.id + 1))")
                    .font(.system(size: 9, weight: .bold)).tracking(1.3).foregroundStyle(Ink.teal)
                  Text(level.title).font(.system(size: 20, design: .serif)).foregroundStyle(
                    Ink.deep)
                  Text(
                    locked
                      ? "Restore the previous shore"
                      : (complete ? "Restored · revisit" : "Ready to restore")
                  )
                  .font(.system(size: 11)).foregroundStyle(Ink.muted)
                }
                Spacer(minLength: 0)
                Image(
                  systemName: locked ? "lock" : (complete ? "checkmark.seal.fill" : "arrow.right")
                )
                .foregroundStyle(Ink.teal)
              }
              .padding(14).background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 22))
              .opacity(locked ? 0.48 : 1)
            }
            .disabled(locked)
            .accessibilityIdentifier("shore-\(level.id)")
          }
          Text(
            "A playful model of marine relationships, inspired by nature.\nHabitat rules are simplified for the puzzle."
          )
          .font(.system(size: 11)).foregroundStyle(Ink.muted).padding(.top, 8)
        }.padding(22)
      }
      .background(Ink.sand)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { showLevels = false }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}
