import XCTest

final class PulseboundUITests: XCTestCase {
  func testFailureRetryAndPause() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["stage.0"].tap()
    app.buttons["mode.normal"].tap()
    app.buttons["Play First Light"].tap()
    let jump = app.buttons["jump"]
    XCTAssertTrue(jump.waitForExistence(timeout: 5))
    jump.tap()
    let retry = app.buttons["retry"]
    XCTAssertTrue(retry.waitForExistence(timeout: 8))
    retry.tap()
    app.buttons["Pause"].tap()
    XCTAssertTrue(app.staticTexts["Between beats."].exists)
    app.buttons["Resume the flow"].tap()
    XCTAssertTrue(retry.waitForExistence(timeout: 8))
    app.buttons["Back to tracks"].tap()
    XCTAssertTrue(app.buttons["stage.0"].exists)
  }
}
