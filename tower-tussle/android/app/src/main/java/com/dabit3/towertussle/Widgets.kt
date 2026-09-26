package com.dabit3.towertussle

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.Locale
import kotlin.math.sin

enum class IconKind { TROPHY, COIN, CROWN, ELIXIR, SWORDS, CARDS, CLOCK, HOME, HELP, SOUND_ON, SOUND_OFF, PAUSE, SWAP, FLAME, SHIELD }

/** Vector icon drawn with the shared Art helpers. */
@Composable
fun IconView(kind: IconKind, size: Dp, modifier: Modifier = Modifier) {
    Canvas(modifier.size(size)) {
        val c = Offset(this.size.width / 2, this.size.height / 2)
        val s = this.size.minDimension
        when (kind) {
            IconKind.TROPHY -> trophy(c, s)
            IconKind.COIN -> coin(c, s)
            IconKind.CROWN -> crown(c, s)
            IconKind.ELIXIR -> elixirDrop(c, s)
            IconKind.SWORDS -> swordsIcon(c, s)
            IconKind.CARDS -> cardsIcon(c, s)
            IconKind.CLOCK -> clock(c, s)
            IconKind.HOME -> {
                val house = Art.polygon(c.x - s * 0.4f to c.y + s * 0.4f, c.x - s * 0.4f to c.y, c.x to c.y - s * 0.42f, c.x + s * 0.4f to c.y, c.x + s * 0.4f to c.y + s * 0.4f)
                shape(house, Art.vertical(Art.stoneLight, Art.stoneDark, house.getBounds()), s * 0.07f)
                drawPath(Art.rounded(Art.rect(c.x - s * 0.1f, c.y + s * 0.1f, s * 0.2f, s * 0.3f), s * 0.05f), Art.woodDark)
            }
            IconKind.HELP -> {
                ball(c.x, c.y, s * 0.42f, Color(0.42f, 0.72f, 1.0f), Color(0.15f, 0.42f, 0.9f), s * 0.06f)
                val q = Path().apply {
                    moveTo(c.x - s * 0.14f, c.y - s * 0.12f)
                    cubicTo(c.x - s * 0.14f, c.y - s * 0.32f, c.x + s * 0.16f, c.y - s * 0.32f, c.x + s * 0.14f, c.y - s * 0.1f)
                    cubicTo(c.x + s * 0.12f, c.y + s * 0.04f, c.x, c.y + s * 0.02f, c.x, c.y + s * 0.14f)
                }
                drawPath(q, Color.White, style = Stroke(s * 0.09f, cap = StrokeCap.Round))
                drawCircle(Color.White, s * 0.06f, Offset(c.x, c.y + s * 0.3f))
            }
            IconKind.SOUND_ON, IconKind.SOUND_OFF -> {
                val horn = Art.polygon(c.x - s * 0.42f to c.y - s * 0.14f, c.x - s * 0.2f to c.y - s * 0.14f, c.x + s * 0.05f to c.y - s * 0.36f, c.x + s * 0.05f to c.y + s * 0.36f, c.x - s * 0.2f to c.y + s * 0.14f, c.x - s * 0.42f to c.y + s * 0.14f)
                shape(horn, Color.White, s * 0.06f)
                if (kind == IconKind.SOUND_ON) {
                    for (i in 1..2) {
                        val r = s * (0.18f + i * 0.12f)
                        val arc = Path().apply { addArc(Rect(c.x + s * 0.02f - r, c.y - r, c.x + s * 0.02f + r, c.y + r), -40f, 80f) }
                        drawPath(arc, Color.White, style = Stroke(s * 0.07f, cap = StrokeCap.Round))
                    }
                } else {
                    val x = Path().apply {
                        moveTo(c.x + s * 0.16f, c.y - s * 0.16f); lineTo(c.x + s * 0.42f, c.y + s * 0.16f)
                        moveTo(c.x + s * 0.42f, c.y - s * 0.16f); lineTo(c.x + s * 0.16f, c.y + s * 0.16f)
                    }
                    drawPath(x, Theme.enemy, style = Stroke(s * 0.09f, cap = StrokeCap.Round))
                }
            }
            IconKind.PAUSE -> {
                for (dx in listOf(-0.2f, 0.2f)) {
                    shape(Art.rounded(Art.rect(c.x + s * dx - s * 0.1f, c.y - s * 0.34f, s * 0.2f, s * 0.68f), s * 0.06f), Color.White, s * 0.06f)
                }
            }
            IconKind.SWAP -> {
                val top = Path().apply { moveTo(c.x - s * 0.36f, c.y - s * 0.16f); lineTo(c.x + s * 0.2f, c.y - s * 0.16f) }
                val bottom = Path().apply { moveTo(c.x + s * 0.36f, c.y + s * 0.16f); lineTo(c.x - s * 0.2f, c.y + s * 0.16f) }
                drawPath(top, Color.White, style = Stroke(s * 0.09f, cap = StrokeCap.Round))
                drawPath(bottom, Color.White, style = Stroke(s * 0.09f, cap = StrokeCap.Round))
                drawPath(Art.polygon(c.x + s * 0.18f to c.y - s * 0.34f, c.x + s * 0.4f to c.y - s * 0.16f, c.x + s * 0.18f to c.y + s * 0.02f), Color.White)
                drawPath(Art.polygon(c.x - s * 0.18f to c.y + s * 0.34f, c.x - s * 0.4f to c.y + s * 0.16f, c.x - s * 0.18f to c.y - s * 0.02f), Color.White)
            }
            IconKind.FLAME -> {
                val flame = Path().apply {
                    moveTo(c.x, c.y - s * 0.44f)
                    cubicTo(c.x + s * 0.34f, c.y - s * 0.1f, c.x + s * 0.34f, c.y + s * 0.2f, c.x, c.y + s * 0.44f)
                    cubicTo(c.x - s * 0.34f, c.y + s * 0.2f, c.x - s * 0.3f, c.y - s * 0.02f, c.x - s * 0.08f, c.y - s * 0.16f)
                    cubicTo(c.x - s * 0.06f, c.y - s * 0.28f, c.x - s * 0.06f, c.y - s * 0.36f, c.x, c.y - s * 0.44f)
                }
                shape(flame, Art.vertical(Art.fireCore, Art.fire, flame.getBounds()), s * 0.06f)
                drawPath(Art.ellipse(c.x, c.y + s * 0.2f, s * 0.12f, s * 0.18f), Art.fireCore)
            }
            IconKind.SHIELD -> {
                val shield = Path().apply {
                    moveTo(c.x - s * 0.38f, c.y - s * 0.34f); lineTo(c.x + s * 0.38f, c.y - s * 0.34f)
                    lineTo(c.x + s * 0.38f, c.y + s * 0.02f)
                    cubicTo(c.x + s * 0.38f, c.y + s * 0.28f, c.x + s * 0.1f, c.y + s * 0.4f, c.x, c.y + s * 0.46f)
                    cubicTo(c.x - s * 0.1f, c.y + s * 0.4f, c.x - s * 0.38f, c.y + s * 0.28f, c.x - s * 0.38f, c.y + s * 0.02f)
                    close()
                }
                shape(shield, Art.vertical(Color(0.55f, 0.78f, 1.0f), Theme.player, shield.getBounds()), s * 0.06f)
                drawPath(Art.rounded(Art.rect(c.x - s * 0.05f, c.y - s * 0.22f, s * 0.1f, s * 0.4f), s * 0.04f), Art.gold)
                drawPath(Art.rounded(Art.rect(c.x - s * 0.2f, c.y - s * 0.1f, s * 0.4f, s * 0.1f), s * 0.04f), Art.gold)
            }
        }
    }
}

