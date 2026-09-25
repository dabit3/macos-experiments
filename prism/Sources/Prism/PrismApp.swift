import AppKit
import PrismCore
import SwiftUI

enum PrismAssets {
  static let images: [String: NSImage] = Dictionary(
    uniqueKeysWithValues: ["Solstice", "Nocturne"].compactMap { name in
      guard let url = bundle.url(forResource: name, withExtension: "png"),
        let image = NSImage(contentsOf: url)
      else { return nil }
      return (name, image)
    })

  static let bundle: Bundle = {
    if let url = Bundle.main.resourceURL?.appendingPathComponent("Prism_Prism.bundle"),
      let bundle = Bundle(url: url)
    {
      return bundle
    }
    return Bundle.module
  }()
}

@main
struct PrismApp: App {
  @StateObject private var store = Store()
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

  var body: some Scene {
    Window("Prism", id: "prism") {
      Workspace()
        .environmentObject(store)
        .preferredColorScheme(.dark)
        .frame(minWidth: 1040, minHeight: 720)
        .onAppear {
          NSApp.setActivationPolicy(.regular)
          NSApp.activate(ignoringOtherApps: true)
        }
    }
    .defaultSize(width: 1380, height: 880)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("New Graph") { store.newProject() }.keyboardShortcut("n")
        Button("Open Project…") { store.openProject() }.keyboardShortcut("o")
        Button("Save Project…") { store.save() }.keyboardShortcut("s")
        Button("Save Project As…") { store.save(asNew: true) }
          .keyboardShortcut("s", modifiers: [.command, .shift])
        Divider()
        Button("Export PNG…") { store.exportPNG() }
          .keyboardShortcut("e", modifiers: [.command, .shift])
      }
      CommandGroup(replacing: .undoRedo) {
        Button("Undo") { store.undo() }.keyboardShortcut("z").disabled(store.history.isEmpty)
        Button("Redo") { store.redo() }.keyboardShortcut("z", modifiers: [.command, .shift])
          .disabled(store.future.isEmpty)
      }
      CommandMenu("Graph") {
        ForEach(NodeKind.allCases.filter { $0 != .output }) { kind in
          Button("Add \(kind.title)") { store.add(kind) }
        }
        Divider()
        Button("Delete Selected Node") { store.deleteSelected() }
          .keyboardShortcut(.delete, modifiers: [])
          .disabled(store.selectedNode == nil || store.selectedNode?.kind == .output)
        Button("Compare Original") { store.comparing.toggle() }
          .keyboardShortcut("b", modifiers: [])
        Button("Restore Example") { store.newProject(sample: true) }
      }
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

enum Palette {
  static let background = Color(red: 0.065, green: 0.073, blue: 0.086)
  static let panel = Color(red: 0.094, green: 0.102, blue: 0.116)
  static let raised = Color(red: 0.13, green: 0.14, blue: 0.157)
  static let stroke = Color.white.opacity(0.09)
  static let secondary = Color(red: 0.59, green: 0.62, blue: 0.66)
  static let accent = Color(red: 0.78, green: 0.75, blue: 1)
}

extension NodeKind {
  var tint: Color {
    switch self {
    case .image: return Color(red: 0.45, green: 0.77, blue: 0.81)
    case .exposure: return Color(red: 0.95, green: 0.77, blue: 0.45)
    case .saturation: return Color(red: 0.81, green: 0.60, blue: 0.90)
    case .blur: return Color(red: 0.48, green: 0.67, blue: 0.98)
    case .blend: return Color(red: 0.94, green: 0.57, blue: 0.55)
    case .output: return Color(red: 0.61, green: 0.85, blue: 0.60)
    }
  }
  var symbol: String {
    switch self {
    case .image: return "photo"
    case .exposure: return "sun.max"
    case .saturation: return "drop.halffull"
    case .blur: return "camera.filters"
    case .blend: return "square.2.layers.3d"
    case .output: return "arrow.up.right.square"
    }
  }
  var explanation: String {
    switch self {
    case .image: return "An original procedural landscape. Your source stays untouched."
    case .exposure: return "Shift the light in your image with a linear exposure adjustment."
    case .saturation: return "Move from quiet monochrome to a richer color palette."
    case .blur: return "A soft Gaussian diffusion, with edges clamped to preserve the frame."
    case .blend: return "Crossfade two image branches. A at 0%, B at 100%."
    case .output: return "The final composite. Export a full-resolution, sRGB PNG."
    }
  }
  func valueLabel(_ value: Double) -> String {
    switch self {
    case .exposure: return String(format: "%+.2f EV", value)
    case .saturation: return String(format: "%.0f%%", value * 100)
    case .blur: return String(format: "%.1f px", value)
    case .blend: return String(format: "%.0f%% B", value * 100)
    default: return ""
    }
  }
}

struct Workspace: View {
  @EnvironmentObject var store: Store

