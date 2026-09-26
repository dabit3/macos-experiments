package com.dabit3.towertussle

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import java.util.Locale
import kotlin.math.ceil
import kotlin.math.min

@Composable
fun BattleScreen(engine: BattleEngine, onFinished: (MatchResult) -> Unit, onQuit: () -> Unit) {
    val profile = LocalProfile.current
    val audio = LocalArcadeAudio.current
    var paused by remember { mutableStateOf(false) }
    var hover by remember { mutableStateOf<Vec?>(null) }

    LaunchedEffect(engine) {
        while (engine.result == null) {
            withFrameNanos { if (!paused) engine.frame(it) }
        }
        hover = null
        delay(1400)
        engine.result?.let(onFinished)
    }

    fun setPaused(value: Boolean) {
        if (engine.result != null) return
        paused = value
        if (!value) engine.resetClock()
    }

    engine.version

    Box(Modifier.fillMaxSize()) {
        SceneryBackdrop(dim = 0.45f)
        Column(Modifier.fillMaxSize().padding(horizontal = 10.dp).padding(bottom = 6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Hud(engine, onPause = { audio?.play("tap"); setPaused(true) })

            BoxWithConstraints(Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.Center) {
                val density = LocalDensity.current
                val widthPx = with(density) { maxWidth.toPx() }
                val heightPx = with(density) { maxHeight.toPx() }
                val scale = min(widthPx / Arena.WIDTH, heightPx / Arena.HEIGHT).toFloat()
                val arenaW = with(density) { (Arena.WIDTH * scale).toFloat().toDp() }
                val arenaH = with(density) { (Arena.HEIGHT * scale).toFloat().toDp() }
                val selected = engine.selectedCard
                Box(
                    Modifier
                        .size(arenaW, arenaH)
                        .shadow(10.dp, RoundedCornerShape(12.dp), clip = false)
                        .clip(RoundedCornerShape(12.dp))
                        .border(2.5.dp, Art.outline.copy(alpha = 0.9f), RoundedCornerShape(12.dp))
                        .pointerInput(engine, scale) {
                            awaitEachGesture {
                                val down = awaitFirstDown()
                                var last = down.position
                                if (engine.selectedCard != null && engine.result == null) hover = Vec(last.x / scale.toDouble(), last.y / scale.toDouble())
                                while (true) {
                                    val event = awaitPointerEvent()
                                    val change = event.changes.firstOrNull { it.id == down.id } ?: break
                                    last = change.position
                                    if (engine.selectedCard != null && engine.result == null) hover = Vec(last.x / scale.toDouble(), last.y / scale.toDouble())
                                    if (!change.pressed) break
                                }
                                hover = null
                                val before = engine.playerElixir
                                engine.deployAtTap(Vec(last.x / scale.toDouble(), last.y / scale.toDouble()))
                                if (engine.playerElixir < before) audio?.play("deploy")
                            }
                        }
                        .semantics {
                            contentDescription = if (selected == null) "Arena. Pick a card first" else "Arena. Tap your half to deploy ${selected.name}"
                        }
                        .testTag("arena"),
                ) {
                    ArenaCanvas(engine, scale, Modifier.fillMaxSize(), hover)
                }
                engine.announcement?.let { text ->
                    DisplayText(
                        text, 18.sp, color = Theme.accent,
                        modifier = Modifier.panel(cornerRadius = 20.dp, tint = Color(0.2f, 0.12f, 0.3f))
                            .padding(horizontal = 18.dp, vertical = 8.dp).testTag("announcement"),
                    )
                }
            }

            HandBar(engine)
        }

        engine.result?.let { r ->
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.35f)), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    DisplayText(
                        r.outcome.title, 56.sp,
                        color = when (r.outcome) { MatchOutcome.VICTORY -> Theme.accent; MatchOutcome.DEFEAT -> Theme.enemy; MatchOutcome.DRAW -> Color.White },
                    )
                    Row(
                        Modifier.panel(cornerRadius = 20.dp).padding(horizontal = 16.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically,
                    ) {
                        CrownRow(r.playerCrowns, Theme.player, 24.dp)
                        Text("vs", fontSize = 14.sp, fontWeight = FontWeight.Black, color = Color.White.copy(alpha = 0.7f))
                        CrownRow(r.enemyCrowns, Theme.enemy, 24.dp)
                    }
                }
            }
        }

        AnimatedVisibility(paused && engine.result == null, enter = fadeIn(), exit = fadeOut()) {
            PauseMenu(
                engine = engine,
                soundEnabled = profile.soundEnabled,
                onResume = { setPaused(false) },
                onToggleSound = {
                    val next = !profile.soundEnabled
                    profile.updateSound(next)
                    audio?.enabled = next
                },
                onSurrender = { setPaused(false); onQuit() },
            )
        }
    }
}

