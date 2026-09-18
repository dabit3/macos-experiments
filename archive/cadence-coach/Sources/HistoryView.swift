import SwiftUI

struct HistoryView: View {
  @EnvironmentObject private var store: CoachStore
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        Eyebrow(text: "A record of showing up").foregroundStyle(Palette.muted)
        Text("The work\nadds up.").instrumentDisplay(52)
        AdaptiveRow {
          Metric(value: "\(store.history.filter(\.completed).count)", label: "COMPLETED")
          Metric(
            value: durationLabel(store.history.reduce(0) { $0 + Int($1.activeSeconds) }),
            label: "ACTIVE TIME")
        }
        Divider()
        if store.history.isEmpty {
          VStack(alignment: .leading, spacing: 14) {
            CadenceMark(color: Palette.ink).padding(.vertical, 14)
            Text("Your first effort belongs here.").font(.title2.weight(.bold))
            Text(
              "Finish a routine and we’ll keep the time, intervals and effort in your training log."
            )
            .foregroundStyle(Palette.muted)
          }.padding(.vertical, 22)
        }
        ForEach(store.history) { record in
          NavigationLink {
            ResultView(record: record).navigationTitle("Session detail")
              .navigationBarTitleDisplayMode(.inline)
          } label: {
            AdaptiveRow {
              VStack(alignment: .leading, spacing: 6) {
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                  .font(.caption).foregroundStyle(Palette.muted)
                Text(record.name).font(.headline)
                Text(
                  record.completed ? "Completed · \(record.skippedPhases) skipped" : "Ended early"
                )
                .font(.caption).foregroundStyle(Palette.muted)
              }
              Spacer()
              Text(clock(Int(record.activeSeconds))).instrumentDisplay(28)
              Image(systemName: "chevron.right").font(.caption)
            }.padding(.vertical, 4)
          }.buttonStyle(.plain)
          Divider()
        }
      }.padding(24)
    }.background(Palette.cream).foregroundStyle(Palette.ink)
      .navigationTitle("Training log").navigationBarTitleDisplayMode(.inline)
  }
}

struct SettingsView: View {
  @EnvironmentObject private var store: CoachStore
  @Environment(\.dismiss) private var dismiss
  @State private var confirmClear = false
  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack(spacing: 18) {
            CadenceMark(color: Palette.ink)
            VStack(alignment: .leading, spacing: 4) {
              Text("Cadence Coach").font(.title2.weight(.bold))
              Text("Find your next gear.").foregroundStyle(Palette.muted)
            }
          }.padding(.vertical, 10)
        }
        Section("During a session") {
          Toggle(
            "Sound cues",
            isOn: Binding(
              get: { !store.muted },
              set: {
                store.muted = !$0
                store.save()
              }))
          Text(
            "A high tone starts work; a low tone starts rest. Cues respect Silent Mode. Phase labels always show what’s next."
          )
          .font(.footnote).foregroundStyle(Palette.muted)
          Text(
            "The clock keeps its place when you leave the app. On return it catches up, including missed intervals. Sound cues play only while the app is active."
          )
          .font(.footnote).foregroundStyle(Palette.muted)
        }
        Section("Your data") {
          Text(
            "Routines, settings and training history stay on this device. No accounts, tracking or network connection."
          )
          .font(.subheadline)
          Button("Clear training history", role: .destructive) { confirmClear = true }
            .disabled(store.history.isEmpty)
        }
        Section {
          Text("Example routines are general movement prompts. Choose your own exercises and pace.")
            .font(.footnote).foregroundStyle(Palette.muted)
          Text("VERSION 1.0 / MADE FOR YOUR RHYTHM").font(.caption2).tracking(1)
        }
      }
      .scrollContentBackground(.hidden).background(Palette.cream)
      .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
      .confirmationDialog(
        "Clear your training history?", isPresented: $confirmClear, titleVisibility: .visible
      ) {
        Button("Clear history", role: .destructive) {
          store.history = []
          store.save()
        }
      } message: {
        Text("This can’t be undone. Your routines will stay saved.")
      }
    }
  }
}
