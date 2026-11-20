package com.speedyservice.partner

import android.media.AudioAttributes
import android.media.MediaPlayer

/**
 * Plays a customer's voice note (short-lived signed HTTPS URL from Supabase
 * Storage). Only one note plays at a time; state changes are reported to
 * Dart through [onEvent].
 */
class VoicePlayer(private val onEvent: (Map<String, Any?>) -> Unit) {

    private var mp: MediaPlayer? = null
    private var prepared = false
    private var source: String? = null

    fun play(src: String) {
        stop()
        source = src
        val p = MediaPlayer()
        mp = p
        p.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build(),
        )
        try {
            p.setDataSource(src)
        } catch (e: Exception) {
            emit("error", e.message)
            release()
            return
        }
        p.setOnPreparedListener {
            if (mp === it) {
                prepared = true
                it.start()
                emit("playing")
            }
        }
        p.setOnCompletionListener {
            if (mp === it) {
                emit("completed")
                release()
            }
        }
        p.setOnErrorListener { player, what, extra ->
            if (mp === player) {
                emit("error", "Playback failed ($what/$extra)")
                release()
            }
            true
        }
        emit("loading")
        p.prepareAsync()
    }

    fun pause() {
        val p = mp ?: return
        if (prepared && p.isPlaying) {
            p.pause()
            emit("paused")
        }
    }

    fun resume() {
        val p = mp ?: return
        if (prepared && !p.isPlaying) {
            p.start()
            emit("playing")
        }
    }

    fun stop() {
        if (mp != null) {
            release()
            emit("stopped")
        }
    }

    fun position(): Map<String, Any?> {
        val p = mp
        return if (p != null && prepared) {
            mapOf(
                "positionMs" to p.currentPosition,
                "durationMs" to p.duration,
                "playing" to p.isPlaying,
                "source" to source,
            )
        } else {
            mapOf("positionMs" to 0, "durationMs" to 0, "playing" to false, "source" to source)
        }
    }

    fun dispose() {
        release()
    }

    private fun release() {
        val p = mp
        mp = null
        prepared = false
        try {
            p?.reset()
        } catch (_: Exception) {
        }
        p?.release()
    }

    private fun emit(state: String, error: String? = null) {
        val p = mp
        onEvent(
            mapOf(
                "state" to state,
                "source" to source,
                "durationMs" to if (p != null && prepared) p.duration else 0,
                "error" to error,
            ),
        )
    }
}
