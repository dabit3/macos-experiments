import LinkPresentation
import SwiftUI
import UIKit

struct CatchView: View {
  let record: CatchRecord
  let total: Int
  let personalBest: Bool
  let again: () -> Void
  let home: () -> Void
  @State private var share: SharePayload?
  @State private var arrived = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var reward: String {
    total == 3
      ? "Violet Reach is now open"
      : "+\(record.species.rare ? 2 : 1) glow bait · saved to your journal"
  }

  var body: some View {
    VStack(spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(personalBest ? "New personal best" : "Catch landed")
            .font(TypeStyle.label(13))
            .foregroundStyle(personalBest ? Palette.sunset : Palette.muted)
          Text(reward).font(TypeStyle.body(13)).foregroundStyle(Palette.muted)
            .accessibilityIdentifier("catch-reward")
        }
        Spacer()
        IconButton(
          systemImage: "xmark", label: "Back to shore", identifier: "result-home", action: home)
      }
      GeometryReader { geometry in
        ScrollView {
          CatchCard(record: record)
            .scaleEffect(arrived || reduceMotion ? 1 : 0.92)
            .opacity(arrived ? 1 : 0)
            .frame(minHeight: geometry.size.height)
        }
      }
      .scrollIndicators(.visible)
      .scrollBounceBehavior(.basedOnSize)
      HStack(spacing: 10) {
        ActionButton(
          title: "Share", systemImage: "square.and.arrow.up", kind: .secondary,
          identifier: "share-catch"
        ) {
          let renderer = ImageRenderer(
            content: CatchCard(record: record).frame(width: 360).padding(20).background(
              Palette.night))
          renderer.scale = 3
          if let image = renderer.uiImage {
            share = SharePayload(
              image: image,
              text:
                "I landed a \(record.length) cm \(record.species.name) at \(record.lake.name) in Dusk Angler. \(record.species.rare ? "Rare" : "Common") · \(record.score) points."
            )
          }
        }
        .frame(maxWidth: 140)
        ActionButton(
          title: "Cast again", systemImage: "arrow.up.forward", identifier: "One more cast",
          action: again)
      }
    }
    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
    .background(Palette.night.opacity(0.88).ignoresSafeArea())
    .sheet(item: $share) { payload in ShareSheet(payload: payload) }
    .onAppear {
      withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.78)) {
        arrived = true
      }
    }
  }
}

struct CatchCard: View {
  let record: CatchRecord
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack(alignment: .top) {
        LinearGradient(
          colors: record.lake == .amber
            ? [Color(red: 0.98, green: 0.62, blue: 0.47), Color(red: 0.45, green: 0.3, blue: 0.5)]
            : [Color(red: 0.55, green: 0.5, blue: 0.9), Color(red: 0.16, green: 0.17, blue: 0.4)],
          startPoint: .top, endPoint: .bottom)
        FishArt(species: record.species)
          .padding(.horizontal, 22).padding(.top, 44).padding(.bottom, 18)
          .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
        HStack {
          Text("Dusk Angler").font(TypeStyle.label(12)).foregroundStyle(Palette.night.opacity(0.75))
          Spacer()
          Text(record.species.rare ? "Rare" : "Common").font(TypeStyle.label(12))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Palette.night.opacity(0.78), in: Capsule())
            .foregroundStyle(record.species.rare ? Palette.violet : Palette.reed)
        }
        .padding(14)
      }
      .frame(height: 230)
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 3) {
          Text(record.species.name).font(TypeStyle.display(26)).lineLimit(1)
            .minimumScaleFactor(0.7)
          Text(record.species.latin).font(TypeStyle.body(14).italic()).foregroundStyle(
            Palette.muted)
        }
        HStack(spacing: 12) {
          Stat(value: "\(record.length) cm", label: "Length")
          Stat(value: "\(record.score)", label: "Score")
        }
        Rectangle().fill(Palette.line).frame(height: 1)
        HStack {
          Label(record.lake.name, systemImage: "mappin.and.ellipse")
          Spacer()
          Text(record.date.formatted(date: .abbreviated, time: .omitted))
        }
        .font(TypeStyle.body(13)).foregroundStyle(Palette.muted)
      }
      .padding(18)
      .background(Palette.surface)
    }
    .foregroundStyle(Palette.text)
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Palette.line, lineWidth: 1))
    .accessibilityElement(children: .combine)
  }
}

struct SharePayload: Identifiable {
  let id = UUID()
  let image: UIImage
  let text: String
}

struct ShareSheet: UIViewControllerRepresentable {
  let payload: SharePayload
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(
      activityItems: [CatchShareItem(payload: payload)], applicationActivities: nil)
  }
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

final class CatchShareItem: NSObject, UIActivityItemSource {
  let payload: SharePayload
  init(payload: SharePayload) { self.payload = payload }

  func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController)
    -> Any
  {
    payload.image
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    payload.image
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    subjectForActivityType activityType: UIActivity.ActivityType?
  ) -> String {
    payload.text
  }

  func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController)
    -> LPLinkMetadata?
  {
    let metadata = LPLinkMetadata()
    metadata.title = payload.text
    metadata.imageProvider = NSItemProvider(object: payload.image)
    metadata.iconProvider = NSItemProvider(object: payload.image)
    return metadata
  }
}

