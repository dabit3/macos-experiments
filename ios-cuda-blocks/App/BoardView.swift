import CudaBlocksCore
import SwiftUI

/// Canvas renderer for the die: grid, locked kernels, ghost, active piece, and VFX.
struct BoardView: View {
  @ObservedObject var store: GameStore

  var body: some View {
    Canvas(rendersAsynchronously: false) { ctx, size in
      draw(&ctx, size: size)
    }
    .aspectRatio(CGFloat(Board.width) / CGFloat(Board.height), contentMode: .fit)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Theme.black)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(Theme.green.opacity(0.55 + store.flash * 0.45), lineWidth: 1.5)
    )
    .shadow(color: Theme.green.opacity(0.25 + store.flash * 0.6), radius: 14 + store.flash * 24)
    .offset(x: shakeOffset.x, y: shakeOffset.y)
  }

  private var shakeOffset: CGPoint {
    guard store.shake > 0 else { return .zero }
    let t = store.now * 60
    let a = store.shake * store.shake * 7
    return CGPoint(x: sin(t * 1.3) * a, y: cos(t * 1.7) * a)
  }

  private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
    let cell = size.width / CGFloat(Board.width)
    let engine = store.engine
    let board = engine.board
    let buffer = Board.buffer
    let now = store.now

    func rect(_ c: Cell, inset: CGFloat = 1.5) -> CGRect {
      CGRect(
        x: CGFloat(c.col) * cell + inset, y: CGFloat(c.row - buffer) * cell + inset,
        width: cell - inset * 2, height: cell - inset * 2)
    }

    // Grid: faint wafer lines with slightly brighter every-5 lines.
    var grid = Path()
    for x in 0...Board.width {
      grid.move(to: CGPoint(x: CGFloat(x) * cell, y: 0))
      grid.addLine(to: CGPoint(x: CGFloat(x) * cell, y: size.height))
    }
    for y in 0...Board.height {
      grid.move(to: CGPoint(x: 0, y: CGFloat(y) * cell))
      grid.addLine(to: CGPoint(x: size.width, y: CGFloat(y) * cell))
    }
    ctx.stroke(grid, with: .color(Theme.green.opacity(0.09)), lineWidth: 0.6)
    var dots = Path()
    for x in 0...Board.width where x % 5 == 0 {
      for y in 0...Board.height where y % 5 == 0 {
        dots.addEllipse(
          in: CGRect(x: CGFloat(x) * cell - 1.5, y: CGFloat(y) * cell - 1.5, width: 3, height: 3))
      }
    }
    ctx.fill(dots, with: .color(Theme.green.opacity(0.35)))

    // Danger glow when the stack is tall.
    let height = board.stackHeight - buffer
    if height >= 14 {
      let t = Double(height - 13) / 7.0
      let pulse = 0.5 + 0.5 * sin(now * 5)
      var top = Path()
      top.addRect(CGRect(x: 0, y: 0, width: size.width, height: cell * 3))
      ctx.fill(
        top,
        with: .linearGradient(
          Gradient(colors: [Theme.amber.opacity(0.25 * t * pulse), .clear]),
          startPoint: .zero, endPoint: CGPoint(x: 0, y: cell * 3)))
    }

    // Locked kernels.
    for row in buffer..<board.totalRows {
      for col in 0..<Board.width {
        let c = Cell(row, col)
        guard let k = board[c] else { continue }
        drawBlock(&ctx, rect: rect(c), color: Theme.color(for: k), alpha: 1, cell: cell)
      }
    }

    // Row flashes.
    for f in store.rowFlashes {
      let t = (now - f.born) / 0.45
      let alpha = max(0, 1 - t)
      var p = Path()
      p.addRect(CGRect(x: 0, y: CGFloat(f.row - buffer) * cell, width: size.width, height: cell))
      ctx.fill(p, with: .color(Color.white.opacity(alpha * 0.85)))
      ctx.fill(p, with: .color(Theme.greenBright.opacity(alpha * 0.6)))
    }

    // Ghost.
    if let ghost = engine.ghost, let current = engine.current, ghost != current {
      let color = Theme.color(for: ghost.kernel)
      for c in ghost.cells where c.row >= buffer {
        let r = rect(c, inset: 2.5)
        ctx.stroke(
          Path(roundedRect: r, cornerRadius: 2), with: .color(color.opacity(0.55)),
          style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
        ctx.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(color.opacity(0.08)))
      }
    }

    // Active piece with lock pulse.
    if let p = engine.current {
      let lockT = engine.lockProgress
      let pulse = lockT > 0 ? 0.75 + 0.25 * sin(now * 18) : 1.0
      let color = Theme.color(for: p.kernel)
      for c in p.cells where c.row >= buffer {
        var r = rect(c)
        if lockT > 0 { r = r.insetBy(dx: -lockT * 1.5, dy: -lockT * 1.5) }
        drawBlock(&ctx, rect: r, color: color, alpha: pulse, cell: cell, glow: true)
      }
    }

    // Sparks.
    for s in store.sparks {
      let age = now - s.born
      let t = age / s.life
      guard t < 1 else { continue }
      let x = (s.x + s.vx * age) * cell
      let y = (s.y - Double(buffer) + s.vy * age + 6 * age * age) * cell
      let sz = cell * 0.16 * (1 - t) + 1
      let color = s.hue < 0.5 ? Theme.greenBright : Color.white
      ctx.fill(
        Path(ellipseIn: CGRect(x: x - sz / 2, y: y - sz / 2, width: sz, height: sz)),
        with: .color(color.opacity(1 - t)))
    }

    // Shockwaves: expanding rings from the cleared rows.
    for w in store.shockwaves {
      let t = (now - w.born) / (w.tensor ? 1.1 : 0.6)
      guard t < 1 else { continue }
      let cy = (w.centerRow - Double(buffer) + 0.5) * cell
      let center = CGPoint(x: size.width / 2, y: cy)
      let maxR = w.tensor ? size.height * 1.1 : size.width * 0.8
      let ease = 1 - pow(1 - t, 3)
      let radius = maxR * ease
      let alpha = (1 - t) * (w.tensor ? 0.95 : 0.6)
      let ring = Path(
        ellipseIn: CGRect(
          x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
      ctx.stroke(
        ring, with: .color(Theme.greenBright.opacity(alpha)),
        lineWidth: w.tensor ? 6 * (1 - t) + 1 : 3)
      if w.tensor {
        let r2 = radius * 0.7
        let ring2 = Path(
          ellipseIn: CGRect(x: center.x - r2, y: center.y - r2, width: r2 * 2, height: r2 * 2))
        ctx.stroke(ring2, with: .color(Color.white.opacity(alpha * 0.6)), lineWidth: 2)
        // Horizontal beam across the die.
        var beam = Path()
        beam.addRect(
          CGRect(x: 0, y: cy - cell * 2 * (1 - t), width: size.width, height: cell * 4 * (1 - t)))
        ctx.fill(
          beam,
          with: .linearGradient(
            Gradient(colors: [.clear, Theme.greenBright.opacity(alpha * 0.5), .clear]),
            startPoint: CGPoint(x: 0, y: cy - cell * 2), endPoint: CGPoint(x: 0, y: cy + cell * 2)))
      }
    }

    // Full-screen flash.
    if store.flash > 0 {
      var p = Path()
      p.addRect(CGRect(origin: .zero, size: size))
      ctx.fill(p, with: .color(Theme.greenBright.opacity(store.flash * 0.18)))
    }
  }

  private func drawBlock(
    _ ctx: inout GraphicsContext, rect: CGRect, color: Color, alpha: Double, cell: CGFloat,
    glow: Bool = false
  ) {
    let path = Path(roundedRect: rect, cornerRadius: cell * 0.14)
    if glow {
      var g = ctx
      g.addFilter(.blur(radius: cell * 0.35))
      g.fill(path, with: .color(color.opacity(0.7 * alpha)))
    }
    ctx.fill(
      path,
      with: .linearGradient(
        Gradient(colors: [color.opacity(alpha), color.opacity(alpha * 0.62)]),
        startPoint: CGPoint(x: rect.minX, y: rect.minY),
        endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
    // Die "pad": inner square like a chip's contact.
    let inner = rect.insetBy(dx: rect.width * 0.28, dy: rect.height * 0.28)
    ctx.fill(
      Path(roundedRect: inner, cornerRadius: 1.5), with: .color(Theme.black.opacity(0.35 * alpha)))
    ctx.stroke(
      Path(roundedRect: inner, cornerRadius: 1.5), with: .color(Color.white.opacity(0.35 * alpha)),
      lineWidth: 0.8)
    // Top-left highlight edge.
    var hi = Path()
    hi.move(to: CGPoint(x: rect.minX + 2, y: rect.maxY - 2))
    hi.addLine(to: CGPoint(x: rect.minX + 2, y: rect.minY + 2))
    hi.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY + 2))
    ctx.stroke(hi, with: .color(Color.white.opacity(0.45 * alpha)), lineWidth: 1)
  }
}

