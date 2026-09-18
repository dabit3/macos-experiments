import SwiftUI

struct AtlasView: View {
  @EnvironmentObject private var store: AtlasStore
  @State private var collected = false
  @State private var settings = false
  @State private var selection: Landscape?

  private var landscapes: [Landscape] {
    Landscape.all.filter { !collected || store.saved.completions[$0.id] != nil }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          HStack {
            Text("A SMALL WORLD, PIECE BY PIECE")
              .font(.system(.caption2, design: .monospaced)).tracking(1.4)
            Spacer()
            Button {
              settings = true
            } label: {
              Image(systemName: "slider.horizontal.3")
                .font(.system(size: 20)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
          }
          .foregroundStyle(Paper.muted)
          VStack(alignment: .leading, spacing: 8) {
            Text("Foldscape")
              .font(.system(size: 49, weight: .regular, design: .serif))
            Text("Find a little peace in the pieces.")
              .font(.system(.subheadline)).foregroundStyle(Paper.muted)
          }
          HStack(spacing: 20) {
            filterButton("Landscapes", active: !collected) { collected = false }
            filterButton(
              "Collected · \(store.saved.completions.count)", active: collected
            ) { collected = true }
            Spacer(minLength: 0)
          }
          if landscapes.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
              Image("mosslight")
                .resizable().aspectRatio(contentMode: .fill)
                .frame(height: 230).clipped().saturation(0.35)
              Text("A world waiting to unfold.")
                .font(.system(.title2, design: .serif))
              Text("Finish a landscape to keep it here. Start gently; there’s no clock to race.")
                .foregroundStyle(Paper.muted)
              Button("Explore landscapes") { collected = false }
                .buttonStyle(InkButton())
            }
          }
          ForEach(landscapes) { scene in
            Button {
              selection = scene
            } label: {
              VStack(alignment: .leading, spacing: 14) {
                Image(scene.id)
                  .resizable().aspectRatio(contentMode: .fill)
                  .frame(height: 290).clipped()
                  .overlay(alignment: .topLeading) {
                    if store.saved.completions[scene.id] != nil {
                      Label("Collected", systemImage: "checkmark")
                        .font(.system(.caption, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Paper.stock, in: Capsule()).padding(16)
                    }
                  }
                  .shadow(color: Paper.ink.opacity(0.12), radius: 12, x: 0, y: 8)
                HStack(alignment: .top, spacing: 12) {
                  Text(scene.number)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(scene.color).padding(.top, 7)
                  VStack(alignment: .leading, spacing: 5) {
                    Text(scene.title).font(.system(.title2, design: .serif))
                    Text(scene.subtitle).font(.subheadline).foregroundStyle(Paper.muted)
                  }
                  Spacer()
                  Image(systemName: "arrow.up.right").padding(.top, 6)
                }
              }
              .padding(.bottom, 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(scene.title). \(scene.subtitle)")
            .accessibilityHint("Opens landscape and puzzle")
          }
          Text("SIX PAPER PLACES · TAKE YOUR TIME")
            .font(.system(.caption2, design: .monospaced))
            .tracking(1.2).foregroundStyle(Paper.muted)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
      }
      .paperScreen()
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(item: $selection) { scene in
        LandscapeView(scene: scene)
      }
      .sheet(isPresented: $settings) { SettingsView() }
      .alert("Your progress couldn’t be saved", isPresented: $store.saveError) {
        Button("Try again") { store.persist() }
      } message: {
        Text("Your current puzzle is still here. Try saving it again before closing the app.")
      }
    }
  }

  private func filterButton(_ title: String, active: Bool, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      VStack(spacing: 10) {
        Text(title).font(.system(.subheadline, weight: active ? .semibold : .regular))
        Rectangle().fill(active ? Paper.ink : .clear).frame(height: 2)
      }
      .padding(.top, 12)
    }
    .buttonStyle(.plain)
    .foregroundStyle(active ? Paper.ink : Paper.muted)
    .accessibilityAddTraits(active ? [.isSelected] : [])
  }
}

extension Landscape: Hashable {
  static func == (lhs: Landscape, rhs: Landscape) -> Bool { lhs.id == rhs.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct InkButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(.body, weight: .medium))
      .frame(maxWidth: .infinity).padding(.vertical, 18)
      .foregroundStyle(Paper.stock)
      .background(Paper.ink, in: RoundedRectangle(cornerRadius: 16))
      .opacity(configuration.isPressed ? 0.8 : 1)
  }
}
