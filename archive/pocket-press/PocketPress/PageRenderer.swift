import PDFKit
import UIKit

struct PrintPalette {
    let paper: UIColor
    let ink: UIColor
    let accent: UIColor
    let quiet: UIColor
    let display: String

    static func forTheme(_ theme: PressTheme) -> PrintPalette {
        switch theme {
        case .riviera:
            PrintPalette(
                paper: UIColor(hex: 0xF5F1E7), ink: UIColor(hex: 0x23251F),
                accent: UIColor(hex: 0x2448D8), quiet: UIColor(hex: 0x696B63), display: "Georgia")
        case .terracotta:
            PrintPalette(
                paper: UIColor(hex: 0xFFF3E5), ink: UIColor(hex: 0x462E25),
                accent: UIColor(hex: 0xB0462C), quiet: UIColor(hex: 0x806458), display: "Baskerville")
        case .nocturne:
            PrintPalette(
                paper: UIColor(hex: 0x182C30), ink: UIColor(hex: 0xF1F0DD),
                accent: UIColor(hex: 0xD7E78A), quiet: UIColor(hex: 0xB4C3BE),
                display: "AvenirNext-DemiBold")
        }
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}

@MainActor
enum PageRenderer {
    static let size = CGSize(width: 420, height: 594)
    private static let cache = NSCache<NSString, UIImage>()

    static func photograph(_ name: String) -> UIImage? {
        if let image = cache.object(forKey: name as NSString) { return image }
        let image: UIImage?
        if name.hasPrefix("import-"), name == URL(fileURLWithPath: name).lastPathComponent {
            image = UIImage(contentsOfFile: PressStore.directory.appending(path: name).path)
        } else if let url = Bundle.main.url(forResource: name, withExtension: "jpg") {
            image = UIImage(contentsOfFile: url.path)
        } else {
            image = nil
        }
        if let image { cache.setObject(image, forKey: name as NSString) }
        return image
    }

    static func preview(_ page: MagazinePage, theme: PressTheme, index: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(page, theme: theme, index: index, in: context.cgContext)
        }
    }

