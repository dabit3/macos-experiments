import AppKit
import SwiftUI

@main
struct WavecraftApp: App {
  @StateObject private var model = StudioModel()

  var body: some Scene {
    Window("Wavecraft", id: "studio") {
      StudioView(model: model)
        .preferredColorScheme(.dark)
        .frame(minWidth: 1080, minHeight: 700)
    }
    .defaultSize(width: 1380, height: 850)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("Open Audio…", action: model.importAudio).keyboardShortcut("o")
        Button("Export WAV…", action: model.exportAudio).keyboardShortcut("e")
      }
      CommandGroup(replacing: .undoRedo) {
        Button("Undo", action: model.undo).keyboardShortcut("z").disabled(model.undoStack.isEmpty)
        Button("Redo", action: model.redo).keyboardShortcut("z", modifiers: [.command, .shift])
          .disabled(model.redoStack.isEmpty)
      }
      CommandMenu("Audio") {
        Button("Play / Stop") { model.togglePlayback() }.keyboardShortcut(.space, modifiers: [])
        Button("Select Entire Waveform", action: model.selectAll)
        Button("Trim to Selection", action: model.trim).keyboardShortcut("t").disabled(
          !model.hasSelection)
      }
    }
  }
}
