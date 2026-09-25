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
        VStack(alignment: .leading, spacing: 24) {
          VStack(alignment: .leading, spacing: 5) {
            Micro(text: "THE COLLECTION")
            Text("Good things\ncome on tape.")
              .font(.system(.largeTitle, design: .rounded).weight(.bold))
              .tracking(-1)
            Text("Original grooves. Yours to make your own.")
              .font(.subheadline).foregroundStyle(Deck.muted)
          }
          VStack(alignment: .leading, spacing: 12) {
            Micro(text: "FACTORY TAPES / 04")
            ForEach(Array(Pattern.presets.enumerated()), id: \.offset) { index, pattern in
              tapeRow(pattern, index: index + 1, factory: true) { requestLoad(pattern) }
            }
          }
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Micro(text: "YOUR TAPES / \(String(format: "%02d", store.archive.tapes.count))")
              Spacer()
              Button {
                showingSave = true
              } label: {
                Image(systemName: "plus").frame(width: 44, height: 44)
              }.accessibilityLabel("Save current pattern")
            }
            if store.archive.tapes.isEmpty {
              VStack(alignment: .leading, spacing: 10) {
                Text("Your next side A.")
                  .font(.system(.title2, design: .rounded).weight(.bold))
                Text("Make a groove, give it a name, keep it here.")
                  .font(.subheadline).foregroundStyle(Deck.muted)
                Button("Save this pattern") { showingSave = true }
                  .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(20)
              .background(Deck.paper, in: RoundedRectangle(cornerRadius: 14))
              .overlay(RoundedRectangle(cornerRadius: 14).stroke(Deck.line))
            }
            ForEach(Array(store.archive.tapes.enumerated()), id: \.element.id) { index, tape in
              HStack(spacing: 6) {
                tapeRow(tape.pattern, index: index + 1, factory: false) {
                  requestLoad(tape.pattern)
                }
                Button {
                  pendingDelete = tape
                } label: {
                  Image(systemName: "trash").frame(width: 44, height: 60)
                }
                .accessibilityLabel("Delete \(tape.pattern.name)")
              }
            }
          }
          Text(
            "Everything stays on this device. Loading a tape replaces the working pattern; saved copies stay in your collection."
          )
          .font(.footnote).foregroundStyle(Deck.muted)
        }
        .padding(22)
      }
      .background(Deck.bone)
      .foregroundStyle(Deck.ink)
      .navigationTitle("Tape library")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
      }
      .sheet(isPresented: $showingSave) { SaveTapeView() }
      .alert(
        "Replace your working pattern?",
        isPresented: Binding(
          get: { pendingLoad != nil }, set: { if !$0 { pendingLoad = nil } }
        )
      ) {
        Button("Load tape", role: .destructive) {
          if let pattern = pendingLoad {
            store.load(pattern)
            dismiss()
          }
        }
        Button("Cancel", role: .cancel) { pendingLoad = nil }
      } message: {
        Text("Save a copy first if you want to keep your edits.")
      }
      .alert(
        "Delete this tape?",
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
        Text("This removes the saved copy. Your working pattern will stay on the deck.")
      }
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
    _ pattern: Pattern, index: Int, factory: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 14) {
        ZStack {
          RoundedRectangle(cornerRadius: 7).fill(Deck.ink)
          VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(factory ? Deck.amber : Deck.bone)
              .frame(height: 10)
            HStack {
              Circle().stroke(Deck.bone, lineWidth: 3).frame(width: 13, height: 13)
              Spacer()
              Circle().stroke(Deck.bone, lineWidth: 3).frame(width: 13, height: 13)
            }
          }.padding(8)
        }.frame(width: 63, height: 46).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
          if store.pattern == pattern {
            Micro(text: "ON DECK", color: Deck.red)
          }
          Text(pattern.name).font(.system(.headline, design: .rounded))
          Micro(text: "\(Int(pattern.tempo)) BPM · \(Int((pattern.swing * 100).rounded()))% SWING")
        }
        Spacer(minLength: 0)
        Image(systemName: store.pattern == pattern ? "checkmark" : "arrow.up.right")
          .font(.caption.weight(.semibold))
      }
      .foregroundStyle(Deck.ink)
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Deck.paper, in: RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(Deck.line))
    }
    .buttonStyle(HardwareButtonStyle())
    .accessibilityLabel(
      "Load \(pattern.name), \(Int(pattern.tempo)) beats per minute, \(factory ? "factory preset" : "saved tape")"
    )
    .accessibilityValue(store.pattern == pattern ? "On deck" : "")
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
          VStack(alignment: .leading, spacing: 8) {
            Micro(text: "MAKE IT A KEEPER")
            Text("Name your tape.")
              .font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text("A fresh copy of all 16 steps, four voices, tempo, swing and mixer settings.")
              .font(.subheadline).foregroundStyle(Deck.muted)
          }
          VStack(alignment: .leading, spacing: 12) {
            Micro(text: "SIDE A / TITLE")
            TextField("e.g. Sunday kitchen", text: $name)
              .font(.system(.title2, design: .rounded).weight(.semibold))
              .focused($focused)
              .submitLabel(.done)
              .onSubmit { save() }
              .accessibilityLabel("Tape name")
              .onChange(of: name) { _, value in
                if value.count > 40 { name = String(value.prefix(40)) }
              }
            Rectangle().fill(Deck.ink).frame(height: 1)
            HStack {
              Micro(text: "\(Int(store.pattern.tempo)) BPM / FOUR VOICES")
              Spacer()
              Text("\(name.count)/40").font(.caption.monospacedDigit()).foregroundStyle(Deck.muted)
            }
            HStack(spacing: 70) {
              Reel(angle: 15).frame(width: 65, height: 65)
              Reel(angle: 15).frame(width: 65, height: 65)
            }.frame(maxWidth: .infinity).padding(.top, 10)
          }
          .padding(22)
          .background(Deck.amber.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
          Button(action: save) {
            Text("Save tape").font(.headline)
              .frame(maxWidth: .infinity, minHeight: 54)
              .foregroundStyle(Deck.paper)
              .background(valid ? Deck.red : Deck.muted, in: RoundedRectangle(cornerRadius: 12))
          }
          .disabled(!valid)
          Text("Saved only on this iPhone. No account. No cloud.")
            .font(.footnote).foregroundStyle(Deck.muted)
        }.padding(22)
      }
      .background(Deck.bone)
      .foregroundStyle(Deck.ink)
      .navigationTitle("Save a copy")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
      }
      .onAppear { name = store.pattern.name }
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

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 30) {
          VStack(alignment: .leading, spacing: 8) {
            Micro(text: "FIND THE POCKET")
            Text("A little push.\nA little pull.")
              .font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text("Changes are live. The groove keeps rolling.")
              .font(.subheadline).foregroundStyle(Deck.muted)
          }
          control(title: "Tempo", value: "\(Int(store.pattern.tempo))", unit: "BPM") {
            Slider(
              value: Binding(
                get: { store.pattern.tempo },
                set: { value in store.edit { $0.tempo = value } }),
              in: 60...180, step: 1
            )
            .accessibilityLabel("Tempo")
            .accessibilityValue("\(Int(store.pattern.tempo)) beats per minute")
            HStack {
              Micro(text: "60 / SLOW")
              Spacer()
              Micro(text: "180 / FAST")
            }
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
            HStack {
              Micro(text: "STRAIGHT")
              Spacer()
              Micro(text: "LAID BACK")
            }
          }
          Text("Swing delays every second sixteenth note without changing the length of the bar.")
            .font(.subheadline).foregroundStyle(Deck.muted)
          Button("Reset to 96 BPM · 0% swing") {
            store.edit {
              $0.tempo = 96
              $0.swing = 0
            }
          }
          .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
        }.padding(22)
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
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        Text(title).font(.headline)
        Spacer()
        Text(value).font(.system(.largeTitle, design: .monospaced).weight(.bold)).monospacedDigit()
        Micro(text: unit)
      }
      content()
    }
    .padding(20)
    .background(Deck.paper, in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Deck.line))
  }
}

