import SwiftUI

@main
struct PrismaticApp: App {
  @State private var studio = Studio()
  var body: some Scene {
    WindowGroup {
      StudioView(studio: studio)
        .preferredColorScheme(.dark)
        .tint(Atelier.ivory)
    }
  }
}

enum Atelier {
  static let background = Color(uiColor: ArtRenderer.background)
  static let ivory = Color(red: 0.94, green: 0.91, blue: 0.84)
  static let muted = Color(red: 0.57, green: 0.63, blue: 0.64)
  static let panel = Color(red: 0.08, green: 0.11, blue: 0.12)
}

struct StudioView: View {
  @Bindable var studio: Studio
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var sheet: StudioSheet?
  @State private var showClear = false
  @State private var showNew = false
  @State private var showSave = false
  @State private var title = ""
  @State private var toast: String?
  enum StudioSheet: Identifiable {
    case brushes, symmetry, pigments, gallery
    case share(URL)
    var id: String {
      switch self {
      case .brushes: "brushes"
      case .symmetry: "symmetry"
      case .pigments: "pigments"
      case .gallery: "gallery"
      case .share(let url): url.absoluteString
      }
    }
  }

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        header
        HStack {
          VStack(alignment: .leading, spacing: 5) {
            Text(studio.current.title)
              .font(.system(.title2, design: .serif))
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
            Text(
              studio.current.isSample
                ? "Editable sample" : "Draft autosaved"
            )
            .font(.caption).foregroundStyle(Atelier.muted)
            .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
          Button {
            showNew = true
          } label: {
            Image(systemName: "plus").frame(width: 44, height: 44)
          }
          .accessibilityLabel("New canvas")
        }
        .padding(.horizontal, 26).padding(.top, 26)
        Spacer(minLength: 12)
        ZStack {
          DrawingSurface(strokes: studio.current.strokes, settings: studio.settings) {
            studio.add($0)
          }
          if studio.current.strokes.isEmpty {
            VStack(spacing: 10) {
              Text("Begin anywhere.")
                .font(.system(.title, design: .serif)).foregroundStyle(Atelier.ivory.opacity(0.85))
              Text("A single line. Infinite possibility.")
                .font(.subheadline).foregroundStyle(Atelier.muted)
                .multilineTextAlignment(.center)
            }
            .allowsHitTesting(false)
          }
        }
        .frame(
          width: min(
            geometry.size.width,
            geometry.size.height * (dynamicTypeSize.isAccessibilitySize ? 0.32 : 0.56)),
          height: min(
            geometry.size.width,
            geometry.size.height * (dynamicTypeSize.isAccessibilitySize ? 0.32 : 0.56))
        )
        .clipped()
        .overlay { CanvasCorners().padding(7).allowsHitTesting(false) }
        Spacer(minLength: 12)
        if dynamicTypeSize.isAccessibilitySize {
          ScrollView {
            studioControls
          }
          .scrollIndicators(.visible)
        } else {
          studioControls
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(Atelier.background.ignoresSafeArea())
    .foregroundStyle(Atelier.ivory)
    .overlay(alignment: .top) {
      if let toast {
        Text(toast).font(.subheadline.weight(.medium))
          .padding(.horizontal, 22).padding(.vertical, 12)
          .background(Atelier.ivory, in: Capsule()).foregroundStyle(Atelier.background)
          .padding(.top, 58).allowsHitTesting(false)
      }
    }
    .sheet(item: $sheet, onDismiss: { studio.persist() }) { destination in
      switch destination {
      case .brushes: BrushSheet(studio: studio)
      case .symmetry: SymmetrySheet(studio: studio)
      case .pigments: PigmentSheet(studio: studio)
      case .gallery: GallerySheet(studio: studio)
      case .share(let url): ShareSheet(url: url)
      }
    }
    .alert("Clear this canvas?", isPresented: $showClear) {
      Button("Clear canvas", role: .destructive) { studio.clear() }
      Button("Keep drawing", role: .cancel) {}
    } message: {
      Text("You can undo this. Saved gallery pieces will stay untouched.")
    }
    .alert("Start a new canvas?", isPresented: $showNew) {
      Button("Save & start new") {
        studio.save(title: studio.current.title)
        studio.newCanvas()
      }
      Button("Start without saving", role: .destructive) { studio.newCanvas() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Save this piece to your gallery before starting fresh.")
    }
    .alert("Name your piece", isPresented: $showSave) {
      TextField("Artwork title", text: $title)
      Button("Save to gallery") {
        studio.save(title: title)
        feedback("Saved to your gallery")
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Your canvas stays editable, stroke by stroke.")
    }
    .alert(
      "Studio notice",
      isPresented: Binding(
        get: { studio.errorMessage != nil }, set: { if !$0 { studio.errorMessage = nil } })
    ) {
      Button("OK") { studio.errorMessage = nil }
    } message: {
      Text(studio.errorMessage ?? "")
    }
    .onChange(of: scenePhase) { _, phase in if phase != .active { studio.persist() } }
  }

  private var studioControls: some View {
    VStack(spacing: 0) {
      Text(
        "Next stroke · \(studio.settings.symmetry) \(studio.settings.mirror ? "mirrored" : "radial") axes"
      )
      .font(.caption).foregroundStyle(Atelier.muted)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 24).padding(.bottom, 12)
      pigmentStrip
      toolCapsule.padding(.top, 14)
      actionBar.padding(.top, 13).padding(.bottom, 8)
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      BrandMark().frame(width: 27, height: 27)
      Text("PRISMATIC").font(.system(size: 14, weight: .semibold)).tracking(3)
      Spacer()
      Button {
        sheet = .gallery
      } label: {
        Image(systemName: "square.grid.2x2")
          .frame(width: 44, height: 44)
          .background(Atelier.panel, in: Circle())
      }.accessibilityLabel("Open gallery")
    }
    .padding(.horizontal, 24).padding(.top, 8)
  }

  private var pigmentStrip: some View {
    HStack(spacing: 5) {
      ForEach((Palette(rawValue: studio.settings.palette) ?? .aurora).colors) { pigment in
        Button {
          studio.settings.pigment = pigment.hex
          studio.persist()
          UISelectionFeedbackGenerator().selectionChanged()
        } label: {
          Circle().fill(Color(uiColor: UIColor(hex: pigment.hex)))
            .frame(width: 24, height: 24)
            .padding(5)
            .overlay(
              Circle().stroke(
                studio.settings.pigment == pigment.hex ? Atelier.ivory : .clear, lineWidth: 1)
            )
            .frame(width: 44, height: 44)
        }
        .accessibilityLabel("\(pigment.name) pigment")
        .accessibilityAddTraits(studio.settings.pigment == pigment.hex ? .isSelected : [])
      }
      Button {
        sheet = .pigments
      } label: {
        Image(systemName: "paintpalette").frame(width: 44, height: 44)
      }.accessibilityLabel("Choose palette")
    }
  }

  private var toolCapsule: some View {
    let layout =
      dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
    return layout {
      Button {
        sheet = .brushes
      } label: {
        HStack(spacing: 12) {
          BrushPreview(
            brush: studio.settings.brush, pigment: "263B3C", weight: studio.settings.width
          )
          .frame(width: 34, height: 24)
          Text(studio.settings.brush.title).font(
            .system(.subheadline, design: .rounded).weight(.semibold)
          )
          .fixedSize(horizontal: false, vertical: true)
          Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
        }.frame(maxWidth: .infinity).frame(minHeight: 56).padding(
          .vertical, dynamicTypeSize.isAccessibilitySize ? 10 : 0)
      }.accessibilityLabel("Brush, \(studio.settings.brush.title)")
      if dynamicTypeSize.isAccessibilitySize {
        Rectangle().fill(.black.opacity(0.13)).frame(height: 1).padding(.horizontal, 24)
      } else {
        Rectangle().fill(.black.opacity(0.13)).frame(width: 1, height: 23)
      }
      Button {
        sheet = .symmetry
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "sparkle")
          Text("\(studio.settings.symmetry) axes").font(
            .system(.subheadline, design: .rounded).weight(.semibold))
          Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
        }.frame(maxWidth: .infinity).frame(minHeight: 56).padding(
          .vertical, dynamicTypeSize.isAccessibilitySize ? 10 : 0)
      }.accessibilityLabel("Symmetry, \(studio.settings.symmetry) axes")
    }
    .foregroundStyle(Atelier.background)
    .background(Atelier.ivory, in: RoundedRectangle(cornerRadius: 28))
    .padding(.horizontal, 24)
  }