    static func export(_ magazine: Magazine) throws -> URL {
        let directory = PressStore.directory.appending(path: "Exports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: magazine.exportFilename)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: magazine.title,
            kCGPDFContextCreator as String: "Pocket Press",
            kCGPDFContextAuthor as String: "Independent traveller",
        ]
        let data = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size), format: format)
            .pdfData { context in
                for (index, page) in magazine.pages.enumerated() {
                    context.beginPage()
                    draw(page, theme: magazine.theme, index: index, in: context.cgContext)
                }
            }
        try data.write(to: url, options: .atomic)
        return url
    }

    static func draw(_ page: MagazinePage, theme: PressTheme, index: Int, in context: CGContext) {
        let palette = PrintPalette.forTheme(theme)
        fill(CGRect(origin: .zero, size: size), palette.paper)
        switch page.kind {
        case .cover: cover(page, palette: palette, context: context)
        case .photograph: photoPage(page, palette: palette, context: context)
        case .story: story(page, palette: palette, context: context)
        case .fieldNotes: notes(page, palette: palette, context: context)
        }
        if page.kind != .cover {
            rule(y: 558, color: palette.quiet.withAlphaComponent(0.35))
            text(
                "POCKET PRESS", rect: CGRect(x: 28, y: 570, width: 200, height: 12),
                font: sans(8), color: palette.quiet, tracking: 2)
            text(
                String(format: "%02d", index + 1),
                rect: CGRect(x: 356, y: 565, width: 36, height: 20), font: sans(13, bold: true),
                color: palette.accent, alignment: .right)
        }
    }

    private static func cover(_ page: MagazinePage, palette: PrintPalette, context: CGContext) {
        text(
            "POCKET PRESS   /   VOL. 01", rect: CGRect(x: 28, y: 24, width: 320, height: 16),
            font: sans(10, bold: true), color: palette.accent, tracking: 2)
        rule(y: 49, color: palette.ink)
        text(
            page.title, rect: CGRect(x: 24, y: 67, width: 372, height: 156),
            font: display(palette, size: 67), color: palette.ink, minimumSize: 24, lineSpacing: -3)
        text(
            page.location.uppercased(), rect: CGRect(x: 29, y: 228, width: 363, height: 18),
            font: sans(10, bold: true), color: palette.accent, tracking: 1.5)
        photograph(
            page.imageName, in: CGRect(x: 0, y: 260, width: 420, height: 260),
            palette: palette, context: context)
        fill(CGRect(x: 28, y: 502, width: 55, height: 37), palette.accent)
        text(
            "01", rect: CGRect(x: 28, y: 510, width: 55, height: 22),
            font: sans(18, bold: true), color: palette.paper, alignment: .center)
        text(
            page.caption, rect: CGRect(x: 105, y: 535, width: 286, height: 40),
            font: sans(11), color: palette.ink, minimumSize: 9, lineSpacing: 2)
        text(
            "A PLACE\nTO KEEP.", rect: CGRect(x: 28, y: 549, width: 70, height: 30),
            font: sans(8, bold: true), color: palette.accent, tracking: 1)
    }

    private static func photoPage(_ page: MagazinePage, palette: PrintPalette, context: CGContext) {
        text(
            page.location.uppercased(), rect: CGRect(x: 28, y: 25, width: 364, height: 24),
            font: sans(10, bold: true), color: palette.accent, tracking: 1.4)
        photograph(
            page.imageName, in: CGRect(x: 28, y: 61, width: 364, height: 305),
            palette: palette, context: context)
        fill(CGRect(x: 28, y: 366, width: 42, height: 4), palette.accent)
        text(
            page.title, rect: CGRect(x: 25, y: 390, width: 367, height: 99),
            font: display(palette, size: 39), color: palette.ink, minimumSize: 24, lineSpacing: -1)
        text(
            page.caption, rect: CGRect(x: 115, y: 497, width: 277, height: 49),
            font: sans(11), color: palette.quiet, minimumSize: 9, lineSpacing: 2)
    }

    private static func story(_ page: MagazinePage, palette: PrintPalette, context: CGContext) {
        text(
            page.location.uppercased(), rect: CGRect(x: 28, y: 25, width: 364, height: 22),
            font: sans(10, bold: true), color: palette.accent, tracking: 1.5)
        text(
            page.title, rect: CGRect(x: 25, y: 65, width: 370, height: 113),
            font: display(palette, size: 46), color: palette.ink, minimumSize: 26, lineSpacing: -2)
        rule(y: 187, color: palette.accent)
        text(
            page.caption, rect: CGRect(x: 28, y: 200, width: 364, height: 35),
            font: sans(9, bold: true), color: palette.accent, minimumSize: 8, tracking: 1)
        text(
            page.body, rect: CGRect(x: 65, y: 246, width: 316, height: 292),
            font: UIFont(name: "Georgia", size: 14) ?? .systemFont(ofSize: 14),
            color: palette.ink, minimumSize: 10, lineSpacing: 4)
        text(
            "“", rect: CGRect(x: 25, y: 238, width: 35, height: 70),
            font: display(palette, size: 56), color: palette.accent)
    }

    private static func notes(_ page: MagazinePage, palette: PrintPalette, context: CGContext) {
        text(
            page.location.uppercased(), rect: CGRect(x: 28, y: 25, width: 364, height: 22),
            font: sans(10, bold: true), color: palette.accent, tracking: 1.5)
        text(
            page.title, rect: CGRect(x: 25, y: 65, width: 370, height: 109),
            font: display(palette, size: 43), color: palette.ink, minimumSize: 25, lineSpacing: -1)
        text(
            page.caption, rect: CGRect(x: 28, y: 185, width: 364, height: 43),
            font: sans(12), color: palette.quiet, minimumSize: 10, lineSpacing: 2)
        let entries = page.body.split(separator: "\n").map(String.init)
        let height = min(72.0, 292.0 / CGFloat(max(entries.count, 1)))
        for (index, entry) in entries.enumerated() {
            let y = 242 + CGFloat(index) * height
            rule(y: y, color: palette.quiet.withAlphaComponent(0.35))
            text(
                String(format: "%02d", index + 1),
                rect: CGRect(x: 28, y: y + 12, width: 40, height: 20),
                font: sans(12, bold: true), color: palette.accent)
            text(
                entry, rect: CGRect(x: 82, y: y + 10, width: 300, height: height - 15),
                font: sans(13), color: palette.ink, minimumSize: 9, lineSpacing: 3)
        }
    }

    private static func photograph(_ name: String, in rect: CGRect, palette: PrintPalette, context: CGContext)
    {
        context.saveGState()
        context.clip(to: rect)
        if let image = photograph(name) {
            let scale = max(rect.width / image.size.width, rect.height / image.size.height)
            let width = image.size.width * scale
            let height = image.size.height * scale
            image.draw(
                in: CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height))
        } else {
            fill(rect, palette.accent.withAlphaComponent(0.12))
            text(
                "A photograph belongs here.", rect: rect.insetBy(dx: 25, dy: rect.height / 2 - 10),
                font: sans(13), color: palette.ink, alignment: .center)
        }
        context.restoreGState()
    }

    private static func sans(_ size: CGFloat, bold: Bool = false) -> UIFont {
        UIFont(name: bold ? "AvenirNext-DemiBold" : "AvenirNext-Regular", size: size)
            ?? .systemFont(ofSize: size)
    }

    private static func display(_ palette: PrintPalette, size: CGFloat) -> UIFont {
        UIFont(name: palette.display, size: size) ?? .systemFont(ofSize: size, weight: .medium)
    }

    private static func fill(_ rect: CGRect, _ color: UIColor) {
        color.setFill()
        UIRectFill(rect)
    }

    private static func rule(y: CGFloat, color: UIColor) {
        fill(CGRect(x: 28, y: y, width: 364, height: 0.6), color)
    }

    private static func text(
        _ value: String, rect: CGRect, font: UIFont, color: UIColor, minimumSize: CGFloat? = nil,
        alignment: NSTextAlignment = .left, tracking: CGFloat = 0, lineSpacing: CGFloat = 0
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineSpacing = lineSpacing
        paragraph.lineBreakMode = .byWordWrapping
        var current = font
        let attributed = NSMutableAttributedString(string: value)
        let range = NSRange(location: 0, length: attributed.length)
        attributed.addAttribute(.font, value: current, range: range)
        attributed.addAttribute(.foregroundColor, value: color, range: range)
        attributed.addAttribute(.paragraphStyle, value: paragraph, range: range)
        attributed.addAttribute(.kern, value: tracking, range: range)
        if let minimumSize {
            while current.pointSize > minimumSize {
                let bounds = attributed.boundingRect(
                    with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                if bounds.height <= rect.height { break }
                current = font.withSize(current.pointSize - 0.5)
                attributed.addAttribute(.font, value: current, range: range)
            }
        }
        attributed.draw(
            with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil)
    }
}
