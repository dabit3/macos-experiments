import XCTest

@testable import Hourgarden

@MainActor
final class GardenStoreTests: XCTestCase {
  private var defaults: UserDefaults!
  private var suite: String!
  private let date = Date(timeIntervalSince1970: 1_800_000_000)

  override func setUp() async throws {
    suite = "hourgarden.tests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suite)
  }

  override func tearDown() async throws {
    defaults.removePersistentDomain(forName: suite)
  }

  func testDeadlineSurvivesRelaunchAndCompletesOnce() throws {
    let store = GardenStore(defaults: defaults)
    XCTAssertTrue(store.start(intention: "Writing", minutes: 25, preview: false, at: date))
    let restarted = GardenStore(defaults: defaults)
    XCTAssertEqual(
      try XCTUnwrap(restarted.data.active).remaining(at: date.addingTimeInterval(600)), 900)
    restarted.synchronize(at: date.addingTimeInterval(1600))
    restarted.synchronize(at: date.addingTimeInterval(1700))
    XCTAssertEqual(restarted.data.specimens.count, 1)
    XCTAssertEqual(restarted.data.specimens[0].completedAt, date.addingTimeInterval(1500))
    XCTAssertNil(restarted.data.active)
    XCTAssertNotNil(GardenStore(defaults: defaults).celebration)
    restarted.dismissCelebration()
    XCTAssertNil(GardenStore(defaults: defaults).celebration)
  }

  func testPausedTimeDoesNotAdvanceAcrossRelaunch() throws {
    let store = GardenStore(defaults: defaults)
    store.start(intention: "Read", minutes: 1, preview: false, at: date)
    store.pause(at: date.addingTimeInterval(10))
    let restarted = GardenStore(defaults: defaults)
    restarted.synchronize(at: date.addingTimeInterval(1000))
    XCTAssertEqual(
      try XCTUnwrap(restarted.data.active).remaining(at: date.addingTimeInterval(1000)), 50)
    restarted.resume(at: date.addingTimeInterval(1000))
    restarted.resume(at: date.addingTimeInterval(1010))
    restarted.synchronize(at: date.addingTimeInterval(1049))
    XCTAssertEqual(
      try XCTUnwrap(restarted.data.active).remaining(at: date.addingTimeInterval(1049)), 1)
    restarted.synchronize(at: date.addingTimeInterval(1050))
    XCTAssertEqual(restarted.data.specimens.count, 1)
  }

  func testCancelNeverAddsPartialHistory() {
    let store = GardenStore(defaults: defaults)
    store.start(intention: "Read", minutes: 1, preview: false, at: date)
    store.cancel(at: date.addingTimeInterval(30))
    store.synchronize(at: date.addingTimeInterval(90))
    XCTAssertNil(store.data.active)
    XCTAssertTrue(store.data.specimens.isEmpty)
    XCTAssertTrue(GardenStore(defaults: defaults).data.specimens.isEmpty)
  }

  func testPauseOrCancelAtDeadlinePreservesCompletedRitual() {
    let store = GardenStore(defaults: defaults)
    store.start(intention: "Read", minutes: 1, preview: false, at: date)
    store.pause(at: date.addingTimeInterval(60))
    store.cancel(at: date.addingTimeInterval(61))
    XCTAssertEqual(store.data.specimens.count, 1)
  }

  func testPreviewUsesRealTwentySecondsAndDoesNotCountTowardGoal() {
    let store = GardenStore(defaults: defaults)
    store.start(intention: "Demo", minutes: 25, preview: true, at: date)
    store.synchronize(at: date.addingTimeInterval(19))
    XCTAssertNotNil(store.data.active)
    store.synchronize(at: date.addingTimeInterval(20))
    XCTAssertEqual(store.data.specimens[0].duration, 20)
    XCTAssertTrue(store.data.specimens[0].isPreview)
    XCTAssertEqual(store.focusedSeconds(on: date), 0)
    XCTAssertEqual(store.sessions(on: date).count, 1)
  }

  func testMidnightTotalsUseCompletionDayAndExcludePreviews() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
    let midnight = calendar.startOfDay(for: date)
    let store = GardenStore(defaults: defaults)
    store.start(
      intention: "Late", minutes: 25, preview: false, at: midnight.addingTimeInterval(-600))
    store.synchronize(at: midnight.addingTimeInterval(900))
    XCTAssertEqual(store.focusedSeconds(on: midnight.addingTimeInterval(-1), calendar: calendar), 0)
    XCTAssertEqual(store.focusedSeconds(on: midnight, calendar: calendar), 1500)
  }

  func testInvalidDurationAndOverlappingStartAreRejected() {
    let store = GardenStore(defaults: defaults)
    XCTAssertFalse(store.start(intention: "Bad", minutes: 0, preview: false, at: date))
    XCTAssertFalse(store.start(intention: "Bad", minutes: 91, preview: false, at: date))
    XCTAssertTrue(store.start(intention: " \n", minutes: 1, preview: false, at: date))
    XCTAssertEqual(store.data.active?.intention, "A little space")
    XCTAssertFalse(store.start(intention: "Overlap", minutes: 10, preview: false, at: date))
    XCTAssertEqual(store.data.active?.duration, 60)
  }

  func testEditingDeletionAndResetPersist() throws {
    let store = GardenStore(defaults: defaults)
    store.start(intention: "Read", minutes: 1, preview: false, at: date)
    store.synchronize(at: date.addingTimeInterval(60))
    let specimen = try XCTUnwrap(store.data.specimens.first)
    store.edit(specimen, intention: "New thought", note: "One quiet page.")
    let restarted = GardenStore(defaults: defaults)
    XCTAssertEqual(restarted.data.specimens.first?.note, "One quiet page.")
    XCTAssertEqual(restarted.data.specimens.first?.intention, "New thought")
    restarted.delete(specimen.id)
    XCTAssertEqual(restarted.focusedSeconds(on: date), 0)
    XCTAssertNil(restarted.celebration)
    restarted.setGoal(999)
    XCTAssertEqual(restarted.data.dailyGoal, 240)
    restarted.reset()
    let reset = GardenStore(defaults: defaults)
    XCTAssertTrue(reset.data.specimens.isEmpty)
    XCTAssertEqual(reset.data.dailyGoal, 60)
  }

  func testCorruptStorageIsNotSilentlyOverwrittenByStart() {
    defaults.set(Data("invalid".utf8), forKey: "hourgarden.v1")
    let store = GardenStore(defaults: defaults)
    XCTAssertNotNil(store.storageMessage)
    XCTAssertFalse(store.start(intention: "Read", minutes: 1, preview: false))
    XCTAssertEqual(defaults.data(forKey: "hourgarden.v1"), Data("invalid".utf8))
  }
}
