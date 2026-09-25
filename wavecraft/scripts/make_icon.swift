import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let pixels = size * scale
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()
    let factor = CGFloat(pixels) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: factor)
    transform.concat()
    let rect = NSRect(x: 40, y: 40, width: 944, height: 944)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
    NSColor(calibratedRed: 0.075, green: 0.087, blue: 0.09, alpha: 1).setFill()
    shape.fill()
    NSColor(white: 0.35, alpha: 0.4).setStroke()
    shape.lineWidth = 3
    shape.stroke()
    let heights: [CGFloat] = [95, 220, 370, 520, 290, 450, 610, 340, 190, 100]
    for (index, height) in heights.enumerated() {
      let bar = NSBezierPath(
        roundedRect: NSRect(
          x: 180 + CGFloat(index) * 70, y: (1024 - height) / 2, width: 31, height: height),
        xRadius: 15, yRadius: 15)
      NSColor(
        calibratedRed: index >= 8 ? 0.96 : 0.53,
        green: index >= 8 ? 0.55 : 0.89,
        blue: index >= 8 ? 0.43 : 0.74, alpha: 1
      ).setFill()
      bar.fill()
    }
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
    else { fatalError("Unable to render app icon") }
    let suffix = scale == 2 ? "@2x" : ""
    try png.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
  }
}
