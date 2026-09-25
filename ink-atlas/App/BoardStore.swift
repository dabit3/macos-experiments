import SwiftUI
import UIKit

enum CanvasTool: String, CaseIterable {
  case select, pen, card, ellipse, text, connect, pan

  var label: String {
    switch self {
    case .select: "Select"
    case .pen: "Draw"
    case .card: "Card"
    case .ellipse: "Ellipse"
    case .text: "Text"
    case .connect: "Connect"
    case .pan: "Hand"
    }
  }

  var symbol: String {
    switch self {
    case .select: "cursorarrow"
    case .pen: "pencil.tip"
    case .card: "rectangle"
    case .ellipse: "circle"
    case .text: "textformat"
    case .connect: "arrow.up.right"
    case .pan: "hand.draw"
    }
  }

  var hint: String {
    switch self {
    case .select: "Tap to select · drag to move · drag the corner to resize"
    case .pen: "Make your mark · draw with a finger, mouse or Pencil"
    case .card: "Tap to place a card · drag for a custom size"
    case .ellipse: "Tap to place an ellipse · drag for a custom size"
    case .text: "Tap anywhere to leave a thought"
    case .connect: "Tap one object, then another to connect their ideas"
    case .pan: "Drag the paper to explore · pinch or use − / + to zoom"
    }
  }
}

@MainActor
final class BoardStore: ObservableObject {
  @Published var board: Board
  @Published var boards: [Board]
  @Published var selection: UUID?
  @Published var tool: CanvasTool = .select
  @Published var tone: InkTone = .ink
  @Published var penWidth: CGFloat = 3
  @Published var zoom: CGFloat = 1
  @Published var offset: CGPoint = .zero
  @Published var fitRequest = 0
  @Published var editing: UUID?
  @Published var showLibrary = false
  @Published var showExport = false
  @Published var showRename = false
  @Published var showHelp = false
  @Published var error: String?
  @Published var saveStatus = "Saved on this iPad"
  @Published var connectionStart: UUID?
  @Published var history = BoardHistory()
  @Published var latestExport: URL?

  private let fileURL: URL
  private var saveAllowed = true

  init() {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    fileURL = documents.appendingPathComponent("InkAtlas-library.json")
    let samples = [Samples.quietCity(), Samples.weekend()]
    board = samples[0]
    boards = samples
    if FileManager.default.fileExists(atPath: fileURL.path) {
      do {
        let library = try JSONDecoder().decode(BoardLibrary.self, from: Data(contentsOf: fileURL))
          .validated()
        boards = library.boards
        board = library.boards.first(where: { $0.id == library.selectedID }) ?? library.boards[0]
      } catch {
        let backup = documents.appendingPathComponent(
          "InkAtlas-recovery-\(Int(Date().timeIntervalSince1970)).json")
        do {
          try FileManager.default.copyItem(at: fileURL, to: backup)
          self.error =
            "Your saved library could not be read. The original is safe in \(backup.lastPathComponent). Sample boards are ready to use."
        } catch {
          saveAllowed = false
          self.error =
            "Your saved library could not be read or backed up. Editing is available, but saving is paused to protect the original. Export your work before closing."
        }
      }
    }
    persist()
  }

  var selectedElement: BoardElement? { board.elements.first { $0.id == selection } }
  var canUndo: Bool { !history.undoStack.isEmpty }
  var canRedo: Bool { !history.redoStack.isEmpty }

  func apply(_ change: (inout Board) -> Void) {
    let previous = board
    change(&board)
    record(previous)
  }

  func record(_ previous: Board) {
    guard previous != board else { return }
    history.record(previous, current: board)
    board.updated = Date()
    persist()
  }

  func undo() {
    guard let previous = history.undo(board) else { return }
    board = previous
    selection = nil
    connectionStart = nil
    persist()
  }

  func redo() {
    guard let next = history.redo(board) else { return }
    board = next
    selection = nil
    connectionStart = nil
    persist()
  }

  func persist() {
    guard saveAllowed else {
      saveStatus = "Saving paused"
      return
    }
    if let index = boards.firstIndex(where: { $0.id == board.id }) { boards[index] = board }
    do {
      let library = BoardLibrary(selectedID: board.id, boards: boards)
      let data = try JSONEncoder().encode(library)
      try data.write(to: fileURL, options: .atomic)
      saveStatus = "Saved on this iPad"
    } catch {
      saveStatus = "Could not save"
      self.error =
        "We could not save this board: \(error.localizedDescription). Please export a copy."
    }
  }

  func switchBoard(_ next: Board) {
    persist()
    board = next
    history = BoardHistory()
    selection = nil
    connectionStart = nil
    latestExport = nil
    tool = .select
    fitRequest += 1
    persist()
    showLibrary = false
  }

  func createBoard() {
    let next = Samples.blank(number: boards.count + 1)
    boards.append(next)
    switchBoard(next)
  }

  func duplicateBoard() {
    var next = board
    next.id = UUID()
    next.title += " / copy"
    next.updated = Date()
    boards.append(next)
    switchBoard(next)
  }

  func deleteSelection() {
    guard let selection else { return }
    apply { $0.remove(selection) }
    self.selection = nil
    connectionStart = nil
  }

  func disconnectSelection() {
    guard let selection else { return }
    apply { $0.connections.removeAll { $0.from == selection || $0.to == selection } }
  }

  func setTone(_ next: InkTone) {
    tone = next
    if let selection {
      apply { board in
        guard let index = board.elements.firstIndex(where: { $0.id == selection }) else { return }
        board.elements[index].tone = next
      }
    }
  }

  func export(pdf: Bool) {
    do {
      let folder = fileURL.deletingLastPathComponent().appendingPathComponent(
        "Exports", isDirectory: true)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let safeTitle = board.title.components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }.joined(separator: "-")
      let name = safeTitle.isEmpty ? "Ink-Atlas" : String(safeTitle.prefix(90))
      let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(
        of: ":", with: "-")
      let url = folder.appendingPathComponent("\(name)-\(timestamp).\(pdf ? "pdf" : "svg")")
      if pdf {
        try BoardRenderer.pdf(board).write(to: url, options: .atomic)
      } else {
        try SVGExporter.export(board).write(to: url, atomically: true, encoding: .utf8)
      }
      latestExport = url
    } catch {
      self.error = "Export could not be saved: \(error.localizedDescription)"
    }
  }
}
