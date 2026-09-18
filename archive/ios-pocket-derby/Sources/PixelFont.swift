import SpriteKit
import SwiftUI

/// Original 5x7 bitmap typeface in the spirit of 8/16-bit console fonts. Glyphs
/// are rendered as hard-edged squares, never smoothed, so type stays on the same
/// pixel grid as the artwork. A handful of icon glyphs live in the same table.
enum PixelFont {
    static let columns = 5
    static let rows = 7
    static let advance = 6
    static let leading = 9

    static let play: Character = "▶"
    static let back: Character = "◀"
    static let up: Character = "▲"
    static let down: Character = "▼"
    static let pause: Character = "‖"
    static let bolt: Character = "⚡"
    static let note: Character = "♪"
    static let stop: Character = "✋"
    static let check: Character = "✓"
    static let trophy: Character = "♛"
    static let star: Character = "★"
    static let heart: Character = "♥"
    static let ball: Character = "●"
    static let pad: Character = "✚"

    static func glyph(_ character: Character) -> [String] {
        glyphs[character] ?? glyphs["?"]!
    }

    /// Filled pixel rectangles for a block of text, in glyph units (1 = one pixel).
    /// Multi-line text is separated by `\n`; `center` centres shorter lines.
    static func rects(_ text: String, center: Bool) -> [CGRect] {
        let lines = text.uppercased().split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let widest = lines.map(\.count).max() ?? 0
        var result: [CGRect] = []
        for (lineIndex, line) in lines.enumerated() {
            let offset = center ? (widest - line.count) * advance / 2 : 0
            let top = lineIndex * leading
            for (charIndex, character) in line.enumerated() {
                let left = offset + charIndex * advance
                for (row, bits) in glyph(character).enumerated() {
                    var run: Int?
                    for (column, bit) in bits.enumerated() {
                        if bit == "#" {
                            if run == nil {
                                run = column
                            }
                        } else if let start = run {
                            result.append(CGRect(x: left + start, y: top + row, width: column - start, height: 1))
                            run = nil
                        }
                    }
                    if let start = run {
                        result.append(CGRect(x: left + start, y: top + row, width: columns - start, height: 1))
                    }
                }
            }
        }
        return result
    }

    static func size(of text: String) -> CGSize {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let widest = lines.map(\.count).max() ?? 0
        return CGSize(
            width: max(0, widest * advance - 1),
            height: max(0, lines.count * leading - (leading - rows))
        )
    }

    /// Crisp SpriteKit texture, one image pixel per glyph pixel.
    static func texture(_ text: String, color: UIColor, outline: UIColor? = nil) -> SKTexture {
        let pad = outline == nil ? 0 : 1
        let base = size(of: text)
        let size = CGSize(width: base.width + CGFloat(pad * 2), height: base.height + CGFloat(pad * 2))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let ctx = context.cgContext
            let rects = rects(text, center: true).map { $0.offsetBy(dx: CGFloat(pad), dy: CGFloat(pad)) }
            if let outline {
                ctx.setFillColor(outline.cgColor)
                for dx in -1 ... 1 {
                    for dy in -1 ... 1 where dx != 0 || dy != 0 {
                        ctx.fill(rects.map { $0.offsetBy(dx: CGFloat(dx), dy: CGFloat(dy)) })
                    }
                }
            }
            ctx.setFillColor(color.cgColor)
            ctx.fill(rects)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    static func label(_ text: String, pixel: CGFloat, color: UIColor, outline: UIColor? = nil) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture(text, color: color, outline: outline))
        node.size = CGSize(width: node.texture!.size().width * pixel, height: node.texture!.size().height * pixel)
        return node
    }

    // swiftformat:disable all
    static let glyphs: [Character: [String]] = [
        " ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".####", "#....", "#....", "#....", "#....", "#....", ".####"],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".####", "#....", "#....", "#.###", "#...#", "#...#", ".####"],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
        "J": ["....#", "....#", "....#", "....#", "#...#", "#...#", ".###."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
        "0": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
        ".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
        ",": [".....", ".....", ".....", ".....", ".##..", "..#..", ".#..."],
        ":": [".....", ".##..", ".##..", ".....", ".##..", ".##..", "....."],
        "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
        "?": [".###.", "#...#", "....#", "..##.", "..#..", ".....", "..#.."],
        "'": [".##..", "..#..", ".#...", ".....", ".....", ".....", "....."],
        "-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
        "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
        "=": [".....", ".....", "#####", ".....", "#####", ".....", "....."],
        "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
        "·": [".....", ".....", ".....", ".##..", ".##..", ".....", "....."],
        "▶": ["#....", "##...", "###..", "####.", "###..", "##...", "#...."],
        "◀": ["....#", "...##", "..###", ".####", "..###", "...##", "....#"],
        "▲": ["..#..", ".###.", "#.#.#", "..#..", "..#..", "..#..", "..#.."],
        "▼": ["..#..", "..#..", "..#..", "..#..", "#.#.#", ".###.", "..#.."],
        "‖": [".....", "##.##", "##.##", "##.##", "##.##", "##.##", "....."],
        "⚡": ["...##", "..##.", ".##..", "#####", "...#.", "..#..", ".#..."],
        "♪": ["..##.", "..#.#", "..#..", "..#..", ".##..", "###..", "##..."],
        "✋": [".###.", "#####", "#####", "#####", "#####", "#####", ".###."],
        "✓": [".....", "....#", "...#.", "#.#..", ".#...", ".....", "....."],
        "♛": ["#####", "#####", ".###.", "..#..", "..#..", ".###.", "#####"],
        "★": ["..#..", ".###.", "#####", ".###.", "#.#.#", ".....", "....."],
        "♥": [".#.#.", "#####", "#####", "#####", ".###.", "..#..", "....."],
        "●": [".###.", "#####", "#####", "#####", ".###.", ".....", "....."],
        "✚": ["..#..", ".###.", "#####", ".###.", "..#..", ".....", "....."]
    ]
    // swiftformat:enable all
}

