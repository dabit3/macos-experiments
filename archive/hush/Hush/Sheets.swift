import SwiftUI

struct SheetShell<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) { content }
          .padding(24).frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(HushStyle.ink)
      .foregroundStyle(HushStyle.silver)
      .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }.foregroundStyle(HushStyle.lavender)
        }
      }
    }
    .tint(HushStyle.lavender)
    .presentationDragIndicator(.visible)
    .preferredColorScheme(.dark)
  }
}

struct SceneLibrary: View {
  @EnvironmentObject private var store: HushStore
  @Environment(\.dismiss) private var dismiss
  @State private var editScene: SavedScene?
  @State private var deleteScene: SavedScene?

  var body: some View {
    SheetShell(title: "Scenes") {
      VStack(alignment: .leading, spacing: 8) {
        Text("Places to disappear.")
          .font(.system(.largeTitle, design: .serif))
        Text("A familiar quiet, one touch away.")
          .font(.subheadline).foregroundStyle(HushStyle.muted)
      }
      sectionLabel("HUSH ORIGINALS")
      ForEach(SavedScene.originals) { scene in
        sceneRow(scene)
      }
      sectionLabel("YOUR SCENES")
      if store.preferences.scenes.isEmpty {
        VStack(alignment: .leading, spacing: 9) {
          Text("Keep a little quiet.").font(.system(.title2, design: .serif))
          Text("Adjust the elements, then tap Save on your mixer. Your scenes stay on this iPhone.")
            .font(.subheadline).foregroundStyle(HushStyle.muted)
        }.padding(.vertical, 12)
      }
      ForEach(store.preferences.scenes) { scene in
        HStack(spacing: 8) {
          sceneRow(scene)
          Menu {
            Button("Rename", systemImage: "pencil") { editScene = scene }
            Button("Delete", systemImage: "trash", role: .destructive) { deleteScene = scene }
          } label: {
            Image(systemName: "ellipsis").frame(width: 44, height: 60)
          }.accessibilityLabel("Options for \(scene.name)")
        }
      }
    }
    .sheet(item: $editScene) { scene in SaveSceneView(existing: scene) }
    .confirmationDialog(
      "Delete \(deleteScene?.name ?? "scene")?",
      isPresented: Binding(get: { deleteScene != nil }, set: { if !$0 { deleteScene = nil } }),
      titleVisibility: .visible
    ) {
      Button("Delete scene", role: .destructive) {
        store.preferences.scenes.removeAll { $0.id == deleteScene?.id }
        deleteScene = nil
      }
      Button("Cancel", role: .cancel) { deleteScene = nil }
    }
  }

  private func sectionLabel(_ title: String) -> some View {
    Text(title).font(.system(size: 10, weight: .medium, design: .monospaced))
      .tracking(2).foregroundStyle(HushStyle.muted).padding(.top, 10)
  }

  private func sceneRow(_ scene: SavedScene) -> some View {
    Button {
      store.recall(scene)
      dismiss()
    } label: {
      HStack(spacing: 16) {
        Landscape(mix: scene.mix)
          .frame(width: 76, height: 84).clipShape(RoundedRectangle(cornerRadius: 18))
        VStack(alignment: .leading, spacing: 7) {
          Text(scene.name).font(.system(.title3, design: .serif))
            .foregroundStyle(HushStyle.silver)
          Text(scene.note).font(.caption).foregroundStyle(HushStyle.muted)
          Text(
            Layer.allCases.filter { scene.mix.level($0) > 0 }.map {
              "\($0 == .brown ? "Brown" : $0.title) \(Int(scene.mix.level($0) * 100))"
            }.joined(separator: " · ")
          )
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(HushStyle.lavender)
        }
        Spacer(minLength: 0)
        Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(HushStyle.lavender)
      }.frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityLabel("Load \(scene.name), \(scene.note)")
  }
}

struct SaveSceneView: View {
  var existing: SavedScene?
  @EnvironmentObject private var store: HushStore
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @FocusState private var focused: Bool

