import SwiftUI

struct VesselFrames: PreferenceKey {
  static let defaultValue: [Int: CGRect] = [:]
  static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

struct PourFlight: Equatable {
  let source: Int
  let destination: Int
  let color: Int
}

struct GameView: View {
  let id: Int
  let advance: (Int) -> Void
  @EnvironmentObject private var store: CollectionStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var selected: Int?
  @State private var message = "Tap a vessel, then choose where to pour."
  @State private var isError = false
  @State private var restart = false
  @State private var help = false
  @State private var result = false
  @State private var flight: PourFlight?
  @State private var flightProgress: CGFloat = 0
  @State private var frames: [Int: CGRect] = [:]

  private var study: Study { Study.all[id] }
  private var puzzle: Puzzle { store.puzzle(id) }
  private var columns: Int { puzzle.vessels.count <= 4 ? 2 : (puzzle.vessels.count <= 6 ? 3 : 4) }

  var body: some View {
    ZStack {
      GalleryBackground()
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          HStack {
            CircleControl(icon: "arrow.left", label: "Back to gallery") { dismiss() }
            Spacer()
            Eyebrow(text: "Chroma Cascade")
            Spacer()
            CircleControl(icon: "questionmark", label: "How to play") { help = true }
          }
          (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center))) {
              VStack(alignment: .leading, spacing: 9) {
                Eyebrow(text: Study.chapterNames[study.chapter])
                Text(study.name)
                  .font(.system(.title2, design: .serif))
                  .accessibilityAddTraits(.isHeader)
                HStack(spacing: 7) {
                  if !typeSize.isAccessibilitySize {
                    ForEach(0..<study.pigmentCount, id: \.self) { color in
                      Circle().fill(Gallery.colors[color]).frame(width: 7, height: 7)
                    }
                  }
                  Text("\(study.pigmentCount) pigments")
                    .font(.caption)
                    .foregroundStyle(Gallery.muted)
                }
              }
              if !typeSize.isAccessibilitySize { Spacer() }
              Text(study.number)
                .font(.system(size: 76, weight: .regular, design: .serif))
                .tracking(-4)
                .foregroundStyle(Gallery.accent)
                .accessibilityLabel("Study \(id + 1)")
            }
          HStack {
            Eyebrow(text: "\(puzzle.moves) \(puzzle.moves == 1 ? "pour" : "pours")")
            Spacer()
            Button {
              store.setSymbols(!store.saved.symbols)
            } label: {
              Label(store.saved.symbols ? "Symbols on" : "Symbols off", systemImage: "shapes")
                .font(.caption)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Color symbols")
            .accessibilityValue(store.saved.symbols ? "On" : "Off")
          }
          .overlay(alignment: .bottom) { Rectangle().fill(Gallery.line).frame(height: 1) }
          board
            .padding(.top, 18)
            .padding(.bottom, 10)
          Text(message)
            .font(.subheadline)
            .foregroundStyle(isError ? Gallery.accent : Gallery.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier("pour-feedback")
          (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 14))
            : AnyLayout(HStackLayout(spacing: 14))) {
              actionButton(
                "Undo", icon: "arrow.uturn.backward", disabled: puzzle.moves == 0 || flight != nil
              ) {
                store.undo(id)
                selected = nil
                isError = false
                message = "One step back. A fresh perspective."
              }
              actionButton("Restart", icon: "arrow.clockwise", disabled: flight != nil) {
                restart = true
              }
            }
          if puzzle.isSolved {
            PrimaryButton(title: "View your finished study") { result = true }
          }
        }
        .padding(.horizontal, 26)
        .padding(.top, 10)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
    }
    .foregroundStyle(Gallery.ink)
    .toolbar(.hidden, for: .navigationBar)
    .onAppear {
      store.open(id)
      message =
        puzzle.isSolved
        ? "Every pigment has found its place." : "Tap a vessel, then choose where to pour."
    }
    .alert("Begin this study again?", isPresented: $restart) {
      Button("Restart study", role: .destructive) { resetStudy() }
      Button("Keep arranging", role: .cancel) {}
    } message: {
      Text("Your current arrangement and undo history will be cleared. Your personal best stays.")
    }
    .sheet(isPresented: $help) { instructions }
    .sheet(isPresented: $result) {
      ResultView(id: id) {
        result = false
        let next = (id + 1) % Study.all.count
        store.open(next)
        advance(next)
      } replay: {
        result = false
        resetStudy()
      }
    }
  }

  private var board: some View {
    let rows = stride(from: 0, to: puzzle.vessels.count, by: columns).map {
      Array($0..<min($0 + columns, puzzle.vessels.count))
    }
    return VStack(spacing: 22) {
      ForEach(rows, id: \.self) { row in
        HStack(spacing: columns == 2 ? 52 : 23) {
          ForEach(row, id: \.self) { index in
            Button {
              tap(index)
            } label: {
              VStack(spacing: 13) {
                Vessel(
                  colors: puzzle.vessels[index], symbols: store.saved.symbols,
                  selected: selected == index, height: 133, capacityMarks: true
                )
                .rotationEffect(.degrees(flight?.source == index ? -9 : 0))
                .offset(y: selected == index ? -10 : 0)
                Text(
                  String(format: "%02d", index + 1) + "\n\(puzzle.vessels[index].count)/4"
                )
                .font(.system(.caption2, design: .monospaced))
                .multilineTextAlignment(.center)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(selected == index ? Gallery.accent : Gallery.muted)
              }
              .frame(width: columns == 2 ? 85 : (columns == 3 ? 76 : 62))
              .contentShape(Rectangle())
              .background(
                GeometryReader { proxy in
                  Color.clear.preference(
                    key: VesselFrames.self,
                    value: [index: proxy.frame(in: .named("board"))])
                })
            }
            .buttonStyle(.plain)
            .disabled(flight != nil)
            .accessibilityLabel(vesselDescription(index))
            .accessibilityValue(selected == index ? "Selected" : "")
            .accessibilityHint("Tap to select or pour into this vessel.")
            .accessibilityIdentifier("vessel-\(index + 1)")
          }
        }
        .frame(maxWidth: .infinity)
      }
    }
    .coordinateSpace(name: "board")
    .onPreferenceChange(VesselFrames.self) { frames = $0 }
    .overlay {
      if let flight, let source = frames[flight.source], let target = frames[flight.destination] {
        PourStream(
          start: CGPoint(x: source.midX, y: source.minY),
          end: CGPoint(x: target.midX, y: target.minY),
          progress: flightProgress, color: Gallery.colors[flight.color]
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      }
    }
  }

  private func actionButton(
    _ title: String, icon: String, disabled: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: icon)
        .font(.subheadline.weight(.medium))
        .frame(maxWidth: .infinity, minHeight: 53)
        .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Gallery.line))
        .opacity(disabled ? 0.4 : 1)
    }
    .buttonStyle(.plain)
    .disabled(disabled)
  }

  private func tap(_ index: Int) {
    guard flight == nil else { return }
    if puzzle.isSolved {
      result = true
      return
    }
    guard let source = selected else {
      if puzzle.vessels[index].isEmpty {
        feedback(PourError.empty.rawValue)
      } else {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { selected = index }
        message = "Now tap a matching color or an empty vessel."
        isError = false
      }
      return
    }
    if source == index {
      selected = nil
      message = "Tap a vessel, then choose where to pour."
      isError = false
      return
    }
    do {
      _ = try puzzle.amount(from: source, to: index)
      let color = puzzle.vessels[source].last ?? 0
      if reduceMotion {
        finishPour(source, index)
      } else {
        flight = PourFlight(source: source, destination: index, color: color)
        flightProgress = 0
        withAnimation(.easeInOut(duration: 0.48)) { flightProgress = 1 }
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(500))
          finishPour(source, index)
          flight = nil
        }
      }
    } catch let error as PourError {
      feedback(error.rawValue)
    } catch {
      feedback("This pour is not available.")
    }
  }

  private func finishPour(_ source: Int, _ destination: Int) {
    do {
      _ = try store.pour(id, from: source, to: destination)
      selected = nil
      isError = false
      message = "Beautiful. Keep finding the balance."
      store.feedback(.success)
      if puzzle.isSolved {
        message = "Every pigment has found its place."
        result = true
      }
    } catch {
      feedback("This pour is not available.")
    }
  }

  private func feedback(_ text: String) {
    message = text
    isError = true
    store.feedback(.warning)
  }

  private func resetStudy() {
    store.restart(id)
    selected = nil
    message = "A clean canvas. Take your time."
    isError = false
  }

  private func vesselDescription(_ index: Int) -> String {
    let contents = puzzle.vessels[index]
    if contents.isEmpty { return "Vessel \(index + 1), empty" }
    let names = contents.reversed().map { Gallery.names[$0] }.joined(separator: ", ")
    return "Vessel \(index + 1), \(contents.count) of 4 layers, top to bottom: \(names)"
  }

  private var instructions: some View {
    ZStack {
      GalleryBackground()
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          HStack {
            Eyebrow(text: "A simple ritual")
            Spacer()
            CircleControl(icon: "xmark", label: "Close instructions") { help = false }
          }
          Text("Let color\nfind its place.")
            .font(.system(.largeTitle, design: .serif))
          ForEach(
            Array(
              [
                (
                  "01", "Choose a vessel", "Tap any vessel with color. Tap it again to set it down."
                ),
                (
                  "02", "Make a little room",
                  "Pour onto the same top color or into an empty vessel. Each holds four layers; matching top layers move together."
                ),
                (
                  "03", "Find the balance",
                  "Finish with one color in each full vessel. Empty vessels are welcome. Undo and restart are always yours."
                ),
              ].enumerated()), id: \.offset
          ) { _, item in
            HStack(alignment: .top, spacing: 18) {
              Text(item.0).font(.system(.title2, design: .serif)).foregroundStyle(Gallery.accent)
              VStack(alignment: .leading, spacing: 9) {
                Text(item.1).font(.headline)
                Text(item.2).font(.body).foregroundStyle(Gallery.muted)
              }
            }
          }
          PrimaryButton(title: "Find my flow") { help = false }
        }
        .padding(28)
      }
    }
    .foregroundStyle(Gallery.ink)
  }
}

