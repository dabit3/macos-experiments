import SwiftUI
import UIKit

@main
struct TerraTableApp: App {
  var body: some Scene {
    WindowGroup {
      StudioView()
        .preferredColorScheme(.light)
        .statusBarHidden()
    }
  }
}

private enum Palette {
  static let paper = Color(red: 0.965, green: 0.960, blue: 0.936)
  static let studio = Color(red: 0.947, green: 0.941, blue: 0.909)
  static let ink = Color(red: 0.17, green: 0.23, blue: 0.19)
  static let muted = Color(red: 0.41, green: 0.45, blue: 0.40)
  static let green = Color(red: 0.23, green: 0.37, blue: 0.28)
  static let line = Color(red: 0.85, green: 0.86, blue: 0.81)
}

struct StudioView: View {
  @StateObject private var model = StudioModel()
  @StateObject private var capture = SceneCapture()
  @State private var libraryOpen = false
  @State private var exportOpen = false
  @State private var helpOpen = false
  @State private var exportedURL: URL?
  @State private var exportMessage = ""

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        header
        Rectangle().fill(Palette.line).frame(height: 1)
        HStack(spacing: 0) {
          sidebar.frame(width: geometry.size.width > 1050 ? 245 : 215)
          Rectangle().fill(Palette.line).frame(width: 1)
          workspace
        }
        footer
      }
      .background(Palette.paper)
      .foregroundStyle(Palette.ink)
      .tint(Palette.green)
      .font(.system(size: 15))
    }
    .sheet(isPresented: $libraryOpen) { library }
    .sheet(isPresented: $exportOpen) { exportSheet }
    .sheet(isPresented: $helpOpen) { guide }
    .alert(
      "Something needs attention",
      isPresented: Binding(
        get: { model.error != nil }, set: { if !$0 { model.error = nil } }
      )
    ) {
      Button("Continue", role: .cancel) { model.error = nil }
    } message: {
      Text(model.error ?? "")
    }
    .onReceive(
      NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
    ) {
      _ in
      model.end()
      model.persist()
    }
  }

  private var header: some View {
    HStack(spacing: 15) {
      ZStack {
        RoundedRectangle(cornerRadius: 14).fill(Palette.green).frame(width: 46, height: 46)
        Image(systemName: "mountain.2").font(.system(size: 25, weight: .light)).foregroundStyle(
          .white)
      }
      VStack(alignment: .leading, spacing: 1) {
        Text("TERRA TABLE").font(.system(size: 12, weight: .semibold)).tracking(3)
        Text("A little world, shaped by you.").font(.system(size: 12)).foregroundStyle(
          Palette.muted)
      }
      Spacer()
      HStack(spacing: 2) {
        iconButton("arrow.uturn.backward", "Undo", disabled: model.history.undoStack.isEmpty) {
          model.undo()
        }
        iconButton("arrow.uturn.forward", "Redo", disabled: model.history.redoStack.isEmpty) {
          model.redo()
        }
      }
      Rectangle().fill(Palette.line).frame(width: 1, height: 28).padding(.horizontal, 4)
      Button {
        libraryOpen = true
      } label: {
        Label("My landscapes", systemImage: "square.stack.3d.up")
      }.buttonStyle(QuietButton())
      Button {
        model.save()
      } label: {
        Label("Save", systemImage: "bookmark")
      }.buttonStyle(QuietButton())
        .keyboardShortcut("s", modifiers: .command)
      Button {
        exportedURL = nil
        exportMessage = ""
        exportOpen = true
      } label: {
        Label("Export", systemImage: "square.and.arrow.up")
      }.buttonStyle(FilledButton())
    }
    .padding(.horizontal, 25).frame(height: 84)
  }

  private var sidebar: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
          eyebrow("THE SCULPTING STUDIO")
          Text("Make room\nfor wonder.")
            .font(.system(size: 30, weight: .regular, design: .serif))
            .lineSpacing(-1)
          Text("Build a peak. Carve a passage.\nLet the water find its way.")
            .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
        }
        VStack(alignment: .leading, spacing: 11) {
          eyebrow("01  /  SHAPE")
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(Brush.allCases, id: \.self) { brush in
              Button {
                model.brush = brush
              } label: {
                VStack(spacing: 7) {
                  Image(systemName: symbol(brush)).font(.system(size: 22, weight: .light))
                  Text(brush.rawValue).font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity).frame(height: 69)
                .foregroundStyle(model.brush == brush ? .white : Palette.ink)
                .background(model.brush == brush ? Palette.green : Color.white.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(
                  RoundedRectangle(cornerRadius: 11).stroke(
                    model.brush == brush ? Palette.green : Palette.line, lineWidth: 1))
              }
              .buttonStyle(.plain).accessibilityIdentifier("brush\(brush.rawValue)")
              .accessibilityAddTraits(model.brush == brush ? .isSelected : [])
            }
          }
        }
        VStack(spacing: 15) {
          parameter("Radius", value: String(format: "%.1f", model.radius)) {
            Slider(value: $model.radius, in: 0.35...2.5).accessibilityLabel("Brush radius")
          }
          parameter("Strength", value: "\(Int(model.strength * 100))%") {
            Slider(value: $model.strength, in: 0.1...1).accessibilityLabel("Brush strength")
          }
        }.opacity(model.brush == .orbit ? 0.45 : 1).disabled(model.brush == .orbit)
        Rectangle().fill(Palette.line).frame(height: 1)
        VStack(alignment: .leading, spacing: 11) {
          eyebrow("02  /  START SOMEWHERE")
          ForEach(Landscape.allCases, id: \.self) { preset in
            Button {
              model.preset(preset)
            } label: {
              HStack(spacing: 10) {
                LandscapeSwatch(landscape: preset).frame(width: 47, height: 43)
                  .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                  Text(preset.rawValue).font(.system(size: 12, weight: .semibold))
                  Text(preset.subtitle).font(.system(size: 9)).foregroundStyle(Palette.muted)
                    .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
              }
              .padding(6).frame(maxWidth: .infinity, alignment: .leading)
              .background(model.terrain.landscape == preset ? Palette.line.opacity(0.32) : .clear)
              .clipShape(RoundedRectangle(cornerRadius: 11))
            }.buttonStyle(.plain).accessibilityLabel("Load \(preset.rawValue) preset")
          }
        }
        Button {
          helpOpen = true
        } label: {
          Label("A field guide", systemImage: "book.closed").font(.system(size: 12))
        }.buttonStyle(.plain).padding(.bottom, 8)
      }.padding(22)
    }
    .scrollIndicators(.hidden)
  }

  private var workspace: some View {
    VStack(spacing: 0) {
      ZStack(alignment: .topLeading) {
        TerrainCanvas(model: model, capture: capture)
        VStack {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
              eyebrow("LIVE DIORAMA   /   81 × 81")
              Text(model.terrain.title)
                .font(.system(size: 28, weight: .regular, design: .serif))
              Text("A study in land & water").font(.system(size: 12))
                .foregroundStyle(Palette.muted)
            }
            Spacer()
            HStack(spacing: 0) {
              modeButton("Natural", selected: !model.contours) { model.contours = false }
              modeButton("Contours", selected: model.contours) { model.contours = true }
            }
            .padding(4).background(Palette.paper.opacity(0.95))
            .clipShape(Capsule())
          }.padding(25)
          Spacer()
          HStack(alignment: .bottom) {
            HStack(spacing: 7) {
              Image(systemName: model.brush == .orbit ? "hand.draw" : "hand.point.up.left")
              Text(
                model.brush == .orbit
                  ? "Drag to orbit · pinch to zoom"
                  : "Drag on the island to \(model.brush.rawValue.lowercased())")
            }
            .font(.system(size: 11)).foregroundStyle(Palette.muted)
            .padding(.horizontal, 13).padding(.vertical, 9)
            .background(Palette.paper.opacity(0.95)).clipShape(Capsule())
            Spacer()
            HStack(spacing: 0) {
              iconButton("minus", "Zoom out", disabled: model.zoom <= 0.7) {
                model.zoom = max(0.7, model.zoom - 0.15)
                model.status = "View scale \(Int(model.zoom * 100))%"
              }
              iconButton("plus", "Zoom in", disabled: model.zoom >= 1.8) {
                model.zoom = min(1.8, model.zoom + 0.15)
                model.status = "View scale \(Int(model.zoom * 100))%"
              }
              Rectangle().fill(Palette.line).frame(width: 1, height: 20)
              iconButton("viewfinder", "Reset view") {
                model.zoom = 1
                model.homeRevision += 1
                model.status = "Studio view restored · 100%"
              }
            }.background(Palette.paper.opacity(0.95)).clipShape(Capsule())
          }.padding(.horizontal, 25).padding(.bottom, 18)
        }
      }
      waterPanel
    }.background(Palette.studio)
  }

  private var waterPanel: some View {
    HStack(spacing: 25) {
      VStack(alignment: .leading, spacing: 6) {
        eyebrow("03  /  FIND THE SHORE")
        HStack(alignment: .firstTextBaseline, spacing: 7) {
          Text("Waterline").font(.system(size: 21, design: .serif))
          Text("\(Int(model.terrain.water * 1000)) m")
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.green).contentTransition(.numericText())
        }
      }
      VStack(spacing: 1) {
        Slider(
          value: Binding(get: { model.terrain.water }, set: { model.setWater($0) }),
          in: 0...0.85,
          onEditingChanged: { editing in editing ? model.begin() : model.end() }
        ).tint(Color(red: 0.18, green: 0.52, blue: 0.52)).accessibilityLabel("Water level")
        HStack {
          Text("LOW TIDE")
          Spacer()
          Text("HIGH WATER")
        }.font(.system(size: 8, weight: .medium)).tracking(1).foregroundStyle(Palette.muted)
      }.frame(maxWidth: .infinity)
      Rectangle().fill(Palette.line).frame(width: 1, height: 42)
      metric("\(model.terrain.landPercent)%", caption: "LAND")
      metric("\(model.terrain.summit)m", caption: "SUMMIT")
    }
    .padding(.horizontal, 25).padding(.vertical, 24)
    .background(Palette.paper)
    .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
  }

  private var footer: some View {
    HStack(spacing: 7) {
      Circle().fill(Palette.green).frame(width: 5, height: 5)
      Text(model.status).lineLimit(1)
      Spacer()
      Text("LOCAL FIRST").tracking(1.3)
      Text("·")
      Text("Heightfield no. 042")
    }
    .font(.system(size: 10)).foregroundStyle(Palette.muted)
    .padding(.horizontal, 25).frame(height: 34)
    .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
  }

  private var library: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text("Small worlds, kept safe.")
            .font(.system(size: 30, design: .serif)).padding(.top, 14)
          Text(
            "Snapshots stay on this iPad. Your current landscape also saves automatically after every edit."
          )
          .foregroundStyle(Palette.muted)
          if model.saved.isEmpty {
            ContentUnavailableView(
              "Your collection starts here", systemImage: "square.stack.3d.up",
              description: Text(
                "Close this panel and tap Save to keep a snapshot of your landscape."))
          }
          ForEach(model.saved) { world in
            Button {
              model.reopen(world)
              libraryOpen = false
            } label: {
              HStack(spacing: 17) {
                LandscapeSwatch(landscape: world.terrain.landscape, terrain: world.terrain)
                  .frame(width: 96, height: 80).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 6) {
                  Text(world.terrain.title).font(.system(size: 20, design: .serif))
                  Text(world.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
                  Text(
                    "\(world.terrain.landPercent)% land · water \(Int(world.terrain.water * 1000))m"
                  )
                  .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
              }.padding(12).background(.white.opacity(0.8)).clipShape(
                RoundedRectangle(cornerRadius: 16))
            }.buttonStyle(.plain).accessibilityLabel("Reopen \(world.terrain.title)")
          }
        }.padding(28)
      }
      .background(Palette.paper).foregroundStyle(Palette.ink)
      .navigationTitle("My landscapes").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { libraryOpen = false } }
      }
    }.tint(Palette.green)
  }

  private var exportSheet: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 23) {
        Image(systemName: "square.and.arrow.up").font(.system(size: 34, weight: .ultraLight))
        Text("Take your world with you.").font(.system(size: 31, design: .serif))
        Text(
          "Export the editable surface as a real triangle mesh, or keep a portrait of your diorama."
        )
        .foregroundStyle(Palette.muted)
        Button {
          exportedURL = model.exportMesh()
          exportMessage = "OBJ ready · 6,561 vertices · 12,800 triangles"
        } label: {
          Label("Export terrain mesh (.obj)", systemImage: "cube.transparent")
            .frame(maxWidth: .infinity)
        }.buttonStyle(FilledButton())
        Button {
          do {
            exportedURL = try capture.exportImage()
            exportMessage = "PNG ready · current camera & display mode"
          } catch { model.error = error.localizedDescription }
        } label: {
          Label("Export diorama image (.png)", systemImage: "photo")
            .frame(maxWidth: .infinity)
        }.buttonStyle(QuietButton())
        if let exportedURL {
          Label(exportMessage, systemImage: "checkmark.circle")
            .font(.system(size: 13)).foregroundStyle(Palette.green)
          ShareLink(item: exportedURL) {
            Label("Share or Save to Files", systemImage: "square.and.arrow.up")
          }.buttonStyle(QuietButton())
        }
        Text(
          "Files are saved in Terra Table → Exports in the Files app. Mesh includes the terrain surface; water and plinth are presentation only."
        )
        .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
        Spacer()
      }.padding(32).background(Palette.paper).foregroundStyle(Palette.ink)
        .navigationTitle("Export").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) { Button("Done") { exportOpen = false } }
        }
    }.tint(Palette.green)
  }

  private var guide: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Text("A field guide to making worlds").font(.system(size: 32, design: .serif))
          guideStep(
            "01", "Shape the land",
            "Select Raise and drag across the island. Carve lowers the surface; Smooth softens a rough ridge. A larger radius shapes broader slopes."
          )
          guideStep(
            "02", "Let the water in",
            "Move Waterline right to flood low ground. Water is a level surface, so low basins become lakes as well as the sea."
          )
          guideStep(
            "03", "Find your perspective",
            "Select Orbit, then drag left or right to rotate and up or down to tilt. Pinch or use + / − to zoom. The viewfinder restores the studio view."
          )
          guideStep(
            "04", "Read the landscape",
            "Contours draw elevation bands every 50 illustrative metres. Natural restores the moss, sand and alpine stone palette."
          )
          guideStep(
            "05", "Keep experimenting",
            "Each stroke, water adjustment and preset is one undo step. Save keeps a snapshot in My landscapes. Export makes an actual OBJ mesh or PNG image."
          )
          Text(
            "The metres are illustrative: this is a creative heightfield model, without erosion, water flow or overhangs. Everything works offline."
          )
          .font(.system(size: 12)).foregroundStyle(Palette.muted)
        }.padding(30)
      }.background(Palette.paper).foregroundStyle(Palette.ink)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) { Button("Done") { helpOpen = false } }
        }
    }.tint(Palette.green)
  }

  private func guideStep(_ number: String, _ title: String, _ detail: String) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Text(number).font(.system(size: 14, design: .monospaced)).foregroundStyle(Palette.green)
      VStack(alignment: .leading, spacing: 7) {
        Text(title).font(.system(size: 20, design: .serif))
        Text(detail).font(.system(size: 14)).foregroundStyle(Palette.muted).lineSpacing(4)
      }
    }
  }

  private func symbol(_ brush: Brush) -> String {
    switch brush {
    case .raise: return "mountain.2"
    case .lower: return "arrow.down.to.line"
    case .smooth: return "water.waves"
    case .orbit: return "rotate.3d"
    }
  }

  private func eyebrow(_ text: String) -> some View {
    Text(text).font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(
      Palette.muted)
  }

  private func metric(_ value: String, caption: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(value).font(.system(size: 23, design: .serif)).monospacedDigit()
      Text(caption).font(.system(size: 8, weight: .semibold)).tracking(1.4).foregroundStyle(
        Palette.muted)
    }
  }

  private func parameter<Control: View>(
    _ title: String, value: String, @ViewBuilder control: () -> Control
  ) -> some View {
    VStack(spacing: 3) {
      HStack {
        Text(title).font(.system(size: 12, weight: .medium))
        Spacer()
        Text(value).font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted)
      }
      control()
    }
  }

  private func modeButton(_ title: String, selected: Bool, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Text(title).font(.system(size: 12, weight: .medium)).padding(.horizontal, 16).padding(
        .vertical, 11
      )
      .background(selected ? Palette.green : .clear)
      .foregroundStyle(selected ? .white : Palette.muted).clipShape(Capsule())
    }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func iconButton(
    _ symbol: String, _ label: String, disabled: Bool = false, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 16)).frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityLabel(label).disabled(disabled).opacity(disabled ? 0.28 : 1)
  }
}

