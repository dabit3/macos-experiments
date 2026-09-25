import CoreGraphics
import Foundation
import XCTest

@testable import InkAtlasCore

final class BoardTests: XCTestCase {
  func testRectangleAnchorUsesBoundaryInEachDirection() {
    let rect = CGRect(x: 10, y: 20, width: 200, height: 100)
    XCTAssertEqual(
      Geometry.anchor(on: rect, toward: CGPoint(x: 500, y: 70)), CGPoint(x: 210, y: 70))
    XCTAssertEqual(
      Geometry.anchor(on: rect, toward: CGPoint(x: 110, y: -30)), CGPoint(x: 110, y: 20))
    let anchor = Geometry.anchor(on: rect, toward: CGPoint(x: 310, y: 270))
    XCTAssertEqual(anchor, CGPoint(x: 160, y: 120))
  }

  func testEllipseAnchorLiesOnEllipse() {
    let rect = CGRect(x: 10, y: 20, width: 200, height: 100)
    let point = Geometry.anchor(on: rect, toward: CGPoint(x: 500, y: 400), ellipse: true)
    let equation = pow((point.x - rect.midX) / 100, 2) + pow((point.y - rect.midY) / 50, 2)
    XCTAssertEqual(equation, 1, accuracy: 0.00001)
    XCTAssertTrue(
      Geometry.anchor(on: rect, toward: CGPoint(x: 110, y: 70), ellipse: true).x.isFinite)
  }

  func testConnectorsTrackMovedAndResizedObjects() throws {
    var board = Samples.quietCity()
    let connection = try XCTUnwrap(board.connections.first)
    let old = try XCTUnwrap(board.endpoints(for: connection))
    let index = try XCTUnwrap(board.elements.firstIndex(where: { $0.id == connection.to }))
    board.elements[index].frame.origin.x += 140
    board.elements[index].frame.size.height += 90
    let new = try XCTUnwrap(board.endpoints(for: connection))
    XCTAssertNotEqual(old.0, new.0)
    XCTAssertNotEqual(old.1, new.1)
    let target = board.elements[index]
    XCTAssertTrue(target.frame.insetBy(dx: -0.001, dy: -0.001).contains(new.1))
  }

  func testDeleteRemovesConnectionsAndHistoryRestoresThem() throws {
    let original = Samples.quietCity()
    var changed = original
    let center = try XCTUnwrap(changed.connections.first?.from)
    changed.remove(center)
    XCTAssertEqual(changed.connections.count, 0)
    var history = BoardHistory()
    history.record(original, current: changed)
    XCTAssertEqual(history.undo(changed), original)
    XCTAssertEqual(history.redo(original), changed)
  }

  func testHistoryClearsRedoAfterNewEditAndIgnoresNoop() {
    let original = Samples.quietCity()
    var modified = original
    modified.title = "Revised"
    var history = BoardHistory()
    history.record(original, current: original)
    XCTAssertTrue(history.undoStack.isEmpty)
    history.record(original, current: modified)
    _ = history.undo(modified)
    var alternative = original
    alternative.title = "Alternative"
    history.record(original, current: alternative)
    XCTAssertNil(history.redo(alternative))
    XCTAssertEqual(history.undo(alternative), original)
  }

  func testStrokeNormalizationAndResizePreserveGeometry() throws {
    var stroke = try XCTUnwrap(
      Geometry.stroke(
        [
          CGPoint(x: -20, y: 5), CGPoint(x: 0, y: 10), CGPoint(x: 20, y: 25),
        ], tone: .ink, width: 4))
    XCTAssertEqual(stroke.frame, CGRect(x: -20, y: 5, width: 40, height: 20))
    XCTAssertEqual(stroke.points[1], CGPoint(x: 0.5, y: 0.25))
    stroke.frame.size.width = 80
    XCTAssertEqual(stroke.frame.minX + stroke.points[1].x * stroke.frame.width, 20)
    let dot = try XCTUnwrap(Geometry.stroke([CGPoint(x: 1, y: 2)], tone: .sage, width: 2))
    XCTAssertTrue(dot.points[0].x.isFinite)
    XCTAssertEqual(dot.frame.width, 1)
    XCTAssertNil(Geometry.stroke([], tone: .ink, width: 3))
  }

  func testInvalidSelfDuplicateAndMissingConnectionsAreIgnored() throws {
    var board = Samples.weekend()
    let edge = try XCTUnwrap(board.connections.first)
    board.connect(edge.from, edge.from, tone: .ink)
    board.connect(edge.from, edge.to, tone: .ink)
    board.connect(UUID(), edge.to, tone: .ink)
    XCTAssertEqual(board.connections.count, 1)
  }

  func testLibraryRoundTripAndValidation() throws {
    let board = Samples.quietCity()
    let library = BoardLibrary(selectedID: board.id, boards: [board, Samples.weekend()])
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: url) }
    try JSONEncoder().encode(library).write(to: url, options: .atomic)
    let decoded = try JSONDecoder().decode(BoardLibrary.self, from: Data(contentsOf: url))
      .validated()
    XCTAssertEqual(decoded.boards[0], board)
    XCTAssertEqual(decoded.selectedID, board.id)
    XCTAssertThrowsError(try BoardLibrary(selectedID: UUID(), boards: [board]).validated())
    var invalid = board
    invalid.elements[0].frame.size.width = -5
    XCTAssertThrowsError(try BoardLibrary(selectedID: board.id, boards: [invalid]).validated())
  }

  func testSVGIsXMLSafeAndUsesContentBoundsAndMovedConnectors() throws {
    var board = Samples.weekend()
    board.title = "A < B & \"C\""
    board.elements[0].text = "Tea & <books>"
    board.elements[0].frame.origin.x = -200
    let svg = SVGExporter.export(board)
    XCTAssertTrue(svg.contains("<title>A &lt; B &amp; &quot;C&quot;</title>"))
    XCTAssertTrue(svg.contains("Tea &amp; &lt;books&gt;"))
    XCTAssertTrue(svg.contains("viewBox=\"-255.00"))
    XCTAssertFalse(svg.contains("Tea & <books>"))
    let connection = try XCTUnwrap(board.connections.first)
    let (_, end) = try XCTUnwrap(board.endpoints(for: connection))
    XCTAssertTrue(svg.contains("L\(SVGExporter.number(end.x)),\(SVGExporter.number(end.y))"))
  }

  func testReverseDragNormalizesShapeAndMinimumSize() {
    XCTAssertEqual(
      Geometry.rect(from: CGPoint(x: 300, y: 200), to: CGPoint(x: 100, y: 50)),
      CGRect(x: 100, y: 50, width: 200, height: 150))
    XCTAssertEqual(
      Geometry.rect(from: .zero, to: CGPoint(x: 2, y: 2)).size,
      CGSize(width: 60, height: 60))
  }
}
