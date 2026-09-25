import SwiftUI

@main
struct InkAtlasApp: App {
  @StateObject private var store = BoardStore()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      AtlasEditor(store: store)
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { _, phase in
          if phase != .active { store.persist() }
        }
    }
  }
}

enum AtlasStyle {
  static let ink = Color(red: 36 / 255, green: 72 / 255, blue: 88 / 255)
  static let muted = Color(red: 112 / 255, green: 125 / 255, blue: 120 / 255)
  static let paper = Color(red: 248 / 255, green: 245 / 255, blue: 237 / 255)
  static let border = Color(red: 223 / 255, green: 224 / 255, blue: 213 / 255)
  static let white = Color(red: 255 / 255, green: 254 / 255, blue: 250 / 255)
}

struct AtlasEditor: View {
  @ObservedObject var store: BoardStore
  @State private var rename = ""
  @State private var confirmClear = false

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        header
        Rectangle().fill(AtlasStyle.border).frame(height: 1)
        HStack(spacing: 0) {
          tools
          ZStack {
            InkCanvas(store: store)
            if store.board.elements.isEmpty { emptyCanvas }
            VStack {
              HStack {
                Text(
                  "ATLAS / \(String(format: "%02d", (store.boards.firstIndex(where: { $0.id == store.board.id }) ?? 0) + 1))"
                )
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2).foregroundStyle(AtlasStyle.muted)
                Spacer()
              }
              .padding(.top, 22).padding(.horizontal, 25)
              Spacer()
              HStack {
                zoomBar
                Spacer()
                if geometry.size.width <= 1100, let selected = store.selectedElement {
                  Button {
                    store.editing = selected.id
                  } label: {
                    Label("Edit selection", systemImage: "slider.horizontal.3")
                  }
                  .buttonStyle(SoftButtonStyle())
                  Button {
                    store.deleteSelection()
                  } label: {
                    Image(systemName: "trash")
                  }
                  .buttonStyle(SoftButtonStyle()).accessibilityLabel("Delete selected object")
                }
                Text(
                  "\(store.board.elements.count) objects · \(store.board.connections.count) connections"
                )
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(AtlasStyle.muted)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(AtlasStyle.paper.opacity(0.9), in: Capsule())
              }
              .padding(20)
            }
          }
          .clipped()
          if geometry.size.width > 1100 {
            inspector.frame(width: 224)
          }
        }
        Rectangle().fill(AtlasStyle.border).frame(height: 1)
        footer
      }
      .background(AtlasStyle.paper)
      .foregroundStyle(AtlasStyle.ink)
    }
    .sheet(isPresented: $store.showLibrary) { LibraryView(store: store) }
    .sheet(isPresented: $store.showExport) { ExportView(store: store) }
    .sheet(isPresented: $store.showHelp) { HelpView() }
    .sheet(
      isPresented: Binding(
        get: { store.editing != nil },
        set: { if !$0 { store.editing = nil } })
    ) {
      if let id = store.editing, let element = store.board.elements.first(where: { $0.id == id }) {
        ElementEditor(store: store, element: element)
      }
    }
    .alert("Name your atlas", isPresented: $store.showRename) {
      TextField("Board name", text: $rename)
      Button("Cancel", role: .cancel) {}
      Button("Save") {
        let title = rename.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { store.apply { $0.title = String(title.prefix(80)) } }
      }
    } message: {
      Text("A good name is the start of an idea.")
    }
    .alert(
      "A note about your board",
      isPresented: Binding(
        get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
    .confirmationDialog("Clear this board?", isPresented: $confirmClear, titleVisibility: .visible)
    {
      Button("Clear canvas", role: .destructive) {
        store.apply {
          $0.elements.removeAll()
          $0.connections.removeAll()
        }
        store.selection = nil
        store.connectionStart = nil
      }
    } message: {
      Text("You can bring everything back with Undo.")
    }
  }

  private var header: some View {
    HStack(spacing: 22) {
      HStack(spacing: 11) {
        Image(systemName: "square.stack.3d.up")
          .font(.system(size: 26, weight: .light))
        VStack(alignment: .leading, spacing: 1) {
          Text("ink atlas").font(.system(size: 25, weight: .regular, design: .serif)).tracking(-1)
          Text("A LITTLE ROOM FOR BIG IDEAS").font(.system(size: 8, weight: .semibold)).tracking(
            1.45)
        }
      }
      Rectangle().fill(AtlasStyle.border).frame(width: 1, height: 35)
      Button {
        store.showLibrary = true
      } label: {
        Label("All boards", systemImage: "square.grid.2x2")
          .font(.system(size: 13, weight: .medium))
      }
      .buttonStyle(.plain).padding(.vertical, 16).accessibilityIdentifier("all-boards")
      Spacer(minLength: 12)
      Button {
        rename = store.board.title
        store.showRename = true
      } label: {
        VStack(spacing: 5) {
          HStack(spacing: 8) {
            Text(store.board.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
          }
          HStack(spacing: 5) {
            Circle().fill(store.saveStatus.hasPrefix("Saved") ? Color(hex: "#6D8C6C") : .orange)
              .frame(width: 4, height: 4)
            Text(store.saveStatus).font(.system(size: 10))
          }
          .foregroundStyle(AtlasStyle.muted)
        }
      }
      .buttonStyle(.plain).accessibilityLabel("Rename board, \(store.board.title)")
      Spacer(minLength: 12)
      HStack(spacing: 4) {
        iconButton("Undo", symbol: "arrow.uturn.backward", enabled: store.canUndo) { store.undo() }
        iconButton("Redo", symbol: "arrow.uturn.forward", enabled: store.canRedo) { store.redo() }
      }
      Button {
        store.showExport = true
      } label: {
        Label("Export", systemImage: "square.and.arrow.up")
          .font(.system(size: 13, weight: .semibold))
          .padding(.horizontal, 18).padding(.vertical, 13)
          .background(AtlasStyle.ink, in: RoundedRectangle(cornerRadius: 12))
          .foregroundStyle(AtlasStyle.white)
      }
      .buttonStyle(.plain).accessibilityIdentifier("export-board")
    }
    .padding(.horizontal, 25).frame(height: 83).background(AtlasStyle.white)
  }

  private var tools: some View {
    VStack(spacing: 7) {
      Spacer(minLength: 16)
      VStack(spacing: 4) {
        ForEach(CanvasTool.allCases, id: \.self) { tool in
          Button {
            store.tool = tool
            store.connectionStart = nil
            if tool != .select { store.selection = nil }
          } label: {
            VStack(spacing: 6) {
              Image(systemName: tool.symbol).font(.system(size: 20, weight: .regular))
              Text(tool.label).font(.system(size: 9, weight: .medium))
            }
            .frame(width: 55, height: 55)
            .foregroundStyle(store.tool == tool ? AtlasStyle.white : AtlasStyle.ink)
            .background(
              store.tool == tool ? AtlasStyle.ink : .clear, in: RoundedRectangle(cornerRadius: 11)
            )
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(tool.label) tool")
          .accessibilityIdentifier("tool-\(tool.rawValue)")
          .accessibilityAddTraits(store.tool == tool ? .isSelected : [])
        }
      }
      .padding(6).background(AtlasStyle.white, in: RoundedRectangle(cornerRadius: 18))
      .overlay(RoundedRectangle(cornerRadius: 18).stroke(AtlasStyle.border, lineWidth: 1))
      .shadow(color: AtlasStyle.ink.opacity(0.07), radius: 14, x: 3, y: 8)
      Spacer(minLength: 12)
      Button {
        store.showHelp = true
      } label: {
        Image(systemName: "questionmark").font(.system(size: 15, weight: .medium)).frame(
          width: 44, height: 44)
      }
      .buttonStyle(.plain).accessibilityLabel("Canvas guide")
    }
    .padding(.leading, 14).padding(.trailing, 7).padding(.bottom, 16).frame(width: 88)
  }

  private var inspector: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack {
        Text("THE TOOLBOX").font(.system(size: 10, weight: .semibold, design: .monospaced))
          .tracking(2)
        Spacer()
        Image(systemName: "slider.horizontal.3").font(.system(size: 13))
      }
      .foregroundStyle(AtlasStyle.muted)
      VStack(alignment: .leading, spacing: 15) {
        Text(store.selectedElement == nil ? "Your palette" : "Object color")
          .font(.system(size: 21, weight: .regular, design: .serif))
        HStack(spacing: 8) {
          ForEach(InkTone.allCases, id: \.self) { tone in
            let selectedTone = store.selectedElement?.tone ?? store.tone
            Button {
              store.setTone(tone)
            } label: {
              Circle().fill(Color(hex: tone.fill)).frame(width: 26, height: 26)
                .overlay(Circle().stroke(AtlasStyle.ink.opacity(0.12), lineWidth: 1))
                .padding(3)
                .overlay(
                  Circle().stroke(selectedTone == tone ? AtlasStyle.ink : .clear, lineWidth: 1.5))
            }
            .buttonStyle(.plain).accessibilityLabel("\(tone.name) color")
          }
        }
        Text((store.selectedElement?.tone ?? store.tone).name.uppercased())
          .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.5)
          .foregroundStyle(AtlasStyle.muted)
        if store.tool == .pen {
          HStack {
            ForEach([CGFloat(2), 4, 7], id: \.self) { width in
              Button {
                store.penWidth = width
              } label: {
                Capsule().fill(AtlasStyle.ink).frame(width: 25, height: width)
                  .frame(width: 49, height: 36)
                  .background(
                    store.penWidth == width ? AtlasStyle.border : .clear,
                    in: RoundedRectangle(cornerRadius: 8))
              }
              .buttonStyle(.plain).accessibilityLabel("\(Int(width)) point stroke")
            }
          }
        }
      }
      Divider().overlay(AtlasStyle.border)
      if let selected = store.selectedElement {
        VStack(alignment: .leading, spacing: 14) {
          Text(selected.kind == .stroke ? "A mark of your own" : "Shape this thought")
            .font(.system(size: 20, weight: .regular, design: .serif))
          Text(
            selected.kind == .stroke
              ? "Move your drawing or pull its lower-right handle to resize."
              : "Drag to move. The connections will follow your idea."
          )
          .font(.system(size: 12)).lineSpacing(5).foregroundStyle(AtlasStyle.muted)
          if selected.kind != .stroke {
            Button {
              store.editing = selected.id
            } label: {
              Label("Edit words", systemImage: "square.and.pencil").frame(
                maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(SoftButtonStyle()).accessibilityIdentifier("edit-words")
          }
          Text("\(Int(selected.frame.width)) × \(Int(selected.frame.height)) pt")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(AtlasStyle.muted)
          if store.board.connections.contains(where: {
            $0.from == selected.id || $0.to == selected.id
          }) {
            Button {
              store.disconnectSelection()
            } label: {
              Label("Disconnect", systemImage: "link.badge.plus")
            }
            .buttonStyle(SoftButtonStyle())
          }
          Button(role: .destructive) {
            store.deleteSelection()
          } label: {
            Label("Delete object", systemImage: "trash").font(.system(size: 12, weight: .medium))
          }
          .padding(.vertical, 8).tint(Color(hex: "#A86451"))
        }
      } else {
        VStack(alignment: .leading, spacing: 14) {
          Text(store.tool == .connect ? "Follow the thread." : "Think on paper.")
            .font(.system(size: 24, weight: .regular, design: .serif))
          Text(
            store.tool == .connect
              ? (store.connectionStart == nil
                ? "Choose your first object, then tap another. Their connection stays with them as they move."
                : "One idea chosen.\nNow tap the idea it leads to.")
              : "A few words, a loose sketch, a line between ideas.\n\nThere is no wrong place to begin."
          )
          .font(.system(size: 13)).lineSpacing(6).foregroundStyle(AtlasStyle.muted)
          HStack(spacing: 5) {
            Rectangle().fill(Color(hex: "#DBE6DA")).frame(width: 28, height: 5)
            Rectangle().fill(Color(hex: "#F2D791")).frame(width: 28, height: 5)
            Rectangle().fill(Color(hex: "#ECD3C8")).frame(width: 28, height: 5)
          }.padding(.top, 4)
        }
      }
      Spacer()
      VStack(alignment: .leading, spacing: 16) {
        Button {
          store.duplicateBoard()
        } label: {
          Label("Duplicate board", systemImage: "plus.square.on.square").font(
            .system(size: 11, weight: .medium))
        }.buttonStyle(.plain)
        Button {
          confirmClear = true
        } label: {
          Label("Clear canvas", systemImage: "eraser").font(.system(size: 11, weight: .medium))
        }.buttonStyle(.plain)
        Rectangle().fill(AtlasStyle.border).frame(height: 1)
        Text("MADE FOR WANDERING MINDS")
          .font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(0.6)
          .foregroundStyle(AtlasStyle.muted)
      }
    }
    .padding(.horizontal, 20).padding(.vertical, 28)
    .background(AtlasStyle.white.opacity(0.78))
    .overlay(alignment: .leading) { Rectangle().fill(AtlasStyle.border).frame(width: 1) }
  }

  private var zoomBar: some View {
    HStack(spacing: 3) {
      iconButton("Zoom out", symbol: "minus", enabled: store.zoom > 0.36) {
        store.zoom = max(0.35, store.zoom / 1.2)
      }
      Text("\(Int((store.zoom * 100).rounded()))%")
        .font(.system(size: 11, weight: .medium, design: .monospaced)).frame(width: 47)
      iconButton("Zoom in", symbol: "plus", enabled: store.zoom < 3.49) {
        store.zoom = min(3.5, store.zoom * 1.2)
      }
      Rectangle().fill(AtlasStyle.border).frame(width: 1, height: 20)
      Button {
        store.fitRequest += 1
      } label: {
        Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 13)).frame(
          width: 38, height: 38)
      }
      .buttonStyle(.plain).accessibilityLabel("Fit board")
    }
    .padding(3).background(AtlasStyle.white, in: Capsule())
    .overlay(Capsule().stroke(AtlasStyle.border, lineWidth: 1))
    .shadow(color: AtlasStyle.ink.opacity(0.05), radius: 10, y: 3)
  }

  private var emptyCanvas: some View {
    VStack(spacing: 16) {
      Image(systemName: "pencil.and.scribble").font(.system(size: 43, weight: .ultraLight))
      Text("What’s on your mind?").font(.system(size: 37, weight: .regular, design: .serif))
      Text("Choose a tool. Make a mark. Let the ideas find each other.")
        .font(.system(size: 14)).foregroundStyle(AtlasStyle.muted)
    }
    .foregroundStyle(AtlasStyle.ink).allowsHitTesting(false)
  }

  private var footer: some View {
    HStack(spacing: 8) {
      Image(systemName: store.tool.symbol).font(.system(size: 11))
      Text(
        store.connectionStart == nil
          ? store.tool.hint : "First idea selected · tap the destination object"
      )
      .font(.system(size: 11))
      Spacer()
      Text("LOCAL BY NATURE").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(
        1.5)
    }
    .foregroundStyle(AtlasStyle.muted).padding(.horizontal, 26).frame(height: 36).background(
      AtlasStyle.white)
  }

  private func iconButton(
    _ label: String, symbol: String, enabled: Bool = true, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 15, weight: .medium)).frame(
        width: 38, height: 38
      )
      .foregroundStyle(AtlasStyle.ink.opacity(enabled ? 1 : 0.22))
    }
    .buttonStyle(.plain).disabled(!enabled).accessibilityLabel(label)
  }
}

extension Color {
  init(hex: String) { self.init(uiColor: UIColor(hex: hex)) }
}

struct SoftButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 12, weight: .medium))
      .padding(.horizontal, 13).padding(.vertical, 12)
      .foregroundStyle(AtlasStyle.ink)
      .background(
        AtlasStyle.border.opacity(configuration.isPressed ? 0.8 : 0.4),
        in: RoundedRectangle(cornerRadius: 10))
  }
}
