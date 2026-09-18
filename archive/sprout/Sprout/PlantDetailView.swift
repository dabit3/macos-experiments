import SwiftUI

struct PlantDetailView: View {
  @EnvironmentObject private var store: PlantStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  var plantID: UUID
  @State private var editing = false
  @State private var deleting = false
  @State private var editingLog: Watering?
  @State private var lastLog: UUID?
  @State private var watered = false
  private var plant: Plant? { store.plants.first { $0.id == plantID } }

  var body: some View {
    Group {
      if let plant {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            ZStack(alignment: .bottomTrailing) {
              Ellipse().fill(Palette.sage.opacity(0.6)).frame(width: 260, height: 245).offset(
                x: -30, y: -5)
              PlantPortrait(plant: plant).frame(height: 270).frame(maxWidth: .infinity).clipped()
                .scaleEffect(watered && !reduceMotion ? 1.025 : 1)
              if watered {
                Label("A little love, logged.", systemImage: "checkmark")
                  .font(.caption.weight(.medium)).padding(12)
                  .background(Palette.cream, in: Capsule()).transition(.opacity)
              }
            }
            VStack(alignment: .leading, spacing: 8) {
              Eyebrow(text: plant.room + (plant.isSample ? " · Sample plant" : ""))
              Text(plant.name).font(.system(.largeTitle, design: .serif))
              Text(plant.kind.scientific).font(.subheadline).italic().foregroundStyle(Palette.muted)
            }
            (typeSize.isAccessibilitySize
              ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
              : AnyLayout(HStackLayout(alignment: .top, spacing: 25))) {
                VStack(alignment: .leading, spacing: 6) {
                  Eyebrow(text: "Next soil check")
                  Text(plant.status()).font(.system(.title2, design: .serif))
                    .foregroundStyle(plant.daysUntilDue() < 0 ? Palette.terracotta : Palette.forest)
                  Text(plant.dueDate(), format: .dateTime.month(.abbreviated).day()).font(.caption)
                    .foregroundStyle(Palette.muted)
                }
                if !typeSize.isAccessibilitySize { Spacer() }
                VStack(alignment: .leading, spacing: 6) {
                  Eyebrow(text: "Your rhythm")
                  Text("Every \(plant.interval)d").font(.system(.title2, design: .serif))
                  Text("Adjust any time").font(.caption).foregroundStyle(Palette.muted)
                }
              }.padding(.vertical, 15)
              .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
              .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
            VStack(spacing: 10) {
              Button {
                if let id = store.water(plantID) {
                  lastLog = id
                  withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) { watered = true }
                  UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
              } label: {
                Label(
                  plant.wateredToday() ? "Watered today" : "I watered this plant",
                  systemImage: plant.wateredToday() ? "checkmark" : "drop")
              }.buttonStyle(PrimaryButton()).disabled(plant.wateredToday())
              if let lastLog {
                Button("Undo watering") {
                  store.removeWatering(plantID: plantID, logID: lastLog)
                  self.lastLog = nil
                  watered = false
                }.font(.subheadline).frame(minHeight: 44)
              } else {
                Text("Only water if the soil needs it.").font(.caption).foregroundStyle(
                  Palette.muted)
              }
            }
            VStack(alignment: .leading, spacing: 12) {
              Text("A few field notes").font(.system(.title2, design: .serif))
              Label(plant.kind.light, systemImage: "sun.max").font(.subheadline)
              Text(plant.kind.water).font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(
                4)
            }
            VStack(alignment: .leading, spacing: 10) {
              (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout())) {
                  Text("Your observations").font(.system(.title2, design: .serif))
                  if !typeSize.isAccessibilitySize { Spacer() }
                  Button("Edit") { editing = true }.font(.subheadline).frame(
                    minWidth: 44, minHeight: 44)
                }
              Text(
                plant.notes.isEmpty
                  ? "No notes yet. Notice a new leaf? Make a little note." : plant.notes
              )
              .font(.body).foregroundStyle(Palette.muted).lineSpacing(4)
            }
            VStack(alignment: .leading, spacing: 12) {
              (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout())) {
                  Text("Care journal").font(.system(.title2, design: .serif))
                  if !typeSize.isAccessibilitySize { Spacer() }
                  Text(
                    "\(plant.history.count) \(plant.history.count == 1 ? "watering" : "waterings")"
                  ).font(.caption).foregroundStyle(
                    Palette.muted)
                }
              if plant.history.isEmpty {
                Text("A fresh page. Your waterings will grow here.").font(.subheadline)
                  .foregroundStyle(Palette.muted)
                Text(
                  "Schedule starts \(plant.startedAt.formatted(date: .abbreviated, time: .omitted))."
                ).font(.caption).foregroundStyle(Palette.muted)
              }
              ForEach(plant.history.sorted { $0.date > $1.date }) { log in
                Button {
                  editingLog = log
                } label: {
                  HStack(spacing: 14) {
                    Image(systemName: "drop.fill").foregroundStyle(Palette.forest)
                      .frame(width: 38, height: 38).background(Palette.sage, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                      Text("Watered").font(.subheadline.weight(.medium))
                      Text(log.date, format: .dateTime.month(.wide).day().year()).font(.caption)
                        .foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Image(systemName: "pencil").font(.subheadline)
                  }.padding(.vertical, 6).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(
                  "Edit watering on \(log.date.formatted(date: .abbreviated, time: .omitted))")
              }
            }.padding(.top, 8)
          }.padding(.horizontal, 26).padding(.bottom, 32)
        }.clipped()
          .onChange(of: plant.history) { _, history in
            if let lastLog, !history.contains(where: { $0.id == lastLog }) {
              self.lastLog = nil
              watered = false
            }
          }
          .sheet(isPresented: $editing) { PlantEditor(existing: plant) }
          .sheet(item: $editingLog) { log in WateringEditor(plantID: plantID, log: log) }
      } else {
        ContentUnavailableView("This plant has left the shelf", systemImage: "leaf")
      }
    }
    .foregroundStyle(Palette.forest).background(Palette.cream)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(Palette.cream, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .principal) { Eyebrow(text: "The plant journal") }
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("Edit plant", systemImage: "pencil") { editing = true }
          Button("Delete plant", systemImage: "trash", role: .destructive) { deleting = true }
        } label: {
          Image(systemName: "ellipsis").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Plant options")
      }
    }
    .confirmationDialog("Remove this plant?", isPresented: $deleting, titleVisibility: .visible) {
      Button("Delete plant", role: .destructive) {
        store.delete(plantID)
        dismiss()
      }
    } message: {
      Text("Its photo, notes and watering history will also be deleted. This cannot be undone.")
    }
  }
}

struct WateringEditor: View {
  @EnvironmentObject private var store: PlantStore
  @Environment(\.dismiss) private var dismiss
  var plantID: UUID
  var log: Watering
  @State private var date = Date.now
  @State private var confirm = false
  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker("Watered on", selection: $date, in: ...Date.now, displayedComponents: .date)
        } footer: {
          Text("The next soil check is calculated from your most recent watering.")
        }
        Button("Delete this watering", role: .destructive) { confirm = true }
          .foregroundStyle(.red)
      }
      .scrollContentBackground(.hidden).background(Palette.cream)
      .navigationTitle("Edit watering").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            store.updateWatering(plantID: plantID, logID: log.id, date: date)
            dismiss()
          }
        }
      }
      .onAppear { date = log.date }
      .confirmationDialog("Delete this watering?", isPresented: $confirm, titleVisibility: .visible)
      {
        Button("Delete watering", role: .destructive) {
          store.removeWatering(plantID: plantID, logID: log.id)
          dismiss()
        }
      }
    }
  }
}
