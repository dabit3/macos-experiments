import KerfCore
import SwiftUI

enum Palette {
  static let chrome = Color(red: 0.105, green: 0.125, blue: 0.135)
  static let panel = Color(red: 0.13, green: 0.15, blue: 0.16)
  static let muted = Color(red: 0.60, green: 0.65, blue: 0.66)
  static let amber = Color(red: 0.98, green: 0.72, blue: 0.32)
  static let blue = Color(red: 0.41, green: 0.66, blue: 0.86)
  static let line = Color.white.opacity(0.09)
}

struct Workspace: View {
  @ObservedObject var editor: Editor
  @State private var confirmReset = false

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider().overlay(Palette.line)
      HStack(spacing: 0) {
        library.frame(width: 212)
        VStack(spacing: 0) {
          tools
          ZStack(alignment: .bottom) {
            FabricationCanvas(editor: editor)
            HStack(spacing: 8) {
              Image(systemName: editor.tool == .select ? "cursorarrow" : editor.tool.symbol)
              Text(toolHint).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Color(red: 0.23, green: 0.29, blue: 0.29))
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(.regularMaterial, in: Capsule())
            .padding(.bottom, 16)
            .allowsHitTesting(false)
          }
        }
        inspector.frame(width: 264)
      }
      footer
    }
    .background(Palette.chrome)
    .foregroundStyle(.white.opacity(0.92))
    .alert("Restore the studio sample?", isPresented: $confirmReset) {
      Button("Restore sample", action: editor.reset)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Your current design can be recovered with Undo.")
    }
    .alert(
      "Kerf",
      isPresented: Binding(get: { editor.notice != nil }, set: { if !$0 { editor.notice = nil } })
    ) {
      Button("OK") { editor.notice = nil }
    } message: {
      Text(editor.notice ?? "")
    }
  }

  var toolHint: String {
    switch editor.tool {
    case .select: "Drag to move  ·  Corner handle to resize  ·  Arrow keys to nudge"
    case .rectangle: "Drag on the sheet to draw a rectangle  ·  Esc to cancel"
    case .circle: "Drag on the sheet to draw a circle  ·  Esc to cancel"
    case .polyline: "Click to add vertices  ·  Return or double-click to finish  ·  Esc to cancel"
    }
  }

  var header: some View {
    HStack(spacing: 20) {
      HStack(spacing: 10) {
        Image(systemName: "square.stack.3d.up").font(.system(size: 23, weight: .light))
          .foregroundStyle(Palette.amber)
        Text("kerf").font(.system(size: 30, weight: .semibold, design: .rounded)).tracking(-1.5)
        Text("STUDIO").font(.system(size: 8, weight: .bold)).tracking(2).foregroundStyle(
          Palette.muted
        ).offset(y: 6)
      }
      .frame(width: 190, alignment: .leading)
      Rectangle().fill(Palette.line).frame(width: 1, height: 28)
      VStack(alignment: .leading, spacing: 4) {
        Text(editor.design.title).font(.system(size: 14, weight: .medium))
        HStack(spacing: 5) {
          Circle().fill(Color(red: 0.46, green: 0.76, blue: 0.6)).frame(width: 4, height: 4)
          Text("LOCAL WORKSPACE").font(.system(size: 8, weight: .semibold)).tracking(1.4)
          Text(" /  autosaved").font(.system(size: 10)).foregroundStyle(Palette.muted)
        }
      }
      Spacer(minLength: 0)
      iconButton("Open design", symbol: "folder", action: editor.open)
      iconButton("Save design", symbol: "square.and.arrow.down", action: editor.save)
      Button(action: editor.exportSVG) {
        HStack(spacing: 8) {
          Text("Export SVG").font(.system(size: 12, weight: .semibold))
          Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(Palette.chrome)
        .padding(.horizontal, 17).padding(.vertical, 11)
        .background(Palette.amber, in: RoundedRectangle(cornerRadius: 7))
      }.buttonStyle(.plain).accessibilityIdentifier("export-svg")
    }
    .padding(.leading, 22).padding(.trailing, 20).padding(.top, 25).padding(.bottom, 17)
  }

  var library: some View {
    VStack(alignment: .leading, spacing: 0) {
      sectionTitle("PROJECT", trailing: "01").padding(.bottom, 16)
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Image(systemName: "square.3.layers.3d").foregroundStyle(Palette.amber)
          Text("Material sheet").font(.system(size: 12, weight: .semibold))
        }
        Text("\(Int(editor.design.sheetWidth)) × \(Int(editor.design.sheetHeight)) mm")
          .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted)
        Text("3 mm  /  \(editor.design.material)").font(.system(size: 10)).foregroundStyle(
          Palette.muted)
      }
      .frame(maxWidth: .infinity, alignment: .leading).padding(13)
      .background(Palette.panel, in: RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.line))
      .padding(.bottom, 26)
      sectionTitle("OBJECTS", trailing: String(format: "%02d", editor.design.parts.count)).padding(
        .bottom, 12)
      ScrollView {
        VStack(spacing: 4) {
          ForEach(editor.design.parts) { part in
            Button {
              editor.selected = part.id
              editor.tool = .select
            } label: {
              HStack(spacing: 10) {
                Image(
                  systemName: part.kind == .circle
                    ? "circle" : part.kind == .rectangle ? "rectangle" : "waveform.path"
                )
                .font(.system(size: 13)).frame(width: 16)
                .foregroundStyle(part.operation == .cut ? Palette.amber : Palette.blue)
                VStack(alignment: .leading, spacing: 4) {
                  Text(part.name).font(.system(size: 10, weight: .medium)).lineLimit(1)
                  Text(part.operation.rawValue.uppercased()).font(
                    .system(size: 7, weight: .semibold)
                  ).tracking(1.2)
                    .foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                if editor.overlaps.contains(part.id) || editor.design.outOfBounds.contains(part.id)
                {
                  Image(systemName: "exclamationmark.circle.fill").font(.system(size: 10))
                    .foregroundStyle(.orange)
                }
              }
              .padding(.horizontal, 10).padding(.vertical, 11)
              .background(
                editor.selected == part.id ? Color.white.opacity(0.08) : .clear,
                in: RoundedRectangle(cornerRadius: 6)
              )
              .overlay(alignment: .leading) {
                if editor.selected == part.id {
                  Rectangle().fill(Palette.amber).frame(width: 2).padding(.vertical, 9)
                }
              }
            }
            .buttonStyle(.plain).accessibilityLabel("Select \(part.name)")
          }
        }
      }
      Spacer(minLength: 12)
      VStack(alignment: .leading, spacing: 12) {
        sectionTitle("QUICK ADD")
        HStack(spacing: 8) {
          quickAdd("Coaster", symbol: "circle", kind: .circle)
          quickAdd("Panel", symbol: "rectangle", kind: .rectangle)
        }
        Button("Restore studio sample") { confirmReset = true }
          .font(.system(size: 10)).foregroundStyle(Palette.muted).buttonStyle(.plain)
          .padding(.top, 5)
      }
    }
    .padding(.horizontal, 16).padding(.vertical, 22)
    .background(Palette.chrome)
  }

  var tools: some View {
    HStack(spacing: 4) {
      ForEach(EditorTool.allCases, id: \.self) { tool in
        Button {
          editor.tool = tool
        } label: {
          Image(systemName: tool.symbol).font(.system(size: 14, weight: .medium))
            .foregroundStyle(editor.tool == tool ? Palette.amber : .white.opacity(0.75))
            .frame(width: 36, height: 34)
            .background(
              editor.tool == tool ? Color.white.opacity(0.09) : .clear,
              in: RoundedRectangle(cornerRadius: 5))
        }.buttonStyle(.plain).help(tool.rawValue).accessibilityLabel("\(tool.rawValue) tool")
      }
      Rectangle().fill(Palette.line).frame(width: 1, height: 20).padding(.horizontal, 9)
      Button {
        editor.snap.toggle()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "grid")
          Text("5 mm").font(.system(size: 10, design: .monospaced))
        }.foregroundStyle(editor.snap ? Palette.amber : Palette.muted).padding(8)
      }.buttonStyle(.plain).help("Toggle 5 mm grid snapping").accessibilityLabel("Grid snap")
      Spacer(minLength: 2)
      Button {
        editor.preview.toggle()
      } label: {
        HStack(spacing: 5) {
          Image(systemName: editor.preview ? "square.3.layers.3d" : "square.dashed")
          Text(editor.preview ? "Material" : "Draft").font(.system(size: 10, weight: .medium))
        }.foregroundStyle(editor.preview ? Palette.amber : .white.opacity(0.8)).padding(7)
      }.buttonStyle(.plain).accessibilityLabel("Toggle material preview")
      iconButton("Zoom out", symbol: "minus") { editor.zoom = max(0.5, editor.zoom - 0.2) }
      Button("\(Int(editor.zoom * 100))%") { editor.zoom = 1 }
        .font(.system(size: 10, design: .monospaced)).buttonStyle(.plain).help("Fit sheet")
        .accessibilityLabel("Fit sheet")
      iconButton("Zoom in", symbol: "plus") { editor.zoom = min(2.5, editor.zoom + 0.2) }
    }
    .padding(.horizontal, 12).frame(height: 52)
    .background(Palette.panel)
  }

  var inspector: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        sectionTitle("INSPECTOR", trailing: "mm")
        if let part = editor.part {
          selectionInspector(part)
        } else {
          VStack(alignment: .leading, spacing: 9) {
            Image(systemName: "cursorarrow.rays").font(.system(size: 24)).foregroundStyle(
              Palette.amber)
            Text("Make something precise.").font(.system(size: 17, weight: .medium))
            Text("Select a part or draw on the sheet to edit its geometry.").font(.system(size: 11))
              .foregroundStyle(Palette.muted)
          }.padding(.vertical, 16)
        }
        Divider().overlay(Palette.line)
        sheetInspector
        Divider().overlay(Palette.line)
        preflight
      }.padding(20)
    }.background(Palette.panel)
  }

  func selectionInspector(_ part: Part) -> some View {
    VStack(alignment: .leading, spacing: 17) {
      VStack(alignment: .leading, spacing: 7) {
        Text(part.kind.rawValue.uppercased()).font(.system(size: 8, weight: .semibold)).tracking(
          1.6
        ).foregroundStyle(Palette.amber)
        TextField(
          "Part name",
          text: Binding(
            get: { editor.part?.name ?? "" }, set: { value in editor.editPart { $0.name = value } })
        )
        .font(.system(size: 17, weight: .medium)).textFieldStyle(.plain)
        .accessibilityIdentifier("part-name")
      }
      HStack(spacing: 8) {
        ForEach(Operation.allCases, id: \.self) { op in
          Button {
            editor.editPart { $0.operation = op }
          } label: {
            HStack(spacing: 6) {
              Circle().fill(op == .cut ? Palette.amber : Palette.blue).frame(width: 5, height: 5)
              Text(op.rawValue.capitalized).font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(
              part.operation == op ? Color.white.opacity(0.1) : Color.black.opacity(0.1),
              in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 6).strokeBorder(
                part.operation == op ? Palette.muted.opacity(0.5) : Palette.line))
          }.buttonStyle(.plain).accessibilityLabel("Set layer \(op.rawValue)")
        }
      }
      sectionTitle("POSITION")
      HStack(spacing: 10) {
        NumericField(label: "X", value: part.x) { value in editor.editPart { $0.x = value } }
        NumericField(label: "Y", value: part.y) { value in editor.editPart { $0.y = value } }
      }
      sectionTitle("DIMENSIONS")
      HStack(spacing: 10) {
        NumericField(label: part.kind == .circle ? "Diameter" : "Width", value: part.width) {
          value in
          editor.editPart {
            $0.width = value
            if $0.kind == .circle { $0.height = value }
          }
        }
        if part.kind != .circle {
          NumericField(label: "Height", value: part.height) { value in
            editor.editPart { $0.height = value }
          }
        }
      }
      HStack(spacing: 8) {
        actionButton("Duplicate", symbol: "plus.square.on.square", action: editor.duplicate)
        iconButton("Delete part", symbol: "trash", action: editor.delete)
      }
      Button(action: editor.placeInFreeSpace) {
        HStack {
          Image(systemName: "square.3.layers.3d.down.right")
          Text("Find free position")
          Spacer()
          Image(systemName: "arrow.up.right")
        }.font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.amber)
      }.buttonStyle(.plain).help("Place this part using a 5 mm search grid and clearance")
    }
    .id(part.id)
  }

  var sheetInspector: some View {
    VStack(alignment: .leading, spacing: 15) {
      sectionTitle("SHEET & PROCESS")
      Picker(
        "Material",
        selection: Binding(
          get: { editor.design.material },
          set: { material in
            editor.commit({ $0.material = material }, message: "Material preview updated")
          })
      ) {
        Text("Birch plywood").tag("Birch plywood")
        Text("Frosted acrylic").tag("Frosted acrylic")
      }.labelsHidden().accessibilityLabel("Material")
      HStack(spacing: 10) {
        NumericField(label: "Sheet W", value: editor.design.sheetWidth) { value in
          editor.commit({ $0.sheetWidth = value }, message: "Sheet resized")
        }
        NumericField(label: "Sheet H", value: editor.design.sheetHeight) { value in
          editor.commit({ $0.sheetHeight = value }, message: "Sheet resized")
        }
      }
      NumericField(label: "Kerf", value: editor.design.kerf) { value in
        editor.commit({ $0.kerf = value }, message: "Kerf updated")
      }
      Toggle(
        "Outside compensation",
        isOn: Binding(
          get: { editor.design.compensate },
          set: { value in
            editor.commit(
              { $0.compensate = value },
              message: "Export compensation \(value ? "enabled" : "disabled")")
          })
      ).toggleStyle(.switch).controlSize(.mini).font(.system(size: 10))
      Text(
        "Offsets cut rectangles & circles by ½ kerf. Polylines stay on the centerline. Nominal dimensions remain unchanged."
      )
      .font(.system(size: 10)).lineSpacing(3).foregroundStyle(Palette.muted)
    }
  }

  var preflight: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("PREFLIGHT")
      HStack(spacing: 8) {
        Image(systemName: editor.issueCount == 0 ? "checkmark.circle" : "exclamationmark.triangle")
        Text(
          editor.issueCount == 0
            ? "Ready to fabricate"
            : "\(editor.issueCount) warning\(editor.issueCount == 1 ? "" : "s") to resolve"
        )
        .font(.system(size: 11, weight: .medium))
      }.foregroundStyle(
        editor.issueCount == 0 ? Color(red: 0.56, green: 0.79, blue: 0.65) : Palette.amber)
      if !editor.design.overlapPairs.isEmpty {
        Text(
          "\(editor.design.overlapPairs.count) overlapping cut pair(s). Move a part or use Find free position."
        )
        .font(.system(size: 10)).lineSpacing(3).foregroundStyle(Palette.amber)
      }
      if !editor.design.outOfBounds.isEmpty {
        Text("\(editor.design.outOfBounds.count) part(s) outside the material sheet.")
          .font(.system(size: 10)).foregroundStyle(Palette.amber)
      }
      Text(
        "Engraving overlays are intentional. Polyline collision checks use conservative bounding boxes."
      )
      .font(.system(size: 9)).lineSpacing(3).foregroundStyle(Palette.muted)
    }
  }

  var footer: some View {
    HStack(spacing: 12) {
      iconButton("Undo", symbol: "arrow.uturn.backward", action: editor.undo).disabled(
        editor.history.past.isEmpty)
      iconButton("Redo", symbol: "arrow.uturn.forward", action: editor.redo).disabled(
        editor.history.future.isEmpty)
      Rectangle().fill(Palette.line).frame(width: 1, height: 14)
      Text(editor.status).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
      Spacer()
      HStack(spacing: 6) {
        Circle().fill(Palette.amber).frame(width: 4, height: 4)
        Text("\(editor.design.parts.filter { $0.operation == .cut }.count) CUT")
        Circle().fill(Palette.blue).frame(width: 4, height: 4).padding(.leading, 10)
        Text("\(editor.design.parts.filter { $0.operation == .engrave }.count) ENGRAVE")
      }.font(.system(size: 8, weight: .semibold)).tracking(1).foregroundStyle(Palette.muted)
      Text("1:1  /  MILLIMETRES").font(.system(size: 8, design: .monospaced)).foregroundStyle(
        Palette.muted
      ).padding(.leading, 12)
    }.padding(.horizontal, 18).frame(height: 38)
  }

  func sectionTitle(_ title: String, trailing: String = "") -> some View {
    HStack {
      Text(title).tracking(1.5)
      Spacer()
      Text(trailing).fontDesign(.monospaced)
    }.font(.system(size: 8, weight: .semibold)).foregroundStyle(Palette.muted)
  }

  func iconButton(_ label: String, symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 13)).frame(width: 27, height: 28)
    }.buttonStyle(.plain).help(label).accessibilityLabel(label)
  }

  func actionButton(_ label: String, symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Label(label, systemImage: symbol).font(.system(size: 10, weight: .medium))
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
    }.buttonStyle(.plain)
  }

  func quickAdd(_ title: String, symbol: String, kind: ShapeKind) -> some View {
    Button {
      editor.add(kind)
    } label: {
      VStack(spacing: 9) {
        Image(systemName: symbol).font(.system(size: 19, weight: .light)).foregroundStyle(
          Palette.amber)
        Text(title).font(.system(size: 9))
      }.frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 6))
    }.buttonStyle(.plain).accessibilityLabel("Add \(title)")
  }
}

