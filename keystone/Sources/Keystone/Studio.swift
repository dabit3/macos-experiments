import AppKit
import KeystoneCore
import SwiftUI
import UniformTypeIdentifiers

enum EditorTool: String, CaseIterable {
  case select = "Select"
  case node = "Node"
  case member = "Member"
  case load = "Load"
  var icon: String {
    switch self {
    case .select: return "cursorarrow"
    case .node: return "plus.circle"
    case .member: return "line.diagonal"
    case .load: return "arrow.down.to.line"
    }
  }
  var hint: String {
    switch self {
    case .select: return "Click to inspect · drag nodes to reshape · 0.5 m snap"
    case .node: return "Click the drafting canvas to add a node"
    case .member: return "Click two nodes to connect a new member"
    case .load: return "Click a node to place a 100 kN downward load"
    }
  }
}

enum DisplayMode: String, CaseIterable {
  case geometry = "Geometry"
  case stress = "Stress"
  case deflection = "Deflection"
}
enum Selection: Equatable {
  case node(Int)
  case member(Int)
}

@MainActor
final class Studio: ObservableObject {
  @Published var design = Design.example()
  @Published var selection: Selection?
  @Published var tool = EditorTool.select
  @Published var mode = DisplayMode.geometry
  @Published var result: Analysis?
  @Published var analysisError: String?
  @Published var analyzed = false
  @Published var showGrid = true
  @Published var showLabels = true
  @Published var startNode: Int?
  @Published var notice = "A small span. A remarkable structure."
  @Published var errorMessage: String?
  @Published var baselineMM: Double?
  @Published var history = DesignHistory()
  private let autosaveURL: URL

