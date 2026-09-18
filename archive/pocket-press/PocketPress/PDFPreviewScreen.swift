import PDFKit
import SwiftUI

struct ExportedIssue: Identifiable {
    var id = UUID()
    let url: URL
    let title: String
}

@MainActor
final class PDFReaderController: NSObject, ObservableObject {
    let view = PDFView()
    @Published var page = 1
    @Published var count = 0
    @Published var failed = false

    func open(_ url: URL) {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            failed = true
            return
        }
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.usePageViewController(true, withViewOptions: nil)
        view.document = document
        view.autoScales = true
        view.backgroundColor = UIColor(hex: 0xDDDCD4)
        view.pageShadowsEnabled = true
        count = document.pageCount
        NotificationCenter.default.removeObserver(self, name: .PDFViewPageChanged, object: view)
        NotificationCenter.default.addObserver(
            self, selector: #selector(pageChanged), name: .PDFViewPageChanged, object: view)
    }

    @objc private func pageChanged() {
        guard let current = view.currentPage, let document = view.document else { return }
        page = document.index(for: current) + 1
    }

    func step(_ offset: Int) {
        guard let document = view.document,
            let target = document.page(at: max(0, min(count - 1, page - 1 + offset)))
        else { return }
        view.go(to: target)
    }

}

struct PDFCanvas: UIViewRepresentable {
    let controller: PDFReaderController
    func makeUIView(context: Context) -> PDFView { controller.view }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

struct PDFPreviewScreen: View {
    let export: ExportedIssue
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = PDFReaderController()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 9) {
                    Eyebrow(text: "Fresh off the press")
                    Text("A place, on paper.").font(PressStyle.serif(30)).tracking(-1)
                    Text("PDF · \(controller.count) pages · saved to Files")
                        .font(PressStyle.sans(12)).foregroundStyle(PressStyle.muted)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(
                    .vertical, 17)
                if controller.failed {
                    ContentUnavailableView(
                        "Couldn’t open this PDF", systemImage: "doc",
                        description: Text("Close this preview and export the issue again."))
                } else {
                    PDFCanvas(controller: controller)
                        .accessibilityLabel("Exported PDF document")
                }
                HStack {
                    Button {
                        controller.step(-1)
                    } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 46)
                    }.disabled(controller.page <= 1).accessibilityLabel("Previous PDF page")
                    Text("\(controller.page) / \(controller.count)").font(PressStyle.sans(12, bold: true))
                    Button {
                        controller.step(1)
                    } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 46)
                    }.disabled(controller.page >= controller.count).accessibilityLabel("Next PDF page")
                    Spacer()
                    ShareLink(item: export.url) {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                            .font(PressStyle.sans(13, bold: true))
                    }.disabled(controller.failed)
                }.padding(.horizontal, 15).padding(.vertical, 6)
            }.background(PressStyle.paper)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Eyebrow(text: "Pocket Press", color: PressStyle.ink)
                    }
                    ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                }
                .onAppear { controller.open(export.url) }
        }
    }
}
