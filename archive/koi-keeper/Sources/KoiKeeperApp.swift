import SwiftUI
import UIKit

@main
struct KoiKeeperApp: App {
  @StateObject private var model = PondModel()
  var body: some Scene {
    WindowGroup { PondHome(model: model) }
  }
}

enum PondSheet: String, Identifiable {
  case collection, garden, journal
  var id: String { rawValue }
}

enum EditMode: Equatable {
  case place(GardenKind)
  case remove
}

struct PondHome: View {
  @ObservedObject var model: PondModel
  @StateObject private var engine = PondEngine()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.scenePhase) private var scenePhase
  @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 34
  @State private var sheet: PondSheet?
  @State private var edit: EditMode?
  @State private var previewPoint: PondPoint?
  @State private var editingMaxY = 0.70

  private var previewKind: GardenKind? {
    if case .place(let kind) = edit { return kind }
    return nil
  }

  private var previewValid: Bool {
    guard let previewKind, let previewPoint else { return false }
    return previewPoint.y <= editingMaxY
      && model.placementIssue(previewKind, at: previewPoint) == nil
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        PondCanvas(
          model: model, engine: engine, reduceMotion: reduceMotion, editing: edit != nil,
          editingMaxY: editingMaxY, previewKind: previewKind, previewPoint: previewPoint,
          previewValid: previewValid
        )
        .ignoresSafeArea()
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0.58),
            .init(color: Color(hex: 0x0D3933).opacity(0.94), location: 1),
          ],
          startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture { location in
            let fullHeight =
              geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            let point = PondPoint(
              x: location.x / geometry.size.width,
              y: (location.y + geometry.safeAreaInsets.top) / fullHeight)
            act(at: point)
          }
          .accessibilityLabel("Living koi pond")
          .accessibilityHint(
            edit == nil
              ? "Use Feed koi below to feed at the center."
              : "Use Find a spot below to preview a placement."
          )
          .accessibilityAddTraits(.isButton)
          .accessibilityAction { act(at: PondPoint(x: 0.5, y: 0.48)) }
        VStack(spacing: 0) {
          header
          Spacer()
          VStack(spacing: 12) {
            if let edit {
              editorBar(edit)
            } else {
              VStack(spacing: 7) {
                if !model.food.isEmpty {
                  Text("\(model.food.count) grains drifting")
                    .font(.system(.caption2, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(PondPalette.paper.opacity(0.8))
                }
                Text(model.notice)
                  .font(.system(.footnote, design: .rounded))
                  .foregroundStyle(PondPalette.paper)
                  .multilineTextAlignment(.center)
                  .accessibilityIdentifier("pondNotice")
              }
              .padding(.horizontal, 18)
              .padding(.vertical, 12)
              .background(PondPalette.ink.opacity(0.76), in: RoundedRectangle(cornerRadius: 20))
              .padding(.horizontal, 25)
              mainControls
            }
          }
          .padding(.bottom, 8)
          .background {
            GeometryReader { panel in
              Color.clear.preference(
                key: PondPanelTop.self, value: panel.frame(in: .named("pond")).minY)
            }
          }
        }
      }
      .coordinateSpace(name: "pond")
      .onPreferenceChange(PondPanelTop.self) { top in
        let fullHeight =
          geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
        editingMaxY = min(
          0.78, max(0.20, (top + geometry.safeAreaInsets.top - 52) / fullHeight))
      }
    }
    .background(PondPalette.jade)
    .preferredColorScheme(.light)
    .sheet(item: $sheet) { destination in
      switch destination {
      case .collection: CollectionView(model: model)
      case .garden:
        GardenView(model: model) { mode in
          edit = mode
          previewPoint = nil
          sheet = nil
          if case .place(let kind) = mode {
            model.notice = "Choose a spot for your \(kind.title.lowercased())."
          } else {
            model.notice = "Tap a garden item to lift it. Paid pearls return."
          }
        }
      case .journal: JournalView(model: model)
      }
    }
    .onAppear { engine.start(model: model, reduceMotion: reduceMotion) }
    .onChange(of: reduceMotion) { _, value in engine.start(model: model, reduceMotion: value) }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        engine.start(model: model, reduceMotion: reduceMotion)
      } else {
        engine.stop()
        model.persist()
      }
    }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 5) {
        Text("Koi Keeper")
          .font(.system(size: min(titleSize, 46), weight: .regular, design: .serif))
          .fixedSize(horizontal: false, vertical: true)
        if !typeSize.isAccessibilitySize {
          HStack(spacing: 6) {
            Circle().fill(Color(hex: 0xC3D7A7)).frame(width: 5, height: 5)
            Text("A LITTLE WORLD, SLOWLY")
              .font(.system(size: 9, weight: .semibold, design: .monospaced))
              .tracking(2)
          }
        }
      }
      Spacer()
      Button {
        sheet = .journal
      } label: {
        VStack(spacing: 8) {
          PearlBalance(amount: model.save.pearls)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(PondPalette.paper, in: Capsule())
            .foregroundStyle(PondPalette.ink)
          Label("Journal", systemImage: "book.closed")
            .font(.system(.caption2, design: .rounded))
        }
      }
      .accessibilityLabel("\(model.save.pearls) care pearls. Open pond journal")
    }
    .foregroundStyle(PondPalette.paper)
    .padding(.horizontal, 26)
    .padding(.top, 12)
    .padding(.bottom, 35)
    .background {
      LinearGradient(
        colors: [Color(hex: 0x234F43).opacity(0.6), .clear], startPoint: .top, endPoint: .bottom
      )
      .ignoresSafeArea(edges: .top)
    }
  }

  private var mainControls: some View {
    HStack(alignment: .center, spacing: 34) {
      pondButton("Garden", symbol: "leaf") { sheet = .garden }
      Button {
        act(at: PondPoint(x: 0.5, y: 0.48))
      } label: {
        VStack(spacing: 8) {
          ZStack {
            Circle().fill(PondPalette.paper).frame(width: 70, height: 70)
            Circle().stroke(PondPalette.gold.opacity(0.35), lineWidth: 1).frame(
              width: 60, height: 60)
            Image(systemName: "circle.grid.2x2.fill").font(.system(size: 20, weight: .regular))
              .rotationEffect(.degrees(-15))
              .foregroundStyle(PondPalette.gold)
          }
          Text("Feed koi").font(.system(.caption, design: .rounded, weight: .semibold))
        }
      }
      .accessibilityIdentifier("feedButton")
      .accessibilityHint("Drop three grains. Earn one care pearl per grain eaten.")
      pondButton("Collection", symbol: "square.stack.3d.up") { sheet = .collection }
    }
    .foregroundStyle(PondPalette.paper)
    .padding(.horizontal, 25)
    .padding(.vertical, 20)
    .frame(maxWidth: .infinity)
  }

  private func pondButton(_ title: String, symbol: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      VStack(spacing: 13) {
        Image(systemName: symbol).font(.system(size: 22, weight: .light)).frame(height: 36)
        Text(title).font(.system(.caption, design: .rounded))
      }
      .frame(minWidth: 70, minHeight: 75)
    }
  }

  private func editorBar(_ mode: EditMode) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          Text(editTitle(mode)).font(.system(.title3, design: .serif))
          Text(mode == .remove ? "Tap an item. Pearls return." : "Tap water to preview")
            .font(.caption).foregroundStyle(PondPalette.muted)
        }
        Spacer(minLength: 8)
        Button(mode == .remove ? "Done" : "Cancel") {
          edit = nil
          previewPoint = nil
          model.notice =
            mode == .remove
            ? "Your garden is saved. Stay a little while." : "Nothing changed. Stay a little while."
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(PondPalette.ink.opacity(0.08), in: Capsule())
      }
      if case .place = mode {
        Text(model.notice).font(.caption).foregroundStyle(PondPalette.muted)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("placementNotice")
        HStack(spacing: 10) {
          Button("Find a spot") { findSpot() }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(PondPalette.ink.opacity(0.07), in: Capsule())
          Button("Place here") { confirmPlacement() }
            .buttonStyle(PondPrimaryStyle())
            .disabled(!previewValid)
        }
      }
    }
    .foregroundStyle(PondPalette.ink)
    .padding(18)
    .background(PondPalette.paper, in: RoundedRectangle(cornerRadius: 24))
    .padding(.horizontal, 20)
    .padding(.bottom, 16)
  }

  private func editTitle(_ mode: EditMode) -> String {
    switch mode {
    case .place(let kind): return "\(kind.title) · \(kind.price) pearls"
    case .remove: return "Lift a garden item"
    }
  }

  private func act(at point: PondPoint) {
    let success: Bool
    switch edit {
    case .place(let kind):
      previewPoint = point
      let issue =
        point.y > editingMaxY
        ? "Choose a spot above the controls." : model.placementIssue(kind, at: point)
      model.notice = issue ?? "A lovely spot. Place here when you’re ready."
      success = issue == nil
    case .remove:
      success = model.remove(at: point)
    case nil:
      success = model.feed(at: point)
    }
    if model.save.haptics {
      if success {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
      } else {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
      }
    }
  }

  private func findSpot() {
    guard let previewKind else { return }
    var candidates: [PondPoint] = []
    for y in stride(from: 0.30, through: editingMaxY, by: 0.14) {
      for x in stride(from: 0.22, through: 0.82, by: 0.15) {
        let point = PondPoint(x: x, y: y)
        if model.placementIssue(previewKind, at: point) == nil { candidates.append(point) }
      }
    }
    guard !candidates.isEmpty else {
      model.notice = "No clear spots here. Lift an item to make room."
      return
    }
    let next =
      previewPoint.flatMap { current in candidates.firstIndex(of: current) }.map {
        ($0 + 1) % candidates.count
      } ?? 0
    act(at: candidates[next])
  }

  private func confirmPlacement() {
    guard previewValid, let previewKind, let previewPoint else { return }
    if model.place(previewKind, at: previewPoint) {
      edit = nil
      self.previewPoint = nil
      if model.save.haptics { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    }
  }
}

