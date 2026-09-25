import SwiftUI

@main
struct PulseGridApp: App {
  @StateObject private var store = ProgressStore()

  var body: some Scene {
    WindowGroup {
      HomeView()
        .environmentObject(store)
        .preferredColorScheme(.dark)
        .tint(Palette.mint)
    }
  }
}

struct HomeView: View {
  @EnvironmentObject private var store: ProgressStore
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @ScaledMetric(relativeTo: .largeTitle) private var brandSize = 49
  @State private var path: [Int] = []
  @State private var showProgress = false
  @State private var showGuide = false

  var body: some View {
    NavigationStack(path: $path) {
      ZStack {
        InstrumentBackground()
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            HStack {
              HStack(spacing: 8) {
                Circle().fill(Palette.mint).frame(width: 6, height: 6)
                MicroLabel(text: "POCKET INSTRUMENT")
              }
              Spacer()
              IconButton(symbol: "slider.horizontal.3", label: "Guide and settings") {
                showGuide = true
              }
            }
            VStack(alignment: .leading, spacing: 12) {
              Text("Pulse Grid")
                .font(.system(size: brandSize, weight: .light, design: .rounded))
                .tracking(-2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
              if !dynamicTypeSize.isAccessibilitySize {
                Text("Find the flow.")
                  .font(.system(.title3, weight: .regular))
                  .foregroundStyle(Palette.muted)
              }
            }
            if !dynamicTypeSize.isAccessibilitySize {
              HeroCircuit().frame(height: 125).padding(.horizontal, 10)
            }
            VStack(alignment: .leading, spacing: 15) {
              HStack {
                MicroLabel(text: "NEXT CONNECTION", color: Palette.mint)
                Spacer()
                MicroLabel(text: String(format: "%02d / 10", store.suggestedLevel + 1))
              }
              HStack(alignment: .firstTextBaseline) {
                Text(Circuits.all[store.suggestedLevel].name)
                  .font(.system(.title2, weight: .medium))
                  .foregroundStyle(Palette.ink)
                Spacer()
                if !dynamicTypeSize.isAccessibilitySize {
                  Text("\(Circuits.all[store.suggestedLevel].receiverCount) RX")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                }
              }
              ActionButton(title: "Enter circuit", symbol: "arrow.up.right", primary: true) {
                path.append(store.suggestedLevel)
              }
            }
            .padding(20)
            .background(Palette.panel.opacity(0.65), in: RoundedRectangle(cornerRadius: 24))
            .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(Palette.line, lineWidth: 1) }
            archiveLayout {
              MicroLabel(text: "CIRCUITS")
              if !dynamicTypeSize.isAccessibilitySize { Spacer() }
              Button {
                showProgress = true
              } label: {
                HStack(spacing: 6) {
                  Text("Archive").fixedSize()
                  Text("\(store.completedCount)/10")
                    .font(.system(.caption, design: .monospaced))
                    .fixedSize()
                  Image(systemName: "arrow.up.right")
                }
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(Palette.mint)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Palette.panel, in: Capsule())
              }
              .accessibilityLabel("Progress, \(store.completedCount) of 10 circuits powered")
            }
            .padding(.bottom, -12)
            LazyVStack(spacing: 0) {
              ForEach(Circuits.all) { level in
                Button {
                  path.append(level.id)
                } label: {
                  LevelRow(level: level, record: store.data.completions[level.id])
                }
                .buttonStyle(.plain)
                Rectangle().fill(Palette.line.opacity(0.65)).frame(height: 1)
              }
            }
            HStack {
              MicroLabel(text: "NO CLOCK. JUST CURRENT.")
              Spacer()
              Image(systemName: "waveform.path").foregroundStyle(Palette.muted)
            }
            .padding(.vertical, 10)
          }
          .padding(.horizontal, 24)
          .padding(.top, 12)
          .padding(.bottom, 28)
        }
      }
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: Int.self) { id in
        GameView(level: Circuits.all[id], initialSession: store.session(for: Circuits.all[id])) {
          path = [($0) % Circuits.all.count]
        }
        .id(id)
      }
      .sheet(isPresented: $showProgress) { ProgressViewScreen() }
      .sheet(isPresented: $showGuide) { GuideView() }
    }
  }

  private var archiveLayout: AnyLayout {
    dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
      : AnyLayout(HStackLayout())
  }
}

struct LevelRow: View {
  let level: CircuitLevel
  let record: CompletionRecord?

  var body: some View {
    HStack(spacing: 16) {
      Text(String(format: "%02d", level.id + 1))
        .font(.system(.title3, design: .monospaced, weight: .light))
        .foregroundStyle(record == nil ? Palette.muted : Palette.mint)
        .fixedSize()
        .frame(minWidth: 32)
      VStack(alignment: .leading, spacing: 6) {
        Text(level.name).font(.system(.body, weight: .medium)).foregroundStyle(Palette.ink)
        Text(
          "\(level.size) × \(level.size)  /  \(level.receiverCount) RECEIVER\(level.receiverCount == 1 ? "" : "S")"
        )
        .font(.system(.caption2, design: .monospaced))
        .tracking(0.6)
        .foregroundStyle(Palette.muted)
      }
      Spacer()
      Image(systemName: record == nil ? "arrow.up.right" : "checkmark.circle.fill")
        .font(.system(size: 18, weight: .light))
        .foregroundStyle(record == nil ? Palette.muted : Palette.mint)
    }
    .padding(.vertical, 20)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}
