import LinkPresentation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SharedLandscape: Identifiable {
  let id = UUID()
  let image: UIImage
  let title: String
  let fileURL: URL

  init(image: UIImage, title: String) throws {
    self.image = image
    self.title = title
    fileURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Tiny Tectonics - \(title).png")
    guard let data = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
    try data.write(to: fileURL, options: .atomic)
  }
}

final class LandscapeActivityItem: NSObject, UIActivityItemSource {
  let landscape: SharedLandscape

  init(landscape: SharedLandscape) { self.landscape = landscape }

  func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController)
    -> Any
  {
    landscape.fileURL
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    landscape.fileURL
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
  ) -> String {
    UTType.png.identifier
  }

  func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController)
    -> LPLinkMetadata?
  {
    let metadata = LPLinkMetadata()
    metadata.title = "\(landscape.title) · Tiny Tectonics"
    metadata.imageProvider = NSItemProvider(object: landscape.image)
    metadata.iconProvider = NSItemProvider(object: landscape.image)
    return metadata
  }
}

struct NativeShare: UIViewControllerRepresentable {
  let landscape: SharedLandscape

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(
      activityItems: [LandscapeActivityItem(landscape: landscape)], applicationActivities: nil)
  }

  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct LandscapeCard: View {
  let level: Landscape
  let heights: [Int]
  let moves: Int
  let stars: Int

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        ContourEmblem().frame(width: 38, height: 38)
        Text("TINY TECTONICS").padding(.leading, 8)
        Spacer()
        Text(String(format: "NO. %02d", level.id + 1))
      }
      .font(.system(size: 11, weight: .medium, design: .monospaced))
      .tracking(2)
      .foregroundStyle(Earth.brass)
      Rectangle().fill(Earth.brass.opacity(0.35)).frame(height: 1).padding(.top, 20)
      Diorama(
        level: level, heights: heights, travel: Double(heights.count - 1), running: true,
        celebration: true, presentation: true
      )
      .frame(height: 365)
      Text(level.region)
        .font(.system(size: 10, design: .monospaced)).tracking(3)
        .foregroundStyle(Earth.brass).padding(.bottom, 10)
      Text(level.name).font(.custom("Georgia", size: 40))
      Text("A landscape, beautifully balanced.")
        .font(.custom("Georgia-Italic", size: 16))
        .foregroundStyle(Earth.muted)
        .padding(.top, 8)
      Rectangle().fill(Earth.brass.opacity(0.3)).frame(height: 1).padding(.vertical, 25)
      HStack {
        Text("\(moves) \(moves == 1 ? "SHIFT" : "SHIFTS")")
        Spacer()
        Text("\(level.fossils.count) AMBER")
        Spacer()
        Text("\(stars) / 3 STARS")
      }
      .font(.system(size: 11, weight: .medium, design: .monospaced))
      .tracking(2)
      .foregroundStyle(Earth.brass)
    }
    .padding(38)
    .frame(width: 600, height: 720)
    .foregroundStyle(Earth.paper)
    .background(GalleryBackground())
    .overlay(Rectangle().strokeBorder(Earth.brass.opacity(0.3), lineWidth: 1).padding(14))
  }
}
