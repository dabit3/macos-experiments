import SwiftUI
import UIKit

struct ObjectDetail: View {
  @EnvironmentObject private var museum: MuseumStore
  @Environment(\.dismiss) private var dismiss
  var objectID: UUID
  @State private var edit = false
  @State private var export = false
  @State private var confirmDelete = false
  @State private var favoriteFeedback = false
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    if let object = museum.object(objectID) {
      ScrollView {
        VStack(alignment: .leading, spacing: 25) {
          ZStack(alignment: .bottomLeading) {
            ExhibitArtwork(artifact: object.artifact, photo: object.photo)
              .frame(height: 315).padding(.horizontal, 25)
            Eyebrow(
              text: object.photo != nil
                ? "From your photo library"
                : object.artifact == .unpictured
                  ? "A portrait waiting to happen" : "Curio original illustration"
            )
            .padding(18)
          }.background(MuseumStyle.stone.opacity(0.48))
          VStack(alignment: .leading, spacing: 22) {
            ViewThatFits(in: .horizontal) {
              HStack {
                Eyebrow(text: "Object / \(museum.number(object))", color: MuseumStyle.cobalt)
                Spacer()
                if object.isSample { Eyebrow(text: "Sample exhibit") }
              }
              VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Object / \(museum.number(object))", color: MuseumStyle.cobalt)
                if object.isSample { Eyebrow(text: "Sample exhibit") }
              }
            }
            VStack(alignment: .leading, spacing: 9) {
              Text(object.title).font(MuseumStyle.serif(39)).tracking(-1)
                .fixedSize(horizontal: false, vertical: true)
              if !object.maker.isEmpty {
                Text(object.maker).font(.subheadline).foregroundStyle(MuseumStyle.muted)
              }
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
              Eyebrow(text: "The story")
              Text(
                object.story.isEmpty
                  ? "Every object has a story. Add yours by editing this exhibit." : object.story
              )
              .font(.body).lineSpacing(5).foregroundStyle(MuseumStyle.ink.opacity(0.85))
              .textSelection(.enabled)
            }
            let metadataLayout =
              typeSize.isAccessibilitySize
              ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
              : AnyLayout(HStackLayout(alignment: .top, spacing: 24))
            metadataLayout {
              VStack(alignment: .leading, spacing: 7) {
                Eyebrow(text: "Acquired")
                Text(object.acquired.formatted(date: .abbreviated, time: .omitted)).font(
                  .subheadline)
              }
              if !typeSize.isAccessibilitySize { Spacer() }
              VStack(alignment: .leading, spacing: 7) {
                Eyebrow(text: "Collection")
                Text(museum.collection(object.collectionID)?.title ?? "").font(.subheadline)
              }
            }.padding(.vertical, 9)
            if !object.tags.isEmpty {
              Text(object.tags.map { "#\($0)" }.joined(separator: "   "))
                .font(.caption.weight(.medium)).foregroundStyle(MuseumStyle.cobalt)
                .fixedSize(horizontal: false, vertical: true)
            }
            Button {
              export = true
            } label: {
              Label("Create a museum label", systemImage: "square.and.arrow.up")
            }.buttonStyle(MuseumButton()).padding(.top, 9)
            Text("A keepsake for your object. Ready to share.")
              .font(.caption).foregroundStyle(MuseumStyle.muted).frame(maxWidth: .infinity)
          }.padding(.horizontal, 25).padding(.bottom, 34)
        }
      }
      .background(MuseumStyle.paper).foregroundStyle(MuseumStyle.ink)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(MuseumStyle.paper, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.light, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .principal) { Eyebrow(text: "The exhibit", color: MuseumStyle.ink) }
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button {
            museum.toggleFavorite(objectID)
            favoriteFeedback.toggle()
          } label: {
            Image(systemName: object.isFavorite ? "heart.fill" : "heart").frame(
              width: 36, height: 44)
          }.accessibilityLabel(object.isFavorite ? "Remove from favorites" : "Add to favorites")
            .sensoryFeedback(.selection, trigger: favoriteFeedback)
          Menu {
            Button("Edit object", systemImage: "pencil") { edit = true }
            Button("Delete object", systemImage: "trash", role: .destructive) {
              confirmDelete = true
            }
          } label: {
            Image(systemName: "ellipsis").frame(width: 36, height: 44)
          }
          .accessibilityLabel("Object options")
        }
      }
      .sheet(isPresented: $edit) {
        ObjectEditor(collectionID: object.collectionID, existing: object)
      }
      .sheet(isPresented: $export) {
        LabelExport(object: object, collection: museum.collection(object.collectionID)?.title ?? "")
      }
      .confirmationDialog(
        "Delete “\(object.title)”?", isPresented: $confirmDelete, titleVisibility: .visible
      ) {
        Button("Delete object", role: .destructive) {
          if museum.deleteObject(objectID) { dismiss() }
        }
      } message: {
        Text("This removes the object, its story and its photo. This cannot be undone.")
      }
    }
  }
}

