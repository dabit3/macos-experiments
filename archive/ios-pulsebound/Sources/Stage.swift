import Foundation

enum ObstacleKind: Equatable {
  case spike
  case block
}

struct Obstacle: Equatable {
  let x: Double
  let width: Double
  let height: Double
  let kind: ObstacleKind
}

struct Stage: Identifiable {
  let id: Int
  let title: String
  let subtitle: String
  let bpm: Double
  let beats: Double
  let speed: Double
  let obstacles: [Obstacle]
  let checkpoints: [Double]

  var beatDistance: Double { speed * 60 / bpm }
  var length: Double { beats * beatDistance }
  var duration: Int { Int(beats * 60 / bpm) }

  static let all: [Stage] = [
    authored(
      id: 0, title: "First Light", subtitle: "Find the pulse", bpm: 120, beats: 52,
      pattern: [
        (6, 1), (10, 1), (14, 1), (18, 2), (22, 1), (26, 2),
        (30, 1), (34, 2), (38, 1), (42, 2), (46, 2),
      ], checkpointBeats: [12, 24, 36]),
    authored(
      id: 1, title: "Afterimage", subtitle: "Trust your timing", bpm: 132, beats: 64,
      pattern: [
        (6, 1), (9, 2), (12, 1), (15, 2), (20, 3), (23, 1),
        (26, 2), (29, 3), (34, 2), (37, 1), (40, 3), (43, 2),
        (48, 3), (51, 2), (54, 1), (57, 3), (60, 2),
      ], checkpointBeats: [18, 32, 46]),
    authored(
      id: 2, title: "Overdrive", subtitle: "Become the rhythm", bpm: 144, beats: 76,
      pattern: [
        (6, 2), (9, 3), (12, 2), (15, 3), (18, 1), (23, 3),
        (26, 2), (29, 3), (32, 2), (35, 3), (40, 2), (43, 3),
        (46, 1), (49, 3), (52, 2), (57, 3), (60, 2), (63, 3),
        (66, 3), (69, 2), (72, 3),
      ], checkpointBeats: [21, 38, 55]),
  ]

  private static func authored(
    id: Int, title: String, subtitle: String, bpm: Double, beats: Double,
    pattern: [(Double, Int)], checkpointBeats: [Double]
  ) -> Stage {
    let speed = 264.0
    let unit = speed * 60 / bpm
    let obstacles = pattern.flatMap { beat, count in
      (0..<count).map { index in
        Obstacle(
          x: beat * unit + Double(index) * 34,
          width: 34, height: 42, kind: .spike)
      }
    }
    return Stage(
      id: id, title: title, subtitle: subtitle, bpm: bpm, beats: beats, speed: speed,
      obstacles: obstacles, checkpoints: checkpointBeats.map { $0 * unit })
  }
}