struct NumericField: View {
  let label: String
  let value: Double
  let commit: (Double) -> Void
  @State private var text = ""
  @State private var invalid = false
  @FocusState private var focused: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(label).font(.system(size: 9)).foregroundStyle(Palette.muted)
      HStack(spacing: 4) {
        TextField(label, text: $text)
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .textFieldStyle(.plain).focused($focused).onSubmit(apply)
          .accessibilityLabel(label).accessibilityIdentifier("numeric-\(label)")
        Text("mm").font(.system(size: 8)).foregroundStyle(Palette.muted)
      }
      .padding(.horizontal, 9).padding(.vertical, 10)
      .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
      .overlay(
        RoundedRectangle(cornerRadius: 5).strokeBorder(
          invalid ? Color.red : focused ? Palette.amber : Palette.line))
      if invalid { Text("Enter a finite number").font(.system(size: 8)).foregroundStyle(.red) }
    }
    .onAppear { reset() }
    .onChange(of: value) { _, _ in reset() }
    .onChange(of: focused) { old, new in if old && !new { apply() } }
  }
  func reset() {
    text = value.formatted(.number.precision(.fractionLength(0...3)))
    invalid = false
  }
  func apply() {
    let normalized = text.replacingOccurrences(of: ",", with: ".")
    guard let number = Double(normalized), number.isFinite else {
      invalid = true
      return
    }
    invalid = false
    commit(number)
    text = value.formatted(.number.precision(.fractionLength(0...3)))
  }
}