private struct PondPanelTop: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

struct PearlBalance: View {
  let amount: Int
  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "circle.inset.filled").font(.system(size: 12, weight: .light))
      Text("\(amount)").font(.system(.title3, design: .serif)).monospacedDigit()
        .contentTransition(.numericText())
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(amount) care pearls")
  }
}

struct PaperPage<Content: View>: View {
  let eyebrow: String
  let title: String
  var dismissLabel = "Return to pond"
  @ViewBuilder let content: Content
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 9) {
            Text(eyebrow.uppercased()).font(.system(.caption2, design: .monospaced)).tracking(2)
              .foregroundStyle(PondPalette.gold)
            Text(title).font(.system(.largeTitle, design: .serif))
          }
          Spacer()
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark").font(.system(size: 15)).frame(width: 44, height: 44)
              .background(PondPalette.ink.opacity(0.06), in: Circle())
          }
          .accessibilityLabel(dismissLabel)
        }
        content
      }
      .padding(26)
      .padding(.top, 15)
      .padding(.bottom, 25)
    }
    .background(PondPalette.paper)
    .foregroundStyle(PondPalette.ink)
    .presentationDragIndicator(.visible)
  }
}

struct CollectionView: View {
  @ObservedObject var model: PondModel
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var selected: KoiKind?
  var body: some View {
    PaperPage(eyebrow: "Living jewels", title: "Your collection") {
      HStack {
        Text("\(model.save.fish.count) of 6 pond places").font(.subheadline)
        Spacer()
        PearlBalance(amount: model.save.pearls)
      }
      Text("Every koi has a quiet character.\nMake room for a new companion.")
        .font(.system(.body, design: .serif)).foregroundStyle(PondPalette.muted)
      ForEach(KoiKind.allCases) { kind in
        Button {
          selected = kind
        } label: {
          let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 18))
          layout {
            KoiPortrait(kind: kind)
              .frame(width: typeSize.isAccessibilitySize ? 180 : 124, height: 98)
              .background(Color(hex: 0xD9E1CF), in: RoundedRectangle(cornerRadius: 22))
            VStack(alignment: .leading, spacing: 6) {
              Text(kind.name).font(.system(.title2, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
              Text(kind.subtitle).font(.caption).foregroundStyle(PondPalette.muted)
              let count = model.save.fish.filter { $0.kind == kind }.count
              Text(count > 0 ? "\(count) in your pond" : "\(kind.price) pearls to welcome")
                .font(.system(.caption2, design: .rounded, weight: .semibold)).foregroundStyle(
                  PondPalette.gold)
            }
            if !typeSize.isAccessibilitySize {
              Spacer(minLength: 0)
              Image(systemName: "chevron.right").font(.caption)
            }
          }
          .padding(.vertical, 4)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
      }
      Text("Care is the only currency. Feed your koi to earn pearls; every eaten grain earns one.")
        .font(.footnote).foregroundStyle(PondPalette.muted)
    }
    .sheet(item: $selected) { kind in
      FishDetail(model: model, kind: kind)
    }
  }
}

struct FishDetail: View {
  @ObservedObject var model: PondModel
  let kind: KoiKind
  @Environment(\.dismiss) private var dismiss
  @State private var welcomed = false
  private var count: Int { model.save.fish.filter { $0.kind == kind }.count }
  private var canAdd: Bool { model.save.pearls >= kind.price && model.save.fish.count < 6 }

