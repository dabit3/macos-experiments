import Combine
import Foundation

@MainActor
final class StudioStore: ObservableObject {
  @Published private(set) var project: Storyboard
  @Published var selectedID: UUID
  @Published var error: String?
  @Published private(set) var saved = true
  @Published private(set) var history: [Storyboard] = []
  let archive: ProjectArchive

  init() {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    archive = ProjectArchive(directory: documents.appendingPathComponent("Projects"))
    var initial = SampleFilm.make()
    var startupError: String?
    do {
      let projects = try archive.list()
      if let id = UserDefaults.standard.string(forKey: "currentProject"),
        let existing = projects.first(where: { $0.id.uuidString == id })
      {
        initial = existing
      } else if let existing = projects.first {
        initial = existing
      }
    } catch {
      startupError = "Could not open the project library: \(error.localizedDescription)"
    }
    project = initial
    selectedID = initial.shots[0].id
    error = startupError
    if startupError == nil { save() }
  }

  var shot: Shot { project.shots.first { $0.id == selectedID } ?? project.shots[0] }
  var selectedIndex: Int { project.shots.firstIndex { $0.id == selectedID } ?? 0 }
  var scene: Scene { project.scenes.first { $0.id == shot.sceneID } ?? project.scenes[0] }

  func edit(_ action: (inout Storyboard) -> Void) {
    history.append(project)
    if history.count > 60 { history.removeFirst() }
    action(&project)
    project.updatedAt = Date()
    save()
  }

  func editShot(_ action: (inout Shot) -> Void) {
    guard let index = project.shots.firstIndex(where: { $0.id == selectedID }) else { return }
    edit { action(&$0.shots[index]) }
  }

  func save() {
    do {
      try archive.save(project)
      UserDefaults.standard.set(project.id.uuidString, forKey: "currentProject")
      saved = true
    } catch {
      saved = false
      self.error = error.localizedDescription
    }
  }

  func undo() {
    guard let previous = history.popLast() else { return }
    project = previous
    if !project.shots.contains(where: { $0.id == selectedID }) {
      selectedID = project.shots[0].id
    }
    save()
  }

  func addShot() {
    let new = Shot(sceneID: shot.sceneID, title: "Untitled shot", ratio: shot.ratio)
    let insertion = selectedIndex + 1
    edit { $0.shots.insert(new, at: insertion) }
    selectedID = new.id
  }

  func addScene(title: String, location: String) {
    let scene = Scene(title: title, location: location)
    let new = Shot(sceneID: scene.id, title: "Opening frame")
    edit {
      $0.scenes.append(scene)
      $0.shots.append(new)
    }
    selectedID = new.id
  }

  func deleteShot() {
    guard project.shots.count > 1 else { return }
    let index = selectedIndex
    let id = selectedID
    edit { $0.shots.removeAll { $0.id == id } }
    selectedID = project.shots[min(index, project.shots.count - 1)].id
  }

  func open(_ project: Storyboard) {
    self.project = project
    selectedID = project.shots[0].id
    history = []
    save()
  }

  func importProject(_ url: URL) {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    do { open(try archive.load(url)) } catch { self.error = error.localizedDescription }
  }
}
