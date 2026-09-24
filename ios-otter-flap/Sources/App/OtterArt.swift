import SpriteKit
import UIKit

enum Palette {
    static let fur = UIColor(red: 0.55, green: 0.34, blue: 0.19, alpha: 1)
    static let furDark = UIColor(red: 0.36, green: 0.21, blue: 0.11, alpha: 1)
    static let outline = UIColor(red: 0.2, green: 0.11, blue: 0.06, alpha: 1)
    static let cream = UIColor(red: 0.96, green: 0.86, blue: 0.7, alpha: 1)
    static let blush = UIColor(red: 0.98, green: 0.55, blue: 0.5, alpha: 0.55)
    static let skyTop = UIColor(red: 0.36, green: 0.68, blue: 0.96, alpha: 1)
    static let skyBottom = UIColor(red: 0.99, green: 0.88, blue: 0.72, alpha: 1)
    static let mountain = UIColor(red: 0.48, green: 0.55, blue: 0.78, alpha: 1)
    static let mountainSnow = UIColor(red: 0.9, green: 0.93, blue: 1, alpha: 1)
    static let pine = UIColor(red: 0.16, green: 0.45, blue: 0.36, alpha: 1)
    static let pineDark = UIColor(red: 0.1, green: 0.33, blue: 0.28, alpha: 1)
    static let grass = UIColor(red: 0.47, green: 0.74, blue: 0.3, alpha: 1)
    static let grassDark = UIColor(red: 0.3, green: 0.56, blue: 0.2, alpha: 1)
    static let water = UIColor(red: 0.17, green: 0.55, blue: 0.72, alpha: 1)
    static let waterDeep = UIColor(red: 0.1, green: 0.38, blue: 0.58, alpha: 1)
    static let bark = UIColor(red: 0.5, green: 0.33, blue: 0.2, alpha: 1)
    static let barkDark = UIColor(red: 0.33, green: 0.2, blue: 0.12, alpha: 1)
    static let barkLight = UIColor(red: 0.66, green: 0.46, blue: 0.28, alpha: 1)
    static let grain = UIColor(red: 0.93, green: 0.77, blue: 0.52, alpha: 1)
    static let moss = UIColor(red: 0.45, green: 0.66, blue: 0.26, alpha: 1)
}

/// Procedurally drawn vector sprites; nothing is loaded from disk.
@MainActor
enum OtterArt {
    static let otterSize = CGSize(width: 66, height: 50)
    static let otterFrames = [0, 1, 2].map { texture(drawOtter(pose: $0)) }
    static let logWidth: CGFloat = 76
    static let logBody = texture(drawLogBody())
    static let logCap = texture(drawLogCap())
    static let cloud = texture(drawCloud())

    static func texture(_ image: UIImage) -> SKTexture {
        SKTexture(image: image)
    }

    static func render(_ size: CGSize, _ draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(size: size, format: format).image { draw($0.cgContext) }
    }

