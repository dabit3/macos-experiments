import PhotosUI
import SwiftUI

struct LibraryView: View {
  @EnvironmentObject private var library: LibraryStore
  @State private var opened: Negative?
  @State private var pickerItem: PhotosPickerItem?
  @State private var showRecipes = false
  @State private var showAbout = false
  @State private var deleting: Negative?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        header
        VStack(alignment: .leading, spacing: 8) {
          Text("A little light.\nA lasting feeling.")
            .font(.system(size: 39, weight: .regular, design: .serif))
            .tracking(-1.3)
            .foregroundStyle(Palette.silver)
          Text("Your personal, pocket-sized darkroom.")
            .font(.subheadline).foregroundStyle(Palette.muted)
        }
        VStack(spacing: 16) {
          HStack {
            Eyebrow(text: "Contact sheet")
            Spacer()
            Eyebrow(text: String(format: "%02d frames", library.state.negatives.count))
          }
          ForEach(Array(library.state.negatives.enumerated()), id: \.element.id) {
            index, negative in
            negativeCard(negative, index: index)
          }
        }
        HStack(spacing: 8) {
          Image(systemName: "lock").font(.caption)
          Text("Only on your device. Always your originals.")
            .font(.caption)
        }
        .foregroundStyle(Palette.muted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
      }
      .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 20)
    }
    .background(Palette.background)
    .safeAreaInset(edge: .bottom) {
      importControl
        .buttonStyle(AmberButton()).disabled(library.importing)
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
        .background(Palette.background)
    }
    .fullScreenCover(item: $opened) { negative in
      EditorView(negative: negative)
    }
    .sheet(isPresented: $showRecipes) { RecipeShelf() }
    .sheet(isPresented: $showAbout) { AboutView() }
    .onChange(of: pickerItem) { _, item in
      guard let item else { return }
      Task {
        opened = await library.importPhoto(item)
        pickerItem = nil
      }
    }
    .alert(
      "Couldn’t complete that",
      isPresented: Binding(
        get: { library.error != nil }, set: { if !$0 { library.error = nil } })
    ) {
      Button("OK", role: .cancel) { library.error = nil }
    } message: {
      Text(library.error ?? "")
    }
    .confirmationDialog(
      "Remove this photograph from Silverroom?",
      isPresented: Binding(
        get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    ) {
      Button("Remove photograph", role: .destructive) {
        if let deleting { library.remove(deleting) }
        deleting = nil
      }
    } message: {
      Text("The photo in your Photos library will not be changed.")
    }
  }

  private var importControl: some View {
    let importing = library.importing
    return PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
      HStack(spacing: 10) {
        if importing { ProgressView().tint(Palette.background) } else { Image(systemName: "plus") }
        Text(importing ? "Opening photograph…" : "Import a photograph")
        Spacer()
        Image(systemName: "arrow.up.right")
      }
    }
  }

  private var header: some View {
    HStack(spacing: 12) {
      DarkroomMark()
      Text("SILVERROOM")
        .font(.system(size: 17, weight: .medium, design: .serif)).tracking(3)
        .foregroundStyle(Palette.silver)
      Spacer(minLength: 0)
      Button {
        showRecipes = true
      } label: {
        Image(systemName: "bookmark").frame(width: 44, height: 44)
      }
      .accessibilityLabel("Saved recipes")
      Button {
        showAbout = true
      } label: {
        Image(systemName: "info.circle").frame(width: 36, height: 44)
      }
      .accessibilityLabel("About Silverroom")
    }
    .foregroundStyle(Palette.muted)
  }

  private func negativeCard(_ negative: Negative, index: Int) -> some View {
    Button {
      opened = negative
    } label: {
      VStack(alignment: .leading, spacing: 0) {
        HStack {
          Text(String(format: "%02d", index + 1))
          Spacer()
          Text(negative.isSample ? "SAMPLE NEGATIVE" : "YOUR NEGATIVE")
          Image(systemName: "arrow.up.right")
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.7)
        .foregroundStyle(Palette.amber).padding(.horizontal, 12).padding(.vertical, 10)
        GeometryReader { geometry in
          if let image = library.thumbnails[negative.id] {
            Image(uiImage: image).resizable().scaledToFill()
              .frame(width: geometry.size.width, height: geometry.size.height).clipped()
          } else {
            Palette.panel.overlay { ProgressView().tint(Palette.amber) }
          }
        }
        .frame(height: index == 0 ? 330 : 230)
        .padding(.horizontal, 8)
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(negative.title).font(.system(.title2, design: .serif))
              .foregroundStyle(Palette.silver)
            Text(negative.subtitle).font(.caption).foregroundStyle(Palette.muted)
          }
          Spacer()
          Image(systemName: "arrow.right").font(.title3).foregroundStyle(Palette.amber)
        }
        .padding(16)
      }
      .background(Palette.panel)
      .overlay { Rectangle().stroke(Palette.line, lineWidth: 1) }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Open \(negative.title)\(negative.isSample ? ", sample photograph" : "")")
    .contextMenu {
      if !negative.isSample {
        Button("Remove from Silverroom", role: .destructive) { deleting = negative }
      }
    }
    .task(id: negative.settings) { await library.refreshThumbnail(negative) }
  }
}

struct AboutView: View {
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          DarkroomMark().padding(.top, 25)
          Text("Made for the\nway you see.")
            .font(.system(size: 38, design: .serif)).foregroundStyle(Palette.silver)
          Text("A slower, more thoughtful place for your photographs.")
            .font(.title3).foregroundStyle(Palette.muted)
          Hairline()
          aboutSection(
            "A private darkroom",
            "Every adjustment happens on your device with Core Image. There are no accounts, uploads, or subscriptions."
          )
          aboutSection(
            "Originals stay original",
            "Silverroom keeps a local copy of imported photographs and saves your edits separately. Reset at any time."
          )
          aboutSection(
            "A beautiful starting point",
            "The cove and Quiet morning are original AI-generated sample photographs, included for exploration."
          )
          aboutSection(
            "Ready to leave the room",
            "Export a full-resolution, high-quality sRGB JPEG. Rotation and the optional square crop determine its dimensions. Location and camera metadata are not included."
          )
          Eyebrow(text: "Silverroom / Version 1.0")
        }
        .padding(26)
      }
      .background(Palette.background)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }

  private func aboutSection(_ title: String, _ detail: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.headline).foregroundStyle(Palette.silver)
      Text(detail).font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(4)
    }
  }
}
