import Foundation

public struct Body {
  public var x = 0.0, y = 40.0, z = 0.0
  public var vx = 0.0, vy = 0.0, vz = 0.0
  public var onGround = false, inWater = false, flying = false
  public init() {}
}

public struct RayHit: Equatable {
  public let x: Int, y: Int, z: Int
  public let nx: Int, ny: Int, nz: Int
  public let distance: Double
  public let id: Int
}

public enum Physics {
  public static func collides(_ world: World, _ x: Double, _ y: Double, _ z: Double) -> Bool {
    for bx in Int(floor(x - 0.3))...Int(floor(x + 0.3 - 1e-6)) {
      for by in Int(floor(y))...Int(floor(y + 1.8 - 1e-6)) {
        for bz in Int(floor(z - 0.3))...Int(floor(z + 0.3 - 1e-6)) {
          if Registry.shared.block(world.peek(bx, by, bz)).solid { return true }
        }
      }
    }
    return false
  }
  public static func inWater(_ world: World, _ body: Body) -> Bool {
    for bx in Int(floor(body.x - 0.3))...Int(floor(body.x + 0.3 - 1e-6)) {
      for by in Int(floor(body.y))...Int(floor(body.y + 1.8 * 0.6)) {
        for bz in Int(floor(body.z - 0.3))...Int(floor(body.z + 0.3 - 1e-6)) {
          if world.peek(bx, by, bz) == 5 { return true }
        }
      }
    }
    return false
  }
  public static func step(
    _ b: inout Body, world: World, dt: Double,
    wishX: Double, wishZ: Double, jump: Bool, wishY: Double = 0
  ) {
    b.inWater = inWater(world, b)
    if b.flying {
      b.vx = wishX
      b.vz = wishZ
      b.vy = wishY
    } else if b.inWater {
      b.vx = b.vx * 0.8 + wishX * 0.2
      b.vz = b.vz * 0.8 + wishZ * 0.2
      b.vy -= 6 * dt
      if jump { b.vy = max(b.vy, 3.2) }
      b.vy = max(-3, min(4, b.vy))
    } else {
      let accel = b.onGround ? 0.35 : 0.12
      b.vx += (wishX - b.vx) * accel
      b.vz += (wishZ - b.vz) * accel
      if jump && b.onGround {
        b.vy = 8.4
        b.onGround = false
      }
      b.vy = max(-60, b.vy - 28 * dt)
    }
    func move(_ dx: Double, _ dy: Double, _ dz: Double) -> Bool {
      for _ in 0..<4 {
        let nx = b.x + dx / 4
        let ny = b.y + dy / 4
        let nz = b.z + dz / 4
        if collides(world, nx, ny, nz) {
          if dx != 0 { b.vx = 0 }
          if dz != 0 { b.vz = 0 }
          return false
        }
        b.x = nx
        b.y = ny
        b.z = nz
      }
      return true
    }
    _ = move(b.vx * dt, 0, 0)
    _ = move(0, 0, b.vz * dt)
    let falling = b.vy < 0
    if !move(0, b.vy * dt, 0) {
      if falling { b.onGround = true }
      b.vy = 0
    } else {
      b.onGround = false
    }
    if !b.onGround && b.vy <= 0 && collides(world, b.x, b.y - 0.02, b.z) { b.onGround = true }
  }
  public static func raycast(
    _ world: World, origin: SIMD3<Double>, direction: SIMD3<Double>,
    distance: Double = 5.5
  ) -> RayHit? {
    var cell = SIMD3<Int>(Int(floor(origin.x)), Int(floor(origin.y)), Int(floor(origin.z)))
    var step = SIMD3<Int>()
    var delta = SIMD3<Double>()
    var maxT = SIMD3<Double>()
    for axis in 0..<3 {
      step[axis] = direction[axis] > 0 ? 1 : -1
      delta[axis] = direction[axis] == 0 ? 1e30 : abs(1 / direction[axis])
      maxT[axis] =
        direction[axis] == 0
        ? 1e30
        : (direction[axis] > 0
          ? Double(cell[axis] + 1) - origin[axis] : origin[axis] - Double(cell[axis])) * delta[axis]
    }
    var normal = SIMD3<Int>()
    var t = 0.0
    for _ in 0..<400 {
      let id = world.peek(cell.x, cell.y, cell.z)
      let def = Registry.shared.block(id)
      if id != 0 && (def.solid || def.decoration) {
        return RayHit(
          x: cell.x, y: cell.y, z: cell.z, nx: normal.x, ny: normal.y, nz: normal.z, distance: t,
          id: id)
      }
      let axis = maxT.x < maxT.y && maxT.x < maxT.z ? 0 : maxT.y < maxT.z ? 1 : 2
      cell[axis] += step[axis]
      t = maxT[axis]
      maxT[axis] += delta[axis]
      normal = .zero
      normal[axis] = -step[axis]
      if t > distance || cell.y < 0 || cell.y >= 64 { return nil }
    }
    return nil
  }
  public static func wish(strafe: Double, forward: Double, yaw: Double) -> SIMD2<Double> {
    let length = max(1, hypot(strafe, forward))
    let sx = strafe / length
    let fz = forward / length
    return SIMD2(cos(yaw) * sx + sin(yaw) * fz, -sin(yaw) * sx + cos(yaw) * fz)
  }
}