  init() {
    let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Keystone", isDirectory: true)
    autosaveURL = folder.appendingPathComponent("Workspace.keystone")
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: autosaveURL.path) {
        design = try DesignExport.decode(Data(contentsOf: autosaveURL))
        notice = "Workspace restored · saved locally"
      }
    } catch { errorMessage = "Could not restore the workspace: \(error.localizedDescription)" }
  }

  var selectedNode: Node? {
    guard case .node(let id) = selection else { return nil }
    return design.node(id)
  }
  var selectedMember: Member? {
    guard case .member(let id) = selection else { return nil }
    return design.members.first { $0.id == id }
  }
  var canUndo: Bool { !history.undoStack.isEmpty }
  var canRedo: Bool { !history.redoStack.isEmpty }

  func change(_ update: (inout Design) -> Void) {
    var next = design
    update(&next)
    guard next != design else { return }
    history.record(design)
    design = next
    refresh()
  }

  func refresh() {
    if analyzed { solve() }
    do {
      let encoder = JSONEncoder()
      try encoder.encode(design).write(to: autosaveURL, options: .atomic)
    } catch { errorMessage = "Autosave failed: \(error.localizedDescription)" }
  }

  func solve() {
    do {
      result = try Solver.solve(design)
      analysisError = nil
    } catch {
      result = nil
      analysisError = error.localizedDescription
    }
  }

  func applyLoad() {
    analyzed = true
    solve()
    if let result, baselineMM == nil { baselineMM = result.maxDisplacementMM }
    mode = .stress
    notice =
      result == nil
      ? "Analysis paused · restore stability to continue"
      : "Load applied · analysis updates as you edit"
  }

  func example(_ height: Double, name: String) {
    change { $0 = .example(height: height, name: name) }
    selection = nil
    startNode = nil
    baselineMM = nil
    analyzed = false
    result = nil
    analysisError = nil
    mode = .geometry
    notice = "Example loaded · \(name)"
  }

  func undo() {
    guard let previous = history.undo(design) else { return }
    design = previous
    selection = nil
    startNode = nil
    refresh()
    notice = "Undid last design change"
  }

  func redo() {
    guard let next = history.redo(design) else { return }
    design = next
    selection = nil
    startNode = nil
    refresh()
    notice = "Redid design change"
  }

  func deleteSelection() {
    guard let selection else { return }
    change { design in
      switch selection {
      case .node(let id):
        design.nodes.removeAll { $0.id == id }
        design.members.removeAll { $0.a == id || $0.b == id }
      case .member(let id): design.members.removeAll { $0.id == id }
      }
    }
    self.selection = nil
    startNode = nil
    notice = "Removed selection · Undo is available"
  }

  func setNode(_ id: Int, _ update: (inout Node) -> Void) {
    change { design in
      guard let i = design.nodes.firstIndex(where: { $0.id == id }) else { return }
      update(&design.nodes[i])
    }
  }

  func setArea(_ id: Int, area: Double) {
    change { design in
      guard let i = design.members.firstIndex(where: { $0.id == id }) else { return }
      design.members[i].areaCM2 = min(100, max(5, area))
    }
  }

  func canvasClick(node: Int?, member: Int?, position: SIMD2<Double>) {
    switch tool {
    case .select:
      selection = node.map(Selection.node) ?? member.map(Selection.member)
    case .node:
      if let node {
        selection = .node(node)
        return
      }
      guard design.nodes.count < 100 else {
        notice = "Node limit reached (100)"
        return
      }
      let id = (design.nodes.map(\.id).max() ?? -1) + 1
      change { $0.nodes.append(Node(id: id, x: position.x, y: position.y)) }
      selection = .node(id)
    case .load:
      guard let node else {
        notice = "Place loads on a node"
        return
      }
      setNode(node) { $0.loadKN = 100 }
      selection = .node(node)
      notice = "100 kN load placed · adjust it in the inspector"
    case .member:
      guard let node else {
        notice = "Members must connect existing nodes"
        return
      }
      if let start = startNode {
        guard start != node else {
          startNode = nil
          return
        }
        guard
          !design.members.contains(where: {
            ($0.a == start && $0.b == node) || ($0.a == node && $0.b == start)
          })
        else {
          notice = "These nodes are already connected"
          startNode = nil
          return
        }
        let id = (design.members.map(\.id).max() ?? -1) + 1
        change { $0.members.append(Member(id: id, a: start, b: node)) }
        selection = .member(id)
        startNode = nil
        notice = "Member connected"
      } else {
        startNode = node
        selection = .node(node)
        notice = "Now choose the second node"
      }
    }
  }

  func save() {
    let panel = NSSavePanel()
    panel.title = "Save bridge design"
    panel.nameFieldStringValue = "River crossing.keystone"
    panel.allowedContentTypes = [UTType(filenameExtension: "keystone") ?? .json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try DesignExport.json(design).write(to: url, options: .atomic)
      notice = "Saved \(url.lastPathComponent)"
    } catch { errorMessage = "Save failed: \(error.localizedDescription)" }
  }

  func open() {
    let panel = NSOpenPanel()
    panel.title = "Open bridge design"
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [UTType(filenameExtension: "keystone") ?? .json, .json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let loaded = try DesignExport.decode(Data(contentsOf: url))
      change { $0 = loaded }
      selection = nil
      startNode = nil
      baselineMM = nil
      notice = "Opened \(url.lastPathComponent)"
    } catch { errorMessage = "Open failed: \(error.localizedDescription)" }
  }

  func export(report: Bool) {
    if report {
      analyzed = true
      solve()
      guard result != nil else {
        errorMessage = "Restore a stable design before exporting a computed report."
        return
      }
    }
    let panel = NSSavePanel()
    panel.title = report ? "Export engineering report" : "Export vector drawing"
    panel.allowedContentTypes = [report ? .html : .svg]
    panel.nameFieldStringValue = report ? "Keystone Report.html" : "Keystone Drawing.svg"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let text: String
      if report, let result {
        text = DesignExport.report(design, analysis: result)
      } else {
        text = DesignExport.svg(design, analysis: result)
      }
      try text.write(to: url, atomically: true, encoding: .utf8)
      notice = "Exported \(url.lastPathComponent)"
    } catch { errorMessage = "Export failed: \(error.localizedDescription)" }
  }
}

enum Ink {
  static let navy = Color(red: 0.09, green: 0.19, blue: 0.25)
  static let muted = Color(red: 0.39, green: 0.45, blue: 0.46)
  static let paper = Color(red: 0.97, green: 0.96, blue: 0.92)
  static let line = Color(red: 0.83, green: 0.84, blue: 0.79)
  static let copper = Color(red: 0.72, green: 0.35, blue: 0.21)
  static let blue = Color(red: 0.20, green: 0.43, blue: 0.54)
  static let green = Color(red: 0.24, green: 0.44, blue: 0.36)
}

@main
struct KeystoneApp: App {
  @StateObject private var studio = Studio()
  var body: some Scene {
    WindowGroup {
      ContentView().environmentObject(studio)
        .frame(minWidth: 1120, minHeight: 720)
        .preferredColorScheme(.light)
        .onAppear {
          NSApp.setActivationPolicy(.regular)
          NSApp.activate(ignoringOtherApps: true)
        }
    }
    .defaultSize(width: 1380, height: 860)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("Open Design…", action: studio.open).keyboardShortcut("o")
        Button("Save Design…", action: studio.save).keyboardShortcut("s")
      }
      CommandGroup(replacing: .undoRedo) {
        Button("Undo", action: studio.undo).keyboardShortcut("z").disabled(!studio.canUndo)
        Button("Redo", action: studio.redo).keyboardShortcut("z", modifiers: [.command, .shift])
          .disabled(!studio.canRedo)
      }
    }
  }
}
