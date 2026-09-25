import PhotosUI
import SwiftUI

@MainActor
final class LibraryStore: ObservableObject {
  @Published var state = LibraryState()
  @Published var error: String?
  @Published var importing = false
  @Published var thumbnails: [String: UIImage] = [:]
  let disk: LibraryDisk

  init() {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    disk = LibraryDisk(directory: documents.appendingPathComponent("Silverroom", isDirectory: true))
    do { state = try disk.load() } catch {
      self.error = "Your library couldn’t be read. Please restart Silverroom."
    }
  }

  func data(for negative: Negative) throws -> Data {
    let url: URL
    if negative.isSample {
      guard let sample = Bundle.main.url(forResource: negative.resource, withExtension: "jpg")
      else {
        throw DarkroomError.unreadable
      }
      url = sample
    } else {
      url = disk.directory.appendingPathComponent(negative.resource)
    }
    return try Data(contentsOf: url)
  }

  func persist() {
    do { try disk.save(state) } catch {
      self.error = "Changes couldn’t be saved. Please check available storage."
    }
  }

  func update(_ negative: Negative, settings: EditSettings) {
    guard let index = state.negatives.firstIndex(where: { $0.id == negative.id }) else { return }
    state.negatives[index].settings = settings.normalized
    persist()
  }

  func addRecipe(name: String, settings: EditSettings) {
    let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
    guard !trimmed.isEmpty else { return }
    state.recipes.insert(Recipe(name: trimmed, settings: settings.recipe), at: 0)
    persist()
  }

  func deleteRecipe(_ recipe: Recipe) {
    state.recipes.removeAll { $0.id == recipe.id }
    persist()
  }

  func renameRecipe(_ recipe: Recipe, name: String) {
    let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
    guard !trimmed.isEmpty, let index = state.recipes.firstIndex(where: { $0.id == recipe.id })
    else { return }
    state.recipes[index].name = trimmed
    persist()
  }

  func remove(_ negative: Negative) {
    guard !negative.isSample else { return }
    state.negatives.removeAll { $0.id == negative.id }
    persist()
    try? FileManager.default.removeItem(
      at: disk.directory.appendingPathComponent(negative.resource))
    thumbnails.removeValue(forKey: negative.id)
  }

  func refreshThumbnail(_ negative: Negative) async {
    guard let data = try? data(for: negative) else { return }
    let settings =
      state.negatives.first(where: { $0.id == negative.id })?.settings ?? negative.settings
    let image = await Task.detached(priority: .utility) {
      try? ImageEngine().render(data, settings: settings, maxPixel: 800)
    }.value
    thumbnails[negative.id] = image
  }

  func importPhoto(_ item: PhotosPickerItem) async -> Negative? {
    importing = true
    defer { importing = false }
    do {
      guard let bytes = try await item.loadTransferable(type: Data.self) else {
        throw DarkroomError.unreadable
      }
      _ = try await Task.detached(priority: .userInitiated) {
        try ImageEngine().source(bytes, maxPixel: 200)
      }.value
      let id = UUID().uuidString
      let fileName = "\(id).photo"
      try FileManager.default.createDirectory(at: disk.directory, withIntermediateDirectories: true)
      try bytes.write(to: disk.directory.appendingPathComponent(fileName), options: .atomic)
      let negative = Negative(
        id: id, title: "Untitled \(state.negatives.filter { !$0.isSample }.count + 1)",
        subtitle: "Your photograph", resource: fileName, isSample: false)
      state.negatives.insert(negative, at: 0)
      persist()
      await refreshThumbnail(negative)
      return negative
    } catch {
      self.error = error.localizedDescription
      return nil
    }
  }
}

@MainActor
final class Darkroom: ObservableObject {
  @Published var settings: EditSettings
  @Published var preview: UIImage?
  @Published var original: UIImage?
  @Published var films: [Film: UIImage] = [:]
  @Published var rendering = false
  @Published var exporting = false
  @Published var error: String?
  @Published var outputSize: CGSize = .zero
  private var bytes: Data?
  private var revision = 0

  init(settings: EditSettings) { self.settings = settings.normalized }

  func load(data: Data) async {
    bytes = data
    rendering = true
    let result = await Task.detached(priority: .userInitiated) {
      let engine = ImageEngine()
      let original = try? engine.render(data, settings: EditSettings(), maxPixel: 1400)
      var films: [Film: UIImage] = [:]
      for film in Film.allCases {
        films[film] = try? engine.render(data, settings: EditSettings(film: film), maxPixel: 240)
      }
      return (original, films)
    }.value
    original = result.0
    films = result.1
    await develop()
  }

  func develop() async {
    guard let bytes else { return }
    revision += 1
    let current = revision
    let settings = settings.normalized
    rendering = true
    do {
      try await Task.sleep(for: .milliseconds(45))
      let result = try await Task.detached(priority: .userInitiated) {
        let engine = ImageEngine()
        return (
          try engine.render(bytes, settings: settings, maxPixel: 1400),
          try engine.dimensions(bytes, settings: settings)
        )
      }.value
      guard current == revision, !Task.isCancelled else { return }
      preview = result.0
      outputSize = result.1
      rendering = false
    } catch is CancellationError {
    } catch {
      guard current == revision else { return }
      rendering = false
      self.error = error.localizedDescription
    }
  }

  func export(directory: URL) async -> URL? {
    guard let bytes else { return nil }
    exporting = true
    defer { exporting = false }
    let settings = settings
    do {
      let data = try await Task.detached(priority: .userInitiated) {
        try ImageEngine().export(bytes, settings: settings)
      }.value
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let url = directory.appendingPathComponent("Silverroom-\(UUID().uuidString.prefix(8)).jpg")
      try data.write(to: url, options: .atomic)
      return url
    } catch {
      self.error = error.localizedDescription
      return nil
    }
  }

  func apply(_ recipe: Recipe) {
    var applied = recipe.settings.recipe
    applied.quarterTurns = settings.quarterTurns
    applied.squareCrop = settings.squareCrop
    settings = applied
  }
}
