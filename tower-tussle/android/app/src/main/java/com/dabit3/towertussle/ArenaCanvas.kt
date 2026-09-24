package com.dabit3.towertussle

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Canvas as GraphicsCanvas
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.sp
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/** Deterministic pseudo-random helper so decorative scatter is stable per frame. */
internal fun hash(x: Int, y: Int, salt: Int = 0): Double {
    var h = x.toLong() * 0x9E3779B97F4A7C15uL.toLong()
    h = h xor (y.toLong() * -0x3D4D51C2D82B14B1L)
    h = h xor (salt.toLong() * 0x165667B19E3779F9L)
    h = (h xor (h ushr 31)) * -0x40A7B892E31B1A47L
    h = h xor (h ushr 29)
    return ((h % 10_000 + 10_000) % 10_000) / 10_000.0
}

@Composable
fun ArenaCanvas(engine: BattleEngine, scale: Float, modifier: Modifier = Modifier, hover: Vec? = null) {
    val measurer = rememberTextMeasurer()
    val art = rememberArt(battle = true)
    Canvas(modifier) {
        engine.version
        renderedImage(art.image("arena"), Offset.Zero, size)
        ArenaPainter(this, engine, measurer, scale, art, hover).drawDynamic()
    }
}

/** Static battlefield: rendered once into a bitmap and reused between frames. */
private class ArenaGroundPainter(val scope: DrawScope, val scale: Float) {
    private fun len(d: Double): Float = (d * scale).toFloat()
    private fun len(d: Float): Float = d * scale
    private fun len(d: Int): Float = d * scale