  var body: some View {
    VStack(spacing: 0) {
      header
      Rectangle().fill(Palette.stroke).frame(height: 1)
      HStack(spacing: 0) {
        GeometryReader { geo in
          VStack(spacing: 0) {
            PreviewPane().frame(height: max(260, geo.size.height * 0.55))
            Rectangle().fill(Palette.stroke).frame(height: 1)
            GraphPane()
          }
        }
        Rectangle().fill(Palette.stroke).frame(width: 1)
        Inspector().frame(width: 244)
      }
      statusBar
    }
    .background(Palette.background)
    .font(.system(size: 12))
    .tint(Palette.accent)
    .alert(
      "Prism",
      isPresented: Binding(
        get: { store.alert != nil },
        set: { if !$0 { store.alert = nil } }
      )
    ) {
      Button("OK") { store.alert = nil }
    } message: {
      Text(store.alert ?? "")
    }
    .onExitCommand {
      store.pendingSource = nil
      store.status = "Connection cancelled"
    }
  }

  private var header: some View {
    HStack(spacing: 14) {
      HStack(spacing: 9) {
        Image(systemName: "triangle.lefthalf.filled")
          .font(.system(size: 22, weight: .light))
          .foregroundStyle(
            LinearGradient(colors: [.white, Palette.accent], startPoint: .top, endPoint: .bottom))
        Text("prism").font(.system(size: 22, weight: .semibold, design: .rounded)).tracking(-0.7)
      }
      Rectangle().fill(Palette.stroke).frame(width: 1, height: 23)
      VStack(alignment: .leading, spacing: 3) {
        Text(store.projectURL?.deletingPathExtension().lastPathComponent ?? store.project.name)
          .font(.system(size: 12, weight: .medium))
        Text("NON-DESTRUCTIVE IMAGE STUDIO")
          .font(.system(size: 8, weight: .medium)).tracking(1.6).foregroundStyle(Palette.secondary)
      }
      Spacer()
      Button {
        store.newProject()
      } label: {
        Label("New", systemImage: "plus")
      }
      .help("Start a new graph (⌘N)")
      Button {
        store.openProject()
      } label: {
        Label("Open", systemImage: "folder")
      }
      Button {
        store.save()
      } label: {
        Label("Save", systemImage: "square.and.arrow.down")
      }
      Button {
        store.exportPNG()
      } label: {
        HStack(spacing: 7) {
          Image(systemName: "arrow.up.right")
          Text("Export PNG")
        }
        .fontWeight(.semibold).foregroundStyle(Palette.background)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 7))
      }
      .disabled(store.renderError != nil)
      .opacity(store.renderError == nil ? 1 : 0.45)
    }
    .buttonStyle(.plain)
    .padding(.leading, 84)
    .padding(.trailing, 18)
    .frame(height: 70)
    .background(Palette.panel)
  }

  private var statusBar: some View {
    HStack(spacing: 8) {
      Circle().fill(store.renderError == nil ? Color.green.opacity(0.7) : Color.orange)
        .frame(width: 5, height: 5)
      Text(store.status).lineLimit(1).font(.system(size: 10))
      Spacer()
      Text("\(store.project.nodes.count) nodes  /  \(store.project.edges.count) connections")
        .font(.system(size: 10, design: .monospaced))
      Text("•  CORE IMAGE").font(.system(size: 8, weight: .medium)).tracking(1)
    }
    .foregroundStyle(Palette.secondary)
    .padding(.horizontal, 18).frame(height: 28)
    .background(Palette.panel)
    .overlay(alignment: .top) { Rectangle().fill(Palette.stroke).frame(height: 1) }
  }
}

