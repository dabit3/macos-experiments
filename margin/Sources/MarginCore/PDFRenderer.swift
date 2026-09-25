import AppKit
import CoreText
import PDFKit

@MainActor
public enum PDFRenderer {
  static let ink = NSColor(calibratedRed: 0.18, green: 0.17, blue: 0.15, alpha: 1)
  static let oxblood = NSColor(calibratedRed: 0.43, green: 0.17, blue: 0.20, alpha: 1)

  public static func generateSource(to url: URL) throws {
    var box = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else {
      throw CocoaError(.fileWriteUnknown)
    }
    for (index, page) in SourceMaterial.pages.enumerated() {
      context.beginPDFPage(nil)
      context.setFillColor(NSColor(calibratedWhite: 0.993, alpha: 1).cgColor)
      context.fill(box)
      draw(
        page.eyebrow, rect: CGRect(x: 58, y: 720, width: 490, height: 20),
        font: .systemFont(ofSize: 10, weight: .semibold), color: oxblood, in: context)
      context.setStrokeColor(oxblood.withAlphaComponent(0.35).cgColor)
      context.setLineWidth(0.6)
      context.move(to: CGPoint(x: 58, y: 707))
      context.addLine(to: CGPoint(x: 554, y: 707))
      context.strokePath()
      draw(
        page.title, rect: CGRect(x: 55, y: 555, width: 500, height: 139),
        font: .init(name: "Georgia", size: 48)!, color: ink, lineSpacing: 0, in: context)
      draw(
        page.subtitle, rect: CGRect(x: 58, y: 528, width: 490, height: 25),
        font: .init(name: "Georgia-Italic", size: 14)!, color: oxblood, in: context)
      draw(
        page.paragraphs.joined(separator: "\n\n"),
        rect: CGRect(x: 58, y: 175, width: 492, height: 330),
        font: .init(name: "Georgia", size: 12.5)!, color: ink,
        lineSpacing: 4.2, in: context)
      context.setFillColor(NSColor(calibratedRed: 0.96, green: 0.93, blue: 0.89, alpha: 1).cgColor)
      context.fill(CGRect(x: 58, y: 75, width: 496, height: 84))
      context.setFillColor(oxblood.cgColor)
      context.fill(CGRect(x: 58, y: 75, width: 3, height: 84))
      draw(
        page.pullQuote, rect: CGRect(x: 78, y: 85, width: 450, height: 57),
        font: .init(name: "Georgia-Italic", size: 18)!, color: oxblood,
        lineSpacing: 3, in: context)
      draw(
        "MARGIN FIELD NOTES     /     ORIGINAL ESSAY · 2026",
        rect: CGRect(x: 58, y: 31, width: 430, height: 18),
        font: .systemFont(ofSize: 8, weight: .medium), color: .gray, in: context)
      draw(
        String(format: "%02d", index + 1),
        rect: CGRect(x: 532, y: 31, width: 30, height: 18),
        font: .systemFont(ofSize: 9, weight: .semibold), color: oxblood, in: context)
      context.endPDFPage()
    }
    context.closePDF()
  }

  public static func export(_ project: Project, to url: URL) throws {
    let content = NSMutableAttributedString()
    content.append(
      NSAttributedString(
        string: project.title + "\n\n",
        attributes: [
          .font: NSFont(name: "Georgia", size: 30)!,
          .foregroundColor: oxblood,
        ]))
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 5
    paragraph.paragraphSpacing = 10
    content.append(
      NSAttributedString(
        string: project.draft,
        attributes: [
          .font: NSFont(name: "Georgia", size: 12)!,
          .foregroundColor: ink,
          .paragraphStyle: paragraph,
        ]))
    if !project.excerpts.isEmpty {
      content.append(
        NSAttributedString(
          string:
            "\n\nSOURCE\nMargin Field Notes (2026). The attentive city: Notes on streets, stillness & public life.\nOriginal illustrative essay bundled with Margin.",
          attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: ink]
        ))
    }
    var box = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else {
      throw CocoaError(.fileWriteUnknown)
    }
    let framesetter = CTFramesetterCreateWithAttributedString(content)
    var offset = 0
    var page = 1
    repeat {
      context.beginPDFPage(nil)
      let frame = CTFramesetterCreateFrame(
        framesetter, CFRange(location: offset, length: 0),
        CGPath(rect: CGRect(x: 64, y: 65, width: 484, height: 657), transform: nil), nil
      )
      CTFrameDraw(frame, context)
      let visible = CTFrameGetVisibleStringRange(frame)
      guard visible.length > 0 else {
        context.endPDFPage()
        context.closePDF()
        throw CocoaError(.fileWriteUnknown)
      }
      offset += visible.length
      draw(
        "MARGIN    /    RESEARCH BRIEF",
        rect: CGRect(x: 64, y: 29, width: 400, height: 18),
        font: .systemFont(ofSize: 8), color: .gray, in: context)
      draw(
        "\(page)", rect: CGRect(x: 530, y: 29, width: 30, height: 18),
        font: .systemFont(ofSize: 9), color: oxblood, in: context)
      context.endPDFPage()
      page += 1
    } while offset < content.length
    context.closePDF()
  }

  private static func draw(
    _ text: String, rect: CGRect, font: NSFont, color: NSColor,
    lineSpacing: CGFloat = 0, in context: CGContext
  ) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = lineSpacing
    let string = NSAttributedString(
      string: text,
      attributes: [
        .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
      ])
    let frame = CTFramesetterCreateFrame(
      CTFramesetterCreateWithAttributedString(string),
      CFRange(location: 0, length: 0),
      CGPath(rect: rect, transform: nil), nil
    )
    CTFrameDraw(frame, context)
  }
}
