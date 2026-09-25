import SwiftUI

enum StudioStyle {
  static let ink = Color(red: 0.18, green: 0.21, blue: 0.20)
  static let muted = Color(red: 0.44, green: 0.46, blue: 0.42)
  static let paper = Color(red: 0.98, green: 0.97, blue: 0.95)
  static let canvas = Color(red: 0.94, green: 0.93, blue: 0.90)
  static let accent = Color(red: 0.79, green: 0.23, blue: 0.14)
  static let line = Color(red: 0.85, green: 0.85, blue: 0.81)

  static func color(_ finish: Finish) -> Color {
    let rgb = finish.rgb
    return Color(red: rgb.0, green: rgb.1, blue: rgb.2)
  }
}

struct StudioView: View {
  @ObservedObject var store: StudioStore
  @State private var cameraView = CameraView.studio
  @State private var cameraCommand = 0
  @State private var zoom = 1.0
  @State private var libraryOpen = false
  @State private var helpOpen = false
  @State private var resetOpen = false
  @State private var projectName = ""
  @State private var exportOpen = false

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        header
        Rectangle().fill(StudioStyle.line).frame(height: 1)
        HStack(spacing: 0) {
          sidebar.frame(width: geometry.size.width > 1100 ? 214 : 184)
          Rectangle().fill(StudioStyle.line).frame(width: 1)
          canvas
          Rectangle().fill(StudioStyle.line).frame(width: 1)
          inspector.frame(width: geometry.size.width > 1100 ? 276 : 248)
        }
        footer
      }
      .background(StudioStyle.paper)
      .foregroundStyle(StudioStyle.ink)
      .font(.system(size: 14))
    }
    .tint(StudioStyle.accent)
    .sheet(isPresented: $libraryOpen) { librarySheet }
    .sheet(isPresented: $helpOpen) { helpSheet }
    .sheet(isPresented: $exportOpen) { exportSheet }
    .alert(
      "Check your model",
      isPresented: Binding(
        get: { store.error != nil },
        set: { if !$0 { store.error = nil } }
      )
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
    .confirmationDialog("Start a new form", isPresented: $resetOpen, titleVisibility: .visible) {
      Button("Empty workplane") { store.newProject() }
      Button("Restore desk organizer") {
        store.reset()
        resetCamera()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Your current work can be recovered with Undo. Save a library copy to keep it.")
    }
  }

  private var header: some View {
    HStack(spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 11).fill(StudioStyle.ink)
        Text("f.").font(.system(size: 34, weight: .medium, design: .serif)).foregroundStyle(
          StudioStyle.paper
        )
        .offset(y: -2)
      }.frame(width: 46, height: 46)
      VStack(alignment: .leading, spacing: 3) {
        Text("FORM FOUNDRY").font(.system(size: 17, weight: .bold)).tracking(2)
        Text("An instrument for everyday objects").font(.system(size: 11)).foregroundStyle(
          StudioStyle.muted)
      }
      Spacer(minLength: 15)
      VStack(spacing: 4) {
        Text(store.project.title).font(.system(size: 15, weight: .semibold))
        HStack(spacing: 5) {
          Circle().fill(Color(red: 0.40, green: 0.53, blue: 0.37)).frame(width: 5, height: 5)
          Text("LOCAL WORKSPACE").font(.system(size: 8, weight: .semibold)).tracking(1.6)
        }.foregroundStyle(StudioStyle.muted)
      }
      Spacer(minLength: 15)
      iconButton("arrow.uturn.backward", label: "Undo", enabled: !store.history.past.isEmpty) {
        store.undo()
      }
      .keyboardShortcut("z", modifiers: .command)
      iconButton("arrow.uturn.forward", label: "Redo", enabled: !store.history.future.isEmpty) {
        store.redo()
      }
      .keyboardShortcut("z", modifiers: [.command, .shift])
      Rectangle().fill(StudioStyle.line).frame(width: 1, height: 26)
      Button {
        projectName = store.project.title
        libraryOpen = true
      } label: {
        Label("Projects", systemImage: "square.stack.3d.up")
      }.buttonStyle(QuietButton())
      Button {
        store.export()
        if store.exportURL != nil && !store.project.solids.isEmpty { exportOpen = true }
      } label: {
        Label("Export OBJ", systemImage: "arrow.up.right")
      }.buttonStyle(AccentButton())
    }.padding(.horizontal, 22).padding(.vertical, 16)
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        eyebrow("ASSEMBLY")
        Spacer()
        Text(String(format: "%02d", store.project.solids.count))
          .font(.system(size: 11, design: .monospaced)).foregroundStyle(StudioStyle.muted)
      }.padding(.bottom, 9)
      Text("The parts make\nthe whole.")
        .font(.system(size: 26, weight: .regular, design: .serif)).lineSpacing(0)
        .padding(.bottom, 21)
      ScrollView {
        VStack(spacing: 4) {
          ForEach(Array(store.project.solids.enumerated()), id: \.element.id) { index, solid in
            Button {
              store.selectedID = solid.id
            } label: {
              HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: solid.profile == .circle ? 12 : 3)
                  .fill(StudioStyle.color(solid.finish))
                  .frame(width: 22, height: 22)
                  .overlay {
                    RoundedRectangle(cornerRadius: solid.profile == .circle ? 12 : 3)
                      .stroke(StudioStyle.ink.opacity(0.15), lineWidth: 1)
                  }
                VStack(alignment: .leading, spacing: 4) {
                  Text(solid.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                  Text("\(number(solid.width)) × \(number(solid.depth)) × \(number(solid.height))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(StudioStyle.muted)
                }
                Spacer(minLength: 0)
                Text(String(format: "%02d", index + 1)).font(.system(size: 8, design: .monospaced))
                  .foregroundStyle(
                    store.selectedID == solid.id ? StudioStyle.accent : StudioStyle.muted)
              }.padding(.horizontal, 9).padding(.vertical, 12)
                .background(store.selectedID == solid.id ? Color.white : Color.clear)
                .overlay(alignment: .leading) {
                  if store.selectedID == solid.id {
                    Rectangle().fill(StudioStyle.accent).frame(width: 2)
                  }
                }
            }.buttonStyle(.plain).accessibilityLabel("Select \(solid.name)")
          }
        }
        if store.project.solids.isEmpty {
          Text("Your first form starts with a profile below.")
            .font(.system(size: 13)).foregroundStyle(StudioStyle.muted).padding(.vertical, 24)
        }
      }
      Rectangle().fill(StudioStyle.line).frame(height: 1).padding(.vertical, 17)
      eyebrow("CREATE A PROFILE").padding(.bottom, 12)
      HStack(spacing: 8) {
        profileButton(.rectangle, symbol: "rectangle")
        profileButton(.circle, symbol: "circle")
      }
      Text("Sketch → dimension → extrude")
        .font(.system(size: 9)).foregroundStyle(StudioStyle.muted).padding(.top, 12)
      HStack {
        Button {
          resetOpen = true
        } label: {
          Label("New", systemImage: "plus")
        }
        Spacer()
        Button {
          helpOpen = true
        } label: {
          Image(systemName: "questionmark.circle")
        }
        .accessibilityLabel("Studio guide")
      }.buttonStyle(QuietButton()).padding(.top, 20)
    }.padding(.horizontal, 16).padding(.vertical, 23)
  }

  private var canvas: some View {
    ZStack {
      StudioScene(
        solids: store.project.solids, selectedID: store.selectedID, cameraView: cameraView,
        cameraCommand: cameraCommand, zoom: zoom, onSelect: { store.selectedID = $0 }
      )
      VStack(spacing: 0) {
        HStack {
          HStack(spacing: 2) {
            ForEach(CameraView.allCases, id: \.self) { mode in
              Button {
                cameraView = mode
                cameraCommand += 1
              } label: {
                Text(mode.rawValue).font(.system(size: 11, weight: .medium))
                  .padding(.horizontal, 12).frame(height: 36)
                  .foregroundStyle(cameraView == mode ? Color.white : StudioStyle.ink)
                  .background(
                    cameraView == mode ? StudioStyle.ink : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7))
              }.buttonStyle(.plain).accessibilityLabel("\(mode.rawValue) view")
            }
          }.padding(4).background(
            StudioStyle.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 11))
          Spacer(minLength: 5)
        }.padding(20)
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 5) {
            Text("OBJECT STUDY").font(.system(size: 9, weight: .semibold)).tracking(2)
            Text(store.project.title).font(.system(size: 12, design: .serif))
          }.foregroundStyle(StudioStyle.muted)
          Spacer()
        }.padding(.horizontal, 23)
        Spacer()
        if store.project.solids.isEmpty {
          VStack(spacing: 10) {
            Text("Make room for an idea.").font(.system(size: 30, design: .serif))
            Text("Choose Rectangle or Ellipse to begin.").foregroundStyle(StudioStyle.muted)
          }
          Spacer()
        }
        HStack(alignment: .bottom) {
          VStack(alignment: .leading, spacing: 7) {
            Text(
              cameraView == .studio
                ? "AXONOMETRIC / MM" : "\(cameraView.rawValue.uppercased()) ORTHOGRAPHIC / MM"
            )
            .font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1.1)
            HStack(spacing: 0) {
              ForEach(0..<11) { index in
                Rectangle().fill(StudioStyle.muted)
                  .frame(width: 1, height: index % 5 == 0 ? 11 : 5)
                  .frame(width: 10, height: 11, alignment: .bottom)
              }
            }
            Text("10 mm grid · drag to orbit").font(.system(size: 9)).foregroundStyle(
              StudioStyle.muted)
          }
          Spacer()
          VStack(spacing: 1) {
            iconButton("plus", label: "Zoom in") {
              zoom = max(0.3, zoom * 0.8)
              cameraCommand += 1
            }
            iconButton("minus", label: "Zoom out") {
              zoom = min(4, zoom * 1.25)
              cameraCommand += 1
            }
            iconButton("viewfinder", label: "Reset camera") { resetCamera() }
          }.padding(3).background(
            StudioStyle.paper.opacity(0.95), in: RoundedRectangle(cornerRadius: 10))
        }.padding(22)
      }
    }.clipped()
  }

  private var inspector: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        HStack {
          eyebrow("SOLID INSPECTOR")
          Spacer()
          Circle().fill(StudioStyle.accent).frame(width: 6, height: 6)
        }
        if let solid = store.selected {
          VStack(alignment: .leading, spacing: 5) {
            Text(solid.name).font(.system(size: 23, weight: .regular, design: .serif)).lineLimit(2)
            Text("\(solid.profile.label.uppercased()) → EXTRUSION")
              .font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1.1)
              .foregroundStyle(StudioStyle.muted)
          }
          ProfileDrawing(solid: solid).frame(height: 118)
          VStack(spacing: 8) {
            numberField("Width", value: solid.width, unit: "mm", key: \.width, step: 5)
            numberField("Depth", value: solid.depth, unit: "mm", key: \.depth, step: 5)
            numberField("Extrude", value: solid.height, unit: "mm", key: \.height, step: 5)
          }
          sectionDivider
          HStack {
            eyebrow("POSITION")
            Spacer()
            Button {
              store.snap.toggle()
            } label: {
              HStack(spacing: 4) {
                Image(systemName: store.snap ? "square.grid.3x3.fill" : "square.grid.3x3")
                Text(store.snap ? "Snap 5" : "Free")
              }.font(.system(size: 10)).foregroundStyle(
                store.snap ? StudioStyle.accent : StudioStyle.muted)
            }.buttonStyle(.plain).accessibilityLabel(
              store.snap ? "Grid snapping on" : "Grid snapping off")
          }
          VStack(spacing: 7) {
            numberField("X", value: solid.x, unit: "mm", key: \.x, step: 5, position: true)
            numberField("Z", value: solid.z, unit: "mm", key: \.z, step: 5, position: true)
            numberField("Lift", value: solid.y, unit: "mm", key: \.y, step: 5, position: true)
            numberField("Rotate", value: solid.rotation, unit: "°", key: \.rotation, step: 15)
          }
          sectionDivider
          HStack {
            eyebrow("MATERIAL")
            Spacer()
            Text(solid.finish.label).font(.system(size: 10)).foregroundStyle(StudioStyle.muted)
          }
          HStack(spacing: 13) {
            ForEach(Finish.allCases, id: \.self) { finish in
              Button {
                store.edit { $0.finish = finish }
              } label: {
                Circle().fill(StudioStyle.color(finish)).frame(width: 27, height: 27)
                  .overlay { Circle().strokeBorder(StudioStyle.ink.opacity(0.15), lineWidth: 1) }
                  .padding(3)
                  .overlay {
                    Circle().stroke(
                      finish == solid.finish ? StudioStyle.ink : Color.clear, lineWidth: 1)
                  }
              }.buttonStyle(.plain).accessibilityLabel("\(finish.label) material")
            }
          }
          HStack {
            Button {
              store.duplicate()
            } label: {
              Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .buttonStyle(QuietButton())
            Spacer(minLength: 0)
            iconButton("trash", label: "Delete selected solid") { store.delete() }
          }
        } else {
          VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "cube.transparent").font(.system(size: 38, weight: .ultraLight))
            Text("A form, waiting.").font(.system(size: 24, design: .serif))
            Text("Select a solid or add a profile to edit its dimensions and material.")
              .font(.system(size: 13)).foregroundStyle(StudioStyle.muted)
          }.padding(.top, 22)
        }
      }.padding(.horizontal, 20).padding(.vertical, 23)
    }
  }

  private var footer: some View {
    HStack(spacing: 8) {
      Circle().fill(StudioStyle.accent).frame(width: 5, height: 5)
      Text(store.status).lineLimit(1)
      Spacer()
      Text("\(store.project.solids.count) solids").fontDesign(.monospaced)
      Rectangle().fill(StudioStyle.line).frame(width: 1, height: 12).padding(.horizontal, 8)
      Text("\(number(store.volume)) cm³ · sum").fontDesign(.monospaced)
      Text("V1.0").font(.system(size: 8, weight: .medium)).padding(.leading, 14)
    }.font(.system(size: 10)).foregroundStyle(StudioStyle.muted)
      .padding(.horizontal, 22).frame(height: 36)
      .background(StudioStyle.paper)
      .overlay(alignment: .top) { Rectangle().fill(StudioStyle.line).frame(height: 1) }
  }

  private var librarySheet: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 24) {
        Text("Keep your ideas.").font(.system(size: 34, design: .serif))
        Text(
          "Save a named snapshot, then reopen it anytime. Your current workspace also saves automatically."
        )
        .foregroundStyle(StudioStyle.muted)
        HStack {
          TextField("Project name", text: $projectName).textFieldStyle(.roundedBorder)
            .accessibilityLabel("Project name")
          Button("Save snapshot") { store.save(named: projectName) }.buttonStyle(AccentButton())
        }
        eyebrow("SAVED PROJECTS")
        if store.savedProjects.isEmpty {
          Text("Your saved forms will appear here.").foregroundStyle(StudioStyle.muted)
        }
        ScrollView {
          VStack(spacing: 10) {
            ForEach(store.savedProjects, id: \.self) { url in
              Button {
                store.open(url)
                libraryOpen = false
                resetCamera()
              } label: {
                HStack {
                  Image(systemName: "cube").font(.system(size: 24, weight: .light))
                  Text(url.deletingPathExtension().lastPathComponent).fontWeight(.medium)
                  Spacer()
                  Text("Open").font(.system(size: 12))
                  Image(systemName: "arrow.up.right")
                }.padding(18).background(Color.white, in: RoundedRectangle(cornerRadius: 10))
              }.buttonStyle(.plain).accessibilityLabel(
                "Open \(url.deletingPathExtension().lastPathComponent)")
            }
          }
        }
      }.padding(28).background(StudioStyle.paper)
        .navigationTitle("Project library").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) { Button("Done") { libraryOpen = false } }
        }
    }.presentationDetents([.large])
  }

  private var exportSheet: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 25) {
          Image(systemName: "cube.transparent").font(.system(size: 46, weight: .ultraLight))
          Text("From form to file.").font(.system(size: 36, design: .serif))
          Text("Your real mesh is ready.").font(.system(size: 18, weight: .medium))
          HStack(spacing: 32) {
            exportStat("\(store.project.solids.count)", label: "SOLIDS")
            exportStat("\(store.exportVertexCount)", label: "VERTICES")
            exportStat("\(store.exportFaceCount)", label: "TRIANGLES")
          }
          Text(
            "Wavefront OBJ · millimeters · Y up\nEach primitive is a separate closed shell. Overlapping objects are not fused."
          )
          .foregroundStyle(StudioStyle.muted).lineSpacing(6)
          .fixedSize(horizontal: false, vertical: true)
          Text("Saved in Files → On My iPad → Form Foundry → Exports → FormFoundry.obj")
            .font(.system(size: 12, design: .monospaced))
            .fixedSize(horizontal: false, vertical: true)
            .padding(18).background(Color.white)
          if let url = store.exportURL {
            ShareLink(item: url) { Label("Share mesh", systemImage: "square.and.arrow.up") }
              .buttonStyle(AccentButton())
          }
        }.padding(30).frame(maxWidth: .infinity, alignment: .leading)
      }.background(StudioStyle.paper)
        .navigationTitle("Export complete").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) { Button("Done") { exportOpen = false } }
        }
    }.presentationDetents([.large])
  }

  private var helpSheet: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text("Small forms.\nReal possibilities.").font(.system(size: 38, design: .serif))
          guide(
            "01", title: "Start with a profile",
            text:
              "Add a rectangle or ellipse. Set width and depth, then use Extrude to set its height. Equal ellipse axes make a circle."
          )
          guide(
            "02", title: "Arrange with intent",
            text:
              "Tap any solid or its assembly row. Edit X, Z and Lift to position it; Rotate turns it around the vertical axis. Snap rounds position edits to 5 mm."
          )
          guide(
            "03", title: "Look from every side",
            text:
              "Drag the canvas to orbit. Pinch or use + / − to zoom. Studio, Top, Front and Right restore precise orthographic views."
          )
          guide(
            "04", title: "Iterate without fear",
            text:
              "Undo and Redo restore modeling changes, including new projects. Projects saves named snapshots. Export creates a real triangulated OBJ mesh."
          )
          Text(
            "A primitive modeler, not a Boolean CAD kernel. Solids remain independent; summed volume includes overlaps. All geometry and files stay on this iPad."
          )
          .font(.system(size: 12)).foregroundStyle(StudioStyle.muted)
        }.padding(30)
      }.background(StudioStyle.paper).navigationTitle("Studio guide").navigationBarTitleDisplayMode(
        .inline
      )
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { helpOpen = false } }
      }
    }
  }

  private func guide(_ index: String, title: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 18) {
      Text(index).font(.system(size: 13, design: .monospaced)).foregroundStyle(StudioStyle.accent)
      VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.system(size: 19, weight: .semibold))
        Text(text).foregroundStyle(StudioStyle.muted).lineSpacing(4)
      }
    }
  }

  private func exportStat(_ value: String, label: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(value).font(.system(size: 30, design: .monospaced))
      eyebrow(label)
    }
  }

  private func numberField(
    _ label: String, value: Double, unit: String, key: WritableKeyPath<Solid, Double>, step: Double,
    position: Bool = false
  ) -> some View {
    DimensionField(label: label, value: value, unit: unit, step: step) {
      store.setNumber($0, key: key, position: position)
    }.id("\(store.selectedID?.uuidString ?? "none")-\(label)")
  }

  private func profileButton(_ profile: Profile, symbol: String) -> some View {
    Button {
      store.add(profile)
    } label: {
      VStack(spacing: 9) {
        Image(systemName: symbol).font(.system(size: 24, weight: .ultraLight))
        Text(profile.label).font(.system(size: 10, weight: .medium))
      }.frame(maxWidth: .infinity).frame(height: 75)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(StudioStyle.line, lineWidth: 1) }
    }.buttonStyle(.plain).accessibilityLabel("Add \(profile.label)")
  }

  private var sectionDivider: some View { Rectangle().fill(StudioStyle.line).frame(height: 1) }

  private func resetCamera() {
    cameraView = .studio
    zoom = 1
    cameraCommand += 1
  }
}

