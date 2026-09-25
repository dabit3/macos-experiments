import SwiftUI
import UIKit

struct LandscapeView: View {
  let scene: Landscape
  @EnvironmentObject private var store: AtlasStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("foldscape.numbers") private var numbers = true
  @AppStorage("foldscape.haptics") private var haptics = true
  @State private var pace: Pace = .gentle
  @State private var playing = false
  @State private var preview = false
  @State private var restart = false
  @State private var hinted = false
  @State private var guidance = "Tap a piece beside the empty space."

  private var puzzle: Puzzle? { store.saved.puzzles[scene.id] }
  private var complete: Bool { playing && puzzle?.isComplete == true }

  var body: some View {
    ScrollView {
      VStack(spacing: complete ? 18 : 24) {
        HStack {
          Button {
            dismiss()
          } label: {
            Image(systemName: "arrow.left").frame(width: 44, height: 44)
          }
          .accessibilityLabel("Back to landscapes")
          Spacer()
          Text("LANDSCAPE \(scene.number) / 06")
            .font(.system(.caption2, design: .monospaced)).tracking(1.5)
          Spacer()
          Image(systemName: complete ? "checkmark.seal" : "leaf")
            .frame(width: 44, height: 44).accessibilityHidden(true)
        }
        .foregroundStyle(Paper.ink)

        VStack(spacing: 6) {
          Text(complete ? "A little world, whole." : scene.title)
            .font(.system(complete ? .title : .largeTitle, design: .serif))
            .multilineTextAlignment(.center)
          Text(complete ? scene.title : scene.subtitle)
            .font(.subheadline).foregroundStyle(Paper.muted)
        }

        if playing && !complete, let puzzle {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("\(puzzle.moves)").font(.system(.title, design: .serif))
                .contentTransition(.numericText())
              Text("MOVES").font(.system(.caption2, design: .monospaced)).tracking(1)
            }
            Spacer()
            Text(puzzle.pace.caption).font(.subheadline).foregroundStyle(Paper.muted)
          }
          PuzzleBoard(
            scene: scene, puzzle: puzzle, numbers: numbers,
            hint: hinted ? puzzle.hintIndex : nil
          ) { index in
            let moved = store.move(scene.id, at: index)
            if moved {
              hinted = false
              guidance = "Tap a piece beside the empty space."
              if haptics {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
              }
              if store.saved.puzzles[scene.id]?.isComplete == true && haptics {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
              }
            } else {
              guidance = "Only pieces touching the empty space can slide."
              if haptics {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
              }
            }
          }
          .animation(
            reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8), value: puzzle.tiles)
          Text(guidance)
            .font(.subheadline).foregroundStyle(Paper.muted)
            .multilineTextAlignment(.center).frame(minHeight: 40)
          HStack(spacing: 12) {
            tool("Preview", icon: "eye") { preview = true }
            tool("Hint", icon: "sparkle") {
              hinted = true
              guidance = "Slide the outlined piece. Hints retrace a path home."
            }
            tool("Restart", icon: "arrow.counterclockwise") { restart = true }
          }
          Text("No timer. Just one piece at a time.")
            .font(.system(.footnote, design: .serif)).italic()
            .foregroundStyle(Paper.muted)
        } else {
          if complete {
            collectedPrint
            completion
          } else {
            LivingLandscape(scene: scene, living: false)
              .aspectRatio(1, contentMode: .fit)
              .clipShape(RoundedRectangle(cornerRadius: 3))
              .shadow(color: scene.color.opacity(0.16), radius: 16, x: 0, y: 10)
            introduction
          }
        }
      }
      .padding(.horizontal, 24).padding(.bottom, 32)
    }
    .paperScreen()
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if complete {
        HStack(spacing: 12) {
          Button("Keep exploring") { dismiss() }.buttonStyle(InkButton())
          Button {
            start(puzzle?.pace ?? pace)
          } label: {
            VStack(spacing: 5) {
              Image(systemName: "arrow.counterclockwise").font(.body)
              Text("Again").font(.caption)
            }
            .frame(width: 70, height: 58)
            .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
          }
          .accessibilityLabel("Play this landscape again")
        }
        .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 8)
        .background(Paper.stock)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $preview) {
      PreviewView(scene: scene)
    }
    .confirmationDialog("Start a fresh shuffle?", isPresented: $restart, titleVisibility: .visible)
    {
      Button("Restart with a new shuffle", role: .destructive) {
        start(playing ? (puzzle?.pace ?? pace) : pace)
      }
    } message: {
      Text("This puzzle’s moves will reset. Collected landscapes stay safe.")
    }
  }

  private var introduction: some View {
    VStack(spacing: 20) {
      Text("Slide eight paper pieces into place.\nBring a quiet landscape to life.")
        .font(.body).foregroundStyle(Paper.muted).multilineTextAlignment(.center)
      Picker("Puzzle pace", selection: $pace) {
        ForEach(Pace.allCases, id: \.self) { Text($0.title).tag($0) }
      }
      .pickerStyle(.segmented)
      if let puzzle, !puzzle.isComplete {
        Button("Continue · \(puzzle.moves) \(puzzle.moves == 1 ? "move" : "moves")") {
          playing = true
        }
        .buttonStyle(InkButton())
        Button("Start a new \(pace.title.lowercased()) puzzle") { restart = true }
          .font(.subheadline).frame(minHeight: 44)
      } else {
        Button {
          start(pace)
        } label: {
          HStack {
            Text("Unfold this place")
            Image(systemName: "arrow.right")
          }
        }
        .buttonStyle(InkButton())
      }
      if let record = store.saved.completions[scene.id] {
        Label("Collected · best \(record.bestMoves) moves", systemImage: "checkmark.seal")
          .font(.footnote).foregroundStyle(scene.color)
      }
    }
  }

  private var collectedPrint: some View {
    VStack(spacing: 0) {
      LivingLandscape(scene: scene, living: true)
        .aspectRatio(1, contentMode: .fit)
        .clipped()
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 4) {
          Text(scene.title).font(.system(.title3, design: .serif))
          Text("PAPER ATLAS  /  \(scene.number)")
            .font(.system(.caption2, design: .monospaced)).tracking(1.4)
            .foregroundStyle(Paper.muted)
        }
        Spacer()
        Image(systemName: "checkmark.seal")
          .font(.system(size: 26, weight: .ultraLight))
          .foregroundStyle(scene.color)
          .rotationEffect(.degrees(-12))
          .accessibilityLabel("Collected")
      }
      .padding(.horizontal, 5).padding(.top, 16).padding(.bottom, 8)
    }
    .padding(12)
    .background(Color(hex: 0xFFFCF3))
    .overlay(Rectangle().stroke(Paper.edge.opacity(0.6), lineWidth: 1))
    .shadow(color: scene.color.opacity(0.14), radius: 12, x: 0, y: 6)
    .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.97)))
  }

  private var completion: some View {
    VStack(spacing: 16) {
      Text(scene.story).font(.system(.body, design: .serif))
        .multilineTextAlignment(.center).lineSpacing(5)
      VStack(spacing: 10) {
        HStack {
          Text("\(puzzle?.moves ?? 0) moves · a world restored")
          Spacer()
          Text("\(store.saved.completions.count) / 6")
        }
        .font(.caption).foregroundStyle(Paper.muted)
        HStack(spacing: 8) {
          ForEach(Landscape.all) { landscape in
            RoundedRectangle(cornerRadius: 3)
              .fill(store.saved.completions[landscape.id] == nil ? Paper.edge : landscape.color)
              .frame(height: 7)
          }
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(
        "\(puzzle?.moves ?? 0) moves. \(store.saved.completions.count) of six landscapes collected."
      )
    }
  }

  private func start(_ selectedPace: Pace) {
    store.begin(scene.id, pace: selectedPace)
    playing = true
    hinted = false
    guidance = "Tap a piece beside the empty space."
  }

  private func tool(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: icon).font(.system(size: 20))
        Text(title).font(.caption)
      }
      .frame(maxWidth: .infinity).padding(.vertical, 14)
      .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(Paper.edge, lineWidth: 1))
    }
    .buttonStyle(.plain)
  }
}

