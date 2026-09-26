package com.dabit3.towertussle

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.Locale
import kotlinx.coroutines.delay

/** Step-based deck editing: browse, or hold one card while the player picks its counterpart. */
sealed class EditMode {
    data object Browse : EditMode()
    data class Replacing(val deckCard: String) : EditMode()
    data class Adding(val collectionCard: String) : EditMode()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CardsScreen(onBack: () -> Unit, onBattle: () -> Unit) {
    val profile = LocalProfile.current
    val audio = LocalArcadeAudio.current
    var mode by remember { mutableStateOf<EditMode>(EditMode.Browse) }
    var detailCard by remember { mutableStateOf<CardDef?>(null) }
    var showResetConfirm by remember { mutableStateOf(false) }
    var toast by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(toast) {
        if (toast != null) {
            delay(2200)
            toast = null
        }
    }

    fun performSwap(deckCard: String, collectionCard: String) {
        profile.swap(deckCard, collectionCard)
        mode = EditMode.Browse
        audio?.play("deploy")
        toast = "${Cards.byId(collectionCard).name} is in, ${Cards.byId(deckCard).name} is out."
    }

    fun tapDeck(id: String) {
        audio?.play("tap")
        when (val m = mode) {
            EditMode.Browse -> detailCard = Cards.byId(id)
            is EditMode.Replacing -> if (m.deckCard == id) detailCard = Cards.byId(id) else mode = EditMode.Replacing(id)
            is EditMode.Adding -> performSwap(id, m.collectionCard)
        }
    }

    fun tapCollection(id: String) {
        audio?.play("tap")
        when (val m = mode) {
            EditMode.Browse -> detailCard = Cards.byId(id)
            is EditMode.Adding -> if (m.collectionCard == id) detailCard = Cards.byId(id) else mode = EditMode.Adding(id)
            is EditMode.Replacing -> performSwap(m.deckCard, id)
        }
    }

    Box(Modifier.fillMaxSize()) {
        SceneryBackdrop(dim = 0.35f)
        Column(Modifier.fillMaxSize()) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(
                    Modifier.panel(cornerRadius = 18.dp).clickable { audio?.play("tap"); onBack() }
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                        .semantics { role = Role.Button; contentDescription = "Back to home" }
                        .testTag("backButton"),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    IconView(IconKind.HOME, 18.dp)
                    DisplayText("HOME", 15.sp)
                }
                Spacer(Modifier.weight(1f))
                DisplayText("DECK", 26.sp, color = Theme.accent)
                Spacer(Modifier.weight(1f))
                DisplayText(
                    "RESET", 15.sp,
                    modifier = Modifier.panel(cornerRadius = 18.dp, tint = Color(0.45f, 0.2f, 0.15f))
                        .clickable { audio?.play("tap"); showResetConfirm = true }
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                        .semantics { role = Role.Button; contentDescription = "Reset to starter deck" }
                        .testTag("resetDeckButton"),
                )
            }

