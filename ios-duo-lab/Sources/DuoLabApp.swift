import SwiftUI

@main
struct DuoLabApp: App {
  var body: some Scene {
    WindowGroup {
      LabView()
    }
  }
}

private enum Experiment: String, CaseIterable, Identifiable {
  case workspace = "Workspace"
  case notes = "Notes"
  case diagnostics = "Diagnostics"

  var id: Self { self }

  var symbol: String {
    switch self {
    case .workspace: "square.grid.2x2"
    case .notes: "square.and.pencil"
    case .diagnostics: "ruler"
    }
  }
}

private struct LabView: View {
  @State private var selection: Experiment? = .workspace
  @AppStorage("duolab.tapCount") private var tapCount = 0
  @AppStorage("duolab.tileCount") private var tileCount = 6
  @AppStorage("duolab.notes") private var notes = ""
  @State private var showingReset = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    GeometryReader { window in
      NavigationSplitView {
        List(Experiment.allCases, selection: $selection) { experiment in
          NavigationLink(value: experiment) {
            Label(experiment.rawValue, systemImage: experiment.symbol)
          }
        }
        .navigationTitle("Duo Lab")
        .safeAreaInset(edge: .bottom) {
          Label("Adaptive layout playground", systemImage: "flask")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding()
        }
      } detail: {
        GeometryReader { detail in
          Group {
            switch selection {
            case .workspace:
              workspace
            case .notes:
              notesEditor
            case .diagnostics:
              diagnostics(window: window, detail: detail)
            case nil:
              ContentUnavailableView(
                "Choose an experiment",
                systemImage: "flask",
                description: Text("Explore layouts, edit notes, and inspect the current window.")
              )
            }
          }
          .navigationTitle(selection?.rawValue ?? "Duo Lab")
          .toolbar {
            if selection == .workspace {
              ToolbarItem(placement: .primaryAction) {
                Button("Reset", systemImage: "arrow.counterclockwise") {
                  showingReset = true
                }
              }
            }
          }
          .safeAreaInset(edge: .bottom) {
            HStack {
              Image(systemName: "rectangle.expand.vertical")
              Text("\(Int(detail.size.width)) × \(Int(detail.size.height)) pt")
              Spacer()
              Text(horizontalSizeClass == .regular ? "Regular width" : "Compact width")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding()
            .background(.bar)
          }
        }
      }
      .navigationSplitViewStyle(.balanced)
    }
    .tint(.indigo)
    .confirmationDialog("Reset workspace?", isPresented: $showingReset) {
      Button("Reset workspace", role: .destructive) {
        tapCount = 0
        tileCount = 6
      }
    } message: {
      Text("The tap count and tile count will reset. Your notes will be kept.")
    }
  }

  private var workspace: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
          Text("A little room\nto experiment.")
            .font(.largeTitle.bold())
          Text("Resize, rotate, or switch displays. Your workspace stays with you.")
            .foregroundStyle(.secondary)
        }

        GroupBox {
          VStack(alignment: .leading, spacing: 16) {
            Text("STATE CHECK").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text("\(tapCount) taps").font(.system(.largeTitle, design: .rounded, weight: .bold))
            Button("Add a tap", systemImage: "plus") {
              tapCount += 1
            }
            .buttonStyle(.borderedProminent)
            Text("Saved on this device, including after you relaunch.")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(8)
        }

        Stepper("Tiles: \(tileCount)", value: $tileCount, in: 1...12)
          .font(.headline)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
          ForEach(0..<tileCount, id: \.self) { index in
            VStack(alignment: .leading, spacing: 24) {
              Image(systemName: "square.stack.3d.up")
                .font(.title2)
                .foregroundStyle(.indigo)
              Text("Experiment \(index + 1)").font(.headline)
              Text("Ready to make your own")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
          }
        }
      }
      .padding(24)
      .frame(maxWidth: 1000, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
  }

  private var notesEditor: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("What should we try next?").font(.title2.bold())
      Text("Notes save automatically on this device.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      TextEditor(text: $notes)
        .accessibilityLabel("Experiment notes")
        .scrollContentBackground(.hidden)
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
    }
    .padding(24)
  }

  private func diagnostics(window: GeometryProxy, detail: GeometryProxy) -> some View {
    Form {
      Section("Live layout") {
        LabeledContent("Window", value: dimensions(window.size))
        LabeledContent("Detail", value: dimensions(detail.size))
        LabeledContent("Horizontal size class", value: sizeClassName(horizontalSizeClass))
        LabeledContent("Vertical size class", value: sizeClassName(verticalSizeClass))
        LabeledContent("Dynamic Type", value: String(describing: dynamicTypeSize))
        LabeledContent("Top safe area", value: "\(Int(window.safeAreaInsets.top)) pt")
        LabeledContent("Bottom safe area", value: "\(Int(window.safeAreaInsets.bottom)) pt")
      }
      Section("About this starter") {
        Text("NavigationSplitView adapts the sidebar to the available space.")
        Text("The grid uses the available width instead of a device model or fixed screen size.")
        Text(
          "Size classes describe this window, not a physical display or fold state. "
            + "Run on the actual iPhone Duo simulator to verify display transitions."
        )
      }
    }
  }

  private func dimensions(_ size: CGSize) -> String {
    "\(Int(size.width)) × \(Int(size.height)) pt"
  }

  private func sizeClassName(_ sizeClass: UserInterfaceSizeClass?) -> String {
    switch sizeClass {
    case .compact: "Compact"
    case .regular: "Regular"
    case nil: "Unspecified"
    @unknown default: "Unknown"
    }
  }
}
