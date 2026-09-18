import PhotosUI
import SwiftUI

struct PageEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PressStore
    @State private var draft: MagazinePage
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var importError: String?
    @State private var importing = false
    let theme: PressTheme
    let index: Int
    var save: (MagazinePage) -> Void

    init(page: MagazinePage, theme: PressTheme, index: Int, save: @escaping (MagazinePage) -> Void) {
        _draft = State(initialValue: page)
        self.theme = theme
        self.index = index
        self.save = save
    }

    var body: some View {
        let importLabel = importing ? "Importing photo…" : "Choose from your photos"
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .center, spacing: 22) {
                        PageArtwork(page: draft, theme: theme, index: index)
                            .frame(width: 93)
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "Page \(String(format: "%02d", index + 1))")
                            Text(draft.kind.title).font(PressStyle.serif(28))
                            Text("Your words.\nOur typesetting.")
                                .font(PressStyle.sans(12)).foregroundStyle(PressStyle.muted)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18).background(
                            Color(uiColor: UIColor(hex: 0xE4E6DE)),
                            in: RoundedRectangle(cornerRadius: 10))
                    if let message = draft.validationMessage {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(PressStyle.sans(12)).foregroundStyle(Color(uiColor: UIColor(hex: 0xA23423)))
                    }
                    field("Title", text: $draft.title, limit: MagazinePage.titleLimit, id: "page-title")
                    field("Place", text: $draft.location, limit: MagazinePage.locationLimit, id: "page-place")
                    field(
                        "Caption", text: $draft.caption, limit: MagazinePage.captionLimit, id: "page-caption")
                    if draft.kind == .story || draft.kind == .fieldNotes {
                        VStack(alignment: .leading, spacing: 8) {
                            fieldLabel(
                                draft.kind == .story ? "Story" : "Notes · one per line",
                                count: draft.body.count, limit: MagazinePage.bodyLimit)
                            TextEditor(text: $draft.body).frame(minHeight: 190)
                                .font(PressStyle.sans(15)).scrollContentBackground(.hidden)
                                .padding(10).background(.white, in: RoundedRectangle(cornerRadius: 10))
                                .accessibilityLabel(draft.kind == .story ? "Story text" : "Notes text")
                            if draft.kind == .fieldNotes {
                                Text("Up to 6 notes, each 150 characters. One note per line.")
                                    .font(PressStyle.sans(11)).foregroundStyle(PressStyle.muted)
                            }
                        }
                    }
                    if draft.kind == .cover || draft.kind == .photograph {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: "Photography", color: PressStyle.ink)
                            HStack(spacing: 12) {
                                photoChoice("manarola", label: "Evening coast")
                                photoChoice("harbour", label: "Blue harbour")
                            }
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label(
                                    importLabel,
                                    systemImage: "photo.badge.plus"
                                )
                                .font(PressStyle.sans(14, bold: true)).frame(
                                    maxWidth: .infinity, minHeight: 48
                                )
                                .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
                            }.disabled(importing)
                            if draft.imageName.hasPrefix("import-") {
                                Label("Your photo is selected", systemImage: "checkmark.circle.fill")
                                    .font(PressStyle.sans(12)).foregroundStyle(PressStyle.cobalt)
                            }
                            if let importError {
                                Text(importError).font(PressStyle.sans(12)).foregroundStyle(.red)
                            }
                            Text(
                                "Photos fill the frame with a centered crop. Originals in your photo library are unchanged."
                            )
                            .font(PressStyle.sans(11)).foregroundStyle(PressStyle.muted)
                        }
                    }
                    Text("The preview and exported PDF use the same typesetting engine.")
                        .font(PressStyle.sans(11)).foregroundStyle(PressStyle.muted).padding(.bottom, 16)
                }.padding(22)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PressStyle.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(PressStyle.muted)
                }
                ToolbarItem(placement: .principal) { Eyebrow(text: "Edit page", color: PressStyle.ink) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save(draft)
                        dismiss()
                    }.font(PressStyle.sans(15, bold: true))
                        .disabled(draft.validationMessage != nil || importing)
                        .opacity(draft.validationMessage == nil && !importing ? 1 : 0.35)
                        .accessibilityLabel("Save page changes")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                importing = true
                importError = nil
                Task {
                    do { draft.imageName = try await store.importPhoto(item) } catch {
                        importError = error.localizedDescription
                    }
                    importing = false
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, limit: Int, id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label, count: text.wrappedValue.count, limit: limit)
            TextField(label, text: text, axis: .vertical)
                .lineLimit(1...4).font(PressStyle.sans(16))
                .padding(14).frame(minHeight: 50)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier(id).accessibilityLabel(label)
        }
    }

    private func fieldLabel(_ label: String, count: Int, limit: Int) -> some View {
        HStack {
            Eyebrow(text: label, color: PressStyle.ink)
            Spacer()
            Text("\(count)/\(limit)").font(PressStyle.sans(10))
                .foregroundStyle(count > limit ? .red : PressStyle.muted)
        }
    }

    private func photoChoice(_ name: String, label: String) -> some View {
        Button {
            draft.imageName = name
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                if let image = PageRenderer.photograph(name) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(height: 90).frame(maxWidth: .infinity).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(alignment: .topTrailing) {
                            if draft.imageName == name {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(
                                    .white, PressStyle.cobalt
                                )
                                .padding(8)
                            }
                        }
                }
                Text(label).font(PressStyle.sans(11)).foregroundStyle(PressStyle.ink)
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain).accessibilityLabel("Use \(label) photo")
    }
}
