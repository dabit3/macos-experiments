import SwiftUI
import UIKit

@main
struct EmberpathApp: App {
  @StateObject private var store = GameStore()
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(store)
        .preferredColorScheme(.dark)
        .tint(Palette.amber)
    }
  }
}

struct ContentView: View {
  @EnvironmentObject private var store: GameStore
  @State private var playing = false
  @State private var guide = false
  @State private var settings = false

  var body: some View {
    ZStack {
      Palette.background.ignoresSafeArea()
      if playing, let journey = store.archive.journey {
        RoomView(journey: journey, onClose: { playing = false }, onGuide: { guide = true })
      } else {
        home
      }
    }
    .sheet(isPresented: $guide) { GuideView() }
    .sheet(isPresented: $settings) { SettingsView() }
  }

  private var home: some View {
    ScrollView {
      VStack(spacing: 0) {
        HStack {
          Text("A SMALL JOURNEY THROUGH THE DARK")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(Palette.muted)
          Spacer(minLength: 4)
          Button {
            settings = true
          } label: {
            Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
          }
          .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 24)
        Text("Emberpath")
          .font(.system(size: 51, weight: .regular, design: .serif))
          .tracking(-2)
          .foregroundStyle(Palette.cream)
        Text("CARRY A LITTLE LIGHT.")
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .tracking(3)
          .foregroundStyle(Palette.amber)
          .padding(.top, 7)
        LanternArt()
          .frame(height: 220)
          .padding(.horizontal, 20)
          .padding(.top, 4)
        VStack(spacing: 14) {
          Button {
            if store.archive.journey == nil || store.archive.journey?.turn.outcome != .exploring {
              store.start(Room.all[store.archive.unlocked])
            }
            playing = true
          } label: {
            HStack {
              Image(systemName: "flame")
              Text(
                store.archive.journey?.turn.outcome == .exploring
                  ? "Continue the journey" : "Enter the dark")
              Spacer()
              Image(systemName: "arrow.right")
            }
          }
          .buttonStyle(AmberButton())
          Button("How to carry the light") { guide = true }
            .font(.subheadline)
            .foregroundStyle(Palette.muted)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 28)
        HStack {
          Text("THE EIGHT CHAMBERS").tracking(2)
          Spacer()
          Text("\(store.archive.bestMoves.count) / 8 ESCAPED").monospacedDigit()
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(Palette.muted)
        .padding(.horizontal, 28)
        .padding(.top, 25)
        .padding(.bottom, 8)
        HStack(spacing: 5) {
          ForEach(Room.all) { room in
            Capsule()
              .fill(store.archive.bestMoves[room.id] != nil ? Palette.amber : Palette.stone)
              .frame(height: 3)
          }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 5)
        .accessibilityHidden(true)
        VStack(spacing: 0) {
          ForEach(Room.all) { room in
            chapterRow(room)
          }
        }
        .padding(.horizontal, 28)
        Text("No rush. Only the next step.")
          .font(.system(.footnote, design: .serif).italic())
          .foregroundStyle(Palette.muted)
          .padding(.vertical, 30)
      }
    }
    .scrollIndicators(.hidden)
  }

  private func chapterRow(_ room: Room) -> some View {
    let unlocked = room.id <= store.archive.unlocked
    let finished = store.archive.bestMoves[room.id]
    return Button {
      store.start(room)
      playing = true
    } label: {
      HStack(spacing: 17) {
        Text(room.chapter)
          .font(.system(size: 15, design: .serif))
          .foregroundStyle(unlocked ? Palette.amber : Palette.muted.opacity(0.6))
          .frame(width: 25)
        VStack(alignment: .leading, spacing: 5) {
          Text(room.title)
            .font(.system(.title3, design: .serif))
            .foregroundStyle(unlocked ? Palette.cream : Palette.muted)
          Text(finished.map { "Light carried · best \($0) steps" } ?? room.subtitle)
            .font(.caption)
            .foregroundStyle(Palette.muted)
        }
        Spacer(minLength: 4)
        Image(systemName: finished != nil ? "checkmark" : unlocked ? "arrow.up.right" : "lock")
          .font(.system(size: 13))
          .foregroundStyle(unlocked ? Palette.amber : Palette.muted)
      }
      .padding(.vertical, 19)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(alignment: .bottom) {
        Rectangle().fill(Palette.muted.opacity(0.15)).frame(height: 1)
      }
    }
    .disabled(!unlocked)
    .accessibilityLabel(
      "Chapter \(room.id + 1), \(room.title), \(unlocked ? "unlocked" : "locked")")
  }
}

struct RoomView: View {
  @EnvironmentObject private var store: GameStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let journey: Journey
  let onClose: () -> Void
  let onGuide: () -> Void
  @State private var restartConfirmation = false

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        HStack(spacing: 4) {
          Button(action: onClose) {
            Label("Chambers", systemImage: "chevron.left").font(.subheadline)
          }
          .frame(minHeight: 44)
          Spacer()
          Text("CHAPTER \(journey.room.chapter)")
            .font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1.8)
            .foregroundStyle(Palette.muted)
          Button(action: onGuide) { Image(systemName: "questionmark").frame(width: 44, height: 44) }
            .accessibilityLabel("How to play")
        }
        .padding(.horizontal, 22)
        ScrollView {
          VStack(spacing: 12) {
            VStack(spacing: 4) {
              Text(journey.room.title)
                .font(.system(.title, design: .serif))
                .foregroundStyle(Palette.cream)
              Text(journey.room.subtitle).font(.caption).foregroundStyle(Palette.muted)
            }
            if journey.turn.outcome == .exploring {
              lightMeter
            }
            HStack {
              Text(
                journey.turn.outcome == .exploring
                  ? (dynamicTypeSize.isAccessibilitySize
                    ? "Use arrows to move · scroll to explore"
                    : "Swipe to move · or tap the arrows")
                  : "YOUR PATH THROUGH THE DARK"
              )
              .font(.caption)
              Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.muted)
            DungeonView(journey: journey)
              .frame(
                maxHeight: journey.turn.outcome == .exploring
                  ? max(200, geometry.size.height - 425) : min(280, geometry.size.height * 0.36)
              )
              .padding(8)
              .background(Palette.background)
              .overlay {
                RoundedRectangle(cornerRadius: 12).stroke(Palette.muted.opacity(0.18), lineWidth: 1)
              }
              .gesture(
                DragGesture(minimumDistance: 25).onEnded { value in
                  if abs(value.translation.width) > abs(value.translation.height) {
                    move(value.translation.width > 0 ? .right : .left)
                  } else {
                    move(value.translation.height > 0 ? .down : .up)
                  }
                },
                including: dynamicTypeSize.isAccessibilitySize ? .none : .all
              )
            if journey.turn.outcome == .exploring {
              let layout =
                dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout())
              layout {
                Label("\(journey.turn.keys) key", systemImage: "key.horizontal")
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Label("\(collectedEmbers)/\(journey.room.embers) embers", systemImage: "diamond")
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text("\(journey.turn.moves) steps")
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(Palette.muted)
            }
            if journey.turn.outcome == .exploring {
              Text(store.message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.cream)
                .frame(maxWidth: .infinity, minHeight: 36)
                .accessibilityIdentifier("journey-message")
            } else {
              result
            }
          }
          .padding(.horizontal, 24)
          .padding(.top, 6)
          .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        if journey.turn.outcome == .exploring {
          HStack(alignment: .center, spacing: 8) {
            Button {
              store.undo()
            } label: {
              VStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward").font(.title3)
                Text("Undo").font(.caption).lineLimit(1).minimumScaleFactor(0.6)
              }
              .frame(maxWidth: .infinity, minHeight: 64)
            }
            .disabled(journey.history.isEmpty)
            controls
            Button {
              restartConfirmation = true
            } label: {
              VStack(spacing: 8) {
                Image(systemName: "arrow.clockwise").font(.title3)
                Text("Restart").font(.caption).lineLimit(1).minimumScaleFactor(0.6)
              }
              .frame(maxWidth: .infinity, minHeight: 64)
            }
          }
          .foregroundStyle(Palette.muted)
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(Palette.background)
          .overlay(alignment: .top) {
            Rectangle().fill(Palette.muted.opacity(0.15)).frame(height: 1).padding(.horizontal, 24)
          }
        }
      }
    }
    .confirmationDialog(
      "Start this chamber again?", isPresented: $restartConfirmation, titleVisibility: .visible
    ) {
      Button("Restart chamber", role: .destructive) { store.restart() }
      Button("Keep exploring", role: .cancel) {}
    } message: {
      Text("Your current steps will be cleared. Unlocked chapters stay yours.")
    }
  }

  private var collectedEmbers: Int {
    journey.turn.collected.filter { journey.room.tile(at: $0) == "e" }.count
  }

  private var lightMeter: some View {
    VStack(spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Label("LANTERN", systemImage: "flame.fill")
          .font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1.7)
        Spacer()
        Text("\(journey.turn.light)")
          .font(.system(size: 26, weight: .regular, design: .serif)).monospacedDigit()
        Text("light left").font(.caption).foregroundStyle(Palette.muted)
      }
      .foregroundStyle(
        journey.turn.light <= 3 && journey.turn.outcome != .escaped
          ? Color(red: 1, green: 0.43, blue: 0.3) : Palette.amber)
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(Palette.stone.opacity(0.6))
          Capsule().fill(
            LinearGradient(
              colors: [Palette.gold, Palette.amber],
              startPoint: .leading, endPoint: .trailing)
          )
          .frame(
            width: geometry.size.width * CGFloat(journey.turn.light) / CGFloat(Journey.capacity))
        }
      }
      .frame(height: 4)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "Lantern, \(journey.turn.light) light remaining. Each step costs one; embers restore six.")
  }

  private var controls: some View {
    VStack(spacing: 4) {
      directionButton(.up)
      HStack(spacing: 4) {
        directionButton(.left)
        Image(systemName: "sparkle")
          .foregroundStyle(Palette.gold)
          .frame(width: 48, height: 44)
          .accessibilityHidden(true)
        directionButton(.right)
      }
      directionButton(.down)
    }
  }

  private func directionButton(_ direction: Direction) -> some View {
    Button {
      move(direction)
    } label: {
      Image(systemName: direction.symbol)
        .font(.system(size: 20, weight: .medium))
        .foregroundStyle(Palette.cream)
        .frame(width: 56, height: 44)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
          RoundedRectangle(cornerRadius: 16).stroke(Palette.muted.opacity(0.25), lineWidth: 1)
        }
    }
    .buttonStyle(DirectionButtonStyle())
    .accessibilityLabel("Move \(direction.rawValue)")
    .accessibilityIdentifier("move-\(direction.rawValue)")
  }

  private func move(_ direction: Direction) {
    let previous = journey.turn.moves
    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { store.move(direction) }
    if store.archive.haptics {
      if store.archive.journey?.turn.moves == previous {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
      } else {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
      }
    }
  }

  private var result: some View {
    let won = journey.turn.outcome == .escaped
    return VStack(spacing: 14) {
      Text(won ? "CHAMBER CLEARED" : "THE LIGHT HAS FADED")
        .font(.system(.caption2, design: .monospaced)).tracking(2)
        .foregroundStyle(Palette.amber)
      Text(won ? "You carried the light." : "Even embers need rest.")
        .font(.system(.title2, design: .serif))
        .foregroundStyle(Palette.cream)
      if won {
        HStack(spacing: 30) {
          resultStat("\(journey.turn.light)", label: "LIGHT SAVED")
          Rectangle().fill(Palette.gold.opacity(0.4)).frame(width: 1, height: 35)
          resultStat("\(journey.turn.moves)", label: "STEPS TAKEN")
        }
        .frame(maxWidth: .infinity)
        Text(
          journey.roomID == 7
            ? "All eight chambers escaped. The dawn is yours."
            : "Chapter \(Room.all[journey.roomID + 1].chapter) · \(Room.all[journey.roomID + 1].title) is unlocked."
        )
        .font(.footnote).foregroundStyle(Palette.cream).multilineTextAlignment(.center)
      } else {
        Text("Retrace a step or try a new path.\nNothing is lost by trying again.")
          .font(.subheadline).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
      }
      Button {
        if won, journey.roomID < Room.all.count - 1 {
          store.start(Room.all[journey.roomID + 1])
        } else if won {
          onClose()
        } else {
          store.restart()
        }
      } label: {
        HStack {
          Text(
            won
              ? (journey.roomID == 7 ? "Return to the chambers" : "Enter the next chamber")
              : "Rekindle & retry")
          Spacer()
          Image(systemName: "arrow.right")
        }
      }
      .buttonStyle(AmberButton())
      if !won {
        Button("Undo the last step") { store.undo() }.frame(minHeight: 44)
      } else {
        Button("View the chambers", action: onClose).frame(minHeight: 44)
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity)
    .background(
      LinearGradient(
        colors: [Palette.gold.opacity(won ? 0.18 : 0.07), Palette.panel],
        startPoint: .top, endPoint: .bottom),
      in: RoundedRectangle(cornerRadius: 20)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 20).stroke(Palette.gold.opacity(0.3), lineWidth: 1)
    }
  }

  private func resultStat(_ value: String, label: String) -> some View {
    VStack(spacing: 4) {
      Text(value).font(.system(.largeTitle, design: .serif)).foregroundStyle(Palette.amber)
      Text(label).font(.system(.caption2, design: .monospaced)).foregroundStyle(Palette.muted)
        .lineLimit(1).minimumScaleFactor(0.6)
    }
  }
}

