import PhotosUI
import SwiftUI
import UIKit

struct CollectionEditor: View {
  @EnvironmentObject private var museum: MuseumStore
  @Environment(\.dismiss) private var dismiss
  var existing: MuseumCollection?
  @State private var title = ""
  @State private var subtitle = ""

  var body: some View {
    NavigationStack {
      Form {
        Section {
          VStack(alignment: .leading, spacing: 10) {
            BrandMark()
            Text("Make room for\nwhat matters.").font(MuseumStyle.serif(31))
            Text("A theme, a passion, a few good finds.")
              .font(.subheadline).foregroundStyle(MuseumStyle.muted)
          }.padding(.vertical, 10)
        }.listRowBackground(Color.clear).listRowInsets(
          EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        Section {
          TextField("Collection name", text: $title).accessibilityIdentifier("collectionName")
          TextField("A short introduction", text: $subtitle, axis: .vertical).lineLimit(2...4)
        } header: {
          Text("Collection details")
        } footer: {
          Text("A collection can hold a theme, a passion, or simply the things you love.")
        }
      }
      .scrollContentBackground(.hidden).background(MuseumStyle.paper)
      .navigationTitle(existing == nil ? "New collection" : "Edit collection")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(MuseumStyle.paper, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.light, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(existing == nil ? "New collection" : "Edit collection")
            .font(.headline).foregroundStyle(MuseumStyle.ink)
        }
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            var collection = existing ?? MuseumCollection(title: "", subtitle: "")
            collection.title = title
            collection.subtitle = subtitle
            if museum.saveCollection(collection) { dismiss() }
          }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .onAppear {
        title = existing?.title ?? ""
        subtitle = existing?.subtitle ?? ""
      }
    }
  }
}

struct ObjectEditor: View {
  @EnvironmentObject private var museum: MuseumStore
  @Environment(\.dismiss) private var dismiss
  var collectionID: UUID
  var existing: MuseumObject?
  @State private var title = ""
  @State private var maker = ""
  @State private var story = ""
  @State private var acquired = Date()
  @State private var tags = ""
  @State private var artifact: Artifact = .unpictured
  @State private var photo: Data?
  @State private var pickedPhoto: PhotosPickerItem?
  @State private var loadingPhoto = false
  @State private var photoError: String?
  @State private var targetCollection: UUID?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          VStack(alignment: .leading, spacing: 7) {
            Eyebrow(
              text: existing == nil ? "A new addition" : "The details matter",
              color: MuseumStyle.cobalt)
            Text(existing == nil ? "Give it a place." : "Continue its story.")
              .font(MuseumStyle.serif(30))
          }.padding(.vertical, 16).padding(.horizontal, 12)
        }.listRowBackground(Color.clear).listRowInsets(
          EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        Section("The exhibit label") {
          TextField("Title (required)", text: $title).accessibilityIdentifier("objectTitle")
          TextField("Maker, material or year", text: $maker).accessibilityIdentifier("objectMaker")
        }
        Section {
          if photo != nil || artifact != .unpictured {
            ExhibitArtwork(artifact: artifact, photo: photo)
              .frame(height: 130).frame(maxWidth: .infinity)
              .listRowBackground(MuseumStyle.stone.opacity(0.45))
          }
          PhotosPicker(selection: $pickedPhoto, matching: .images, photoLibrary: .shared()) {
            HStack(spacing: 12) {
              Image(systemName: "photo.badge.plus").font(.title3)
                .frame(width: 42, height: 48)
                .background(MuseumStyle.cobalt.opacity(0.07)).clipShape(
                  RoundedRectangle(cornerRadius: 5))
              VStack(alignment: .leading, spacing: 4) {
                Text(
                  loadingPhoto
                    ? "Preparing photo…" : photo == nil ? "Add your own photo" : "Replace photo"
                )
                .font(.body.weight(.medium))
                Text("Private, on-device, entirely yours.")
                  .font(.caption).foregroundStyle(MuseumStyle.muted)
              }
            }.padding(.vertical, 3)
          }.disabled(loadingPhoto)
          if photo != nil {
            Button("Remove photo", role: .destructive) {
              photo = nil
              pickedPhoto = nil
            }
          } else {
            Picker("Illustration", selection: $artifact) {
              ForEach(Artifact.allCases) { Text($0.title).tag($0) }
            }
          }
        } header: {
          Text("Its portrait")
        } footer: {
          Text(
            photo == nil
              ? "A photo is optional. Choose an illustration, or leave a quiet space for one."
              : "Your photo stays offline, with this object.")
        }
        Section("Provenance") {
          DatePicker("Acquired", selection: $acquired, in: ...Date(), displayedComponents: .date)
          if museum.collections.count > 1 {
            Picker("Collection", selection: $targetCollection) {
              ForEach(museum.collections) { Text($0.title).tag(Optional($0.id)) }
            }
          }
        }
        Section {
          TextField("Where did you find it? Why does it matter?", text: $story, axis: .vertical)
            .lineLimit(4...12).accessibilityIdentifier("objectStory")
        } header: {
          Text("Its story")
        }
        Section {
          TextField("ceramics, vintage, a good find", text: $tags)
            .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier(
              "objectTags")
        } header: {
          Text("Tags")
        } footer: {
          Text("Separate tags with commas. You can filter by them in your gallery.")
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .scrollContentBackground(.hidden).background(MuseumStyle.paper)
      .navigationTitle(existing == nil ? "New object" : "Edit object")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(MuseumStyle.paper, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.light, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(existing == nil ? "New object" : "Edit object")
            .font(.headline).foregroundStyle(MuseumStyle.ink)
        }
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loadingPhoto)
            .accessibilityIdentifier("saveObject")
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") {
            UIApplication.shared.sendAction(
              #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
          }
        }
      }
      .onAppear {
        if let existing {
          title = existing.title
          maker = existing.maker
          story = existing.story
          acquired = existing.acquired
          tags = existing.tags.joined(separator: ", ")
          artifact = existing.artifact
          photo = existing.photo
        }
        targetCollection = existing?.collectionID ?? collectionID
      }
      .task(id: pickedPhoto) {
        guard let pickedPhoto else { return }
        loadingPhoto = true
        defer { loadingPhoto = false }
        do {
          guard let data = try await pickedPhoto.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
          else { throw PhotoFailure.invalid }
          try Task.checkCancellation()
          let ratio = min(1, 1600 / max(image.size.width, image.size.height))
          let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
          let format = UIGraphicsImageRendererFormat()
          format.scale = 1
          let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
          }
          guard let compressed = resized.jpegData(compressionQuality: 0.85) else {
            throw PhotoFailure.invalid
          }
          photo = compressed
        } catch is CancellationError {
        } catch {
          photoError = "This photo couldn’t be opened. Try another image."
        }
      }
      .alert(
        "Photo unavailable",
        isPresented: Binding(get: { photoError != nil }, set: { if !$0 { photoError = nil } })
      ) {
        Button("OK") { photoError = nil }
      } message: {
        Text(photoError ?? "")
      }
    }
  }

  private func save() {
    var object =
      existing
      ?? MuseumObject(
        collectionID: collectionID, title: "", maker: "", story: "", acquired: Date(), tags: [],
        artifact: .unpictured, catalogNumber: 0)
    object.collectionID = targetCollection ?? collectionID
    object.title = title
    object.maker = maker
    object.story = story
    object.acquired = acquired
    object.tags = MuseumObject.tags(from: tags)
    object.artifact = artifact
    object.photo = photo
    if museum.saveObject(object) { dismiss() }
  }
}

private enum PhotoFailure: Error { case invalid }
