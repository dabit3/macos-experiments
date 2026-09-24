import SwiftUI

struct LibraryView: View {
  @EnvironmentObject private var store: TapeStore
  @Environment(\.dismiss) private var dismiss
  @State private var showingSave = false
  @State private var pendingLoad: Pattern?
  @State private var pendingDelete: SavedTape?

  private var hasUnsavedChanges: Bool {
    !Pattern.presets.contains(store.pattern)
      && !store.archive.tapes.contains(where: { $0.pattern == store.pattern })
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          section("Your tapes", count: store.archive.tapes.count) {
            if store.archive.tapes.isEmpty {
              VStack(alignment: .leading, spacing: 6) {
                Text("Nothing saved yet")
                  .font(.headline)
                Text("Save the pattern on the deck to keep a copy here.")
                  .font(.subheadline)
                  .foregroundStyle(Deck.muted)
                Button("Save current pattern") { showingSave = true }
                  .font(.subheadline.weight(.semibold))
                  .frame(minHeight: 44)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(18)
              .background(Deck.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            ForEach(store.archive.tapes) { tape in
              tapeRow(tape.pattern, factory: false, onDelete: { pendingDelete = tape }) {
                requestLoad(tape.pattern)
              }
            }
          }
          section("Factory patterns", count: Pattern.presets.count) {
            ForEach(Array(Pattern.presets.enumerated()), id: \.offset) { _, pattern in
              tapeRow(pattern, factory: true) { requestLoad(pattern) }
            }
          }
          Text("Loading a tape replaces the pattern on the deck. Everything stays on this iPhone.")
            .font(.footnote)
            .foregroundStyle(Deck.muted)
        }
        .padding(20)
      }
      .background(Deck.bone)
      .foregroundStyle(Deck.ink)
      .navigationTitle("Library")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Save current") { showingSave = true }
        }
        ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
      }
      .sheet(isPresented: $showingSave) { SaveTapeView() }
      .alert(
        "Replace the pattern on the deck?",
        isPresented: Binding(
          get: { pendingLoad != nil }, set: { if !$0 { pendingLoad = nil } }
        )
      ) {
        Button("Load", role: .destructive) {
          if let pattern = pendingLoad {
            store.load(pattern)
            dismiss()
          }
        }
        Button("Cancel", role: .cancel) { pendingLoad = nil }
      } message: {
        Text("Your current edits aren't saved. Save a copy first if you want to keep them.")
      }
      .alert(
        "Delete \(pendingDelete?.pattern.name ?? "this tape")?",
        isPresented: Binding(
          get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        )
      ) {
        Button("Delete", role: .destructive) {
          if let tape = pendingDelete { store.delete(id: tape.id) }
          pendingDelete = nil
        }
        Button("Cancel", role: .cancel) { pendingDelete = nil }
      } message: {
        Text("The pattern on the deck is not affected.")
      }
    }
  }

  private func section<Content: View>(
    _ title: String, count: Int, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(title).font(.headline)
        Text("\(count)").font(.subheadline.monospacedDigit()).foregroundStyle(Deck.muted)
      }
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
      content()
    }
  }

  private func requestLoad(_ pattern: Pattern) {
    if hasUnsavedChanges {
      pendingLoad = pattern
    } else {
      store.load(pattern)
      dismiss()
    }
  }

  private func tapeRow(
    _ pattern: Pattern, factory: Bool, onDelete: (() -> Void)? = nil,
    action: @escaping () -> Void
  ) -> some View {
    let onDeck = store.pattern == pattern
    return HStack(spacing: 0) {
      Button(action: action) {
        HStack(spacing: 14) {
          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
              if onDeck {
                Circle().fill(Deck.red).frame(width: 8, height: 8)
              }
              Text(pattern.name).font(.headline).lineLimit(2)
            }
            Text(
              (onDeck ? "On deck · " : "")
                + "\(Int(pattern.tempo)) BPM · \(Int((pattern.swing * 100).rounded()))% swing"
            )
            .font(.subheadline)
            .foregroundStyle(onDeck ? Deck.red : Deck.muted)
            .monospacedDigit()
            .lineLimit(2)
          }
          Spacer(minLength: 12)
          PatternPreview(pattern: pattern, height: 6)
            .frame(width: 84)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .accessibilityLabel(
        "\(pattern.name), \(Int(pattern.tempo)) beats per minute, \(factory ? "factory pattern" : "saved tape")"
      )
      .accessibilityValue(onDeck ? "On deck" : "")
      .accessibilityHint("Loads this pattern onto the deck")
      if let onDelete {
        Button(action: onDelete) {
          Image(systemName: "trash")
            .font(.body)
            .foregroundStyle(Deck.muted)
            .frame(width: 44, height: 44)
        }
        .padding(.trailing, 6)
        .accessibilityLabel("Delete \(pattern.name)")
      }
    }
    .foregroundStyle(Deck.ink)
    .buttonStyle(HardwareButtonStyle())
    .background(Deck.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(onDeck ? Deck.red.opacity(0.6) : Deck.line))
  }
}

struct SaveTapeView: View {
  @EnvironmentObject private var store: TapeStore
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @FocusState private var focused: Bool

