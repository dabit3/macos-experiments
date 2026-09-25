import UIKit
import XCTest

@testable import SkyhookSalvage

final class ArtworkTests: XCTestCase {
  func testIllustrationsArePackagedInTheApp() throws {
    let names = CargoKind.allCases.map(\.assetName) + ["Airship", "HarborCover", "HarborBackdrop"]
    for name in names {
      let image = try XCTUnwrap(UIImage(named: name), "\(name) is missing from the app bundle")
      XCTAssertGreaterThan(image.size.width, 0)
      XCTAssertGreaterThan(image.size.height, 0)
    }
  }
}