@Composable
private fun PauseMenu(engine: BattleEngine, soundEnabled: Boolean, onResume: () -> Unit, onToggleSound: () -> Unit, onSurrender: () -> Unit) {
    val s = engine.remainingSeconds
    Box(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.55f))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onResume)
            .testTag("pauseMenu"),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            Modifier.padding(horizontal = 24.dp).widthIn(max = 340.dp).panel(cornerRadius = 24.dp)
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
                .padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            DisplayText("PAUSED", 40.sp)
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
                CrownRow(engine.crowns(Side.PLAYER), Theme.player, 22.dp)
                Text(String.format(Locale.US, "%d:%02d", s / 60, s % 60), fontSize = 22.sp, fontWeight = FontWeight.Black, color = Color.White)
                CrownRow(engine.crowns(Side.ENEMY), Theme.enemy, 22.dp)
            }
            ChunkyButton("RESUME", onClick = onResume, icon = IconKind.SWORDS, height = 58.dp, fontSize = 22.sp, modifier = Modifier.testTag("resumeButton"))
            ChunkyButton(
                if (soundEnabled) "SOUND ON" else "SOUND OFF", onClick = onToggleSound,
                icon = if (soundEnabled) IconKind.SOUND_ON else IconKind.SOUND_OFF, style = ChunkyStyle.SLATE, height = 48.dp, fontSize = 17.sp,
                modifier = Modifier.testTag("pauseSoundButton"),
            )
            ChunkyButton("SURRENDER", onClick = onSurrender, style = ChunkyStyle.RED, height = 48.dp, fontSize = 17.sp, modifier = Modifier.testTag("surrenderButton"))
            Text("Surrendering counts as a 3-crown defeat.", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.6f))
        }
    }
}

@Composable
private fun Hud(engine: BattleEngine, onPause: () -> Unit) {
    val s = engine.remainingSeconds
    val phase: Pair<String, Color>? = when {
        engine.isOvertime -> "OVERTIME · NEXT TOWER WINS" to Theme.enemy
        engine.isDoubleElixir -> "2× ELIXIR" to Theme.elixir
        else -> null
    }
    Row(Modifier.fillMaxWidth().padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        IconButton(IconKind.PAUSE, "Pause. Opens the pause menu with resume, sound and surrender", onClick = onPause, Modifier.testTag("quitButton"))
        Spacer(Modifier.weight(1f))
        Column(
            Modifier.panel(cornerRadius = 20.dp).padding(horizontal = 14.dp, vertical = 5.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    SectionLabel("Rival", color = Theme.enemy.copy(alpha = 0.9f))
                    Box(Modifier.testTag("enemyCrowns")) { CrownRow(engine.crowns(Side.ENEMY), Theme.enemy, 18.dp) }
                }
                DisplayText(
                    String.format(Locale.US, "%d:%02d", s / 60, s % 60),
                    26.sp,
                    color = if (engine.isOvertime) Theme.enemy else if (engine.isDoubleElixir) Color(0.95f, 0.65f, 1.0f) else Color.White,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.width(78.dp).semantics { contentDescription = "$s seconds left" }.testTag("timer"),
                )
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    SectionLabel("You", color = Theme.player.copy(alpha = 0.9f))
                    Box(Modifier.testTag("playerCrowns")) { CrownRow(engine.crowns(Side.PLAYER), Theme.player, 18.dp) }
                }
            }
            if (phase != null) PhaseChip(phase.first, phase.second, Modifier.testTag("phaseChip"))
        }
        Spacer(Modifier.weight(1f))
        Spacer(Modifier.size(40.dp))
    }
}