  private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text("Keeps all four tracks, tempo, swing and the mixer as they are right now.")
            .font(.subheadline)
            .foregroundStyle(Deck.muted)
          VStack(alignment: .leading, spacing: 8) {
            Text("Name")
              .font(.caption.weight(.medium))
              .foregroundStyle(Deck.muted)
            TextField("Tape name", text: $name)
              .font(.title2.weight(.semibold))
              .focused($focused)
              .submitLabel(.done)
              .onSubmit { save() }
              .accessibilityLabel("Tape name")
              .onChange(of: name) { _, value in
                if value.count > 40 { name = String(value.prefix(40)) }
              }
              .padding(.horizontal, 16)
              .frame(minHeight: 56)
              .background(Deck.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
              .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .stroke(focused ? Deck.ink : Deck.line))
            Text("\(name.count)/40")
              .font(.caption.monospacedDigit())
              .foregroundStyle(Deck.muted)
          }
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text("\(Int(store.pattern.tempo)) BPM")
              Text("·")
              Text("\(Int((store.pattern.swing * 100).rounded()))% swing")
            }
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(Deck.muted)
            PatternPreview(pattern: store.pattern, height: 10)
          }
          .padding(16)
          .background(Deck.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          .accessibilityHidden(true)
          Button(action: save) {
            Text("Save tape")
              .font(.headline)
              .frame(maxWidth: .infinity, minHeight: 54)
              .foregroundStyle(Deck.paper)
              .background(
                valid ? Deck.red : Deck.muted,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(HardwareButtonStyle())
          .disabled(!valid)
        }
        .padding(20)
      }
      .background(Deck.bone)
      .foregroundStyle(Deck.ink)
      .navigationTitle("Save a copy")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
      }
      .onAppear {
        name = store.pattern.name
        focused = true
      }
    }
  }

  private func save() {
    guard valid else { return }
    store.save(name: name)
    dismiss()
  }
}

struct ParameterView: View {
  @EnvironmentObject private var store: TapeStore
  @Environment(\.dismiss) private var dismiss
  @State private var tapHint = "Tap on the beat"

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          control(title: "Tempo", value: "\(Int(store.pattern.tempo))", unit: "BPM") {
            Slider(
              value: Binding(
                get: { store.pattern.tempo },
                set: { value in store.edit { $0.tempo = value } }),
              in: 60...180, step: 1
            )
            .accessibilityLabel("Tempo")
            .accessibilityValue("\(Int(store.pattern.tempo)) beats per minute")
            Button {
              tapHint = store.tapTempo() ? "\(Int(store.pattern.tempo)) BPM" : "Keep tapping"
              UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            } label: {
              HStack {
                Text("Tap tempo").font(.subheadline.weight(.semibold))
                Spacer()
                Text(tapHint).font(.subheadline).foregroundStyle(Deck.muted).monospacedDigit()
              }
              .padding(.horizontal, 16)
              .frame(minHeight: 48)
              .background(Deck.bone, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(HardwareButtonStyle())
            .accessibilityHint("Tap repeatedly on the beat to set the tempo")
          }
          control(title: "Swing", value: "\(Int((store.pattern.swing * 100).rounded()))", unit: "%")
          {
            Slider(
              value: Binding(
                get: { store.pattern.swing * 100 },
                set: { value in store.edit { $0.swing = value / 100 } }),
              in: 0...60, step: 1
            )
            .accessibilityLabel("Swing")
            .accessibilityValue("\(Int((store.pattern.swing * 100).rounded())) percent")
            Text("Delays every second sixteenth. 0% is straight; around 15–30% is a light shuffle.")
              .font(.footnote)
              .foregroundStyle(Deck.muted)
          }
          Button("Reset to 96 BPM, 0% swing") {
            store.edit {
              $0.tempo = 96
              $0.swing = 0
            }
          }
          .font(.subheadline.weight(.semibold))
          .frame(minHeight: 44)
        }
        .padding(20)
      }
      .background(Deck.bone)
      .foregroundStyle(Deck.ink)
      .navigationTitle("Tempo & swing")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
  }

  private func control<Content: View>(
    title: String, value: String, unit: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(title).font(.headline)
        Spacer()
        Text(value).font(.largeTitle.weight(.semibold)).monospacedDigit()
        Text(unit).font(.subheadline).foregroundStyle(Deck.muted)
      }
      content()
    }
    .padding(18)
    .background(Deck.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

struct GuideView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          guide(
            "play.fill", "Play",
            "Starts the loop from step 1. Turn up the media volume to hear it.")
          guide(
            "square.grid.2x2.fill", "Steps",
            "Pick a track, then tap pads to place hits. Each row of pads is one beat. Amber is on, charcoal is off, and the red outline is the playhead."
          )
          guide(
            "speaker.slash.fill", "Mute and solo",
            "M silences a track. S lets only soloed tracks play. Mute wins if both are on.")
          guide(
            "metronome.fill", "Tempo and swing",
            "Use the steppers on the deck, or tap a value for sliders and tap tempo. Changes apply while playing."
          )
          guide(
            "square.and.arrow.down.fill", "Save",
            "Save keeps a named copy in the library. The pattern on the deck also saves itself as you go."
          )
          Text(
            "Four original synthesized sounds. No samples, network, tracking or accounts. Playback stops when you leave the app or your audio output disconnects."
          )
          .font(.footnote)
          .foregroundStyle(Deck.muted)
        }
        .padding(20)
      }
      .background(Deck.bone)
      .foregroundStyle(Deck.ink)
      .navigationTitle("How it works")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
  }

  private func guide(_ symbol: String, _ title: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: symbol)
        .font(.body.weight(.semibold))
        .foregroundStyle(Deck.paper)
        .frame(width: 36, height: 36)
        .background(Deck.ink, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.headline)
        Text(text).font(.subheadline).foregroundStyle(Deck.muted)
      }
    }
  }
}
