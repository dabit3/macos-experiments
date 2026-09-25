import SceneKit
import XCTest

@testable import DominoDaydream

final class DioramaTests: XCTestCase {
  @MainActor
  func testColumnLabelsAreVisibleAboveSceneryOnEveryBoard() throws {
    for puzzle in Puzzle.all {
      for size in [CGSize(width: 375, height: 277), CGSize(width: 440, height: 480)] {
        let view = DioramaView(frame: CGRect(origin: .zero, size: size))
        let model = Diorama(puzzle: puzzle, labels: true)
        view.model = model
        view.scene = model.scene
        view.pointOfView = model.camera
        model.update(
          pieces: puzzle.fixed, selected: nil, result: nil, beat: -1,
          guides: true, reduceMotion: true)
        _ = view.snapshot()
        for letter in "ABCDEFG" {
          let name = "lettering-\(letter)"
          let node = try XCTUnwrap(
            model.scene.rootNode.childNode(withName: name, recursively: false))
          let point = view.projectPoint(node.position)
          let hits = view.hitTest(
            CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)),
            options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])
          XCTAssertEqual(
            hits.first?.node.name, name,
            "\(puzzle.title): column \(letter) is obscured at \(size)")
        }
      }
    }
  }

  @MainActor
  func testBoardProjectionFindsEveryCellOnCompactAndLargeViewports() {
    for size in [CGSize(width: 375, height: 300), CGSize(width: 440, height: 440)] {
      let view = DioramaView(frame: CGRect(origin: .zero, size: size))
      let model = Diorama(puzzle: Puzzle.all[0], labels: true)
      view.model = model
      view.scene = model.scene
      view.pointOfView = model.camera
      _ = view.snapshot()
      for y in 0..<9 {
        for x in 0..<7 {
          let point = view.projectPoint(SCNVector3(Float(x - 3), 0.08, Float(y - 4)))
          XCTAssertEqual(
            view.cell(at: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))),
            Cell(x: x, y: y), "Incorrect touch projection at \(x),\(y) on \(size)")
        }
      }
      XCTAssertNil(view.cell(at: CGPoint(x: -1000, y: -1000)))
    }
  }
}