struct DimensionField: View {
  let label: String
  let value: Double
  let unit: String
  let step: Double
  var onCommit: (Double) -> Void
  @State private var text = ""
  @FocusState private var focused: Bool

  var body: some View {
    HStack(spacing: 5) {
      Text(label).font(.system(size: 11, weight: .medium)).frame(width: 47, alignment: .leading)
      Button {
        onCommit(value - step)
      } label: {
        Image(systemName: "minus").font(.system(size: 10, weight: .medium)).frame(
          width: 27, height: 35)
      }.buttonStyle(.plain).accessibilityLabel("Decrease \(label)")
      TextField(label, text: $text)
        .font(.system(size: 13, weight: .medium, design: .monospaced))
        .multilineTextAlignment(.trailing).focused($focused)
        .keyboardType(.numbersAndPunctuation).submitLabel(.done)
        .onSubmit {
          commit()
          focused = false
        }
        .onChange(of: focused) { _, newValue in if !newValue { commit() } }
        .accessibilityLabel("\(label) value")
      Text(unit).font(.system(size: 9)).foregroundStyle(StudioStyle.muted).frame(width: 19)
      Button {
        onCommit(value + step)
      } label: {
        Image(systemName: "plus").font(.system(size: 10, weight: .medium)).frame(
          width: 27, height: 35)
      }.buttonStyle(.plain).accessibilityLabel("Increase \(label)")
    }.padding(.horizontal, 8)
      .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
      .overlay {
        RoundedRectangle(cornerRadius: 6).stroke(
          focused ? StudioStyle.accent : StudioStyle.line, lineWidth: 0.7)
      }
      .onAppear { text = number(value) }
      .onChange(of: value) { _, newValue in text = number(newValue) }
  }

