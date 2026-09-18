import PhotosUI
import SwiftUI
import UIKit

struct JourneyEditor: View {
  @EnvironmentObject private var journal: Journal
  @Environment(\.dismiss) private var dismiss
  var existing: Journey?
  @State private var title = ""
  @State private var region = ""
  @State private var style = JourneyStyle.coast
  private var valid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("e.g. A summer in Sicily", text: $title)
            .accessibilityLabel("Journey title")
            .onChange(of: title) { _, value in title = String(value.prefix(80)) }
          TextField("e.g. SICILY · ITALY", text: $region)
            .accessibilityLabel("Region")
            .onChange(of: region) { _, value in region = String(value.prefix(80)) }
        } header: {
          Text("Name your next chapter")
        } footer: {
          Text("A title is all you need. Add places and dates as you go.")
        }
        Section("Choose your cover") {
          Landscape(style: style).frame(height: 175).listRowInsets(EdgeInsets())
          Picker("Illustration", selection: $style) {
            ForEach(JourneyStyle.allCases) { style in Text(style.name).tag(style) }
          }
        }
      }
      .scrollContentBackground(.hidden).background(Ink.paper)
      .navigationTitle(existing == nil ? "A new journey" : "Edit journey")
      .navigationBarTitleDisplayMode(.inline)
      .journalNavigation()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            var trip = existing ?? Journey(title: title, region: region, style: style)
            trip.title = title
            trip.region = region
            trip.style = style
            if journal.save(trip) {
              UIImpactFeedbackGenerator(style: .soft).impactOccurred()
              dismiss()
            }
          }
          .disabled(!valid)
        }
      }
      .onAppear {
        if let existing {
          title = existing.title
          region = existing.region
          style = existing.style
        }
      }
    }
  }
}

struct MemoryEditor: View {
  @EnvironmentObject private var journal: Journal
  @Environment(\.dismiss) private var dismiss
  @ScaledMetric(relativeTo: .body) private var noteHeight = 180.0
  var journeyID: UUID
  var existing: Memory?
  @State private var place = ""
  @State private var date = Date()
  @State private var note = ""
  @State private var photo: Data?
  @State private var selection: PhotosPickerItem?
  @State private var isLoadingPhoto = false
  @State private var photoError: String?
  private var valid: Bool {
    !place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoadingPhoto
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("A place to remember") {
          TextField("Place name", text: $place).accessibilityLabel("Place name")
            .onChange(of: place) { _, value in place = String(value.prefix(80)) }
          DatePicker("Date", selection: $date, displayedComponents: .date)
        }
        Section {
          TextEditor(text: $note)
            .frame(height: min(noteHeight, 280))
            .overlay(alignment: .topLeading) {
              if note.isEmpty {
                Text("What do you want to remember?")
                  .foregroundStyle(.tertiary).padding(.top, 8).padding(.leading, 5)
                  .allowsHitTesting(false).accessibilityHidden(true)
              }
            }
            .accessibilityLabel("Memory note")
            .onChange(of: note) { _, value in note = String(value.prefix(4000)) }
        } header: {
          Text("The little details")
        } footer: {
          Text("\(note.count) / 4,000 characters · saved only on this device")
        }
        Section {
          if let photo, let image = UIImage(data: photo) {
            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200)
              .frame(maxWidth: .infinity).accessibilityLabel("Selected photo preview")
          }
          PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            Label(
              photo == nil ? "Add a photo" : "Choose another photo",
              systemImage: "photo.on.rectangle.angled")
          }
          .disabled(isLoadingPhoto)
          if isLoadingPhoto {
            ProgressView("Preparing photo…")
          }
          if photo != nil {
            Button("Remove photo", role: .destructive) {
              photo = nil
              selection = nil
            }
          }
        } header: {
          Text("A window into the day")
        } footer: {
          Text("Without a photo, your journey's original illustration will appear here.")
        }
      }
      .scrollContentBackground(.hidden).background(Ink.paper)
      .navigationTitle(existing == nil ? "A new stop" : "Edit memory")
      .navigationBarTitleDisplayMode(.inline)
      .journalNavigation()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            var memory = existing ?? Memory(place: place, date: date, note: note)
            memory.place = place
            memory.date = date
            memory.note = note
            memory.photo = photo
            if journal.saveMemory(memory, in: journeyID) {
              UIImpactFeedbackGenerator(style: .soft).impactOccurred()
              dismiss()
            }
          }
          .disabled(!valid)
        }
      }
      .onAppear {
        if let existing {
          place = existing.place
          date = existing.date
          note = existing.note
          photo = existing.photo
        }
      }
      .task(id: selection) {
        guard let selection else { return }
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        do {
          guard let data = try await selection.loadTransferable(type: Data.self),
            let image = UIImage(data: data),
            image.size.width > 0, image.size.height > 0
          else {
            photoError = "That photo could not be opened. Please choose a different image."
            return
          }
          try Task.checkCancellation()
          let ratio = min(1, 1600 / max(image.size.width, image.size.height))
          let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
          let format = UIGraphicsImageRendererFormat()
          format.scale = 1
          let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
          }
          photo = resized.jpegData(compressionQuality: 0.82)
        } catch is CancellationError {
          return
        } catch {
          photoError = "This photo isn't available offline. Try one stored on your device."
        }
      }
      .alert(
        "Unable to import photo",
        isPresented: Binding(
          get: { photoError != nil }, set: { if !$0 { photoError = nil } }
        )
      ) {
        Button("OK") { photoError = nil }
      } message: {
        Text(photoError ?? "")
      }
    }
  }
}