  private var actionBar: some View {
    HStack(spacing: 2) {
      action("Undo", icon: "arrow.uturn.backward", disabled: !studio.history.canUndo) {
        studio.undo()
      }
      action("Redo", icon: "arrow.uturn.forward", disabled: !studio.history.canRedo) {
        studio.redo()
      }
      action("Clear", icon: "trash", disabled: studio.current.strokes.isEmpty) { showClear = true }
      Spacer(minLength: 0)
      Button {
        title = studio.current.isSample ? "\(studio.current.title) study" : studio.current.title
        showSave = true
      } label: {
        Text("Save").font(.subheadline.weight(.semibold)).fixedSize()
          .frame(minWidth: 60, minHeight: 44)
      }.accessibilityLabel("Save artwork")
      action("Export PNG", icon: "square.and.arrow.up", disabled: studio.current.strokes.isEmpty) {
        do {
          sheet = .share(try ArtRenderer.export(studio.current))
        } catch { studio.errorMessage = "The PNG could not be created. Please try again." }
      }
    }.padding(.horizontal, 25)
  }

  private func action(_ label: String, icon: String, disabled: Bool, perform: @escaping () -> Void)
    -> some View
  {
    Button(action: perform) {
      Image(systemName: icon).font(.system(size: 17)).frame(width: 46, height: 44)
    }.accessibilityLabel(label).disabled(disabled).opacity(disabled ? 0.25 : 1)
  }

