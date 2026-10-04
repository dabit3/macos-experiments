import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let output = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let bitmap = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
  samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
  bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.current = context
let cg = context.cgContext
cg.translateBy(x: 0, y: 1024)
cg.scaleBy(x: 1, y: -1)

func color(_ hex: UInt32) -> NSColor {
  NSColor(
    red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
    blue: CGFloat(hex & 255) / 255, alpha: 1
  )
}

func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ fill: UInt32) {
  color(fill).setFill()
  NSBezierPath(ovalIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)).fill()
}

NSGradient(colors: [color(0x8FC8EC), color(0xC9E4F2), color(0xFFE3C2)])!.draw(
  in: NSRect(x: 0, y: 0, width: 1024, height: 1024), angle: 90
)
oval(780, 230, 220, 220, 0xFFF1C9)
color(0x3F9BC7).setFill()
NSBezierPath(rect: CGRect(x: 0, y: 820, width: 1024, height: 204)).fill()
color(0xB9825A).setFill()
NSBezierPath(roundedRect: CGRect(x: 820, y: 560, width: 150, height: 300), xRadius: 18, yRadius: 18)
  .fill()
NSBezierPath(roundedRect: CGRect(x: 820, y: -20, width: 150, height: 220), xRadius: 18, yRadius: 18)
  .fill()

cg.translateBy(x: 470, y: 520)
cg.rotate(by: -0.28)
cg.scaleBy(x: 8, y: 8)
oval(-46, 6, 36, 14, 0x6B4029)
oval(-4, 0, 60, 42, 0x8C5A3C)
oval(0, 8, 40, 24, 0xF3DEC0)
oval(18, -12, 12, 11, 0x6B4029)
oval(22, -2, 40, 36, 0x8C5A3C)
oval(30, 6, 28, 18, 0xF3DEC0)
oval(16, 8, 8, 5, 0xF49A9A)
oval(24, -6, 8, 9, 0x2B1C14)
oval(37, -6, 8, 9, 0x2B1C14)
oval(25.5, -8, 3, 3, 0xFFFFFF)
oval(38.5, -8, 3, 3, 0xFFFFFF)
oval(33, 1, 11, 7, 0x2B1C14)
oval(14, 22, 11, 17, 0x6B4029)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
print("Generated Otter Flap icon.")
