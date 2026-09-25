import SwiftUI
import UIKit

struct ExportFile: Identifiable {
  let id = UUID()
  let url: URL
}

struct ExportView: View {
  @Environment(\.dismiss) private var dismiss
  let file: ExportFile
  let preview: UIImage?
  let dimensions: CGSize
  @State private var showShare = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          Eyebrow(text: "From negative to keepsake").padding(.top, 22)
          Text("Worth keeping.")
            .font(.system(size: 36, design: .serif)).foregroundStyle(Palette.silver)
          if let preview {
            Image(uiImage: preview).resizable().scaledToFit()
              .frame(maxHeight: 320).padding(10).background(Palette.silver)
              .rotationEffect(.degrees(-2))
              .padding(.horizontal, 35).padding(.vertical, 10)
              .accessibilityLabel("Your finished photograph")
          }
          VStack(spacing: 10) {
            Text("Your photograph is developed.")
              .font(.system(.title3, design: .serif)).foregroundStyle(Palette.silver)
            Text("\(Int(dimensions.width)) × \(Int(dimensions.height))  /  JPEG  /  sRGB")
              .font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.amber)
            Text("Full resolution. No watermark.\nShare it, or save it to Photos or Files.")
              .font(.subheadline).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
              .lineSpacing(4)
          }
          Button {
            showShare = true
          } label: {
            Label("Share photograph", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
          }
          .buttonStyle(AmberButton())
          Text("Your original and editing recipe stay in Silverroom.")
            .font(.caption).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        }
        .padding(26)
      }
      .background(Palette.background)
      .navigationTitle("Export").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
      .sheet(isPresented: $showShare) { ShareSheet(url: file.url) }
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
