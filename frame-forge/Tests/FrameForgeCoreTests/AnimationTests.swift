import Foundation
import Testing

@testable import FrameForgeCore

@Test func sampleRoundTripsAndMoves() throws {
  let sample = SampleAnimation.make()
  _ = try sample.validated()
  #expect(sample.frames.count == 8)
  #expect(sample.frames[0].strokes != sample.frames[4].strokes)
  let decoded = try JSONDecoder().decode(
    AnimationProject.self, from: JSONEncoder().encode(sample))
  #expect(decoded == sample)
}

@Test func duplicateHasIndependentIdentityAndStrokes() {
  var project = SampleAnimation.make()
  let original = project.frames[0]
  let selection = FrameEditing.duplicate(in: &project, at: 0)
  #expect(selection == 1)
  #expect(project.frames.count == 9)
  #expect(project.frames[1].id != original.id)
  #expect(project.frames[1].strokes[0].id != original.strokes[0].id)
  project.frames[1].strokes.removeLast()
  #expect(project.frames[0] == original)
}

@Test func deleteAndReorderPreserveBoundaries() {
  var project = SampleAnimation.make()
  let first = project.frames[0].id
  #expect(FrameEditing.move(in: &project, at: 0, by: -1) == 0)
  #expect(FrameEditing.move(in: &project, at: 0, by: 1) == 1)
  #expect(project.frames[1].id == first)
  #expect(FrameEditing.delete(in: &project, at: 7) == 6)
  #expect(project.frames.count == 7)
  var blank = AnimationProject.blank()
  #expect(FrameEditing.delete(in: &blank, at: 0) == 0)
  #expect(blank.frames.count == 1)
}

@Test func historyUndoesEditsAndClearsRedoBranch() {
  var history = AnimationHistory()
  let original = SampleAnimation.make()
  var changed = original
  history.record(original)
  changed.frames.removeLast()
  let restored = history.undo(changed)
  #expect(restored == original)
  #expect(history.redo(original) == changed)
  _ = history.undo(changed)
  history.record(original)
  #expect(history.future.isEmpty)
  for _ in 0..<80 { history.record(original) }
  #expect(history.past.count == 60)
}

@Test func validationRejectsBrokenDocuments() {
  var project = AnimationProject.blank()
  project.fps = 0
  #expect(throws: ProjectError.self) { try project.validated() }
  project.fps = 8
  project.frames = []
  #expect(throws: ProjectError.self) { try project.validated() }
  project = .blank()
  project.frames[0].strokes = [
    InkStroke(points: [InkPoint(x: .infinity, y: 0)], color: "493446", width: 4)
  ]
  #expect(throws: ProjectError.self) { try project.validated() }
}

@Test func frameLimitCannotBeExceededByDuplication() {
  var project = AnimationProject(name: "Full", frames: (0..<120).map { _ in AnimationFrame() })
  #expect(FrameEditing.duplicate(in: &project, at: 119) == 119)
  #expect(project.frames.count == 120)
}
