import AppKit
import SwiftUI

@main
struct IconGenerator {
  @MainActor static func main() {
    guard
      let portrait = NSImage(
        contentsOfFile: "Assets.xcassets/RaccoonPortrait.imageset/raccoon.png"),
      let scene = NSImage(contentsOfFile: "Assets.xcassets/TowerScene.imageset/tower.jpg")
    else { fatalError("Run from the Rooftop Raccoon project directory") }
    let image = ImageRenderer(
      content: ZStack {
        Image(nsImage: scene).resizable().scaledToFill()
          .frame(width: 1024, height: 1024).clipped()
        LinearGradient(
          colors: [Palette.ink.opacity(0.2), Palette.ink], startPoint: .top, endPoint: .bottom)
        Image(nsImage: portrait).resizable().scaledToFit()
          .frame(width: 1300, height: 1300).offset(x: -80, y: 140)
      }
      .frame(width: 1024, height: 1024).clipped())
    image.scale = 1
    guard let cgImage = image.cgImage,
      let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    else { fatalError("Could not render icon") }
    do {
      try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    } catch {
      fatalError("Could not write icon: \(error)")
    }
  }
}
