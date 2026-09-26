package com.dabit3.towertussle

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily

object Theme {
    val background = Color(0.07f, 0.10f, 0.20f)
    val panel = Color(0.13f, 0.17f, 0.30f)
    val accent = Color(1.0f, 0.72f, 0.20f)
    val orange = Color(0.95f, 0.5f, 0.1f)
    val elixir = Color(0.86f, 0.30f, 0.95f)
    val elixirDark = Color(0.6f, 0.15f, 0.8f)
    val player = Color(0.25f, 0.55f, 1.0f)
    val enemy = Color(0.95f, 0.30f, 0.30f)
    val grass = Color(0.36f, 0.62f, 0.30f)
    val grassDark = Color(0.31f, 0.56f, 0.26f)
    val river = Color(0.25f, 0.55f, 0.85f)
    val bridge = Color(0.62f, 0.45f, 0.25f)
    val darkText = Color(0.25f, 0.12f, 0.0f)
    val troopTop = Color(0.25f, 0.45f, 0.85f)
    val troopBottom = Color(0.12f, 0.25f, 0.55f)
    val spellTop = Color(0.55f, 0.25f, 0.75f)
    val spellBottom = Color(0.3f, 0.1f, 0.5f)
}

val LocalProfile = compositionLocalOf<PlayerProfile> { error("No profile") }

enum class Screen { HOME, CARDS, BATTLE, RESULTS }

class MainActivity : ComponentActivity() {
    private lateinit var audio: ArcadeAudio

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val profile = PlayerProfile(applicationContext)
        audio = ArcadeAudio(applicationContext).also { it.enabled = profile.soundEnabled }
        setContent {
            MaterialTheme(
                colorScheme = darkColorScheme(
                    primary = Theme.accent,
                    background = Theme.background,
                    surface = Theme.panel,
                    onBackground = Color.White,
                    onSurface = Color.White,
                ),
                typography = Typography(),
            ) {
                androidx.compose.runtime.CompositionLocalProvider(LocalProfile provides profile, LocalArcadeAudio provides audio) {
                    RootView()
                }
            }
        }
    }

    override fun onDestroy() {
        audio.release()
        super.onDestroy()
    }
}

@Composable
fun RootView() {
    val profile = LocalProfile.current
    var screen by remember { mutableStateOf(Screen.HOME) }
    var engine by remember { mutableStateOf<BattleEngine?>(null) }
    var lastResult by remember { mutableStateOf<MatchResult?>(null) }

    fun startBattle() {
        engine = BattleEngine(profile.deck.toList())
        screen = Screen.BATTLE
    }

    Box(Modifier.fillMaxSize().background(Theme.background).safeDrawingPadding()) {
        AnimatedContent(
            targetState = screen,
            transitionSpec = { fadeIn() togetherWith fadeOut() },
            label = "screen",
        ) { target ->
            when (target) {
                Screen.HOME -> HomeScreen(onBattle = { startBattle() }, onCards = { screen = Screen.CARDS })
                Screen.CARDS -> CardsScreen(onBack = { screen = Screen.HOME }, onBattle = { startBattle() })
                Screen.BATTLE -> engine?.let { e ->
                    BattleScreen(
                        engine = e,
                        onFinished = { result ->
                            profile.apply(result)
                            lastResult = result
                            screen = Screen.RESULTS
                        },
                        onQuit = { e.surrender() },
                    )
                }
                Screen.RESULTS -> lastResult?.let { r ->
                    ResultsScreen(result = r, onHome = { screen = Screen.HOME }, onCards = { screen = Screen.CARDS }, onRematch = { startBattle() })
                }
            }
        }
    }
}

val RoundedFont: FontFamily = FontFamily.SansSerif