struct GuideView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 25) {
          Micro(text: "TD—01 / QUICK START")
          Text("Small machine.\nBig pocket.")
            .font(.system(.largeTitle, design: .rounded).weight(.bold))
          guide(
            "01", "Press play.",
            "The factory tape is ready to go. Turn up your iPhone’s media volume to hear it.")
          guide(
            "02", "Make your mark.",
            "Choose Kick, Snare, Hat or Clap. Amber pads play; dark pads rest. Each row is one beat, read left to right."
          )
          guide(
            "03", "Find the feel.",
            "Tap either knob for tempo and swing. MUTE silences the selected voice; SOLO isolates it. Mute wins if both are on. HELD means another track is soloed."
          )
          guide(
            "04", "Keep a side A.",
            "Save creates a named snapshot. Your working pattern also saves automatically, including mute and solo."
          )
          Text(
            "Four original synthesized sounds. No samples, network, tracking or accounts. Playback stops when you leave the app or disconnect your audio output."
          )
          .font(.footnote).foregroundStyle(Deck.muted)
        }.padding(22)
      }
      .background(Deck.bone).foregroundStyle(Deck.ink)
      .navigationTitle("Field notes")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
  }

  private func guide(_ number: String, _ title: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Micro(text: number, color: Deck.red).padding(.top, 5)
      VStack(alignment: .leading, spacing: 7) {
        Text(title).font(.system(.title3, design: .rounded).weight(.bold))
        Text(text).font(.body).foregroundStyle(Deck.muted)
      }
    }
  }
}
