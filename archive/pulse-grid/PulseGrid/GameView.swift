import SwiftUI
import UIKit

struct GameView: View {
  let level: CircuitLevel
  let next: (Int) -> Void
  @State private var session: CircuitSession
  @EnvironmentObject private var store: ProgressStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var showReset = false
  @State private var showGuide = false
  @State private var hintIndex: Int?

  init(level: CircuitLevel, initialSession: CircuitSession, next: @escaping (Int) -> Void) {
    self.level = level
    self.next = next
    _session = State(initialValue: initialSession)
  }

  private var network: [Int: Int] { level.connected(turns: session.turns) }
  private var received: Int { level.receivers.filter { network[$0] != nil }.count }
  private var solved: Bool { received == level.receiverCount }
  private var pinCompletion: Bool { dynamicTypeSize <= .xLarge }

  var body: some View {
    ZStack {
      InstrumentBackground()
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          HStack {
            Button {
              dismiss()
            } label: {
              HStack(spacing: 8) {
                Image(systemName: "arrow.left")
                Text("Circuits")
                  .fixedSize()
              }
              .font(.system(.subheadline, weight: .medium))
              .foregroundStyle(Palette.ink)
              .frame(minHeight: 44)
            }
            Spacer()
            if !dynamicTypeSize.isAccessibilitySize {
              MicroLabel(text: String(format: "CIRCUIT %02d / 10", level.id + 1))
            }
            IconButton(symbol: "questionmark", label: "How to play") { showGuide = true }
          }
          VStack(alignment: .leading, spacing: 10) {
            MicroLabel(
              text: dynamicTypeSize.isAccessibilitySize
                ? String(format: "%02d / 10 · %@", level.id + 1, level.complexity)
                : level.complexity,
              color: Palette.mint)
            Text(level.name)
              .font(.system(.largeTitle, design: .rounded, weight: .light))
              .foregroundStyle(Palette.ink)
              .accessibilityAddTraits(.isHeader)
            Text(level.subtitle)
              .font(.system(.subheadline))
              .foregroundStyle(Palette.muted)
          }
          statistics
          board
          HStack(spacing: 8) {
            Circle().fill(solved ? Palette.mint : Palette.coral).frame(width: 6, height: 6)
            MicroLabel(
              text: solved ? "ALL RECEIVERS ONLINE" : "TAP A TILE TO ROTATE",
              color: solved ? Palette.mint : Palette.muted)
            Spacer()
            MicroLabel(text: "\(level.size) × \(level.size)")
          }
          .padding(.top, -9)
          if solved && !pinCompletion {
            completion
              .padding(18)
              .background(Palette.panel.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
          }
          if !solved {
            VStack(spacing: 14) {
              actionLayout {
                ActionButton(title: "Reset", symbol: "arrow.counterclockwise") { showReset = true }
                ActionButton(title: "Hint", symbol: "sparkle") { giveHint() }
              }
              Text(
                hintIndex == nil
                  ? "Connect the mint source to every coral receiver."
                  : "One tile aligned. Follow the current from the source."
              )
              .font(.system(.footnote))
              .foregroundStyle(Palette.muted)
              .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 20)
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if solved && pinCompletion {
        completion
          .padding(.horizontal, 24)
          .padding(.top, 16)
          .padding(.bottom, 12)
          .background {
            Palette.background
              .overlay(alignment: .top) {
                Rectangle().fill(Palette.mint.opacity(0.25)).frame(height: 1)
              }
              .ignoresSafeArea(edges: .bottom)
          }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .onAppear { store.save(session, for: level) }
    .sheet(isPresented: $showGuide) { GuideView(allowErase: false) }
    .confirmationDialog("Reset this circuit?", isPresented: $showReset, titleVisibility: .visible) {
      Button("Reset circuit", role: .destructive) {
        session = CircuitSession(level: level)
        hintIndex = nil
        store.save(session, for: level)
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Current rotations and hints will reset. Your completed-circuit record stays saved.")
    }
  }

  private var statistics: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 24) {
        receivers.fixedSize()
        Spacer(minLength: 0)
        metric("TURNS", value: session.moves).fixedSize()
        metric("HINTS", value: session.hints).fixedSize()
      }
      VStack(alignment: .leading, spacing: 14) {
        receivers
        HStack(spacing: 32) {
          metric("TURNS", value: session.moves)
          metric("HINTS", value: session.hints)
        }
      }
    }
    .padding(.horizontal, 4)
  }

  private var receivers: some View {
    VStack(alignment: .leading, spacing: 7) {
      MicroLabel(text: "RECEIVERS")
      HStack(spacing: 7) {
        ForEach(level.receivers, id: \.self) { receiver in
          Image(systemName: network[receiver] == nil ? "diamond" : "diamond.fill")
            .font(.system(size: 14))
            .foregroundStyle(network[receiver] == nil ? Palette.coral : Palette.mint)
        }
        Text("\(received)/\(level.receiverCount)")
          .font(.system(.subheadline, design: .monospaced))
          .foregroundStyle(Palette.ink)
          .padding(.leading, 4)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(received) of \(level.receiverCount) receivers powered")
  }

  private func metric(_ title: String, value: Int) -> some View {
    VStack(alignment: .trailing, spacing: 7) {
      MicroLabel(text: title)
      Text(String(format: "%02d", value))
        .font(.system(.title3, design: .monospaced, weight: .light))
        .foregroundStyle(Palette.ink)
        .contentTransition(.numericText())
    }
    .accessibilityElement(children: .combine)
  }

  private var board: some View {
    LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: level.size), spacing: 7
    ) {
      ForEach(level.masks.indices, id: \.self) { index in
        if level.isRotatable(index) {
          Button {
            rotate(index)
          } label: {
            TileView(
              level: level, index: index, turns: session.turns[index],
              distance: network[index], hint: hintIndex == index)
          }
          .buttonStyle(.plain)
          .allowsHitTesting(!solved)
          .accessibilityLabel(tileLabel(index))
          .accessibilityHint(
            solved ? "Circuit complete. Reset to play again." : "Rotates clockwise one quarter turn"
          )
        } else {
          TileView(
            level: level, index: index, turns: session.turns[index],
            distance: network[index], hint: false
          )
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(tileLabel(index))
        }
      }
    }
    .padding(10)
    .background(Palette.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 24))
    .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(Palette.line, lineWidth: 1) }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Circuit board")
  }

