import PhotosUI
import SwiftUI

struct LibraryView: View {
  @EnvironmentObject private var library: LibraryStore
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var opened: Negative?
  @State private var pickerItem: PhotosPickerItem?
  @State private var showRecipes = false
  @State private var showAbout = false
  @State private var deleting: Negative?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        LazyVGrid(
          columns: Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: typeSize.isAccessibilitySize ? 1 : 2),
          alignment: .leading, spacing: 20
        ) {
          ForEach(library.state.negatives) { negative in
            photograph(negative)
          }
        }
      }
      .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
    }
    .background(Palette.background)
    .foregroundStyle(Palette.ink)
    .safeAreaInset(edge: .bottom) {
      importControl.buttonStyle(PrimaryButton()).disabled(library.importing)
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
        .background(Palette.background)
    }
    .fullScreenCover(item: $opened) { negative in EditorView(negative: negative) }
    .sheet(isPresented: $showRecipes) { RecipeShelf() }
    .sheet(isPresented: $showAbout) { AboutView() }
    .onChange(of: pickerItem) { _, item in
      guard let item else { return }
      Task {
        opened = await library.importPhoto(item)
        pickerItem = nil
      }
    }
    .sheet(
      isPresented: Binding(
        get: { library.error != nil }, set: { if !$0 { library.error = nil } })
    ) {
      NoticeSheet(
        title: "Something went wrong", detail: library.error ?? "", actionTitle: "OK"
      ) { library.error = nil }
    }
    .sheet(item: $deleting) { negative in
      NoticeSheet(
        title: "Remove \(negative.title)?",
        detail: "Its edits are removed from Silverroom. Your Photos library is unchanged.",
        actionTitle: "Remove"
      ) { library.remove(negative) }
    }
  }

  private var importControl: some View {
    let importing = library.importing
    return PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
      HStack(spacing: 8) {
        if importing { ProgressView().tint(Palette.background) } else { Image(systemName: "plus") }
        Text(importing ? "Opening…" : "Import photo")
      }
      .frame(maxWidth: .infinity)
    }
  }

  private var header: some View {
    HStack(spacing: 0) {
      Text("Silverroom").font(TypeStyle.display)
        .frame(maxWidth: .infinity, alignment: .leading)
      IconButton(symbol: "bookmark", label: "Recipes", size: 18) { showRecipes = true }
      IconButton(symbol: "info.circle", label: "About Silverroom", size: 18) { showAbout = true }
    }
    .padding(.leading, 4).padding(.top, 4)
  }

  private func photograph(_ negative: Negative) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Button {
        opened = negative
      } label: {
        GeometryReader { geometry in
          if let image = library.thumbnails[negative.id] {
            Image(uiImage: image).resizable().scaledToFill()
              .frame(width: geometry.size.width, height: geometry.size.height)
              .clipped()
          } else {
            Palette.panel.overlay { ProgressView().tint(Palette.ink) }
          }
        }
        .aspectRatio(0.8, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Open \(negative.title)\(negative.isSample ? ", sample photo" : "")")
      .contextMenu {
        if !negative.isSample {
          Button("Remove from Silverroom", systemImage: "trash", role: .destructive) {
            deleting = negative
          }
        }
      }
      .accessibilityHint(negative.isSample ? "" : "Touch and hold to remove")
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(negative.title).font(TypeStyle.label).lineLimit(2)
        if negative.isSample {
          Text("Sample").font(TypeStyle.micro).foregroundStyle(Palette.muted)
        }
      }
      .padding(.horizontal, 2)
    }
    .task(id: negative.settings) { await library.refreshThumbnail(negative) }
  }
}

struct AboutView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      SheetHeader(title: "About") { dismiss() }
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          section(
            "On device",
            "Every adjustment is processed locally with Core Image. No account, upload or subscription."
          )
          section(
            "Non-destructive",
            "Originals stay untouched and edits save automatically. Undo and redo cover the current session."
          )
          section(
            "Sample photos",
            "The cove and Quiet morning are original AI-generated images included to try the tools."
          )
          section(
            "Export",
            "Exports are full-resolution sRGB JPEGs with camera and location metadata removed. Crop and rotation set the final dimensions."
          )
          Text("Version 1.0").font(TypeStyle.caption).foregroundStyle(Palette.muted)
        }
        .padding(20)
      }
    }
    .foregroundStyle(Palette.ink).presentationBackground(Palette.background)
    .presentationDragIndicator(.visible)
  }

  private func section(_ title: String, _ detail: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(TypeStyle.heading)
      Text(detail).font(TypeStyle.body).foregroundStyle(Palette.muted)
    }
  }
}
