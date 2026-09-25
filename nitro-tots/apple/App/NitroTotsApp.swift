import SwiftUI

@main struct NitroTotsApp: App {
  @State private var model = AppModel()
  var body: some Scene {
    WindowGroup {
      RootView(model: model)
        #if os(macOS)
          .frame(minWidth: 640, minHeight: 480)
        #endif
    }
    #if os(macOS)
      .defaultSize(width: windowSize.width, height: windowSize.height)
      .commands { CommandGroup(replacing: .newItem) {} }
    #endif
  }
  private var windowSize: CGSize {
    let parts = (model.launch["WINDOW"] ?? "1120x760").split(separator: "x")
    guard parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]),
      width.isFinite, height.isFinite
    else { return CGSize(width: 1120, height: 760) }
    return CGSize(width: max(640, width), height: max(480, height))
  }
}
