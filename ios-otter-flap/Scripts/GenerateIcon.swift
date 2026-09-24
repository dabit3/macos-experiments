import AppKit

// App icon: an otter head peeking between two driftwood logs over a river at golden hour.
let side = 1024
let s = CGFloat(side)
let c = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: 1)
}

func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: CGColor) {
    c.setFillColor(color)
    c.fillEllipse(in: CGRect(x: x, y: s - y - h, width: w, height: h))
}

let fur = rgb(0.55, 0.34, 0.19), furDark = rgb(0.36, 0.21, 0.11), outline = rgb(0.2, 0.11, 0.06)
let cream = rgb(0.96, 0.86, 0.7), bark = rgb(0.5, 0.33, 0.2), barkLight = rgb(0.66, 0.46, 0.28)

let sky = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [rgb(0.36, 0.68, 0.96), rgb(0.99, 0.88, 0.72)] as CFArray, locations: nil)!
c.drawLinearGradient(sky, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])
oval(620, 130, 190, 190, rgb(1, 0.93, 0.62))
c.setFillColor(rgb(0.17, 0.55, 0.72))
c.fill(CGRect(x: 0, y: 0, width: s, height: 190))
c.setFillColor(rgb(0.47, 0.74, 0.3))
c.fill(CGRect(x: 0, y: 190, width: s, height: 40))

for (x, top, bottom) in [(CGFloat(40), CGFloat(0), CGFloat(300)), (CGFloat(804), CGFloat(560), CGFloat(1024))] {
    c.setFillColor(bark)
    c.fill(CGRect(x: x, y: s - bottom, width: 180, height: bottom - top))
    c.setFillColor(barkLight)
    c.fill(CGRect(x: x + 60, y: s - bottom, width: 40, height: bottom - top))
}

oval(250, 250, 520, 480, fur)
oval(270, 230, 110, 100, furDark)
oval(640, 230, 110, 100, furDark)
oval(250, 250, 520, 480, fur)
oval(330, 470, 360, 260, cream)
oval(380, 400, 70, 80, outline)
oval(570, 400, 70, 80, outline)
oval(400, 410, 24, 24, rgb(1, 1, 1))
oval(590, 410, 24, 24, rgb(1, 1, 1))
oval(450, 505, 120, 80, outline)
oval(310, 520, 80, 50, CGColor(red: 0.98, green: 0.55, blue: 0.5, alpha: 0.6))
oval(630, 520, 80, 50, CGColor(red: 0.98, green: 0.55, blue: 0.5, alpha: 0.6))
c.setStrokeColor(outline)
c.setLineWidth(10)
c.setLineCap(.round)
c.move(to: CGPoint(x: 510, y: s - 585))
c.addLine(to: CGPoint(x: 510, y: s - 625))
c.strokePath()
for dy in [CGFloat(-20), 10, 40] {
    c.setLineWidth(5)
    c.move(to: CGPoint(x: 420, y: s - 560 - dy * 0.3))
    c.addLine(to: CGPoint(x: 260, y: s - 560 - dy))
    c.move(to: CGPoint(x: 600, y: s - 560 - dy * 0.3))
    c.addLine(to: CGPoint(x: 760, y: s - 560 - dy))
    c.strokePath()
}

let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
let image = c.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