    fun draw() = with(scope) {
        val w = size.width; val h = size.height
        drawRect(Brush.verticalGradient(listOf(Theme.grass, Theme.grassDark, Theme.grass)))
        for (gy in 0 until Arena.HEIGHT.toInt()) {
            for (gx in 0 until Arena.WIDTH.toInt()) {
                val n = hash(gx, gy)
                var shade = if ((gy / 2) % 2 == 0) 0.0 else -0.03
                shade += (n - 0.5) * 0.06
                if ((gx + gy) % 2 == 0) shade -= 0.02
                val color = Color((0.36 + shade).toFloat(), (0.62 + shade * 1.2).toFloat(), (0.30 + shade).toFloat())
                drawRect(color, Offset(len(gx), len(gy)), Size(len(1) + 0.5f, len(1) + 0.5f))
            }
        }
        for (bx in Arena.BRIDGE_XS) {
            for ((top, bottom) in listOf(2.5 to Arena.RIVER_TOP, Arena.RIVER_BOTTOM to 29.5)) {
                val lane = Art.rect(len(bx - 1.05), len(top), len(2.1), len(bottom - top))
                drawPath(Art.rounded(lane, len(1)), Color(0.55f, 0.47f, 0.3f).copy(alpha = 0.22f))
                drawPath(Art.rounded(lane.deflate(len(0.35)).let { Rect(it.left, lane.top, it.right, lane.bottom) }, len(0.7)), Color(0.6f, 0.5f, 0.32f).copy(alpha = 0.28f))
            }
        }
        for (side in Side.values()) {
            val y = if (side == Side.PLAYER) 27.5 else 4.5
            val lane = Art.rect(len(3.5), len(y - 0.9), len(11), len(1.8))
            drawPath(Art.rounded(lane, len(0.9)), Color(0.6f, 0.5f, 0.32f).copy(alpha = 0.22f))
        }
        for (gy in 0 until Arena.HEIGHT.toInt()) {
            for (gx in 0 until Arena.WIDTH.toInt()) {
                val n = hash(gx, gy, 7)
                val x = len(gx + hash(gx, gy, 3))
                val y = len(gy + hash(gx, gy, 5))
                if (y > len(Arena.RIVER_TOP - 0.4) && y < len(Arena.RIVER_BOTTOM + 0.4)) continue
                if (n < 0.42) {
                    val s = len(0.18)
                    val tuft = Path().apply {
                        moveTo(x - s, y + s * 0.4f); lineTo(x - s * 0.5f, y - s)
                        moveTo(x, y + s * 0.4f); lineTo(x, y - s * 1.3f)
                        moveTo(x + s, y + s * 0.4f); lineTo(x + s * 0.5f, y - s)
                    }
                    drawPath(tuft, Color(0.25f, 0.5f, 0.2f).copy(alpha = 0.75f), style = Stroke(max(1f, len(0.06)), cap = StrokeCap.Round))
                } else if (n > 0.955) {
                    val color = if (hash(gx, gy, 9) > 0.5) Color(1.0f, 0.95f, 0.85f) else Color(1.0f, 0.85f, 0.35f)
                    for (i in 0 until 4) {
                        val a = i / 4.0 * PI * 2
                        drawPath(Art.circle(x + cos(a).toFloat() * len(0.09), y + sin(a).toFloat() * len(0.09), len(0.06)), color)
                    }
                    drawPath(Art.circle(x, y, len(0.05)), Art.gold)
                }
            }
        }
        val bushes = listOf(Triple(1.2, 1.3, 0.9), Triple(16.8, 1.2, 0.8), Triple(1.1, 12.5, 0.8), Triple(16.9, 12.3, 0.9), Triple(0.9, 19.4, 0.85), Triple(17.1, 19.6, 0.8), Triple(1.3, 30.7, 0.9), Triple(16.7, 30.8, 0.85), Triple(9.0, 9.8, 0.7), Triple(9.0, 22.2, 0.7))
        for ((bx, by, s) in bushes) {
            val cx = len(bx); val cy = len(by)
            softShadow(cx, cy + len(0.35 * s), len(0.9 * s), len(0.3 * s), 0.3f)
            for ((dx, dy, rr) in listOf(Triple(-0.35, 0.05, 0.42), Triple(0.35, 0.05, 0.42), Triple(0.0, -0.25, 0.48), Triple(0.0, 0.2, 0.4))) {
                val r = len(rr * s)
                val px = cx + len(dx * s); val py = cy + len(dy * s)
                shape(Art.circle(px, py, r), Art.radial(listOf(Color(0.36f, 0.66f, 0.3f), Art.leafDark), Offset(px - r * 0.4f, py - r * 0.4f), r * 1.4f), max(1f, len(0.06)))
            }
        }
        for ((rx, ry, s) in listOf(Triple(6.3, 12.2, 0.5), Triple(11.8, 20.1, 0.45), Triple(2.2, 22.8, 0.4), Triple(15.6, 9.7, 0.4))) {
            val cx = len(rx); val cy = len(ry)
            softShadow(cx, cy + len(0.25 * s), len(0.8 * s), len(0.25 * s), 0.3f)
            val rock = Art.polygon(
                cx - len(0.7 * s) to cy + len(0.2 * s), cx - len(0.5 * s) to cy - len(0.4 * s),
                cx + len(0.1 * s) to cy - len(0.6 * s), cx + len(0.7 * s) to cy - len(0.1 * s), cx + len(0.5 * s) to cy + len(0.3 * s),
            )
            shape(rock, Art.vertical(Art.stoneLight, Art.stoneDark, rock.getBounds()), max(1f, len(0.06)))
        }

        // River bed, water, banks
        val river = Rect(0f, len(Arena.RIVER_TOP), w, len(Arena.RIVER_BOTTOM))
        val bank = river.inflate(len(0.32)).let { Rect(0f, it.top, w, it.bottom) }
        drawRect(Color(0.72f, 0.64f, 0.42f), bank.topLeft, bank.size)
        val bed = river.inflate(len(0.12))
        drawRect(Color(0.16f, 0.36f, 0.6f), Offset(0f, bed.top), Size(w, bed.height))
        drawRect(Brush.verticalGradient(listOf(Color(0.32f, 0.66f, 0.95f), Theme.river, Color(0.2f, 0.45f, 0.8f)), startY = river.top, endY = river.bottom), river.topLeft, river.size)
        for (i in 0 until 9) {
            val x = len(i * 2.1 + 0.4)
            val y = river.top + river.height * (0.2 + 0.6 * hash(i, 1, 11)).toFloat()
            drawPath(Art.ellipse(x, y, len(0.55), len(0.14)), Color.White.copy(alpha = 0.12f))
        }
        for (i in 0 until 28) {
            val x = len(i * 0.66 + hash(i, 2, 4) * 0.5)
            val y = if (hash(i, 3, 4) > 0.5) bank.top + len(0.12) else bank.bottom - len(0.12)
            drawPath(Art.ellipse(x, y, len(0.12 + hash(i, 4, 4) * 0.08), len(0.08)), Art.stone.copy(alpha = 0.8f))
        }
        // Bridges
        for (bx in Arena.BRIDGE_XS) {
            val r = Art.rect(len(bx - Arena.BRIDGE_HALF_WIDTH), len(Arena.RIVER_TOP - 0.45), len(Arena.BRIDGE_HALF_WIDTH * 2), len(Arena.RIVER_BOTTOM - Arena.RIVER_TOP + 0.9))
            drawPath(Art.rounded(r.translate(len(0.12), len(0.18)), len(0.1)), Color.Black.copy(alpha = 0.28f))
            shape(Art.rounded(r, len(0.1)), Art.horizontal(Art.wood, Art.woodDark, r), max(1f, len(0.07)))
            val planks = 7
            for (i in 0 until planks) {
                val y = r.top + i * r.height / planks
                val plank = Art.rect(r.left + len(0.05), y + len(0.04), r.width - len(0.1), r.height / planks - len(0.08))
                val tint = (0.02 * (hash((bx * 10).toInt(), i, 6) - 0.5)).toFloat()
                drawPath(Art.rounded(plank, len(0.05)), Color(0.66f + tint, 0.46f + tint, 0.24f + tint))
                drawRect(Color.White.copy(alpha = 0.15f), plank.topLeft, Size(plank.width, len(0.05)))
            }
            for (rx in listOf(r.left + len(0.08), r.right - len(0.08))) {
                drawPath(Art.segment(Offset(rx, r.top + len(0.1)), Offset(rx, r.bottom - len(0.1))), Art.woodDark, style = Stroke(max(1.5f, len(0.09))))
                for (i in 0 until 4) {
                    val y = r.top + len(0.1) + i * (r.height - len(0.2)) / 3
                    shape(Art.rounded(Art.rect(rx - len(0.13), y - len(0.16), len(0.26), len(0.32)), len(0.05)), Art.wood, max(1f, len(0.05)))
                }
            }
        }
        // Stone perimeter wall
        val wall = len(0.32)
        val full = Rect(0f, 0f, w, h)
        val frame = Path().apply {
            fillType = PathFillType.EvenOdd
            addRect(full)
            addPath(Art.rounded(full.deflate(wall), len(0.2)))
        }
        drawPath(frame, Brush.linearGradient(listOf(Art.stoneLight, Art.stone), start = Offset.Zero, end = Offset(w, h)))
        drawPath(Art.rounded(full.deflate(wall), len(0.2)), Art.stoneDark.copy(alpha = 0.8f), style = Stroke(max(1f, len(0.05))))
        val mortar = Path()
        var x = 0f
        while (x < w) { mortar.moveTo(x, 0f); mortar.lineTo(x, wall); mortar.moveTo(x + wall, h - wall); mortar.lineTo(x + wall, h); x += len(0.8) }
        var y = 0f
        while (y < h) { mortar.moveTo(0f, y); mortar.lineTo(wall, y); mortar.moveTo(w - wall, y + wall); mortar.lineTo(w, y + wall); y += len(0.8) }
        drawPath(mortar, Art.stoneDark.copy(alpha = 0.5f), style = Stroke(max(1f, len(0.04))))
        drawPath(Art.rounded(full.deflate(wall + len(0.1)), len(0.2)), Color.Black.copy(alpha = 0.18f), style = Stroke(len(0.2)))
    }
}

