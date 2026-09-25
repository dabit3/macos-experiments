import PhotosUI
import SwiftUI
import UIKit

struct ObservationEditor: View {
  @Environment(JournalStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var draft: ObservationEntry
  @State private var tags: String
  @State private var photoItem: PhotosPickerItem?
  @State private var loadingPhoto = false
  @State private var error: String?
  @State private var discarding = false
  @FocusState private var focused: Bool
  private let initial: ObservationEntry
  private let isEditing: Bool

  init(initial: ObservationEntry = ObservationEntry(), isEditing: Bool = false) {
    self.initial = initial
    self.isEditing = isEditing
    _draft = State(initialValue: initial)
    _tags = State(initialValue: initial.tags.joined(separator: ", "))
  }

  private var changed: Bool {
    draft != initial || tags != initial.tags.joined(separator: ", ")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text("Observation name").font(.caption).foregroundStyle(FieldStyle.muted)
            TextField(
              "What did you notice?", text: $draft.title,
              prompt: Text("What did you notice?").foregroundStyle(FieldStyle.muted),
              axis: .vertical
            )
            .font(.system(.title2, design: .serif)).focused($focused)
            .accessibilityLabel("Observation name")
          }.padding(.vertical, 6)
          Picker("Category", selection: $draft.category) {
            ForEach(SpecimenCategory.allCases) { category in
              Label(category.rawValue, systemImage: category.symbol).tag(category)
            }
          }.onChange(of: draft.category) { _, category in
            if GuideSubject.find(draft.guideID)?.category != category { draft.guideID = nil }
          }
          DatePicker(
            "Observed", selection: $draft.date, in: ...Date(),
            displayedComponents: [.date, .hourAndMinute])
        } header: {
          Eyebrow(text: "The discovery")
        } footer: {
          Text("A common name or your own description. No identification needed.")
        }
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text("Location · optional").font(.caption).foregroundStyle(FieldStyle.muted)
            TextField(
              "Place or trail", text: $draft.location,
              prompt: Text("Place or trail").foregroundStyle(FieldStyle.muted)
            )
            .accessibilityLabel("Location").focused($focused)
          }.padding(.vertical, 6)
          VStack(alignment: .leading, spacing: 8) {
            Text("Tags · optional").font(.caption).foregroundStyle(FieldStyle.muted)
            TextField(
              "woodland, morning, rain", text: $tags,
              prompt: Text("woodland, morning, rain").foregroundStyle(FieldStyle.muted),
              axis: .vertical
            )
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .accessibilityLabel("Tags, separated by commas").focused($focused)
          }.padding(.vertical, 6)
        } header: {
          Eyebrow(text: "Out in the world")
        } footer: {
          Text("Separate tags with commas. Up to 8 tags. Location is text only.")
        }
        Section {
          TextField(
            "Color, shape, sound. What made you stop?", text: $draft.notes,
            prompt: Text("Color, shape, sound. What made you stop?").foregroundStyle(
              FieldStyle.muted), axis: .vertical
          )
          .lineLimit(5...12).focused($focused).accessibilityLabel("Observation notes")
        } header: {
          Eyebrow(text: "Field notes")
        }
        Section {
          if let data = draft.photo, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
              .frame(maxWidth: .infinity).accessibilityLabel("Selected observation photo")
            Button("Remove photo", role: .destructive) {
              draft.photo = nil
              photoItem = nil
            }
          }
          PhotosPicker(selection: $photoItem, matching: .images) {
            Label(
              draft.photo == nil ? "Add a photograph" : "Replace photograph", systemImage: "photo"
            )
            .frame(minHeight: 32)
          }.disabled(loadingPhoto)
          if loadingPhoto { ProgressView("Preparing photograph…") }
        } header: {
          Eyebrow(text: "A closer look")
        } footer: {
          Text("Optional. Photos are resized and saved privately with this observation.")
        }
      }
      .scrollContentBackground(.hidden).background { Paper() }
      .foregroundStyle(FieldStyle.ink).navigationTitle(
        isEditing ? "Edit entry" : "New entry"
      )
      .navigationBarTitleDisplayMode(.inline)
      .scrollDismissesKeyboard(.interactively)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { if changed { discarding = true } else { dismiss() } }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            focused = false
            do {
              draft.tags = ObservationEntry.normalizedTags(tags)
              try store.save(draft)
              dismiss()
            } catch { self.error = error.localizedDescription }
          }.fontWeight(.semibold).disabled(loadingPhoto)
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { focused = false }
        }
      }
      .interactiveDismissDisabled(changed)
      .confirmationDialog(
        "Discard your changes?", isPresented: $discarding, titleVisibility: .visible
      ) {
        Button("Discard changes", role: .destructive) { dismiss() }
      }
      .alert(
        "One small thing",
        isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
      ) {
        Button("OK") { error = nil }
      } message: {
        Text(error ?? "")
      }
      .task(id: photoItem) {
        guard let item = photoItem else { return }
        loadingPhoto = true
        defer { loadingPhoto = false }
        do {
          guard let data = try await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
          else {
            throw JournalError.invalid("That photo could not be opened. Please choose another.")
          }
          try Task.checkCancellation()
          let longest = max(image.size.width, image.size.height)
          let factor = min(1, 1600 / max(longest, 1))
          let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
          let format = UIGraphicsImageRendererFormat()
          format.scale = 1
          format.opaque = true
          let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
          }
          guard let jpeg = resized.jpegData(compressionQuality: 0.8) else {
            throw JournalError.invalid("That photo could not be saved. Please choose another.")
          }
          draft.photo = jpeg
        } catch is CancellationError {
        } catch { self.error = error.localizedDescription }
      }
    }
  }
}
