import Foundation
import Testing

@testable import KerfCore

@Test func sampleRoundTrip() throws {
  let design = try Design.sample.validated()
  let restored = try JSONDecoder().decode(Design.self, from: JSONEncoder().encode(design))
  #expect(restored == design)
  #expect(design.outOfBounds.isEmpty)
  #expect(design.overlapPairs.isEmpty)
}

@Test func accurateCircularOverlap() {
  let a = Part(name: "a", kind: .circle, x: 0, y: 0, width: 10, height: 10)
  let b = Part(name: "b", kind: .circle, x: 9, y: 9, width: 10, height: 10)
  #expect(!Design.overlaps(a, b))
  var c = b
  c.x = 5
  c.y = 0
  #expect(Design.overlaps(a, c))
  c.x = 10
  #expect(!Design.overlaps(a, c))
  #expect(Design.overlaps(a, c, clearance: 0.15))
}

@Test func cornerClearance() {
  let rect = Part(name: "a", kind: .rectangle, x: 0, y: 0, width: 10, height: 10)
  var circle = Part(name: "b", kind: .circle, x: 9.5, y: 9.5, width: 4, height: 4)
  #expect(!Design.overlaps(rect, circle))
  circle.x = 8
  #expect(Design.overlaps(rect, circle))
}

@Test func engravingExemptAndBoundsRespectKerf() {
  var design = Design()
  let p = Part(name: "a", kind: .rectangle, x: 0, y: 0, width: 30, height: 20)
  var engraving = p
  engraving.id = UUID()
  engraving.operation = .engrave
  design.parts = [p, engraving]
  #expect(design.overlapPairs.isEmpty)
  #expect(design.outOfBounds.isEmpty)
  design.compensate = true
  #expect(design.outOfBounds == [p.id])
  design.parts[1].operation = .cut
  #expect(design.overlapPairs.count == 1)
}

@Test func physicalSVGAndCompensation() throws {
  var design = Design()
  design.title = "A & <B>"
  design.parts = [
    Part(name: "90 mm", kind: .circle, x: 10, y: 20, width: 90, height: 90),
    Part(name: "panel", kind: .rectangle, x: 150, y: 20, width: 100, height: 80),
    Part(
      name: "line", kind: .polyline, x: 10, y: 140, width: 30, height: 20,
      points: [Point(0, 0), Point(1, 1)]),
  ]
  design.kerf = 0.2
  design.compensate = true
  let svg = try design.svg()
  #expect(svg.contains("width=\"320.000mm\" height=\"240.000mm\""))
  #expect(svg.contains("cx=\"55.000\" cy=\"65.000\" r=\"45.100\""))
  #expect(svg.contains("x=\"149.900\" y=\"19.900\" width=\"100.200\" height=\"80.200\""))
  #expect(svg.contains("points=\"10.000,140.000 40.000,160.000\""))
  #expect(svg.contains("A &amp; &lt;B&gt;"))
}

@Test func validationRejectsCorruptGeometry() {
  var design = Design.sample
  design.parts[0].width = .nan
  #expect(throws: DesignError.self) { try design.validated() }
  design = Design.sample
  design.parts[0].height = 40
  #expect(throws: DesignError.self) { try design.validated() }
  design = Design.sample
  design.sheetWidth = -1
  #expect(throws: DesignError.self) { try design.validated() }
  design = Design.sample
  design.parts.append(design.parts[0])
  #expect(throws: DesignError.self) { try design.validated() }
}

@Test func historyBranchesAndLimits() {
  var history = History()
  let a = Design.sample
  var b = a
  b.title = "B"
  var c = b
  c.title = "C"
  history.record(a)
  #expect(history.undo(b) == a)
  #expect(history.redo(a) == b)
  #expect(history.undo(b) == a)
  history.record(a)
  #expect(history.redo(c) == nil)
  for _ in 0..<110 { history.record(c) }
  #expect(history.past.count == 100)
}

@Test func polylineHitTesting() {
  let p = Part(
    name: "line", kind: .polyline, x: 10, y: 20, width: 50, height: 50,
    points: [Point(0, 0), Point(1, 1)])
  #expect(p.contains(Point(35, 45)))
  #expect(!p.contains(Point(10, 70)))
}
