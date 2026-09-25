import Foundation

struct ContourSegment {
  let start: CGPoint
  let end: CGPoint
}

enum TerrainContours {
  static let granite = make(phase: 0)
  static let juniper = make(phase: 0.8)
  static let mirror = make(phase: 1.6)

  static func make(phase: Double) -> [[ContourSegment]] {
    let cells = 72
    let width = cells + 1
    let heights = (0..<(width * width)).map { index in
      let x = Double(index % width) / Double(cells)
      let y = Double(index / width) / Double(cells)
      let left = 1.1 * exp(-((x - 0.04) * (x - 0.04) * 7 + (y - 0.18) * (y - 0.18) * 9))
      let right = 1.3 * exp(-((x - 0.97) * (x - 0.97) * 10 + (y - 0.82) * (y - 0.82) * 6))
      let ridge = 0.14 * sin(x * 9 + y * 5 + phase) + 0.06 * cos(x * 14 - y * 9)
      return left + right + ridge
    }
    return stride(from: 0.08, through: 1.55, by: 0.055).map { level in
      var segments: [ContourSegment] = []
      for row in 0..<cells {
        for column in 0..<cells {
          let a = row * width + column
          let b = a + 1
          let c = a + width + 1
          let d = a + width
          for triangle in [[a, b, c], [a, c, d]] {
            var intersections: [CGPoint] = []
            for edge in 0..<3 {
              let first = triangle[edge]
              let second = triangle[(edge + 1) % 3]
              guard (heights[first] < level) != (heights[second] < level) else { continue }
              let mix = (level - heights[first]) / (heights[second] - heights[first])
              let x = Double(first % width) + Double(second % width - first % width) * mix
              let y = Double(first / width) + Double(second / width - first / width) * mix
              intersections.append(CGPoint(x: x / Double(cells), y: y / Double(cells)))
            }
            if intersections.count == 2 {
              segments.append(ContourSegment(start: intersections[0], end: intersections[1]))
            }
          }
        }
      }
      return segments
    }
  }
}