/** Round icon-only button in the same beveled style as ChunkyButton. */
@Composable
fun IconButton(
    icon: IconKind,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    style: ChunkyStyle = ChunkyStyle.SLATE,
    size: Dp = 40.dp,
) {
    val interaction = remember { MutableInteractionSource() }
    val audio = LocalArcadeAudio.current
    val pressed by interaction.collectIsPressedAsState()
    Box(
        modifier.size(size, size + 4.dp)
            .semantics { role = Role.Button; contentDescription = label }
            .clickable(interactionSource = interaction, indication = null, onClick = { audio?.play("tap"); onClick() }),
    ) {
        Box(Modifier.size(size).offset(y = if (pressed) 2.dp else 4.dp).clip(CircleShape).background(style.edge))
        Box(
            Modifier.size(size).offset(y = if (pressed) 2.dp else 0.dp).clip(CircleShape)
                .background(Brush.verticalGradient(listOf(style.top, style.bottom)))
                .border(2.dp, Art.outline.copy(alpha = 0.9f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            IconView(icon, size * 0.55f)
        }
    }
}

/** Heavy display text with a dark outline and drop shadow. */
@Composable
fun DisplayText(
    text: String,
    size: TextUnit,
    color: Color = Color.White,
    modifier: Modifier = Modifier,
    outline: Color = Art.outline,
    textAlign: TextAlign? = null,
    maxLines: Int = Int.MAX_VALUE,
) {
    val strokeWidth = size.value * 0.16f
    val fill = if (textAlign != null) Modifier.fillMaxWidth() else Modifier
    Box(modifier) {
        Text(
            text, fontSize = size, fontWeight = FontWeight.Black, color = outline, textAlign = textAlign, maxLines = maxLines,
            overflow = TextOverflow.Clip, modifier = fill,
            style = TextStyle(
                drawStyle = Stroke(width = strokeWidth, join = StrokeJoin.Round),
                shadow = Shadow(Color.Black.copy(alpha = 0.5f), Offset(0f, size.value * 0.12f), size.value * 0.1f),
            ),
        )
        Text(text, fontSize = size, fontWeight = FontWeight.Black, color = color, textAlign = textAlign, maxLines = maxLines, overflow = TextOverflow.Clip, modifier = fill)
    }
}

enum class ChunkyStyle(val top: Color, val bottom: Color, val edge: Color, val text: Color) {
    GOLD(Color(1.0f, 0.86f, 0.35f), Color(0.98f, 0.62f, 0.12f), Color(0.62f, 0.34f, 0.04f), Color(0.3f, 0.14f, 0.0f)),
    BLUE(Color(0.42f, 0.72f, 1.0f), Color(0.15f, 0.42f, 0.9f), Color(0.06f, 0.2f, 0.5f), Color.White),
    GREEN(Color(0.55f, 0.9f, 0.4f), Color(0.22f, 0.62f, 0.2f), Color(0.08f, 0.32f, 0.08f), Color.White),
    RED(Color(1.0f, 0.55f, 0.5f), Color(0.85f, 0.2f, 0.22f), Color(0.45f, 0.06f, 0.08f), Color.White),
    SLATE(Color(0.5f, 0.56f, 0.7f), Color(0.24f, 0.28f, 0.42f), Color(0.1f, 0.12f, 0.22f), Color.White),
}

/** Beveled 3D-style button used across the menus. */
@Composable
fun ChunkyButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: IconKind? = null,
    style: ChunkyStyle = ChunkyStyle.GOLD,
    height: Dp = 60.dp,
    fontSize: TextUnit = 24.sp,
) {
    val interaction = remember { MutableInteractionSource() }
    val audio = LocalArcadeAudio.current
    val pressed by interaction.collectIsPressedAsState()
    val lift = if (pressed) 2.dp else 6.dp
    Box(
        modifier
            .fillMaxWidth()
            .height(height + 6.dp)
            .padding(top = if (pressed) 4.dp else 0.dp)
            .semantics { role = Role.Button }
            .clickable(interactionSource = interaction, indication = null, onClick = { audio?.play("tap"); onClick() }),
    ) {
        val shape = RoundedCornerShape(16.dp)
        Box(Modifier.fillMaxWidth().height(height).offset(y = lift).clip(shape).background(style.edge))
        Box(
            Modifier.fillMaxWidth().height(height).shadow(6.dp, shape, clip = false).clip(shape)
                .background(Brush.verticalGradient(listOf(style.top, style.bottom)))
                .drawBehind {
                    val w = size.width; val h = size.height
                    drawRoundRect(Color.White.copy(alpha = 0.18f), Offset(8.dp.toPx(), 5.dp.toPx()), Size(w - 16.dp.toPx(), 22.dp.toPx()), CornerRadius(12.dp.toPx()))
                    drawRoundRect(
                        Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.55f), Color.White.copy(alpha = 0f)), endY = h / 2),
                        Offset(3.dp.toPx(), 3.dp.toPx()), Size(w - 6.dp.toPx(), h - 6.dp.toPx()), CornerRadius(13.dp.toPx()), style = Stroke(2.dp.toPx()),
                    )
                }
                .border(2.5.dp, Art.outline.copy(alpha = 0.9f), shape),
            contentAlignment = Alignment.Center,
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                if (icon != null) IconView(icon, with(LocalDensity.current) { (fontSize.toPx() * 1.25f).toDp() })
                Text(
                    title, fontSize = fontSize, fontWeight = FontWeight.Black, color = style.text,
                    style = TextStyle(shadow = Shadow(if (style == ChunkyStyle.GOLD) Color.White.copy(alpha = 0.35f) else Color.Black.copy(alpha = 0.5f), Offset(0f, if (style == ChunkyStyle.GOLD) 1.5f else -1.5f), 0f)),
                )
            }
        }
    }
}

