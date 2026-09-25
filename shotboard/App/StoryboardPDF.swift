import PDFKit
import SwiftUI
import UIKit

struct ExportedPDF: Identifiable {
  let id = UUID()
  let url: URL
}

enum StoryboardPDF {
  static func export(_ project: Storyboard) throws -> URL {
    let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Exports")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let safeTitle = project.title.components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }.joined(separator: "-")
    let url = folder.appendingPathComponent(
      "\(safeTitle.isEmpty ? "Storyboard" : safeTitle)-\(project.id.uuidString.prefix(8)).pdf")
    let page = CGRect(x: 0, y: 0, width: 842, height: 595)
    let format = UIGraphicsPDFRendererFormat()
    format.documentInfo = [
      kCGPDFContextTitle as String: project.title,
      kCGPDFContextCreator as String: "Shotboard",
      kCGPDFContextSubject as String:
        "Ordered storyboard · \(project.shots.count) shots · \(project.runtimeLabel)",
    ]
    let renderer = UIGraphicsPDFRenderer(bounds: page, format: format)
    try renderer.writePDF(to: url) { document in
      for (index, shot) in project.shots.enumerated() {
        document.beginPage()
        let context = document.cgContext
        context.setFillColor(UIColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1).cgColor)
        context.fill(page)
        text(
          "SHOTBOARD  /  PRODUCTION STORYBOARD", at: CGRect(x: 34, y: 25, width: 650, height: 20),
          size: 9, mono: true)
        text(project.title, at: CGRect(x: 34, y: 49, width: 690, height: 34), size: 25, serif: true)
        text(
          String(format: "%02d", index + 1), at: CGRect(x: 738, y: 32, width: 70, height: 50),
          size: 40, mono: true)
        let maxFrame = CGRect(x: 34, y: 105, width: 534, height: 353)
        let width = min(maxFrame.width, maxFrame.height * shot.ratio.value)
        let height = width / shot.ratio.value
        let frame = CGRect(
          x: maxFrame.midX - width / 2, y: maxFrame.midY - height / 2, width: width, height: height)
        InkRenderer.draw(shot.strokes, in: frame, context: context)
        context.setStrokeColor(InkColor.shadow.uiColor.cgColor)
        context.setLineWidth(0.5)
        context.stroke(frame)
        let scene = project.scenes.first { $0.id == shot.sceneID }
        text(
          scene?.location ?? "", at: CGRect(x: 594, y: 108, width: 214, height: 35), size: 9,
          mono: true)
        text(shot.title, at: CGRect(x: 594, y: 147, width: 214, height: 70), size: 22, serif: true)
        text(
          "\(scene?.title ?? "")\n\n\(shot.size.rawValue)  /  \(shot.movement.rawValue)\n\(shot.duration) seconds  /  \(shot.ratio.rawValue)",
          at: CGRect(x: 594, y: 230, width: 214, height: 130), size: 12)
        text(
          "DIRECTOR'S NOTES", at: CGRect(x: 34, y: 473, width: 700, height: 16), size: 9, mono: true
        )
        let hasExtendedNotes =
          shot.notes.count > 380 || shot.notes.components(separatedBy: "\n").count > 3
        text(
          hasExtendedNotes ? "Full director's notes on the following page." : shot.notes,
          at: CGRect(x: 34, y: 494, width: 774, height: 60), size: 11)
        text(
          "SHOT \(String(format: "%02d", index + 1)) OF \(String(format: "%02d", project.shots.count))  ·  TOTAL RUNTIME \(project.runtimeLabel)",
          at: CGRect(x: 34, y: 566, width: 774, height: 16), size: 9, mono: true)
        if hasExtendedNotes {
          document.beginPage()
          context.setFillColor(UIColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1).cgColor)
          context.fill(page)
          text(
            "SHOT \(String(format: "%02d", index + 1)) / DIRECTOR'S NOTES",
            at: CGRect(x: 34, y: 30, width: 774, height: 22), size: 10, mono: true)
          text(shot.title, at: CGRect(x: 34, y: 70, width: 774, height: 65), size: 25, serif: true)
          text(shot.notes, at: CGRect(x: 34, y: 155, width: 774, height: 395), size: 13)
        }
      }
    }
    return url
  }

  private static func text(
    _ value: String, at rect: CGRect, size: CGFloat, mono: Bool = false, serif: Bool = false
  ) {
    var font: UIFont
    if mono {
      font = .monospacedSystemFont(ofSize: size, weight: .medium)
    } else if serif {
      font = UIFont(name: "Georgia", size: size) ?? .systemFont(ofSize: size)
    } else {
      font = .systemFont(ofSize: size)
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = 3
    while font.pointSize > 8 {
      let bounds = (value as NSString).boundingRect(
        with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: font, .paragraphStyle: paragraph], context: nil)
      if bounds.height <= rect.height { break }
      font = font.withSize(font.pointSize - 0.5)
    }
    (value as NSString).draw(
      in: rect,
      withAttributes: [
        .font: font, .foregroundColor: InkColor.graphite.uiColor, .paragraphStyle: paragraph,
      ])
  }
}

struct PDFPreview: View {
  let export: ExportedPDF
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      NativePDF(url: export.url)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          Label("Saved in On My iPad → Shotboard → Exports", systemImage: "checkmark.circle")
            .font(.system(size: 12)).foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity).padding(.vertical, 14).background(Palette.panel)
        }
        .navigationTitle("Production storyboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
          ToolbarItem(placement: .topBarTrailing) {
            ShareLink(item: export.url) { Label("Share PDF", systemImage: "square.and.arrow.up") }
          }
        }
    }
  }
}

struct NativePDF: UIViewRepresentable {
  let url: URL
  func makeUIView(context: Context) -> PDFView {
    let view = PDFView()
    view.document = PDFDocument(url: url)
    view.autoScales = true
    view.displayDirection = .vertical
    view.displayMode = .singlePageContinuous
    return view
  }
  func updateUIView(_ view: PDFView, context: Context) {}
}
