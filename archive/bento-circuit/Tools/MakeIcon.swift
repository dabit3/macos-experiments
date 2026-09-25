import AppKit

let destination =
  CommandLine.arguments.dropFirst().first ?? "Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
  NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
}
func rect(_ box: NSRect, radius: CGFloat, fill: NSColor) {
  fill.setFill()
  NSBezierPath(roundedRect: box, xRadius: radius, yRadius: radius).fill()
}
func food(_ name: String, x: CGFloat, y: CGFloat, size: CGFloat) {
  guard
    let ingredient = NSImage(
      contentsOfFile: "Assets.xcassets/Food-\(name).imageset/Food-\(name).png")
  else {
    fatalError("Missing food illustration: \(name)")
  }
  ingredient.draw(in: NSRect(x: x, y: y, width: size, height: size))
}
let paper = color(0.96, 0.94, 0.88)
let ink = color(0.12, 0.21, 0.18)
ink.setFill()
NSRect(origin: .zero, size: size).fill()
let outer = NSBezierPath(
  roundedRect: NSRect(x: 51, y: 51, width: 922, height: 922), xRadius: 170, yRadius: 170)
color(0.70, 0.53, 0.27).setStroke()
outer.lineWidth = 3
outer.stroke()
rect(NSRect(x: 120, y: 166, width: 784, height: 717), radius: 77, fill: color(0.07, 0.12, 0.10))
rect(NSRect(x: 127, y: 183, width: 770, height: 705), radius: 73, fill: color(0.78, 0.59, 0.37))
rect(NSRect(x: 146, y: 202, width: 732, height: 667), radius: 57, fill: color(0.44, 0.31, 0.20))
rect(NSRect(x: 160, y: 216, width: 450, height: 639), radius: 42, fill: color(0.66, 0.73, 0.57))
rect(NSRect(x: 626, y: 216, width: 239, height: 639), radius: 42, fill: color(0.89, 0.78, 0.54))
food("shiso", x: 159, y: 500, size: 380)
food("salmon", x: 155, y: 532, size: 260)
food("salmon", x: 369, y: 532, size: 260)
food("tamago", x: 151, y: 313, size: 257)
food("onigiri", x: 355, y: 294, size: 280)
food("citrus", x: 620, y: 573, size: 248)
food("strawberry", x: 620, y: 326, size: 248)
rect(NSRect(x: 187, y: 258, width: 650, height: 19), radius: 3, fill: color(0.73, 0.23, 0.12))
let caption: [NSAttributedString.Key: NSObject] = [
  .font: NSFont.systemFont(ofSize: 28, weight: .medium),
  .foregroundColor: paper,
  .kern: NSNumber(value: 7),
]
NSAttributedString(string: "B E N T O", attributes: caption)
  .draw(at: NSPoint(x: 373, y: 105))
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Could not render icon") }
try png.write(to: URL(fileURLWithPath: destination))
print("Wrote \(destination)")