    /// Side-on otter facing right. Pose 0 = paws up, 1 = mid, 2 = paws down.
    static func drawOtter(pose: Int) -> UIImage {
        render(otterSize) { c in
            c.setLineJoin(.round)
            c.setLineCap(.round)
            let paw = [CGFloat(-6), 0, 6][pose]

            // Tail
            let tail = UIBezierPath()
            tail.move(to: CGPoint(x: 18, y: 24))
            tail.addCurve(to: CGPoint(x: 2, y: 30 + paw * 0.4), controlPoint1: CGPoint(x: 10, y: 24), controlPoint2: CGPoint(x: 5, y: 25))
            tail.addCurve(to: CGPoint(x: 18, y: 36), controlPoint1: CGPoint(x: 6, y: 36), controlPoint2: CGPoint(x: 12, y: 37))
            tail.close()
            fill(c, tail, Palette.furDark)

            // Back foot
            fill(c, UIBezierPath(ovalIn: CGRect(x: 14, y: 33 - paw * 0.5, width: 11, height: 7)), Palette.furDark)

            // Body
            let body = UIBezierPath(ovalIn: CGRect(x: 12, y: 15, width: 36, height: 24))
            fill(c, body, Palette.fur)
            fill(c, UIBezierPath(ovalIn: CGRect(x: 22, y: 27, width: 24, height: 11)), Palette.cream)

            // Ears
            for ear in [CGPoint(x: 41, y: 8), CGPoint(x: 50, y: 7)] {
                fill(c, UIBezierPath(ovalIn: CGRect(x: ear.x - 3.5, y: ear.y - 3, width: 7, height: 6)), Palette.furDark)
            }

            // Head
            fill(c, UIBezierPath(ovalIn: CGRect(x: 34, y: 6, width: 25, height: 23)), Palette.fur)
            fill(c, UIBezierPath(ovalIn: CGRect(x: 45, y: 16, width: 18, height: 13)), Palette.cream)
            fill(c, UIBezierPath(ovalIn: CGRect(x: 42, y: 19, width: 6, height: 4)), Palette.blush)

            // Eye
            fill(c, UIBezierPath(ovalIn: CGRect(x: 47.5, y: 12, width: 5, height: 5.5)), Palette.outline)
            fill(c, UIBezierPath(ovalIn: CGRect(x: 49.5, y: 12.8, width: 1.8, height: 1.8)), .white)

            // Nose and mouth
            fill(c, UIBezierPath(ovalIn: CGRect(x: 58.5, y: 16.5, width: 6, height: 4.5)), Palette.outline)
            let mouth = UIBezierPath()
            mouth.move(to: CGPoint(x: 61, y: 21))
            mouth.addQuadCurve(to: CGPoint(x: 56, y: 24), controlPoint: CGPoint(x: 60, y: 24.5))
            stroke(c, mouth, Palette.outline, 1.1)

            // Whiskers
            c.setAlpha(0.75)
            for (dy, end) in [(CGFloat(-1), CGFloat(-3)), (1, 1), (3, 5)] {
                let whisker = UIBezierPath()
                whisker.move(to: CGPoint(x: 56, y: 21 + dy))
                whisker.addLine(to: CGPoint(x: 65, y: 21 + end))
                stroke(c, whisker, Palette.outline, 0.6)
            }
            c.setAlpha(1)

            // Front paw
            let front = UIBezierPath(ovalIn: CGRect(x: 36, y: 30 + paw, width: 8, height: 10))
            fill(c, front, Palette.furDark)
        }
    }

    static func drawLogBody() -> UIImage {
        let size = CGSize(width: logWidth, height: 1000)
        return render(size) { c in
            gradient(c, CGRect(origin: .zero, size: size), [Palette.barkDark, Palette.bark, Palette.barkLight, Palette.bark, Palette.barkDark], horizontal: true)
            var seed: UInt64 = 11
            func next() -> CGFloat {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
            }
            c.setAlpha(0.5)
            for _ in 0 ..< 70 {
                let x = 6 + next() * (logWidth - 12)
                let y = next() * 1000
                let line = UIBezierPath()
                line.move(to: CGPoint(x: x, y: y))
                line.addCurve(to: CGPoint(x: x + (next() - 0.5) * 4, y: y + 40 + next() * 70), controlPoint1: CGPoint(x: x + 3, y: y + 20), controlPoint2: CGPoint(x: x - 3, y: y + 40))
                stroke(c, line, next() > 0.4 ? Palette.barkDark : Palette.barkLight, 1.4)
            }
            for _ in 0 ..< 10 {
                let knot = CGRect(x: 10 + next() * (logWidth - 30), y: next() * 1000, width: 9, height: 14)
                fill(c, UIBezierPath(ovalIn: knot), Palette.barkDark)
                stroke(c, UIBezierPath(ovalIn: knot.insetBy(dx: -2, dy: -3)), Palette.barkDark, 1)
            }
            c.setAlpha(1)
        }
    }