/** Layered dark panel with a light inset stroke. */
fun Modifier.panel(cornerRadius: Dp = 18.dp, tint: Color = Theme.panel): Modifier = this
    .shadow(6.dp, RoundedCornerShape(cornerRadius), clip = false)
    .clip(RoundedCornerShape(cornerRadius))
    .background(Brush.verticalGradient(listOf(tint.copy(alpha = 0.97f), Theme.background.copy(alpha = 0.98f))))
    .drawBehind {
        val r = cornerRadius.toPx()
        drawRoundRect(
            Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.25f), Color.White.copy(alpha = 0.03f))),
            Offset(2.dp.toPx(), 2.dp.toPx()), Size(size.width - 4.dp.toPx(), size.height - 4.dp.toPx()), CornerRadius(r - 2.dp.toPx()), style = Stroke(1.5.dp.toPx()),
        )
    }
    .border(2.dp, Art.outline.copy(alpha = 0.9f), RoundedCornerShape(cornerRadius))

@Composable
fun ElixirBadge(cost: Int, size: Dp = 24.dp, modifier: Modifier = Modifier) {
    Box(modifier.size(size * 1.15f).semantics { contentDescription = "$cost elixir" }, contentAlignment = Alignment.Center) {
        IconView(IconKind.ELIXIR, size * 1.15f)
        Text(
            "$cost", color = Color.White, fontWeight = FontWeight.Black, fontSize = (size.value * 0.6f).sp,
            modifier = Modifier.offset(y = size * 0.08f),
            style = TextStyle(shadow = Shadow(Color.Black.copy(alpha = 0.8f), Offset(1.5f, 1.5f), 0f)),
        )
    }
}

