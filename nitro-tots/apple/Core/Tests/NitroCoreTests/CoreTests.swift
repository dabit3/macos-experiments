import Foundation
import XCTest

@testable import NitroCore

final class CoreTests: XCTestCase {
  struct Fixture: Decodable {
    let trackId: String
    let snapshots: [Snapshot]
    let tick: Int
    let results: [RaceResult]
  }
  func testDartRuleFixtures() throws {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "fixtures", withExtension: "json"))
    let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
    for fixture in fixtures {
      let track = Catalog.shared.track(fixture.trackId)
      let racers = Catalog.shared.characters.enumerated().map { i, c in
        Racer(
          RacerProfile(
            slot: i, playerId: "", name: c.name, character: c.id,
            kart: Catalog.shared.karts[i % 6].id, bot: true, platform: "bot"))
      }
      let sim = RaceSim(
        track: track, racers: racers, seed: 4242, laps: 1, mode: track.isArena ? .battle : .race,
        battleSeconds: 30)
      let bots = racers.map { BotDriver(slot: $0.slot, seed: 4242) }
      while sim.phase != .finished && sim.tick < 12000 {
        sim.step([:]) { s, r in bots[r.slot].drive(s, r) }
        if let snapshot = fixture.snapshots.first(where: { $0.tick == sim.tick }) {
          for state in snapshot.racers {
            let racer = try XCTUnwrap(sim.racer(state.s))
            XCTAssertEqual(
              racer.pos.x, state.x, accuracy: 0.011,
              "\(fixture.trackId) tick \(sim.tick), slot \(state.s)")
            XCTAssertEqual(racer.pos.y, state.y, accuracy: 0.011)
            XCTAssertEqual(racer.lap, state.l)
            XCTAssertEqual(racer.item, state.i)
          }
        }
      }
      XCTAssertEqual(sim.tick, fixture.tick, fixture.trackId)
      XCTAssertEqual(sim.results, fixture.results, fixture.trackId)
    }
  }
  func testInputEdgesAndWireEncoding() throws {
    var buffer = InputBuffer()
    buffer.add(KartInput(item: true))
    buffer.add(KartInput(throttle: -1, steer: 0.5, drift: true, lookBack: true))
    let input = buffer.consume()
    XCTAssertTrue(input.item)
    XCTAssertFalse(buffer.consume().item)
    let data = try JSONEncoder().encode(ClientMessage.input(88, input))
    struct Wire: Decodable {
      let type: String
      let tick, d, i, b: Int
      let t, s: Double
    }
    let wire = try JSONDecoder().decode(Wire.self, from: data)
    XCTAssertEqual(wire.type, "input")
    XCTAssertEqual(wire.tick, 88)
    XCTAssertEqual(wire.t, -1)
    XCTAssertEqual(wire.s, 0.5)
    XCTAssertEqual([wire.d, wire.i, wire.b], [1, 1, 1])
  }
  func testGeometryAndStandings() {
    for track in Catalog.shared.tracks {
      XCTAssertEqual(track.samples.count, 512)
      XCTAssertEqual(track.startGrid.count, 8)
      XCTAssertGreaterThan(track.length, 100)
    }
    let results = (0..<8).map { i in
      RaceResult(
        slot: i, name: "Racer \(i)", character: "pip", kart: "jellybean", bot: false,
        platform: "test", place: 8 - i, finishTick: 3000, lapTicks: [2880],
        points: pointsForPlace(8 - i), score: 0)
    }
    let combined = standings([results, results])
    XCTAssertEqual(combined.first?.slot, 7)
    XCTAssertEqual(combined.first?.points, 30)
    XCTAssertEqual(combined.last?.places, [8, 8])
  }
}