  private func commit() {
    guard let parsed = Double(text), parsed.isFinite else {
      text = number(value)
      return
    }
    onCommit(parsed)
    text = number(value)
  }
}

struct ProfileDrawing: View {
  var solid: Solid

  var body: some View {
    GeometryReader { geometry in
      let maxWidth = geometry.size.width - 74
      let scale = min(maxWidth / solid.width, 64 / solid.depth)
      let width = max(3, solid.width * scale)
      let depth = max(3, solid.depth * scale)
      ZStack {
        StudioStyle.canvas.opacity(0.6)
        Canvas { context, size in
          for x in stride(from: 8.0, to: size.width, by: 10) {
            for y in stride(from: 8.0, to: size.height, by: 10) {
              context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                with: .color(StudioStyle.muted.opacity(0.25)))
            }
          }
        }
        VStack(spacing: 5) {
          Text("\(number(solid.width)) mm").font(.system(size: 9, design: .monospaced))
          HStack(spacing: 6) {
            if solid.profile == .rectangle {
              Rectangle().fill(StudioStyle.accent.opacity(0.08))
                .overlay { Rectangle().stroke(StudioStyle.accent, lineWidth: 1.2) }
                .frame(width: width, height: depth)
            } else {
              Ellipse().fill(StudioStyle.accent.opacity(0.08))
                .overlay { Ellipse().stroke(StudioStyle.accent, lineWidth: 1.2) }
                .frame(width: width, height: depth)
            }
            Text(number(solid.depth)).font(.system(size: 9, design: .monospaced)).foregroundStyle(
              StudioStyle.accent)
          }
        }.foregroundStyle(StudioStyle.accent)
      }.clipShape(RoundedRectangle(cornerRadius: 7))
    }
  }
}