private class ArenaPainter(
    val scope: DrawScope,
    val engine: BattleEngine,
    val measurer: TextMeasurer,
    val scale: Float,
    val art: RenderedArt,
    val hover: Vec? = null,
) {
    private fun pt(v: Vec) = Offset((v.x * scale).toFloat(), (v.y * scale).toFloat())
    private fun len(d: Double): Float = (d * scale).toFloat()
    private fun len(d: Float): Float = d * scale
    private fun len(d: Int): Float = d * scale
    private fun DrawScope.px(sp: Float): Float = sp * scale / 12f

    fun drawDynamic() = with(scope) {
        drawWater()
        drawDeployHint()
        val drawables = ArrayList<Pair<Double, () -> Unit>>()
        for (tower in engine.towers) drawables.add((tower.pos.y + 0.6) to { drawTower(tower) })
        for (unit in engine.units) if (unit.alive) drawables.add((unit.pos.y + (if (unit.card.flying) 3 else 0)) to { drawUnit(unit) })
        for (e in engine.effects) if (e.kind == EffectKind.DEPLOY || (e.kind != EffectKind.TOWER_FALL && !e.landed)) drawables.add((e.pos.y - 5) to { drawEffect(e) })
        drawables.sortBy { it.first }
        for ((_, d) in drawables) d()
        for (p in engine.particles) if (p.kind == ParticleKind.DUST || p.kind == ParticleKind.DEBRIS || p.kind == ParticleKind.BONE) drawParticle(p)
        for (p in engine.projectiles) drawProjectile(p)
        for (e in engine.effects) if (e.kind == EffectKind.TOWER_FALL || (e.kind != EffectKind.DEPLOY && e.landed)) drawEffect(e)
        for (p in engine.particles) if (!(p.kind == ParticleKind.DUST || p.kind == ParticleKind.DEBRIS || p.kind == ParticleKind.BONE)) drawParticle(p)
        drawFloatingTexts()
        drawGhost()
    }

    /** Placement preview that follows the finger while a card is selected. */
    private fun DrawScope.drawGhost() {
        val pos = hover ?: return
        val card = engine.selectedCard ?: return
        if (engine.result != null) return
        val valid = engine.isValidDeploy(card, pos) && engine.canAfford(card)
        val color = if (valid) Theme.player else Theme.enemy
        val c = pt(pos)
        val r = if (card.kind == CardKind.SPELL) len(card.radius) else len(1.1)
        val pulse = (0.5 + 0.5 * sin(engine.elapsed * 6)).toFloat()
        drawCircle(color.copy(alpha = 0.18f + 0.08f * pulse), r, c)
        drawCircle(color.copy(alpha = 0.9f), r, c, style = Stroke(2.5f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 4f), (engine.elapsed * 30).toFloat())))
        val cross = Path().apply {
            moveTo(c.x - len(0.5), c.y); lineTo(c.x + len(0.5), c.y)
            moveTo(c.x, c.y - len(0.5)); lineTo(c.x, c.y + len(0.5))
        }
        drawPath(cross, Color.White.copy(alpha = 0.9f), style = Stroke(2f, cap = StrokeCap.Round))
        if (card.kind == CardKind.TROOP) {
            val size = len(if (card.count > 1) 2.4 else 3.0)
            drawImage(
                art.image("units_${card.id}"), srcOffset = IntOffset.Zero, srcSize = IntSize(256, 256),
                dstOffset = IntOffset((c.x - size / 2).toInt(), (c.y - size * 0.85f).toInt()),
                dstSize = IntSize(size.toInt().coerceAtLeast(1), size.toInt().coerceAtLeast(1)),
                alpha = if (valid) 0.75f else 0.35f,
                filterQuality = FilterQuality.Medium,
            )
        }
    }

    private fun DrawScope.drawWater() {
        val t = engine.elapsed
        val top = len(Arena.RIVER_TOP); val bottom = len(Arena.RIVER_BOTTOM)
        clipRect(0f, top, size.width, bottom) {
            for (i in 0 until 4) {
                val baseY = top + (bottom - top) * (i + 0.5f) / 4
                val phase = (t * 1.6 + i * 1.3).toFloat()
                val wave = Path()
                wave.moveTo(-len(2), baseY)
                var x = -len(2)
                while (x < size.width + len(2)) {
                    val dy = sin(x / len(1.8) + phase) * len(0.12)
                    wave.quadraticBezierTo(x + len(0.9), baseY - len(0.2) + dy, x + len(1.8), baseY + dy)
                    x += len(1.8)
                }
                drawPath(wave, Color.White.copy(alpha = if (i % 2 == 0) 0.22f else 0.14f), style = Stroke(max(1f, len(0.06))))
            }
            for (i in 0 until 10) {
                val s = sin(t * 3 + i * 2.1).toFloat()
                if (s <= 0.6f) continue
                val x = len(i * 1.85 + 0.9)
                val y = top + (bottom - top) * (0.25 + 0.5 * hash(i, 12, 2)).toFloat()
                drawPath(Art.circle(x, y, len(0.07) * s), Color.White.copy(alpha = (0.8f * (s - 0.6f) * 2.5f).coerceIn(0f, 1f)))
            }
        }
    }

    private fun DrawScope.drawDeployHint() {
        val card = engine.selectedCard ?: return
        if (engine.result != null) return
        val color = if (engine.canAfford(card)) Theme.player else Theme.enemy
        val rect: Rect
        if (card.kind == CardKind.SPELL) {
            rect = Rect(0f, 0f, len(Arena.WIDTH), len(Arena.HEIGHT))
        } else {
            rect = Rect(0f, len(Arena.PLAYER_DEPLOY_MIN_Y), len(Arena.WIDTH), len(Arena.HEIGHT))
            drawRect(Color.Black.copy(alpha = 0.28f), Offset.Zero, Size(len(Arena.WIDTH), len(Arena.PLAYER_DEPLOY_MIN_Y)))
        }
        val pulse = (0.5 + 0.5 * sin(engine.elapsed * 4)).toFloat()
        drawRect(color.copy(alpha = 0.10f + 0.05f * pulse), rect.topLeft, rect.size)
        val grid = Path()
        var gx = 0.0
        while (gx <= Arena.WIDTH) { grid.moveTo(len(gx), rect.top); grid.lineTo(len(gx), rect.bottom); gx += 1 }
        var gy = floor(rect.top / scale).toDouble()
        while (gy <= Arena.HEIGHT) { val yy = max(rect.top, len(gy)); grid.moveTo(0f, yy); grid.lineTo(rect.right, yy); gy += 1 }
        drawPath(grid, color.copy(alpha = 0.18f), style = Stroke(1f))
        drawRect(color.copy(alpha = 0.75f), rect.deflate(1.5f).topLeft, rect.deflate(1.5f).size,
            style = Stroke(2.5f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 5f), (engine.elapsed * 20).toFloat())))
    }

    private fun DrawScope.drawTower(tower: Tower) {
        val r = len(tower.kind.radius) * (if (tower.kind == TowerKind.KEEP) 0.82f else 0.9f)
        val foot = pt(tower.pos)
        val center = Offset(foot.x, foot.y + r * 0.4f)
        if (tower.alive) {
            val name = "tower_${if (tower.kind == TowerKind.KEEP) "keep" else "guard"}_${if (tower.side == Side.PLAYER) "blue" else "red"}"
            renderedImage(art.image(name), Offset(center.x - r * 1.8f, center.y - r * 2.5f), Size(r * 3.6f, r * 3.6f), tower.hitFlash > 0)
        } else {
            tower(tower.kind, tower.side, center, r, false, tower.activated, false, engine.elapsed)
        }
        if (!tower.alive) return
        val barY = center.y + r * 1.0f + len(0.25)
        healthBar(Offset(center.x, barY), r * 2.1f, len(0.34), tower.hp / tower.kind.maxHp, tower.side)
        outlinedText(tower.hp.toInt().toString(), Offset(center.x, barY), px(3.6f), Color.White)
        if (!tower.activated && tower.kind == TowerKind.KEEP) {
            val bob = sin(engine.elapsed * 2).toFloat() * len(0.1)
            outlinedText("z", Offset(center.x + r * 1.3f, center.y - r * 1.5f + bob), len(0.5), Color.White.copy(alpha = 0.85f))
            outlinedText("z", Offset(center.x + r * 1.65f, center.y - r * 1.9f - bob), len(0.38), Color.White.copy(alpha = 0.7f))
        }
    }

    private fun DrawScope.drawUnit(unit: Troop) {
        val r = len(unit.radius) * (if (unit.card.id == "giant") 1.32f else if (unit.card.count > 1) 1.20f else 1.10f)
        val foot = pt(unit.pos)
        val spawn = min(1.0, unit.spawnAge / 0.35).toFloat()
        val pop = 1f + (1f - spawn) * 0.6f
        val shadowR = if (unit.card.flying) r * 0.9f else r * 1.1f
        softShadow(foot.x, foot.y, shadowR, shadowR * 0.4f, if (unit.card.flying) 0.25f else 0.35f)
        drawPath(Art.ellipse(foot.x, foot.y, shadowR, shadowR * 0.42f), Art.team(unit.side).copy(alpha = 0.85f), style = Stroke(len(0.10)))
        renderedUnit(art, unit, foot, r * pop)
        val barW = r * (if (unit.card.count > 1) 1.8f else 2.4f)
        val height = if (unit.card.id == "giant") 4.5f else 3.9f
        val lift = if (unit.card.flying) 1.6f else 0f
        healthBar(Offset(foot.x, foot.y - r * (height + lift)), barW, len(0.22), unit.hp / unit.card.hp, unit.side)
    }

    private fun DrawScope.drawProjectile(p: Projectile) {
        val start = pt(p.start); val end = pt(p.target)
        val prog = p.progress.toFloat()
        val flat = pt(p.pos)
        val dist = hypot(end.x - start.x, end.y - start.y)
        val arcH = dist * (if (p.kind == ProjectileKind.CANNON) 0.35f else if (p.kind == ProjectileKind.FIREBALL) 0.12f else 0.2f)
        val lift = sin(prog * PI).toFloat() * arcH
        val c = Offset(flat.x, flat.y - lift)
        drawPath(Art.ellipse(flat.x, flat.y, len(0.16), len(0.07)), Color.Black.copy(alpha = 0.25f))
        val ux = (end.x - start.x) / max(1f, dist); val uy = (end.y - start.y) / max(1f, dist)
        val slope = cos(prog * PI).toFloat() * PI.toFloat() * arcH / max(1f, dist)
        val angle = atan2(uy - slope, ux)
        when (p.kind) {
            ProjectileKind.ARROW, ProjectileKind.BOLT -> withTransform({
                translate(c.x, c.y)
                rotate(angle * 180f / PI.toFloat(), Offset.Zero)
            }) {
                val l = len(if (p.kind == ProjectileKind.BOLT) 0.8 else 0.7)
                val shaft = Art.segment(Offset(-l / 2, 0f), Offset(l / 2, 0f))
                drawPath(shaft, Art.outline, style = Stroke(len(0.14), cap = StrokeCap.Round))
                drawPath(shaft, if (p.kind == ProjectileKind.BOLT) Art.steel else Art.wood, style = Stroke(len(0.07), cap = StrokeCap.Round))
                drawPath(Art.polygon(l / 2 + len(0.12) to 0f, l / 2 - len(0.1) to -len(0.09), l / 2 - len(0.1) to len(0.09)), Art.steel)
                val feather = Art.team(p.side)
                drawPath(Art.polygon(-l / 2 to 0f, -l / 2 - len(0.12) to -len(0.11), -l / 2 + len(0.16) to -len(0.02)), feather)
                drawPath(Art.polygon(-l / 2 to 0f, -l / 2 - len(0.12) to len(0.11), -l / 2 + len(0.16) to len(0.02)), feather)
            }
            ProjectileKind.CANNON -> {
                ball(c.x, c.y, len(0.22), Art.steelDark, Art.outline, max(1f, len(0.05)))
                drawPath(Art.circle(c.x - len(0.07), c.y - len(0.07), len(0.05)), Color.White.copy(alpha = 0.6f))
            }
            ProjectileKind.FIREBALL -> {
                for (i in 1..3) {
                    val bx = c.x - cos(angle) * len(0.22) * i; val by = c.y - sin(angle) * len(0.22) * i
                    drawPath(Art.circle(bx, by, len(0.2) * (1 - i * 0.25f)), Art.fire.copy(alpha = 0.5f - i * 0.12f))
                }
                drawPath(Art.circle(c.x, c.y, len(0.4)), Art.radial(listOf(Art.fireCore, Art.fire.copy(alpha = 0f)), c, len(0.4)), blendMode = BlendMode.Plus)
                ball(c.x, c.y, len(0.2), Art.fireCore, Art.fire, max(1f, len(0.04)))
            }
        }
    }

    private fun DrawScope.drawEffect(e: SpellEffect) {
        val c = pt(e.pos)
        val rad = len(e.radius)
        val team = Art.team(e.side)
        val dash = Stroke(2f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 4f), (e.age * 30).toFloat()))
        when (e.kind) {
            EffectKind.DEPLOY -> {
                val p = e.progress.toFloat()
                val r = rad * (0.3f + 0.9f * p)
                drawPath(Art.ellipse(c.x, c.y, r, r * 0.55f), team.copy(alpha = 0.9f * (1 - p)), style = Stroke(max(1f, len(0.12)) * (1 - p) + 1))
                drawPath(Art.ellipse(c.x, c.y, r * 0.8f, r * 0.44f), team.copy(alpha = 0.35f * (1 - p)))
                val gc = Offset(c.x, c.y - len(0.6))
                drawPath(Art.circle(gc.x, gc.y, len(1.0) * (1 - p) + 0.1f), Art.radial(listOf(Color.White.copy(alpha = 0.7f * (1 - p)), Color.White.copy(alpha = 0f)), gc, len(1.0) * (1 - p) + 0.1f), blendMode = BlendMode.Plus)
            }
            EffectKind.METEOR -> {
                val delay = e.kind.impactDelay
                if (!e.landed) {
                    val f = (e.age / delay).toFloat()
                    drawPath(Art.ellipse(c.x, c.y, rad, rad * 0.6f), Art.fire.copy(alpha = 0.7f), style = dash)
                    drawPath(Art.ellipse(c.x, c.y, rad * f, rad * 0.6f * f), Color.Black.copy(alpha = 0.25f * f))
                    val from = Offset(c.x + len(6), c.y - len(14))
                    val m = Offset(from.x + (c.x - from.x) * f, from.y + (c.y - from.y) * f)
                    val dx = from.x - c.x; val dy = from.y - c.y
                    val l = max(1f, hypot(dx, dy))
                    val nx = dx / l; val ny = dy / l
                    val tail = Offset(m.x + nx * len(3.5), m.y + ny * len(3.5))
                    drawPath(Art.segment(m, tail), Brush.linearGradient(listOf(Art.fireCore, Art.fire.copy(alpha = 0f)), start = m, end = tail), style = Stroke(len(1.0), cap = StrokeCap.Round), blendMode = BlendMode.Plus)
                    drawPath(Art.circle(m.x, m.y, len(0.95)), Art.radial(listOf(Art.fireCore, Art.fire.copy(alpha = 0f)), m, len(0.95)), blendMode = BlendMode.Plus)
                    ball(m.x, m.y, len(0.55), Color(0.55f, 0.3f, 0.2f), Color(0.25f, 0.12f, 0.08f), max(1f, len(0.06)))
                    drawPath(Art.circle(m.x - len(0.15), m.y + len(0.1), len(0.12)), Art.fire)
                } else {
                    val f = min(1.0, (e.age - delay) / (e.kind.duration - delay)).toFloat()
                    val boom = min(1f, f * 2.2f)
                    drawPath(Art.ellipse(c.x, c.y, rad * 1.05f, rad * 0.62f), Color(0.12f, 0.08f, 0.06f).copy(alpha = 0.55f * (1 - f)))
                    val r = rad * (0.5f + 0.8f * boom)
                    val gc = Offset(c.x, c.y - len(0.3))
                    drawPath(Art.ellipse(gc.x, gc.y, r, r * 0.75f), Art.radial(listOf(Color.White.copy(alpha = 0.95f * (1 - boom)), Art.fireCore.copy(alpha = 0.9f * (1 - f)), Art.fire.copy(alpha = 0.6f * (1 - f)), Art.fire.copy(alpha = 0f)), gc, r), blendMode = BlendMode.Plus)
                    val ring = rad * (0.6f + 1.0f * boom)
                    drawPath(Art.ellipse(c.x, c.y, ring, ring * 0.6f), Art.fireCore.copy(alpha = 0.8f * (1 - boom)), style = Stroke(max(1f, len(0.25) * (1 - boom))), blendMode = BlendMode.Plus)
                    if (f < 0.5f) {
                        val flame = rad * 0.9f * (1 - f * 2)
                        for (i in 0 until 5) {
                            val a = i / 5.0 * PI * 2 + e.age * 2
                            val fx = c.x + cos(a).toFloat() * rad * 0.45f; val fy = c.y - len(0.2) + sin(a).toFloat() * rad * 0.25f
                            drawPath(Art.ellipse(fx, fy - flame * 0.4f, flame * 0.35f, flame * 0.7f), Art.radial(listOf(Art.fireCore, Art.fire.copy(alpha = 0f)), Offset(fx, fy), flame * 0.7f), blendMode = BlendMode.Plus)
                        }
                    }
                }
            }
            EffectKind.VOLLEY -> {
                val delay = e.kind.impactDelay
                if (!e.landed) {
                    val f = (e.age / delay).toFloat()
                    drawPath(Art.ellipse(c.x, c.y, rad, rad * 0.6f), Color.Cyan.copy(alpha = 0.7f), style = dash)
                    drawPath(Art.ellipse(c.x, c.y, rad, rad * 0.6f), Color.Cyan.copy(alpha = 0.12f))
                    for (i in 0 until 14) {
                        val a = hash(i, 21, e.id) * PI * 2
                        val rr = sqrt(hash(i, 22, e.id)) * rad
                        val land = Offset(c.x + (cos(a) * rr).toFloat(), c.y + (sin(a) * rr * 0.6).toFloat())
                        val stagger = hash(i, 23, e.id).toFloat() * 0.35f
                        val g = ((f - stagger) / (1 - stagger)).coerceIn(0f, 1f)
                        val from = Offset(land.x + len(1.2), land.y - len(12))
                        val m = Offset(from.x + (land.x - from.x) * g, from.y + (land.y - from.y) * g)
                        val s = Art.segment(m, Offset(m.x + len(0.09), m.y - len(0.9)))
                        drawPath(s, Art.outline, style = Stroke(len(0.11), cap = StrokeCap.Round))
                        drawPath(s, Art.wood, style = Stroke(len(0.05), cap = StrokeCap.Round))
                        drawPath(Art.polygon(m.x to m.y + len(0.12), m.x - len(0.07) to m.y - len(0.08), m.x + len(0.07) to m.y - len(0.06)), Art.steel)
                    }
                } else {
                    val f = min(1.0, (e.age - delay) / (e.kind.duration - delay)).toFloat()
                    val ring = rad * (0.7f + 0.5f * min(1f, f * 2))
                    drawPath(Art.ellipse(c.x, c.y, ring, ring * 0.6f), Color.Cyan.copy(alpha = 0.7f * (1 - min(1f, f * 2))), style = Stroke(max(1f, len(0.2) * (1 - f))), blendMode = BlendMode.Plus)
                    for (i in 0 until 14) {
                        val a = hash(i, 21, e.id) * PI * 2
                        val rr = sqrt(hash(i, 22, e.id)) * rad
                        val land = Offset(c.x + (cos(a) * rr).toFloat(), c.y + (sin(a) * rr * 0.6).toFloat())
                        val s = Art.segment(land, Offset(land.x + len(0.08), land.y - len(0.6)))
                        drawPath(s, Art.outline.copy(alpha = 1 - f), style = Stroke(len(0.1), cap = StrokeCap.Round))
                        drawPath(s, Art.wood.copy(alpha = 1 - f), style = Stroke(len(0.045), cap = StrokeCap.Round))
                        drawPath(Art.polygon(land.x + len(0.08) to land.y - len(0.6), land.x + len(0.16) to land.y - len(0.5), land.x + len(0.02) to land.y - len(0.45)), Color.White.copy(alpha = 1 - f))
                    }
                }
            }
            EffectKind.TOWER_FALL -> {
                val f = e.progress.toFloat()
                val r = rad * (0.4f + 0.9f * min(1f, f * 1.6f))
                drawPath(Art.ellipse(c.x, c.y, r, r * 0.6f), Art.radial(listOf(Color.White.copy(alpha = 0.8f * (1 - f)), Art.gold.copy(alpha = 0.4f * (1 - f)), Color.Transparent), c, r), blendMode = BlendMode.Plus)
                drawPath(Art.ellipse(c.x, c.y, r * 1.1f, r * 0.65f), Color(0.9f, 0.9f, 0.9f).copy(alpha = 0.7f * (1 - f)), style = Stroke(max(1f, len(0.3) * (1 - f))), blendMode = BlendMode.Plus)
            }
        }
    }

    private fun DrawScope.drawParticle(p: Particle) {
        val c = pt(p.pos)
        val life = p.life.toFloat()
        val s = len(p.size)
        when (p.kind) {
            ParticleKind.DUST, ParticleKind.SMOKE -> {
                val grow = if (p.kind == ParticleKind.SMOKE) 1.6f - life * 0.6f else 1.3f - life * 0.3f
                drawPath(Art.circle(c.x, c.y, s * grow), Art.radial(listOf(p.color.copy(alpha = 0.55f * life), p.color.copy(alpha = 0f)), c, s * grow))
            }
            ParticleKind.SPARK, ParticleKind.EMBER, ParticleKind.GLOW -> {
                drawPath(Art.circle(c.x, c.y, s * 2.2f), Art.radial(listOf(p.color.copy(alpha = 0.7f * life), p.color.copy(alpha = 0f)), c, s * 2.2f), blendMode = BlendMode.Plus)
                drawPath(Art.circle(c.x, c.y, s * (0.5f + 0.5f * life)), (if (p.kind == ParticleKind.EMBER) Art.fireCore else Color.White).copy(alpha = life))
            }
            ParticleKind.DEBRIS -> withTransform({
                translate(c.x, c.y)
                rotate((p.id + (1 - life) * 6) * 180f / PI.toFloat(), Offset.Zero)
            }) {
                shape(Art.rounded(Rect(-s / 2, -s / 2, s / 2, s * 0.3f), s * 0.15f), p.color.copy(alpha = min(1f, life * 2)), max(0.5f, s * 0.15f))
            }
            ParticleKind.BONE -> withTransform({
                translate(c.x, c.y)
                rotate((p.id + (1 - life) * 8) * 180f / PI.toFloat(), Offset.Zero)
            }) {
                val alpha = min(1f, life * 2)
                val b = Art.segment(Offset(-s, 0f), Offset(s, 0f))
                drawPath(b, Art.outline.copy(alpha = alpha), style = Stroke(s * 0.7f, cap = StrokeCap.Round))
                drawPath(b, Art.bone.copy(alpha = alpha), style = Stroke(s * 0.4f, cap = StrokeCap.Round))
                drawPath(Art.circle(-s, 0f, s * 0.3f), Art.bone.copy(alpha = alpha))
                drawPath(Art.circle(s, 0f, s * 0.3f), Art.bone.copy(alpha = alpha))
            }
            ParticleKind.LEAF -> drawPath(Art.ellipse(c.x, c.y, s, s * 0.5f), p.color.copy(alpha = life))
        }
    }

    private fun DrawScope.drawFloatingTexts() {
        val bounds = Rect(len(0.2), len(0.2), len(Arena.WIDTH - 0.2), len(Arena.HEIGHT - 0.2))
        val occupied = mutableListOf<Rect>()
        for (t in engine.floatingTexts.sortedByDescending { it.ttl }) {
            val maxFont = len(0.93)
            val measured = measurer.measure(t.text, TextStyle(fontSize = (maxFont / density).sp / fontScale, fontWeight = FontWeight.Black))
            val padding = 2 * max(1f, maxFont * 0.08f) + len(0.1)
            val width = measured.size.width + padding
            val height = measured.size.height + padding
            val origin = pt(t.pos)
            val x = (origin.x + len(if (t.victim == Side.PLAYER) 0.9 else -0.9)).coerceIn(bounds.left + width / 2, bounds.right - width / 2)
            val y = origin.y.coerceIn(bounds.top + height / 2, bounds.bottom - height / 2)
            for (row in 0 until 48) {
                val offset = if (row == 0) 0 else if (row % 2 == 1) -(row + 1) / 2 else row / 2
                val rect = Rect(x - width / 2, y + offset * height - height / 2, x + width / 2, y + offset * height + height / 2)
                if (rect.top < bounds.top || rect.bottom > bounds.bottom || occupied.any { it.overlaps(rect) }) continue
                occupied.add(rect)
                val life = t.life.toFloat()
                val pop = 1f + 0.5f * max(0f, life - 0.75f) * 4
                val alpha = min(1f, life * 3)
                outlinedText(t.text, rect.center, len(0.62) * pop, t.color.copy(alpha = alpha), Art.outline.copy(alpha = alpha))
                break
            }
        }
    }

    private fun DrawScope.outlinedText(text: String, at: Offset, sizePx: Float, color: Color, outline: Color = Art.outline) {
        val style = TextStyle(fontSize = (sizePx / density).sp / fontScale, fontWeight = FontWeight.Black)
        val layout = measurer.measure(text, style)
        val topLeft = Offset(at.x - layout.size.width / 2f, at.y - layout.size.height / 2f)
        val d = max(1f, sizePx * 0.08f)
        for ((dx, dy) in listOf(-d to 0f, d to 0f, 0f to -d, 0f to d, -d to -d, d to d, -d to d, d to -d)) {
            drawText(layout, outline, Offset(topLeft.x + dx, topLeft.y + dy))
        }
        drawText(layout, color, topLeft)
    }
}
