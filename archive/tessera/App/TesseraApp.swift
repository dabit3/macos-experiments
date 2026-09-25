import SwiftUI
import UIKit

@main
struct TesseraApp: App {
  @StateObject private var game = GameModel()
  var body: some Scene {
    WindowGroup { ChamberView().environmentObject(game).preferredColorScheme(.dark) }
  }
}

@MainActor
final class GameModel: ObservableObject {
  @Published private(set) var progress: Progress
  @Published var selected: String?
  @Published var saveError = false
  private let saveURL: URL
  var chamber: Chamber { Chambers.all[progress.current] }
  var state: ChamberState { progress.states[chamber.id] ?? ChamberState(chamber: chamber) }
  var trace: Trace { RayTracer.trace(chamber, orientations: state.orientations) }

  init() {
    saveURL = URL.documentsDirectory.appending(path: "tessera-progress.json")
    progress = (try? Data(contentsOf: saveURL)).map(Progress.decode) ?? Progress()
  }

  func rotate(_ optic: Optic) {
    selected = optic.id
    var updated = state
    updated.rotate(optic)
    commit(updated)
    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
  }

  func undo() {
    var updated = state
    updated.undo()
    commit(updated)
    selected = nil
  }

  func reset() {
    var updated = state
    updated.reset(chamber)
    commit(updated)
    selected = nil
  }

