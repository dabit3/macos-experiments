import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let source = URL(fileURLWithPath: "scripts/Artwork/HarborCover.png")
let output = URL(fileURLWithPath: "Assets.xcassets/AppIcon.appiconset/AppIcon.png")
guard let input = CGImageSourceCreateWithURL(source as CFURL, nil),
  let artwork = CGImageSourceCreateImageAtIndex(input, 0, nil),
  let context = CGContext(
    data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
  let destination = CGImageDestinationCreateWithURL(
    output as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("Cannot prepare app icon") }
context.draw(artwork, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
guard let icon = context.makeImage() else { fatalError("Cannot render app icon") }
CGImageDestinationAddImage(destination, icon, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Cannot encode app icon") }
