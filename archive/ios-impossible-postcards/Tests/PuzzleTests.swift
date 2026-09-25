@testable import PostcardRules
import XCTest

final class PuzzleTests: XCTestCase {
    func testEveryAuthoredChapterHasARealCompletableRoute() throws {
        for chapter in Chapters.all {
            let actions = try XCTUnwrap(chapter.shortestSolution(), chapter.title)
            var state = chapter.initialState
            for action in actions {
                state = try XCTUnwrap(chapter.applying(action, to: state))
            }
            XCTAssertTrue(chapter.hasArrived(state))
            XCTAssertEqual(state.moves, actions.count)
            XCTAssertEqual(state.switches, chapter.requiredSwitches)
            XCTAssertNil(chapter.applying(.rotate(0), to: state))
            print("OPTIMAL \(chapter.id + 1): \(actions.count) moves — \(actions)")
        }
    }

    func testRotationChangesConnectivityAndFourTurnsRestoreIt() throws {
        for chapter in Chapters.all {
            var state = chapter.initialState
            state.switches = chapter.requiredSwitches
            for (index, mechanism) in chapter.mechanisms.enumerated() {
                let original = Set(chapter.neighbors(of: mechanism.center, state: state))
                state = try XCTUnwrap(chapter.applying(.rotate(index), to: state))
                XCTAssertNotEqual(original, Set(chapter.neighbors(of: mechanism.center, state: state)))
                for _ in 0 ..< 3 {
                    state = try XCTUnwrap(chapter.applying(.rotate(index), to: state))
                }
                XCTAssertEqual(original, Set(chapter.neighbors(of: mechanism.center, state: state)))
            }
        }
    }

    func testDisconnectedTapCannotTeleportOrActivateASeal() {
        let chapter = Chapters.all[0]
        let state = chapter.initialState
        XCTAssertNil(chapter.path(to: 3, state: state))
        XCTAssertNil(chapter.applying(.walk(3), to: state))
        XCTAssertEqual(state.switches, 0)
        XCTAssertEqual(state.moves, 0)
        XCTAssertEqual(chapter.path(to: 2, state: state), [1, 2])
    }

    func testSealsGateTheDestinationAndUnlockUpperMechanism() throws {
        let chapter = Chapters.all[2]
        var state = chapter.initialState
        XCTAssertFalse(chapter.canRotate(1, state: state))
        XCTAssertNil(chapter.applying(.rotate(1), to: state))
        XCTAssertFalse(chapter.connections(state).contains { $0.to == chapter.destination })
        for tile in [1, 2, 3] {
            state = try XCTUnwrap(chapter.applying(.walk(tile), to: state))
        }
        XCTAssertEqual(state.switches, 1)
        XCTAssertTrue(chapter.canRotate(1, state: state))
        XCTAssertFalse(chapter.connections(state).contains { $0.to == chapter.destination })
    }

    func testRoutesUseConnectedEdgesAndCountEveryLanding() throws {
        for chapter in Chapters.all {
            let initial = chapter.initialState
            for tile in chapter.tiles {
                guard let path = chapter.path(to: tile.id, state: initial) else { continue }
                var state = initial
                for landing in path {
                    state = try XCTUnwrap(chapter.applying(.walk(landing), to: state))
                }
                XCTAssertEqual(state.tile, tile.id)
                XCTAssertEqual(state.moves, path.count)
            }
        }
    }

    func testEveryReachablePositionCanStillFinishWithoutRestarting() {
        for chapter in Chapters.all {
            var queue = [chapter.initialState]
            var visited: Set<SearchKey> = [chapter.initialState.searchKey]
            var cursor = 0
            while cursor < queue.count {
                let state = queue[cursor]
                cursor += 1
                if chapter.hasArrived(state) {
                    continue
                }
                let actions = chapter.neighbors(of: state.tile, state: state).map(PuzzleAction.walk)
                    + chapter.mechanisms.indices.map(PuzzleAction.rotate)
                for action in actions {
                    guard let next = chapter.applying(action, to: state),
                          visited.insert(next.searchKey).inserted else { continue }
                    queue.append(next)
                }
            }
            for state in queue {
                XCTAssertNotNil(chapter.shortestSolution(from: state), "\(chapter.title): \(state)")
            }
        }
    }

    func testSavedStateValidationAndCodableRoundTrip() throws {
        let chapter = Chapters.all[0]
        let state = chapter.initialState
        XCTAssertTrue(chapter.isValid(state))
        XCTAssertEqual(try JSONDecoder().decode(PuzzleState.self, from: JSONEncoder().encode(state)), state)
        XCTAssertFalse(chapter.isValid(PuzzleState(tile: 99, orientations: [0])))
        XCTAssertFalse(chapter.isValid(PuzzleState(tile: 0, orientations: [])))
        XCTAssertFalse(chapter.isValid(PuzzleState(tile: 0, orientations: [8])))
        XCTAssertFalse(chapter.isValid(PuzzleState(tile: 0, orientations: [0], switches: 8)))
        XCTAssertFalse(chapter.isValid(PuzzleState(tile: 0, orientations: [0], moves: -1)))
    }
}
