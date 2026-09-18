import XCTest

@testable import LanternfallCore

final class GameTests: XCTestCase {
  func testPauseFreezesAllSimulation() {
    var game = GameModel(seed: 42)
    game.movement = V2(x: 1)
    game.tick(0.05)
    let elapsed = game.elapsed
    let player = game.player
    game.pause()
    for _ in 0..<500 { game.tick(0.05) }
    XCTAssertEqual(game.elapsed, elapsed)
    XCTAssertEqual(game.player, player)
    XCTAssertEqual(game.movement, .zero)
    game.resume()
    game.tick(0.05)
    XCTAssertGreaterThan(game.elapsed, elapsed)
  }
  func testUpgradeConsumesExperienceAndChangesWeapon() {
    var game = GameModel(seed: 19)
    game.experience = game.neededExperience
    game.checkLevel()
    XCTAssertEqual(game.level, 2)
    XCTAssertEqual(game.phase, .choosing)
    XCTAssertEqual(Set(game.choices).count, 3)
    game.choices = [.lantern, .orbit, .nova]
    game.choose(.lantern)
    game.enemies = [Enemy(id: 99, position: V2(x: 100), health: 100, maxHealth: 100, kind: .shade)]
    game.fireVolley()
    XCTAssertEqual(game.bolts.count, 2)
    XCTAssertEqual(game.experience, 0)
  }
  func testProjectileCollisionDropsRealExperience() {
    var game = GameModel(seed: 4)
    game.enemies = [Enemy(id: 99, position: V2(x: 50), health: 10, maxHealth: 10, kind: .shade)]
    game.bolts = [Bolt(id: 100, position: V2(x: 40), velocity: V2(x: 100))]
    game.tick(0.05)
    XCTAssertEqual(game.kills, 1)
    XCTAssertFalse(game.pickups.isEmpty)
    game.player = game.pickups[0].position
    game.tick(0.05)
    XCTAssertGreaterThan(game.experience, 0)
  }
  func testSpawnsAreOutsideImmediateDangerAndDeterministic() {
    var first = GameModel(seed: 23)
    var second = GameModel(seed: 23)
    for _ in 0..<100 {
      first.spawnEnemy()
      second.spawnEnemy()
    }
    XCTAssertEqual(first.enemies.map(\.position), second.enemies.map(\.position))
    XCTAssertTrue(first.enemies.allSatisfy { ($0.position - first.player).length >= 360 })
  }
  func testBossAndDawnWinCondition() {
    var game = GameModel(seed: 2)
    game.elapsed = 240
    game.tick(0.01)
    XCTAssertEqual(game.enemies.filter { $0.kind == .boss }.count, 1)
    game.elapsed = 299.99
    game.bossDefeated = true
    game.tick(0.02)
    XCTAssertEqual(game.phase, .victory)
    XCTAssertEqual(game.elapsed, 300)
    var losing = GameModel(seed: 2)
    losing.elapsed = 299.99
    losing.tick(0.02)
    XCTAssertEqual(losing.phase, .defeat)
  }
  func testHealthDamageCooldownAndDefeat() {
    var game = GameModel(seed: 5)
    game.health = 10
    game.enemies = [Enemy(id: 99, position: .zero, health: 100, maxHealth: 100, kind: .shade)]
    game.tick(0.01)
    XCTAssertEqual(game.phase, .defeat)
    XCTAssertEqual(game.health, 0)
  }
  func testNormalizedMovementAndBoundary() {
    var game = GameModel(seed: 3)
    game.movement = V2(x: 1, y: 1)
    game.tick(0.05)
    XCTAssertEqual(game.player.length, 145 * 0.05, accuracy: 0.001)
    game.player = V2(x: 1100, y: 1100)
    game.tick(0.05)
    XCTAssertLessThanOrEqual(game.player.x, 1100)
    XCTAssertLessThanOrEqual(game.player.y, 1100)
  }
  func testCollectedGemCannotGrantExperienceTwice() {
    var game = GameModel(seed: 12)
    game.pickups = [Pickup(id: 99, position: .zero, value: 3, healing: false)]
    game.tick(0.01)
    XCTAssertEqual(game.experience, 3)
    for _ in 0..<20 { game.tick(0.01) }
    XCTAssertEqual(game.experience, 3)
    XCTAssertTrue(game.pickups.isEmpty)
  }
  func testBackloggedGiftsPreserveExperienceAndAllowGameplay() {
    var game = GameModel(seed: 12)
    game.experience = 1000
    game.checkLevel()
    let remaining = game.experience
    game.choose(game.choices[0])
    XCTAssertEqual(game.phase, .playing)
    for _ in 0..<100 { game.tick(0.05) }
    XCTAssertEqual(game.phase, .playing)
    XCTAssertEqual(game.experience, remaining)
    for _ in 0..<62 { game.tick(0.05) }
    XCTAssertEqual(game.phase, .choosing)
    XCTAssertEqual(game.level, 3)
    XCTAssertLessThan(game.experience, remaining)
  }
  func testThornsWarnBeforeDamageAndMovingEscapes() {
    var still = GameModel(seed: 1)
    still.blooms = [ThornBloom(id: 99, position: .zero)]
    var moving = still
    moving.movement = V2(x: 1)
    for _ in 0..<30 {
      still.tick(0.05)
      moving.tick(0.05)
    }
    XCTAssertEqual(still.health, 100)
    for _ in 0..<10 {
      still.tick(0.05)
      moving.tick(0.05)
    }
    XCTAssertEqual(still.health, 84)
    XCTAssertEqual(moving.health, 100)
  }
  func testDefeatExplainsTheLethalDamageSource() {
    var bloom = GameModel(seed: 1)
    bloom.health = 10
    bloom.blooms = [ThornBloom(id: 99, position: .zero, age: ThornBloom.warning)]
    bloom.tick(0.01)
    XCTAssertEqual(bloom.phase, .defeat)
    XCTAssertEqual(bloom.defeatCause, .thorns)
    var enemy = GameModel(seed: 1)
    enemy.health = 10
    enemy.enemies = [Enemy(id: 99, position: .zero, health: 50, maxHealth: 50, kind: .moth)]
    enemy.tick(0.01)
    XCTAssertEqual(enemy.phase, .defeat)
    XCTAssertEqual(enemy.defeatCause, .moth)
  }
}