struct QuietButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 12, weight: .medium))
      .padding(.horizontal, 10).frame(minHeight: 38)
      .foregroundStyle(StudioStyle.ink)
      .background(
        configuration.isPressed ? StudioStyle.line.opacity(0.5) : Color.clear,
        in: RoundedRectangle(cornerRadius: 7))
  }
}

struct AccentButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 12, weight: .semibold))
      .padding(.horizontal, 16).frame(minHeight: 40)
      .foregroundStyle(Color.white)
      .background(
        StudioStyle.accent.opacity(configuration.isPressed ? 0.7 : 1),
        in: RoundedRectangle(cornerRadius: 8))
  }
}

func eyebrow(_ text: String) -> some View {
  Text(text).font(.system(size: 9, weight: .semibold)).tracking(1.7).foregroundStyle(
    StudioStyle.muted)
}

func number(_ value: Double) -> String {
  value.formatted(.number.precision(.fractionLength(0...1)))
}

func iconButton(_ symbol: String, label: String, enabled: Bool = true, action: @escaping () -> Void)
  -> some View
{
  Button(action: action) {
    Image(systemName: symbol).font(.system(size: 15, weight: .regular))
      .frame(width: 34, height: 36)
  }.buttonStyle(.plain).foregroundStyle(StudioStyle.ink.opacity(enabled ? 1 : 0.25))
    .disabled(!enabled).accessibilityLabel(label)
}
