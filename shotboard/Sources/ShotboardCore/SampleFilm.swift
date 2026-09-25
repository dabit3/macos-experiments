import Foundation

enum SampleFilm {
  static func make() -> Storyboard {
    let coast = Scene(title: "The approach", location: "EXT. COAST / BLUE HOUR")
    let tower = Scene(title: "The keeper", location: "INT. LIGHTHOUSE / DAWN")
    let dawn = Scene(title: "First light", location: "EXT. LANTERN / SUNRISE")
    return Storyboard(
      title: "The Last Light", subtitle: "A quiet film about finding the way home.",
      scenes: [coast, tower, dawn],
      shots: [
        Shot(
          sceneID: coast.id, title: "A light on the edge", duration: 8,
          notes: "Hold on the headland. A single beam cuts through the sea mist.",
          strokes: landscape()),
        Shot(
          sceneID: coast.id, title: "Someone is waiting", size: .medium, movement: .tracking,
          duration: 6, notes: "Follow the keeper along the breakwater. Let the horizon breathe.",
          strokes: keeper()),
        Shot(
          sceneID: tower.id, title: "The climb", size: .overhead, movement: .tilt,
          duration: 5, notes: "Look down the spiral. Footsteps rise before the keeper appears.",
          strokes: stairs()),
        Shot(
          sceneID: tower.id, title: "One small gesture", size: .detail, duration: 4,
          notes: "A hand turns the brass switch. The mechanism wakes.",
          strokes: switchDetail()),
        Shot(
          sceneID: dawn.id, title: "The room fills with gold", size: .closeUp,
          movement: .dolly, duration: 7,
          notes: "Push toward the lens. Warm light spills across the keeper's silhouette.",
          strokes: lantern()),
        Shot(
          sceneID: dawn.id, title: "The way home", movement: .pan, duration: 10,
          notes: "The boat returns. Hold the empty water after it passes. Fade to ivory.",
          strokes: boat()),
      ])
  }

  static func line(
    _ coordinates: [(Double, Double)], _ color: InkColor = .graphite,
    _ width: Double = 0.003, filled: Bool = false
  ) -> InkStroke {
    InkStroke(
      points: coordinates.map { InkPoint(x: $0.0, y: $0.1) }, color: color, width: width,
      filled: filled)
  }

  static func ellipse(
    x: Double, y: Double, rx: Double, ry: Double, color: InkColor = .graphite,
    filled: Bool = false
  ) -> InkStroke {
    line(
      (0...80).map {
        let angle = Double($0) / 80 * 2 * Double.pi
        return (x + cos(angle) * rx, y + sin(angle) * ry)
      }, color, filled: filled)
  }

  static func sea(_ horizon: Double = 0.56) -> [InkStroke] {
    var result = [
      line([(0, horizon), (1, horizon), (1, 1), (0, 1)], .mist, filled: true),
      line([(0, horizon), (1, horizon)], .graphite, 0.0015),
    ]
    for i in 0..<22 {
      let x = Double((i * 37) % 95) / 100
      let y = horizon + 0.035 + Double(i % 7) * 0.055
      result.append(line([(x, y), (min(x + 0.035 + Double(i % 3) * 0.02, 1), y)], .shadow, 0.001))
    }
    return result
  }

  static func landscape() -> [InkStroke] {
    var s = sea()
    s += [
      ellipse(x: 0.23, y: 0.28, rx: 0.062, ry: 0.145, color: .yellow, filled: true),
      line([(0.64, 0.27), (0.15, 0.47), (0.64, 0.34)], .ivory, filled: true),
      line(
        [
          (0.31, 1), (0.43, 0.77), (0.53, 0.72), (0.57, 0.6), (0.71, 0.58),
          (0.82, 0.72), (1, 0.81), (1, 1),
        ], .shadow, filled: true),
      line([(0.59, 0.61), (0.615, 0.26), (0.678, 0.26), (0.71, 0.61)], .ivory, filled: true),
      line([(0.59, 0.61), (0.615, 0.26), (0.678, 0.26), (0.71, 0.61)], .graphite),
      line([(0.609, 0.26), (0.609, 0.18), (0.684, 0.18), (0.684, 0.26)], .graphite, 0.005),
      line([(0.601, 0.18), (0.646, 0.11), (0.693, 0.18)], .graphite, filled: true),
      line([(0.614, 0.22), (0.68, 0.22)], .yellow, 0.012),
      line([(0.644, 0.51), (0.644, 0.59)], .graphite, 0.014),
      line([(0.628, 0.34), (0.664, 0.34)], .graphite),
      line([(0.625, 0.42), (0.67, 0.42)], .graphite),
      line([(0.5, 0.83), (0.59, 0.75), (0.66, 0.74), (0.7, 0.68)], .mist, 0.006),
      line([(0.11, 0.2), (0.13, 0.18), (0.15, 0.2), (0.17, 0.18), (0.19, 0.2)], .graphite, 0.002),
    ]
    for i in 0..<9 {
      let x = 0.48 + Double(i) * 0.045
      s.append(line([(x, 0.86), (min(x + 0.05, 1), 0.78)], .mist, 0.001))
    }
    return s
  }