struct PuzzleBoard: View {
  let scene: Landscape
  let puzzle: Puzzle
  let numbers: Bool
  let hint: Int?
  let move: (Int) -> Void

  var body: some View {
    GeometryReader { geometry in
      let side = geometry.size.width
      let cell = (side - 12) / 3
      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 10).fill(scene.color.opacity(0.09))
        RoundedRectangle(cornerRadius: 5)
          .fill(
            scene.color.opacity(0.11).shadow(
              .inner(color: .black.opacity(0.10), radius: 5, x: 0, y: 3))
          )
          .overlay {
            RoundedRectangle(cornerRadius: 4)
              .strokeBorder(
                scene.color.opacity(0.24), style: StrokeStyle(lineWidth: 1, dash: [3, 4])
              )
              .padding(9)
          }
          .overlay {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
              .font(.system(size: 18, weight: .ultraLight))
              .foregroundStyle(scene.color.opacity(0.6))
          }
          .frame(width: cell, height: cell)
          .position(
            x: CGFloat(puzzle.blank % 3) * (cell + 6) + cell / 2,
            y: CGFloat(puzzle.blank / 3) * (cell + 6) + cell / 2
          )
          .accessibilityLabel(
            "Empty space, row \(puzzle.blank / 3 + 1), column \(puzzle.blank % 3 + 1)")
        ForEach(1...8, id: \.self) { value in
          if let index = puzzle.tiles.firstIndex(of: value) {
            Button {
              move(index)
            } label: {
              PaperTile(
                scene: scene, value: value, cell: cell,
                numbers: numbers, highlighted: hint == index,
                direction: direction(from: index)
              )
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: cell, height: cell)
            .contentShape(Rectangle())
            .position(
              x: CGFloat(index % 3) * (cell + 6) + cell / 2,
              y: CGFloat(index / 3) * (cell + 6) + cell / 2
            )
            .accessibilityLabel(
              "\(hint == index ? "Hint: " : "")Piece \(value), row \(index / 3 + 1), column \(index % 3 + 1)"
            )
            .accessibilityHint(
              puzzle.legalIndices.contains(index)
                ? "Double tap to slide into the empty space" : "Not beside the empty space")
          }
        }
      }
      .overlay {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture { location in
            let grid = BoardGeometry(side: Double(side))
            if let index = grid.index(x: Double(location.x), y: Double(location.y)),
              puzzle.tiles[index] != 0
            {
              move(index)
            }
          }
          .accessibilityHidden(true)
      }
    }
    .aspectRatio(1, contentMode: .fit)
  }

  private func direction(from index: Int) -> String {
    if puzzle.blank / 3 < index / 3 { return "arrow.up" }
    if puzzle.blank / 3 > index / 3 { return "arrow.down" }
    return puzzle.blank < index ? "arrow.left" : "arrow.right"
  }
}