    /// End band drawn at the mouth of each gap: a sawn ring with moss on top.
    static func drawLogCap() -> UIImage {
        let size = CGSize(width: logWidth + 12, height: 30)
        return render(size) { c in
            let band = UIBezierPath(roundedRect: CGRect(x: 1, y: 6, width: size.width - 2, height: 23), cornerRadius: 6)
            c.saveGState()
            band.addClip()
            gradient(c, CGRect(origin: .zero, size: size), [Palette.barkDark, Palette.barkLight, Palette.grain, Palette.barkLight, Palette.barkDark], horizontal: true)
            c.restoreGState()
            stroke(c, band, Palette.outline.withAlphaComponent(0.55), 1.5)
            for inset in [CGFloat(10), 22, 32] {
                let ring = UIBezierPath()
                ring.move(to: CGPoint(x: inset, y: 18))
                ring.addLine(to: CGPoint(x: size.width - inset, y: 18))
                stroke(c, ring, Palette.barkDark.withAlphaComponent(0.35), 1)
            }
            let moss = UIBezierPath()
            moss.move(to: CGPoint(x: 2, y: 9))
            var x: CGFloat = 2
            while x < size.width - 2 {
                moss.addQuadCurve(to: CGPoint(x: x + 8, y: 9), controlPoint: CGPoint(x: x + 4, y: 1 + CGFloat(Int(x) % 3)))
                x += 8
            }
            moss.addLine(to: CGPoint(x: size.width - 2, y: 12))
            moss.addLine(to: CGPoint(x: 2, y: 12))
            moss.close()
            fill(c, moss, Palette.moss)
        }
    }

    static func drawCloud() -> UIImage {
        render(CGSize(width: 120, height: 50)) { c in
            let puffs = [CGRect(x: 8, y: 20, width: 40, height: 28), CGRect(x: 30, y: 6, width: 44, height: 40), CGRect(x: 62, y: 14, width: 40, height: 32), CGRect(x: 84, y: 24, width: 30, height: 24)]
            c.setFillColor(UIColor.white.cgColor)
            for puff in puffs {
                c.fillEllipse(in: puff)
            }
            c.fill(CGRect(x: 22, y: 34, width: 80, height: 14))
        }
    }