struct PreviewPane: View {
  @EnvironmentObject var store: Store

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("VIEWER").font(.system(size: 9, weight: .semibold)).tracking(1.6)
        Text("/").foregroundStyle(.white.opacity(0.2))
        Text(store.comparing ? "Original source" : "Final composite").font(.system(size: 11))
        Spacer()
        Button {
          store.comparing.toggle()
        } label: {
          Label(
            store.comparing ? "Viewing original" : "Compare original",
            systemImage: "rectangle.leadinghalf.inset.filled"
          )
          .font(.system(size: 10, weight: .medium))
          .padding(.horizontal, 10).padding(.vertical, 6)
          .background(
            store.comparing ? Palette.accent.opacity(0.17) : Palette.raised, in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Toggle original comparison (B)")
      }
      .foregroundStyle(Palette.secondary).padding(.horizontal, 22).frame(height: 42)

      ZStack {
        if let image = store.comparing ? store.original : store.preview {
          Image(nsImage: image)
            .resizable().aspectRatio(contentMode: .fit)
            .shadow(color: .black.opacity(0.5), radius: 22, y: 8)
            .padding(.horizontal, 24).padding(.vertical, 5)
            .accessibilityLabel(store.comparing ? "Original artwork" : "Rendered composite")
        } else {
          VStack(spacing: 13) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
              .font(.system(size: 35, weight: .ultraLight)).foregroundStyle(Palette.accent)
            Text("A connection away").font(.system(size: 19, weight: .medium))
            Text(store.renderError ?? "Add an image to get started")
              .foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
              .frame(maxWidth: 320)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      HStack(spacing: 6) {
        Text(store.comparing ? "SOURCE" : "COMPOSITE").tracking(1.3)
        Text("•")
        Text("1600 × 1100")
        Spacer()
        Text("sRGB").padding(.horizontal, 6).padding(.vertical, 2)
          .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.stroke))
        Text("FIT").tracking(1)
      }
      .font(.system(size: 8, weight: .medium, design: .monospaced))
      .foregroundStyle(Palette.secondary).padding(.horizontal, 24).frame(height: 30)
    }
    .background(
      RadialGradient(
        colors: [Color.white.opacity(0.035), .clear], center: .center, startRadius: 30,
        endRadius: 550)
    )
  }
}

struct GraphPane: View {
  @EnvironmentObject var store: Store
  private let canvasWidth: CGFloat = 2040
  private let canvasHeight: CGFloat = 1220

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 9) {
        Text("GRAPH").font(.system(size: 9, weight: .semibold)).tracking(1.5)
          .foregroundStyle(Palette.secondary)
        Spacer(minLength: 3)
        ForEach(NodeKind.allCases.filter { $0 != .output }) { kind in
          Button {
            store.add(kind)
          } label: {
            HStack(spacing: 5) {
              Image(systemName: kind.symbol).foregroundStyle(kind.tint)
              Text(kind.title)
            }
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: 5))
          }
          .buttonStyle(.plain).help("Add \(kind.title) node")
          .accessibilityIdentifier("add-\(kind.rawValue)")
        }
        Divider().frame(height: 15)
        Button {
          store.zoom = max(0.45, store.zoom - 0.1)
        } label: {
          Image(systemName: "minus").frame(width: 24, height: 28).contentShape(Rectangle())
        }
        .accessibilityLabel("Zoom out")
        Text("\(Int(store.zoom * 100))%").font(.system(size: 9, design: .monospaced)).frame(
          width: 30)
        Button {
          store.zoom = min(1.4, store.zoom + 0.1)
        } label: {
          Image(systemName: "plus").frame(width: 24, height: 28).contentShape(Rectangle())
        }
        .accessibilityLabel("Zoom in")
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 18).frame(height: 45).background(Palette.panel)
      ScrollView([.horizontal, .vertical]) {
        ZStack(alignment: .topLeading) {
          Canvas { context, size in
            for x in stride(from: 12.0, to: size.width, by: 22) {
              for y in stride(from: 12.0, to: size.height, by: 22) {
                context.fill(
                  Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                  with: .color(.white.opacity(0.11)))
              }
            }
          }
          .allowsHitTesting(false)
          connections
          ForEach(store.project.nodes) { node in
            NodeCard(node: node)
              .position(x: node.x + 90, y: node.y + 55)
          }
          Text(
            store.pendingSource == nil
              ? "OUTPUT PORT → INPUT PORT   •   DRAG HEADERS TO ARRANGE"
              : "CHOOSE AN INPUT PORT TO CONNECT   •   ESC TO CANCEL"
          )
          .font(.system(size: 9, weight: .medium, design: .monospaced))
          .tracking(1).foregroundStyle(
            store.pendingSource == nil ? Palette.secondary : Palette.accent
          )
          .position(x: 380, y: 26)
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .scaleEffect(store.zoom, anchor: .topLeading)
        .frame(
          width: canvasWidth * store.zoom, height: canvasHeight * store.zoom, alignment: .topLeading
        )
      }
      .background(Palette.background)
    }
  }

  private var connections: some View {
    Canvas { context, _ in
      for edge in store.project.edges {
        guard let source = store.project.nodes.first(where: { $0.id == edge.source }),
          let target = store.project.nodes.first(where: { $0.id == edge.target })
        else { continue }
        let start = CGPoint(x: source.x + 180, y: source.y + 76)
        let end = CGPoint(x: target.x, y: target.y + 65 + Double(edge.input) * 27)
        var path = Path()
        path.move(to: start)
        let bend = max(65, abs(end.x - start.x) * 0.5)
        path.addCurve(
          to: end, control1: CGPoint(x: start.x + bend, y: start.y),
          control2: CGPoint(x: end.x - bend, y: end.y))
        context.stroke(path, with: .color(source.kind.tint.opacity(0.14)), lineWidth: 7)
        context.stroke(path, with: .color(source.kind.tint.opacity(0.65)), lineWidth: 1.5)
      }
    }
    .allowsHitTesting(false)
  }
}

