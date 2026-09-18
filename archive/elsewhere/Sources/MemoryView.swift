import SwiftUI
import UIKit

struct MemoryView: View {
  @EnvironmentObject private var journal: Journal
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicType
  let journeyID: UUID
  let memoryID: UUID
  @State private var editing = false
  @State private var deleting = false
  @State private var postcard = false

  var body: some View {
    Group {
      if let trip = journal.journey(journeyID),
        let memory = trip.stops.first(where: { $0.id == memoryID })
      {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 0) {
              MemoryArt(photo: memory.photo, style: trip.style)
                .frame(height: dynamicType.isAccessibilitySize ? 125 : 215)
              HStack {
                Eyebrow(
                  text: memory.photo == nil ? "An illustrated memory" : "From your camera roll",
                  color: Ink.muted)
                Spacer()
                Image(systemName: "sparkle").foregroundStyle(Ink.red)
              }
              .padding(14)
            }
            .padding(10).background(.white).rotationEffect(.degrees(-1.5))
            .shadow(color: Ink.navy.opacity(0.08), radius: 8, y: 4)
            HStack {
              Eyebrow(text: memory.date.formatted(.dateTime.day().month(.wide).year()))
              Spacer()
              Button {
                journal.toggleFavorite(memoryID, in: journeyID)
                UISelectionFeedbackGenerator().selectionChanged()
              } label: {
                Image(systemName: memory.isFavorite ? "heart.fill" : "heart")
                  .font(.title2).foregroundStyle(Ink.red).frame(width: 44, height: 44)
              }
              .accessibilityLabel(memory.isFavorite ? "Remove from saved" : "Save to favorites")
            }
            Text(memory.place).font(.system(.largeTitle, design: .serif)).foregroundStyle(Ink.navy)
            if memory.note.isEmpty {
              Button("Add the little details") { editing = true }
                .font(.system(.body, design: .serif)).foregroundStyle(Ink.blue)
                .padding(.vertical, 16)
            } else {
              Text(memory.note).font(.system(.title3, design: .serif))
                .lineSpacing(7).foregroundStyle(Ink.navy)
                .textSelection(.enabled)
            }
            HStack {
              Rectangle().fill(Ink.red).frame(width: 30, height: 1)
              Eyebrow(text: trip.title, color: Ink.muted)
            }
          }
          .padding(24)
        }
        .background(Ink.paper)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          ActionShelf {
            Button {
              postcard = true
            } label: {
              Label("Make a postcard", systemImage: "rectangle.and.pencil.and.ellipsis")
            }
          }
        }
        .sheet(isPresented: $editing) { MemoryEditor(journeyID: journeyID, existing: memory) }
        .sheet(isPresented: $postcard) { PostcardView(journey: trip, memory: memory) }
      } else {
        EmptyJournal(
          title: "A memory moved on.", detail: "This stop has been removed from the journal.")
      }
    }
    .navigationTitle("A little memory").navigationBarTitleDisplayMode(.inline)
    .journalNavigation()
    .toolbar(.hidden, for: .tabBar)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("Edit memory", systemImage: "pencil") { editing = true }
          Button("Delete stop", systemImage: "trash", role: .destructive) { deleting = true }
        } label: {
          Image(systemName: "ellipsis").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Memory options")
      }
    }
    .confirmationDialog("Delete this stop?", isPresented: $deleting, titleVisibility: .visible) {
      Button("Delete stop", role: .destructive) {
        if journal.deleteMemory(memoryID, in: journeyID) { dismiss() }
      }
    } message: {
      Text("This memory, note and photo will be removed.")
    }
  }
}

struct PostcardArtwork: View {
  var journey: Journey
  var memory: Memory
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Eyebrow(text: "A small piece of somewhere", color: Ink.blue)
        Spacer()
        Text("01").font(.system(size: 20, design: .monospaced)).foregroundStyle(Ink.red)
      }
      .padding(.bottom, 18)
      MemoryArt(photo: memory.photo, style: journey.style).frame(height: 400).clipped()
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 10) {
          Text("Greetings from").font(.system(size: 24, design: .serif)).italic()
          Text(memory.place).font(.system(size: 52, design: .serif))
            .lineLimit(2).minimumScaleFactor(0.6)
        }
        Spacer(minLength: 10)
        Stamp(text: "SENT WITH\nLOVE").scaleEffect(1.1).padding(10)
      }
      .foregroundStyle(Ink.navy).padding(.top, 22)
      Text(memory.note.isEmpty ? "A moment worth keeping." : String(memory.note.prefix(220)))
        .font(.system(size: 22, design: .serif)).lineSpacing(6)
        .foregroundStyle(Ink.navy).lineLimit(5).padding(.top, 18)
      Spacer(minLength: 20)
      Rectangle().fill(Ink.navy.opacity(0.2)).frame(height: 1)
      HStack {
        Text(memory.date.formatted(.dateTime.day().month(.wide).year()))
        Spacer()
        Text("ELSEWHERE")
      }
      .font(.system(size: 13, weight: .medium, design: .monospaced)).tracking(2)
      .foregroundStyle(Ink.blue).padding(.top, 16)
    }
    .padding(32).frame(width: 600, height: 880).background(Ink.paper)
  }
}

@MainActor
enum PostcardExporter {
  enum ExportError: Error {
    case encodingFailed
  }

  static func render(journey: Journey, memory: Memory) -> UIImage? {
    let renderer = ImageRenderer(
      content: PostcardArtwork(journey: journey, memory: memory)
        .environment(\.dynamicTypeSize, .large))
    renderer.scale = 2
    return renderer.uiImage
  }

