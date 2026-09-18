import Foundation

@main
struct EngineTests {
  static func main() {
    testNoInputCrashes()
    testJumpCannotDoubleJump()
    testPauseFreezesTime()
    testRetryAndCheckpoint()
    testTriangleCollision()
    testStagesAreFair()
    testFrameRateIndependence()
    print("PASS: 7 gameplay suites, including all 3 authored stage clears.")
  }

  static func expect(_ condition: Bool, _ message: String) {
    if !condition { fatalError(message) }
  }

  static func play(_ stage: Stage, practice: Bool = false, frame: Double = 1 / 120) -> Engine {
    var run = Engine(stage: stage, practice: practice)
    run.start()
    for _ in 0..<20_000 {
      if run.grounded, let next = run.nextHazardDistance, next < 53, next > 0 {
        run.jump()
      }
      run.advance(frame)
      if run.phase != .running { break }
    }
    return run
  }

  static func testNoInputCrashes() {
    var run = Engine(stage: Stage.all[0], practice: false)
    run.start()
    for _ in 0..<1_000 { run.advance(1 / 120) }
    expect(run.phase == .crashed, "No-input run must collide")
    expect(run.progress > 10 && run.progress < 12, "Crash should occur at first authored spike")
  }

  static func testJumpCannotDoubleJump() {
    var run = Engine(stage: Stage.all[0], practice: false)
    run.start()
    run.jump()
    run.advance(0.1)
    let velocity = run.velocity
    run.jump()
    expect(run.velocity == velocity, "Midair tap must not change jump velocity")
    expect(run.jumps == 1, "Only one actual jump")
    for _ in 0..<100 { run.advance(1 / 120) }
    expect(run.grounded, "Consistent gravity returns to ground")
  }

  static func testPauseFreezesTime() {
    var run = Engine(stage: Stage.all[0], practice: false)
    run.start()
    run.advance(0.1)
    run.jump()
    run.pause()
    let x = run.x
    let y = run.y
    run.advance(30)
    run.jump()
    expect(run.x == x && run.y == y, "Pause must freeze physics and ignore input")
    run.resume()
    run.advance(1 / 120)
    expect(run.x > x && run.x - x < 3, "Resume must not catch up paused time")
  }

  static func testRetryAndCheckpoint() {
    var run = play(Stage.all[0], practice: true)
    expect(run.checkpoint == Stage.all[0].checkpoints.last!, "Final checkpoint reached")
    run.retry()
    expect(run.x == run.checkpoint && run.x > 0, "Practice retry retains checkpoint")
    expect(run.y == 0 && run.grounded && run.phase == .ready, "Retry resets physical state")
    var normal = play(Stage.all[0])
    normal.retry()
    expect(normal.x == 0 && normal.checkpoint == 0, "Normal retry always starts at zero")
  }

  static func testTriangleCollision() {
    let spike = Obstacle(x: 100, width: 40, height: 40, kind: .spike)
    expect(
      !Engine.intersects(x: 101, bottom: 20, halfWidth: 1, height: 20, obstacle: spike),
      "Triangle empty corner is safe")
    expect(
      Engine.intersects(x: 120, bottom: 20, halfWidth: 1, height: 20, obstacle: spike),
      "Triangle apex must collide")
    expect(
      !Engine.intersects(x: 120, bottom: 41, halfWidth: 15, height: 30, obstacle: spike),
      "Jump over apex is safe")
  }

  static func testStagesAreFair() {
    for stage in Stage.all {
      let run = play(stage)
      expect(
        run.phase == .cleared,
        "\(stage.title) must be beatable with legal inputs; got \(run.progress)")
      expect(run.progress == 100, "Clear is exactly 100 percent")
      for marker in stage.checkpoints {
        expect(
          !stage.obstacles.contains { abs($0.x - marker) < 150 },
          "Checkpoint must give a safe landing and a reaction window")
      }
    }
  }

  static func testFrameRateIndependence() {
    let a = play(Stage.all[2], frame: 1 / 120)
    let b = play(Stage.all[2], frame: 1 / 60)
    let c = play(Stage.all[2], frame: 1 / 30)
    expect(
      a.phase == .cleared && b.phase == .cleared && c.phase == .cleared,
      "Authored jumps work at 30, 60 and 120 Hz")
    expect(a.jumps == b.jumps && b.jumps == c.jumps, "Fixed steps preserve required jumps")
  }
}