private struct QuietButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 13, weight: .medium))
      .padding(.horizontal, 14).frame(height: 43)
      .background(configuration.isPressed ? Palette.line : Color.white.opacity(0.7))
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
  }
}

private struct FilledButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 13, weight: .medium))
      .padding(.horizontal, 17).frame(height: 43).foregroundStyle(.white)
      .background(Palette.green.opacity(configuration.isPressed ? 0.8 : 1))
      .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}

private struct LandscapeSwatch: View {
  let landscape: Landscape
  var terrain: Terrain?

  var body: some View {
    Canvas { context, size in
      let field = terrain ?? Terrain(landscape: landscape)
      let n = Terrain.resolution
      let cell = CGSize(width: size.width / CGFloat(n), height: size.height / CGFloat(n))
      for z in stride(from: 0, to: n, by: 2) {
        for x in stride(from: 0, to: n, by: 2) {
          let h = field.heights[z * n + x]
          let color: Color =
            h < field.water
            ? Color(red: 0.29, green: 0.63, blue: 0.62)
            : Color(
              red: Double(0.30 + h * 0.40), green: Double(0.40 + h * 0.35),
              blue: Double(0.23 + h * 0.43))
          context.fill(
            Path(
              CGRect(
                x: CGFloat(x) * cell.width, y: CGFloat(z) * cell.height,
                width: cell.width * 2 + 0.5, height: cell.height * 2 + 0.5)), with: .color(color))
        }
      }
    }.accessibilityHidden(true)
  }
}