/// Small preview of a kernel for hold/next panels.
struct KernelPreview: View {
  var kernel: Kernel?
  var dimmed = false
  var size: CGFloat = 14

  var body: some View {
    Canvas { ctx, canvasSize in
      guard let kernel else { return }
      let cells = kernel.cells(rotation: 0)
      let minR = cells.map(\.row).min() ?? 0
      let maxR = cells.map(\.row).max() ?? 0
      let minC = cells.map(\.col).min() ?? 0
      let maxC = cells.map(\.col).max() ?? 0
      let w = CGFloat(maxC - minC + 1) * size
      let h = CGFloat(maxR - minR + 1) * size
      let ox = (canvasSize.width - w) / 2
      let oy = (canvasSize.height - h) / 2
      let color = Theme.color(for: kernel).opacity(dimmed ? 0.35 : 1)
      for c in cells {
        let r = CGRect(
          x: ox + CGFloat(c.col - minC) * size + 1, y: oy + CGFloat(c.row - minR) * size + 1,
          width: size - 2, height: size - 2)
        ctx.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(color))
        let inner = r.insetBy(dx: r.width * 0.3, dy: r.height * 0.3)
        ctx.fill(Path(roundedRect: inner, cornerRadius: 1), with: .color(Theme.black.opacity(0.35)))
      }
    }
    .frame(width: size * 4 + 4, height: size * 2 + 4)
  }
}
