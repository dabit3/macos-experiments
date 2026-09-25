import XCTest

@testable import MuseumAfterDark

final class HeistEngineTests: XCTestCase {
  func testAllReflectionDirections() {
    XCTAssertEqual(Direction.east.reflected(slash: true), .north)
    XCTAssertEqual(Direction.east.reflected(slash: false), .south)
    for direction in Direction.allCases {
      for slash in [false, true] {
        XCTAssertEqual(direction.reflected(slash: slash).reflected(slash: slash), direction)
      }
    }
  }

  func testInvalidMovementAndRemoteInteractionDoNotConsumeTurns() {
    let room = Rooms.all[0]
    let initial = HeistEngine.initial(room)
    XCTAssertNil(HeistEngine.applying(.move(.south), to: initial, in: room))
    XCTAssertNil(HeistEngine.applying(.interact(room.nodes[0]), to: initial, in: room))
    XCTAssertEqual(initial.turn, 0)
  }

  func testCircuitTurnsOffOnlyItsOwnEmitters() {
    let room = Rooms.all[3]
    var state = HeistEngine.initial(room)
    state.player = Tile(x: 1, y: 5)
    let darkened = HeistEngine.applying(.interact(Tile(x: 2, y: 5)), to: state, in: room)!
    let field = HeistEngine.field(room, darkened)
    XCTAssertFalse(field.danger.contains(Tile(x: 3, y: 4)))
    XCTAssertTrue(field.danger.contains(Tile(x: 3, y: 2)))
    XCTAssertEqual(darkened.turn, 1)
  }

  func testCurrentLaserCatchesBeforeArtifactCanBeTaken() {
    let room = Rooms.all[0]
    var state = HeistEngine.initial(room)
    state.player = Tile(x: 2, y: 4)
    let caught = HeistEngine.applying(.move(.north), to: state, in: room)!
    XCTAssertEqual(caught.outcome, .caught)
    XCTAssertNil(HeistEngine.applying(.wait, to: caught, in: room))
  }

  func testNextSearchlightPositionIsHazardous() {
    let room = Rooms.all[2]
    var state = HeistEngine.initial(room)
    state.player = Tile(x: 4, y: 3)
    XCTAssertFalse(HeistEngine.field(room, state).danger.contains(state.player))
    XCTAssertTrue(HeistEngine.field(room, state, nextTurn: true).danger.contains(state.player))
    XCTAssertEqual(HeistEngine.applying(.wait, to: state, in: room)?.outcome, .caught)
  }

  func testMirrorsRedirectAndWallsStopBeams() {
    let room = Rooms.all[1]
    var state = HeistEngine.initial(room)
    let before = HeistEngine.field(room, state)
    XCTAssertTrue(before.danger.contains(Tile(x: 3, y: 1)))
    XCTAssertFalse(before.danger.contains(Tile(x: 3, y: 4)))
    state.player = Tile(x: 4, y: 3)
    let after = HeistEngine.applying(.interact(Tile(x: 3, y: 3)), to: state, in: room)!
    XCTAssertFalse(HeistEngine.field(room, after).danger.contains(Tile(x: 3, y: 1)))
    XCTAssertTrue(HeistEngine.field(room, after).danger.contains(Tile(x: 3, y: 4)))
    XCTAssertFalse(HeistEngine.field(room, after).danger.contains(Tile(x: 3, y: 7)))
  }

  func testExitRequiresArtifactAndSafeReturn() {
    let room = Rooms.all[0]
    var state = HeistEngine.initial(room)
    XCTAssertEqual(HeistEngine.applying(.wait, to: state, in: room)?.outcome, .playing)
    state.player = Tile(x: 3, y: 2)
    state.power = 0
    let acquired = HeistEngine.applying(.move(.north), to: state, in: room)!
    XCTAssertTrue(acquired.hasArtifact)
    XCTAssertEqual(acquired.outcome, .playing)
    var returning = acquired
    returning.player = Tile(x: 1, y: 5)
    XCTAssertEqual(HeistEngine.applying(.move(.south), to: returning, in: room)?.outcome, .escaped)
  }

  func testEveryAuthoredRoomHasSafeSolutionWithinPar() {
    for room in Rooms.all {
      XCTAssertEqual(Set(room.map.map(\.count)), [7], "Room \(room.id) must be rectangular")
      XCTAssertEqual(room.map.count, 8)
      XCTAssertFalse(HeistEngine.field(room, HeistEngine.initial(room)).danger.contains(room.start))
      guard let route = solve(room) else {
        XCTFail("Room \(room.id) is unsolvable")
        continue
      }
      print(
        "SOLUTION \(room.id): \(route.count) moves: \(route.map(describe).joined(separator: ", "))")
      XCTAssertLessThanOrEqual(route.count, room.par, "Room \(room.id) medal must be achievable")
    }
  }

  @MainActor
  func testUndoAndRelaunchRestoreStateAndSettings() {
    let suite = "museum-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = HeistStore(defaults: defaults)
    store.begin(0)
    store.act(.move(.east))
    let moved = store.state
    store.act(.interact(Tile(x: 2, y: 5)))
    XCTAssertEqual(store.state.power, 2)
    store.undo()
    XCTAssertEqual(store.state, moved)
    store.saved.sound = true
    store.persist()
    let restored = HeistStore(defaults: defaults)
    XCTAssertEqual(restored.state, moved)
    XCTAssertEqual(restored.saved.history.count, 1)
    XCTAssertTrue(restored.saved.sound)
    restored.undo()
    XCTAssertEqual(restored.state, HeistEngine.initial(Rooms.all[0]))
  }

  @MainActor
  func testCompletingRoomUnlocksNextAndKeepsBest() {
    let suite = "museum-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = HeistStore(defaults: defaults)
    store.begin(0)
    for action in solve(store.room)! { store.act(action) }
    XCTAssertEqual(store.state.outcome, .escaped)
    XCTAssertEqual(store.unlocked, 2)
    XCTAssertEqual(store.saved.best[1], store.state.turn)
    let restored = HeistStore(defaults: defaults)
    XCTAssertEqual(restored.unlocked, 2)
    XCTAssertEqual(restored.saved.best, store.saved.best)
  }

  private func describe(_ action: HeistAction) -> String {
    switch action {
    case .move(let direction): return direction.name
    case .wait: return "Wait"
    case .interact(let tile): return "Tap(\(tile.x),\(tile.y))"
    }
  }

  private func solve(_ room: Room) -> [HeistAction]? {
    var queue: [(HeistState, [HeistAction])] = [(HeistEngine.initial(room), [])]
    var visited = Set<HeistState>()
    var index = 0
    while index < queue.count {
      let (state, path) = queue[index]
      index += 1
      for action in HeistEngine.actions(room, state) {
        guard let next = HeistEngine.applying(action, to: state, in: room), next.outcome != .caught
        else { continue }
        let route = path + [action]
        if next.outcome == .escaped { return route }
        var key = next
        key.turn %= 4
        if visited.insert(key).inserted { queue.append((next, route)) }
      }
    }
    return nil
  }
}
