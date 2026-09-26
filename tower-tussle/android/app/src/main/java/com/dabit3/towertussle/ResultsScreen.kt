package com.dabit3.towertussle

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max

@Composable
fun ResultsScreen(result: MatchResult, onHome: () -> Unit, onCards: () -> Unit, onRematch: () -> Unit) {
    val profile = LocalProfile.current
    val audio = LocalArcadeAudio.current
    var revealed by remember { mutableStateOf(false) }
    LaunchedEffect(result) {
        audio?.play(when (result.outcome) {
            MatchOutcome.VICTORY -> "victory"
            MatchOutcome.DEFEAT -> "defeat"
            MatchOutcome.DRAW -> "tap"
        })
        revealed = true
    }
    val emblemScale by animateFloatAsState(if (revealed) 1f else 0.4f, spring(dampingRatio = Spring.DampingRatioMediumBouncy), label = "emblem")
    val titleScale by animateFloatAsState(if (revealed) 1f else 1.6f, spring(dampingRatio = Spring.DampingRatioMediumBouncy), label = "title")
    val fade by animateFloatAsState(if (revealed) 1f else 0f, label = "fade")

    val titleColor = when (result.outcome) {
        MatchOutcome.VICTORY -> Theme.accent
        MatchOutcome.DEFEAT -> Theme.enemy
        MatchOutcome.DRAW -> Color.White
    }
    val duration = String.format(Locale.US, "%d:%02d", result.durationSeconds / 60, result.durationSeconds % 60)
    val subtitle = when (result.outcome) {
        MatchOutcome.VICTORY -> if (result.playerCrowns == 3) "Three-crown win in $duration" else "You took the lead in $duration"
        MatchOutcome.DEFEAT ->
            if (result.enemyCrowns == 3 && result.playerCrowns == 0 && result.durationSeconds < Arena.REGULATION_SECONDS.toInt()) "The rival broke through in $duration"
            else "The rival edged it in $duration"
        MatchOutcome.DRAW -> "Dead even after $duration"
    }
    val previousLeague = League.forTrophies(max(0, profile.trophies - result.trophyDelta))
    val league = profile.league

    Box(Modifier.fillMaxSize()) {
        SceneryBackdrop(dim = if (result.outcome == MatchOutcome.DEFEAT) 0.6f else 0.2f)
        Column(Modifier.fillMaxSize()) {
            Column(
                Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 22.dp).padding(bottom = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                RenderedImage(
                    "emblem",
                    Modifier.padding(top = 12.dp).size(150.dp).scale(emblemScale).alpha(fade).rotate(if (result.outcome == MatchOutcome.DEFEAT) -12f else 0f),
                    muted = result.outcome == MatchOutcome.DEFEAT,
                )
                Column(Modifier.scale(titleScale).alpha(fade), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    DisplayText(result.outcome.title, 52.sp, color = titleColor, modifier = Modifier.testTag("resultTitle"))
                    Text(subtitle, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.8f), modifier = Modifier.testTag("resultSubtitle"))
                }

                Row(
                    Modifier.panel(cornerRadius = 22.dp).padding(horizontal = 24.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(30.dp), verticalAlignment = Alignment.CenterVertically,
                ) {
                    CrownColumn("You", result.playerCrowns, Theme.player)
                    DisplayText("VS", 20.sp, color = Color.White.copy(alpha = 0.5f))
                    CrownColumn("Rival", result.enemyCrowns, Theme.enemy)
                }

                Column(Modifier.fillMaxWidth().panel().padding(12.dp).testTag("progressPanel"), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        SectionLabel("League progress")
                        Spacer(Modifier.weight(1f))
                        if (previousLeague != league) {
                            val promoted = league.minTrophies > previousLeague.minTrophies
                            Text(
                                if (promoted) "PROMOTED!" else "DEMOTED", fontSize = 10.sp, letterSpacing = 1.sp, fontWeight = FontWeight.Black, color = Art.outline,
                                modifier = Modifier.clip(CircleShape).background(if (promoted) Theme.accent else Theme.enemy).padding(horizontal = 8.dp, vertical = 3.dp).testTag("leagueChange"),
                            )
                        }
                    }
                    LeagueBadge(profile.trophies)
                }

                Column(Modifier.fillMaxWidth().panel().padding(14.dp).testTag("rewardsPanel"), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    RewardRow(IconKind.TROPHY, "Trophies", result.trophyDelta, profile.trophies)
                    RewardRow(IconKind.COIN, "Gold", result.goldDelta, profile.gold)
                    if (profile.streak >= 2) {
                        Row(
                            Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
                            horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically,
                        ) {
                            IconView(IconKind.FLAME, 24.dp)
                            Text("Win streak", color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.weight(1f))
                            Text("${profile.streak}", color = Theme.accent, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                            Text(
                                if (profile.streak >= profile.bestStreak) "BEST" else "best ${profile.bestStreak}",
                                fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = Color.White.copy(alpha = 0.5f),
                            )
                        }
                    }
                }

                Row(
                    Modifier.fillMaxWidth().panel(cornerRadius = 16.dp).padding(12.dp).semantics(mergeDescendants = true) {}.testTag("tipPanel"),
                    horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top,
                ) {
                    IconView(IconKind.HELP, 22.dp)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        SectionLabel(if (result.outcome == MatchOutcome.DEFEAT) "Next time" else "Pro tip")
                        Text(BattleTips.tip(result.outcome, profile.matchesPlayed), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.85f))
                    }
                }
            }

            Column(
                Modifier.fillMaxWidth()
                    .background(Brush.verticalGradient(listOf(Theme.background.copy(alpha = 0f), Theme.background.copy(alpha = 0.9f))))
                    .padding(horizontal = 22.dp).padding(top = 6.dp, bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                ChunkyButton("REMATCH", onClick = onRematch, icon = IconKind.SWORDS, height = 58.dp, fontSize = 24.sp, modifier = Modifier.testTag("rematchButton"))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    ChunkyButton("EDIT DECK", onClick = onCards, icon = IconKind.CARDS, style = ChunkyStyle.SLATE, height = 46.dp, fontSize = 16.sp, modifier = Modifier.weight(1f).testTag("editDeckButton"))
                    ChunkyButton("HOME", onClick = onHome, style = ChunkyStyle.SLATE, height = 46.dp, fontSize = 16.sp, modifier = Modifier.weight(1f).testTag("homeButton"))
                }
            }
        }
    }
}

@Composable
private fun CrownColumn(label: String, count: Int, color: Color) {
    Column(
        Modifier.semantics(mergeDescendants = true) { contentDescription = "$label: $count crowns" },
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        CrownRow(count, color, 28.dp)
        Text(label.uppercase(), color = Color.White.copy(alpha = 0.75f), fontSize = 12.sp, fontWeight = FontWeight.Black)
    }
}

@Composable
private fun RewardRow(icon: IconKind, label: String, delta: Int, total: Int) {
    Row(
        Modifier.fillMaxWidth().semantics(mergeDescendants = true) {
            contentDescription = "$label ${if (delta >= 0) "plus" else "minus"} ${abs(delta)}, now $total"
        },
        horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically,
    ) {
        IconView(icon, 24.dp)
        Text(label, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.weight(1f))
        DisplayText(
            if (delta >= 0) "+$delta" else "$delta", 17.sp,
            color = if (delta > 0) Color(0xFF73E666) else if (delta < 0) Theme.enemy else Color.White.copy(alpha = 0.6f),
        )
        Text("→ $total", color = Color.White.copy(alpha = 0.55f), fontSize = 14.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.End, modifier = Modifier.widthIn(min = 56.dp))
    }
}