struct NodeCard: View {
  @EnvironmentObject var store: Store
  let node: GraphNode
  @State private var dragOrigin: CGPoint?
  var selected: Bool { store.selected == node.id }

  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 9)
        .fill(Palette.panel)
        .overlay(
          RoundedRectangle(cornerRadius: 9)
            .stroke(
              selected ? node.kind.tint.opacity(0.8) : Palette.stroke, lineWidth: selected ? 1.5 : 1
            )
        )
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 8) {
          Image(systemName: node.kind.symbol).foregroundStyle(node.kind.tint).font(
            .system(size: 14))
          Text(node.kind.title).font(.system(size: 12, weight: .semibold))
          Spacer()
          Circle().fill(node.kind.tint.opacity(0.7)).frame(width: 4, height: 4)
        }
        .padding(.horizontal, 14).frame(height: 39)
        .background(node.kind.tint.opacity(selected ? 0.1 : 0.035))
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 3)
            .onChanged { value in
              if dragOrigin == nil {
                store.checkpoint()
                store.selected = node.id
                dragOrigin = CGPoint(x: node.x, y: node.y)
              }
              if let origin = dragOrigin {
                store.move(
                  node.id, x: origin.x + value.translation.width / store.zoom,
                  y: origin.y + value.translation.height / store.zoom)
              }
            }
            .onEnded { _ in dragOrigin = nil })
        Rectangle().fill(Palette.stroke).frame(height: 1)
        VStack(alignment: .leading, spacing: 6) {
          if node.kind == .image {
            Text(node.asset).font(.system(size: 11, weight: .medium))
            Text("1600 × 1100 · RGB").font(.system(size: 8, design: .monospaced))
              .foregroundStyle(Palette.secondary)
          } else if node.kind == .output {
            Text("Final composite").font(.system(size: 10)).foregroundStyle(Palette.secondary)
            Text("PNG / sRGB").font(.system(size: 8, design: .monospaced)).foregroundStyle(
              node.kind.tint)
          } else {
            Text(node.kind.valueLabel(node.value))
              .font(.system(size: 17, weight: .light, design: .monospaced))
              .foregroundStyle(node.kind.tint)
            if node.kind == .blend {
              Text("A + B crossfade").font(.system(size: 8)).foregroundStyle(Palette.secondary)
            }
          }
        }
        .padding(.leading, node.kind.inputs > 0 ? 27 : 14).padding(.top, 13)
        Spacer(minLength: 0)
      }
      .clipShape(RoundedRectangle(cornerRadius: 9))
      ForEach(0..<node.kind.inputs, id: \.self) { input in
        Button {
          store.inputClicked(node.id, input: input)
        } label: {
          Circle()
            .fill(
              store.project.incoming(node.id, input: input) == nil ? Palette.panel : node.kind.tint
            )
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(node.kind.tint, lineWidth: 1.5))
            .frame(width: 28, height: 26).contentShape(Rectangle())
        }
        .buttonStyle(.plain).position(x: 0, y: 65 + Double(input) * 27)
        .help("\(node.kind.title) input \(input == 0 ? "A" : "B")")
        .accessibilityLabel("\(node.kind.title) input \(input == 0 ? "A" : "B")")
      }
      if node.kind != .output {
        Button {
          store.outputClicked(node.id)
        } label: {
          Circle().fill(node.kind.tint).frame(width: 10, height: 10)
            .overlay(
              Circle().stroke(.white.opacity(store.pendingSource == node.id ? 1 : 0), lineWidth: 3)
            )
            .frame(width: 28, height: 26).contentShape(Rectangle())
        }
        .buttonStyle(.plain).position(x: 180, y: 76)
        .help("\(node.kind.title) output — click, then choose an input")
        .accessibilityLabel("\(node.kind.title) output")
      }
    }
    .frame(width: 180, height: 110)
    .onTapGesture { store.selected = node.id }
    .accessibilityIdentifier("node-\(node.kind.rawValue)")
    .contextMenu {
      Button("Select") { store.selected = node.id }
      if node.kind != .output {
        Button("Delete Node") {
          store.selected = node.id
          store.deleteSelected()
        }
      }
    }
  }
}