struct PaperTile: View {
  let scene: Landscape
  let value: Int
  let cell: CGFloat
  let numbers: Bool
  let highlighted: Bool
  let direction: String

  var body: some View {
    Image(scene.id).resizable()
      .frame(width: cell * 3, height: cell * 3)
      .offset(
        x: -CGFloat((value - 1) % 3) * cell,
        y: -CGFloat((value - 1) / 3) * cell
      )
      .frame(width: cell, height: cell, alignment: .topLeading)
      .clipped()
      .overlay(alignment: .bottomLeading) {
        if numbers {
          Text("\(value)").font(.system(.caption, design: .monospaced, weight: .medium))
            .foregroundStyle(Paper.ink).padding(7)
            .background(Paper.stock.opacity(0.94), in: Circle()).padding(6)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 5))
      .overlay {
        RoundedRectangle(cornerRadius: 5)
          .stroke(
            highlighted ? Paper.ink : Color.white.opacity(0.4),
            lineWidth: highlighted ? 4 : 1)
      }
      .overlay(alignment: .topTrailing) {
        if highlighted {
          Image(systemName: direction).font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Paper.stock).padding(9)
            .background(Paper.ink, in: Circle()).padding(6)
        }
      }
      .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 3)
  }
}

struct LivingLandscape: View {
  let scene: Landscape
  let living: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var drift = false
  @State private var revealed = false