  var body: some View {
    PaperPage(
      eyebrow: "The koi field guide", title: kind.name, dismissLabel: "Return to collection"
    ) {
      KoiPortrait(kind: kind)
        .frame(height: 215)
        .frame(maxWidth: .infinity)
        .background {
          RoundedRectangle(cornerRadius: 100).fill(Color(hex: 0xD3DDCA))
        }
      Text(kind.subtitle).font(.system(.title2, design: .serif))
      Text(kind.story).font(.body).foregroundStyle(PondPalette.muted)
      HStack {
        VStack(alignment: .leading, spacing: 6) {
          Text("IN YOUR POND").font(.caption2).tracking(1.5)
          Text("\(count) koi").font(.system(.title2, design: .serif))
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 6) {
          Text("GRAINS ENJOYED").font(.caption2).tracking(1.5)
          Text("\(model.save.fish.filter { $0.kind == kind }.reduce(0) { $0 + $1.meals })").font(
            .system(.title2, design: .serif))
        }
      }
      Divider()
      if welcomed {
        Text("Welcome home, \(kind.name).").font(.system(.title2, design: .serif))
        Button("Back to collection") { dismiss() }.buttonStyle(PondPrimaryStyle())
      } else {
        HStack {
          Text("Your care pearls").font(.subheadline)
          Spacer()
          PearlBalance(amount: model.save.pearls)
        }
        Button("Welcome \(kind.name) · \(kind.price) pearls") {
          welcomed = model.addFish(kind)
        }
        .buttonStyle(PondPrimaryStyle())
        .disabled(!canAdd)
        if !canAdd {
          Text(
            model.save.fish.count >= 6
              ? "Your pond is full. Six koi have room to thrive."
              : "Earn \(kind.price - model.save.pearls) more pearls by feeding your koi."
          )
          .font(.footnote).foregroundStyle(PondPalette.muted)
        }
      }
    }
  }
}

struct GardenView: View {
  @ObservedObject var model: PondModel
  @Environment(\.dynamicTypeSize) private var typeSize
  var select: (EditMode) -> Void
  var body: some View {
    PaperPage(eyebrow: "Make it yours", title: "A garden, afloat") {
      HStack {
        Text("\(model.save.garden.count) of 16 garden spaces").font(.subheadline)
        Spacer()
        PearlBalance(amount: model.save.pearls)
      }
      Text("Choose a small addition, preview its place, then make it yours.")
        .font(.system(.body, design: .serif)).foregroundStyle(PondPalette.muted)
      ForEach(GardenKind.allCases) { kind in
        VStack(spacing: 8) {
          let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 18))
          layout {
            GardenPortrait(kind: kind).frame(width: 90, height: 90)
            VStack(alignment: .leading, spacing: 6) {
              Text(kind.title).font(.system(.title2, design: .serif))
              Text(kind.detail).font(.caption).foregroundStyle(PondPalette.muted)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
          }
          Button("Place \(kind.title.lowercased()) · \(kind.price) pearls") { select(.place(kind)) }
            .buttonStyle(PondPrimaryStyle())
            .disabled(model.save.pearls < kind.price || model.save.garden.count >= 16)
        }
      }
      Button {
        select(.remove)
      } label: {
        Label("Lift an item", systemImage: "arrow.up.and.line.horizontal.and.arrow.down")
          .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, 15)
      }
      .disabled(model.save.garden.isEmpty)
      Text(
        "Lift items to rearrange. Purchased items return all their pearls. Your first three garden pieces are a gift."
      )
      .font(.footnote).foregroundStyle(PondPalette.muted)
      if !model.save.garden.isEmpty {
        DisclosureGroup("Lift from your garden") {
          ForEach(Array(model.save.garden.enumerated()), id: \.element.id) { index, item in
            Button {
              model.remove(at: item.point)
            } label: {
              HStack {
                Text("\(index + 1). \(item.kind.title)")
                Spacer()
                Text("Lift · \(item.paid) back")
              }
              .font(.subheadline)
              .padding(.vertical, 12)
            }
            .accessibilityLabel(
              "Lift \(item.kind.title) number \(index + 1), return \(item.paid) pearls")
          }
        }
        .font(.subheadline)
        .tint(PondPalette.ink)
      }
    }
  }
}

