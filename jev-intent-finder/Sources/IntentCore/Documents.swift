import AppKit
import CryptoKit
import Foundation
import PDFKit

public struct FinderError: LocalizedError, Sendable {
  public let message: String
  public init(_ message: String) { self.message = message }
  public var errorDescription: String? { message }
}

public struct FileStamp: Equatable, Sendable {
  public let inode: UInt64
  public let device: UInt64
  public let size: UInt64
  public let modified: Date
  public let digest: String

  public static func read(_ url: URL) throws -> FileStamp {
    let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
    guard attrs[.type] as? FileAttributeType == .typeRegular,
      let inode = attrs[.systemFileNumber] as? UInt64,
      let device = attrs[.systemNumber] as? UInt64,
      let size = attrs[.size] as? UInt64,
      let modified = attrs[.modificationDate] as? Date
    else { throw FinderError("File is missing, a symlink, or not a regular document.") }
    guard size <= 2_000_000 else { throw FinderError("Larger than the 2 MB extraction limit.") }
    let data = try Data(contentsOf: url)
    return FileStamp(
      inode: inode, device: device, size: size, modified: modified,
      digest: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
  }
}

public struct Document: Identifiable, Sendable {
  public var id: String { url.path }
  public let url: URL
  public let stamp: FileStamp
  public let text: String
  public let extraction: String
  public let complete: Bool
  public var name: String { url.lastPathComponent }

  public func verify() throws {
    guard try FileStamp.read(url) == stamp else {
      throw FinderError("“\(name)” changed since this search. Search again before acting.")
    }
    guard url.resolvingSymlinksInPath().standardizedFileURL == url.standardizedFileURL else {
      throw FinderError("The document path now resolves through a symbolic link.")
    }
  }
}

public struct Scan: Sendable {
  public let documents: [Document]
  public let notices: [String]
}

public enum Documents {
  public static let extensions = Set(["txt", "md", "rtf", "pdf"])
  public static let limit = 120

  public static func scan(_ folder: URL) throws -> Scan {
    let root = folder.resolvingSymlinksInPath().standardizedFileURL
    guard
      let enumerator = FileManager.default.enumerator(
        at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants])
    else { throw FinderError("Cannot read the chosen folder.") }
    var urls: [URL] = []
    var notices: [String] = []
    var visited = 0
    for case let url as URL in enumerator {
      visited += 1
      if visited > 2_000 {
        notices.append(
          "Scope capped at 2,000 visited entries. Choose a smaller folder for full coverage.")
        break
      }
      let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
      if values.isSymbolicLink == true {
        enumerator.skipDescendants()
        continue
      }
      if values.isRegularFile == true, extensions.contains(url.pathExtension.lowercased()) {
        urls.append(url)
      }
    }
    urls.sort { $0.path < $1.path }
    if urls.count > limit {
      notices.append(
        "Only the first \(limit) of \(urls.count) eligible files are evaluated. Narrow the scope.")
    }
    var docs: [Document] = []
    for url in urls.prefix(limit) {
      do { docs.append(try extract(url)) } catch {
        notices.append("\(url.lastPathComponent): \(error.localizedDescription)")
      }
    }
    if docs.isEmpty {
      notices.append("No readable txt, md, rtf or text PDF documents in this scope.")
    }
    return Scan(documents: docs, notices: notices)
  }

  public static func extract(_ url: URL) throws -> Document {
    let before = try FileStamp.read(url)
    let text: String
    var complete = true
    var method = "UTF-8 text"
    switch url.pathExtension.lowercased() {
    case "pdf":
      guard let pdf = PDFDocument(url: url), !pdf.isLocked else {
        throw FinderError("PDF is locked or unreadable.")
      }
      method = "PDFKit · \(pdf.pageCount) pages"
      var pages: [String] = []
      for index in 0..<min(pdf.pageCount, 100) {
        let page = pdf.page(at: index)?.string ?? ""
        if page.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { complete = false }
        pages.append(page)
      }
      complete = complete && pdf.pageCount <= 100
      text = pages.joined(separator: "\n\n")
    case "rtf":
      let data = try Data(contentsOf: url)
      guard let attributed = NSAttributedString(rtf: data, documentAttributes: nil) else {
        throw FinderError("RTF text could not be extracted.")
      }
      text = attributed.string
      method = "AppKit · rich text"
    case "txt", "md":
      text = try String(contentsOf: url, encoding: .utf8)
    default:
      throw FinderError("Unsupported format.")
    }
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw FinderError("No extractable text. Scans and images need OCR; OCR is not enabled.")
    }
    if text.count > 14_000 { complete = false }
    guard try FileStamp.read(url) == before else { throw FinderError("Changed during extraction.") }
    return Document(
      url: url, stamp: before, text: String(text.prefix(14_000)),
      extraction: method + (complete ? " · complete" : " · PARTIAL (manual review)"),
      complete: complete)
  }

  public static func filenameOverlap(query: String, document: Document) -> Int {
    func tokens(_ value: String) -> Set<String> {
      Set(value.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
    }
    return tokens(query).intersection(tokens(document.name)).count
  }
}

public struct SearchIdentity: Equatable, Sendable {
  public let generation: UUID
  public let query: String
  public init(generation: UUID, query: String) {
    self.generation = generation
    self.query = query
  }

  public func validate(current: SearchIdentity) throws {
    guard self == current else {
      throw FinderError("This search is stale. Run the current intent again.")
    }
  }
}
