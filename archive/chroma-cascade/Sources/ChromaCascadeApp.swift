import SwiftUI

@main
struct ChromaCascadeApp: App {
  @StateObject private var store = CollectionStore()

  var body: some Scene {
    WindowGroup {
      HomeView()
        .environmentObject(store)
        .tint(Gallery.ink)
        .preferredColorScheme(.light)
    }
  }
}

struct HomeView: View {
  @EnvironmentObject private var store: CollectionStore
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var path: [Int] = []
  @State private var chapters = false
  @State private var settings = false

  var body: some View {
    NavigationStack(path: $path) {
      ZStack {
        GalleryBackground()
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            HStack {
              Eyebrow(text: "An exercise in harmony")
              Spacer()
              CircleControl(icon: "slider.horizontal.3", label: "Settings") { settings = true }
            }
            .padding(.top, 12)
            Text("Chroma\nCascade")
              .font(.system(size: 59, weight: .regular, design: .serif))
              .tracking(-2.5)
              .lineSpacing(-6)
              .padding(.top, 26)
              .accessibilityAddTraits(.isHeader)
            Text("A little order. A little wonder.")
              .font(.system(.subheadline))
              .foregroundStyle(Gallery.muted)
              .padding(.top, 15)
            GallerySculpture().padding(.top, 8)
            (typeSize.isAccessibilitySize
              ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
              : AnyLayout(HStackLayout())) {
                Eyebrow(text: "The collection")
                if !typeSize.isAccessibilitySize { Spacer() }
                Text("\(store.saved.bestMoves.count) of 12 studies")
                  .font(.system(.caption, design: .monospaced))
                  .foregroundStyle(Gallery.muted)
              }
            ProgressView(value: Double(store.saved.bestMoves.count), total: 12)
              .tint(Gallery.accent)
              .padding(.top, 12)
              .padding(.bottom, 25)
            PrimaryButton(
              title: store.saved.puzzles.isEmpty ? "Begin with color" : "Return to your study"
            ) { open(store.saved.currentLevel) }
            Button {
              chapters = true
            } label: {
              HStack {
                Text("Explore the chapters")
                Image(systemName: "square.grid.2x2")
              }
              .font(.subheadline)
              .frame(maxWidth: .infinity, minHeight: 58)
            }
            .buttonStyle(.plain)
            Eyebrow(text: "No clock. No rush. Just color.")
              .frame(maxWidth: .infinity)
              .padding(.bottom, 26)
          }
          .padding(.horizontal, 28)
        }
        .scrollIndicators(.hidden)
      }
      .foregroundStyle(Gallery.ink)
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: Int.self) { id in
        GameView(id: id) { next in path = [next] }
          .id(id)
      }
      .sheet(isPresented: $chapters) {
        ChaptersView { id in
          chapters = false
          open(id)
        }
      }
      .sheet(isPresented: $settings) { SettingsView() }
    }
  }

  private func open(_ id: Int) {
    store.open(id)
    path = [id]
  }
}

struct ChaptersView: View {
  @EnvironmentObject private var store: CollectionStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize
  let choose: (Int) -> Void