/** Framed card: illustration, bevel, cost badge and name plaque. */
@Composable
fun CardFrame(
    card: CardDef,
    modifier: Modifier = Modifier,
    selected: Boolean = false,
    affordable: Boolean = true,
    showName: Boolean = true,
    compact: Boolean = false,
) {
    val frameColors = when {
        card.kind == CardKind.SPELL -> listOf(Color(0.85f, 0.65f, 1.0f), Color(0.5f, 0.25f, 0.75f))
        card.count > 1 || card.cost <= 3 -> listOf(Color(0.86f, 0.88f, 0.95f), Color(0.45f, 0.5f, 0.62f))
        else -> listOf(Color(1.0f, 0.9f, 0.5f), Color(0.75f, 0.5f, 0.1f))
    }
    val desaturate = remember(affordable) {
        if (affordable) null else ColorFilter.colorMatrix(ColorMatrix().apply { setToSaturation(0.15f) })
    }
    BoxWithConstraints(modifier.aspectRatio(0.78f)) {
        val w = maxWidth
        val radius = w * 0.14f
        val border = (w * 0.05f).coerceAtLeast(2.dp)
        Box(Modifier.fillMaxSize().colorFiltered(desaturate).alpha(if (affordable) 1f else 0.75f)) {
            Box(
                Modifier.fillMaxSize()
                    .shadow(if (selected) 10.dp else 3.dp, RoundedCornerShape(radius), ambientColor = if (selected) Theme.accent else Color.Black, spotColor = if (selected) Theme.accent else Color.Black)
                    .clip(RoundedCornerShape(radius))
                    .background(Brush.linearGradient(frameColors))
                    .border((w * 0.03f).coerceAtLeast(1.5.dp), Art.outline, RoundedCornerShape(radius)),
            ) {
                Column(Modifier.fillMaxSize().padding(border)) {
                    RenderedImage(
                        "card_${card.id}",
                        Modifier.fillMaxWidth().weight(1f).clip(RoundedCornerShape(radius * 0.6f))
                            .border(1.dp, Art.outline.copy(alpha = 0.8f), RoundedCornerShape(radius * 0.6f)),
                        fill = true,
                    )
                    if (showName) {
                        Box(
                            Modifier.fillMaxWidth().padding(top = border * 0.6f).height((w * 0.24f).coerceAtLeast(12.dp))
                                .clip(RoundedCornerShape(radius * 0.4f)).background(Art.outline.copy(alpha = 0.75f)),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                card.name.uppercase(), color = Color.White, fontWeight = FontWeight.Black,
                                fontSize = (w.value * 0.12f).coerceAtLeast(7f).sp, maxLines = 1, overflow = TextOverflow.Clip,
                                style = TextStyle(shadow = Shadow(Color.Black.copy(alpha = 0.9f), Offset(1f, 1f), 0f)),
                                modifier = Modifier.padding(horizontal = 3.dp),
                            )
                        }
                    }
                }
            }
            if (selected) {
                Box(Modifier.fillMaxSize().border(3.dp, Theme.accent, RoundedCornerShape(radius)))
            }
            ElixirBadge(card.cost, if (compact) w * 0.34f else w * 0.3f, Modifier.offset(x = -w * 0.08f, y = -w * 0.08f))
        }
    }
}