            Column(
                Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 14.dp).padding(bottom = 12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                val activeToast = toast
                when (val m = mode) {
                    EditMode.Browse -> if (activeToast != null) HintBanner(null, activeToast, tone = HintTone.ACTIVE)
                    else HintBanner("i", "Tap any card for stats and to swap it in or out of your deck.")
                    is EditMode.Replacing -> HintBanner("2", "Pick a collection card to replace ${Cards.byId(m.deckCard).name}.", tone = HintTone.ACTIVE) { mode = EditMode.Browse }
                    is EditMode.Adding -> HintBanner("2", "Pick a deck card to swap out for ${Cards.byId(m.collectionCard).name}.", tone = HintTone.ACTIVE) { mode = EditMode.Browse }
                }

                SectionHeader("Battle deck", "${profile.deck.size} / 8") {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.testTag("avgElixir")) {
                        IconView(IconKind.ELIXIR, 16.dp)
                        Text(String.format(Locale.US, "%.1f avg", profile.averageElixir), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                    Text("${profile.troopCount} troops · ${profile.spellCount} spells", color = Color.White.copy(alpha = 0.6f), fontSize = 11.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 8.dp))
                }

                Box(Modifier.fillMaxWidth().panel(cornerRadius = 18.dp, tint = Color(0.12f, 0.2f, 0.38f)).padding(10.dp)) {
                    CardGrid(profile.deck.toList()) { id ->
                        val m = mode
                        CardTile(
                            card = Cards.byId(id),
                            selected = m is EditMode.Replacing && m.deckCard == id,
                            dimmed = m is EditMode.Replacing && m.deckCard != id,
                            hint = when (m) {
                                EditMode.Browse -> "Shows stats and lets you swap it out"
                                is EditMode.Replacing -> if (m.deckCard == id) "Selected to be replaced" else "Select this card to replace instead"
                                is EditMode.Adding -> "Replace with ${Cards.byId(m.collectionCard).name}"
                            },
                            modifier = Modifier.testTag("deck-$id"),
                            onClick = { tapDeck(id) },
                        )
                    }
                }

                SectionHeader("Collection", "${profile.collection.size} on the bench") {}

                Box(Modifier.fillMaxWidth().panel(cornerRadius = 18.dp).padding(10.dp)) {
                    CardGrid(profile.collection) { id ->
                        val m = mode
                        CardTile(
                            card = Cards.byId(id),
                            selected = m is EditMode.Adding && m.collectionCard == id,
                            dimmed = m is EditMode.Adding && m.collectionCard != id,
                            hint = when (m) {
                                EditMode.Browse -> "Shows stats and lets you add it to your deck"
                                is EditMode.Adding -> if (m.collectionCard == id) "Selected to add" else "Select this card to add instead"
                                is EditMode.Replacing -> "Swap in for ${Cards.byId(m.deckCard).name}"
                            },
                            modifier = Modifier.testTag("collection-$id"),
                            onClick = { tapCollection(id) },
                        )
                    }
                }
            }

            Box(
                Modifier.fillMaxWidth()
                    .background(Brush.verticalGradient(listOf(Color.Transparent, Theme.background.copy(alpha = 0.95f), Theme.background)))
                    .padding(horizontal = 18.dp).padding(top = 8.dp, bottom = 10.dp),
            ) {
                ChunkyButton("BATTLE WITH THIS DECK", onClick = onBattle, icon = IconKind.SWORDS, height = 54.dp, fontSize = 19.sp, modifier = Modifier.testTag("deckBattleButton"))
            }
        }
    }

    detailCard?.let { card ->
        val inDeck = card.id in profile.deck
        ModalBottomSheet(onDismissRequest = { detailCard = null }, containerColor = Theme.background) {
            CardDetailSheet(card, inDeck) {
                audio?.play("tap")
                detailCard = null
                mode = if (inDeck) EditMode.Replacing(card.id) else EditMode.Adding(card.id)
            }
        }
    }

    if (showResetConfirm) {
        AlertDialog(
            onDismissRequest = { showResetConfirm = false },
            title = { Text("Reset to the starter deck?") },
            text = { Text("Your current eight cards will be replaced with the starter deck.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showResetConfirm = false
                        profile.resetDeck()
                        mode = EditMode.Browse
                        toast = "Starter deck restored"
                    },
                    modifier = Modifier.testTag("confirmResetButton"),
                ) { Text("Reset deck", color = Theme.enemy, fontWeight = FontWeight.Bold) }
            },
            dismissButton = { TextButton(onClick = { showResetConfirm = false }) { Text("Keep my deck") } },
        )
    }
}

@Composable
private fun SectionHeader(title: String, count: String, trailing: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        SectionLabel(title, color = Color.White)
        Text(count, color = Color.White.copy(alpha = 0.55f), fontSize = 11.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 8.dp))
        Spacer(Modifier.weight(1f))
        trailing()
    }
}