  var body: some View {
    ZStack {
      GalleryBackground()
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          HStack {
            Eyebrow(text: "The collection / 12 studies")
            Spacer()
            CircleControl(icon: "xmark", label: "Close chapters") { dismiss() }
          }
          Text("Find your\nflow.")
            .font(.system(.largeTitle, design: .serif))
            .tracking(-1.5)
            .accessibilityAddTraits(.isHeader)
          Text("Every study is open. Follow your curiosity.")
            .font(.subheadline)
            .foregroundStyle(Gallery.muted)
          ForEach(0..<3) { chapter in
            VStack(alignment: .leading, spacing: 16) {
              HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(String(format: "%02d", chapter + 1))
                  .font(.system(.largeTitle, design: .serif))
                  .foregroundStyle(Gallery.accent)
                VStack(alignment: .leading, spacing: 5) {
                  Text(Study.chapterNames[chapter]).font(.title3.weight(.medium))
                  Text(Study.chapterNotes[chapter])
                    .font(.caption)
                    .foregroundStyle(Gallery.muted)
                }
              }
              LazyVGrid(
                columns: Array(
                  repeating: GridItem(.flexible(), spacing: 12),
                  count: typeSize.isAccessibilitySize ? 2 : 4),
                spacing: 12
              ) {
                ForEach((chapter * 4)..<(chapter * 4 + 4), id: \.self) { id in
                  Button {
                    choose(id)
                  } label: {
                    VStack(spacing: 9) {
                      Text(Study.all[id].number)
                        .font(.system(.title2, design: .serif))
                      Image(
                        systemName: store.saved.bestMoves[id] == nil
                          ? "circle" : "checkmark.circle.fill"
                      )
                      .font(.system(size: 12))
                      .foregroundStyle(
                        store.saved.bestMoves[id] == nil ? Gallery.line : Gallery.accent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .padding(.vertical, typeSize.isAccessibilitySize ? 16 : 0)
                    .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 15))
                    .overlay(
                      RoundedRectangle(cornerRadius: 15).strokeBorder(Gallery.line.opacity(0.7)))
                  }
                  .buttonStyle(.plain)
                  .accessibilityLabel(
                    "Study \(id + 1), \(Study.names[id]), \(store.saved.bestMoves[id] == nil ? "not yet completed" : "completed")"
                  )
                }
              }
              Rectangle().fill(Gallery.line).frame(height: 1).padding(.top, 8)
            }
          }
        }
        .padding(26)
      }
    }
    .foregroundStyle(Gallery.ink)
  }
}

struct SettingsView: View {
  @EnvironmentObject private var store: CollectionStore
  @Environment(\.dismiss) private var dismiss
  @State private var reset = false

  var body: some View {
    ZStack {
      GalleryBackground()
      ScrollView {
        VStack(alignment: .leading, spacing: 27) {
          HStack {
            Eyebrow(text: "Make yourself at home")
            Spacer()
            CircleControl(icon: "xmark", label: "Close settings") { dismiss() }
          }
          Text("Your studio")
            .font(.system(.largeTitle, design: .serif))
            .accessibilityAddTraits(.isHeader)
          VStack(alignment: .leading, spacing: 20) {
            Toggle(
              "Color symbols",
              isOn: Binding(get: { store.saved.symbols }, set: { store.setSymbols($0) }))
            Text("Identify every pigment by shape as well as color.")
              .font(.subheadline)
              .foregroundStyle(Gallery.muted)
            Divider()
            Toggle(
              "Gentle haptics",
              isOn: Binding(get: { store.saved.haptics }, set: { store.setHaptics($0) }))
          }
          .tint(Gallery.accent)
          .padding(23)
          .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
          Eyebrow(text: "Pigment index")
          ForEach(0..<5) { color in
            HStack(spacing: 16) {
              Image(systemName: Gallery.symbols[color])
                .font(.system(size: 22))
                .foregroundStyle(Gallery.colors[color])
                .frame(width: 24)
              Text(Gallery.names[color]).font(.body)
              Spacer()
              Text(String(format: "%02d", color + 1))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Gallery.muted)
            }
          }
          Divider()
          Text("Made for a slower moment.")
            .font(.title3).fontDesign(.serif)
          Text(
            "12 solvable studies. Unlimited undo. Your progress stays on this device, automatically. No accounts or clocks."
          )
          .font(.subheadline)
          .foregroundStyle(Gallery.muted)
          Button("Reset all progress", role: .destructive) { reset = true }
            .font(.subheadline)
            .frame(minHeight: 44)
        }
        .padding(26)
      }
    }
    .foregroundStyle(Gallery.ink)
    .alert("Clear your collection?", isPresented: $reset) {
      Button("Reset all progress", role: .destructive) { store.resetCollection() }
      Button("Keep my progress", role: .cancel) {}
    } message: {
      Text("This removes all saved puzzles and personal bests. Your studio preferences will stay.")
    }
  }
}
