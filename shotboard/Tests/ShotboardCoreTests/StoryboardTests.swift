import Foundation
import Testing

@testable import ShotboardCore

@Test func sampleFilmIsCompleteAndValid() throws {
  let project = try SampleFilm.make().validated()
  #expect(project.shots.count == 6)
  #expect(project.scenes.count == 3)
  #expect(project.runtime == 40)
  #expect(project.runtimeLabel == "00:40")
  #expect(project.shots.allSatisfy { !$0.strokes.isEmpty })
}

@Test func movePreservesIdentityAndTimeline() {
  var project = SampleFilm.make()
  let ids = project.shots.map(\.id)
  project.moveShot(ids[2], by: -1)
  #expect(project.shots.map(\.id) == [ids[0], ids[2], ids[1], ids[3], ids[4], ids[5]])
  #expect(project.runtime == 40)
  project.moveShot(ids[2], by: -100)
  #expect(project.shots[0].id == ids[2])
  project.moveShot(ids[2], by: 100)
  #expect(project.shots[5].id == ids[2])
  let snapshot = project
  project.moveShot(UUID(), by: 2)
  #expect(project == snapshot)
}

@Test func playbackBoundariesUseShotDurations() {
  let project = SampleFilm.make()
  #expect(project.shotIndex(at: -1) == nil)
  #expect(project.shotIndex(at: 0) == 0)
  #expect(project.shotIndex(at: 7) == 0)
  #expect(project.shotIndex(at: 8) == 1)
  #expect(project.shotIndex(at: 14) == 2)
  #expect(project.shotIndex(at: 39) == 5)
  #expect(project.shotIndex(at: 40) == nil)
  #expect(Storyboard.timecode(125) == "02:05")
}

@Test func archiveRoundTripPreservesEditedSequenceAndArtwork() throws {
  let directory = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Caches/ShotboardTests/\(UUID())")
  defer { try? FileManager.default.removeItem(at: directory) }
  let archive = ProjectArchive(directory: directory)
  var project = SampleFilm.make()
  project.shots[0].notes = "Focus on the keeper — then the sea."
  project.shots[0].duration = 12
  project.shots[0].ratio = .academy
  project.shots[0].strokes.append(
    InkStroke(points: [InkPoint(x: 0.3, y: 0.2), InkPoint(x: 0.8, y: 0.9)], color: .yellow))
  project.moveShot(project.shots[0].id, by: 3)
  try archive.save(project)
  let loaded = try archive.load(archive.url(for: project.id))
  #expect(loaded == project)
  #expect(try archive.list() == [project])
  project.title = "Second revision"
  try archive.save(project)
  #expect(try archive.list().count == 1)
  #expect(try archive.load(archive.url(for: project.id)).title == "Second revision")
}

@Test func rejectsBrokenProjectsAndInvalidDrawingData() throws {
  var project = SampleFilm.make()
  project.shots[0].duration = 0
  #expect(throws: ProjectError.self) { try project.validated() }
  project.shots[0].duration = 121
  #expect(throws: ProjectError.self) { try project.validated() }
  project = SampleFilm.make()
  project.shots[0].sceneID = UUID()
  #expect(throws: ProjectError.self) { try project.validated() }
  project = SampleFilm.make()
  project.shots[0].strokes[0].points[0].x = 1.1
  #expect(throws: ProjectError.self) { try project.validated() }
  project = SampleFilm.make()
  project.shots.append(project.shots[0])
  #expect(throws: ProjectError.self) { try project.validated() }
  project = SampleFilm.make()
  project.schemaVersion = 2
  #expect(throws: ProjectError.self) { try project.validated() }
  #expect(throws: (any Error).self) {
    try JSONDecoder().decode(Storyboard.self, from: Data("not a project".utf8))
  }
}
