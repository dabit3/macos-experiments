import PhotosUI
import SwiftUI

struct PlantEditor: View {
  @EnvironmentObject private var store: PlantStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize
  var existing: Plant?
  @State private var name = ""
  @State private var room = "Living room"
  @State private var kind: PlantKind = .monstera
  @State private var interval = 7
  @State private var baseline = Date.now
  @State private var notes = ""
  @State private var photo: Data?
  @State private var selectedPhoto: PhotosPickerItem?
  @State private var photoError = false
  @State private var loadingPhoto = false
  private enum Field { case name, room, notes }
  @FocusState private var focused: Field?
  private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack {
            Spacer()
            PlantPortrait(
              plant: Plant(
                name: name, kind: kind, room: room, interval: interval, startedAt: baseline,
                photo: photo)
            )
            .frame(width: 130, height: 150).clipped()
            Spacer()
          }.listRowBackground(Color.clear)
          PhotosPicker(selection: $selectedPhoto, matching: .images) {
            Label(
              loadingPhoto
                ? "Preparing photo…" : photo == nil ? "Add a plant photo" : "Choose another photo",
              systemImage: "photo")
          }.disabled(loadingPhoto)
          if photo != nil {
            Button("Use illustration instead", role: .destructive) {
              photo = nil
              selectedPhoto = nil
            }
          }
        }
        Section("Make it yours") {
          TextField("Plant name", text: $name).focused($focused, equals: .name)
            .textInputAutocapitalization(.words)
            .accessibilityIdentifier("plantName")
          Picker("Plant / illustration", selection: $kind) {
            ForEach(PlantKind.allCases) { Text($0.rawValue).tag($0) }
          }
          TextField("Room", text: $room).textInputAutocapitalization(.words)
            .focused($focused, equals: .room)
            .accessibilityIdentifier("plantRoom")
        }
        Section {
          if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
              Text("Check every \(interval) \(interval == 1 ? "day" : "days")")
                .foregroundStyle(Palette.forest).fixedSize(horizontal: false, vertical: true)
              Stepper("Watering interval", value: $interval, in: 1...90).labelsHidden()
                .accessibilityLabel("Watering interval").accessibilityValue("\(interval) days")
            }
          } else {
            Stepper(value: $interval, in: 1...90) {
              HStack {
                Text("Check every")
                Spacer()
                Text("\(interval) \(interval == 1 ? "day" : "days")").foregroundStyle(
                  Palette.forest
                )
                .fontWeight(.semibold)
              }
            }.accessibilityLabel("Watering interval, \(interval) days")
          }
          if existing?.history.isEmpty != false {
            DatePicker(
              "Last watered / start date", selection: $baseline, in: ...Date.now,
              displayedComponents: .date)
          }
        } header: {
          Text("A gentle rhythm")
        } footer: {
          Text(
            "Reminders count from the latest watering. Always check the soil first; needs change with light, season and pot size. You can adjust history on the plant page."
          )
        }
        Section("Notes") {
          TextField("Light, new leaves, little observations…", text: $notes, axis: .vertical)
            .focused($focused, equals: .notes)
            .lineLimit(4...8).accessibilityIdentifier("plantNotes")
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .scrollContentBackground(.hidden).background(Palette.cream)
      .navigationTitle(existing == nil ? "A new little life" : "Edit plant")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }.fontWeight(.semibold).disabled(!valid || loadingPhoto)
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { focused = nil }
        }
      }
      .onAppear {
        guard let existing else { return }
        name = existing.name
        room = existing.room
        kind = existing.kind
        interval = existing.interval
        baseline = existing.startedAt
        notes = existing.notes
        photo = existing.photo
      }
      .onChange(of: selectedPhoto) { _, item in
        guard let item else { return }
        loadingPhoto = true
        Task {
          defer { loadingPhoto = false }
          do {
            guard let data = try await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
            else {
              photoError = true
              return
            }
            let ratio = min(1, 1200 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            photo = UIGraphicsImageRenderer(size: size, format: format)
              .image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
              .jpegData(compressionQuality: 0.8)
          } catch {
            photoError = true
          }
        }
      }
      .alert("That photo couldn’t be opened", isPresented: $photoError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Try another photo. Your plant details are still here.")
      }
    }
  }

  private func save() {
    var plant =
      existing ?? Plant(name: name, kind: kind, room: room, interval: interval, startedAt: baseline)
    plant.name = name
    plant.kind = kind
    plant.room = room
    plant.interval = interval
    plant.startedAt = baseline
    plant.notes = notes
    plant.photo = photo
    if store.save(plant) { dismiss() }
  }
}