struct FieldPanel: View {
  @ObservedObject var store: GameStore
  let panel: AnglerView.Panel
  let replayTutorial: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          switch panel {
          case .journal: journal
          case .settings: settings
          }
        }
        .padding(20)
      }
      .background(Palette.night)
      .foregroundStyle(Palette.text)
      .font(TypeStyle.body(15))
      .navigationTitle(panel == .journal ? "Field journal" : "Settings")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }.font(TypeStyle.label(17)).foregroundStyle(Palette.sunset)
            .accessibilityIdentifier("panel-done")
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  private var journal: some View {
    VStack(alignment: .leading, spacing: 28) {
      HStack(spacing: 12) {
        Stat(
          value: "\(store.progress.total)",
          label: store.progress.total == 1 ? "Catch" : "Catches")
        Stat(
          value: "\(Set(store.progress.catches.map(\.species)).count)/\(Species.allCases.count)",
          label: "Species")
        Stat(value: store.progress.best == 0 ? "—" : "\(store.progress.best)", label: "Best score")
      }
      .panel(padding: 16)
      VStack(alignment: .leading, spacing: 12) {
        Text("Species").font(TypeStyle.title(20))
        LazyVGrid(
          columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12
        ) {
          ForEach(Species.allCases) { species in speciesTile(species) }
        }
      }
      VStack(alignment: .leading, spacing: 4) {
        Text("Recent catches").font(TypeStyle.title(20)).padding(.bottom, 8)
        if store.progress.catches.isEmpty {
          Text("Nothing yet. Your first catch will appear here.")
            .font(TypeStyle.body(15)).foregroundStyle(Palette.muted)
        }
        ForEach(store.progress.catches.suffix(8).reversed()) { record in
          HStack(spacing: 14) {
            FishArt(species: record.species).frame(width: 56, height: 32)
            VStack(alignment: .leading, spacing: 2) {
              Text(record.species.name).font(TypeStyle.label(15))
              Text(
                "\(record.lake.name) · \(record.date.formatted(date: .abbreviated, time: .omitted))"
              )
              .font(TypeStyle.body(12)).foregroundStyle(Palette.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
              Text("\(record.length) cm").font(TypeStyle.number(15))
              Text("\(record.score) pts").font(TypeStyle.body(12)).foregroundStyle(Palette.muted)
            }
          }
          .padding(.vertical, 10)
          .accessibilityElement(children: .combine)
          Rectangle().fill(Palette.line).frame(height: 1)
        }
      }
      Text(
        "Every catch earns glow bait (2 for rare fish). Spend 2 before a cast to draw a rare fish. The latest 100 catches are kept on this device."
      )
      .font(TypeStyle.body(13)).foregroundStyle(Palette.muted)
    }
  }

  private func speciesTile(_ species: Species) -> some View {
    let records = store.progress.catches.filter { $0.species == species }
    let largest = records.map(\.length).max()
    return VStack(alignment: .leading, spacing: 8) {
      FishArt(species: species, silhouette: records.isEmpty)
        .frame(height: 58).frame(maxWidth: .infinity)
        .opacity(records.isEmpty ? 0.9 : 1)
        .padding(.vertical, 8)
      HStack(spacing: 6) {
        Text(species.name).font(TypeStyle.label(14)).lineLimit(1).minimumScaleFactor(0.8)
        if species.rare { Circle().fill(Palette.violet).frame(width: 6, height: 6) }
      }
      Text(largest.map { "Best \($0) cm · \(records.count) caught" } ?? "Not caught yet")
        .font(TypeStyle.body(12)).foregroundStyle(Palette.muted).lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .padding(12)
    .background(
      records.isEmpty ? Palette.surface : Palette.raised, in: RoundedRectangle(cornerRadius: 16)
    )
    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line, lineWidth: 1))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("species-\(species.rawValue)")
  }

  private var settings: some View {
    VStack(alignment: .leading, spacing: 28) {
      VStack(spacing: 0) {
        Toggle("Sound effects", isOn: $store.sound).tint(Palette.sunset)
          .accessibilityIdentifier("sound-toggle")
          .padding(.vertical, 12)
        Rectangle().fill(Palette.line).frame(height: 1)
        Toggle("Haptics", isOn: $store.haptics).tint(Palette.sunset)
          .accessibilityIdentifier("haptic-toggle")
          .padding(.vertical, 12)
      }
      .font(TypeStyle.label(16))
      .panel(padding: 16)
      VStack(alignment: .leading, spacing: 12) {
        Text("How to fish").font(TypeStyle.title(20))
        Text(
          "Pick a fish and cast. When the float dips, tap Hook. Hold the reel pad to pull; let go during red surges. 100% tension snaps the line, and five seconds of slack lets the fish go."
        )
        .font(TypeStyle.body(15)).foregroundStyle(Palette.muted)
        ActionButton(
          title: "Replay tutorial", systemImage: "play.circle", kind: .secondary,
          identifier: "Replay tutorial"
        ) {
          dismiss()
          replayTutorial()
        }
      }
      Text(
        "Progress stays on this device. Fish and their names are fictional. Supports Reduce Motion; with VoiceOver, activate Reel to toggle holding."
      )
      .font(TypeStyle.body(13)).foregroundStyle(Palette.muted)
    }
  }
}
