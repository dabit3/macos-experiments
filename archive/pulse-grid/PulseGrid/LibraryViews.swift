import SwiftUI

struct ProgressViewScreen: View {
  @EnvironmentObject private var store: ProgressStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      InstrumentBackground()
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          VStack(alignment: .leading, spacing: 8) {
            Text("A little more\nconnected.")
              .font(.system(.largeTitle, design: .rounded, weight: .light))
              .foregroundStyle(Palette.ink)
            Text("Every circuit you bring to life stays here.")
              .font(.subheadline)
              .foregroundStyle(Palette.muted)
          }
          HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(String(format: "%02d", store.completedCount))
              .font(.system(size: 76, weight: .ultraLight, design: .rounded))
              .foregroundStyle(Palette.mint)
            Text("/ 10")
              .font(.system(.title2, design: .monospaced, weight: .light))
              .foregroundStyle(Palette.muted)
            Spacer()
            MicroLabel(text: "CIRCUITS\nPOWERED")
          }
          HStack(spacing: 6) {
            ForEach(Circuits.all) { level in
              Capsule()
                .fill(store.data.completions[level.id] == nil ? Palette.line : Palette.mint)
                .frame(height: 5)
            }
          }
          .accessibilityHidden(true)
          VStack(spacing: 0) {
            ForEach(Circuits.all) { level in
              HStack(spacing: 15) {
                Image(
                  systemName: store.data.completions[level.id] == nil
                    ? "circle" : "checkmark.circle.fill"
                )
                .foregroundStyle(
                  store.data.completions[level.id] == nil ? Palette.line : Palette.mint)
                VStack(alignment: .leading, spacing: 5) {
                  Text(level.name).foregroundStyle(Palette.ink)
                  if let record = store.data.completions[level.id] {
                    Text(
                      "\(record.moves) turns · \(record.hints == 0 ? "unassisted" : "\(record.hints) hints")"
                    )
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                  } else {
                    Text("Awaiting a connection")
                      .font(.caption)
                      .foregroundStyle(Palette.muted)
                  }
                }
                Spacer()
                MicroLabel(text: String(format: "%02d", level.id + 1))
              }
              .padding(.vertical, 17)
              Divider().overlay(Palette.line)
            }
          }
          Text("Your best run favors fewer hints, then fewer rotations. There’s no time limit.")
            .font(.footnote)
            .foregroundStyle(Palette.muted)
        }
        .padding(24)
      }
    }
    .safeAreaInset(edge: .top, spacing: 0) {
      SheetHeader(title: "SIGNAL ARCHIVE", closeLabel: "Close progress") { dismiss() }
    }
  }
}

struct GuideView: View {
  var allowErase = true
  @EnvironmentObject private var store: ProgressStore
  @Environment(\.dismiss) private var dismiss
  @State private var confirmErase = false

  var body: some View {
    ZStack {
      InstrumentBackground()
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          Text("Turn. Connect.\nCome alive.")
            .font(.system(.largeTitle, design: .rounded, weight: .light))
            .foregroundStyle(Palette.ink)
          HeroCircuit().frame(height: 135).padding(.horizontal, 10)
          guideStep(
            "01", title: "Give the current a path.",
            text:
              "Tap any circuit tile to rotate it clockwise. Both neighboring ends must meet for power to flow."
          )
          guideStep(
            "02", title: "Reach every receiver.",
            text:
              "The mint bolt is your source. Coral diamonds are receivers. These terminals stay fixed; connect all of them to complete the circuit."
          )
          guideStep(
            "03", title: "Take the long way.",
            text:
              "Branches and loops are welcome. Dark cells are blocked. There’s no timer and no penalty for exploring."
          )
          guideStep(
            "04", title: "A nudge, if you need one.",
            text:
              "Hint aligns one tile to a working route. Hints are counted separately. Reset restores the starting layout, while keeping your completion record."
          )
          Toggle(
            "Haptic feedback",
            isOn: Binding(get: { store.data.haptics }, set: { store.setHaptics($0) })
          )
          .foregroundStyle(Palette.ink)
          .padding(.vertical, 10)
          VStack(alignment: .leading, spacing: 10) {
            MicroLabel(text: "ON THIS DEVICE")
            Text(
              "Circuits, rotations and progress save automatically. No account. No connection required."
            )
            .font(.footnote)
            .foregroundStyle(Palette.muted)
            if allowErase {
              Button("Erase all progress", role: .destructive) { confirmErase = true }
                .font(.subheadline)
                .foregroundStyle(Palette.coral)
                .frame(minHeight: 44)
            }
          }
          MicroLabel(text: "PULSE GRID / VERSION 1.0")
        }
        .padding(24)
      }
    }
    .safeAreaInset(edge: .top, spacing: 0) {
      SheetHeader(title: "OPERATOR’S GUIDE", closeLabel: "Close guide") { dismiss() }
    }
    .confirmationDialog(
      "Erase all progress?", isPresented: $confirmErase, titleVisibility: .visible
    ) {
      Button("Erase all progress", role: .destructive) { store.erase() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("All saved circuits and completion records on this device will be removed.")
    }
  }

  private func guideStep(_ number: String, title: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 18) {
      MicroLabel(text: number, color: Palette.mint).padding(.top, 4)
      VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.system(.headline, weight: .medium)).foregroundStyle(Palette.ink)
        Text(text).font(.subheadline).foregroundStyle(Palette.muted).fixedSize(
          horizontal: false, vertical: true)
      }
    }
  }
}
