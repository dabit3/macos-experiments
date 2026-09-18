import SwiftUI

/// Console-era palette: a small set of saturated, hard-edged colours shared by
/// the SwiftUI shell and the SpriteKit arena. Everything is drawn on a 4pt
/// pixel grid (`Theme.px`) with square corners and no blur, gradients or glow.
enum Theme {
    static let px: CGFloat = 4

    static let ink = Color(hex: 0x0C0C1C)
    static let white = Color(hex: 0xFCFCFC)
    static let grey = Color(hex: 0xBCBCBC)
    static let greyDark = Color(hex: 0x7C7C7C)
    static let sky = Color(hex: 0x3CBCFC)
    static let skyDeep = Color(hex: 0x0058F8)
    static let skyPale = Color(hex: 0xA4E4FC)
    static let blue = Color(hex: 0x0058F8)
    static let blueLight = Color(hex: 0x3CBCFC)
    static let red = Color(hex: 0xF83800)
    static let redLight = Color(hex: 0xF87858)
    static let yellow = Color(hex: 0xF8D800)
    static let orange = Color(hex: 0xFC9838)
    static let green = Color(hex: 0x3CB43C)
    static let greenDark = Color(hex: 0x2C982C)
    static let purple = Color(hex: 0x201C5C)
    static let purpleLight = Color(hex: 0x4838B8)
    static let panel = Color(hex: 0x14143C)
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

/// Every half second flips between two states; the classic "PRESS START" blink.
/// Static when reduced motion is on.
struct Blink<Content: View>: View {
    var interval = 0.5
    var reduced = false
    @ViewBuilder let content: (Bool) -> Content
    var body: some View {
        if reduced {
            content(true)
        } else {
            TimelineView(.periodic(from: .now, by: interval)) { timeline in
                content(Int(timeline.date.timeIntervalSinceReferenceDate / interval).isMultiple(of: 2))
            }
        }
    }
}

/// Console dialog box: dark fill, white double border, hard-edged corners.
struct PixelPanel: ViewModifier {
    var fill = Theme.panel
    var border = Theme.white
    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(Rectangle().strokeBorder(border, lineWidth: Theme.px))
            .padding(Theme.px)
            .background(Theme.ink)
    }
}

extension View {
    func pixelPanel(fill: Color = Theme.panel, border: Color = Theme.white) -> some View {
        modifier(PixelPanel(fill: fill, border: border))
    }
}

/// Chunky two-tone button with a hard drop shadow; pressing snaps it down onto
/// the shadow with no easing, like a cartridge-era menu.
struct PixelButtonStyle: ButtonStyle {
    var face = Theme.yellow
    var shade = Theme.orange
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .background(
                VStack(spacing: 0) {
                    face
                    shade.frame(height: Theme.px * 2)
                }
            )
            .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: Theme.px))
            .background(
                Theme.ink.offset(x: pressed ? 0 : Theme.px, y: pressed ? 0 : Theme.px)
            )
            .offset(x: pressed ? Theme.px : 0, y: pressed ? Theme.px : 0)
            .animation(nil, value: pressed)
    }
}

/// Team badge: a square shield with the team's initial.
struct TeamBadge: View {
    var color: Color
    var light: Color
    var letter: String
    var px: CGFloat = 2
    var body: some View {
        ZStack {
            Rectangle().fill(color)
            VStack(spacing: 0) {
                light.frame(height: px)
                Spacer(minLength: 0)
            }
            PixelText(letter, px: px, color: Theme.white)
        }
        .frame(width: px * (CGFloat(letter.count) * 6 + 3), height: px * 9)
        .overlay(Rectangle().strokeBorder(Theme.ink, lineWidth: px))
        .padding(px)
        .background(Theme.white)
        .padding(px)
        .background(Theme.ink)
        .accessibilityHidden(true)
    }
}

/// Daytime skyline drawn as 4pt pixels: banded sky, sun, drifting-still clouds
/// and two tiers of block towers with lit windows.
struct PixelSkyline: View {
    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: false) { context, size in
            let px = Theme.px
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
                context.fill(Path(CGRect(x: x * px, y: y * px, width: w * px, height: h * px)), with: .color(color))
            }
            let cols = ceil(size.width / px)
            let rows = ceil(size.height / px)
            var seed: UInt32 = 4211
            func random() -> CGFloat {
                seed = seed &* 1_664_525 &+ 1_013_904_223
                return CGFloat(seed >> 8) / CGFloat(1 << 24)
            }
            // Sky bands with a dithered seam between each pair.
            let bands: [(CGFloat, Color)] = [(0, Theme.skyDeep), (0.18, Theme.sky), (0.46, Theme.skyPale)]
            for (index, band) in bands.enumerated() {
                let top = floor(rows * band.0)
                let bottom = index + 1 < bands.count ? floor(rows * bands[index + 1].0) : rows
                rect(0, top, cols, bottom - top, band.1)
                if index + 1 < bands.count {
                    let next = bands[index + 1].1
                    for x in stride(from: 0, to: cols, by: 2) {
                        rect(x, bottom - 1, 1, 1, next)
                        rect(x + 1, bottom, 1, 1, band.1)
                    }
                }
            }
            // Sun.
            let sun = CGPoint(x: floor(cols * 0.42), y: floor(rows * 0.09))
            let disc: [String] = [
                "..####..",
                ".######.",
                "########",
                "########",
                "########",
                "########",
                ".######.",
                "..####.."
            ]
            for (y, row) in disc.enumerated() {
                for (x, bit) in row.enumerated() where bit == "#" {
                    rect(sun.x + CGFloat(x), sun.y + CGFloat(y), 1, 1, y < 5 ? Theme.yellow : Theme.orange)
                }
            }
            // Clouds.
            let cloud: [String] = ["....####....", "..########..", ".##########.", "############", ".##########."]
            for origin in [CGPoint(x: 0.08, y: 0.13), CGPoint(x: 0.62, y: 0.2), CGPoint(x: 0.84, y: 0.07)] {
                let cx = floor(cols * origin.x), cy = floor(rows * origin.y)
                for (y, row) in cloud.enumerated() {
                    for (x, bit) in row.enumerated() where bit == "#" {
                        rect(cx + CGFloat(x), cy + CGFloat(y), 1, 1, y == cloud.count - 1 ? Theme.grey : Theme.white)
                    }
                }
            }
            // Towers.
            for layer in 0 ..< 2 {
                let base = floor(rows * (layer == 0 ? 0.66 : 0.8))
                let fill = layer == 0 ? Theme.purpleLight : Theme.purple
                let window = layer == 0 ? Theme.skyPale : Theme.yellow
                var x: CGFloat = -2
                while x < cols + 4 {
                    let width = floor(6 + random() * 12)
                    let height = floor(5 + random() * (layer == 0 ? 22 : 14))
                    rect(x, base - height, width, rows - base + height, fill)
                    if random() > 0.55 {
                        rect(x + floor(width / 2), base - height - 4, 1, 4, fill)
                    }
                    var wy = base - height + 2
                    while wy < base - 1 {
                        var wx = x + 1
                        while wx < x + width - 1 {
                            if random() > 0.45 {
                                rect(wx, wy, 1, 1, window)
                            }
                            wx += 2
                        }
                        wy += 3
                    }
                    x += width + 1 + floor(random() * 3)
                }
            }
            rect(0, rows - 6, cols, 6, Theme.purple)
            rect(0, rows - 6, cols, 1, Theme.purpleLight)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension Color {
    func mixed(_ other: Color, _ amount: CGFloat) -> Color {
        Color(uiColor: UIColor(self).mixed(with: UIColor(other), amount))
    }
}