  var body: some View {
    GeometryReader { geometry in
      Image(scene.id).resizable().scaledToFill()
      if living {
        if !reduceMotion {
          PaperCloud().fill(Color(hex: 0xFFF5DA).opacity(0.4))
            .frame(width: geometry.size.width * 0.25, height: geometry.size.height * 0.06)
            .shadow(color: .black.opacity(0.06), radius: 2, x: 1, y: 2)
            .offset(x: geometry.size.width * (drift ? 0.48 : 0.17), y: geometry.size.height * 0.27)
            .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: drift)
        }
        Rectangle().fill(Paper.stock)
          .frame(width: geometry.size.width / 3, height: geometry.size.height / 3)
          .offset(x: geometry.size.width * 2 / 3, y: geometry.size.height * 2 / 3)
          .opacity(revealed ? 0 : 1)
        Path { path in
          for part in 1...2 {
            let fraction = CGFloat(part) / 3
            path.move(to: CGPoint(x: geometry.size.width * fraction, y: 0))
            path.addLine(to: CGPoint(x: geometry.size.width * fraction, y: geometry.size.height))
            path.move(to: CGPoint(x: 0, y: geometry.size.height * fraction))
            path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * fraction))
          }
        }
        .stroke(Paper.stock, lineWidth: 5)
        .opacity(revealed ? 0 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.8).delay(0.3), value: revealed)
      }
    }
    .clipped()
    .onAppear {
      if living {
        drift = !reduceMotion
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) { revealed = true }
      }
    }
    .accessibilityLabel("\(scene.title), a layered paper landscape")
  }
}

struct PaperCloud: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      path.move(to: CGPoint(x: 0, y: rect.height * 0.9))
      path.addCurve(
        to: CGPoint(x: rect.width * 0.24, y: rect.height * 0.42),
        control1: CGPoint(x: rect.width * 0.01, y: rect.height * 0.35),
        control2: CGPoint(x: rect.width * 0.14, y: rect.height * 0.3))
      path.addCurve(
        to: CGPoint(x: rect.width * 0.66, y: rect.height * 0.32),
        control1: CGPoint(x: rect.width * 0.26, y: -rect.height * 0.12),
        control2: CGPoint(x: rect.width * 0.6, y: -rect.height * 0.13))
      path.addCurve(
        to: CGPoint(x: rect.width, y: rect.height * 0.9),
        control1: CGPoint(x: rect.width * 0.88, y: rect.height * 0.17),
        control2: CGPoint(x: rect.width, y: rect.height * 0.48))
      path.closeSubpath()
    }
  }
}

struct PreviewView: View {
  let scene: Landscape
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 24) {
      HStack {
        Text("THE WHOLE PICTURE").font(.system(.caption2, design: .monospaced)).tracking(1.5)
        Spacer()
        Button("Done") { dismiss() }.frame(minHeight: 44)
      }
      Spacer()
      Image(scene.id).resizable().scaledToFit()
        .shadow(color: scene.color.opacity(0.2), radius: 16, y: 10)
      Text(scene.title).font(.system(.largeTitle, design: .serif))
      Text("The last piece appears when everything finds its place.")
        .font(.body).foregroundStyle(Paper.muted).multilineTextAlignment(.center)
      Spacer()
    }
    .padding(24).background(Paper.stock)
    .presentationDragIndicator(.visible)
  }
}
