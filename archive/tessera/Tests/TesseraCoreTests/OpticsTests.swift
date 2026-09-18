import XCTest

@testable import TesseraCore

final class OpticsTests: XCTestCase {
  let solutions: [[String: Int]] = [
    ["D7": 0],
    ["C8": 0, "C4": 0],
    ["D5": 0],
    ["C5": 0, "F5": 0, "C8": 1],
    ["D5": 0, "F5": 0, "F2": 1, "D3": 0, "D8": 1],
    ["C6": 0, "F6": 1, "F8": 0, "C3": 0, "F3": 1, "F5": 0, "C9": 1],
  ]

  func testAllSixChambersHavePhysicalSolutionsAndStartUnsolved() {
    XCTAssertEqual(Chambers.all.count, 6)
    for chamber in Chambers.all {
      XCTAssertFalse(RayTracer.trace(chamber, orientations: chamber.initial).solved, chamber.title)
      let trace = RayTracer.trace(chamber, orientations: solutions[chamber.id])
      XCTAssertTrue(trace.solved, chamber.title)
      XCTAssertEqual(trace.powered.count, chamber.receivers.count)
    }
  }

  func testEveryRequiredOpticBreaksItsSolutionWhenRotated() {
    for chamber in Chambers.all {
      for optic in chamber.optics {
        var changed = solutions[chamber.id]
        changed[optic.id] = (changed[optic.id]! + 1) % optic.turns
        XCTAssertFalse(
          RayTracer.trace(chamber, orientations: changed).solved, "\(chamber.title) \(optic.id)")
      }
    }
  }

  func testReflectionIsReversibleForEveryDirection() {
    for direction in Direction.allCases {
      for slash in [true, false] {
        XCTAssertEqual(direction.reflected(slash: slash).reflected(slash: slash), direction)
        XCTAssertNotEqual(direction.reflected(slash: slash), direction)
      }
    }
  }

  func testPrismRejectsWrongIntakeAndSplitsIntoExactColors() {
    let chamber = Chambers.all[2]
    for angle in 1...3 {
      XCTAssertEqual(RayTracer.trace(chamber, orientations: ["D5": angle]).powered.count, 0)
    }
    let trace = RayTracer.trace(chamber, orientations: ["D5": 0])
    XCTAssertEqual(Set(trace.beams.map(\.color)), Set(Spectrum.allCases))
    XCTAssertTrue(trace.solved)
  }

  func testWrongColorDoesNotPowerReceiver() {
    let chamber = Chamber(
      id: 10, title: "", subtitle: "", lesson: "", hint: "",
      source: Cell(-1, 4), color: .blue, optics: [],
      receivers: [Receiver(4, 4, .red)], walls: [])
    XCTAssertFalse(RayTracer.trace(chamber, orientations: [:]).solved)
  }

  func testWallStopsRay() {
    let chamber = Chamber(
      id: 10, title: "", subtitle: "", lesson: "", hint: "",
      source: Cell(-1, 4), color: .red, optics: [],
      receivers: [Receiver(4, 4, .red)], walls: [Cell(2, 4)])
    let trace = RayTracer.trace(chamber, orientations: [:])
    XCTAssertFalse(trace.solved)
    XCTAssertEqual(trace.beams.last?.end, Cell(2, 4))
  }

  func testRotateUndoResetAndUndoReset() {
    let chamber = Chambers.all[1]
    var state = ChamberState(chamber: chamber)
    let initial = state
    state.rotate(chamber.optics[0])
    XCTAssertNotEqual(state.orientations, initial.orientations)
    state.undo()
    XCTAssertEqual(state, initial)
    state.rotate(chamber.optics[0])
    let rotated = state.orientations
    state.reset(chamber)
    XCTAssertEqual(state.orientations, chamber.initial)
    state.undo()
    XCTAssertEqual(state.orientations, rotated)
  }

  func testPersistenceRoundTripIncludingUndoAndProgress() throws {
    var progress = Progress()
    progress.completed = [0, 1]
    progress.current = 2
    var state = ChamberState(chamber: Chambers.all[2])
    state.rotate(Chambers.all[2].optics[0])
    progress.states[2] = state
    XCTAssertEqual(Progress.decode(try progress.encoded()), progress)
    XCTAssertEqual(progress.unlocked, 2)
  }

  func testCorruptAndInvalidPersistenceRecovers() throws {
    XCTAssertEqual(Progress.decode(Data("broken".utf8)), Progress())
    var progress = Progress()
    progress.current = 900
    progress.completed = [-1, 100]
    var state = ChamberState(chamber: Chambers.all[0])
    state.orientations = ["D7": -99, "garbage": 1]
    progress.states = [0: state, 100: state]
    let restored = Progress.decode(try progress.encoded())
    XCTAssertEqual(restored.current, 0)
    XCTAssertEqual(restored.completed, [])
    XCTAssertEqual(restored.states[0]?.orientations, Chambers.all[0].initial)
    XCTAssertNil(restored.states[100])
  }
}
