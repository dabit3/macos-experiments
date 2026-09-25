import Foundation

public struct ArenaViewport {
  public let scale, originX, originY: Double
  public init(width: Double, height: Double, playerX: Double, playerY: Double, arena: Arena) {
    let scale = max(26, min((width - 128) / arena.width, (height - 124) / arena.height))
    self.scale = scale
    func origin(extent: Double, world: Double, focus: Double, leading: Double, trailing: Double)
      -> Double
    {
      let minimum = extent - trailing - world * scale
      let maximum = leading
      if minimum >= maximum { return (extent + leading - trailing - world * scale) / 2 }
      return min(maximum, max(minimum, (extent + leading - trailing) / 2 - focus * scale))
    }
    originX = origin(extent: width, world: arena.width, focus: playerX, leading: 64, trailing: 64)
    originY = origin(extent: height, world: arena.height, focus: playerY, leading: 80, trailing: 44)
  }
}
