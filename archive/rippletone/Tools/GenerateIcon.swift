import AppKit
import SwiftUI

@main
struct GenerateIcon {
  @MainActor static func main() throws {
    _ = NSApplication.shared
    let destination =
      CommandLine.arguments.dropFirst().first
      ?? "Rippletone/Assets.xcassets/AppIcon.appiconset/Icon.png"
    let renderer = ImageRenderer(
      content: PondArt(hero: true, reducedMotion: true).frame(width: 1024, height: 1024))
    renderer.scale = 1
    renderer.isOpaque = true
    guard let image = renderer.cgImage else {
      throw CocoaError(.coderInvalidValue)
    }
    let context = CGContext(
      data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(
      to: URL(fileURLWithPath: destination))
  }
}
