import Foundation
import Testing

@testable import RailwayCore

@Test func graphRoutesAreContinuous() {
  for origin in Station.allCases {
    for destination in Station.allCases where destination != origin {
      for scenic in [false, true] {
        let route = Network.route(from: origin, to: destination, scenic: scenic)
        var node = origin.rawValue
        for leg in route {
          let edge = Network.track(leg.trackID)
          #expect((leg.reversed ? edge.to : edge.from) == node)
          node = leg.reversed ? edge.from : edge.to
        }
        #expect(node == destination.rawValue)
      }
    }
  }
}

@Test func signalOccupancySwitchAndDelivery() {
  var sim = Simulation()
  let redDispatched = sim.dispatch("R01")
  let blueDispatched = sim.dispatch("B02")
  #expect(redDispatched)
  #expect(blueDispatched)
  sim.paused = false
  for _ in 0..<12 { sim.tick(1) }
  #expect(sim.corridorOwner == "R01")
  #expect(sim.trains[1].waiting == "Held at signal")
  let changedWhileLocked = sim.toggleEastSwitch()
  #expect(!changedWhileLocked)
  sim.toggleSignal(.harbor)
  sim.tick(1)
  #expect(sim.trains[1].waiting == "Block occupied by R01")
  for _ in 0..<30 { sim.tick(1) }
  #expect(sim.trains[0].state == .delivered)
  #expect(sim.trains[1].waiting == "Set W2 to STW")
  let changedAfterRelease = sim.toggleEastSwitch()
  #expect(changedAfterRelease)
  for _ in 0..<40 { sim.tick(1) }
  #expect(sim.delivered == 2)
  #expect(sim.corridorOwner == nil)
}

@Test func persistencePauseAndCorruptRecovery() throws {
  var sim = Simulation()
  sim.dispatch("R01")
  sim.paused = false
  sim.tick(5)
  sim.paused = true
  let previous = sim
  sim.tick(5)
  #expect(previous == sim)
  let restored = try Simulation.decoded(sim.encoded())
  #expect(restored == sim)
  var invalid = sim
  invalid.trains[0].legIndex = 999
  #expect(throws: SaveError.self) { try Simulation.decoded(invalid.encoded()) }
  invalid = sim
  invalid.corridorOwner = "B02"
  #expect(throws: SaveError.self) { try Simulation.decoded(invalid.encoded()) }
}

@Test func scenicRouteAndSpeed() {
  var sim = Simulation()
  let changedRoute = sim.toggleWestSwitch()
  #expect(changedRoute)
  sim.dispatch("R01")
  #expect(sim.trains[0].route.contains { $0.trackID == "scenic" })
  sim.paused = false
  var fast = sim
  fast.speed = 2
  sim.tick(1)
  fast.tick(1)
  #expect(abs(fast.trains[0].progress - 2 * sim.trains[0].progress) < 0.000001)
}

@Test func occupiedDestinationPreventsConflict() {
  var sim = Simulation()
  sim.setDestination("R01", station: .harbor)
  sim.toggleEastSwitch()
  sim.dispatch("R01")
  sim.paused = false
  for _ in 0..<20 { sim.tick(1) }
  #expect(sim.trains[0].waiting == "Destination platform occupied")
  #expect(sim.corridorOwner == nil)
}

@Test func allRoutesRemainSafeUnderRandomControls() throws {
  var sim = Simulation()
  sim.dispatch("R01")
  sim.dispatch("B02")
  sim.paused = false
  for frame in 0..<2400 {
    if frame % 127 == 0 { sim.toggleSignal(.harbor) }
    if frame % 293 == 0 { sim.toggleWestSwitch() }
    if frame % 137 == 0 { sim.toggleEastSwitch() }
    sim.tick(0.1)
    let admitted = sim.trains.filter { $0.state == .running && $0.legIndex > 0 }
    #expect(admitted.count <= 1)
    #expect(try Simulation.decoded(sim.encoded()) == sim)
  }
}