struct PourStream: View, Animatable {
  let start: CGPoint
  let end: CGPoint
  var progress: CGFloat
  let color: Color

  nonisolated var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  var body: some View {
    Canvas { context, _ in
      let control = CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) - 55)
      var path = Path()
      path.move(to: start)
      path.addQuadCurve(to: end, control: control)
      let segment = path.trimmedPath(from: max(0, progress - 0.28), to: progress)
      context.stroke(
        segment, with: .color(color.opacity(0.8)), style: StrokeStyle(lineWidth: 7, lineCap: .round)
      )
      context.stroke(
        segment, with: .color(.white.opacity(0.35)),
        style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
  }
}

struct ResultView: View {
  let id: Int
  let next: () -> Void
  let replay: () -> Void
  @EnvironmentObject private var store: CollectionStore

  var body: some View {
    ZStack {
      GalleryBackground()
      ScrollView {
        VStack(spacing: 22) {
          Eyebrow(text: "Study \(Study.all[id].number) / complete")
            .padding(.top, 40)
          HStack(alignment: .bottom, spacing: 16) {
            ForEach(0..<Study.all[id].pigmentCount, id: \.self) { pigment in
              Vessel(
                colors: Array(repeating: pigment, count: 4),
                symbols: store.saved.symbols, height: pigment.isMultiple(of: 2) ? 113 : 133
              )
              .frame(width: Study.all[id].pigmentCount > 3 ? 43 : 58)
            }
          }
          .padding(.vertical, 20)
          Text("In perfect\nbalance.")
            .font(.system(size: 46, design: .serif))
            .tracking(-1.5)
            .multilineTextAlignment(.center)
          Text("A small moment of order, beautifully made.")
            .font(.subheadline)
            .foregroundStyle(Gallery.muted)
            .multilineTextAlignment(.center)
          HStack(spacing: 42) {
            VStack(spacing: 7) {
              Text("\(store.puzzle(id).moves)").font(.system(size: 32, design: .serif))
              Eyebrow(text: "Pours")
            }
            Rectangle().fill(Gallery.line).frame(width: 1, height: 44)
            VStack(spacing: 7) {
              Text("\(store.saved.bestMoves[id] ?? 0)").font(.system(size: 32, design: .serif))
              Eyebrow(text: "Personal best")
            }
          }
          .padding(.vertical, 10)
          PrimaryButton(
            title: id == 11
              ? "Return to the first study" : "Next study · \(Study.all[id + 1].number)",
            action: next)
          Button("Arrange this one again", action: replay)
            .font(.subheadline)
            .frame(minHeight: 48)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 30)
      }
    }
    .foregroundStyle(Gallery.ink)
  }
}