  static func write(
    image: UIImage, place: String,
    directory: URL = URL.cachesDirectory.appending(path: "Postcards", directoryHint: .isDirectory)
  ) throws -> URL {
    guard let data = image.pngData() else { throw ExportError.encodingFailed }
    let folder = directory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let name = String(place.prefix(80)).components(separatedBy: .alphanumerics.inverted)
      .filter { !$0.isEmpty }.joined(separator: " ")
    let url = folder.appending(path: name.isEmpty ? "Elsewhere.png" : "Greetings from \(name).png")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    do {
      try data.write(to: url, options: .atomic)
      return url
    } catch {
      try? FileManager.default.removeItem(at: folder)
      throw error
    }
  }
}

struct PostcardShare: Identifiable {
  let url: URL
  var id: URL { url }
}

struct PostcardView: View {
  @Environment(\.dismiss) private var dismiss
  var journey: Journey
  var memory: Memory
  @State private var image: UIImage?
  @State private var share: PostcardShare?
  @State private var exportDirectory: URL?
  @State private var inspecting = false
  @State private var exportError = false
  @State private var shareError = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 22) {
          Eyebrow(text: "Some things are worth sending", color: Ink.blue)
          if let image {
            Button {
              inspecting = true
            } label: {
              Image(uiImage: image).resizable().scaledToFit()
                .shadow(color: Ink.navy.opacity(0.12), radius: 12, y: 8)
                .overlay(alignment: .topTrailing) {
                  Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .foregroundStyle(Ink.blue).padding(12).background(Ink.paper, in: Circle())
                    .padding(8)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Inspect postcard from \(memory.place)")
            .accessibilityHint("Open a larger preview with zoom controls.")
            Text("Tap to inspect · 1200 × 1760 pixels")
              .font(.caption).foregroundStyle(Ink.muted)
          } else if exportError {
            EmptyJournal(
              title: "Couldn't make your postcard.", detail: "Close this page and try again.")
          } else {
            ProgressView("Pressing your postcard…")
          }
          Text(
            memory.note.count > 220
              ? "Your postcard includes an excerpt of your note. The full memory stays in your journal."
              : "A real image, made on your device.\nSave it, or send a little hello."
          )
          .font(.caption).multilineTextAlignment(.center).foregroundStyle(Ink.muted)
        }
        .padding(24)
      }
      .background(Ink.pale).navigationTitle("Your postcard").navigationBarTitleDisplayMode(.inline)
      .journalNavigation()
      .safeAreaInset(edge: .bottom, spacing: 0) {
        ActionShelf {
          Button {
            guard let image else { return }
            do {
              let url = try PostcardExporter.write(image: image, place: memory.place)
              exportDirectory = url.deletingLastPathComponent()
              share = PostcardShare(url: url)
            } catch {
              shareError = true
            }
          } label: {
            Label("Share postcard", systemImage: "square.and.arrow.up")
          }
          .disabled(image == nil)
        }
      }
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
      .task {
        image = PostcardExporter.render(journey: journey, memory: memory)
        exportError = image == nil
      }
      .sheet(
        item: $share,
        onDismiss: {
          if let exportDirectory {
            try? FileManager.default.removeItem(at: exportDirectory)
          }
          exportDirectory = nil
        }
      ) { share in
        ShareSheet(url: share.url)
      }
      .alert("Couldn't prepare your postcard", isPresented: $shareError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("The image couldn't be saved for sharing. Free up storage and try again.")
      }
      .fullScreenCover(isPresented: $inspecting) {
        if let image {
          PostcardInspection(image: image, memory: memory)
        }
      }
    }
  }
}

struct PostcardInspection: View {
  @Environment(\.dismiss) private var dismiss
  let image: UIImage
  let memory: Memory
  @State private var zoom = 1.0
  @State private var gestureZoom = 1.0

  var body: some View {
    NavigationStack {
      GeometryReader { proxy in
        ScrollView([.horizontal, .vertical]) {
          Image(uiImage: image).resizable().scaledToFit()
            .frame(width: (proxy.size.width - 32) * zoom)
            .padding(16)
            .accessibilityLabel(
              "Greetings from \(memory.place). \(memory.date.formatted(date: .long, time: .omitted)). \(String(memory.note.prefix(220)))"
            )
            .onTapGesture(count: 2) { setZoom(zoom > 1 ? 1 : 2) }
            .simultaneousGesture(
              MagnifyGesture()
                .onChanged { value in zoom = min(3, max(1, gestureZoom * value.magnification)) }
                .onEnded { _ in gestureZoom = zoom }
            )
        }
      }
      .background(Ink.pale)
      .navigationTitle("A closer look").navigationBarTitleDisplayMode(.inline)
      .journalNavigation()
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        HStack {
          Button {
            setZoom(zoom - 0.5)
          } label: {
            Image(systemName: "minus.magnifyingglass").frame(width: 52, height: 48)
          }.disabled(zoom <= 1).accessibilityLabel("Zoom out")
          Spacer()
          Button {
            setZoom(1)
          } label: {
            Text("\(Int(zoom * 100))% · Reset").font(.subheadline).padding(12)
          }.accessibilityLabel("Reset postcard zoom")
          Spacer()
          Button {
            setZoom(zoom + 0.5)
          } label: {
            Image(systemName: "plus.magnifyingglass").frame(width: 52, height: 48)
          }.disabled(zoom >= 3).accessibilityLabel("Zoom in")
        }
        .tint(Ink.blue).padding(.horizontal, 20).background(Ink.paper)
      }
    }
  }

  private func setZoom(_ value: Double) {
    zoom = min(3, max(1, value))
    gestureZoom = zoom
  }
}

struct ShareSheet: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [url], applicationActivities: nil)
  }
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
