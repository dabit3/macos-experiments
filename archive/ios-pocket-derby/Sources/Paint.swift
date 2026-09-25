import SpriteKit
import UIKit

/// CoreGraphics painting helpers that bake shaded, gradient-lit artwork into
/// SpriteKit textures. Contexts are centred and y-up so drawing code shares the
/// arena's coordinate system.
enum Paint {
    static func texture(size: CGSize, scale: CGFloat = 3, _ draw: (CGContext) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let ctx = context.cgContext
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.scaleBy(x: 1, y: -1)
            draw(ctx)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    static func sprite(size: CGSize, scale: CGFloat = 3, z: CGFloat = 0, _ draw: (CGContext) -> Void) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture(size: size, scale: scale, draw))
        node.size = size
        node.zPosition = z
        return node
    }

    static func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    static func gradient(_ colors: [UIColor], locations: [CGFloat]? = nil) -> CGGradient {
        CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map(\.cgColor) as CFArray,
            locations: locations
        )!
    }

    static func fill(_ ctx: CGContext, _ path: CGPath, _ color: UIColor) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }

    static func stroke(_ ctx: CGContext, _ path: CGPath, _ color: UIColor, width: CGFloat) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.strokePath()
        ctx.restoreGState()
    }

    static func linear(_ ctx: CGContext, _ path: CGPath, _ colors: [UIColor], from: CGPoint, to: CGPoint) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(
            gradient(colors),
            start: from,
            end: to,
            options: [.drawsAfterEndLocation, .drawsBeforeStartLocation]
        )
        ctx.restoreGState()
    }

    static func radial(_ ctx: CGContext, _ path: CGPath?, _ colors: [UIColor], center: CGPoint, radius: CGFloat) {
        ctx.saveGState()
        if let path {
            ctx.addPath(path)
            ctx.clip()
        }
        ctx.drawRadialGradient(
            gradient(colors), startCenter: center, startRadius: 0,
            endCenter: center, endRadius: radius, options: [.drawsAfterEndLocation]
        )
        ctx.restoreGState()
    }

    static func glow(_ ctx: CGContext, _ path: CGPath, _ color: UIColor, blur: CGFloat, fill: UIColor? = nil) {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: blur, color: color.cgColor)
        ctx.addPath(path)
        ctx.setFillColor((fill ?? color).cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }

    static func line(_ ctx: CGContext, _ points: [CGPoint], _ color: UIColor, width: CGFloat) {
        guard let first = points.first else { return }
        let path = CGMutablePath()
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        stroke(ctx, path, color, width: width)
    }

    /// Soft additive light blob used for trails, glows and floodlight haze.
    static func softLight(diameter: CGFloat, color: UIColor) -> SKTexture {
        texture(size: CGSize(width: diameter, height: diameter), scale: 2) { ctx in
            radial(ctx, nil, [color, color.withAlphaComponent(0)], center: .zero, radius: diameter / 2)
        }
    }

    // MARK: - Pixel art

    /// Bakes a low-resolution image (one point per art pixel, centred, y-up) and
    /// displays it magnified `pixel` times with nearest-neighbour filtering.
    static func pixelTexture(width: Int, height: Int, _ draw: (Pixels) -> Void) -> SKTexture {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let ctx = context.cgContext
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.scaleBy(x: 1, y: -1)
            ctx.setShouldAntialias(false)
            draw(Pixels(ctx: ctx))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    static func pixelSprite(
        width: Int,
        height: Int,
        pixel: CGFloat,
        z: CGFloat = 0,
        _ draw: (Pixels) -> Void
    ) -> SKSpriteNode {
        let node = SKSpriteNode(texture: pixelTexture(width: width, height: height, draw))
        node.size = CGSize(width: CGFloat(width) * pixel, height: CGFloat(height) * pixel)
        node.zPosition = z
        return node
    }

    /// Classic sprite-sheet authoring: rows of characters looked up in a palette.
    /// Rows are listed top-down; `.` (or any unmapped character) is transparent.
    static func spriteMap(_ rows: [String], palette: [Character: UIColor]) -> SKTexture {
        let height = rows.count
        let width = rows.map(\.count).max() ?? 0
        return pixelTexture(width: width, height: height) { pixels in
            for (rowIndex, row) in rows.enumerated() {
                for (column, key) in row.enumerated() {
                    if let color = palette[key] {
                        pixels.fill(column - width / 2, height / 2 - rowIndex - 1, 1, 1, color)
                    }
                }
            }
        }
    }

    static func spriteNode(
        _ rows: [String],
        palette: [Character: UIColor],
        pixel: CGFloat,
        z: CGFloat = 0
    ) -> SKSpriteNode {
        let node = SKSpriteNode(texture: spriteMap(rows, palette: palette))
        node.size = CGSize(width: node.texture!.size().width * pixel, height: node.texture!.size().height * pixel)
        node.zPosition = z
        return node
    }
}