    static func sky(_ size: CGSize) -> SKTexture {
        texture(render(size) { c in
            gradient(c, CGRect(origin: .zero, size: size), [Palette.skyTop, Palette.skyBottom], horizontal: false)
            c.setFillColor(UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 0.35).cgColor)
            c.fillEllipse(in: CGRect(x: size.width * 0.62 - 20, y: size.height * 0.2 - 20, width: 100, height: 100))
            c.setFillColor(UIColor(red: 1, green: 0.93, blue: 0.62, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: size.width * 0.62, y: size.height * 0.2, width: 60, height: 60))
        })
    }

    /// Repeating mountain range; the first and last points share a height so tiles join.
    static func mountains(width: CGFloat) -> SKTexture {
        let size = CGSize(width: width, height: 220)
        return texture(render(size) { c in
            let peaks: [(CGFloat, CGFloat)] = [(0, 120), (0.12, 40), (0.25, 110), (0.4, 20), (0.55, 100), (0.7, 50), (0.85, 115), (1, 120)]
            let range = UIBezierPath()
            range.move(to: CGPoint(x: 0, y: size.height))
            for (x, y) in peaks {
                range.addLine(to: CGPoint(x: x * width, y: y))
            }
            range.addLine(to: CGPoint(x: width, y: size.height))
            range.close()
            fill(c, range, Palette.mountain)
            c.saveGState()
            range.addClip()
            for (x, y) in peaks where y < 60 {
                let cap = UIBezierPath()
                cap.move(to: CGPoint(x: x * width - 40, y: y + 34))
                cap.addLine(to: CGPoint(x: x * width, y: y))
                cap.addLine(to: CGPoint(x: x * width + 40, y: y + 34))
                cap.addLine(to: CGPoint(x: x * width + 14, y: y + 26))
                cap.addLine(to: CGPoint(x: x * width, y: y + 36))
                cap.addLine(to: CGPoint(x: x * width - 14, y: y + 26))
                cap.close()
                fill(c, cap, Palette.mountainSnow)
            }
            c.restoreGState()
        })
    }

    static func forest(width: CGFloat) -> SKTexture {
        let size = CGSize(width: width, height: 150)
        return texture(render(size) { c in
            fill(c, UIBezierPath(rect: CGRect(x: 0, y: 110, width: width, height: 40)), Palette.pineDark)
            let count = Int(width / 26)
            let step = width / CGFloat(count)
            for index in 0 ..< count {
                let x = CGFloat(index) * step + step / 2
                let height: CGFloat = 70 + CGFloat((index * 37) % 5) * 12
                let top = 120 - height
                for (layer, color) in [(0, Palette.pineDark), (1, Palette.pine)] {
                    let inset = CGFloat(layer) * 3
                    let tree = UIBezierPath()
                    tree.move(to: CGPoint(x: x, y: top + inset))
                    tree.addLine(to: CGPoint(x: x + 16 - inset, y: 122))
                    tree.addLine(to: CGPoint(x: x - 16 + inset, y: 122))
                    tree.close()
                    fill(c, tree, color)
                }
            }
        })
    }

    /// Grassy bank over a river; tiles horizontally every `width` points.
    static func ground(width: CGFloat, height: CGFloat) -> SKTexture {
        let size = CGSize(width: width, height: height)
        return texture(render(size) { c in
            gradient(c, CGRect(x: 0, y: 18, width: width, height: height - 18), [Palette.water, Palette.waterDeep], horizontal: false)
            fill(c, UIBezierPath(rect: CGRect(x: 0, y: 0, width: width, height: 20)), Palette.grass)
            fill(c, UIBezierPath(rect: CGRect(x: 0, y: 16, width: width, height: 5)), Palette.grassDark)
            let blades = Int(width / 12)
            for index in 0 ..< blades {
                let x = CGFloat(index) * width / CGFloat(blades)
                let blade = UIBezierPath()
                blade.move(to: CGPoint(x: x, y: 6))
                blade.addLine(to: CGPoint(x: x + 4, y: -2))
                blade.addLine(to: CGPoint(x: x + 7, y: 6))
                blade.close()
                fill(c, blade, index % 2 == 0 ? Palette.grassDark : Palette.grass)
            }
            c.setAlpha(0.35)
            for row in 0 ..< 5 {
                let y = 34 + CGFloat(row) * 16
                var x = CGFloat(row % 2) * 30
                while x < width {
                    let ripple = UIBezierPath()
                    ripple.move(to: CGPoint(x: x, y: y))
                    ripple.addQuadCurve(to: CGPoint(x: x + 26, y: y), controlPoint: CGPoint(x: x + 13, y: y - 5))
                    stroke(c, ripple, .white, 2)
                    x += 60
                }
            }
            c.setAlpha(1)
        })
    }

    private static func fill(_ c: CGContext, _ path: UIBezierPath, _ color: UIColor) {
        c.setFillColor(color.cgColor)
        c.addPath(path.cgPath)
        c.fillPath()
    }

    private static func stroke(_ c: CGContext, _ path: UIBezierPath, _ color: UIColor, _ width: CGFloat) {
        c.setStrokeColor(color.cgColor)
        c.setLineWidth(width)
        c.addPath(path.cgPath)
        c.strokePath()
    }

    private static func gradient(_ c: CGContext, _ rect: CGRect, _ colors: [UIColor], horizontal: Bool) {
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: nil) else { return }
        c.saveGState()
        c.clip(to: rect)
        let end = horizontal ? CGPoint(x: rect.maxX, y: rect.minY) : CGPoint(x: rect.minX, y: rect.maxY)
        c.drawLinearGradient(gradient, start: rect.origin, end: end, options: [])
        c.restoreGState()
    }
}