struct Inspector: View {
  @EnvironmentObject var store: Store

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("INSPECTOR").font(.system(size: 9, weight: .semibold)).tracking(1.5)
        Spacer()
        Image(systemName: "slider.horizontal.3")
      }
      .foregroundStyle(Palette.secondary).padding(20).frame(height: 44)
      Rectangle().fill(Palette.stroke).frame(height: 1)
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          if let node = store.selectedNode {
            title(node)
            if node.kind == .image { sourceControls(node) }
            if node.kind != .image && node.kind != .output { adjustment(node) }
            if node.kind.inputs > 0 { inputs(node) }
            if node.kind == .output { outputDetails }
            if node.kind != .output {
              Button(role: .destructive) {
                store.deleteSelected()
              } label: {
                Label("Delete node", systemImage: "trash")
                  .font(.system(size: 11)).foregroundStyle(Palette.secondary)
              }.buttonStyle(.plain)
            }
          } else {
            Image(systemName: "cursorarrow.rays").font(.system(size: 26, weight: .light))
              .foregroundStyle(Palette.accent)
            Text("Make it yours").font(.system(size: 20, weight: .light))
            Text("Select a node to shape the image. Add new nodes from the graph toolbar.")
              .font(.system(size: 12)).foregroundStyle(Palette.secondary)
          }
        }.padding(20)
      }
      Spacer(minLength: 0)
      VStack(alignment: .leading, spacing: 10) {
        Text("A LITTLE ROOM TO EXPERIMENT").font(.system(size: 8, weight: .semibold)).tracking(1)
        Text("Branch, blend, start again.\nYour source is always safe.")
          .font(.system(size: 11)).lineSpacing(3)
        HStack(spacing: 15) {
          Button {
            store.undo()
          } label: {
            Label("Undo", systemImage: "arrow.uturn.backward")
          }
          .disabled(store.history.isEmpty)
          Button {
            store.redo()
          } label: {
            Image(systemName: "arrow.uturn.forward")
          }
          .disabled(store.future.isEmpty).accessibilityLabel("Redo")
          Spacer()
          Button("Example") { store.newProject(sample: true) }
        }
        .buttonStyle(.plain).font(.system(size: 10))
      }
      .foregroundStyle(Palette.secondary).padding(20)
      .overlay(alignment: .top) { Rectangle().fill(Palette.stroke).frame(height: 1) }
    }
    .background(Palette.panel)
  }

  private func title(_ node: GraphNode) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: node.kind.symbol)
        .font(.system(size: 23, weight: .light))
        .foregroundStyle(node.kind.tint).frame(width: 44, height: 44)
        .background(node.kind.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
      Text(node.kind.title).font(.system(size: 25, weight: .light))
      Text(node.kind.explanation).font(.system(size: 11)).lineSpacing(4)
        .foregroundStyle(Palette.secondary)
    }
  }

  private func sourceControls(_ node: GraphNode) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionLabel("SOURCE LIBRARY")
      ForEach(["Solstice", "Nocturne"], id: \.self) { asset in
        Button {
          store.updateAsset(node.id, asset: asset)
        } label: {
          HStack(spacing: 10) {
            if let image = PrismAssets.images[asset] {
              Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                .frame(width: 53, height: 39).clipped().cornerRadius(4)
            }
            VStack(alignment: .leading, spacing: 4) {
              Text(asset).font(.system(size: 11, weight: .medium))
              Text(asset == "Solstice" ? "Warm / mineral" : "Cool / twilight")
                .font(.system(size: 9)).foregroundStyle(Palette.secondary)
            }
            Spacer()
            if node.asset == asset {
              Image(systemName: "circle.inset.filled").foregroundStyle(node.kind.tint).font(
                .system(size: 9))
            }
          }
          .padding(8).background(
            Palette.raised.opacity(node.asset == asset ? 1 : 0.3),
            in: RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain)
      }
      Text("Original artwork generated for Prism.\nBundled locally, available offline.")
        .font(.system(size: 9)).lineSpacing(3).foregroundStyle(Palette.secondary)
    }
  }

  private func adjustment(_ node: GraphNode) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        sectionLabel(node.kind == .blend ? "MIX AMOUNT" : "AMOUNT")
        Spacer()
        Button("Reset") {
          store.checkpoint()
          store.updateValue(node.id, value: node.kind.defaultValue)
        }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(Palette.secondary)
      }
      Text(node.kind.valueLabel(node.value))
        .font(.system(size: 29, weight: .light, design: .monospaced)).foregroundStyle(
          node.kind.tint)
      Slider(
        value: Binding(get: { node.value }, set: { store.updateValue(node.id, value: $0) }),
        in: node.kind.range,
        onEditingChanged: { if $0 { store.checkpoint() } }
      )
      .tint(node.kind.tint).accessibilityLabel("\(node.kind.title) amount")
      HStack {
        Text(node.kind.valueLabel(node.kind.range.lowerBound))
        Spacer()
        Text(node.kind.valueLabel(node.kind.range.upperBound))
      }
      .font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.secondary)
      HStack {
        Text("Exact value").font(.system(size: 10)).foregroundStyle(Palette.secondary)
        Spacer()
        TextField(
          "Value",
          value: Binding(
            get: { node.value },
            set: {
              store.checkpoint()
              store.updateValue(node.id, value: $0)
            }
          ), format: .number.precision(.fractionLength(0...2))
        )
        .textFieldStyle(.roundedBorder).frame(width: 78)
        .accessibilityLabel("Exact \(node.kind.title.lowercased()) value")
      }
    }
  }

  private func inputs(_ node: GraphNode) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionLabel("CONNECTIONS")
      ForEach(0..<node.kind.inputs, id: \.self) { input in
        let edge = store.project.incoming(node.id, input: input)
        let parent = store.project.nodes.first { $0.id == edge?.source }
        HStack(spacing: 8) {
          Text(input == 0 ? "A" : "B")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(node.kind.tint).frame(width: 15)
          Menu {
            ForEach(store.project.nodes.filter { $0.kind != .output }) { source in
              Button(
                "\(source.kind.title) · \(store.project.nodes.firstIndex(where: { $0.id == source.id })! + 1)"
              ) {
                store.connect(source.id, to: node.id, input: input)
              }
            }
          } label: {
            Text(parent?.kind.title ?? "Choose source")
              .font(.system(size: 11)).frame(maxWidth: .infinity, alignment: .leading)
          }
          .accessibilityLabel("\(node.kind.title) input \(input == 0 ? "A" : "B") source")
          if edge != nil {
            Button {
              store.disconnect(node.id, input: input)
            } label: {
              Image(systemName: "xmark.circle").foregroundStyle(Palette.secondary)
            }.buttonStyle(.plain).help("Disconnect input").accessibilityLabel(
              "Disconnect input \(input)")
          }
        }
      }
      Text("Click a port in the graph, or choose a source here. Loops are safely rejected.")
        .font(.system(size: 10)).foregroundStyle(Palette.secondary).lineSpacing(3)
    }
  }

  private var outputDetails: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionLabel("DELIVERY")
      HStack {
        Text("Dimensions")
        Spacer()
        Text("1600 × 1100")
      }
      HStack {
        Text("Format")
        Spacer()
        Text("PNG · 8-bit")
      }
      HStack {
        Text("Color space")
        Spacer()
        Text("sRGB")
      }
    }
    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text).font(.system(size: 8, weight: .semibold)).tracking(1.4).foregroundStyle(
      Palette.secondary)
  }
}