  private func feedback(_ text: String) {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    toast = text
    Task {
      try? await Task.sleep(for: .seconds(2))
      toast = nil
    }
  }
}

struct BrandMark: View {
  var body: some View {
    Canvas { context, size in
      for axis in 0..<8 {
        var copy = context
        copy.translateBy(x: size.width / 2, y: size.height / 2)
        copy.rotate(by: .degrees(Double(axis) * 45))
        let rect = CGRect(
          x: -size.width * 0.12, y: -size.height * 0.44, width: size.width * 0.24,
          height: size.height * 0.44)
        copy.stroke(Path(ellipseIn: rect), with: .color(Atelier.ivory), lineWidth: 0.7)
      }
    }.accessibilityHidden(true)
  }
}

struct BrushPreview: View {
  var brush: Brush
  var pigment: String
  var weight: Double = 2.5
  var body: some View {
    Canvas { context, size in
      var path = Path()
      let points = (0...60).map { step in
        let t = Double(step) / 60
        return CGPoint(x: t * size.width, y: size.height * (0.5 + sin(t * .pi * 2) * 0.23))
      }
      path.addLines(points)
      let color = Color(uiColor: UIColor(hex: pigment))
      if brush == .silk {
        context.addFilter(.shadow(color: color.opacity(0.7), radius: 3))
      }
      if brush == .stardust {
        for point in points.enumerated() where point.offset % 5 == 0 {
          context.fill(
            Path(
              ellipseIn: CGRect(
                x: point.element.x - weight / 2, y: point.element.y - weight / 2, width: weight,
                height: weight)),
            with: .color(color))
        }
      } else {
        context.stroke(
          path, with: .color(color),
          style: StrokeStyle(lineWidth: weight, lineCap: .round))
      }
    }.accessibilityHidden(true)
  }
}

struct CanvasCorners: View {
  var body: some View {
    Canvas { context, size in
      for corner in 0..<4 {
        var copy = context
        copy.translateBy(x: corner % 2 == 0 ? 0 : size.width, y: corner < 2 ? 0 : size.height)
        copy.scaleBy(x: corner % 2 == 0 ? 1 : -1, y: corner < 2 ? 1 : -1)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 14))
        path.addLine(to: .zero)
        path.addLine(to: CGPoint(x: 14, y: 0))
        copy.stroke(path, with: .color(Atelier.muted.opacity(0.6)), lineWidth: 0.8)
      }
    }.accessibilityHidden(true)
  }
}

struct ShareSheet: UIViewControllerRepresentable {
  var url: URL
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [url], applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