@Composable
private fun CardGrid(ids: List<String>, tile: @Composable (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        for (row in ids.chunked(4)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                for (id in row) Box(Modifier.weight(1f)) { tile(id) }
                repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
fun CardTile(card: CardDef, selected: Boolean, dimmed: Boolean, hint: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val scale by animateFloatAsState(if (selected) 1.06f else 1f, label = "tile scale")
    val alpha by animateFloatAsState(if (dimmed) 0.45f else 1f, label = "tile alpha")
    Box(
        modifier
            .scale(scale)
            .alpha(alpha)
            .padding(top = 6.dp, start = 6.dp)
            .clickable(onClick = onClick)
            .semantics(mergeDescendants = true) { contentDescription = "${card.name}, ${card.cost} elixir. $hint"; role = Role.Button },
    ) {
        CardFrame(card, selected = selected)
        if (selected) {
            Box(
                Modifier.align(Alignment.BottomEnd).offset(x = 6.dp, y = 6.dp).size(30.dp).clip(CircleShape)
                    .background(Theme.accent).border(2.dp, Art.outline, CircleShape),
                contentAlignment = Alignment.Center,
            ) { IconView(IconKind.SWAP, 20.dp) }
        }
    }
}

@Composable
fun CardDetailSheet(card: CardDef, inDeck: Boolean, onAction: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(24.dp).padding(bottom = 24.dp).testTag("cardDetail"), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            CardFrame(card, modifier = Modifier.width(96.dp).padding(top = 8.dp, start = 6.dp), showName = false)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                DisplayText(card.name.uppercase(), 26.sp, color = Theme.accent)
                Text(
                    if (card.kind == CardKind.SPELL) "Spell" else if (card.flying) "Flying troop" else "Ground troop",
                    color = Color.White.copy(alpha = 0.7f), fontSize = 15.sp, fontWeight = FontWeight.Bold,
                )
                Text(
                    if (inDeck) "IN YOUR DECK" else "ON THE BENCH", fontSize = 10.sp, letterSpacing = 1.sp, fontWeight = FontWeight.Black,
                    color = if (inDeck) Art.outline else Color.White,
                    modifier = Modifier.clip(CircleShape).background(if (inDeck) Theme.accent else Color.White.copy(alpha = 0.18f)).padding(horizontal = 8.dp, vertical = 3.dp),
                )
            }
            ElixirBadge(card.cost, 40.dp)
        }
        Text(card.description, color = Color.White.copy(alpha = 0.85f), fontSize = 16.sp)
        HorizontalDivider(color = Color.White.copy(alpha = 0.2f))
        if (card.kind == CardKind.TROOP) {
            StatRow("Hitpoints", "${card.hp.toInt()}" + if (card.count > 1) " ×${card.count}" else "")
            StatRow("Damage", "${card.damage.toInt()}")
            StatRow("Hit speed", String.format(Locale.US, "%.1fs", card.hitSpeed))
            StatRow("Range", if (card.isMelee) "Melee" else String.format(Locale.US, "%.1f", card.range))
            StatRow("Speed", when {
                card.speed >= 3.4 -> "Very fast"
                card.speed >= 2.8 -> "Fast"
                card.speed >= 1.8 -> "Medium"
                else -> "Slow"
            })
            if (card.buildingsOnly) StatRow("Targets", "Buildings only")
            StatRow("Deploy", "Your half of the arena")
        } else {
            StatRow("Damage", "${card.damage.toInt()}")
            StatRow("Tower damage", "${(card.damage * Arena.TOWER_SPELL_FACTOR).toInt()}")
            StatRow("Radius", String.format(Locale.US, "%.1f", card.radius))
            StatRow("Deploy", "Anywhere in the arena")
        }
        Spacer(Modifier.size(4.dp))
        ChunkyButton(
            if (inDeck) "SWAP OUT" else "ADD TO DECK", onClick = onAction, icon = IconKind.SWAP,
            style = if (inDeck) ChunkyStyle.SLATE else ChunkyStyle.GOLD, height = 54.dp, fontSize = 20.sp,
            modifier = Modifier.testTag("cardActionButton"),
        )
        Text(
            if (inDeck) "Next, pick the collection card that takes its place." else "Next, pick which deck card it replaces.",
            color = Color.White.copy(alpha = 0.65f), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun StatRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth()) {
        Text(label, color = Color.White.copy(alpha = 0.7f), fontSize = 15.sp)
        Spacer(Modifier.weight(1f))
        Text(value, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold)
    }
}
