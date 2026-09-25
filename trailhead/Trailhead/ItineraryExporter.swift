import PDFKit
import SwiftUI
import UIKit

struct ExportDocument: Identifiable {
  let id = UUID()
  let url: URL
}

@MainActor
enum ItineraryExporter {
  static func create(trip: Trip, trail: Trail) throws -> ExportDocument {
    let directory = URL.documentsDirectory.appending(path: "Itineraries")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appending(path: "Trailhead-\(trail.id)-\(trip.id.uuidString.prefix(8)).pdf")
    let pageSize = CGSize(width: 595, height: 842)
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
    let ink = UIColor(red: 0.13, green: 0.25, blue: 0.20, alpha: 1)
    let paper = UIColor(red: 0.95, green: 0.94, blue: 0.88, alpha: 1)
    let data = renderer.pdfData { context in
      var y: CGFloat = 42
      var page = 0
      var section = ""
      func beginPage() {
        context.beginPage()
        page += 1
        paper.setFill()
        context.fill(CGRect(origin: .zero, size: pageSize))
        y = 42
        ("TRAILHEAD / FIELD ITINERARY                                        \(page)" as NSString)
          .draw(
            at: CGPoint(x: 40, y: 807),
            withAttributes: [
              .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .regular),
              .foregroundColor: ink,
            ])
      }
      func text(_ value: String, size: CGFloat = 12, serif: Bool = false) {
        let font: UIFont
        if serif, let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor.withDesign(.serif)
        {
          font = UIFont(descriptor: descriptor, size: size)
        } else {
          font = UIFont.systemFont(ofSize: size)
        }
        let attrs: [NSAttributedString.Key: NSObject] = [.font: font, .foregroundColor: ink]
        let rect = (value as NSString).boundingRect(
          with: CGSize(width: 515, height: CGFloat.greatestFiniteMagnitude),
          options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        if y + rect.height > 775 {
          beginPage()
          if !section.isEmpty {
            ("\(section) / CONTINUED" as NSString).draw(
              at: CGPoint(x: 40, y: y),
              withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: ink,
              ])
            y += 30
          }
        }
        (value as NSString).draw(
          in: CGRect(x: 40, y: y, width: 515, height: ceil(rect.height) + 3), withAttributes: attrs)
        y += ceil(rect.height) + 12
      }
      beginPage()
      text("THE OUTSIDE IS CALLING", size: 10)
      text(trip.name, size: 30, serif: true)
      text("\(trail.region)  /  \(trail.difficulty.uppercased())", size: 10)
      text(
        String(
          format: "%.1f km  •  %.0f m ascent  •  %@ moving time", trail.distance, trail.ascent,
          trail.duration), size: 14)
      let image = ImageRenderer(
        content: TopoArtwork(trail: trail, fraction: 0.5, waypoints: trip.waypoints).frame(
          width: 515, height: 240))
      image.scale = 2
      if let uiImage = image.uiImage {
        uiImage.draw(in: CGRect(x: 40, y: y, width: 515, height: 240))
        y += 257
      }
      text(trail.description)
      func heading(_ title: String) {
        if y + 100 > 775 { beginPage() }
        section = title
        text(title, size: 15, serif: true)
      }
      heading("WAYPOINTS")
      for (index, waypoint) in trip.waypoints.enumerated() {
        let point = trail.point(at: waypoint.fraction)
        text(
          String(
            format: "%02d  %@  —  %.2f km / %.0f m\n      %.5f, %.5f",
            index + 1, waypoint.name, trail.distance * waypoint.fraction, point.elevation,
            point.latitude, point.longitude))
      }
      heading("PACKING LIST")
      for item in trip.gear {
        text("\(item.packed ? "[PACKED]" : "[      ]")  \(item.name)")
      }
      heading("PLANNING NOTES")
      text(
        "Moving time uses 4 km/h plus 1 hour per 600 m ascent; breaks, weather, terrain and descent difficulty are not included. Carry water, layers and appropriate navigation."
      )
      text(
        "ILLUSTRATIVE DEMO — NOT FOR NAVIGATION. Route coordinates and elevations are authored fixtures, not surveyed trails. Contours and water features are decorative and do not represent actual terrain. Verify conditions and use authoritative maps for real trips.",
        size: 10)
    }
    try data.write(to: url, options: .atomic)
    return ExportDocument(url: url)
  }
}

struct NativePDF: UIViewRepresentable {
  let url: URL
  func makeUIView(context: Context) -> PDFView {
    let view = PDFView()
    view.autoScales = true
    view.displayDirection = .vertical
    view.document = PDFDocument(url: url)
    view.backgroundColor = UIColor(Field.paper)
    return view
  }
  func updateUIView(_ uiView: PDFView, context: Context) {}
}

struct PDFPreview: View {
  @Environment(\.dismiss) private var dismiss
  let document: ExportDocument
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        NativePDF(url: document.url)
        VStack(spacing: 10) {
          Text("Saved on device · Documents / Itineraries")
            .font(.system(size: 10)).foregroundStyle(Field.muted)
          ShareLink(item: document.url) {
            Label("Share itinerary PDF", systemImage: "square.and.arrow.up")
              .font(.system(size: 14, weight: .semibold))
              .frame(maxWidth: .infinity).frame(height: 48)
              .background(Field.ink, in: RoundedRectangle(cornerRadius: 13)).foregroundStyle(
                Field.paper)
          }.accessibilityIdentifier("sharePDF")
        }.padding(20).background(Field.paper)
      }
      .navigationTitle("Your itinerary").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }.tint(Field.ink)
  }
}
