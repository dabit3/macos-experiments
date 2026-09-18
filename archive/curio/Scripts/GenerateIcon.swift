import AppKit
import Foundation

let destination = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(red: 0.96, green: 0.95, blue: 0.91, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let blue = NSColor(red: 0.12, green: 0.24, blue: 0.89, alpha: 1)
blue.setFill()
let path = NSBezierPath()
path.move(to: NSPoint(x: 427, y: 785))
path.curve(
  to: NSPoint(x: 285, y: 438), controlPoint1: NSPoint(x: 470, y: 620),
  controlPoint2: NSPoint(x: 251, y: 615))
path.curve(
  to: NSPoint(x: 365, y: 267), controlPoint1: NSPoint(x: 287, y: 324),
  controlPoint2: NSPoint(x: 314, y: 267))
path.line(to: NSPoint(x: 659, y: 267))
path.curve(
  to: NSPoint(x: 739, y: 438), controlPoint1: NSPoint(x: 710, y: 267),
  controlPoint2: NSPoint(x: 737, y: 324))
path.curve(
  to: NSPoint(x: 597, y: 785), controlPoint1: NSPoint(x: 773, y: 615),
  controlPoint2: NSPoint(x: 554, y: 620))
path.close()
path.fill()
NSColor(red: 0.05, green: 0.13, blue: 0.55, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 427, y: 766, width: 170, height: 35)).fill()
blue.setFill()
NSBezierPath(rect: NSRect(x: 249, y: 180, width: 526, height: 20)).fill()
NSBezierPath(rect: NSRect(x: 286, y: 129, width: 452, height: 10)).fill()
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Could not render icon") }
try png.write(to: URL(fileURLWithPath: destination))
