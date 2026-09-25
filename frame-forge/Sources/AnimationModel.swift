import Foundation

struct InkPoint: Codable, Equatable {
  var x: Double
  var y: Double
}

struct InkStroke: Codable, Equatable, Identifiable {
  var id = UUID()
  var points: [InkPoint]
  var color: String
  var width: Double
  var filled = false
  var eraser = false
}

struct AnimationFrame: Codable, Equatable, Identifiable {
  var id = UUID()
  var strokes: [InkStroke] = []
}

struct AnimationProject: Codable, Equatable, Identifiable {
  var id = UUID()
  var name: String
  var frames: [AnimationFrame]
  var fps: Int = 8
  var updatedAt = Date()

  static let maximumFrames = 120

  func validated() throws -> AnimationProject {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      (1...24).contains(fps), (1...Self.maximumFrames).contains(frames.count),
      Set(frames.map(\.id)).count == frames.count,
      frames.allSatisfy({ frame in
        frame.strokes.count <= 10_000
          && frame.strokes.allSatisfy { stroke in
            stroke.width.isFinite && (0.5...80).contains(stroke.width)
              && stroke.color.count == 6
              && UInt32(stroke.color, radix: 16) != nil
              && stroke.points.count <= 100_000
              && stroke.points.allSatisfy {
                $0.x.isFinite && $0.y.isFinite
                  && (0...800).contains($0.x) && (0...520).contains($0.y)
              }
          }
      })
    else { throw ProjectError.invalid }
    return self
  }

  static func blank() -> AnimationProject {
    AnimationProject(name: "Untitled loop", frames: [AnimationFrame()])
  }
}

enum ProjectError: LocalizedError {
  case invalid
  var errorDescription: String? { "This project contains invalid animation data." }
}

struct AnimationHistory {
  private(set) var past: [AnimationProject] = []
  private(set) var future: [AnimationProject] = []

  mutating func record(_ project: AnimationProject) {
    past.append(project)
    if past.count > 60 { past.removeFirst() }
    future.removeAll()
  }

  mutating func undo(_ project: AnimationProject) -> AnimationProject? {
    guard let restored = past.popLast() else { return nil }
    future.append(project)
    return restored
  }

  mutating func redo(_ project: AnimationProject) -> AnimationProject? {
    guard let restored = future.popLast() else { return nil }
    past.append(project)
    return restored
  }
}

enum FrameEditing {
  static func duplicate(in project: inout AnimationProject, at index: Int) -> Int {
    guard project.frames.indices.contains(index),
      project.frames.count < AnimationProject.maximumFrames
    else { return index }
    var frame = project.frames[index]
    frame.id = UUID()
    frame.strokes = frame.strokes.map {
      var stroke = $0
      stroke.id = UUID()
      return stroke
    }
    project.frames.insert(frame, at: index + 1)
    return index + 1
  }

  static func delete(in project: inout AnimationProject, at index: Int) -> Int {
    guard project.frames.indices.contains(index), project.frames.count > 1 else {
      return index
    }
    project.frames.remove(at: index)
    return min(index, project.frames.count - 1)
  }

  static func move(in project: inout AnimationProject, at index: Int, by offset: Int) -> Int {
    let destination = index + offset
    guard project.frames.indices.contains(index),
      project.frames.indices.contains(destination)
    else { return index }
    project.frames.swapAt(index, destination)
    return destination
  }
}

enum SampleAnimation {
  static func make() -> AnimationProject {
    let frames = (0..<8).map { frame -> AnimationFrame in
      let phase = Double(frame) / 8 * .pi * 2
      let lift = (1 - cos(phase)) * 45
      let centerX = 405 + sin(phase) * 24
      let centerY = 322 - lift
      let squash = 1 - cos(phase) * 0.06
      var ink: [InkStroke] = []
      func line(_ points: [(Double, Double)], _ color: String, _ width: Double = 5) {
        ink.append(
          InkStroke(
            points: points.map { InkPoint(x: $0.0, y: $0.1) },
            color: color, width: width))
      }
      func polygon(_ points: [(Double, Double)], _ color: String) {
        ink.append(
          InkStroke(
            points: points.map { InkPoint(x: $0.0, y: $0.1) },
            color: color, width: 1, filled: true))
      }
      func oval(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ color: String) {
        polygon(
          (0..<64).map {
            let a = Double($0) / 64 * .pi * 2
            return (x + cos(a) * rx, y + sin(a) * ry)
          }, color)
      }
      func star(_ x: Double, _ y: Double, _ radius: Double, _ color: String) {
        polygon(
          (0..<8).map {
            let a = Double($0) / 8 * .pi * 2
            let r = $0.isMultiple(of: 2) ? radius : radius * 0.25
            return (x + cos(a) * r, y + sin(a) * r)
          }, color)
      }
      oval(401, 410, 145 - lift * 0.45, 12 - lift * 0.04, "E5DCCD")
      line([(190, 410), (610, 410)], "C9BCAB", 2)
      oval(183, 183, 29, 29, "B8B9EC")
      line(
        (0...35).map {
          let a = Double($0) / 35 * .pi * 2
          return (183 + cos(a) * 44, 183 + sin(a) * 11)
        }, "7F81B4", 3)
      star(595, 170 + sin(phase) * 5, 20, "E5AD53")
      star(250, 294, 10, "E5AD53")
      star(571, 327, 12, "8EADB0")
      oval(613, 246, 4, 4, "D4B9A8")
      oval(288, 151, 4, 4, "D4B9A8")
      line(
        [
          (centerX - 60, centerY + 28), (centerX - 100, centerY + 14),
          (centerX - 108, centerY - 8),
        ], "B94D4A", 9)
      line(
        [
          (centerX + 57, centerY + 27), (centerX + 94, centerY + 5),
          (centerX + 105, centerY - 14),
        ], "B94D4A", 9)
      line(
        [
          (centerX - 35, centerY + 59 * squash),
          (centerX - 46 - sin(phase) * 15, centerY + 81),
          (centerX - 64 - sin(phase) * 15, centerY + 81),
        ], "493446", 9)
      line(
        [
          (centerX + 30, centerY + 59 * squash),
          (centerX + 47 + sin(phase) * 15, centerY + 81),
          (centerX + 63 + sin(phase) * 15, centerY + 81),
        ], "493446", 9)
      polygon(
        (0..<80).map {
          let a = Double($0) / 80 * .pi * 2
          let r = 1 + 0.035 * sin(a * 3 + phase)
          return (centerX + cos(a) * 75 * r, centerY + sin(a) * 71 * squash * r)
        }, "ED7969")
      oval(centerX - 20, centerY - 31, 24, 12, "F69982")
      oval(centerX - 25, centerY - 5, 6, 10, "493446")
      oval(centerX + 24, centerY - 5, 6, 10, "493446")
      oval(centerX - 42, centerY + 15, 11, 6, "D75C5D")
      oval(centerX + 41, centerY + 15, 11, 6, "D75C5D")
      line(
        (0...16).map {
          let a = Double($0) / 16 * .pi
          return (centerX + cos(a) * 13, centerY + 12 + sin(a) * 10)
        }, "493446", 4)
      star(centerX + 16, centerY - 107, 13, "ED7969")
      return AnimationFrame(strokes: ink)
    }
    return AnimationProject(name: "A little lift", frames: frames)
  }
}
