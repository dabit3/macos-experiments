import PDFKit
import SwiftUI
import UIKit

struct StudioView: View {
  @State private var store = StudioStore()
  @State private var libraryTab = 0
  @State private var mode = "Studio"
  @State private var yaw = 0.68
  @State private var zoom = 0.76
  @State private var sheet: StudioSheet?
  @State private var saveName = ""
  @State private var showNewConfirmation = false

  enum StudioSheet: Identifiable {
    case rooms, save, dimensions
    case export(URL)

    var id: String {
      switch self {
      case .rooms: "Rooms"
      case .save: "Save"
      case .dimensions: "Dimensions"
      case .export: "Your plan · PDF"
      }
    }

    var detents: Set<PresentationDetent> {
      switch self {
      case .export: [.large]
      default: [.medium, .large]
      }
    }
  }

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        header
        Rectangle().fill(Palette.line).frame(height: 1)
        HStack(spacing: 0) {
          library.frame(width: geometry.size.width > 1100 ? 242 : 210)
          Rectangle().fill(Palette.line).frame(width: 1)
          workspace
        }
        footer
      }
    }
    .background(Palette.paper)
    .foregroundStyle(Palette.ink)
    .tint(Palette.clay)
    .preferredColorScheme(.light)
    .sheet(item: $sheet) { item in
      sheetContent(item)
        .presentationDetents(item.detents)
        .presentationDragIndicator(.visible)
    }
    .alert(
      "Roomlight",
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
    .confirmationDialog(
      "Start an empty room?", isPresented: $showNewConfirmation, titleVisibility: .visible
    ) {
      Button("Create empty room") {
        store.newRoom()
        sheet = nil
      }
    } message: {
      Text("Your saved rooms stay in the library. Undo also restores the current room.")
    }
  }

  private var header: some View {
    HStack(spacing: 16) {
      HStack(spacing: 10) {
        Image(systemName: "square.split.bottomrightquarter")
          .font(.system(size: 25, weight: .light))
          .foregroundStyle(Palette.clay)
        Text("roomlight").font(.system(size: 28, weight: .medium, design: .serif))
      }
      Text("SPACES TO FEEL AT HOME").font(.system(size: 9, weight: .semibold)).tracking(2)
        .foregroundStyle(Palette.muted)
        .padding(.leading, 14)
      Spacer()
      toolbarButton("Rooms", symbol: "square.grid.2x2") { sheet = .rooms }
      toolbarButton("Save", symbol: "square.and.arrow.down") {
        saveName = store.room.name
        sheet = .save
      }
      Button(action: exportPlan) {
        Label("Export plan", systemImage: "arrow.up.right")
          .font(.system(size: 13, weight: .semibold))
          .padding(.horizontal, 19).frame(height: 42)
          .background(Palette.ink, in: Capsule()).foregroundStyle(Palette.paper)
      }.accessibilityIdentifier("exportPlan")
    }
    .padding(.horizontal, 28).frame(height: 80)
  }

  private var library: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("THE COLLECTION").font(.system(size: 10, weight: .semibold)).tracking(2)
        .foregroundStyle(Palette.muted).padding(.top, 26)
      Text("Considered pieces.").font(.system(size: 23, weight: .regular, design: .serif))
        .padding(.top, 8)
      HStack(spacing: 20) {
        tab("Furniture", index: 0)
        tab("Materials", index: 1)
      }.padding(.top, 23).padding(.bottom, 17)
      Rectangle().fill(Palette.line).frame(height: 1)
      if libraryTab == 0 {
        ScrollView {
          VStack(spacing: 5) {
            ForEach(FurnitureKind.allCases, id: \.self) { kind in
              Button {
                store.add(kind)
              } label: {
                HStack(spacing: 7) {
                  FurnitureGlyph(kind: kind)
                    .background(Palette.oat.opacity(0.35), in: RoundedRectangle(cornerRadius: 9))
                  VStack(alignment: .leading, spacing: 5) {
                    Text(kind.title).font(.system(size: 12, weight: .semibold))
                    Text(kind.subtitle).font(.system(size: 9))
                      .foregroundStyle(Palette.muted)
                  }
                  Spacer(minLength: 0)
                }
                .padding(.vertical, 7)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel("Add \(kind.title)")
              .accessibilityIdentifier("add-\(kind.rawValue)")
            }
          }.padding(.top, 10)
        }
        Text("TAP TO PLACE · DRAG TO ARRANGE")
          .font(.system(size: 8, weight: .medium)).tracking(0.8)
          .foregroundStyle(Palette.muted).padding(.vertical, 17)
      } else {
        materials
        Spacer()
        Text("A palette inspired by natural light.")
          .font(.system(size: 12, design: .serif)).italic()
          .foregroundStyle(Palette.muted).padding(.bottom, 22)
      }
    }
    .padding(.horizontal, 20)
    .background(Color(red: 0.95, green: 0.94, blue: 0.90))
  }

  private var materials: some View {
    VStack(alignment: .leading, spacing: 15) {
      Text("UNDERFOOT").font(.system(size: 9, weight: .semibold)).tracking(1.8).padding(.top, 24)
      ForEach(FloorMaterial.allCases, id: \.self) { floor in
        materialButton(
          floor.title, color: Palette.floor(floor), selected: store.room.floor == floor
        ) {
          store.change { $0.floor = floor }
          store.message = "\(floor.title) floor applied"
        }
      }
      Text("AROUND YOU").font(.system(size: 9, weight: .semibold)).tracking(1.8).padding(.top, 18)
      ForEach(WallMaterial.allCases, id: \.self) { wall in
        materialButton(wall.title, color: Palette.wall(wall), selected: store.room.wall == wall) {
          store.change { $0.wall = wall }
          store.message = "\(wall.title) walls applied"
        }
      }
    }
  }

  private var workspace: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 7) {
          Text("ROOM STUDY / 01").font(.system(size: 9, weight: .semibold))
            .tracking(2).foregroundStyle(Palette.clay)
          Text(store.room.name).font(.system(size: 30, weight: .regular, design: .serif))
            .lineLimit(1).minimumScaleFactor(0.7)
          Button {
            sheet = .dimensions
          } label: {
            HStack(spacing: 7) {
              Text(String(format: "%.1f × %.1f m", store.room.width, store.room.depth))
              Text("·")
              Text(String(format: "%.1f m²", store.room.width * store.room.depth))
              Image(systemName: "slider.horizontal.3")
            }.font(.system(size: 11)).foregroundStyle(Palette.muted)
          }.accessibilityLabel("Edit room dimensions").padding(.top, 3)
        }
        Spacer(minLength: 12)
        HStack(spacing: 2) {
          ForEach(["Plan", "Studio", "3D"], id: \.self) { value in
            Button {
              mode = value
            } label: {
              Text(value).font(.system(size: 12, weight: .medium))
                .frame(width: 59, height: 36)
                .background(mode == value ? Palette.ink : .clear, in: Capsule())
                .foregroundStyle(mode == value ? Palette.paper : Palette.muted)
            }.accessibilityLabel("\(value) view")
          }
        }.padding(4).background(Palette.oat.opacity(0.6), in: Capsule())
      }.padding(.horizontal, 28).padding(.vertical, 25)
      HStack(spacing: 1) {
        if mode != "3D" {
          VStack(spacing: 0) {
            canvasHeading("01", "THE PLAN", trailing: "METRES")
            InteractivePlan(store: store)
            HStack {
              Text("Every piece in its place.").font(.system(size: 12, design: .serif)).italic()
                .foregroundStyle(Palette.muted)
              Spacer()
              Button {
                store.snap.toggle()
              } label: {
                Label(
                  store.snap ? "Snap 10 cm" : "Free move",
                  systemImage: store.snap ? "dot.scope" : "move.3d"
                )
                .font(.system(size: 10, weight: .medium))
                .padding(10).background(Palette.oat.opacity(0.6), in: Capsule())
              }.accessibilityLabel(store.snap ? "Snap on, 10 centimeters" : "Snap off")
            }.padding(.horizontal, 18).padding(.bottom, 19)
          }.background(Palette.paper)
        }
        if mode == "Studio" { Rectangle().fill(Palette.line).frame(width: 1) }
        if mode != "Plan" {
          VStack(spacing: 0) {
            canvasHeading("02", "THE PERSPECTIVE", trailing: "LIVE")
            ZStack(alignment: .topLeading) {
              RoomScene(room: store.room, yaw: yaw, zoom: zoom)
              VStack(alignment: .leading, spacing: 4) {
                Text("Soft northern light")
                  .font(.system(size: 13, weight: .regular, design: .serif)).italic()
                Text(
                  "\(store.room.floor.title.uppercased()) / \(store.room.wall.title.uppercased())"
                )
                .font(.system(size: 8, weight: .medium)).tracking(1.6)
              }.foregroundStyle(Palette.muted).padding(20)
            }
            HStack(spacing: 10) {
              cameraButton("Rotate camera left", symbol: "rotate.left") { yaw -= .pi / 8 }
              cameraButton("Rotate camera right", symbol: "rotate.right") { yaw += .pi / 8 }
              Spacer(minLength: 0)
              cameraButton("Zoom out", symbol: "minus") { zoom = min(1.1, zoom + 0.1) }
              cameraButton("Zoom in", symbol: "plus") { zoom = max(0.45, zoom - 0.1) }
              cameraButton("Reset camera", symbol: "viewfinder") {
                yaw = 0.68
                zoom = 0.76
              }
            }.padding(.horizontal, 18).padding(.bottom, 19)
          }.background(Palette.oat)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 13))
      .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.line, lineWidth: 1))
      .padding(.horizontal, 26)
      inspector.padding(.horizontal, 28).frame(height: 88)
    }
  }

  private var inspector: some View {
    HStack(spacing: 16) {
      if let selected = store.selected {
        FurnitureGlyph(kind: selected.kind).frame(width: 65)
        VStack(alignment: .leading, spacing: 5) {
          Text(selected.kind.title).font(.system(size: 14, weight: .semibold))
          Text(
            String(
              format: "%.2f × %.2f m   ·   %d°   ·   x %.1f / y %.1f",
              selected.kind.width, selected.kind.depth, selected.rotation, selected.x, selected.z)
          )
          .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
        }
        Spacer(minLength: 2)
        toolbarButton("Rotate 90°", symbol: "rotate.right") { store.rotate() }
        Button {
          store.remove()
        } label: {
          Image(systemName: "trash").frame(width: 40, height: 40)
        }.accessibilityLabel("Delete selected piece")
      } else {
        Image(systemName: "cursorarrow.motionlines").font(.system(size: 20, weight: .light))
          .foregroundStyle(Palette.clay)
        VStack(alignment: .leading, spacing: 5) {
          Text(
            store.room.furniture.isEmpty
              ? "Begin with a favorite piece." : "Good rooms begin with a little curiosity."
          )
          .font(.system(size: 15, design: .serif))
          Text("Choose from the collection, then drag in the plan to arrange.")
            .font(.system(size: 11)).foregroundStyle(Palette.muted)
        }
        Spacer()
      }
    }
  }

  private var footer: some View {
    HStack(spacing: 14) {
      Circle().fill(Palette.clay).frame(width: 5, height: 5)
      Text(store.message).font(.system(size: 11)).lineLimit(1)
      Spacer()
      Text("\(store.room.furniture.count) PIECES").font(.system(size: 9, weight: .medium)).tracking(
        1.5
      )
      .foregroundStyle(Palette.muted)
      Rectangle().fill(Palette.line).frame(width: 1, height: 16).padding(.horizontal, 4)
      Button {
        store.undo()
      } label: {
        Label("Undo", systemImage: "arrow.uturn.backward")
          .font(.system(size: 12, weight: .medium)).frame(height: 40)
      }.disabled(!store.canUndo).keyboardShortcut("z", modifiers: .command)
    }
    .padding(.horizontal, 28).frame(height: 47)
    .background(Palette.oat.opacity(0.55))
    .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
  }

  private func tab(_ title: String, index: Int) -> some View {
    Button {
      libraryTab = index
    } label: {
      Text(title).font(.system(size: 12, weight: libraryTab == index ? .semibold : .regular))
        .foregroundStyle(libraryTab == index ? Palette.clay : Palette.muted)
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
          if libraryTab == index { Rectangle().fill(Palette.clay).frame(height: 1) }
        }
    }
  }

  private func canvasHeading(_ number: String, _ title: String, trailing: String) -> some View {
    HStack {
      Text(number).foregroundStyle(Palette.clay)
      Text(title).tracking(1.7)
      Spacer()
      Text(trailing).foregroundStyle(Palette.muted).tracking(1)
    }
    .font(.system(size: 8, weight: .semibold)).padding(.horizontal, 18).frame(height: 46)
    .overlay(alignment: .bottom) { Rectangle().fill(Palette.line.opacity(0.7)).frame(height: 1) }
  }

  private func toolbarButton(_ title: String, symbol: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Label(title, systemImage: symbol).font(.system(size: 12, weight: .medium))
        .frame(height: 42).padding(.horizontal, 9).contentShape(Rectangle())
    }.buttonStyle(.plain)
  }

  private func cameraButton(_ label: String, symbol: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 13))
        .frame(width: 38, height: 36).background(Palette.paper.opacity(0.7), in: Capsule())
    }.accessibilityLabel(label)
  }

  private func materialButton(
    _ title: String, color: Color, selected: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        RoundedRectangle(cornerRadius: 6).fill(color).frame(width: 42, height: 42)
          .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.ink.opacity(0.15)))
        Text(title).font(.system(size: 12, weight: .medium))
        Spacer()
        if selected { Image(systemName: "checkmark").font(.system(size: 12)) }
      }
    }.buttonStyle(.plain).accessibilityLabel("\(title) material\(selected ? ", selected" : "")")
  }

  @ViewBuilder
  private func sheetContent(_ item: StudioSheet) -> some View {
    NavigationStack {
      Group {
        switch item {
        case .save:
          VStack(alignment: .leading, spacing: 24) {
            Text("Give your space a name.").font(.system(size: 30, design: .serif))
            TextField("Room name", text: $saveName).textFieldStyle(.roundedBorder)
              .accessibilityIdentifier("roomName")
            Text(
              "Saved rooms live on this iPad. Your current edits are also recovered automatically."
            )
            .font(.system(size: 14)).foregroundStyle(Palette.muted)
            .fixedSize(horizontal: false, vertical: true)
            Button("Save room") {
              store.save(name: saveName)
              sheet = nil
            }.buttonStyle(.borderedProminent).controlSize(.large)
            Spacer()
          }.padding(30)
        case .rooms:
          ScrollView {
            VStack(alignment: .leading, spacing: 18) {
              HStack {
                Text("A room of your own.").font(.system(size: 27, design: .serif))
                Spacer()
                Button("New empty room") { showNewConfirmation = true }
                  .buttonStyle(.bordered)
              }
              Button {
                store.open(.sample)
                sheet = nil
              } label: {
                savedRoomCard(.sample, caption: "BUNDLED ROOM STUDY")
              }.buttonStyle(.plain)
              ForEach(store.archive.saved) { room in
                Button {
                  store.open(room)
                  sheet = nil
                } label: {
                  savedRoomCard(room, caption: "SAVED ON THIS IPAD")
                }.buttonStyle(.plain)
              }
              if store.archive.saved.isEmpty {
                Text(
                  "Your saved spaces will appear here. Tap Save in the studio to keep your first room."
                )
                .font(.system(size: 14)).foregroundStyle(Palette.muted)
              }
            }.padding(26)
          }
        case .dimensions:
          VStack(alignment: .leading, spacing: 24) {
            Text("Make room.").font(.system(size: 30, design: .serif))
            Text("Rectangular rooms · 3–10 metres per side")
              .font(.system(size: 14)).foregroundStyle(Palette.muted)
            Stepper(
              value: Binding(
                get: { store.room.width }, set: { value in store.change { $0.width = value } }),
              in: 3...10, step: 0.5
            ) {
              Text(String(format: "Width    %.1f m", store.room.width))
            }.accessibilityIdentifier("roomWidth")
            Stepper(
              value: Binding(
                get: { store.room.depth }, set: { value in store.change { $0.depth = value } }),
              in: 3...10, step: 0.5
            ) {
              Text(String(format: "Depth    %.1f m", store.room.depth))
            }.accessibilityIdentifier("roomDepth")
            Text(
              "Pieces stay within the room when its size changes. You can undo any dimension edit."
            )
            .font(.system(size: 13)).foregroundStyle(Palette.muted)
            Spacer()
          }.padding(30)
        case .export(let url):
          PDFPreview(url: url)
            .toolbar {
              ToolbarItem(placement: .bottomBar) {
                ShareLink(item: url) {
                  Label("Share PDF", systemImage: "square.and.arrow.up")
                }
              }
            }
        }
      }
      .background(Palette.paper)
      .navigationTitle(item.id)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sheet = nil } } }
    }.tint(Palette.clay)
  }

  private func savedRoomCard(_ room: Room, caption: String) -> some View {
    HStack(spacing: 22) {
      PlanArtwork(room: room, grid: false).frame(width: 130, height: 120)
      VStack(alignment: .leading, spacing: 8) {
        Text(caption).font(.system(size: 8, weight: .semibold)).tracking(1.5).foregroundStyle(
          Palette.clay)
        Text(room.name).font(.system(size: 19, design: .serif))
        Text(
          String(
            format: "%.1f m² · %d pieces · %@", room.width * room.depth, room.furniture.count,
            room.floor.title)
        )
        .font(.system(size: 11)).foregroundStyle(Palette.muted)
      }
      Spacer()
      Image(systemName: "arrow.up.right").foregroundStyle(Palette.clay)
    }
    .padding(14).background(Palette.oat.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
  }

  private func exportPlan() {
    let room = store.room
    let imageRenderer = ImageRenderer(
      content: PlanArtwork(room: room, grid: false).frame(width: 1000, height: 780))
    imageRenderer.scale = 2
    guard let image = imageRenderer.uiImage else {
      store.error = "The plan image could not be rendered."
      return
    }
    let url = URL.documentsDirectory.appendingPathComponent("Roomlight-plan.pdf")
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 842, height: 595))
    do {
      try renderer.writePDF(to: url) { context in
        context.beginPage()
        UIColor(Palette.paper).setFill()
        context.cgContext.fill(CGRect(x: 0, y: 0, width: 842, height: 595))
        let titleFont = UIFont(name: "Georgia", size: 27) ?? .systemFont(ofSize: 27)
        ("roomlight / " + room.name).draw(
          at: CGPoint(x: 38, y: 27),
          withAttributes: [
            .font: titleFont, .foregroundColor: UIColor(Palette.ink),
          ])
        image.draw(in: CGRect(x: 35, y: 75, width: 600, height: 470))
        let schedule = FurnitureKind.allCases.compactMap { kind -> String? in
          let count = room.furniture.filter { $0.kind == kind }.count
          return count == 0 ? nil : "\(count) × \(kind.title)"
        }.joined(separator: "\n")
        let detail = """
          ROOM STUDY

          \(String(format: "%.2f × %.2f m", room.width, room.depth))
          \(String(format: "%.1f m²", room.width * room.depth))
          \(room.furniture.count) pieces

          MATERIALS
          \(room.floor.title) floor
          \(room.wall.title) walls

          FURNITURE
          \(schedule)
          """
        (detail as NSString).draw(
          in: CGRect(x: 655, y: 105, width: 155, height: 415),
          withAttributes: [
            .font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor(Palette.ink),
          ])
        ("Concept layout · Dimensions in metres · Not a construction drawing" as NSString)
          .draw(
            at: CGPoint(x: 38, y: 560),
            withAttributes: [
              .font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor(Palette.muted),
            ])
      }
      store.message = "PDF exported · Roomlight-plan.pdf"
      sheet = .export(url)
    } catch { store.error = "Could not export PDF: \(error.localizedDescription)" }
  }
}

struct PDFPreview: UIViewRepresentable {
  let url: URL
  func makeUIView(context: Context) -> PDFView {
    let view = PDFView()
    view.autoScales = true
    view.backgroundColor = UIColor(Palette.oat)
    view.document = PDFDocument(url: url)
    return view
  }
  func updateUIView(_ uiView: PDFView, context: Context) {}
}
