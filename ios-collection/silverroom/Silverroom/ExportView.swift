import SwiftUI
import UIKit

struct ExportFile: Identifiable {
  let id = UUID()
  let url: URL
}

struct ExportView: View {
  @Environment(\.dismiss) private var dismiss
  let file: ExportFile
  @State private var preview: UIImage?
  @State private var dimensions: CGSize = .zero
  @State private var fileSize = ""
  @State private var showShare = false
  @State private var error: String?

  var body: some View {
    VStack(spacing: 0) {
      SheetHeader(title: "Export") { dismiss() }
      ScrollView {
        VStack(spacing: 20) {
          if let preview {
            Image(uiImage: preview).resizable().scaledToFit()
              .frame(maxWidth: .infinity).frame(maxHeight: 380)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
              .accessibilityLabel("Exported photo")
          } else if let error {
            Text(error).font(TypeStyle.body).foregroundStyle(Palette.muted)
          } else {
            ProgressView().tint(Palette.ink).frame(maxWidth: .infinity, minHeight: 240)
          }
          VStack(spacing: 4) {
            Text(
              dimensions == .zero
                ? "Full resolution" : "\(Int(dimensions.width)) × \(Int(dimensions.height))"
            )
            .font(TypeStyle.heading).monospacedDigit()
            Text("JPEG · sRGB" + (fileSize.isEmpty ? "" : " · \(fileSize)"))
              .font(TypeStyle.caption).foregroundStyle(Palette.muted).monospacedDigit()
          }
          .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 20).padding(.top, 8)
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      Button {
        showShare = true
      } label: {
        Label("Save or share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
      }
      .buttonStyle(PrimaryButton())
      .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 12)
    }
    .foregroundStyle(Palette.ink).presentationBackground(Palette.background)
    .presentationDragIndicator(.visible)
    .sheet(isPresented: $showShare) { ShareSheet(url: file.url) }
    .task {
      let url = file.url
      do {
        let result = try await Task.detached(priority: .userInitiated) {
          let data = try Data(contentsOf: url)
          let engine = ImageEngine()
          return (
            try engine.render(data, settings: EditSettings(), maxPixel: 1000),
            try engine.dimensions(data, settings: EditSettings()),
            ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
          )
        }.value
        preview = result.0
        dimensions = result.1
        fileSize = result.2
      } catch { self.error = error.localizedDescription }
    }
  }

}

struct ShareSheet: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [url], applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