  private func commit(_ updated: ChamberState) {
    let wasSolved = trace.solved
    progress.states[chamber.id] = updated
    if trace.solved {
      progress.completed.insert(chamber.id)
      if !wasSolved { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }
    save()
  }

  func open(_ index: Int) {
    guard index >= 0, index <= progress.unlocked else { return }
    progress.current = index
    selected = nil
    save()
  }

  func save() {
    do {
      try progress.encoded().write(to: saveURL, options: .atomic)
      saveError = false
    } catch {
      saveError = true
    }
  }
}

enum Palette {
  static let background = Color(red: 0.025, green: 0.039, blue: 0.06)
  static let muted = Color(red: 0.49, green: 0.57, blue: 0.65)
  static let pearl = Color(red: 0.86, green: 0.94, blue: 0.94)
  static let teal = Color(red: 0.53, green: 0.94, blue: 0.84)
}

extension Spectrum {
  var tint: Color {
    switch self {
    case .white: Palette.pearl
    case .red: Color(red: 1, green: 0.38, blue: 0.47)
    case .green: Color(red: 0.42, green: 1, blue: 0.74)
    case .blue: Color(red: 0.32, green: 0.64, blue: 1)
    }
  }
}

struct ChamberView: View {
  @EnvironmentObject private var game: GameModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var showAtlas = false
  @State private var showHint = false
  @State private var showGuide = false
  private var solved: Bool { game.trace.solved }

  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 720
      VStack(spacing: compact ? 12 : 20) {
        header
        title
        HStack {
          HStack(spacing: 7) {
            ForEach(game.chamber.receivers) { receiver in
              Image(
                systemName: game.trace.powered.contains(receiver.id) ? "diamond.fill" : "diamond"
              )
              .foregroundStyle(receiver.color.tint)
              .shadow(color: receiver.color.tint.opacity(0.5), radius: 6)
            }
            Text("\(game.trace.powered.count) / \(game.chamber.receivers.count) LIT")
              .tracking(1.5).padding(.leading, 5)
          }
          Spacer()
          Text(String(format: "%02d", game.state.moves)).foregroundStyle(Palette.pearl)
          Text("MOVES").tracking(1.5)
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(Palette.muted)
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 5)

        ChamberBoard(
          chamber: game.chamber, state: game.state, trace: game.trace,
          selected: game.selected, rotate: game.rotate
        )
        .id(game.chamber.id)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .frame(maxWidth: 470, maxHeight: .infinity)
        .layoutPriority(1)

        VStack(spacing: 8) {
          HStack(spacing: 6) {
            Circle().fill(solved ? Palette.teal : Palette.muted).frame(width: 4, height: 4)
            Text(solved ? "CHAMBER ILLUMINATED" : "FOLLOW THE LIGHT")
              .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2)
          }.foregroundStyle(solved ? Palette.teal : Palette.muted)
          Text(solved ? "Every path has found its purpose." : game.chamber.lesson)
            .font(.system(size: compact ? 13 : 14)).foregroundStyle(Palette.pearl.opacity(0.8))
            .multilineTextAlignment(.center).frame(minHeight: 32)
            .fixedSize(horizontal: false, vertical: true)
        }
        controls
        if solved {
          Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) {
              if game.chamber.id < 5 { game.open(game.chamber.id + 1) } else { showAtlas = true }
            }
          } label: {
            HStack {
              Text(
                game.chamber.id == 5 ? "Your constellation is complete" : "Enter the next chamber")
              Spacer()
              Image(systemName: "arrow.right")
            }
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 20).frame(height: 48)
            .background(Palette.pearl, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(Palette.background)
          }.accessibilityIdentifier("nextChamber")
        } else {
          HStack(spacing: 5) {
            Image(systemName: "hand.tap")
            Text("TAP AN OPTIC TO ROTATE")
          }
          .font(.system(size: 9, weight: .medium, design: .monospaced))
          .tracking(1.6).foregroundStyle(Palette.muted).frame(height: compact ? 22 : 28)
        }
      }
      .padding(.horizontal, 24).padding(.top, compact ? 8 : 16).padding(.bottom, 10)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background {
        ZStack {
          Palette.background
          RadialGradient(
            colors: [Color(red: 0.08, green: 0.14, blue: 0.17), .clear],
            center: .init(x: 0.7, y: 0.42), startRadius: 0, endRadius: 450)
        }.ignoresSafeArea()
      }
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: solved)
    }
    .sheet(isPresented: $showAtlas) { atlas }
    .sheet(isPresented: $showHint) { hint }
    .sheet(isPresented: $showGuide) { guide }
    .alert("Progress couldn’t be saved", isPresented: $game.saveError) {
      Button("Retry") { game.save() }
      Button("Keep playing", role: .cancel) {}
    } message: {
      Text(
        "Your current game is still in memory. Free some device storage and retry before closing Tessera."
      )
    }
  }

  private var header: some View {
    HStack {
      HStack(spacing: 8) {
        Image(systemName: "diamond").font(.system(size: 16, weight: .light))
          .foregroundStyle(Palette.teal)
        Text("TESSERA").font(.system(size: 15, weight: .semibold)).tracking(5)
      }
      Spacer()
      Button {
        showGuide = true
      } label: {
        Image(systemName: "questionmark").font(.system(size: 14)).frame(width: 38, height: 44)
      }.accessibilityLabel("How to play")
      Button {
        showAtlas = true
      } label: {
        Image(systemName: "square.grid.2x2").font(.system(size: 18, weight: .light))
          .frame(width: 38, height: 44)
      }.accessibilityLabel("Chamber collection").accessibilityIdentifier("chamberCollection")
    }.foregroundStyle(Palette.pearl)
  }

  private var title: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(String(format: "%02d", game.chamber.id + 1)).foregroundStyle(Palette.teal)
        Rectangle().fill(Palette.muted.opacity(0.4)).frame(width: 26, height: 1)
        Text(game.chamber.subtitle).foregroundStyle(Palette.muted)
        Spacer()
        Text("06").foregroundStyle(Palette.muted.opacity(0.6))
      }.font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2)
      Text(game.chamber.title)
        .font(.system(size: 32, weight: .regular, design: .serif))
        .tracking(-0.8).foregroundStyle(Palette.pearl)
        .lineLimit(1).minimumScaleFactor(0.72)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }

  private var controls: some View {
    HStack(spacing: 10) {
      control(
        "Undo", icon: "arrow.uturn.backward", disabled: game.state.history.isEmpty,
        action: game.undo)
      control(
        "Reset", icon: "arrow.counterclockwise",
        disabled: game.state.orientations == game.chamber.initial, action: game.reset)
      control("Hint", icon: "sparkle", action: { showHint = true })
    }
  }

  private func control(
    _ title: String, icon: String, disabled: Bool = false, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: icon)
        Text(title)
      }.font(.system(size: 12, weight: .medium))
        .frame(maxWidth: .infinity).frame(height: 48)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.07), lineWidth: 1))
    }.foregroundStyle(Palette.pearl.opacity(disabled ? 0.25 : 0.9))
      .disabled(disabled).accessibilityIdentifier(title.lowercased())
  }

  private var atlas: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Text("A study in light").font(.system(size: 32, design: .serif))
          Text("\(game.progress.completed.count) OF 6 CHAMBERS ILLUMINATED")
            .font(.system(size: 10, design: .monospaced)).tracking(2).foregroundStyle(Palette.teal)
          ForEach(Chambers.all) { chamber in
            Button {
              withAnimation { game.open(chamber.id) }
              showAtlas = false
            } label: {
              HStack(spacing: 18) {
                Text(String(format: "%02d", chamber.id + 1))
                  .font(.system(size: 22, weight: .light, design: .monospaced))
                  .foregroundStyle(
                    chamber.id <= game.progress.unlocked ? Palette.teal : Palette.muted)
                VStack(alignment: .leading, spacing: 5) {
                  Text(chamber.title).font(.system(size: 18, design: .serif))
                  Text(chamber.subtitle).font(.system(size: 8, design: .monospaced)).tracking(1.5)
                    .foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(
                  systemName: game.progress.completed.contains(chamber.id)
                    ? "diamond.fill"
                    : (chamber.id <= game.progress.unlocked ? "arrow.up.right" : "lock")
                )
                .foregroundStyle(Palette.teal)
              }
              .padding(18).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
              .opacity(chamber.id <= game.progress.unlocked ? 1 : 0.4)
            }.disabled(chamber.id > game.progress.unlocked)
          }
        }.padding(24)
      }.background(Palette.background).foregroundStyle(Palette.pearl)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) { Button("Done") { showAtlas = false } }
        }
    }.tint(Palette.teal)
  }

  private var hint: some View {
    sheet(title: "A little illumination", close: { showHint = false }) {
      Image(systemName: "sparkle").font(.system(size: 36, weight: .ultraLight)).foregroundStyle(
        Palette.teal)
      Text(game.chamber.hint).font(.system(size: 20, design: .serif)).lineSpacing(8)
      Text("A hint changes nothing in the chamber. The next move is yours.")
        .font(.system(size: 13)).foregroundStyle(Palette.muted)
    }.presentationDetents([.medium])
  }

  private var guide: some View {
    sheet(title: "The language of light", close: { showGuide = false }) {
      guideRow(
        "01", title: "Turn, don’t move",
        text:
          "Tap a pearlescent mirror to rotate its face. A / or \\ surface reflects light through a right angle. Optics stay on their pedestals."
      )
      guideRow(
        "02", title: "Find the spectrum",
        text:
          "A prism accepts light only along its arrow. Coral continues straight, jade turns left, and azure turns right relative to the incoming ray."
      )
      guideRow(
        "03", title: "Give each color a home",
        text:
          "A receiver lights only for its exact color. Walls and receivers stop beams. Crossed rays pass through each other."
      )
      guideRow(
        "04", title: "Explore without pressure",
        text:
          "Undo retraces your moves, including Reset. There is no timer. Progress and unfinished chambers save automatically."
      )
    }.presentationDetents([.large])
  }

  private func guideRow(_ number: String, title: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Text(number).font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.teal)
        .padding(.top, 4)
      VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.system(size: 21, design: .serif))
        Text(text).font(.system(size: 14)).foregroundStyle(Palette.muted).lineSpacing(4)
      }
    }
  }

  private func sheet<Content: View>(
    title: String, close: @escaping () -> Void,
    @ViewBuilder content: () -> Content
  ) -> some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          Text(title).font(.system(size: 30, design: .serif))
          content()
        }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
      }.background(Palette.background).foregroundStyle(Palette.pearl)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done", action: close) } }
    }.tint(Palette.teal)
  }
}
