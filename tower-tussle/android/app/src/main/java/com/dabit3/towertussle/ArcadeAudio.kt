package com.dabit3.towertussle

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import androidx.compose.runtime.compositionLocalOf

class ArcadeAudio(context: Context) {
    private val pool = SoundPool.Builder().setMaxStreams(4)
        .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
        .build()
    private val ready = mutableSetOf<Int>()
    private val sounds = mutableMapOf<String, Int>()
    var enabled = true

    init {
        pool.setOnLoadCompleteListener { _, id, status -> if (status == 0) ready.add(id) }
        for (name in listOf("tap", "deploy", "victory", "defeat")) {
            context.assets.openFd("art/$name.wav").use { sounds[name] = pool.load(it, 1) }
        }
    }

    fun play(name: String) {
        if (!enabled) return
        val id = sounds[name] ?: return
        if (id in ready) pool.play(id, 0.7f, 0.7f, 1, 0, 1f)
    }

    fun release() = pool.release()
}

val LocalArcadeAudio = compositionLocalOf<ArcadeAudio?> { null }
