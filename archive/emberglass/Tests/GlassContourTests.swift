import SceneKit
import XCTest

@testable import Emberglass

final class GlassContourTests: XCTestCase {
  func testTracingOutlineHasAFlatFootWithoutAnImaginaryRoundedBase() {
    let rect = CGRect(x: 0, y: 0, width: 320, height: 420)
    let path = VesselShape(profile: Commission.tide.radii).path(in: rect)
    XCTAssertEqual(path.boundingRect.maxY, 375.13, accuracy: 0.02)
    XCTAssertTrue(path.contains(CGPoint(x: rect.midX, y: 374)))
    XCTAssertFalse(path.contains(CGPoint(x: rect.midX, y: 390)))
  }

  func testLathePassesThroughEveryTracedPointWithoutOvershoot() {
    for commission in Commission.allCases {
      let profile = commission.radii
      for index in profile.indices {
        XCTAssertEqual(
          GlassContour.radius(profile, at: Double(index) / 7), profile[index], accuracy: 0.00001)
      }
      for segment in 0..<7 {
        let lower = min(profile[segment], profile[segment + 1])
        let upper = max(profile[segment], profile[segment + 1])
        for step in 0...20 {
          let t = (Double(segment) + Double(step) / 20) / 7
          let radius = GlassContour.radius(profile, at: t)
          XCTAssertGreaterThanOrEqual(radius, lower - 0.00001)
          XCTAssertLessThanOrEqual(radius, upper + 0.00001)
        }
      }
    }
  }

  func testLatheClampsEndpointsAndHandlesEmptyContours() {
    XCTAssertEqual(GlassContour.radius([], at: 0.5), 0)
    XCTAssertEqual(GlassContour.radius([0.5], at: 0.5), 0.5)
    XCTAssertEqual(GlassContour.radius([0.3, 0.8], at: -1), 0.3)
    XCTAssertEqual(GlassContour.radius([0.3, 0.8], at: 2), 0.8)
  }

  func testHollowVesselHasPairedSurfacesAndClosedAngularSeam() throws {
    let outside = GlassContour.geometry(profile: Commission.tide.radii)
    let inside = GlassContour.geometry(profile: Commission.tide.radii, inside: true)
    for geometry in [outside, inside] {
      let vertices = try XCTUnwrap(geometry.sources(for: .vertex).first)
      let normals = try XCTUnwrap(geometry.sources(for: .normal).first)
      let texture = try XCTUnwrap(geometry.sources(for: .texcoord).first)
      XCTAssertEqual(vertices.vectorCount, 113 * 97)
      XCTAssertEqual(normals.vectorCount, vertices.vectorCount)
      XCTAssertEqual(texture.vectorCount, vertices.vectorCount)
      XCTAssertEqual(geometry.elements.first?.primitiveCount, 112 * 96 * 2)
    }
    XCTAssertNotEqual(outside.elements.first?.data, inside.elements.first?.data)
  }
}
