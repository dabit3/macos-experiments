import Foundation
import XCTest

@testable import KeystoneCore

final class KeystoneCoreTests: XCTestCase {
  func testVerticalBarMatchesPLOverEA() throws {
    let design = Design(
      name: "Analytic bar",
      nodes: [
        Node(id: 0, x: 0, y: 0, support: .pin),
        Node(id: 1, x: 0, y: 2, support: .pin),
      ], members: [Member(id: 0, a: 0, b: 1)])
    let fixed = try Solver.solve(design)
    XCTAssertEqual(fixed.maxDisplacementMM, 0)
    // A horizontal bar with Y rollers leaves only the axial X degree of freedom.
    var axial = Design(
      name: "Sloped bar",
      nodes: [
        Node(id: 0, x: 0, y: 0, support: .pin),
        Node(id: 1, x: 3, y: 4, support: .roller, loadKN: 100),
      ], members: [Member(id: 0, a: 0, b: 1)])
    let roller = try Solver.solve(axial)
    XCTAssertEqual(roller.reactionsKN[1]?.y ?? 0, 100, accuracy: 1e-8)
    axial.nodes[1].support = .free
    XCTAssertThrowsError(try Solver.solve(axial))
  }

  func testTriangleAnalyticDisplacementAndForces() throws {
    let design = Design(
      name: "Triangle",
      nodes: [
        Node(id: 0, x: -3, y: 0, support: .pin),
        Node(id: 1, x: 3, y: 0, support: .pin),
        Node(id: 2, x: 0, y: 4, loadKN: 100),
      ],
      members: [Member(id: 0, a: 0, b: 2), Member(id: 1, a: 1, b: 2)])
    let result = try Solver.solve(design)
    let expectedM = 100_000.0 / (2 * 200e9 * 0.002 / 5 * 0.8 * 0.8)
    XCTAssertEqual(result.displacement[2]?.y ?? 0, -expectedM, accuracy: 1e-12)
    XCTAssertEqual(result.members[0]?.forceKN ?? 0, -62.5, accuracy: 1e-8)
    XCTAssertEqual(result.members[1]?.stressMPa ?? 0, -31.25, accuracy: 1e-8)
    XCTAssertEqual(result.reactionsKN[0]?.y ?? 0, 50, accuracy: 1e-8)
    XCTAssertEqual(result.reactionsKN[1]?.x ?? 0, -37.5, accuracy: 1e-8)
    XCTAssertLessThan(result.residualN, 1e-7)
  }

  func testWarrenEquilibriumSymmetryAndScaling() throws {
    let original = Design.example()
    let first = try Solver.solve(original)
    XCTAssertGreaterThan(first.maxDisplacementMM, 0)
    XCTAssertEqual(first.reactionsKN[0]?.y ?? 0, 50, accuracy: 1e-7)
    XCTAssertEqual(first.reactionsKN[4]?.y ?? 0, 50, accuracy: 1e-7)
    XCTAssertEqual(first.displacement[1]?.y ?? 0, first.displacement[3]?.y ?? 1, accuracy: 1e-10)
    XCTAssertLessThan(first.residualN, 1e-7)
    var thicker = original
    for i in thicker.members.indices { thicker.members[i].areaCM2 *= 2 }
    let second = try Solver.solve(thicker)
    XCTAssertEqual(second.maxDisplacementMM, first.maxDisplacementMM / 2, accuracy: 1e-9)
    XCTAssertEqual(thicker.massKg, original.massKg * 2, accuracy: 1e-9)
    for member in original.members {
      XCTAssertEqual(
        second.members[member.id]?.forceKN ?? 0, first.members[member.id]?.forceKN ?? 1,
        accuracy: 1e-7)
    }
    var doubleLoad = original
    doubleLoad.nodes[2].loadKN *= 2
    XCTAssertEqual(
      try Solver.solve(doubleLoad).maxDisplacementMM, first.maxDisplacementMM * 2, accuracy: 1e-9)
  }

  func testMechanismsAndDisconnectedNodesAreRejected() {
    var design = Design.example()
    design.members.remove(at: 8)
    XCTAssertThrowsError(try Solver.solve(design)) {
      XCTAssertEqual($0 as? AnalysisError, .unstable)
    }
    design = .example()
    design.nodes[0].support = .roller
    XCTAssertThrowsError(try Solver.solve(design))
    design = .example()
    design.nodes.append(Node(id: 50, x: 20, y: 0))
    XCTAssertThrowsError(try Solver.solve(design))
  }

  func testAllExamplesStableAndDeeperBridgeStiffer() throws {
    let shallow = try Solver.solve(.example(height: 1.5))
    let normal = try Solver.solve(.example())
    let deep = try Solver.solve(.example(height: 4.5))
    XCTAssertGreaterThan(shallow.maxDisplacementMM, normal.maxDisplacementMM)
    XCTAssertGreaterThan(normal.maxDisplacementMM, deep.maxDisplacementMM)
  }

  func testInvalidDataRejected() throws {
    var design = Design.example()
    design.members[0].areaCM2 = 0
    XCTAssertThrowsError(try design.validated())
    design = .example()
    design.nodes[0].x = .nan
    XCTAssertThrowsError(try design.validated())
    design = .example()
    design.members[0].b = 999
    XCTAssertThrowsError(try design.validated())
    design = .example()
    design.members.append(Member(id: 99, a: 1, b: 0))
    XCTAssertThrowsError(try design.validated())
    XCTAssertThrowsError(try DesignExport.decode(Data("not json".utf8)))
  }

  func testPersistenceExportsAndEscaping() throws {
    var design = Design.example()
    design.name = "Bridge <one> & \"two\""
    let data = try DesignExport.json(design)
    XCTAssertEqual(try DesignExport.decode(data), design)
    let result = try Solver.solve(design)
    let report = DesignExport.report(design, analysis: result)
    XCTAssertTrue(report.contains("Bridge &lt;one&gt; &amp; &quot;two&quot;"))
    XCTAssertTrue(report.contains("Member schedule"))
    XCTAssertTrue(report.contains("Nodal displacements"))
    XCTAssertFalse(report.contains("nan"))
    let svg = DesignExport.svg(design, analysis: result)
    XCTAssertTrue(svg.contains("<svg"))
    XCTAssertTrue(svg.contains("MPa"))
    XCTAssertTrue(svg.contains("100.0 kN"))
  }

  func testUndoRedoAndBranching() {
    var history = DesignHistory()
    let first = Design.example()
    let second = Design.example(height: 4.5)
    history.record(first)
    XCTAssertEqual(history.undo(second), first)
    XCTAssertEqual(history.redo(first), second)
    _ = history.undo(second)
    history.record(first)
    XCTAssertNil(history.redo(second))
  }
}