  static func keeper() -> [InkStroke] {
    sea(0.48) + [
      line([(0, 1), (0.62, 0.58), (0.69, 0.58), (1, 1)], .shadow, filled: true),
      line([(0.25, 1), (0.65, 0.59)], .ivory, 0.004),
      ellipse(x: 0.56, y: 0.31, rx: 0.031, ry: 0.07, filled: true),
      line([(0.526, 0.38), (0.49, 0.71), (0.605, 0.71), (0.589, 0.38)], .graphite, filled: true),
      line([(0.524, 0.7), (0.52, 0.9), (0.54, 0.9), (0.554, 0.72)], .graphite, filled: true),
      line([(0.57, 0.7), (0.59, 0.88)], .graphite, 0.02),
      line([(0.516, 0.45), (0.484, 0.65)], .graphite, 0.016),
      line([(0.585, 0.42), (0.617, 0.6)], .graphite, 0.016),
      line([(0.6, 0.61), (0.631, 0.61), (0.631, 0.72), (0.6, 0.72)], .yellow, filled: true),
      line([(0.8, 0.33), (0.813, 0.2), (0.832, 0.33)], .shadow, filled: true),
    ]
  }

  static func stairs() -> [InkStroke] {
    var s = [
      ellipse(x: 0.5, y: 0.5, rx: 0.34, ry: 0.46, color: .mist, filled: true),
      ellipse(x: 0.5, y: 0.5, rx: 0.33, ry: 0.45),
      ellipse(x: 0.5, y: 0.5, rx: 0.13, ry: 0.18, filled: true),
    ]
    for i in 0..<20 {
      let angle = Double(i) * Double.pi / 10
      s.append(
        line(
          [
            (0.5 + cos(angle) * 0.13, 0.5 + sin(angle) * 0.18),
            (0.5 + cos(angle + 0.2) * 0.33, 0.5 + sin(angle + 0.2) * 0.45),
          ],
          i > 14 ? .yellow : .graphite, i > 14 ? 0.008 : 0.002))
    }
    s.append(ellipse(x: 0.71, y: 0.37, rx: 0.027, ry: 0.059, filled: true))
    return s
  }

  static func switchDetail() -> [InkStroke] {
    [
      line([(0.23, 0.18), (0.66, 0.18), (0.66, 0.84), (0.23, 0.84)], .mist, filled: true),
      line([(0.23, 0.18), (0.66, 0.18), (0.66, 0.84), (0.23, 0.84), (0.23, 0.18)]),
      ellipse(x: 0.43, y: 0.48, rx: 0.115, ry: 0.24),
      ellipse(x: 0.43, y: 0.48, rx: 0.085, ry: 0.18, color: .yellow, filled: true),
      line([(0.42, 0.48), (0.51, 0.33)], .graphite, 0.026),
      line(
        [
          (0.98, 0.85), (0.67, 0.66), (0.5, 0.53), (0.48, 0.42), (0.52, 0.32),
          (0.57, 0.34), (0.55, 0.45), (0.7, 0.51), (0.8, 0.58), (0.99, 0.66),
        ],
        .ivory, filled: true),
      line([
        (0.98, 0.85), (0.67, 0.66), (0.5, 0.53), (0.48, 0.42), (0.52, 0.32),
        (0.57, 0.34), (0.55, 0.45), (0.7, 0.51), (0.8, 0.58), (0.99, 0.66),
      ]),
      ellipse(x: 0.27, y: 0.25, rx: 0.009, ry: 0.02),
      ellipse(x: 0.62, y: 0.77, rx: 0.009, ry: 0.02),
    ]
  }

  static func lantern() -> [InkStroke] {
    var s = [
      line([(0.3, 0.12), (0.7, 0.12), (0.7, 0.89), (0.3, 0.89)], .mist, filled: true),
      ellipse(x: 0.5, y: 0.48, rx: 0.14, ry: 0.32, color: .yellow, filled: true),
    ]
    for i in 0..<6 {
      s.append(
        ellipse(
          x: 0.5, y: 0.48, rx: 0.03 + Double(i) * 0.022,
          ry: 0.065 + Double(i) * 0.05, color: .shadow))
    }
    s += [
      line([(0.31, 0.06), (0.31, 0.94)], .graphite, 0.015),
      line([(0.69, 0.06), (0.69, 0.94)], .graphite, 0.015),
      line([(0.28, 0.12), (0.72, 0.12)], .graphite, 0.014),
      line([(0.28, 0.89), (0.72, 0.89)], .graphite, 0.014),
      line([(0.69, 0.2), (0.97, 0.05)], .yellow, 0.003),
      line([(0.69, 0.4), (0.99, 0.35)], .yellow, 0.003),
      line([(0.69, 0.7), (0.98, 0.88)], .yellow, 0.003),
    ]
    return s
  }

  static func boat() -> [InkStroke] {
    sea(0.52) + [
      ellipse(x: 0.73, y: 0.29, rx: 0.07, ry: 0.16, color: .yellow, filled: true),
      line([(0.26, 0.68), (0.47, 0.68), (0.43, 0.77), (0.31, 0.77)], .graphite, filled: true),
      line([(0.35, 0.68), (0.35, 0.2)], .graphite, 0.004),
      line([(0.357, 0.24), (0.357, 0.64), (0.47, 0.64)], .ivory, filled: true),
      line([(0.357, 0.24), (0.357, 0.64), (0.47, 0.64), (0.357, 0.24)]),
      line([(0.339, 0.35), (0.27, 0.64), (0.339, 0.64)], .mist, filled: true),
      line([(0.2, 0.82), (0.42, 0.82)], .ivory, 0.007),
      line([(0.17, 0.87), (0.34, 0.87)], .ivory, 0.004),
      line([(0.71, 0.62), (0.76, 0.62)], .yellow, 0.008),
      line([(0.7, 0.69), (0.77, 0.69)], .yellow, 0.006),
    ]
  }
}
