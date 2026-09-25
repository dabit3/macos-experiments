import SwiftUI
import UIKit

struct SamplePhoto: Identifiable {
  let id: String
  let title: String
  let subtitle: String
  let number: String
  var url: URL? { Bundle.main.url(forResource: id, withExtension: "jpg") }
  var image: UIImage? { url.flatMap { UIImage(contentsOfFile: $0.path) } }

  static let all = [
    SamplePhoto(
      id: "dunes", title: "The quiet earth", subtitle: "NAMIB · LAST LIGHT", number: "01"),
    SamplePhoto(
      id: "coast", title: "Where the tide turns", subtitle: "PACIFIC · GOLDEN HOUR", number: "02"),
    SamplePhoto(
      id: "bloom", title: "A study in stillness", subtitle: "STUDIO · WINDOW LIGHT", number: "03"),
  ]
}

struct ExportedPhoto: Identifiable {
  let id = UUID()
  let url: URL
  let image: UIImage
  let width: Int
  let height: Int
  let bytes: Int
}

@MainActor
final class EditorStore: ObservableObject {
  @Published private(set) var project = Project()
  @Published var draft = Edit()
  @Published var preview: UIImage?
  @Published var exporting = false
  @Published var rendering = false
  @Published var exported: ExportedPhoto?
  @Published var error: String?
  @Published var thumbnails: [FilmLook: UIImage] = [:]
  private var generation = 0
  private let fileURL: URL
  private var saveFailed = false

  var photo: SamplePhoto {
    SamplePhoto.all.first { $0.id == project.selectedID } ?? SamplePhoto.all[0]
  }
  var history: EditHistory { project.photos[photo.id] ?? EditHistory() }
  var isEdited: Bool { draft != Edit() }
  var status: String {
    saveFailed ? "Save failed" : (isEdited ? "Edits saved" : "Original negative")
  }

  init() {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    fileURL = documents.appendingPathComponent("Afterglow/project.json")
    if FileManager.default.fileExists(atPath: fileURL.path) {
      do {
        project = try ProjectFile.load(from: fileURL)
      } catch {
        self.error =
          "Your saved project could not be read. The originals are safe. A fresh session is ready."
      }
    }
    draft = history.current.sanitized()
    render()
    makeThumbnails()
  }

  func select(_ photo: SamplePhoto) {
    commit()
    project.selectedID = photo.id
    draft = history.current.sanitized()
    preview = nil
    persist()
    render()
    makeThumbnails()
  }

  func change(_ update: (inout Edit) -> Void) {
    update(&draft)
    draft = draft.sanitized()
    commit()
  }

  func commit() {
    var updated = history
    updated.apply(draft)
    project.photos[photo.id] = updated
    draft = updated.current
    persist()
    render()
  }

  func undo() {
    var updated = history
    updated.undo()
    project.photos[photo.id] = updated
    draft = updated.current
    persist()
    render()
  }

  func redo() {
    var updated = history
    updated.redo()
    project.photos[photo.id] = updated
    draft = updated.current
    persist()
    render()
  }

  private func persist() {
    do {
      try ProjectFile.save(project, to: fileURL)
      saveFailed = false
    } catch {
      saveFailed = true
      self.error =
        "Your edit is still on screen, but could not be saved: \(error.localizedDescription)"
    }
  }

  func render() {
    guard let url = photo.url else {
      error = RenderError.missingImage.localizedDescription
      return
    }
    generation += 1
    let ticket = generation
    let edit = draft
    rendering = true
    Task {
      let result = await Task.detached(priority: .userInitiated) {
        Result { try PhotoRenderer.render(url: url, edit: edit, maxDimension: 1000) }
      }.value
      guard ticket == generation else { return }
      rendering = false
      switch result {
      case .success(let image): preview = UIImage(cgImage: image)
      case .failure(let failure): error = failure.localizedDescription
      }
    }
  }

  private func makeThumbnails() {
    guard let url = photo.url else { return }
    let selected = photo.id
    thumbnails = [:]
    Task {
      let images = await Task.detached(priority: .utility) {
        FilmLook.allCases.compactMap { look -> (FilmLook, CGImage)? in
          var edit = Edit()
          edit.look = look
          guard let image = try? PhotoRenderer.render(url: url, edit: edit, maxDimension: 150)
          else { return nil }
          return (look, image)
        }
      }.value
      guard selected == photo.id else { return }
      thumbnails = Dictionary(uniqueKeysWithValues: images.map { ($0.0, UIImage(cgImage: $0.1)) })
    }
  }

  func export() {
    commit()
    guard let source = photo.url else {
      error = RenderError.missingImage.localizedDescription
      return
    }
    exporting = true
    let edit = draft
    let url = fileURL.deletingLastPathComponent().appendingPathComponent("Exports")
      .appendingPathComponent("Afterglow-\(photo.id)-\(UUID().uuidString.prefix(8)).jpg")
    Task {
      let result = await Task.detached(priority: .userInitiated) {
        Result {
          let image = try PhotoRenderer.render(url: source, edit: edit)
          try PhotoRenderer.exportJPEG(image: image, to: url)
          return (image, try Data(contentsOf: url).count)
        }
      }.value
      exporting = false
      switch result {
      case .success(let (image, count)):
        exported = ExportedPhoto(
          url: url, image: UIImage(cgImage: image), width: image.width,
          height: image.height, bytes: count)
      case .failure(let failure): error = failure.localizedDescription
      }
    }
  }
}
