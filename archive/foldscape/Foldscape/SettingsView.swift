import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var store: AtlasStore
  @Environment(\.dismiss) private var dismiss
  @AppStorage("foldscape.numbers") private var numbers = true
  @AppStorage("foldscape.haptics") private var haptics = true
  @State private var reset = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle("Number the pieces", isOn: $numbers)
          Toggle("Gentle haptics", isOn: $haptics)
        } header: {
          Text("Make yourself at home")
        } footer: {
          Text(
            "Piece numbers read left to right, top to bottom. The empty space belongs in the bottom right."
          )
        }
        Section("How to unfold") {
          Text(
            "Tap a piece beside the empty space to slide it. Arrange the picture and the ninth piece will return."
          )
          Text(
            "Preview shows the whole landscape. Hint outlines a piece on a path back to the finished picture; it may retrace your moves."
          )
          Text(
            "Gentle begins six shuffling steps from home. Wandering takes forty. Neither has a timer or a move limit."
          )
        }
        Section("Your paper atlas") {
          Text(
            "Puzzles save after every move, on this device. Completed scenes stay in your collection. No account or internet needed."
          )
          Button("Erase puzzles and collection", role: .destructive) { reset = true }
        }
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text("Foldscape").font(.system(.title2, design: .serif))
            Text("Six original paper places.\nMade for moments between things.")
              .font(.subheadline).foregroundStyle(Paper.muted)
            Text("VERSION 1.0").font(.system(.caption2, design: .monospaced))
              .foregroundStyle(Paper.muted)
          }
          .padding(.vertical, 8)
        }
      }
      .foregroundStyle(Paper.ink)
      .scrollContentBackground(.hidden).background(Paper.stock)
      .navigationTitle("A few small things")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
      .confirmationDialog("Erase your paper atlas?", isPresented: $reset, titleVisibility: .visible)
      {
        Button("Erase all progress", role: .destructive) { store.reset() }
      } message: {
        Text("This removes every saved puzzle and completion. It cannot be undone.")
      }
    }
  }
}