  private var completion: some View {
    VStack(alignment: .leading, spacing: 10) {
      completionLayout {
        VStack(alignment: .leading, spacing: 6) {
          Text("Signal locked.")
            .font(.system(.title2, design: .rounded, weight: .medium))
            .foregroundStyle(Palette.mint)
          Text(
            "\(session.moves) rotations · \(session.hints == 0 ? "No hints" : "\(session.hints) hint\(session.hints == 1 ? "" : "s")")"
          )
          .font(.system(.footnote, design: .monospaced))
          .foregroundStyle(Palette.muted)
        }
        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
        Button {
          showReset = true
        } label: {
          Label("Replay", systemImage: "arrow.counterclockwise")
            .font(.system(.subheadline, weight: .medium))
            .fixedSize()
            .foregroundStyle(Palette.mint)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Palette.panel, in: Capsule())
        }
        .accessibilityLabel("Play again")
      }
      ActionButton(
        title: level.id == 9 ? "Back to circuits" : "Next circuit",
        symbol: "arrow.right", primary: true
      ) {
        if level.id == 9 { dismiss() } else { next(level.id + 1) }
      }
    }
    .accessibilityElement(children: .contain)
  }

  private var completionLayout: AnyLayout {
    !pinCompletion
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
      : AnyLayout(HStackLayout(alignment: .center))
  }

  private var actionLayout: AnyLayout {
    dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: 12))
      : AnyLayout(HStackLayout(spacing: 12))
  }

  private func rotate(_ index: Int) {
    guard !solved else { return }
    hintIndex = nil
    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72)) {
      session.rotate(index, in: level)
    }
    changed()
  }

  private func giveHint() {
    withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) {
      hintIndex = session.hint(in: level)
    }
    changed()
  }

  private func changed() {
    store.save(session, for: level)
    if store.data.haptics {
      if solved {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      } else {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
      }
    }
    if solved {
      UIAccessibility.post(
        notification: .announcement, argument: "Signal locked. All receivers online.")
    }
  }

  private func tileLabel(_ index: Int) -> String {
    let position = "Row \(index / level.size + 1), column \(index % level.size + 1)"
    if level.masks[index] == 0 { return "\(position), blocked cell" }
    let role =
      index == level.source
      ? "Fixed power source" : (level.receivers.contains(index) ? "Fixed receiver" : "Tile")
    let ports = Direction.allCases.filter {
      level.mask(at: index, turns: session.turns) & $0.bit != 0
    }.map { String(describing: $0) }.joined(separator: ", ")
    return
      "\(position), \(role), \(network[index] != nil ? "powered" : "unpowered"), connects \(ports)"
  }
}
