import Foundation
import XCTest

@testable import LastfortKit

final class ProfileTests: XCTestCase {
  @MainActor func testExistingApplePreferencesMigrateAndRemainEditable() throws {
    let name = "lastfort.migration.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set("Island Veteran", forKey: "flutter.name")
    defaults.set(2100, forKey: "flutter.xp")
    defaults.set(["outfit_ember"], forKey: "flutter.unlocked")
    defaults.set(["1", "2"], forKey: "flutter.claimed")
    defaults.set(false, forKey: "flutter.sound")
    defaults.set(
      "{\"matches\":9,\"wins\":2,\"kills\":12,\"damage\":420,\"harvested\":90,\"built\":30,\"best\":1}",
      forKey: "flutter.career")
    let profile = Profile(defaults: defaults)
    XCTAssertEqual(profile.data.name, "Island Veteran")
    XCTAssertEqual(profile.data.xp, 2100)
    XCTAssertTrue(profile.data.unlocked.contains("outfit_ember"))
    XCTAssertTrue(profile.data.unlocked.contains("outfit_recruit"))
    XCTAssertEqual(profile.data.claimed, [1, 2])
    XCTAssertEqual(profile.data.career.bestPlacement, 1)
    XCTAssertFalse(profile.data.sound)
    profile.data.name = "Native Veteran"
    let restored = Profile(defaults: defaults)
    XCTAssertEqual(restored.data.name, "Native Veteran")
    XCTAssertEqual(restored.data.career.wins, 2)
  }
}
