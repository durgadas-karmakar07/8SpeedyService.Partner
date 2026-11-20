package com.speedyservice.partner

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Loops the 8Speedy ringtone + vibration while the in-app "incoming request"
 * screen is open. Respects the phone's ringer mode like a real call:
 * Normal = ring + vibrate, Vibrate = vibrate only, Silent = nothing.
 */
class Ringer(private val context: Context) {

    private var player: MediaPlayer? = null
    private var vibrating = false

    @Suppress("DEPRECATION")
    private val vibrator: Vibrator? by lazy {
        if (Build.VERSION.SDK_INT >= 31) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    fun start() {
        stop()
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val mode = audio.ringerMode
        if (mode == AudioManager.RINGER_MODE_NORMAL) {
            try {
                val afd = context.resources.openRawResourceFd(R.raw.speedy_ring)
                val mp = MediaPlayer()
                mp.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                mp.isLooping = true
                mp.prepare()
                mp.start()
                player = mp
            } catch (_: Exception) {
                player = null
            }
        }
        if (mode != AudioManager.RINGER_MODE_SILENT) vibrate()
    }

    @Suppress("DEPRECATION")
    private fun vibrate() {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= 26) {
            v.vibrate(VibrationEffect.createWaveform(JobAlerts.VIBRATION, 0))
        } else {
            v.vibrate(JobAlerts.VIBRATION, 0)
        }
        vibrating = true
    }

    fun stop() {
        player?.let {
            try {
                it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        player = null
        if (vibrating) {
            vibrator?.cancel()
            vibrating = false
        }
    }
}
