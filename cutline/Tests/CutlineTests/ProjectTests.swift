import Foundation
import XCTest

@testable import Cutline

final class ProjectTests: XCTestCase {
  func fixture() -> Project {
    let media = Media(
      id: "coast", name: "Coast", detail: "SAMPLE", duration: 6, path: "/fixture.mov")
    return Project(
      media: [media],
      clips: [
        Clip(mediaID: "coast", inPoint: 0, outPoint: 4),
        Clip(mediaID: "coast", inPoint: 2, outPoint: 6),
      ])
  }

  func testCutsUseHalfOpenTimeRangesAndRespectTrimmedDuration() throws {
    var project = fixture()
    let first = project.clips[0].id
    let second = project.clips[1].id
    try project.trim(first, start: 0.5, end: 2.5)
    XCTAssertEqual(project.duration, 6)
    XCTAssertEqual(project.clip(at: 1.999)?.id, first)
    XCTAssertEqual(project.clip(at: 2)?.id, second)
    XCTAssertEqual(project.clip(at: 6)?.id, second)
  }

  func testInvalidTrimIsAtomic() throws {
    var project = fixture()
    let original = project
    for range in [(3.0, 2.0), (-1, 3), (0, 7), (1, 1.1), (.nan, 3), (0, .infinity)] {
      XCTAssertThrowsError(try project.trim(project.clips[0].id, start: range.0, end: range.1))
      XCTAssertEqual(project, original)
    }
  }

  func testReorderPreservesIdentityAndBoundaries() {
    var project = fixture()
    let first = project.clips[0]
    project.move(first.id, by: -1)
    XCTAssertEqual(project.clips[0], first)
    project.move(first.id, by: 1)
    XCTAssertEqual(project.clips[1], first)
    XCTAssertEqual(project.duration, 8)
  }

  func testRoundTripAndBrokenMediaReferenceValidation() throws {
    let project = fixture()
    let decoded = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))
    XCTAssertEqual(try decoded.validated(), project)
    var broken = decoded
    broken.clips[0].mediaID = "nonexistent"
    XCTAssertThrowsError(try broken.validated())
    broken = decoded
    broken.clips.append(broken.clips[0])
    XCTAssertThrowsError(try broken.validated())
  }

  func testUnsupportedVersionIsRejected() {
    var project = fixture()
    project.version = 77
    XCTAssertThrowsError(try project.validated())
  }
}
