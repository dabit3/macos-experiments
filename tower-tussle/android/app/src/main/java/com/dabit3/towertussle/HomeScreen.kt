package com.dabit3.towertussle

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(onBattle: () -> Unit, onCards: () -> Unit) {
    val profile = LocalProfile.current
    val audio = LocalArcadeAudio.current
    var showHelp by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val transition = rememberInfiniteTransition(label = "floating island")
    val hover by transition.animateFloat(2f, -6f, infiniteRepeatable(tween(3000), RepeatMode.Reverse), label = "hover")

    LaunchedEffect(Unit) { if (!profile.hasSeenTutorial) showHelp = true }

    Box(Modifier.fillMaxSize()) {
        SceneryBackdrop()
        Column(Modifier.fillMaxSize()) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically,
            ) {
                LeagueBadge(profile.trophies, Modifier.weight(1f), compact = true)
                StatPill(IconKind.COIN, "${profile.gold}", "Gold")
                IconButton(
                    if (profile.soundEnabled) IconKind.SOUND_ON else IconKind.SOUND_OFF,
                    if (profile.soundEnabled) "Sound on" else "Sound off",
                    onClick = {
                        val next = !profile.soundEnabled
                        profile.updateSound(next)
                        audio?.enabled = next
                    },
                    Modifier.testTag("soundButton"),
                )
                IconButton(IconKind.HELP, "How to play", onClick = { showHelp = true }, Modifier.testTag("helpButton"))
            }

            Column(
                Modifier.fillMaxWidth().padding(top = 12.dp).semantics(mergeDescendants = true) { contentDescription = "Tower Tussle" },
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    "THE SKY IS YOUR BATTLEFIELD", fontSize = 9.sp, letterSpacing = 3.sp,
                    fontWeight = FontWeight.Black, color = Color.Cyan.copy(alpha = 0.8f),
                    modifier = Modifier.padding(bottom = 6.dp),
                )
                DisplayText("TOWER", 48.sp, color = Color.White)
                DisplayText("TUSSLE", 56.sp, color = Theme.accent, modifier = Modifier.offset(y = (-12).dp))
            }

            RenderedImage("hero", Modifier.fillMaxWidth().weight(1f).offset(y = hover.dp))

            Column(
                Modifier.fillMaxWidth().padding(horizontal = 18.dp).padding(bottom = 14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                DeckStrip(profile.deck, profile.averageElixir, onClick = onCards)
                ChunkyButton("BATTLE", onClick = onBattle, icon = IconKind.SWORDS, height = 66.dp, fontSize = 28.sp, modifier = Modifier.testTag("battleButton"))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    ChunkyButton("CARDS", onClick = onCards, icon = IconKind.CARDS, style = ChunkyStyle.SLATE, height = 46.dp, fontSize = 16.sp, modifier = Modifier.weight(1f).testTag("cardsButton"))
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            "${profile.wins}W · ${profile.losses}L · ${profile.draws}D",
                            fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.75f),
                        )
                        Text(
                            if (profile.streak > 0) "${profile.streak} win streak" else if (profile.matchesPlayed == 0) "No battles yet" else "Best streak ${profile.bestStreak}",
                            fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = if (profile.streak > 0) Theme.accent else Color.White.copy(alpha = 0.55f),
                            modifier = Modifier.testTag("streakLabel"),
                        )
                    }
                }
            }
        }
    }

    if (showHelp) {
        ModalBottomSheet(
            onDismissRequest = { showHelp = false; profile.markTutorialSeen() },
            sheetState = sheetState,
            containerColor = Theme.background,
        ) {
            HowToPlaySheet(onDone = { showHelp = false; profile.markTutorialSeen() })
        }
    }
}
