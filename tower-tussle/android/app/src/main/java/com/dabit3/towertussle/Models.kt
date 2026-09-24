package com.dabit3.towertussle

import androidx.compose.ui.graphics.Color
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

enum class Side {
    PLAYER, ENEMY;

    val opposite: Side get() = if (this == PLAYER) ENEMY else PLAYER
}

enum class CardKind { TROOP, SPELL }

data class CardDef(
    val id: String,
    val name: String,
    val cost: Int,
    val kind: CardKind,
    val emoji: String,
    val count: Int,
    val hp: Double,
    val damage: Double,
    val range: Double,
    val hitSpeed: Double,
    val speed: Double,
    val flying: Boolean,
    val buildingsOnly: Boolean,
    val radius: Double,
    val description: String,
) {
    val isMelee: Boolean get() = range <= 1.2

    companion object {
        fun troop(
            id: String, name: String, cost: Int, emoji: String, count: Int = 1,
            hp: Double, damage: Double, range: Double, hitSpeed: Double, speed: Double,
            flying: Boolean = false, buildingsOnly: Boolean = false, description: String,
        ) = CardDef(id, name, cost, CardKind.TROOP, emoji, count, hp, damage, range, hitSpeed, speed, flying, buildingsOnly, 0.0, description)

        fun spell(id: String, name: String, cost: Int, emoji: String, damage: Double, radius: Double, description: String) =
            CardDef(id, name, cost, CardKind.SPELL, emoji, 0, 0.0, damage, 0.0, 0.0, 0.0, false, false, radius, description)
    }
}

object Cards {
    val all: List<CardDef> = listOf(
        CardDef.troop("knight", "Knight", 3, "🛡️", hp = 1400.0, damage = 160.0, range = 1.0, hitSpeed = 1.1, speed = 2.0,
            description = "A sturdy melee fighter. Good at soaking damage."),
        CardDef.troop("archers", "Archers", 3, "🏹", count = 2, hp = 250.0, damage = 90.0, range = 5.0, hitSpeed = 1.0, speed = 2.0,
            description = "A pair of ranged shooters. Can hit flying troops."),
        CardDef.troop("giant", "Colossus", 5, "🗿", hp = 3300.0, damage = 210.0, range = 1.0, hitSpeed = 1.5, speed = 1.3,
            buildingsOnly = true, description = "Slow, huge, and only interested in towers."),
        CardDef.troop("duelist", "Duelist", 4, "⚔️", hp = 1100.0, damage = 550.0, range = 1.0, hitSpeed = 1.6, speed = 3.0,
            description = "Fast, and hits like a truck. Fragile in a crowd."),
        CardDef.troop("sharpshooter", "Sharpshooter", 4, "🎯", hp = 600.0, damage = 180.0, range = 6.0, hitSpeed = 1.1, speed = 2.0,
            description = "Long range. Picks off troops before they arrive."),
        CardDef.troop("gremlins", "Gremlins", 2, "👺", count = 3, hp = 170.0, damage = 100.0, range = 0.8, hitSpeed = 1.1, speed = 3.5,
            description = "Three very fast, very rude little fighters."),
        CardDef.troop("bones", "Bone Brigade", 3, "💀", count = 6, hp = 70.0, damage = 70.0, range = 0.8, hitSpeed = 1.0, speed = 3.0,
            description = "Six skeletons. Overwhelms single targets, melts to spells."),
        CardDef.troop("whelp", "Whelp", 4, "🐲", hp = 1000.0, damage = 130.0, range = 3.5, hitSpeed = 1.5, speed = 2.3,
            flying = true, description = "A baby dragon. Flies over the river; melee can't touch it."),
        CardDef.spell("meteor", "Meteor", 4, "☄️", damage = 570.0, radius = 2.5, description = "Big area damage. Towers take 35%."),
        CardDef.spell("volley", "Volley", 3, "🌧️", damage = 240.0, radius = 4.0, description = "Wide, light area damage. Clears swarms."),
    )

    val defaultDeck = listOf("knight", "archers", "giant", "duelist", "sharpshooter", "gremlins", "meteor", "volley")

    fun byId(id: String): CardDef = all.firstOrNull { it.id == id } ?: all[0]
}

data class Vec(val x: Double, val y: Double) {
    operator fun minus(o: Vec) = Vec(x - o.x, y - o.y)
    operator fun plus(o: Vec) = Vec(x + o.x, y + o.y)
    operator fun times(s: Double) = Vec(x * s, y * s)
    val length: Double get() = sqrt(x * x + y * y)
    fun distance(o: Vec): Double = (this - o).length
    val normalized: Vec get() = if (length > 0.0001) this * (1 / length) else Vec(0.0, 0.0)
}

class Troop(val id: Int, val card: CardDef, val side: Side, var pos: Vec) {
    var hp: Double = card.hp
    var attackCooldown: Double = 0.0
    var laneX: Double = 3.5
    var hitFlash: Double = 0.0
    var walkPhase: Double = 0.0
    var facing: Double = 1.0
    var moving: Boolean = false
    var attackAnim: Double = 0.0
    var spawnAge: Double = 0.0
    val alive: Boolean get() = hp > 0
    val radius: Double get() = if (card.count > 1) 0.35 else 0.5
}

