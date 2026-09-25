import AppKit
import Combine
import MarginCore
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class Workspace: ObservableObject {
  @Published var project: Project {
    didSet { if ready { autosave() } }
  }
  @Published var searchQuery = ""
  @Published var libraryQuery = ""
  @Published var searchCount = 0
  @Published var searchIndex = 0
  @Published var hasSearched = false
  @Published var selectedText = ""
  @Published var currentPage = 1
  @Published var status = "All changes saved on this Mac"
  @Published var errorMessage: String?
  @Published var showReset = false
  @Published var undoClippings: [[Excerpt]] = []
  @Published var activeExcerpt: UUID?
  var pdfView: PDFView?
  weak var editor: NSTextView?
  let source: PDFDocument
  let autosaveURL: URL
  private var ready = false
  private var searchResults: [PDFSelection] = []
  private var saveURL: URL?

  init() {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[
      0
    ]
    .appendingPathComponent("Margin", isDirectory: true)
    autosaveURL = support.appendingPathComponent("Workspace.margin")
    project = .sample
    let sourceURL = Bundle.main.resourceURL?.appendingPathComponent("The Attentive City.pdf")
    source = sourceURL.flatMap(PDFDocument.init(url:)) ?? PDFDocument()
    do {
      try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: autosaveURL.path) {
        project = try Project.decode(Data(contentsOf: autosaveURL))
        status = "Workspace restored · saved on this Mac"
      }
    } catch {
      errorMessage = "Could not restore the local workspace: \(error.localizedDescription)"
    }
    if source.pageCount == 0 {
      errorMessage = "The bundled source PDF is missing. Rebuild Margin with scripts/build.sh."
    }
    ready = true
  }

  func autosave() {
    do {
      try project.encoded().write(to: autosaveURL, options: .atomic)
      status = "All changes saved on this Mac"
    } catch {
      status = "Autosave failed — use Save project"
    }
  }

  func search() {
    let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    searchResults = query.isEmpty ? [] : source.findString(query, withOptions: .caseInsensitive)
    searchCount = searchResults.count
    searchIndex = 0
    hasSearched = !query.isEmpty
    pdfView?.highlightedSelections = searchResults.map {
      let selection = $0.copy() as! PDFSelection
      selection.color = NSColor.systemYellow.withAlphaComponent(0.32)
      return selection
    }
    if !searchResults.isEmpty { showSearchResult(0) }
  }

  func showSearchResult(_ index: Int) {
    guard !searchResults.isEmpty else { return }
    searchIndex = (index + searchResults.count) % searchResults.count
    let selection = searchResults[searchIndex]
    pdfView?.setCurrentSelection(selection, animate: true)
    pdfView?.go(to: selection)
    selectedText = selection.string ?? ""
  }

  func movePage(_ delta: Int) {
    let target = min(max(currentPage - 1 + delta, 0), source.pageCount - 1)
    guard let page = source.page(at: target) else { return }
    pdfView?.go(to: page)
  }

  func capture() {
    guard let selection = pdfView?.currentSelection,
      let raw = selection.string
    else { return }
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    let spans = selection.selectionsByLine().flatMap { line in
      line.pages.map { page in
        let rect = line.bounds(for: page)
        return PassageRect(
          page: source.index(for: page), x: rect.minX, y: rect.minY,
          width: rect.width, height: rect.height
        )
      }
    }
    guard !spans.isEmpty else { return }
    let excerpt = Excerpt(text: text, spans: spans)
    guard !project.excerpts.contains(where: { $0.text == text && $0.pages == excerpt.pages }) else {
      status = "That passage is already in your collection"
      return
    }
    undoClippings.append(project.excerpts)
    project.excerpts.append(excerpt)
    activeExcerpt = excerpt.id
    refreshAnnotations()
    status = "Passage collected · page \(excerpt.pageLabel)"
  }

  func remove(_ excerpt: Excerpt) {
    undoClippings.append(project.excerpts)
    project.excerpts.removeAll { $0.id == excerpt.id }
    refreshAnnotations()
    status = "Passage removed · Undo is available"
  }

  func undoClipping() {
    guard let previous = undoClippings.popLast() else { return }
    project.excerpts = previous
    refreshAnnotations()
    status = "Collection change undone"
  }

  func show(_ excerpt: Excerpt) {
    activeExcerpt = excerpt.id
    guard let span = excerpt.spans.first, let page = source.page(at: span.page) else { return }
    pdfView?.go(to: CGRect(x: span.x, y: span.y, width: span.width, height: span.height), on: page)
  }

  func insert(_ excerpt: Excerpt) {
    let text = "\n\n" + excerpt.citedText + "\n"
    if let editor {
      editor.window?.makeFirstResponder(editor)
      editor.insertText(text, replacementRange: editor.selectedRange())
      editor.scrollRangeToVisible(editor.selectedRange())
    } else {
      project.draft += text
    }
    status = "Cited passage inserted · page \(excerpt.pageLabel)"
  }

  func refreshAnnotations() {
    for pageIndex in 0..<source.pageCount {
      guard let page = source.page(at: pageIndex) else { continue }
      for annotation in page.annotations where annotation.userName == "Margin" {
        page.removeAnnotation(annotation)
      }
    }
    for excerpt in project.excerpts {
      for span in excerpt.spans {
        let annotation = PDFAnnotation(
          bounds: CGRect(x: span.x, y: span.y, width: span.width, height: span.height),
          forType: .highlight, withProperties: nil
        )
        annotation.color = NSColor(calibratedRed: 0.65, green: 0.25, blue: 0.28, alpha: 0.24)
        annotation.userName = "Margin"
        annotation.contents = excerpt.citation
        source.page(at: span.page)?.addAnnotation(annotation)
      }
    }
  }

  func saveProject() {
    let panel = NSSavePanel()
    panel.title = "Save Margin project"
    panel.nameFieldStringValue = saveURL?.lastPathComponent ?? "Attentive City.margin"
    panel.allowedContentTypes = [UTType(exportedAs: "studio.margin.project", conformingTo: .json)]
    panel.canCreateDirectories = true
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try project.encoded().write(to: url, options: .atomic)
      saveURL = url
      status = "Project saved · \(url.lastPathComponent)"
    } catch { errorMessage = error.localizedDescription }
  }

  func openProject() {
    let panel = NSOpenPanel()
    panel.title = "Open Margin project"
    panel.allowedContentTypes = [.data]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let opened = try Project.decode(Data(contentsOf: url))
      project = opened
      saveURL = url
      undoClippings = []
      activeExcerpt = nil
      editor?.undoManager?.removeAllActions()
      refreshAnnotations()
      status = "Opened · \(url.lastPathComponent)"
    } catch { errorMessage = error.localizedDescription }
  }

  func export(pdf: Bool) {
    let panel = NSSavePanel()
    panel.title = pdf ? "Export research brief as PDF" : "Export research brief as Markdown"
    panel.nameFieldStringValue = "Margin Brief.\(pdf ? "pdf" : "md")"
    panel.allowedContentTypes = pdf ? [.pdf] : [.plainText]
    panel.canCreateDirectories = true
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      if pdf {
        let temporary = url.deletingLastPathComponent()
          .appendingPathComponent(".margin-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try PDFRenderer.export(project, to: temporary)
        try Data(contentsOf: temporary).write(to: url, options: .atomic)
      } else {
        try project.markdown.write(to: url, atomically: true, encoding: .utf8)
      }
      status = "Exported \(pdf ? "PDF" : "Markdown") · \(url.lastPathComponent)"
    } catch { errorMessage = error.localizedDescription }
  }

  func resetSample() {
    project = .sample
    undoClippings = []
    activeExcerpt = nil
    searchQuery = ""
    libraryQuery = ""
    search()
    editor?.undoManager?.removeAllActions()
    refreshAnnotations()
    movePage(1 - currentPage)
    saveURL = nil
    status = "Fresh sample workspace · saved on this Mac"
  }
}