  private var clean: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
  var body: some View {
    SheetShell(title: existing == nil ? "Save scene" : "Rename scene") {
      Landscape(mix: existing?.mix ?? store.mix)
        .frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 24))
      Text(existing == nil ? "Give this quiet a name." : "A new name, the same quiet.")
        .font(.system(.title, design: .serif))
      VStack(alignment: .leading, spacing: 10) {
        Text("SCENE NAME").font(.caption.monospaced()).tracking(2).foregroundStyle(HushStyle.muted)
        TextField("e.g. Rain at midnight", text: $name)
          .font(.title3).padding(18).background(
            .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16)
          )
          .focused($focused).submitLabel(.done)
          .onChange(of: name) { _, value in name = String(value.prefix(40)) }
          .onSubmit { save() }
          .accessibilityLabel("Scene name")
        Text("\(name.count)/40 · Saved only on this iPhone")
          .font(.caption).foregroundStyle(HushStyle.muted)
      }
      Button(action: save) {
        Label(existing == nil ? "Save scene" : "Save name", systemImage: "bookmark")
          .font(.headline).frame(maxWidth: .infinity, minHeight: 56)
          .foregroundStyle(HushStyle.ink)
          .background(HushStyle.lavender.opacity(clean.isEmpty ? 0.3 : 1), in: Capsule())
      }.disabled(clean.isEmpty)
    }
    .onAppear { name = existing?.name ?? "" }
  }

  private func save() {
    guard !clean.isEmpty else { return }
    if let existing,
      let index = store.preferences.scenes.firstIndex(where: { $0.id == existing.id })
    {
      store.preferences.scenes[index].name = clean
      if store.preferences.sceneName == existing.name { store.preferences.sceneName = clean }
    } else {
      store.saveScene(name: clean)
    }
    focused = false
    dismiss()
  }
}

struct TimerView: View {
  @EnvironmentObject private var store: HushStore
  @Environment(\.dismiss) private var dismiss
  @State private var duration = 30.0 * 60

  var body: some View {
    SheetShell(title: "Sleep timer") {
      VStack(alignment: .leading, spacing: 12) {
        Text(store.timerFinished ? "A softer landing." : "Let the night take over.")
          .font(.system(.largeTitle, design: .serif))
        Text(
          store.timerFinished
            ? "Your sounds have faded away. Stay a little longer, or begin again."
            : "Your soundscape gently fades over the final 10 seconds, then stops."
        )
        .font(.subheadline).foregroundStyle(HushStyle.muted)
      }
      ZStack {
        Circle().stroke(HushStyle.lavender.opacity(0.10), lineWidth: 1)
        Circle().trim(from: 0, to: progress)
          .stroke(HushStyle.lavender, style: StrokeStyle(lineWidth: 2, lineCap: .round))
          .rotationEffect(.degrees(-90))
        VStack(spacing: 10) {
          Image(systemName: "moon.zzz").font(.system(size: 25, weight: .ultraLight))
            .foregroundStyle(HushStyle.lavender)
          Text(
            store.timerFinished
              ? "Quiet" : store.countdown == nil ? displayDuration : store.timerLabel
          )
          .font(.system(size: 48, weight: .ultraLight, design: .rounded)).monospacedDigit()
          Text(
            store.timerFinished
              ? "TIMER COMPLETE"
              : store.isFading
                ? "FADING TO QUIET" : store.countdown == nil ? "UNTIL QUIET" : "REMAINING"
          )
          .font(.system(size: 12, weight: .medium, design: .monospaced)).tracking(1.3)
          .foregroundStyle(HushStyle.lavender)
        }
      }.frame(width: 236, height: 236).frame(maxWidth: .infinity).padding(.vertical, 12)
      if store.timerFinished {
        Button {
          store.play()
          dismiss()
        } label: {
          Text("Listen again").font(.headline).frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(HushStyle.ink).background(HushStyle.lavender, in: Capsule())
        }
        Button {
          store.timerFinished = false
          store.message = nil
        } label: {
          Text("Set another timer").frame(maxWidth: .infinity, minHeight: 48)
        }
      } else if store.countdown == nil {
        HStack(spacing: 10) {
          ForEach([15.0, 30.0, 60.0], id: \.self) { minutes in
            Button {
              duration = minutes * 60
            } label: {
              Text("\(Int(minutes)) min")
                .font(.subheadline).frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(duration == minutes * 60 ? HushStyle.ink : HushStyle.silver)
                .background(
                  duration == minutes * 60 ? HushStyle.lavender : .white.opacity(0.06),
                  in: Capsule())
            }.accessibilityAddTraits(duration == minutes * 60 ? .isSelected : [])
          }
        }
        Button {
          store.startTimer(seconds: duration)
        } label: {
          Text("Start timer").font(.headline).frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(HushStyle.ink).background(HushStyle.lavender, in: Capsule())
        }
        Button {
          store.startTimer(seconds: 30)
        } label: {
          Text("Try a 30-second fade preview").font(.subheadline)
            .frame(maxWidth: .infinity, minHeight: 44)
        }.foregroundStyle(HushStyle.muted)
      } else {
        Button {
          store.countdown = nil
          store.haptic()
        } label: {
          Text("Cancel timer · keep listening")
            .font(.subheadline).frame(maxWidth: .infinity, minHeight: 56)
            .background(.white.opacity(0.07), in: Capsule())
        }
      }
      if let message = store.message, !store.timerFinished {
        Text(message).font(.subheadline).foregroundStyle(HushStyle.lavender)
      }
      Text(
        store.timerFinished
          ? "No alarm. Nothing to do. Just quiet."
          : "The timer keeps counting when playback is paused. No alarm, no abrupt ending."
      )
      .font(.footnote).foregroundStyle(HushStyle.muted)
    }
  }

