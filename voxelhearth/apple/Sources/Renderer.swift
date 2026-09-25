import Foundation
import HearthCore
import MetalKit
import SwiftUI
import simd

struct Uniforms {
  var res = SIMD4<Float>(), cam = SIMD4<Float>(), forward = SIMD4<Float>()
  var right = SIMD4<Float>(), up = SIMD4<Float>(), fov = SIMD4<Float>()
  var origin = SIMD4<Float>(), time = SIMD4<Float>(), target = SIMD4<Float>()
}

@MainActor final class VoxelRenderer: NSObject, MTKViewDelegate {
  let game: Game
  let device: MTLDevice
  let queue: MTLCommandQueue
  let pipeline: MTLRenderPipelineState
  var textures: [MTLTexture] = []
  var originX = 0, originZ = 0
  var lastRevision = -1
  var lastWorld: World?
  var lastTime = CACurrentMediaTime()
  var rebuildTime = 0.0
  private var adaptiveScale: CGFloat = 0.65
  private var frameTime = 0.0
  private var frameCount = 0

  init(game: Game, device: MTLDevice) throws {
    self.game = game
    self.device = device
    guard let queue = device.makeCommandQueue(), let library = device.makeDefaultLibrary() else {
      throw RenderError.resource("The Metal shader library is missing.")
    }
    self.queue = queue
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "hearthVertex")
    descriptor.fragmentFunction = library.makeFunction(name: "hearthFragment")
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    super.init()
    for _ in 0..<4 { textures.append(try texture(width: 512, height: 512)) }
    textures.append(try resource("tiles", width: 256, height: 2))
    textures.append(try resource("atlas", width: 256, height: 80))
    textures.append(try texture(width: 128, height: 1))
  }
  enum RenderError: Error { case resource(String) }
  private func texture(width: Int, height: Int) throws -> MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
    descriptor.storageMode = .shared
    descriptor.usage = .shaderRead
    guard let texture = device.makeTexture(descriptor: descriptor) else {
      throw RenderError.resource("Metal texture allocation failed.")
    }
    return texture
  }
  private func resource(_ name: String, width: Int, height: Int) throws -> MTLTexture {
    guard let url = Bundle.main.url(forResource: name, withExtension: "rgba") else {
      throw RenderError.resource("Missing \(name) texture.")
    }
    let data = try Data(contentsOf: url)
    let texture = try texture(width: width, height: height)
    guard data.count == width * height * 4 else {
      throw RenderError.resource("Invalid \(name) texture.")
    }
    data.withUnsafeBytes { bytes in
      if let base = bytes.baseAddress {
        texture.replace(
          region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: base,
          bytesPerRow: width * 4)
      }
    }
    return texture
  }
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
  func draw(in view: MTKView) {
    let now = CACurrentMediaTime()
    let dt = now - lastTime
    lastTime = now
    game.update(dt)
    frameTime += min(0.1, dt)
    frameCount += 1
    if frameTime >= 1 {
      let fps = Double(frameCount) / frameTime
      if fps < 48 { adaptiveScale = max(0.3, adaptiveScale - 0.05) }
      if fps > 58 { adaptiveScale = min(1, adaptiveScale + 0.025) }
      frameTime = 0
      frameCount = 0
    }
    guard let world = game.session.world else { return }
    let x = Int(floor(game.body.x))
    let z = Int(floor(game.body.z))
    let moved = x < originX + 32 || x >= originX + 96 || z < originZ + 32 || z >= originZ + 96
    if (lastWorld !== world || moved || lastRevision != world.revision) && now - rebuildTime > 0.2 {
      if lastWorld !== world || moved {
        originX = World.coordinate(x - 64) * 16
        originZ = World.coordinate(z - 64) * 16
      }
      rebuild(world)
      lastRevision = world.revision
      lastWorld = world
      rebuildTime = now
    }
    let quality = game.session.preferences.quality
    let scale: CGFloat = quality == 0 ? 0.4 : quality == 1 ? adaptiveScale : 1
    let wanted = CGSize(
      width: max(1, view.bounds.width * scale), height: max(1, view.bounds.height * scale))
    if view.drawableSize != wanted { view.drawableSize = wanted }
    guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
      let command = queue.makeCommandBuffer(),
      let encoder = command.makeRenderCommandEncoder(descriptor: pass)
    else { return }
    var uniforms = Uniforms()
    let camera = game.camera
    let f = game.forward
    let r = SIMD3<Double>(cos(game.yaw), 0, -sin(game.yaw))
    let u = simd_cross(f, r)
    let tanFOV = tan(game.session.preferences.fov * .pi / 360)
    uniforms.res = SIMD4(
      Float(wanted.width), Float(wanted.height), Float(packEntities()), game.damage)
    uniforms.cam = SIMD4(Float(camera.x), Float(camera.y), Float(camera.z), 0)
    uniforms.forward = SIMD4(Float(f.x), Float(f.y), Float(f.z), 0)
    uniforms.right = SIMD4(Float(r.x), Float(r.y), Float(r.z), 0)
    uniforms.up = SIMD4(Float(u.x), Float(u.y), Float(u.z), 0)
    uniforms.fov = SIMD4(Float(tanFOV * wanted.width / wanted.height), Float(tanFOV), 0, 0)
    uniforms.origin = SIMD4(Float(originX), 0, Float(originZ), 0)
    let underwater =
      world.peek(Int(floor(camera.x)), Int(floor(camera.y)), Int(floor(camera.z))) == 5
    uniforms.time = SIMD4(
      Float(game.session.time) / 24000, Float(game.animation), quality == 0 ? 56 : 96,
      underwater ? 1 : 0)
    if let target = game.target {
      uniforms.target = SIMD4(
        Float(target.x - originX), Float(target.y), Float(target.z - originZ), Float(game.progress))
    } else {
      uniforms.target = SIMD4(-1000, -1000, -1000, 0)
    }
    encoder.setRenderPipelineState(pipeline)
    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
    for index in textures.indices { encoder.setFragmentTexture(textures[index], index: index) }
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()
    command.present(drawable)
    command.commit()
  }
  private func rebuild(_ world: World) {
    let width = 128
    let layer = width * width
    let volume = layer * 64
    var ids = [UInt8](repeating: 0, count: volume)
    var sky = [UInt8](repeating: 0, count: volume)
    var block = sky
    for cz in 0..<8 {
      for cx in 0..<8 {
        let key = ChunkKey(World.coordinate(originX) + cx, World.coordinate(originZ) + cz)
        guard let chunk = world.chunks[key] else { continue }
        for y in 0..<64 {
          for z in 0..<16 {
            let base = y * layer + (cz * 16 + z) * width + cx * 16
            let source = (y * 16 + z) * 16
            ids.replaceSubrange(base..<(base + 16), with: chunk.blocks[source..<(source + 16)])
          }
        }
      }
    }
    let opacity = (0..<256).map { id -> UInt8 in
      if [0, 15, 23, 24, 27, 20, 19].contains(id) { return 0 }
      if [7, 32, 5].contains(id) { return 1 }
      return 15
    }
    let emission = (0..<256).map { id -> UInt8 in
      if id == 15 { return 14 }
      if id == 27 { return 15 }
      if id == 13 { return 7 }
      if id == 17 { return 6 }
      return 0
    }
    for z in 0..<width {
      for x in 0..<width {
        var light = 15
        for y in stride(from: 63, through: 0, by: -1) {
          let i = y * layer + z * width + x
          let op = Int(opacity[Int(ids[i])])
          if op >= 15 { light = 0 } else if op > 0 { light = max(0, light - op - 1) }
          sky[i] = UInt8(light)
          block[i] = emission[Int(ids[i])]
        }
      }
    }
    func spread(_ lights: inout [UInt8]) {
      var queue: [Int] = []
      queue.reserveCapacity(volume)
      for i in 0..<volume where lights[i] > 1 { queue.append(i) }
      var head = 0
      while head < queue.count {
        let i = queue[head]
        head += 1
        let x = i % width
        let z = (i / width) % width
        let y = i / layer
        let light = Int(lights[i])
        func neighbor(_ j: Int) {
          let level = light - 1 - Int(opacity[Int(ids[j])])
          if level > Int(lights[j]) {
            lights[j] = UInt8(level)
            queue.append(j)
          }
        }
        if x > 0 { neighbor(i - 1) }
        if x < 127 { neighbor(i + 1) }
        if z > 0 { neighbor(i - width) }
        if z < 127 { neighbor(i + width) }
        if y > 0 { neighbor(i - layer) }
        if y < 63 { neighbor(i + layer) }
      }
    }
    spread(&sky)
    spread(&block)
    var quads = Array(repeating: [UInt8](repeating: 255, count: 512 * 512 * 4), count: 4)
    for y in 0..<64 {
      for z in 0..<128 {
        for x in 0..<128 {
          let i = y * layer + z * 128 + x
          let q = (x >= 64 ? 2 : 0) + (z >= 64 ? 1 : 0)
          let o = (((y >> 3) * 64 + (z & 63)) * 512 + (y & 7) * 64 + (x & 63)) * 4
          quads[q][o] = ids[i]
          quads[q][o + 1] = opacity[Int(ids[i])] < 15 ? sky[i] * 17 : 0
          quads[q][o + 2] = opacity[Int(ids[i])] < 15 ? block[i] * 17 : 0
        }
      }
    }
    for q in 0..<4 {
      quads[q].withUnsafeBytes {
        if let base = $0.baseAddress {
          textures[q].replace(
            region: MTLRegionMake2D(0, 0, 512, 512), mipmapLevel: 0, withBytes: base,
            bytesPerRow: 2048)
        }
      }
    }
  }
  private func packEntities() -> Int {
    var entities: [(Double, Double, Double, Double, Int, Int, Bool)] = []
    for p in game.renderPlayers where p.id != game.session.playerID && (p.hp ?? 0) > 0 {
      let seed = p.id.utf8.reduce(UInt32(2_166_136_261)) { ($0 ^ UInt32($1)) &* 16_777_619 }
      entities.append((p.x ?? 0, p.y ?? 0, p.z ?? 0, p.yaw ?? 0, 0, Int(seed % 10), false))
    }
    for m in game.renderMobs {
      entities.append(
        (
          m.x, m.y, m.z, m.yaw, m.kind == "mossback" ? 1 : m.kind == "hollow" ? 2 : 3, m.id % 10,
          m.hurt
        ))
    }
    entities.sort {
      hypot($0.0 - game.body.x, $0.2 - game.body.z) < hypot($1.0 - game.body.x, $1.2 - game.body.z)
    }
    var bytes = [UInt8](repeating: 255, count: 512)
    for (i, e) in entities.prefix(24).enumerated() {
      let x = max(0, min(65535, Int(((e.0 - Double(originX) + 16) * 256).rounded())))
      let z = max(0, min(65535, Int(((e.2 - Double(originZ) + 16) * 256).rounded())))
      let y = max(0, min(65535, Int(((e.1 + 16) * 256).rounded())))
      let o = i * 12
      bytes[o] = UInt8(x >> 8)
      bytes[o + 1] = UInt8(x & 255)
      bytes[o + 2] = UInt8(z >> 8)
      bytes[o + 4] = UInt8(z & 255)
      bytes[o + 5] = UInt8(y >> 8)
      bytes[o + 6] = UInt8(y & 255)
      bytes[o + 8] = UInt8(e.5 * 10 + e.4)
      let angle = (e.3 + .pi).truncatingRemainder(dividingBy: 2 * .pi)
      bytes[o + 9] = UInt8(
        max(0, min(255, Int(((angle < 0 ? angle + 2 * .pi : angle) / (2 * .pi) * 255).rounded()))))
      bytes[o + 10] = e.6 ? 255 : 0
    }
    bytes.withUnsafeBytes {
      if let base = $0.baseAddress {
        textures[6].replace(
          region: MTLRegionMake2D(0, 0, 128, 1), mipmapLevel: 0, withBytes: base, bytesPerRow: 512)
      }
    }
    return min(24, entities.count)
  }
}