struct MuseumPoster: View {
  var object: MuseumObject
  var collection: String

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        HStack(spacing: 9) {
          BrandMark()
          Text("Curio").font(MuseumStyle.serif(25))
        }
        Spacer()
        Eyebrow(text: "A personal museum")
      }.padding(.bottom, 22)
      ExhibitArtwork(artifact: object.artifact, photo: object.photo)
        .frame(height: 290).background(MuseumStyle.stone.opacity(0.45))
      Rectangle().fill(MuseumStyle.cobalt).frame(width: 34, height: 4).padding(.top, 27).padding(
        .bottom, 17)
      Eyebrow(
        text: String(format: "Object / %03d", object.catalogNumber), color: MuseumStyle.cobalt)
      Text(object.title).font(MuseumStyle.serif(36)).tracking(-0.8).padding(.top, 11)
        .fixedSize(horizontal: false, vertical: true)
      Text(object.maker).font(.system(size: 13)).foregroundStyle(MuseumStyle.muted).padding(.top, 8)
      if !object.story.isEmpty {
        Text(object.story).font(.system(size: 14)).lineSpacing(5)
          .padding(.top, 22).fixedSize(horizontal: false, vertical: true)
      }
      Divider().padding(.top, 25).padding(.bottom, 15)
      Text(collection.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(2)
      Text(
        "Acquired \(object.acquired.formatted(date: .abbreviated, time: .omitted))\(object.isSample ? " · Sample exhibit" : "")"
      )
      .font(.system(size: 10)).foregroundStyle(MuseumStyle.muted).padding(.top, 7)
    }.padding(30).frame(width: 480)
      .background(MuseumStyle.paper).foregroundStyle(MuseumStyle.ink)
      .environment(\.dynamicTypeSize, .medium)
  }
}

@MainActor
enum PosterRenderer {
  static func image(object: MuseumObject, collection: String) -> UIImage? {
    let renderer = ImageRenderer(content: MuseumPoster(object: object, collection: collection))
    renderer.scale = 2
    return renderer.uiImage
  }

  static func export(object: MuseumObject, collection: String) throws -> URL {
    guard let data = image(object: object, collection: collection)?.pngData() else {
      throw ExportFailure.render
    }
    let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("MuseumLabels")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let title = object.title.unicodeScalars.map {
      CharacterSet.alphanumerics.contains($0) ? String($0) : "-"
    }.joined()
      .split(separator: "-").joined(separator: "-")
    let filename = String(title.prefix(60))
    let url = directory.appendingPathComponent(
      "Curio-\(String(format: "%03d", object.catalogNumber))-\(filename.isEmpty ? "Object" : filename).png"
    )
    try data.write(to: url, options: .atomic)
    return url
  }
}

private enum ExportFailure: LocalizedError {
  case render
  var errorDescription: String? { "The label could not be created. Please try again." }
}

struct LabelExport: View {
  @Environment(\.dismiss) private var dismiss
  var object: MuseumObject
  var collection: String
  @State private var fileURL: URL?
  @State private var preview: UIImage?
  @State private var error: String?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 19) {
          Eyebrow(text: "From your private museum", color: MuseumStyle.cobalt)
          Text("Ready to take with you.").font(MuseumStyle.serif(29)).tracking(-0.5)
          if let preview {
            Image(uiImage: preview).resizable().scaledToFit()
              .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 5)
              .accessibilityLabel("Museum label preview for \(object.title)")
          }
          if let error {
            Text(error).foregroundStyle(.red)
            Button("Try again") { generate() }.buttonStyle(MuseumButton())
          }
        }.padding(25)
      }.background(MuseumStyle.stone)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          if let fileURL, let preview {
            VStack(spacing: 9) {
              ShareLink(
                item: fileURL, preview: SharePreview(object.title, image: Image(uiImage: preview))
              ) {
                Label("Share museum label", systemImage: "square.and.arrow.up")
              }.buttonStyle(MuseumButton())
              Text("High-resolution PNG · Share or save to Files")
                .font(.caption).foregroundStyle(MuseumStyle.muted)
            }.padding(.horizontal, 25).padding(.top, 12).padding(.bottom, 8)
              .frame(maxWidth: .infinity).background(MuseumStyle.paper)
          }
        }
        .navigationTitle("Museum label").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MuseumStyle.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .onAppear { generate() }
    }
  }

  private func generate() {
    do {
      fileURL = try PosterRenderer.export(object: object, collection: collection)
      preview = fileURL.flatMap { UIImage(contentsOfFile: $0.path) }
      error = nil
    } catch { self.error = error.localizedDescription }
  }
}
