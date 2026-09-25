import Foundation

@main
struct CoreTests {
  static var count = 0
  static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
      fatalError("FAIL: \(message)")
    }
    count += 1
    print("PASS: \(message)")
  }

  static func main() throws {
    for level in PoolLevel.all {
      expect(level.terrain.count == 16, "Shore \(level.id + 1) has 16 habitats")
      expect(
        Puzzle.restored(level.reference, level: level),
        "Shore \(level.id + 1) reference truly restores")
      let solution = Puzzle.solution(level: level, preserving: [])
      expect(solution != nil, "Shore \(level.id + 1) solver finds a complete solution")
      expect(
        solution.map { Puzzle.restored($0, level: level) } == true,
        "Shore \(level.id + 1) solver output satisfies every constraint")
      let prefix = Array(level.reference.prefix(2))
      let continuation = Puzzle.solution(level: level, preserving: prefix)
      expect(
        continuation.map { result in prefix.allSatisfy { result.contains($0) } } == true,
        "Shore \(level.id + 1) hint preserves existing residents")
      expect(!Puzzle.restored([], level: level), "Empty shore \(level.id + 1) is not a win")
    }
    let first = PoolLevel.all[0]
    expect(Puzzle.adjacent(0, 1), "Horizontal neighbors")
    expect(Puzzle.adjacent(0, 4), "Vertical neighbors")
    expect(!Puzzle.adjacent(0, 5), "Diagonal neighbors are excluded")
    expect(!Puzzle.adjacent(3, 4), "Row wrapping is excluded")
    expect(
      Puzzle.placementError(.coral, cell: 2, in: [], level: first) != nil,
      "Coral is rejected from water")
    expect(
      Puzzle.placementError(.clownfish, cell: 0, in: [], level: first) != nil,
      "Fish is rejected from rock")
    expect(
      Puzzle.placementError(.coral, cell: -1, in: [], level: first) != nil,
      "Negative cell is rejected")
    expect(
      Puzzle.placementError(.coral, cell: 16, in: [], level: first) != nil,
      "Out-of-bounds cell is rejected")
    expect(
      Puzzle.placementError(
        .anemone, cell: 0, in: [Placement(creature: .coral, cell: 0)], level: first) != nil,
      "Occupied cell is rejected")
    expect(
      Puzzle.placementError(
        .coral, cell: 1, in: [Placement(creature: .coral, cell: 0)], level: first) != nil,
      "Species inventory cannot be exceeded")
    let lonelyFish = Placement(creature: .clownfish, cell: 3)
    expect(
      !Puzzle.healthy(lonelyFish, board: [lonelyFish], level: first), "Fish requires an anemone")
    expect(
      !Puzzle.healthy(
        Placement(creature: .anemone, cell: 5),
        board: [Placement(creature: .coral, cell: 0)], level: first),
      "Diagonal coral does not support anemone")
    let third = PoolLevel.all[2]
    let crowdedCorals = [
      Placement(creature: .coral, cell: 0), Placement(creature: .coral, cell: 1),
    ]
    expect(
      !Puzzle.healthy(crowdedCorals[0], board: crowdedCorals, level: third),
      "Room to grow enforces coral separation")
    let urchin = Placement(creature: .urchin, cell: 0)
    expect(
      !Puzzle.healthy(
        urchin,
        board: [
          urchin, Placement(creature: .coral, cell: 1), Placement(creature: .coral, cell: 4),
        ],
        level: third),
      "Urchin needs an empty neighboring space")
    let fourth = PoolLevel.all[3]
    expect(
      !Puzzle.healthy(
        Placement(creature: .urchin, cell: 1),
        board: [Placement(creature: .urchin, cell: 1), Placement(creature: .coral, cell: 0)],
        level: fourth),
      "Quiet refuge keeps urchin away from coral")
    expect(
      Puzzle.solution(level: first, preserving: [Placement(creature: .clownfish, cell: 15)]) == nil,
      "Solver rejects invalid preserved board")

    let directory = FileManager.default.homeDirectoryForCurrentUser
      .appending(path: "tidepool-test-\(UUID().uuidString)", directoryHint: .isDirectory)
    let file = ProgressFile(url: directory.appending(path: "progress.json"))
    defer { try? FileManager.default.removeItem(at: directory) }
    expect(file.load() == SavedProgress(), "Missing save recovers with first shore")
    let saved = SavedProgress(currentLevel: 1, completed: [0], boards: [0: first.reference])
    try file.save(saved)
    expect(file.load() == saved, "Atomic persistence round-trip preserves unlocks and board")
    try Data("broken".utf8).write(to: file.url)
    expect(file.load() == SavedProgress(), "Corrupt save recovers safely")
    var unsafe = SavedProgress(
      currentLevel: 99, completed: [-1, 0, 100], boards: [0: [lonelyFish], 8: []])
    unsafe.sanitize()
    expect(
      unsafe.currentLevel == 1 && unsafe.completed == [0],
      "Invalid progress is bounded to unlocked shores")
    expect(
      unsafe.boards[8] == nil && unsafe.boards[0] != nil,
      "Save validation retains valid partial boards")
    print("\n\(count) assertions passed.")
  }
}