@Composable
private fun HandBar(engine: BattleEngine) {
    val audio = LocalArcadeAudio.current
    Column(
        Modifier.fillMaxWidth().panel(cornerRadius = 18.dp).padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        DeployHint(engine)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Bottom) {
            val next = Cards.byId(engine.nextCard)
            Column(Modifier.width(48.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text("NEXT", fontSize = 9.sp, fontWeight = FontWeight.Black, color = Color.White.copy(alpha = 0.7f))
                HandCard(
                    next, selected = false, affordable = true, small = true,
                    modifier = Modifier.semantics { contentDescription = "Next card ${next.name}" }.testTag("nextCard"),
                )
            }
            for ((index, id) in engine.hand.withIndex()) {
                val card = Cards.byId(id)
                val selected = engine.selectedHandIndex == index
                val affordable = engine.canAfford(card)
                HandCard(
                    card, selected = selected, affordable = affordable, small = false,
                    modifier = Modifier.weight(1f)
                        .semantics {
                            contentDescription = "${card.name}, ${card.cost} elixir" + (if (selected) ", selected" else "") +
                                (if (affordable) ". Select, then tap the arena to deploy" else ". Not enough elixir yet")
                            role = Role.Button
                        }
                        .testTag("hand-$index"),
                    onClick = { audio?.play("tap"); engine.selectHand(index) },
                )
            }
        }
        ElixirBar(engine.playerElixir, Arena.MAX_ELIXIR, Modifier.testTag("elixirBar"))
    }
}

/** One-line helper naming the selected card and exactly what to do with it. */
@Composable
private fun DeployHint(engine: BattleEngine) {
    val card = engine.selectedCard
    Row(
        Modifier.fillMaxWidth().height(18.dp).testTag("deployHint"),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically,
    ) {
        if (card != null) {
            val short = ceil(card.cost - engine.playerElixir).toInt()
            ElixirBadge(card.cost, 16.dp)
            Text(card.name.uppercase(), fontSize = 12.sp, fontWeight = FontWeight.Black, color = Theme.accent, maxLines = 1)
            Text("·", color = Color.White.copy(alpha = 0.4f), fontSize = 12.sp)
            Text(
                when {
                    short > 0 -> "Need $short more elixir"
                    card.kind == CardKind.SPELL -> "Tap anywhere, even on enemy towers"
                    else -> "Tap or drag on your half to deploy"
                },
                fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis,
                color = if (short > 0) Color(1.0f, 0.6f, 0.55f) else Color.White,
            )
        } else {
            Text(
                if (engine.isDoubleElixir) "Elixir is doubled. Pick a card and push!" else "Pick a card, then tap the arena",
                fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.75f), maxLines = 1,
            )
        }
    }
}

@Composable
fun HandCard(card: CardDef, selected: Boolean, affordable: Boolean, small: Boolean, modifier: Modifier = Modifier, onClick: (() -> Unit)? = null) {
    val lift by animateDpAsState(if (selected) (-10).dp else 0.dp, label = "lift")
    Box(
        modifier
            .offset(y = lift)
            .padding(top = 6.dp, start = 4.dp)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
    ) {
        CardFrame(card, selected = selected, affordable = affordable, showName = !small, compact = small)
    }
}
