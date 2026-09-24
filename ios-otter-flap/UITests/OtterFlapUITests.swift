import XCTest

final class OtterFlapUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testFlapCrashAndReplay() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["title"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sound"].exists)
        attach(app, "1-title")

        let playfield = app.otherElements["playfield"].firstMatch
        let tapTarget = playfield.exists ? playfield : app.windows.firstMatch
        tapTarget.tap()

        let playAgain = app.buttons["playAgain"]
        XCTAssertTrue(playAgain.waitForExistence(timeout: 10), "Otter eventually splashes down and results appear")
        XCTAssertTrue(app.descendants(matching: .any)["finalScore"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["bestScore"].firstMatch.exists)
        attach(app, "3-results")

        playAgain.tap()
        XCTAssertTrue(app.descendants(matching: .any)["title"].firstMatch.waitForExistence(timeout: 3), "Replay returns to the ready screen")
        XCTAssertFalse(playAgain.exists)
    }

    func testScoringThroughLogs() {
        let app = XCUIApplication()
        app.launchArguments = ["-autopilotScore", "3", "-seed", "42"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["title"].firstMatch.waitForExistence(timeout: 5))
        app.windows.firstMatch.tap()

        XCTAssertTrue(app.descendants(matching: .any)["score"].firstMatch.waitForExistence(timeout: 3))
        sleep(3)
        attach(app, "2-playing")

        let playAgain = app.buttons["playAgain"]
        XCTAssertTrue(playAgain.waitForExistence(timeout: 30))
        XCTAssertEqual(app.descendants(matching: .any)["finalScore"].firstMatch.label, "SCORE, 3")
        attach(app, "4-results-scored")
    }

    func testSoundToggle() {
        let app = XCUIApplication()
        app.launch()
        let sound = app.buttons["sound"]
        XCTAssertTrue(sound.waitForExistence(timeout: 5))
        let before = sound.label
        sound.tap()
        XCTAssertNotEqual(sound.label, before)
        sound.tap()
        XCTAssertEqual(sound.label, before)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