enum class TowerKind(val maxHp: Double, val damage: Double, val range: Double, val hitSpeed: Double, val radius: Double, val label: String) {
    GUARD(2500.0, 100.0, 7.5, 0.8, 1.0, "Guard Tower"),
    KEEP(4000.0, 120.0, 7.0, 1.0, 1.3, "Keep"),
}

class Tower(val id: Int, val kind: TowerKind, val side: Side, val pos: Vec) {
    var hp: Double = kind.maxHp
    var attackCooldown: Double = 0.0
    var activated: Boolean = kind == TowerKind.GUARD
    var hitFlash: Double = 0.0
    val alive: Boolean get() = hp > 0
}

enum class EffectKind(val impactDelay: Double, val duration: Double) {
    METEOR(0.55, 1.6),
    VOLLEY(0.4, 1.3),
    TOWER_FALL(0.0, 1.4),
    DEPLOY(0.0, 0.6),
}

class SpellEffect(val id: Int, val kind: EffectKind, val pos: Vec, val radius: Double, val side: Side, val damage: Double = 0.0) {
    var ttl: Double = kind.duration
    var resolved: Boolean = kind.impactDelay == 0.0
    val age: Double get() = kind.duration - ttl
    val progress: Double get() = min(1.0, max(0.0, age / kind.duration))
    val landed: Boolean get() = age >= kind.impactDelay
}

enum class ProjectileKind { ARROW, BOLT, FIREBALL, CANNON }

class Projectile(val id: Int, val kind: ProjectileKind, val start: Vec, var pos: Vec, val target: Vec, val side: Side, var ttl: Double) {
    val progress: Double
        get() {
            val total = start.distance(target)
            return if (total < 0.001) 1.0 else min(1.0, start.distance(pos) / total)
        }
}

enum class ParticleKind { DUST, SPARK, SMOKE, EMBER, DEBRIS, BONE, LEAF, GLOW }

class Particle(val id: Int, val kind: ParticleKind, var pos: Vec, var vel: Vec, var ttl: Double, val maxTtl: Double, val size: Double, val color: Color) {
    val life: Double get() = max(0.0, min(1.0, ttl / maxTtl))
}

class FloatingText(val id: Int, var pos: Vec, var amount: Double, val victim: Side, val color: Color, var ttl: Double, val maxTtl: Double) {
    val text: String get() = amount.toInt().toString()
    val life: Double get() = max(0.0, min(1.0, ttl / maxTtl))
    val age: Double get() = maxTtl - ttl
}

enum class MatchOutcome(val title: String) { VICTORY("VICTORY"), DEFEAT("DEFEAT"), DRAW("DRAW") }

data class MatchResult(
    val outcome: MatchOutcome,
    val playerCrowns: Int,
    val enemyCrowns: Int,
    val trophyDelta: Int,
    val goldDelta: Int,
    val durationSeconds: Int,
)

/** Trophy tiers that give the player a sense of progression between battles. */
data class League(val name: String, val minTrophies: Int, val color: Color) {
    val next: League? get() = all.getOrNull(all.indexOf(this) + 1)

    /** 0..1 progress from this league's floor to the next league. */
    fun progress(trophies: Int): Double {
        val n = next ?: return 1.0
        return ((trophies - minTrophies).toDouble() / (n.minTrophies - minTrophies)).coerceIn(0.0, 1.0)
    }

    companion object {
        val all = listOf(
            League("Sky Rookie", 0, Color(0.55f, 0.75f, 0.9f)),
            League("Cloud Squire", 60, Color(0.45f, 0.85f, 0.75f)),
            League("Storm Knight", 160, Color(0.4f, 0.65f, 1.0f)),
            League("Sun Champion", 320, Color(1.0f, 0.75f, 0.3f)),
            League("Star Legend", 560, Color(0.95f, 0.6f, 1.0f)),
        )

        fun forTrophies(trophies: Int): League = all.last { trophies >= it.minTrophies }
    }
}

object BattleTips {
    private val afterDefeat = listOf(
        "Wait for 10 elixir before starting a big push.",
        "Volley clears Bone Brigade and Gremlins in one cast.",
        "Drop the Colossus at the back so support catches up.",
        "Archers and Sharpshooter can shoot the flying Whelp.",
        "Defend on your side first: your towers help you fight.",
    )
    private val afterVictory = listOf(
        "Keep your average elixir under 4 for faster cycles.",
        "Meteor on a crowded bridge swings the whole match.",
        "A tower with low health is worth a Meteor at 35%.",
        "Double elixir starts in the last minute: go all in.",
    )

    fun tip(outcome: MatchOutcome, seed: Int): String {
        val pool = if (outcome == MatchOutcome.DEFEAT) afterDefeat else afterVictory
        return pool[Math.floorMod(seed, pool.size)]
    }
}