  private var displayDuration: String { "\(Int(duration / 60)) min" }
  private var progress: Double {
    guard let timer = store.countdown else { return store.timerFinished ? 0 : 1 }
    return timer.remaining(at: store.now) / timer.duration
  }
}

struct SettingsView: View {
  @EnvironmentObject private var store: HushStore

  var body: some View {
    SheetShell(title: "The little things") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Quiet by design.").font(.system(.largeTitle, design: .serif))
        Text("Four original sounds. One small place to switch off.")
          .font(.subheadline).foregroundStyle(HushStyle.muted)
      }
      VStack(alignment: .leading, spacing: 16) {
        Text("Fade to quiet").font(.headline)
        Text("How slowly the master fade button brings your soundscape to silence.")
          .font(.subheadline).foregroundStyle(HushStyle.muted)
        HStack(spacing: 10) {
          ForEach([3.0, 8.0, 15.0], id: \.self) { seconds in
            Button {
              store.preferences.fadeSeconds = seconds
              store.haptic()
            } label: {
              Text("\(Int(seconds)) sec")
                .font(.subheadline).frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(
                  store.preferences.fadeSeconds == seconds ? HushStyle.ink : HushStyle.silver
                )
                .background(
                  store.preferences.fadeSeconds == seconds
                    ? HushStyle.lavender : .white.opacity(0.06), in: Capsule())
            }
            .accessibilityLabel("Master fade \(Int(seconds)) seconds")
            .accessibilityAddTraits(store.preferences.fadeSeconds == seconds ? .isSelected : [])
          }
        }
      }
      Divider().overlay(.white.opacity(0.08))
      Toggle("Gentle haptics", isOn: $store.preferences.haptics).tint(HushStyle.lavender)
      Divider().overlay(.white.opacity(0.08))
      VStack(alignment: .leading, spacing: 18) {
        info(
          "Entirely offline",
          "Rain, ocean, wind and brown noise are synthesized on your iPhone. No downloads, microphones or accounts."
        )
        info(
          "Yours to keep",
          "Mix levels, master volume, saved scenes and preferences stay on this device. Playback always starts paused. Timers clear when the app is closed."
        )
        info(
          "Listen comfortably",
          "Start low, especially with headphones. Hush is an ambient mixer, with no health or sleep claims."
        )
      }
      Text("HUSH / 1.0\nAn original place to be still.")
        .font(.caption.monospaced()).lineSpacing(5).foregroundStyle(HushStyle.muted).padding(
          .top, 20)
    }
  }

  private func info(_ title: String, _ detail: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.subheadline.weight(.medium))
      Text(detail).font(.footnote).foregroundStyle(HushStyle.muted).lineSpacing(4)
    }
  }
}
