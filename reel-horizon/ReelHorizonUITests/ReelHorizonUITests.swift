import XCTest

/// Golden-path UI tests. They drive the real app through the accessibility identifiers
/// exposed on every control and attach screenshots so the xcresult bundle doubles as evidence.
final class ReelHorizonUITests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--reset-profile", "--skip-tutorial", "--fast-fish", "--rich"]
    app.launch()
  }

  private func snap(_ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func wait(_ element: XCUIElement, _ timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(element.waitForExistence(timeout: timeout), "missing \(element)", file: file, line: line)
  }

  func testHomeShowsMapAndMenus() {
    wait(app.otherElements["home.map"])
    XCTAssertTrue(app.staticTexts["REEL HORIZON"].exists)
    snap("home")
    app.buttons["home.shop"].tap()
    wait(app.buttons["shop.tab.rods"])
    snap("shop")
    app.buttons["shop.tab.rods"].tap()
    XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'shop.buy.'")).count > 0)
    app.buttons["header.back"].tap()
    app.buttons["home.missions"].tap()
    wait(app.staticTexts["header.title"])
    XCTAssertTrue(app.staticTexts["header.title"].label.localizedCaseInsensitiveContains("missions"))
    snap("missions")
    app.buttons["header.back"].tap()
    app.buttons["home.profile"].tap()
    wait(app.staticTexts["header.title"])
    XCTAssertTrue(app.staticTexts["header.title"].label.localizedCaseInsensitiveContains("angler"))
    snap("angler")
    app.buttons["header.back"].tap()
    wait(app.otherElements["home.map"])
  }

  func testBuyAndEquipLure() {
    wait(app.otherElements["home.map"])
    app.buttons["home.shop"].tap()
    wait(app.buttons["shop.tab.lures"])
    app.buttons["shop.tab.lures"].tap()
    let buy = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'shop.buy.'")).firstMatch
    wait(buy)
    let id = buy.identifier.replacingOccurrences(of: "shop.buy.", with: "")
    buy.tap()
    let equip = app.buttons["shop.equip.\(id)"]
    wait(equip)
    equip.tap()
    XCTAssertTrue(app.staticTexts["EQUIPPED"].waitForExistence(timeout: 4))
    snap("shop-equipped")
  }

  func testCastStrikeAndLandAFish() {
    wait(app.otherElements["home.map"])
    app.buttons["home.waterwayInfo"].tap()
    wait(app.buttons["location.goFishing"])
    snap("location")
    app.buttons["location.goFishing"].tap()
    let cast = app.buttons["fishing.cast"]
    wait(cast)
    snap("fishing-ready")

    // Big fish can legitimately snap the starter line, so allow a few casts before failing.
    let keep = app.buttons["catch.keep"]
    let release = app.buttons["catch.release"]
    let outcome = app.buttons["outcome.continue"]
    var landed = false
    for attempt in 1...3 {
      castStrikeAndFight(cast: cast, attempt: attempt)
      if outcome.exists {
        snap("fishing-lost-\(attempt)")
        outcome.tap()
        wait(cast, 6)
        continue
      }
      landed = true
      break
    }
    XCTAssertTrue(landed, "fish was lost on every attempt")
    wait(keep, 4)
    snap("catch-card")
    XCTAssertTrue(app.staticTexts["catch.species"].exists)
    if keep.isEnabled { keep.tap() } else { release.tap() }
    wait(cast, 6)

    app.buttons["fishing.endDay"].tap()
    wait(app.buttons["summary.done"])
    snap("day-summary")
    if app.buttons["summary.sell"].isEnabled { app.buttons["summary.sell"].tap() }
    app.buttons["summary.done"].tap()
    wait(app.otherElements["home.map"])
  }

  /// Casts, waits for a bite, strikes and works the fish until the session shows either the
  /// catch card or the lost-fish outcome.
  private func castStrikeAndFight(cast: XCUIElement, attempt: Int) {
    // Hold to charge, release to cast.
    cast.press(forDuration: 0.6)
    let status = app.staticTexts["fishing.status"]
    wait(status)
    XCTAssertTrue(waitForStatus(containing: "BITE", or: "RETRIEVE", timeout: 10) || waitForStatus(containing: "STRIKE", or: "FISH ON", timeout: 1))
    if attempt == 1 { snap("fishing-soaking") }

    // With --fast-fish a bite arrives quickly; strike as soon as the button appears.
    let strike = app.buttons["fishing.strike"]
    let scene = app.otherElements["fishing.scene"]
    var hooked = false
    for _ in 0..<40 {
      if strike.waitForExistence(timeout: 1) {
        strike.tap()
        if waitForStatus(containing: "FISH ON", or: "TIGHT", timeout: 2) || waitForStatus(containing: "EASE", or: "SNAP", timeout: 1) || app.staticTexts["catch.species"].exists {
          hooked = true
          break
        }
      } else if !scene.exists {
        break
      }
      if app.staticTexts["LANDED!"].exists || app.buttons["catch.keep"].exists {
        hooked = true
        break
      }
    }
    XCTAssertTrue(hooked, "never hooked a fish")
    if attempt == 1 { snap("fishing-fight") }

    // Pump the reel in short bursts so the tension stays out of the red.
    let reel = app.buttons["fishing.reel"]
    let keep = app.buttons["catch.keep"]
    let release = app.buttons["catch.release"]
    let outcome = app.buttons["outcome.continue"]
    for _ in 0..<240 {
      if keep.exists || release.exists || outcome.exists { break }
      let tension = app.staticTexts["fishing.tension"].label
      let pct = Int(tension.replacingOccurrences(of: "%", with: "")) ?? 50
      if pct < 60 {
        reel.press(forDuration: 0.3)
      } else {
        Thread.sleep(forTimeInterval: 0.25)
      }
    }
  }

  private func waitForStatus(containing a: String, or b: String, timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      let label = app.staticTexts["fishing.status"].label
      if label.contains(a) || label.contains(b) { return true }
      Thread.sleep(forTimeInterval: 0.1)
    }
    return false
  }
}
