import Foundation
import XCTest

@testable import LastfortKit

final class IslandTests: XCTestCase {
  struct Fixture: Decodable {
    let seed: Int
    let rules: Rules
    let terrain: [Terrain]
    let pois: [PointOfInterest]
    let nodes: [ResourceNode]
    let chests: [Chest]
    let structures: [Structure]
  }
  func testWorldMatchesAuthoritativeDartGeneration() throws {
    for seed in [0, 4242, 2_147_483_647] {
      let url = try XCTUnwrap(
        Bundle.module.url(
          forResource: "world-\(seed)", withExtension: "json", subdirectory: "Fixtures"))
      let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
      let island = Island(rules: fixture.rules, seed: seed)
      XCTAssertEqual(island.terrain, fixture.terrain, "Terrain differs for seed \(seed)")
      XCTAssertEqual(island.pois.count, fixture.pois.count)
      for (actual, expected) in zip(island.pois, fixture.pois) {
        XCTAssertEqual(actual.name, expected.name)
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.006)
        XCTAssertEqual(actual.y, expected.y, accuracy: 0.006)
        XCTAssertEqual(actual.r, expected.r, accuracy: 0.006)
      }
      XCTAssertEqual(island.structures.count, fixture.structures.count)
      for expected in fixture.structures {
        let actual = try XCTUnwrap(island.structures[island.key(expected.gx, expected.gy)])
        XCTAssertEqual(actual.id, expected.id)
        XCTAssertEqual(actual.p, expected.p)
        XCTAssertEqual(actual.m, expected.m)
        XCTAssertEqual(actual.e, expected.e)
      }
      XCTAssertEqual(island.nodes.count, fixture.nodes.count)
      for expected in fixture.nodes {
        let actual = try XCTUnwrap(island.nodes[expected.id])
        XCTAssertEqual(actual.k, expected.k)
        XCTAssertEqual(actual.v, expected.v)
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.006)
        XCTAssertEqual(actual.y, expected.y, accuracy: 0.006)
      }
      XCTAssertEqual(island.chests.count, fixture.chests.count)
      for expected in fixture.chests {
        let actual = try XCTUnwrap(island.chests[expected.id])
        XCTAssertEqual(actual.x, expected.x)
        XCTAssertEqual(actual.y, expected.y)
      }
    }
  }
}
