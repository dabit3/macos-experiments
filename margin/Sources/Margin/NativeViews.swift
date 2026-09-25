import AppKit
import MarginCore
import PDFKit
import SwiftUI

struct SourceReader: NSViewRepresentable {
  @ObservedObject var workspace: Workspace

  func makeNSView(context: Context) -> PDFView {
    let view = PDFView()
    view.document = workspace.source
    view.displayMode = .singlePageContinuous
    view.displayDirection = .vertical
    view.autoScales = true
    view.displaysPageBreaks = true
    view.pageBreakMargins = NSEdgeInsets(top: 20, left: 22, bottom: 20, right: 22)
    view.backgroundColor = NSColor(calibratedRed: 0.90, green: 0.89, blue: 0.86, alpha: 1)
    view.setAccessibilityLabel("Source PDF: The attentive city")
    workspace.pdfView = view
    workspace.refreshAnnotations()
    context.coordinator.connect(view)
    return view
  }

  func updateNSView(_ nsView: PDFView, context: Context) {}
  func makeCoordinator() -> Coordinator { Coordinator(workspace) }

  @MainActor
  final class Coordinator: NSObject {
    let workspace: Workspace

    init(_ workspace: Workspace) { self.workspace = workspace }

    func connect(_ view: PDFView) {
      NotificationCenter.default.addObserver(
        self, selector: #selector(selectionChanged),
        name: .PDFViewSelectionChanged, object: view
      )
      NotificationCenter.default.addObserver(
        self, selector: #selector(pageChanged),
        name: .PDFViewPageChanged, object: view
      )
    }

    @objc func selectionChanged(_ notification: Notification) {
      guard let view = notification.object as? PDFView else { return }
      workspace.selectedText = view.currentSelection?.string ?? ""
    }

    @objc func pageChanged(_ notification: Notification) {
      guard let view = notification.object as? PDFView, let page = view.currentPage else { return }
      workspace.currentPage = workspace.source.index(for: page) + 1
    }

    deinit { NotificationCenter.default.removeObserver(self) }
  }
}

struct DraftEditor: NSViewRepresentable {
  @ObservedObject var workspace: Workspace

  func makeNSView(context: Context) -> NSScrollView {
    let scroll = NSScrollView()
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true
    scroll.drawsBackground = false
    let editor = NSTextView()
    editor.isRichText = false
    editor.isAutomaticQuoteSubstitutionEnabled = false
    editor.isAutomaticDashSubstitutionEnabled = false
    editor.isContinuousSpellCheckingEnabled = true
    editor.allowsUndo = true
    editor.isVerticallyResizable = true
    editor.isHorizontallyResizable = false
    editor.autoresizingMask = [.width]
    editor.textContainer?.widthTracksTextView = true
    editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
    editor.textContainerInset = NSSize(width: 27, height: 18)
    editor.font = NSFont(name: "Georgia", size: 16)
    editor.textColor = NSColor(Theme.ink)
    editor.backgroundColor = NSColor(Theme.paper)
    editor.insertionPointColor = NSColor(Theme.wine)
    editor.selectedTextAttributes = [.backgroundColor: NSColor(Theme.wine).withAlphaComponent(0.17)]
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 7
    paragraph.paragraphSpacing = 5
    editor.defaultParagraphStyle = paragraph
    editor.typingAttributes = [
      .font: NSFont(name: "Georgia", size: 16)!,
      .foregroundColor: NSColor(Theme.ink),
      .paragraphStyle: paragraph,
    ]
    editor.string = workspace.project.draft
    editor.delegate = context.coordinator
    editor.setAccessibilityIdentifier("draft-editor")
    editor.setAccessibilityLabel("Research brief draft")
    scroll.documentView = editor
    workspace.editor = editor
    return scroll
  }

  func updateNSView(_ scroll: NSScrollView, context: Context) {
    guard let editor = scroll.documentView as? NSTextView else { return }
    if editor.string != workspace.project.draft {
      editor.string = workspace.project.draft
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator(workspace) }

  @MainActor
  final class Coordinator: NSObject, NSTextViewDelegate {
    let workspace: Workspace
    init(_ workspace: Workspace) { self.workspace = workspace }

    func textDidChange(_ notification: Notification) {
      guard let editor = notification.object as? NSTextView else { return }
      workspace.project.draft = editor.string
    }
  }
}
