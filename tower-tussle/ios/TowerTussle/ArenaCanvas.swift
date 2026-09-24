import SwiftUI

/// Deterministic pseudo-random helper so decorative scatter is stable per frame.
private func hash(_ x: Int, _ y: Int, _ salt: Int = 0) -> Double {
    var h = UInt64(bitPattern: Int64(x)) &* 0x9E3779B97F4A7C15
    h ^= UInt64(bitPattern: Int64(y)) &* 0xC2B2AE3D27D4EB4F
    h ^= UInt64(bitPattern: Int64(salt)) &* 0x165667B19E3779F9
    h = (h ^ (h >> 31)) &* 0xBF58476D1CE4E5B9
    h = (h ^ (h >> 29))
    return Double(h % 10_000) / 10_000
}

struct ArenaCanvas: View {
    @ObservedObject var engine: BattleEngine
    let scale: CGFloat
    var hover: Vec? = nil

    var body: some View {
        ZStack {
            ArenaGround(scale: scale).equatable()
            Canvas(rendersAsynchronously: false) { ctx, size in
                let painter = ArenaPainter(engine: engine, scale: scale, hover: hover)
                painter.drawDynamic(&ctx, size: size)
            }
        }
    }
}

/// Static battlefield: drawn once and reused between frames.
struct ArenaGround: View, Equatable {
    let scale: CGFloat
    static func == (a: ArenaGround, b: ArenaGround) -> Bool { a.scale == b.scale }

    var body: some View {
        RenderedArt.image("arena").resizable().interpolation(.high)
    }
}

struct ArenaPainter {
    let engine: BattleEngine
    let scale: CGFloat
    var hover: Vec? = nil

    private func pt(_ v: Vec) -> CGPoint { CGPoint(x: v.x * scale, y: v.y * scale) }
    private func len(_ d: Double) -> CGFloat { d * scale }

    // MARK: Ground

