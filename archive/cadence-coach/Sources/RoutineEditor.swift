import SwiftUI

struct RoutineEditor: View {
  @EnvironmentObject private var store: CoachStore
  @Environment(\.dismiss) private var dismiss
  @State var routine: Routine
  @FocusState private var fieldFocused: Bool
  @State private var confirmDiscard = false
  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Routine name", text: $routine.name)
            .font(.title3.weight(.bold)).focused($fieldFocused)
            .accessibilityLabel("Routine name")
          Stepper(value: $routine.rounds, in: 1...30) {
            HStack {
              Text("Rounds")
              Spacer()
              Text("\(routine.rounds)").font(.headline.monospacedDigit())
            }
          }.accessibilityLabel("Rounds, \(routine.rounds)")
        } header: {
          Text("Build your rhythm")
        } footer: {
          Text(
            "Repeat the sequence \(routine.rounds) times · \(durationLabel(routine.totalSeconds)) total"
          )
        }
        ForEach(Array(routine.intervals.enumerated()), id: \.element.id) { index, interval in
          Section {
            Picker("Phase", selection: $routine.intervals[index].kind) {
              ForEach(PhaseKind.allCases) { kind in Text(kind.title).tag(kind) }
            }.pickerStyle(.segmented)
            TextField("Movement or cue", text: $routine.intervals[index].name)
              .focused($fieldFocused).accessibilityLabel("Interval \(index + 1) name")
            HStack {
              Text("Duration")
              Spacer()
              TextField(
                "Seconds",
                text: Binding(
                  get: { String(routine.intervals[index].seconds) },
                  set: { routine.intervals[index].seconds = min(Int($0) ?? 0, 3600) }
                )
              )
              .keyboardType(.numberPad).multilineTextAlignment(.trailing)
              .frame(width: 80).focused($fieldFocused)
              .accessibilityLabel("Interval \(index + 1) seconds")
              Text("sec").foregroundStyle(Palette.muted)
            }
            HStack {
              Button {
                routine.intervals.swapAt(index, index - 1)
              } label: {
                Image(systemName: "arrow.up").frame(width: 44, height: 32)
              }.disabled(index == 0).accessibilityLabel("Move interval \(index + 1) up")
              Button {
                routine.intervals.swapAt(index, index + 1)
              } label: {
                Image(systemName: "arrow.down").frame(width: 44, height: 32)
              }.disabled(index == routine.intervals.count - 1)
                .accessibilityLabel("Move interval \(index + 1) down")
              Spacer()
              Button(role: .destructive) {
                routine.intervals.remove(at: index)
              } label: {
                Image(systemName: "trash").frame(width: 44, height: 32)
              }.disabled(routine.intervals.count == 1).accessibilityLabel(
                "Delete interval \(index + 1)")
            }.buttonStyle(.borderless)
          } header: {
            Text(String(format: "%02d / %@", index + 1, interval.kind.title))
          }
        }
        Section {
          Button {
            routine.intervals.append(Interval(name: "Work", kind: .work, seconds: 30))
          } label: {
            Label("Add interval", systemImage: "plus")
          }
          .disabled(routine.intervals.count >= 12)
        } footer: {
          Text(
            routine.isValid
              ? "Your sequence is ready. You can adjust it any time."
              : "Add a name, at least one work interval, and durations from 1 to 3,600 seconds.")
        }
      }
      .scrollContentBackground(.hidden).background(Palette.cream)
      .navigationTitle("Routine studio").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { confirmDiscard = true }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            fieldFocused = false
            store.upsert(routine)
            dismiss()
          }.fontWeight(.bold).disabled(!routine.isValid)
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { fieldFocused = false }
        }
      }
      .interactiveDismissDisabled()
      .confirmationDialog(
        "Discard this draft?", isPresented: $confirmDiscard, titleVisibility: .visible
      ) {
        Button("Discard changes", role: .destructive) { dismiss() }
      } message: {
        Text("Your saved routines won’t change.")
      }
    }
  }
}