/// Integer pixel drawing over a centred, y-up CoreGraphics context.
struct Pixels {
    let ctx: CGContext

    func fill(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: UIColor) {
        guard width > 0, height > 0 else { return }
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: x, y: y, width: width, height: height))
    }

    func dot(_ x: Int, _ y: Int, _ color: UIColor) {
        fill(x, y, 1, 1, color)
    }

    func hline(_ x0: Int, _ x1: Int, _ y: Int, _ color: UIColor) {
        fill(min(x0, x1), y, abs(x1 - x0) + 1, 1, color)
    }

    func vline(_ x: Int, _ y0: Int, _ y1: Int, _ color: UIColor) {
        fill(x, min(y0, y1), 1, abs(y1 - y0) + 1, color)
    }

    func frame(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: UIColor) {
        hline(x, x + width - 1, y, color)
        hline(x, x + width - 1, y + height - 1, color)
        vline(x, y, y + height - 1, color)
        vline(x + width - 1, y, y + height - 1, color)
    }

    /// Row spans of a pixel rounded rectangle: (y, x0, x1) inclusive.
    static func roundedSpans(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ radius: Int) -> [(Int, Int, Int)] {
        (0 ..< height).map { row in
            let fromEdge = min(row, height - 1 - row)
            var inset = 0
            if fromEdge < radius {
                let dy = Double(radius - fromEdge) - 0.5
                inset = radius - Int((Double(radius * radius) - dy * dy).squareRoot().rounded())
            }
            return (y + row, x + inset, x + width - 1 - inset)
        }
    }

    func roundedFill(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ radius: Int, _ color: UIColor) {
        for (row, x0, x1) in Pixels.roundedSpans(x, y, width, height, radius) {
            hline(x0, x1, row, color)
        }
    }

    func roundedFrame(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ radius: Int, _ color: UIColor) {
        let spans = Pixels.roundedSpans(x, y, width, height, radius)
        for (index, span) in spans.enumerated() {
            let (row, x0, x1) = span
            if index == 0 || index == spans.count - 1 {
                hline(x0, x1, row, color)
                continue
            }
            let previous = spans[index - 1]
            let next = spans[index + 1]
            hline(min(x0, previous.1, next.1), x0, row, color)
            hline(x1, max(x1, previous.2, next.2), row, color)
        }
    }

    func roundedPath(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ radius: Int) -> CGPath {
        let path = CGMutablePath()
        for (row, x0, x1) in Pixels.roundedSpans(x, y, width, height, radius) {
            path.addRect(CGRect(x: x0, y: row, width: x1 - x0 + 1, height: 1))
        }
        return path
    }

    func circleFrame(_ cx: Int, _ cy: Int, _ radius: Int, _ color: UIColor) {
        let r = Double(radius) - 0.5
        for offset in -radius ..< radius {
            let d = Double(offset) + 0.5
            let span = Int((r * r - d * d).squareRoot().rounded())
            for sign in [-1, 1] {
                dot(cx + offset, cy + sign * span - (sign < 0 ? 1 : 0), color)
                dot(cx + sign * span - (sign < 0 ? 1 : 0), cy + offset, color)
            }
        }
    }

    func circleFill(_ cx: Int, _ cy: Int, _ radius: Int, _ color: UIColor) {
        let r = Double(radius) - 0.5
        for offset in -radius ..< radius {
            let d = Double(offset) + 0.5
            let span = Int((r * r - d * d).squareRoot().rounded())
            hline(cx - span, cx + span - 1, cy + offset, color)
        }
    }

    /// Two-colour checkerboard clipped to a path, `cell` pixels per square.
    func checker(_ path: CGPath, cell: Int, _ a: UIColor, _ b: UIColor, origin: Int = 0) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let bounds = path.boundingBoxOfPath
        let x0 = Int(bounds.minX.rounded(.down)), x1 = Int(bounds.maxX.rounded(.up))
        let y0 = Int(bounds.minY.rounded(.down)), y1 = Int(bounds.maxY.rounded(.up))
        fill(x0, y0, x1 - x0, y1 - y0, a)
        var y = y0 - (y0 - origin) % cell - cell
        while y < y1 {
            var x = x0 - (x0 - origin) % cell - cell
            while x < x1 {
                let dark = (((x - origin) / cell) + ((y - origin) / cell)).isMultiple(of: 2)
                if dark {
                    fill(x, y, cell, cell, b)
                }
                x += cell
            }
            y += cell
        }
        ctx.restoreGState()
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255,
            alpha: 1
        )
    }

    func mixed(with other: UIColor, _ amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * amount, green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount, alpha: a1 + (a2 - a1) * amount
        )
    }

    var lighter: UIColor {
        mixed(with: .white, 0.32)
    }

    var darker: UIColor {
        mixed(with: .black, 0.4)
    }
}
