import AppKit
import Foundation
import PDFKit

public struct Fixture: Codable, Sendable {
  public let name: String
  public let text: String
}

public struct EvaluationCase: Decodable, Sendable {
  public let id: String
  public let query: String
  public let text: String
  public let accept: Bool
}

public enum Fixtures {
  public static func heldOut() throws -> [EvaluationCase] {
    guard let url = Bundle.module.url(forResource: "HeldOut", withExtension: "json") else {
      throw FinderError("Held-out evaluation resource is missing.")
    }
    return try JSONDecoder().decode([EvaluationCase].self, from: Data(contentsOf: url))
  }

  public static func vault() throws -> [Fixture] {
    guard let url = Bundle.module.url(forResource: "Vault", withExtension: "json") else {
      throw FinderError("Demo vault resource is missing.")
    }
    return try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
  }

  @MainActor
  public static func write(to folder: URL) throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for fixture in try vault() {
      let url = folder.appendingPathComponent(fixture.name)
      switch url.pathExtension {
      case "pdf":
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data),
          let context = CGContext(consumer: consumer, mediaBox: nil, nil)
        else { throw FinderError("Cannot create fixture PDF.") }
        context.beginPDFPage([kCGPDFContextMediaBox as String: NSValue(rect: page)] as CFDictionary)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        (fixture.text as NSString).draw(
          in: CGRect(x: 48, y: 60, width: 516, height: 680),
          withAttributes: [.font: NSFont.systemFont(ofSize: 12), .paragraphStyle: style])
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
        try (data as Data).write(to: url)
      case "rtf":
        let attributed = NSAttributedString(
          string: fixture.text, attributes: [.font: NSFont.systemFont(ofSize: 13)])
        guard
          let data = attributed.rtf(
            from: NSRange(location: 0, length: attributed.length), documentAttributes: [:])
        else { throw FinderError("Cannot create fixture RTF.") }
        try data.write(to: url)
      default:
        try fixture.text.write(to: url, atomically: true, encoding: .utf8)
      }
    }
  }
}