    static func drawGround(_ ctx: inout GraphicsContext, size: CGSize, scale: CGFloat) {
        func len(_ d: Double) -> CGFloat { d * scale }
        let full = CGRect(origin: .zero, size: size)
        ctx.fill(Path(full), with: .linearGradient(Gradient(colors: [Theme.grass, Theme.grassDark, Theme.grass]),
                                                   startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        // Mottled turf tiles
        for gy in 0..<Int(Arena.height) {
            for gx in 0..<Int(Arena.width) {
                let n = hash(gx, gy)
                let tile = CGRect(x: len(Double(gx)), y: len(Double(gy)), width: len(1) + 0.5, height: len(1) + 0.5)
                let stripe = (gy / 2) % 2 == 0
                var shade = stripe ? 0.0 : -0.03
                shade += (n - 0.5) * 0.06
                if (gx + gy) % 2 == 0 { shade -= 0.02 }
                let color = Color(red: 0.36 + shade, green: 0.62 + shade * 1.2, blue: 0.30 + shade)
                ctx.fill(Path(tile), with: .color(color))
            }
        }
        // Worn lanes from bridges to keeps
        for bx in Arena.bridgeXs {
            for (top, bottom) in [(2.5, Arena.riverTop), (Arena.riverBottom, 29.5)] {
                let lane = CGRect(x: len(bx - 1.05), y: len(top), width: len(2.1), height: len(bottom - top))
                ctx.fill(Path(roundedRect: lane, cornerRadius: len(1)), with: .color(Color(red: 0.55, green: 0.47, blue: 0.3).opacity(0.22)))
                ctx.fill(Path(roundedRect: lane.insetBy(dx: len(0.35), dy: 0), cornerRadius: len(0.7)), with: .color(Color(red: 0.6, green: 0.5, blue: 0.32).opacity(0.28)))
            }
        }
        for side in [Side.player, Side.enemy] {
            let y = side == .player ? 27.5 : 4.5
            let lane = CGRect(x: len(3.5), y: len(y - 0.9), width: len(11), height: len(1.8))
            ctx.fill(Path(roundedRect: lane, cornerRadius: len(0.9)), with: .color(Color(red: 0.6, green: 0.5, blue: 0.32).opacity(0.22)))
        }
        // Grass tufts and flowers
        for gy in 0..<Int(Arena.height) {
            for gx in 0..<Int(Arena.width) {
                let n = hash(gx, gy, 7)
                let x = len(Double(gx) + hash(gx, gy, 3))
                let y = len(Double(gy) + hash(gx, gy, 5))
                let inRiver = y > len(Arena.riverTop - 0.4) && y < len(Arena.riverBottom + 0.4)
                if inRiver { continue }
                if n < 0.42 {
                    var tuft = Path()
                    let s = len(0.18)
                    tuft.move(to: CGPoint(x: x - s, y: y + s * 0.4)); tuft.addLine(to: CGPoint(x: x - s * 0.5, y: y - s))
                    tuft.move(to: CGPoint(x: x, y: y + s * 0.4)); tuft.addLine(to: CGPoint(x: x, y: y - s * 1.3))
                    tuft.move(to: CGPoint(x: x + s, y: y + s * 0.4)); tuft.addLine(to: CGPoint(x: x + s * 0.5, y: y - s))
                    ctx.stroke(tuft, with: .color(Color(red: 0.25, green: 0.5, blue: 0.2).opacity(0.75)), style: StrokeStyle(lineWidth: max(1, len(0.06)), lineCap: .round))
                } else if n > 0.955 {
                    let color = hash(gx, gy, 9) > 0.5 ? Color(red: 1.0, green: 0.95, blue: 0.85) : Color(red: 1.0, green: 0.85, blue: 0.35)
                    for i in 0..<4 {
                        let a = Double(i) / 4 * .pi * 2
                        ctx.fill(Art.circle(x + CGFloat(cos(a)) * len(0.09), y + CGFloat(sin(a)) * len(0.09), len(0.06)), with: .color(color))
                    }
                    ctx.fill(Art.circle(x, y, len(0.05)), with: .color(Art.gold))
                }
            }
        }
        // Bushes and rocks near edges
        let bushes: [(Double, Double, Double)] = [(1.2, 1.3, 0.9), (16.8, 1.2, 0.8), (1.1, 12.5, 0.8), (16.9, 12.3, 0.9), (0.9, 19.4, 0.85), (17.1, 19.6, 0.8), (1.3, 30.7, 0.9), (16.7, 30.8, 0.85), (9, 9.8, 0.7), (9, 22.2, 0.7)]
        for (bx, by, s) in bushes {
            let c = CGPoint(x: len(bx), y: len(by))
            Art.softShadow(&ctx, cx: c.x, cy: c.y + len(0.35 * s), rx: len(0.9 * s), ry: len(0.3 * s), alpha: 0.3)
            for (dx, dy, rr) in [(-0.35, 0.05, 0.42), (0.35, 0.05, 0.42), (0.0, -0.25, 0.48), (0.0, 0.2, 0.4)] {
                let r = len(rr * s)
                let p = Art.circle(c.x + len(dx * s), c.y + len(dy * s), r)
                Art.shape(&ctx, p, fill: .radialGradient(Gradient(colors: [Color(red: 0.36, green: 0.66, blue: 0.3), Art.leafDark]), center: CGPoint(x: c.x + len(dx * s) - r * 0.4, y: c.y + len(dy * s) - r * 0.4), startRadius: 0, endRadius: r * 1.4), line: max(1, len(0.06)))
            }
        }
        let rocks: [(Double, Double, Double)] = [(6.3, 12.2, 0.5), (11.8, 20.1, 0.45), (2.2, 22.8, 0.4), (15.6, 9.7, 0.4)]
        for (rx, ry, s) in rocks {
            let c = CGPoint(x: len(rx), y: len(ry))
            Art.softShadow(&ctx, cx: c.x, cy: c.y + len(0.25 * s), rx: len(0.8 * s), ry: len(0.25 * s), alpha: 0.3)
            let rock = Art.polygon([CGPoint(x: c.x - len(0.7 * s), y: c.y + len(0.2 * s)), CGPoint(x: c.x - len(0.5 * s), y: c.y - len(0.4 * s)),
                                    CGPoint(x: c.x + len(0.1 * s), y: c.y - len(0.6 * s)), CGPoint(x: c.x + len(0.7 * s), y: c.y - len(0.1 * s)),
                                    CGPoint(x: c.x + len(0.5 * s), y: c.y + len(0.3 * s))])
            Art.shape(&ctx, rock, fill: Art.vertical(Art.stoneLight, Art.stoneDark, rock.boundingRect), line: max(1, len(0.06)))
        }

        // River bed, water, banks
        let riverRect = CGRect(x: 0, y: len(Arena.riverTop), width: size.width, height: len(Arena.riverBottom - Arena.riverTop))
        let bank = riverRect.insetBy(dx: 0, dy: -len(0.32))
        ctx.fill(Path(bank), with: .color(Color(red: 0.72, green: 0.64, blue: 0.42)))
        ctx.fill(Path(riverRect.insetBy(dx: 0, dy: -len(0.12))), with: .color(Color(red: 0.16, green: 0.36, blue: 0.6)))
        ctx.fill(Path(riverRect), with: .linearGradient(Gradient(colors: [Color(red: 0.32, green: 0.66, blue: 0.95), Theme.river, Color(red: 0.2, green: 0.45, blue: 0.8)]),
                                                        startPoint: CGPoint(x: 0, y: riverRect.minY), endPoint: CGPoint(x: 0, y: riverRect.maxY)))
        for i in 0..<9 {
            let x = len(Double(i) * 2.1 + 0.4)
            let y = riverRect.minY + riverRect.height * CGFloat(0.2 + 0.6 * hash(i, 1, 11))
            ctx.fill(Art.ellipse(x, y, len(0.55), len(0.14)), with: .color(.white.opacity(0.12)))
        }
        // pebbles along bank
        for i in 0..<28 {
            let x = len(Double(i) * 0.66 + hash(i, 2, 4) * 0.5)
            let top = hash(i, 3, 4) > 0.5
            let y = top ? bank.minY + len(0.12) : bank.maxY - len(0.12)
            ctx.fill(Art.ellipse(x, y, len(0.12 + hash(i, 4, 4) * 0.08), len(0.08)), with: .color(Art.stone.opacity(0.8)))
        }
        // Bridges
        for bx in Arena.bridgeXs {
            let rect = CGRect(x: len(bx - Arena.bridgeHalfWidth), y: len(Arena.riverTop - 0.45),
                              width: len(Arena.bridgeHalfWidth * 2), height: len(Arena.riverBottom - Arena.riverTop + 0.9))
            ctx.fill(Path(roundedRect: rect.offsetBy(dx: len(0.12), dy: len(0.18)), cornerRadius: len(0.1)), with: .color(.black.opacity(0.28)))
            Art.shape(&ctx, Path(roundedRect: rect, cornerRadius: len(0.1)), fill: Art.horizontal(Art.wood, Art.woodDark, rect), line: max(1, len(0.07)))
            let planks = 7
            for i in 0..<planks {
                let y = rect.minY + CGFloat(i) * rect.height / CGFloat(planks)
                let plank = CGRect(x: rect.minX + len(0.05), y: y + len(0.04), width: rect.width - len(0.1), height: rect.height / CGFloat(planks) - len(0.08))
                let tint = 0.02 * (hash(Int(bx * 10), i, 6) - 0.5)
                ctx.fill(Path(roundedRect: plank, cornerRadius: len(0.05)), with: .color(Color(red: 0.66 + tint, green: 0.46 + tint, blue: 0.24 + tint)))
                ctx.fill(Path(CGRect(x: plank.minX, y: plank.minY, width: plank.width, height: len(0.05))), with: .color(.white.opacity(0.15)))
            }
            // railings
            for rx in [rect.minX + len(0.08), rect.maxX - len(0.08)] {
                var rope = Path()
                rope.move(to: CGPoint(x: rx, y: rect.minY + len(0.1)))
                rope.addLine(to: CGPoint(x: rx, y: rect.maxY - len(0.1)))
                ctx.stroke(rope, with: .color(Art.woodDark), lineWidth: max(1.5, len(0.09)))
                for i in 0..<4 {
                    let y = rect.minY + len(0.1) + CGFloat(i) * (rect.height - len(0.2)) / 3
                    Art.shape(&ctx, Path(roundedRect: CGRect(x: rx - len(0.13), y: y - len(0.16), width: len(0.26), height: len(0.32)), cornerRadius: len(0.05)), fill: .color(Art.wood), line: max(1, len(0.05)))
                }
            }
        }
        // Stone perimeter wall
        let wall = len(0.32)
        let outer = Path(full)
        let inner = Path(roundedRect: full.insetBy(dx: wall, dy: wall), cornerRadius: len(0.2))
        var frame = outer
        frame.addPath(inner)
        ctx.fill(frame, with: .linearGradient(Gradient(colors: [Art.stoneLight, Art.stone]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)), style: FillStyle(eoFill: true))
        ctx.stroke(inner, with: .color(Art.stoneDark.opacity(0.8)), lineWidth: max(1, len(0.05)))
        var mortar = Path()
        var x: CGFloat = 0
        while x < size.width { mortar.move(to: CGPoint(x: x, y: 0)); mortar.addLine(to: CGPoint(x: x, y: wall)); mortar.move(to: CGPoint(x: x + wall, y: size.height - wall)); mortar.addLine(to: CGPoint(x: x + wall, y: size.height)); x += len(0.8) }
        var y: CGFloat = 0
        while y < size.height { mortar.move(to: CGPoint(x: 0, y: y)); mortar.addLine(to: CGPoint(x: wall, y: y)); mortar.move(to: CGPoint(x: size.width - wall, y: y + wall)); mortar.addLine(to: CGPoint(x: size.width, y: y + wall)); y += len(0.8) }
        ctx.stroke(mortar, with: .color(Art.stoneDark.opacity(0.5)), lineWidth: max(1, len(0.04)))
        // inner vignette for depth
        ctx.stroke(Path(roundedRect: full.insetBy(dx: wall + len(0.1), dy: wall + len(0.1)), cornerRadius: len(0.2)), with: .color(.black.opacity(0.18)), lineWidth: len(0.2))
    }

    // MARK: Dynamic layer

    func drawDynamic(_ ctx: inout GraphicsContext, size: CGSize) {
        drawWater(&ctx, size: size)
        drawDeployHint(&ctx)
        var drawables: [(Double, (inout GraphicsContext) -> Void)] = []
        for tower in engine.towers {
            drawables.append((tower.pos.y + 0.6, { c in self.drawTower(&c, tower) }))
        }
        for unit in engine.units where unit.alive {
            drawables.append((unit.pos.y + (unit.card.flying ? 3 : 0), { c in self.drawUnit(&c, unit) }))
        }
        for e in engine.effects where e.kind == .deploy || (e.kind != .towerFall && !e.landed) {
            drawables.append((e.pos.y - 5, { c in self.drawEffect(&c, e) }))
        }
        for (_, draw) in drawables.sorted(by: { $0.0 < $1.0 }) { draw(&ctx) }
        for p in engine.particles where p.kind == .dust || p.kind == .debris || p.kind == .bone { drawParticle(&ctx, p) }
        for p in engine.projectiles { drawProjectile(&ctx, p) }
        for e in engine.effects where e.kind == .towerFall || (e.kind != .deploy && e.landed) { drawEffect(&ctx, e) }
        for p in engine.particles where !(p.kind == .dust || p.kind == .debris || p.kind == .bone) { drawParticle(&ctx, p) }
        drawFloatingTexts(&ctx)
        drawGhost(&ctx)
    }

    /// Placement preview that follows the finger while a card is selected.
    private func drawGhost(_ ctx: inout GraphicsContext) {
        guard let hover, let card = engine.selectedCard, engine.result == nil else { return }
        let valid = engine.isValidDeploy(card, at: hover) && engine.canAfford(card)
        let color = valid ? Theme.player : Theme.enemy
        let c = pt(hover)
        let r = card.kind == .spell ? len(card.radius) : len(1.1)
        let pulse = 0.5 + 0.5 * sin(engine.elapsed * 6)
        ctx.fill(Art.circle(c.x, c.y, r), with: .color(color.opacity(0.18 + 0.08 * pulse)))
        ctx.stroke(Art.circle(c.x, c.y, r), with: .color(color.opacity(0.9)), style: StrokeStyle(lineWidth: 2.5, dash: [6, 4], dashPhase: CGFloat(engine.elapsed * 30)))
        var cross = Path()
        cross.move(to: CGPoint(x: c.x - len(0.5), y: c.y)); cross.addLine(to: CGPoint(x: c.x + len(0.5), y: c.y))
        cross.move(to: CGPoint(x: c.x, y: c.y - len(0.5))); cross.addLine(to: CGPoint(x: c.x, y: c.y + len(0.5)))
        ctx.stroke(cross, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        if card.kind == .troop {
            if let frame = RenderedArt.frames[card.id]?.first {
                let size = len(card.count > 1 ? 2.4 : 3.0)
                var g = ctx
                g.opacity = valid ? 0.75 : 0.35
                g.draw(frame, in: CGRect(x: c.x - size / 2, y: c.y - size * 0.85, width: size, height: size))
            }
        }
    }

    private func drawWater(_ ctx: inout GraphicsContext, size: CGSize) {
        let t = engine.elapsed
        let top = len(Arena.riverTop), bottom = len(Arena.riverBottom)
        var c = ctx
        c.clip(to: Path(CGRect(x: 0, y: top, width: size.width, height: bottom - top)))
        for i in 0..<4 {
            let baseY = top + (bottom - top) * (CGFloat(i) + 0.5) / 4
            var wave = Path()
            let phase = CGFloat(t * 1.6 + Double(i) * 1.3)
            wave.move(to: CGPoint(x: -len(2), y: baseY))
            var x: CGFloat = -len(2)
            while x < size.width + len(2) {
                let mid = x + len(0.9)
                let dy = sin((x / len(1.8)) + phase) * len(0.12)
                wave.addQuadCurve(to: CGPoint(x: x + len(1.8), y: baseY + dy), control: CGPoint(x: mid, y: baseY - len(0.2) + dy))
                x += len(1.8)
            }
            c.stroke(wave, with: .color(.white.opacity(i % 2 == 0 ? 0.22 : 0.14)), lineWidth: max(1, len(0.06)))
        }
        // sparkle
        for i in 0..<10 {
            let s = sin(t * 3 + Double(i) * 2.1)
            guard s > 0.6 else { continue }
            let x = len(Double(i) * 1.85 + 0.9)
            let y = top + (bottom - top) * CGFloat(0.25 + 0.5 * hash(i, 12, 2))
            c.fill(Art.circle(x, y, len(0.07) * CGFloat(s)), with: .color(.white.opacity(0.8 * (s - 0.6) * 2.5)))
        }
    }

    private func drawDeployHint(_ ctx: inout GraphicsContext) {
        guard let card = engine.selectedCard, engine.result == nil else { return }
        let affordable = engine.canAfford(card)
        let color = affordable ? Theme.player : Theme.enemy
        let rect: CGRect
        if card.kind == .spell {
            rect = CGRect(x: 0, y: 0, width: len(Arena.width), height: len(Arena.height))
        } else {
            rect = CGRect(x: 0, y: len(Arena.playerDeployMinY), width: len(Arena.width), height: len(Arena.height - Arena.playerDeployMinY))
            let blocked = CGRect(x: 0, y: 0, width: len(Arena.width), height: len(Arena.playerDeployMinY))
            ctx.fill(Path(blocked), with: .color(.black.opacity(0.28)))
        }
        let pulse = 0.5 + 0.5 * sin(engine.elapsed * 4)
        ctx.fill(Path(rect), with: .color(color.opacity(0.10 + 0.05 * pulse)))
        var grid = Path()
        var gx = 0.0
        while gx <= Arena.width { grid.move(to: CGPoint(x: len(gx), y: rect.minY)); grid.addLine(to: CGPoint(x: len(gx), y: rect.maxY)); gx += 1 }
        var gy = floor(rect.minY / scale)
        while gy <= Arena.height { let yy = max(rect.minY, len(gy)); grid.move(to: CGPoint(x: 0, y: yy)); grid.addLine(to: CGPoint(x: rect.maxX, y: yy)); gy += 1 }
        ctx.stroke(grid, with: .color(color.opacity(0.18)), lineWidth: 1)
        ctx.stroke(Path(rect.insetBy(dx: 1.5, dy: 1.5)), with: .color(color.opacity(0.75)), style: StrokeStyle(lineWidth: 2.5, dash: [8, 5], dashPhase: CGFloat(engine.elapsed * 20)))
    }

    private func drawTower(_ ctx: inout GraphicsContext, _ tower: Tower) {
        let r = len(tower.kind.radius) * (tower.kind == .keep ? 0.82 : 0.9)
        let foot = pt(tower.pos)
        // Art is taller above its origin than below, so sit it slightly low on the footprint.
        let center = CGPoint(x: foot.x, y: foot.y + r * 0.4)
        if tower.alive {
            let name = "tower_\(tower.kind == .keep ? "keep" : "guard")_\(tower.side == .player ? "blue" : "red")"
            var g = ctx
            if tower.hitFlash > 0 { g.addFilter(.brightness(0.3)) }
            g.draw(RenderedArt.image(name), in: CGRect(x: center.x - r * 1.8, y: center.y - r * 2.5, width: r * 3.6, height: r * 3.6))
        } else {
            Art.tower(&ctx, kind: tower.kind, side: tower.side, center: center, r: r, alive: false,
                      activated: tower.activated, flash: false, time: engine.elapsed)
        }
        guard tower.alive else { return }
        let barY = center.y + r * 1.0 + len(0.25)
        Art.healthBar(&ctx, center: CGPoint(x: center.x, y: barY), width: r * 2.1, height: len(0.34),
                      fraction: tower.hp / tower.kind.maxHp, side: tower.side, label: "\(Int(tower.hp))")
        if tower.kind == .keep && !tower.activated {
            let t = engine.elapsed
            let bob = CGFloat(sin(t * 2)) * len(0.1)
            Art.outlinedText(&ctx, "z", at: CGPoint(x: center.x + r * 1.3, y: center.y - r * 1.5 + bob), size: len(0.5), color: .white.opacity(0.85))
            Art.outlinedText(&ctx, "z", at: CGPoint(x: center.x + r * 1.65, y: center.y - r * 1.9 - bob), size: len(0.38), color: .white.opacity(0.7))
        }
    }

    private func drawUnit(_ ctx: inout GraphicsContext, _ unit: Unit) {
        let r = len(unit.radius) * (unit.card.id == "giant" ? 1.32 : (unit.card.count > 1 ? 1.20 : 1.10))
        let foot = pt(unit.pos)
        let scaleIn = CGFloat(min(1, unit.spawnAge / 0.25))
        let shadowR = len(unit.radius) * (unit.card.flying ? 0.8 : 1.1)
        Art.softShadow(&ctx, cx: foot.x, cy: foot.y + len(0.05), rx: shadowR, ry: shadowR * 0.4, alpha: unit.card.flying ? 0.25 : 0.4)
        ctx.stroke(Art.ellipse(foot.x, foot.y, shadowR, shadowR * 0.42), with: .color(Art.team(unit.side).opacity(0.85)), lineWidth: len(0.10))
        RenderedArt.unit(&ctx, unit: unit, foot: foot, radius: r * (0.6 + 0.4 * scaleIn))
        if unit.hp < unit.card.hp {
            let top = foot.y - r * (unit.card.id == "giant" ? 4.6 : (unit.card.flying ? 5.2 : 4.0))
            Art.healthBar(&ctx, center: CGPoint(x: foot.x, y: top), width: max(len(1.0), r * 2.6), height: len(0.2),
                          fraction: unit.hp / unit.card.hp, side: unit.side)
        }
    }

    private func drawProjectile(_ ctx: inout GraphicsContext, _ p: Projectile) {
        let start = pt(p.start), end = pt(p.target)
        let prog = CGFloat(p.progress)
        let flat = pt(p.pos)
        let dist = hypot(end.x - start.x, end.y - start.y)
        let arcH = dist * (p.kind == .cannon ? 0.35 : (p.kind == .fireball ? 0.12 : 0.2))
        let lift = sin(prog * .pi) * arcH
        let c = CGPoint(x: flat.x, y: flat.y - lift)
        // ground shadow
        ctx.fill(Art.ellipse(flat.x, flat.y, len(0.16), len(0.07)), with: .color(.black.opacity(0.25)))
        let ux = (end.x - start.x) / max(1, dist), uy = (end.y - start.y) / max(1, dist)
        let slope = cos(prog * .pi) * .pi * arcH / max(1, dist)
        let angle = atan2(uy - slope, ux)
        switch p.kind {
        case .arrow, .bolt:
            var g = ctx
            g.translateBy(x: c.x, y: c.y)
            g.rotate(by: .radians(angle))
            let l = len(p.kind == .bolt ? 0.8 : 0.7)
            var shaft = Path()
            shaft.move(to: CGPoint(x: -l / 2, y: 0)); shaft.addLine(to: CGPoint(x: l / 2, y: 0))
            g.stroke(shaft, with: .color(Art.outline), style: StrokeStyle(lineWidth: len(0.14), lineCap: .round))
            g.stroke(shaft, with: .color(p.kind == .bolt ? Art.steel : Art.wood), style: StrokeStyle(lineWidth: len(0.07), lineCap: .round))
            g.fill(Art.polygon([CGPoint(x: l / 2 + len(0.12), y: 0), CGPoint(x: l / 2 - len(0.1), y: -len(0.09)), CGPoint(x: l / 2 - len(0.1), y: len(0.09))]), with: .color(Art.steel))
            let feather = p.side == .player ? Theme.player : Theme.enemy
            g.fill(Art.polygon([CGPoint(x: -l / 2, y: 0), CGPoint(x: -l / 2 - len(0.12), y: -len(0.11)), CGPoint(x: -l / 2 + len(0.16), y: -len(0.02))]), with: .color(feather))
            g.fill(Art.polygon([CGPoint(x: -l / 2, y: 0), CGPoint(x: -l / 2 - len(0.12), y: len(0.11)), CGPoint(x: -l / 2 + len(0.16), y: len(0.02))]), with: .color(feather))
        case .cannon:
            Art.ball(&ctx, cx: c.x, cy: c.y, r: len(0.22), color: Art.steelDark, dark: Art.outline, line: max(1, len(0.05)))
            ctx.fill(Art.circle(c.x - len(0.07), c.y - len(0.07), len(0.05)), with: .color(.white.opacity(0.6)))
        case .fireball:
            for i in 1...3 {
                let back = CGPoint(x: c.x - cos(angle) * len(0.22) * CGFloat(i), y: c.y - sin(angle) * len(0.22) * CGFloat(i))
                ctx.fill(Art.circle(back.x, back.y, len(0.2) * (1 - CGFloat(i) * 0.25)), with: .color(Art.fire.opacity(0.5 - Double(i) * 0.12)))
            }
            var g = ctx
            g.blendMode = .plusLighter
            g.fill(Art.circle(c.x, c.y, len(0.4)), with: .radialGradient(Gradient(colors: [Art.fireCore, Art.fire.opacity(0.0)]), center: c, startRadius: 0, endRadius: len(0.4)))
            Art.ball(&ctx, cx: c.x, cy: c.y, r: len(0.2), color: Art.fireCore, dark: Art.fire, line: max(1, len(0.04)))
        }
    }

    private func drawEffect(_ ctx: inout GraphicsContext, _ e: SpellEffect) {
        let c = pt(e.pos)
        let R = len(e.radius)
        let team = Art.team(e.side)
        switch e.kind {
        case .deploy:
            let p = CGFloat(e.progress)
            let r = R * (0.3 + 0.9 * p)
            ctx.stroke(Art.ellipse(c.x, c.y, r, r * 0.55), with: .color(team.opacity(0.9 * (1 - Double(p)))), lineWidth: max(1, len(0.12)) * (1 - p) + 1)
            ctx.fill(Art.ellipse(c.x, c.y, r * 0.8, r * 0.44), with: .color(team.opacity(0.35 * (1 - Double(p)))))
            var g = ctx
            g.blendMode = .plusLighter
            g.fill(Art.circle(c.x, c.y - len(0.6), len(1.0) * (1 - p)), with: .radialGradient(Gradient(colors: [Color.white.opacity(0.7 * (1 - Double(p))), Color.white.opacity(0)]), center: CGPoint(x: c.x, y: c.y - len(0.6)), startRadius: 0, endRadius: len(1.0) * (1 - p) + 0.1))
        case .meteor:
            let delay = e.kind.impactDelay
            if !e.landed {
                let f = CGFloat(e.age / delay)
                // target marker
                ctx.stroke(Art.ellipse(c.x, c.y, R, R * 0.6), with: .color(Art.fire.opacity(0.7)), style: StrokeStyle(lineWidth: 2, dash: [6, 4], dashPhase: CGFloat(e.age * 30)))
                ctx.fill(Art.ellipse(c.x, c.y, R * f, R * 0.6 * f), with: .color(Color.black.opacity(0.25 * Double(f))))
                // falling rock
                let from = CGPoint(x: c.x + len(6), y: c.y - len(14))
                let m = CGPoint(x: from.x + (c.x - from.x) * f, y: from.y + (c.y - from.y) * f)
                let dir = CGPoint(x: (from.x - c.x), y: (from.y - c.y))
                let l = max(1, hypot(dir.x, dir.y))
                let n = CGPoint(x: dir.x / l, y: dir.y / l)
                var trail = Path()
                trail.move(to: m)
                trail.addLine(to: CGPoint(x: m.x + n.x * len(3.5), y: m.y + n.y * len(3.5)))
                var g = ctx
                g.blendMode = .plusLighter
                g.stroke(trail, with: .linearGradient(Gradient(colors: [Art.fireCore, Art.fire.opacity(0)]), startPoint: m, endPoint: CGPoint(x: m.x + n.x * len(3.5), y: m.y + n.y * len(3.5))), style: StrokeStyle(lineWidth: len(1.0), lineCap: .round))
                g.fill(Art.circle(m.x, m.y, len(0.95)), with: .radialGradient(Gradient(colors: [Art.fireCore, Art.fire.opacity(0)]), center: m, startRadius: 0, endRadius: len(0.95)))
                Art.ball(&ctx, cx: m.x, cy: m.y, r: len(0.55), color: Color(red: 0.55, green: 0.3, blue: 0.2), dark: Color(red: 0.25, green: 0.12, blue: 0.08), line: max(1, len(0.06)))
                ctx.fill(Art.circle(m.x - len(0.15), m.y + len(0.1), len(0.12)), with: .color(Art.fire))
            } else {
                let f = CGFloat(min(1, (e.age - delay) / (e.kind.duration - delay)))
                let boom = min(1, f * 2.2)
                // scorch
                ctx.fill(Art.ellipse(c.x, c.y, R * 1.05, R * 0.62), with: .color(Color(red: 0.12, green: 0.08, blue: 0.06).opacity(0.55 * (1 - Double(f)))))
                var g = ctx
                g.blendMode = .plusLighter
                let r = R * (0.5 + 0.8 * boom)
                g.fill(Art.ellipse(c.x, c.y - len(0.3), r, r * 0.75), with: .radialGradient(Gradient(colors: [Color.white.opacity(0.95 * (1 - Double(boom))), Art.fireCore.opacity(0.9 * (1 - Double(f))), Art.fire.opacity(0.6 * (1 - Double(f))), Art.fire.opacity(0)]), center: CGPoint(x: c.x, y: c.y - len(0.3)), startRadius: 0, endRadius: r))
                let ring = R * (0.6 + 1.0 * boom)
                g.stroke(Art.ellipse(c.x, c.y, ring, ring * 0.6), with: .color(Art.fireCore.opacity(0.8 * (1 - Double(boom)))), lineWidth: max(1, len(0.25) * (1 - boom)))
                if f < 0.5 {
                    let flame = R * 0.9 * (1 - f * 2)
                    for i in 0..<5 {
                        let a = Double(i) / 5 * .pi * 2 + e.age * 2
                        let fx = c.x + CGFloat(cos(a)) * R * 0.45, fy = c.y - len(0.2) + CGFloat(sin(a)) * R * 0.25
                        g.fill(Art.ellipse(fx, fy - flame * 0.4, flame * 0.35, flame * 0.7), with: .radialGradient(Gradient(colors: [Art.fireCore, Art.fire.opacity(0)]), center: CGPoint(x: fx, y: fy), startRadius: 0, endRadius: flame * 0.7))
                    }
                }
            }
        case .volley:
            let delay = e.kind.impactDelay
            if !e.landed {
                let f = CGFloat(e.age / delay)
                ctx.stroke(Art.ellipse(c.x, c.y, R, R * 0.6), with: .color(Color.cyan.opacity(0.7)), style: StrokeStyle(lineWidth: 2, dash: [6, 4], dashPhase: CGFloat(e.age * 30)))
                ctx.fill(Art.ellipse(c.x, c.y, R, R * 0.6), with: .color(Color.cyan.opacity(0.12)))
                for i in 0..<14 {
                    let a = hash(i, 21, e.id) * .pi * 2
                    let rr = sqrt(hash(i, 22, e.id)) * Double(R)
                    let land = CGPoint(x: c.x + CGFloat(cos(a) * rr), y: c.y + CGFloat(sin(a) * rr * 0.6))
                    let stagger = CGFloat(hash(i, 23, e.id)) * 0.35
                    let g = max(0, min(1, (f - stagger) / (1 - stagger)))
                    let from = CGPoint(x: land.x + len(1.2), y: land.y - len(12))
                    let m = CGPoint(x: from.x + (land.x - from.x) * g, y: from.y + (land.y - from.y) * g)
                    var s = Path()
                    s.move(to: m)
                    s.addLine(to: CGPoint(x: m.x + len(0.09), y: m.y - len(0.9)))
                    ctx.stroke(s, with: .color(Art.outline), style: StrokeStyle(lineWidth: len(0.11), lineCap: .round))
                    ctx.stroke(s, with: .color(Art.wood), style: StrokeStyle(lineWidth: len(0.05), lineCap: .round))
                    ctx.fill(Art.polygon([CGPoint(x: m.x, y: m.y + len(0.12)), CGPoint(x: m.x - len(0.07), y: m.y - len(0.08)), CGPoint(x: m.x + len(0.07), y: m.y - len(0.06))]), with: .color(Art.steel))
                }
            } else {
                let f = CGFloat(min(1, (e.age - delay) / (e.kind.duration - delay)))
                var g = ctx
                g.blendMode = .plusLighter
                let ring = R * (0.7 + 0.5 * min(1, f * 2))
                g.stroke(Art.ellipse(c.x, c.y, ring, ring * 0.6), with: .color(Color.cyan.opacity(0.7 * (1 - Double(min(1, f * 2))))), lineWidth: max(1, len(0.2) * (1 - f)))
                for i in 0..<14 {
                    let a = hash(i, 21, e.id) * .pi * 2
                    let rr = sqrt(hash(i, 22, e.id)) * Double(R)
                    let land = CGPoint(x: c.x + CGFloat(cos(a) * rr), y: c.y + CGFloat(sin(a) * rr * 0.6))
                    var s = Path()
                    s.move(to: land)
                    s.addLine(to: CGPoint(x: land.x + len(0.08), y: land.y - len(0.6)))
                    ctx.stroke(s, with: .color(Art.outline.opacity(1 - Double(f))), style: StrokeStyle(lineWidth: len(0.1), lineCap: .round))
                    ctx.stroke(s, with: .color(Art.wood.opacity(1 - Double(f))), style: StrokeStyle(lineWidth: len(0.045), lineCap: .round))
                    ctx.fill(Art.polygon([CGPoint(x: land.x + len(0.08), y: land.y - len(0.6)), CGPoint(x: land.x + len(0.16), y: land.y - len(0.5)), CGPoint(x: land.x + len(0.02), y: land.y - len(0.45))]), with: .color(Color.white.opacity(1 - Double(f))))
                }
            }
        case .towerFall:
            let f = CGFloat(e.progress)
            var g = ctx
            g.blendMode = .plusLighter
            let r = R * (0.4 + 0.9 * min(1, f * 1.6))
            g.fill(Art.ellipse(c.x, c.y, r, r * 0.6), with: .radialGradient(Gradient(colors: [Color.white.opacity(0.8 * (1 - Double(f))), Art.gold.opacity(0.4 * (1 - Double(f))), Color.clear]), center: c, startRadius: 0, endRadius: r))
            g.stroke(Art.ellipse(c.x, c.y, r * 1.1, r * 0.65), with: .color(Color(white: 0.9).opacity(0.7 * (1 - Double(f)))), lineWidth: max(1, len(0.3) * (1 - f)))
        }
    }

    private func drawParticle(_ ctx: inout GraphicsContext, _ p: Particle) {
        let c = pt(p.pos)
        let life = p.life
        let s = len(p.size)
        switch p.kind {
        case .dust, .smoke:
            let grow = p.kind == .smoke ? CGFloat(1.6 - life * 0.6) : CGFloat(1.3 - life * 0.3)
            ctx.fill(Art.circle(c.x, c.y, s * grow), with: .radialGradient(Gradient(colors: [p.color.opacity(0.55 * life), p.color.opacity(0)]), center: c, startRadius: 0, endRadius: s * grow))
        case .spark, .ember, .glow:
            var g = ctx
            g.blendMode = .plusLighter
            g.fill(Art.circle(c.x, c.y, s * 2.2), with: .radialGradient(Gradient(colors: [p.color.opacity(0.7 * life), p.color.opacity(0)]), center: c, startRadius: 0, endRadius: s * 2.2))
            ctx.fill(Art.circle(c.x, c.y, s * CGFloat(0.5 + 0.5 * life)), with: .color((p.kind == .ember ? Art.fireCore : Color.white).opacity(life)))
        case .debris:
            var g = ctx
            g.translateBy(x: c.x, y: c.y)
            g.rotate(by: .radians(Double(p.id) + (1 - life) * 6))
            Art.shape(&g, Path(roundedRect: CGRect(x: -s / 2, y: -s / 2, width: s, height: s * 0.8), cornerRadius: s * 0.15), fill: .color(p.color.opacity(min(1, life * 2))), line: max(0.5, s * 0.15))
        case .bone:
            var g = ctx
            g.translateBy(x: c.x, y: c.y)
            g.rotate(by: .radians(Double(p.id) + (1 - life) * 8))
            var bone = Path()
            bone.move(to: CGPoint(x: -s, y: 0)); bone.addLine(to: CGPoint(x: s, y: 0))
            g.stroke(bone, with: .color(Art.outline.opacity(min(1, life * 2))), style: StrokeStyle(lineWidth: s * 0.7, lineCap: .round))
            g.stroke(bone, with: .color(Art.bone.opacity(min(1, life * 2))), style: StrokeStyle(lineWidth: s * 0.4, lineCap: .round))
            g.fill(Art.circle(-s, 0, s * 0.3), with: .color(Art.bone.opacity(min(1, life * 2))))
            g.fill(Art.circle(s, 0, s * 0.3), with: .color(Art.bone.opacity(min(1, life * 2))))
        case .leaf:
            ctx.fill(Art.ellipse(c.x, c.y, s, s * 0.5), with: .color(p.color.opacity(life)))
        }
    }

    private func drawFloatingTexts(_ ctx: inout GraphicsContext) {
        let bounds = CGRect(x: len(0.2), y: len(0.2), width: len(Arena.width - 0.4), height: len(Arena.height - 0.4))
        var occupied: [CGRect] = []
        for t in engine.floatingTexts.sorted(by: { $0.ttl > $1.ttl }) {
            let maxFont = len(0.93)
            let measured = ctx.resolve(Text(t.text).font(.system(size: maxFont, weight: .black, design: .rounded)))
                .measure(in: bounds.size)
            let padding = 2 * max(1, maxFont * 0.08) + len(0.1)
            let width = measured.width + padding, height = measured.height + padding
            let origin = pt(t.pos)
            let x = min(bounds.maxX - width / 2, max(bounds.minX + width / 2, origin.x + len(t.side == .player ? 0.9 : -0.9)))
            let y = min(bounds.maxY - height / 2, max(bounds.minY + height / 2, origin.y))
            for row in 0..<48 {
                let offset = row == 0 ? 0 : (row % 2 == 1 ? -(row + 1) / 2 : row / 2)
                let rect = CGRect(x: x - width / 2, y: y + CGFloat(offset) * height - height / 2, width: width, height: height)
                guard bounds.contains(rect), !occupied.contains(where: { $0.intersects(rect) }) else { continue }
                occupied.append(rect)
                let pop = 1 + 0.5 * max(0, t.life - 0.75) * 4
                var g = ctx
                g.opacity = min(1, t.life * 3)
                Art.outlinedText(&g, t.text, at: CGPoint(x: rect.midX, y: rect.midY), size: len(0.62) * CGFloat(pop), color: t.color)
                break
            }
        }
    }
}