struct AmberButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(.subheadline, weight: .semibold))
      .foregroundStyle(Palette.background)
      .padding(.horizontal, 20)
      .frame(minHeight: 56)
      .background(
        configuration.isPressed ? Palette.gold : Palette.amber,
        in: RoundedRectangle(cornerRadius: 15))
  }
}

struct DirectionButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .brightness(configuration.isPressed ? 0.12 : 0)
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
  }
}

struct GuideView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Text("The dark can wait.\nYour light cannot.")
            .font(.system(.title, design: .serif)).foregroundStyle(Palette.cream)
          LazyVGrid(
            columns: Array(
              repeating: GridItem(.flexible()),
              count: dynamicTypeSize.isAccessibilitySize ? 2 : 4), spacing: 18
          ) {
            guideSymbol("e", title: "+6 light")
            guideSymbol("k", title: "Key")
            guideSymbol("D", title: "Door")
            guideSymbol("X", title: "Exit")
          }
          .padding(.vertical, 14)
          .background(Palette.panel, in: RoundedRectangle(cornerRadius: 16))
          rule(
            "01", title: "One step. One light.",
            text:
              "Tap the arrows to move. Every successful move costs one light. Bumping into stone costs nothing."
          )
          rule(
            "02", title: "Follow the embers.",
            text:
              "Amber diamonds restore six light, up to eighteen. They can only be gathered once. New ground appears as you explore."
          )
          rule(
            "03", title: "A key. A door. A way out.",
            text:
              "Golden keys open sealed doors. Reach the glowing arch with at least one light remaining to escape."
          )
          rule(
            "04", title: "Leave no hope behind.",
            text:
              "Undo restores your previous position, light and items. Restart a chamber whenever you like. There is no timer."
          )
          Button {
            dismiss()
          } label: {
            Text("I'll carry the light").frame(maxWidth: .infinity)
          }
          .buttonStyle(AmberButton())
        }
        .padding(28)
      }
      .background(Palette.background)
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
    .preferredColorScheme(.dark)
  }

  private func guideSymbol(_ symbol: Character, title: String) -> some View {
    VStack(spacing: 10) {
      Canvas { context, size in
        Artwork.item(&context, value: symbol, rect: CGRect(origin: .zero, size: size))
      }
      .frame(width: 34, height: 34)
      .accessibilityHidden(true)
      Text(title).font(.caption).foregroundStyle(Palette.cream)
    }
    .frame(maxWidth: .infinity)
  }

  private func rule(_ number: String, title: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Text(number).font(.system(.subheadline, design: .monospaced)).foregroundStyle(Palette.amber)
      VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.system(.title3, design: .serif)).foregroundStyle(Palette.cream)
        Text(text).font(.subheadline).foregroundStyle(Palette.muted).fixedSize(
          horizontal: false, vertical: true)
      }
    }
  }
}