/** Renders the content through a color filter (used to grey out unaffordable cards). */
private fun Modifier.colorFiltered(filter: ColorFilter?): Modifier = if (filter == null) this else drawWithContent {
    drawIntoCanvas { it.saveLayer(Rect(0f, 0f, size.width, size.height), Paint().apply { colorFilter = filter }) }
    drawContent()
    drawIntoCanvas { it.restore() }
}

/** Painted backdrop for the menu screens: sky, hills and a castle skyline. */
@Composable
private fun LegacySceneryBackdrop(modifier: Modifier = Modifier, dim: Float = 0f) {
    Canvas(modifier.fillMaxSize()) {
        val w = size.width; val h = size.height
        drawRect(Brush.verticalGradient(listOf(Color(0.09f, 0.15f, 0.36f), Color(0.2f, 0.4f, 0.75f), Color(0.55f, 0.72f, 0.9f)), endY = h * 0.7f))
        drawPath(Art.circle(w * 0.72f, h * 0.32f, w * 0.55f), Art.radial(listOf(Art.gold.copy(alpha = 0.35f), Art.gold.copy(alpha = 0f)), Offset(w * 0.72f, h * 0.32f), w * 0.55f), blendMode = BlendMode.Plus)
        for (i in 0 until 40) {
            val x = ((i * 0.618) % 1.0).toFloat() * w
            val y = ((i * 0.2713 + 0.1) % 1.0).toFloat() * h * 0.35f
            drawPath(Art.circle(x, y, 0.8f + (i % 3) * 0.5f), Color.White.copy(alpha = 0.5f + (i % 4) * 0.12f))
        }
        for ((cx, cy, s) in listOf(Triple(0.2f, 0.22f, 1.0f), Triple(0.75f, 0.15f, 0.7f), Triple(0.5f, 0.32f, 0.55f))) {
            val c = Offset(w * cx, h * cy)
            val r = w * 0.09f * s
            for ((dx, dy, rr) in listOf(Triple(-1.1f, 0.2f, 0.7f), Triple(0f, 0f, 1f), Triple(1.1f, 0.25f, 0.75f), Triple(0.5f, -0.4f, 0.6f))) {
                drawPath(Art.circle(c.x + r * dx, c.y + r * dy, r * rr), Color.White.copy(alpha = 0.18f))
            }
        }
        fun hills(baseY: Float, amp: Float, color: Color, seed: Float) {
            val p = Path()
            p.moveTo(0f, h); p.lineTo(0f, baseY)
            var x = 0f
            while (x <= w) {
                val y = baseY - amp * (0.5f + 0.5f * sin(x / w * 5 + seed)) - amp * 0.3f * sin(x / w * 13 + seed * 2)
                p.lineTo(x, y); x += 8f
            }
            p.lineTo(w, h); p.close()
            drawPath(p, color)
        }
        hills(h * 0.62f, h * 0.08f, Color(0.18f, 0.32f, 0.5f), 1f)
        hills(h * 0.68f, h * 0.07f, Color(0.16f, 0.36f, 0.36f), 3f)
        val baseY = h * 0.7f
        val silhouette = Color(0.1f, 0.16f, 0.3f).copy(alpha = 0.9f)
        for ((cx, cw, ch) in listOf(Triple(0.12f, 0.09f, 0.12f), Triple(0.3f, 0.06f, 0.08f), Triple(0.5f, 0.12f, 0.16f), Triple(0.7f, 0.06f, 0.09f), Triple(0.88f, 0.09f, 0.12f))) {
            val r = Rect(w * cx - w * cw / 2, baseY - h * ch, w * cx + w * cw / 2, baseY + 4)
            drawRect(silhouette, r.topLeft, r.size)
            for (i in 0 until 3) {
                val bx = r.left + r.width * (i + 0.5f) / 3
                drawRect(silhouette, Offset(bx - r.width * 0.12f, r.top - h * 0.015f), Size(r.width * 0.24f, h * 0.02f))
            }
            drawRect(silhouette, Offset(r.center.x - 1, r.top - h * 0.05f), Size(2f, h * 0.05f))
            drawPath(Art.polygon(r.center.x to r.top - h * 0.05f, r.center.x + w * 0.03f to r.top - h * 0.04f, r.center.x to r.top - h * 0.03f), if (cx == 0.5f) Art.gold else Theme.enemy)
            drawPath(Art.rounded(Art.rect(r.center.x - r.width * 0.1f, r.top + r.height * 0.3f, r.width * 0.2f, r.height * 0.18f), r.width * 0.1f), Art.gold.copy(alpha = 0.85f))
        }
        drawRect(silhouette, Offset(0f, baseY - 2), Size(w, h - baseY + 2))
        drawRect(Brush.verticalGradient(listOf(Color(0.2f, 0.42f, 0.24f), Color(0.08f, 0.2f, 0.14f)), startY = baseY, endY = h), Offset(0f, baseY), Size(w, h - baseY))
        for (i in 0 until 60) {
            val x = ((i * 0.731) % 1.0).toFloat() * w
            val y = baseY + ((i * 0.457) % 1.0).toFloat() * (h - baseY)
            val s = 3 + (y - baseY) / (h - baseY) * 5
            val tuft = Path().apply {
                moveTo(x - s, y); lineTo(x - s * 0.4f, y - s * 1.5f)
                moveTo(x, y); lineTo(x, y - s * 2)
                moveTo(x + s, y); lineTo(x + s * 0.4f, y - s * 1.5f)
            }
            drawPath(tuft, Color(0.3f, 0.6f, 0.3f).copy(alpha = 0.5f), style = Stroke(1.5f, cap = StrokeCap.Round))
        }
        if (dim > 0) drawRect(Color.Black.copy(alpha = dim))
    }
}

