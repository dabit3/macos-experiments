import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
NSColor(calibratedRed: 0.043, green: 0.043, blue: 0.043, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()

NSColor(calibratedRed: 0.463, green: 0.725, blue: 0, alpha: 0.22).setStroke()
for index in 0..<9 {
  let path = NSBezierPath()
  path.lineWidth = 3
  let y = CGFloat(80 + index * 108)
  path.move(to: NSPoint(x: 30, y: y))
  path.line(to: NSPoint(x: 230, y: y))
  path.line(to: NSPoint(x: 290, y: y + 42))
  path.line(to: NSPoint(x: 980, y: y + 42))
  path.stroke()
}

let green = NSColor(calibratedRed: 0.463, green: 0.725, blue: 0, alpha: 1)
let origin: CGFloat = 190
let cell: CGFloat = 128
let gap: CGFloat = 16
for row in 0..<5 {
  for column in 0..<5 {
    let rect = NSRect(
      x: origin + CGFloat(column) * (cell + gap),
      y: origin + CGFloat(4 - row) * (cell + gap),
      width: cell,
      height: cell
    )
    let square = NSBezierPath(roundedRect: rect, xRadius: 20, yRadius: 20)
    if row == column {
      green.withAlphaComponent(0.9).setFill()
      NSShadow().also {
        $0.shadowColor = green.withAlphaComponent(0.8)
        $0.shadowBlurRadius = 24
        $0.shadowOffset = .zero
        $0.set()
      }
      square.fill()
      NSShadow().set()
    } else {
      NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
      square.fill()
      green.withAlphaComponent(0.28).setStroke()
      square.lineWidth = 4
      square.stroke()
    }
  }
}
image.unlockFocus()

let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  .appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Unable to render icon") }
try png.write(to: output)

extension NSObject {
  @discardableResult
  func also(_ body: (Self) -> Void) -> Self {
    body(self)
    return self
  }
}