struct SettingsView: View {
  @EnvironmentObject private var store: GameStore
  @Environment(\.dismiss) private var dismiss
  @State private var confirm = false
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text("By lantern light")
            .font(.system(.largeTitle, design: .serif)).foregroundStyle(Palette.cream)
          VStack(alignment: .leading, spacing: 16) {
            Text("The way you wander")
              .font(.system(.title2, design: .serif)).foregroundStyle(Palette.cream)
            Toggle(
              "Gentle haptics", isOn: Binding(get: { store.archive.haptics }, set: store.setHaptics)
            )
            Text("Emberpath follows your device’s text size and Reduce Motion settings.")
              .font(.footnote).foregroundStyle(Palette.muted)
          }
          .padding(20)
          .background(Palette.panel, in: RoundedRectangle(cornerRadius: 18))
          VStack(alignment: .leading, spacing: 16) {
            Text("Your journal")
              .font(.system(.title2, design: .serif)).foregroundStyle(Palette.cream)
            LabeledContent("Chambers escaped", value: "\(store.archive.bestMoves.count) of 8")
            Text(
              "Your steps, gathered items and unlocked chapters are saved on this device after every move."
            )
            .font(.footnote).foregroundStyle(Palette.muted)
            Button("Erase all progress", role: .destructive) { confirm = true }.frame(minHeight: 44)
          }
          .padding(20)
          .background(Palette.panel, in: RoundedRectangle(cornerRadius: 18))
          VStack(alignment: .leading, spacing: 14) {
            Text(
              "Eight small rooms. One stubborn spark.\nMade for a quiet moment, wherever you are."
            )
            .font(.system(.body, design: .serif))
            .foregroundStyle(Palette.cream)
            Text("Emberpath · 1.0\nNo accounts, ads, or network connection.")
              .font(.footnote).foregroundStyle(Palette.muted)
          }
          .padding(.horizontal, 4)
        }
        .padding(24)
      }
      .background(Palette.background)
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
      .alert("Erase your journey?", isPresented: $confirm) {
        Button("Erase progress", role: .destructive) { store.reset() }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("All unlocked chambers, records and your current journey will be removed.")
      }
    }
    .preferredColorScheme(.dark)
  }
}
