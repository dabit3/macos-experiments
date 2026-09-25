import AppKit
import CoreImage
import PrismCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class Store: ObservableObject {
  @Published var project: Project
  @Published var selected: UUID?
  @Published var pendingSource: UUID?
  @Published var preview: NSImage?
  @Published var original: NSImage?
  @Published var comparing = false
  @Published var zoom = 0.85
  @Published var status = "Ready • all changes saved locally"
  @Published var renderError: String?
  @Published var alert: String?
  @Published var projectURL: URL?
  @Published var dirty = false
  @Published var history: [Project] = []
  @Published var future: [Project] = []
  private let renderer = Renderer()
  private var assets: [String: CIImage] = [:]
  private var rendered: CIImage?
  private let autosave: URL

  init() {
    let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Prism", isDirectory: true)
    autosave = folder.appendingPathComponent("autosave.prism")
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    if let data = try? Data(contentsOf: autosave), let restored = try? Project.decode(data) {
      project = restored
    } else {
      project = .sample()
    }
    selected = project.nodes.first(where: { $0.kind == .exposure })?.id ?? project.nodes.first?.id
    for name in ["Solstice", "Nocturne"] {
      if let url = PrismAssets.bundle.url(forResource: name, withExtension: "png") {
        assets[name] = CIImage(contentsOf: url)
      }
    }
    render()
  }

  var selectedNode: GraphNode? { project.nodes.first { $0.id == selected } }

  func checkpoint() {
    history.append(project)
    if history.count > 80 { history.removeFirst() }
    future = []
  }

  func changed(renderImage: Bool = true) {
    dirty = true
    do { try project.encoded().write(to: autosave, options: .atomic) } catch {
      status = "Local save failed: \(error.localizedDescription)"
    }
    if renderImage { render() }
  }

  func render() {
    do {
      let image = try renderer.evaluate(project) { assets[$0] }
      rendered = image
      let cg = try renderer.cgImage(image)
      preview = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
      renderError = nil
    } catch {
      rendered = nil
      preview = nil
      renderError = error.localizedDescription
    }
    if let node = project.nodes.first(where: { $0.kind == .image }),
      let source = assets[node.asset], let cg = try? renderer.cgImage(source)
    {
      original = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    } else {
      original = nil
    }
  }

  func newProject(sample: Bool = false) {
    checkpoint()
    project = sample ? .sample() : .starter()
    projectURL = nil
    selected = project.nodes.first?.id
    pendingSource = nil
    comparing = false
    zoom = 0.85
    status = sample ? "Example restored" : "New graph • add an adjustment and connect its ports"
    changed()
  }

  func add(_ kind: NodeKind) {
    guard kind != .output, project.nodes.count < 64 else { return }
    checkpoint()
    let count = project.nodes.filter { $0.kind != .image && $0.kind != .output }.count
    let node = GraphNode(
      kind: kind, x: 285 + Double(count % 3) * 250,
      y: count < 2 ? 62 : min(1000, 245 + Double((count - 2) / 3) * 155))
    project.nodes.append(node)
    selected = node.id
    status = "\(kind.title) added • connect an output port to an input port"
    changed()
  }

  func connect(_ source: UUID, to target: UUID, input: Int) {
    do {
      var candidate = project
      try candidate.connect(source: source, target: target, input: input)
      checkpoint()
      project = candidate
      pendingSource = nil
      status = "Connection made"
      changed()
    } catch {
      pendingSource = nil
      alert = error.localizedDescription
      status = error.localizedDescription
    }
  }

  func inputClicked(_ target: UUID, input: Int) {
    selected = target
    if let source = pendingSource {
      connect(source, to: target, input: input)
    } else {
      status = "Choose an output port first, or use the inspector’s input menu"
    }
  }

  func outputClicked(_ id: UUID) {
    selected = id
    pendingSource = pendingSource == id ? nil : id
    status =
      pendingSource == nil ? "Connection cancelled" : "Now choose an input port • Escape to cancel"
  }

  func disconnect(_ target: UUID, input: Int) {
    checkpoint()
    project.edges.removeAll { $0.target == target && $0.input == input }
    status = "Input disconnected • ⌘Z to undo"
    changed()
  }

  func move(_ id: UUID, x: Double, y: Double) {
    guard let index = project.nodes.firstIndex(where: { $0.id == id }) else { return }
    project.nodes[index].x = max(20, min(1800, x))
    project.nodes[index].y = max(20, min(1000, y))
    changed(renderImage: false)
  }

  func updateValue(_ id: UUID, value: Double) {
    guard value.isFinite, let index = project.nodes.firstIndex(where: { $0.id == id }) else {
      return
    }
    let range = project.nodes[index].kind.range
    project.nodes[index].value = min(range.upperBound, max(range.lowerBound, value))
    changed()
  }

  func updateAsset(_ id: UUID, asset: String) {
    guard let index = project.nodes.firstIndex(where: { $0.id == id }) else { return }
    checkpoint()
    project.nodes[index].asset = asset
    changed()
  }

  func deleteSelected() {
    guard let id = selected, selectedNode?.kind != .output else { return }
    checkpoint()
    project.delete(id)
    selected = nil
    pendingSource = nil
    status = "Node deleted • ⌘Z to undo"
    changed()
  }

  func undo() {
    guard let previous = history.popLast() else { return }
    future.append(project)
    project = previous
    pendingSource = nil
    status = "Undone"
    changed()
  }

  func redo() {
    guard let next = future.popLast() else { return }
    history.append(project)
    project = next
    pendingSource = nil
    status = "Redone"
    changed()
  }

  func save(asNew: Bool = false) {
    if let url = projectURL, !asNew {
      writeProject(to: url)
      return
    }
    let panel = NSSavePanel()
    panel.title = "Save Prism Project"
    panel.nameFieldStringValue = "Solstice"
    panel.allowedContentTypes = [.init(filenameExtension: "prism") ?? .json]
    panel.canCreateDirectories = true
    if panel.runModal() == .OK, let url = panel.url { writeProject(to: url) }
  }

  private func writeProject(to url: URL) {
    do {
      try project.encoded().write(to: url, options: .atomic)
      projectURL = url
      dirty = false
      status = "Saved \(url.lastPathComponent)"
    } catch { alert = "Could not save: \(error.localizedDescription)" }
  }

  func openProject() {
    let panel = NSOpenPanel()
    panel.title = "Open Prism Project"
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.init(filenameExtension: "prism") ?? .json, .json]
    if panel.runModal() == .OK, let url = panel.url {
      do {
        let loaded = try Project.decode(Data(contentsOf: url))
        checkpoint()
        project = loaded
        projectURL = url
        selected = loaded.nodes.first?.id
        pendingSource = nil
        comparing = false
        changed()
        dirty = false
        status = "Opened \(url.lastPathComponent)"
      } catch { alert = "Could not open this project. \(error.localizedDescription)" }
    }
  }

  func exportPNG() {
    guard let image = rendered else {
      alert = "Connect all required inputs before exporting."
      return
    }
    let panel = NSSavePanel()
    panel.title = "Export Composited Image"
    panel.nameFieldStringValue = "Prism-\(comparing ? "composite" : "Solstice").png"
    panel.allowedContentTypes = [.png]
    panel.canCreateDirectories = true
    if panel.runModal() == .OK, let url = panel.url {
      do {
        try renderer.exportPNG(image, to: url)
        status = "Exported \(url.lastPathComponent) • 1600 × 1100 PNG"
      } catch { alert = "Export failed: \(error.localizedDescription)" }
    }
  }
}
