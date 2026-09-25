import CryptoKit
import Foundation
import ImageIO

guard CommandLine.arguments.count == 4,
  let expectedFrames = Int(CommandLine.arguments[2]),
  let expectedFPS = Double(CommandLine.arguments[3]),
  let source = CGImageSourceCreateWithURL(
    URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil)
else { fatalError("Usage: swift Scripts/verify-gif.swift <GIF> <frame-count> <fps>") }

let count = CGImageSourceGetCount(source)
precondition(count == expectedFrames, "Unexpected frame count")
let properties = CGImageSourceCopyProperties(source, nil) as NSDictionary?
let gif = properties?[kCGImagePropertyGIFDictionary as String] as? NSDictionary
precondition(gif?[kCGImagePropertyGIFLoopCount as String] as? Int == 0, "Expected infinite loop")
var hashes = Set<String>()
for index in 0..<count {
  guard let image = CGImageSourceCreateImageAtIndex(source, index, nil),
    let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as NSDictionary?,
    let gif = properties[kCGImagePropertyGIFDictionary as String] as? NSDictionary,
    let delay = gif[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
  else { fatalError("Could not decode frame \(index)") }
  precondition(image.width == 800 && image.height == 520, "Unexpected dimensions")
  precondition(abs(delay - 1 / expectedFPS) < 0.011, "Unexpected delay")
  let context = CGContext(
    data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
    bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
  let data = Data(bytes: context.data!, count: image.width * image.height * 4)
  let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  hashes.insert(hash)
  print("Frame \(index + 1): 800x520 delay=\(delay)s sha256=\(hash)")
}
precondition(hashes.count > 1, "The GIF must contain visibly different frames")
print(
  "PASS: \(count) frames, \(hashes.count) distinct RGBA images, infinite loop, \(expectedFPS) fps")