@Composable
fun StatPill(icon: IconKind, value: String, label: String, modifier: Modifier = Modifier) {
    Row(
        modifier
            .panel(cornerRadius = 22.dp)
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .semantics(mergeDescendants = true) { contentDescription = "$label: $value" },
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconView(icon, 26.dp)
        Column {
            DisplayText(value, 17.sp)
            Text(label, fontSize = 11.sp, color = Color.White.copy(alpha = 0.65f), fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
fun CrownRow(count: Int, color: Color, size: Dp) {
    Row(Modifier.semantics { contentDescription = "$count crowns" }, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        for (i in 0 until 3) {
            Canvas(Modifier.size(size)) {
                val c = Offset(this.size.width / 2, this.size.height / 2)
                crown(c, this.size.minDimension, color = color, dim = i >= count)
            }
        }
    }
}

@Composable
fun ElixirBar(value: Double, max: Double, modifier: Modifier = Modifier) {
    val fraction = (value / max).toFloat().coerceIn(0f, 1f)
    Row(
        modifier.fillMaxWidth().semantics { contentDescription = "Elixir ${value.toInt()} of ${max.toInt()}" },
        horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically,
    ) {
        IconView(IconKind.ELIXIR, 26.dp)
        Box(Modifier.weight(1f).height(22.dp)) {
            Canvas(Modifier.fillMaxSize()) {
                val h = size.height; val w = size.width
                val r = CornerRadius(h / 2)
                drawRoundRect(Art.outline.copy(alpha = 0.9f), Offset.Zero, Size(w, h), r)
                drawRoundRect(Color(0.12f, 0.08f, 0.18f), Offset(2f, 2f), Size(w - 4, h - 4), r)
                val fillW = (w - 4) * fraction
                if (fillW > 0) {
                    drawRoundRect(Brush.verticalGradient(listOf(Color(0.95f, 0.55f, 1.0f), Theme.elixir, Theme.elixirDark)), Offset(2f, 2f), Size(fillW.coerceAtLeast(h - 4), h - 4), r)
                    drawRoundRect(Color.White.copy(alpha = 0.3f), Offset(6f, 4f), Size((fillW - 8).coerceAtLeast(1f), (h - 4) * 0.35f), r)
                }
                for (i in 1 until max.toInt()) {
                    val x = 2 + (w - 4) * i / max.toFloat()
                    drawRect(Art.outline.copy(alpha = 0.55f), Offset(x - 0.75f, 2f), Size(1.5f, h - 4))
                }
            }
            DisplayText("${value.toInt()}", 13.sp, modifier = Modifier.align(Alignment.Center))
        }
    }
}

// Progression

/** Small uppercase caption used to title sections and groups of controls. */
@Composable
fun SectionLabel(text: String, color: Color = Color.White.copy(alpha = 0.7f), modifier: Modifier = Modifier) {
    Text(
        text.uppercase(), fontSize = 10.sp, letterSpacing = 2.sp, fontWeight = FontWeight.Black, color = color, modifier = modifier,
        style = TextStyle(shadow = Shadow(Color.Black.copy(alpha = 0.7f), Offset(0f, 1.5f), 0f)),
    )
}

@Composable
fun ProgressTrack(progress: Double, color: Color = Theme.accent, height: Dp = 10.dp, modifier: Modifier = Modifier) {
    val animated by animateFloatAsState(progress.toFloat().coerceIn(0f, 1f), label = "progress")
    Canvas(modifier.fillMaxWidth().height(height)) {
        val h = size.height; val w = size.width
        val r = CornerRadius(h / 2)
        drawRoundRect(Color.Black.copy(alpha = 0.45f), Offset.Zero, Size(w, h), r)
        val fillW = (w * animated).coerceAtLeast(h)
        drawRoundRect(Brush.verticalGradient(listOf(color.copy(alpha = 0.95f), color.copy(alpha = 0.65f))), Offset.Zero, Size(fillW, h), r)
        drawRoundRect(Color.White.copy(alpha = 0.35f), Offset(4f, 2f), Size((fillW - 8).coerceAtLeast(1f), h * 0.3f), r)
        drawRoundRect(Art.outline, Offset.Zero, Size(w, h), r, style = Stroke(1.5.dp.toPx()))
    }
}

/** League name, trophy count and progress to the next tier. */
@Composable
fun LeagueBadge(trophies: Int, modifier: Modifier = Modifier, compact: Boolean = false) {
    val league = League.forTrophies(trophies)
    val next = league.next
    Row(
        modifier.panel(cornerRadius = 22.dp, tint = Color(0.16f, 0.2f, 0.36f))
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .semantics(mergeDescendants = true) { contentDescription = "$trophies trophies, ${league.name}" }
            .testTag("leagueBadge"),
        horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically,
    ) {
        IconView(IconKind.TROPHY, if (compact) 28.dp else 34.dp)
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("$trophies", fontSize = if (compact) 17.sp else 20.sp, fontWeight = FontWeight.Black, color = Color.White)
                Text(league.name.uppercase(), fontSize = 10.sp, letterSpacing = 1.sp, fontWeight = FontWeight.Black, color = league.color, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            ProgressTrack(league.progress(trophies), league.color, 7.dp)
            if (next != null && !compact) {
                Text("${next.minTrophies - trophies} to ${next.name}", fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.65f))
            }
        }
    }
}

/** Miniature battle deck: eight portraits plus the average elixir, tappable to edit. */
@Composable
fun DeckStrip(deck: List<String>, averageElixir: Double, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val audio = LocalArcadeAudio.current
    Column(
        modifier.fillMaxWidth().panel(cornerRadius = 18.dp)
            .clickable { audio?.play("tap"); onClick() }
            .padding(horizontal = 12.dp, vertical = 9.dp)
            .semantics(mergeDescendants = true) {
                role = Role.Button
                contentDescription = "Battle deck, average elixir ${String.format(Locale.US, "%.1f", averageElixir)}. Edit deck"
            }
            .testTag("deckStrip"),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SectionLabel("Battle deck")
            Spacer(Modifier.weight(1f))
            IconView(IconKind.ELIXIR, 14.dp)
            Text(String.format(Locale.US, " %.1f avg", averageElixir), fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.85f))
            Text("EDIT ›", fontSize = 11.sp, fontWeight = FontWeight.Black, color = Theme.accent, modifier = Modifier.padding(start = 8.dp))
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            for (id in deck) CardFrame(Cards.byId(id), Modifier.weight(1f).padding(top = 4.dp, start = 3.dp), showName = false, compact = true)
        }
    }
}

enum class HintTone { NEUTRAL, ACTIVE, WARNING }

/** Persistent instruction strip that tells the player what to do next. */
@Composable
fun HintBanner(step: String?, text: String, modifier: Modifier = Modifier, tone: HintTone = HintTone.NEUTRAL, onCancel: (() -> Unit)? = null) {
    val audio = LocalArcadeAudio.current
    val color = when (tone) {
        HintTone.NEUTRAL -> Color.White.copy(alpha = 0.6f)
        HintTone.ACTIVE -> Theme.accent
        HintTone.WARNING -> Theme.enemy
    }
    Row(
        modifier.fillMaxWidth()
            .panel(cornerRadius = 16.dp, tint = if (tone == HintTone.NEUTRAL) Theme.panel else color.copy(alpha = 0.35f))
            .then(if (tone == HintTone.NEUTRAL) Modifier else Modifier.border(2.dp, color.copy(alpha = 0.8f), RoundedCornerShape(16.dp)))
            .padding(horizontal = 12.dp, vertical = 9.dp)
            .testTag("hintBanner"),
        horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically,
    ) {
        if (step != null) {
            Box(Modifier.size(24.dp).clip(CircleShape).background(color), contentAlignment = Alignment.Center) {
                Text(step, fontSize = 12.sp, fontWeight = FontWeight.Black, color = Art.outline)
            }
        }
        Text(text, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Color.White, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        if (onCancel != null) {
            Text(
                "CANCEL", fontSize = 11.sp, fontWeight = FontWeight.Black, color = Color.White,
                modifier = Modifier.clip(CircleShape).background(Color.White.copy(alpha = 0.15f))
                    .border(1.dp, Color.White.copy(alpha = 0.4f), CircleShape)
                    .clickable { audio?.play("tap"); onCancel() }
                    .padding(horizontal = 10.dp, vertical = 6.dp)
                    .semantics { role = Role.Button }
                    .testTag("cancelSwapButton"),
            )
        }
    }
}

/** Three-step explainer shown on first launch and from the help button. */
@Composable
fun HowToPlaySheet(onDone: () -> Unit) {
    data class Step(val icon: IconKind, val title: String, val body: String)
    val steps = listOf(
        Step(IconKind.CARDS, "Pick a card", "Tap a card in your hand. Each card costs elixir, which refills over time."),
        Step(IconKind.SHIELD, "Drop it on your side", "Tap or drag on your half of the arena to deploy. Spells can land anywhere, even on enemy towers."),
        Step(IconKind.CROWN, "Take the towers", "Destroy guard towers for crowns. Break the keep for an instant 3-crown win. Three minutes, then sudden-death overtime."),
    )
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 24.dp).testTag("howToPlay"),
        verticalArrangement = Arrangement.spacedBy(14.dp), horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        DisplayText("HOW TO PLAY", 30.sp, color = Theme.accent)
        for ((index, step) in steps.withIndex()) {
            Row(
                Modifier.fillMaxWidth().panel(cornerRadius = 16.dp).padding(12.dp),
                horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.Top,
            ) {
                Box(Modifier.size(52.dp)) {
                    Box(Modifier.size(52.dp).clip(CircleShape).background(Theme.panel).border(2.dp, Art.outline, CircleShape), contentAlignment = Alignment.Center) {
                        IconView(step.icon, 30.dp)
                    }
                    Box(Modifier.align(Alignment.TopEnd).size(18.dp).clip(CircleShape).background(Theme.accent), contentAlignment = Alignment.Center) {
                        Text("${index + 1}", fontSize = 11.sp, fontWeight = FontWeight.Black, color = Art.outline)
                    }
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(step.title.uppercase(), fontSize = 15.sp, fontWeight = FontWeight.Black, color = Color.White)
                    Text(step.body, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = Color.White.copy(alpha = 0.78f))
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            IconView(IconKind.ELIXIR, 18.dp)
            Text("Elixir doubles in the last minute. Surrender any time from the pause menu.", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.7f))
        }
        ChunkyButton("LET'S TUSSLE", onClick = onDone, icon = IconKind.SWORDS, height = 56.dp, fontSize = 22.sp, modifier = Modifier.testTag("tutorialDoneButton"))
    }
}

/** Battle phase chip: shows OVERTIME / 2x ELIXIR under the timer. */
@Composable
fun PhaseChip(text: String, color: Color, modifier: Modifier = Modifier) {
    Text(
        text, fontSize = 10.sp, letterSpacing = 1.sp, fontWeight = FontWeight.Black, color = Art.outline,
        modifier = modifier.clip(CircleShape).background(color).border(1.5.dp, Art.outline, CircleShape).padding(horizontal = 8.dp, vertical = 3.dp),
    )
}