/// SwiftUI text rendered with `PixelFont`. `px` is the on-screen size of one
/// glyph pixel; `bottom` gives the lower three rows a second colour for the
/// classic two-tone title look.
struct PixelText: View {
    let text: String
    var px: CGFloat = 2
    var color: Color = Theme.white
    var bottom: Color?
    var outline: Color?
    var shadow: Color?
    var center = false

    init(
        _ text: String,
        px: CGFloat = 2,
        color: Color = Theme.white,
        bottom: Color? = nil,
        outline: Color? = nil,
        shadow: Color? = nil,
        center: Bool = false
    ) {
        self.text = text
        self.px = px
        self.color = color
        self.bottom = bottom
        self.outline = outline
        self.shadow = shadow
        self.center = center
    }

    var body: some View {
        let pad: CGFloat = outline == nil ? 0 : 1
        let drop: CGFloat = shadow == nil ? 0 : 1
        let base = PixelFont.size(of: text)
        let frame = CGSize(
            width: (base.width + pad * 2 + drop) * px,
            height: (base.height + pad * 2 + drop) * px
        )
        Canvas(opaque: false, rendersAsynchronously: false) { context, _ in
            let rects = PixelFont.rects(text, center: center)
            func paint(dx: CGFloat, dy: CGFloat, _ shading: GraphicsContext.Shading, rows: ClosedRange<Int>? = nil) {
                var path = Path()
                for rect in rects {
                    if let rows, !rows.contains(Int(rect.minY) % PixelFont.leading) {
                        continue
                    }
                    path.addRect(CGRect(
                        x: (rect.minX + pad + dx) * px,
                        y: (rect.minY + pad + dy) * px,
                        width: rect.width * px,
                        height: rect.height * px
                    ))
                }
                context.fill(path, with: shading)
            }
            if let shadow {
                let reach = outline == nil ? 0 : 1
                for dx in -reach ... reach {
                    for dy in -reach ... reach {
                        paint(dx: CGFloat(dx) + 1, dy: CGFloat(dy) + 1, .color(shadow))
                    }
                }
            }
            if let outline {
                for dx in -1 ... 1 {
                    for dy in -1 ... 1 where dx != 0 || dy != 0 {
                        paint(dx: CGFloat(dx), dy: CGFloat(dy), .color(outline))
                    }
                }
            }
            if let bottom {
                paint(dx: 0, dy: 0, .color(color), rows: 0 ... 3)
                paint(dx: 0, dy: 0, .color(bottom), rows: 4 ... 6)
            } else {
                paint(dx: 0, dy: 0, .color(color))
            }
        }
        .frame(width: frame.width, height: frame.height)
        .accessibilityLabel(Text(text.replacingOccurrences(of: "\n", with: " ")))
    }
}
