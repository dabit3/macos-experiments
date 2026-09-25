import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let files = FileManager.default
let source = URL(fileURLWithPath: "scripts/Artwork", isDirectory: true)
let catalog = URL(fileURLWithPath: "Assets.xcassets", isDirectory: true)

func load(_ name: String) -> CGImage {
  let url = source.appendingPathComponent(name + ".png")
  guard let input = CGImageSourceCreateWithURL(url as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(input, 0, nil)
  else { fatalError("Cannot read \(url.path)") }
  return image
}

func save(_ image: CGImage, named name: String) throws {
  let directory = catalog.appendingPathComponent(name + ".imageset", isDirectory: true)
  try files.createDirectory(at: directory, withIntermediateDirectories: true)
  let url = directory.appendingPathComponent(name + ".png")
  guard
    let destination = CGImageDestinationCreateWithURL(
      url as CFURL, UTType.png.identifier as CFString, 1, nil)
  else { fatalError("Cannot write \(name)") }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else { fatalError("Cannot encode \(name)") }
  let contents = """
    {"images":[{"filename":"\(name).png","idiom":"universal"}],"info":{"author":"xcode","version":1}}
    """
  try contents.write(
    to: directory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

func isolate(_ image: CGImage, crop: CGRect) -> CGImage {
  guard let cell = image.cropping(to: crop),
    let context = CGContext(
      data: nil, width: cell.width, height: cell.height, bitsPerComponent: 8,
      bytesPerRow: cell.width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
    let data = context.data
  else { fatalError("Cannot prepare sprite") }
  context.draw(cell, in: CGRect(x: 0, y: 0, width: cell.width, height: cell.height))
  let pixels = data.bindMemory(to: UInt8.self, capacity: cell.width * cell.height * 4)
  var minX = cell.width
  var minY = cell.height
  var maxX = 0
  var maxY = 0
  for y in 0..<cell.height {
    for x in 0..<cell.width {
      let i = (y * cell.width + x) * 4
      let red = Int(pixels[i])
      let green = Int(pixels[i + 1])
      let blue = Int(pixels[i + 2])
      if min(red, blue) - green > 32 {
        for channel in 0..<4 { pixels[i + channel] = 0 }
      } else {
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
      }
    }
  }
  guard let keyed = context.makeImage(),
    let trimmed = keyed.cropping(
      to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
  else { fatalError("Empty sprite") }
  return trimmed
}

try save(load("HarborCover"), named: "HarborCover")
try save(load("HarborBackdrop"), named: "HarborBackdrop")
let atlas = load("SalvageAtlas")
let sprites: [(String, CGRect)] = [
  ("CargoPiano", CGRect(x: 0, y: 0, width: 512, height: 512)),
  ("CargoClock", CGRect(x: 512, y: 0, width: 512, height: 512)),
  ("CargoTrunk", CGRect(x: 1024, y: 0, width: 512, height: 512)),
  ("CargoPlant", CGRect(x: 0, y: 512, width: 512, height: 512)),
  ("CargoTelescope", CGRect(x: 512, y: 512, width: 455, height: 512)),
  ("Airship", CGRect(x: 968, y: 512, width: 568, height: 512)),
]
for (name, crop) in sprites { try save(isolate(atlas, crop: crop), named: name) }
print("Prepared harbor backgrounds and six transparent salvage sprites.")
