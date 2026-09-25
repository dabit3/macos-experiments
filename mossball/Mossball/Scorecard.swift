import LinkPresentation
import SwiftUI
import UIKit

struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let text: String
}

struct ShareSheet: UIViewControllerRepresentable {
    let payload: SharePayload
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let configuration = UIActivityItemsConfiguration(objects: [payload.image])
        configuration.metadataProvider = { key in
            switch key {
            case .title, .messageBody: return payload.text
            default: return nil
            }
        }
        configuration.perItemMetadataProvider = { _, key in
            guard key == .linkPresentationMetadata else { return nil }
            let metadata = LPLinkMetadata()
            metadata.title = payload.text
            metadata.imageProvider = NSItemProvider(object: payload.image)
            return metadata
        }
        return UIActivityViewController(activityItemsConfiguration: configuration)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@MainActor
enum ScorecardRenderer {
    static func hole(game: GameStore) -> SharePayload? {
        let card = ShareCard(
            title: game.resultTitle, subtitle: "\(game.hole.name) · \(game.resultLabel.lowercased())",
            score: "\(game.simulation.strokes)", detail: "\(game.strokeNoun.uppercased())  /  PAR \(game.hole.par)",
            simulation: game.simulation, record: nil, practice: game.practice)
        return render(
            card,
            text:
                "Mossball — \(game.hole.name): \(game.simulation.strokes) \(game.strokeNoun), par \(game.hole.par).\(game.practice ? " Practice round." : "") A little golf. A little wild."
        )
    }

    static func course(record: CourseRecord) -> SharePayload? {
        let card = ShareCard(
            title: "Well wandered.", subtitle: "The overgrown nine",
            score: "\(record.total)", detail: record.caption.uppercased(),
            simulation: GolfSimulation(hole: Hole.course[8]), record: record, practice: false)
        return render(
            card,
            text:
                "Mossball — \(record.total) strokes across nine gardens (\(record.caption)).\(record.finished ? "" : " Includes stroke-limit holes.")"
        )
    }

    private static func render(_ card: ShareCard, text: String) -> SharePayload? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        guard let image = renderer.uiImage else { return nil }
        return SharePayload(image: image, text: text)
    }
}

private struct ShareCard: View {
    let title: String
    let subtitle: String
    let score: String
    let detail: String
    let simulation: GolfSimulation
    let record: CourseRecord?
    let practice: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("M O S S B A L L")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(GardenPalette.gold)
                .padding(.top, 32)
            Text(title).font(.system(size: 42, design: .serif))
            Text(subtitle).font(.system(size: 14)).foregroundStyle(GardenPalette.muted)
            if let record {
                HStack(alignment: .firstTextBaseline) {
                    Text(score).font(.system(size: 78, weight: .light, design: .serif))
                    Text("strokes").font(.system(size: 23, design: .serif))
                }
                Text(detail).font(.system(size: 12, design: .monospaced)).foregroundStyle(GardenPalette.gold)
                VStack(spacing: 13) {
                    HStack {
                        Text("GARDEN")
                        Spacer()
                        Text("PAR").frame(width: 40)
                        Text("YOU").frame(width: 40)
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(GardenPalette.muted)
                    ForEach(Array(Hole.course.enumerated()), id: \.offset) { index, hole in
                        HStack {
                            Text(String(format: "%02d", hole.number))
                                .font(.system(size: 11, design: .monospaced)).foregroundStyle(GardenPalette.gold)
                            Text(hole.name).font(.system(size: 18, design: .serif))
                            Spacer()
                            Text("\(hole.par)").frame(width: 40).foregroundStyle(GardenPalette.muted)
                            Text("\(record.strokes[index])\(record.completed[index] ? "" : "×")")
                                .frame(width: 40).foregroundStyle(GardenPalette.gold)
                        }
                        Divider().overlay(GardenPalette.muted.opacity(0.12))
                    }
                    if !record.finished {
                        Text("× Stroke limit reached").font(.system(size: 11)).foregroundStyle(GardenPalette.muted)
                    }
                }
                .padding(.horizontal, 35).padding(.top, 20)
                Spacer()
            } else {
                GardenCanvas(
                    simulation: simulation, bloom: simulation.sunk ? 1 : 0, reducedMotion: true, decorative: true
                )
                .frame(height: 390).padding(.top, -15).padding(.bottom, -22)
                Text(score).font(.system(size: 68, weight: .light, design: .serif))
                Text(detail).font(.system(size: 12, design: .monospaced)).foregroundStyle(GardenPalette.gold)
                if practice {
                    Text("PRACTICE ROUND").font(.system(size: 10, design: .monospaced)).foregroundStyle(
                        GardenPalette.muted)
                }
                Spacer(minLength: 5)
            }
            Text("A little golf. A little wild.")
                .font(.system(size: 17, design: .serif)).italic().foregroundStyle(GardenPalette.muted)
                .padding(.bottom, 28)
        }
        .frame(width: 450, height: 800)
        .foregroundStyle(GardenPalette.cream)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x244E38), GardenPalette.night], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .environment(\.colorScheme, .dark)
    }
}