struct JournalView: View {
  @ObservedObject var model: PondModel
  @State private var confirmReset = false
  var body: some View {
    PaperPage(eyebrow: "A moment of stillness", title: "Pond journal") {
      HStack(alignment: .firstTextBaseline) {
        Text("\(model.save.totalMeals)").font(.system(size: 68, weight: .regular, design: .serif))
        Text("small acts\nof care").font(.system(.title3, design: .serif)).foregroundStyle(
          PondPalette.muted)
      }
      Text("One grain. One happy koi. One pearl.\nThere is no hurry here.")
        .font(.system(.title3, design: .serif))
      Divider()
      Label("Saved on this iPhone", systemImage: "checkmark.circle")
        .font(.subheadline.weight(.medium))
      Text(
        "Your fish, garden and pearls save automatically after every change. Swimming pauses while you are away."
      )
      .font(.footnote).foregroundStyle(PondPalette.muted)
      Toggle(
        "Gentle haptics", isOn: Binding(get: { model.save.haptics }, set: { model.setHaptics($0) })
      )
      .tint(PondPalette.ink)
      VStack(alignment: .leading, spacing: 10) {
        Text("How to keep koi").font(.system(.title2, design: .serif))
        Text(
          "Tap open water or Feed koi. Fish seek the nearest grain and earn a pearl when they eat it. Up to eight grains can float at once; uneaten grains dissolve after 45 seconds."
        )
        Text(
          "Welcome up to six koi in Collection. Place lilies, stones and irises in Garden. Leave a little space between each piece."
        )
      }
      .font(.footnote).foregroundStyle(PondPalette.muted)
      Divider()
      Button("Begin a new pond", role: .destructive) { confirmReset = true }
        .font(.subheadline).frame(minHeight: 44)
      Text("KOI KEEPER / VOLUME 01").font(.system(.caption2, design: .monospaced)).tracking(2)
        .foregroundStyle(PondPalette.muted)
    }
    .alert("Begin a new pond?", isPresented: $confirmReset) {
      Button("Keep my pond", role: .cancel) {}
      Button("Reset pond", role: .destructive) { model.reset() }
    } message: {
      Text(
        "This removes your fish, garden changes and pearls. You’ll start with two koi, three garden pieces and 12 pearls."
      )
    }
  }
}

struct PondPrimaryStyle: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(.subheadline, design: .rounded, weight: .semibold))
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity, minHeight: 24)
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .foregroundStyle(enabled ? PondPalette.paper : PondPalette.muted)
      .background(enabled ? PondPalette.ink : PondPalette.ink.opacity(0.08), in: Capsule())
      .opacity(configuration.isPressed ? 0.75 : 1)
  }
}
