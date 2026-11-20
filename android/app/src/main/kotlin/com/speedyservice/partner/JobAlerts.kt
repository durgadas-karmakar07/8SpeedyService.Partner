package com.speedyservice.partner

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import java.util.UUID

/**
 * Call-style "new job request" notification.
 *
 * Uses a full-screen intent (shows over the lock screen like an incoming
 * call when allowed) and an insistent sound, so the ringtone keeps looping
 * until the mechanic opens it or it times out.
 */
class JobAlerts(private val context: Context) {

    private val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun ringUri(): Uri = Uri.parse("android.resource://${context.packageName}/${R.raw.speedy_ring}")

    fun notificationsAllowed(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        return nm.areNotificationsEnabled()
    }

    /** Android 14+ lets the user switch full-screen alerts off per app. */
    fun canUseFullScreen(): Boolean =
        if (Build.VERSION.SDK_INT >= 34) nm.canUseFullScreenIntent() else true

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "New job requests",
            NotificationManager.IMPORTANCE_HIGH,
        )
        channel.description = "Rings like a phone call when a customer near you needs a mechanic."
        channel.setSound(
            ringUri(),
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        channel.enableVibration(true)
        channel.vibrationPattern = VIBRATION
        channel.enableLights(true)
        channel.lightColor = BRAND_COLOR
        channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        nm.createNotificationChannel(channel)
    }

    @Suppress("DEPRECATION")
    fun show(bookingId: String, title: String, body: String): Boolean {
        if (!notificationsAllowed()) return false
        ensureChannel()

        // One-time token: MainActivity is exported (launcher), so other apps
        // could send it this action. Only intents carrying the token we just
        // created are treated as a real job alert.
        val token = UUID.randomUUID().toString()
        activeToken = token
        val intent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_INCOMING
            putExtra(EXTRA_BOOKING_ID, bookingId)
            putExtra(EXTRA_TOKEN, token)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pending = PendingIntent.getActivity(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context)
                .setPriority(Notification.PRIORITY_MAX)
                .setSound(ringUri(), AudioManager.STREAM_RING)
                .setVibrate(VIBRATION)
        }
        builder
            .setSmallIcon(R.drawable.ic_stat_job)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_CALL)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setColor(BRAND_COLOR)
            .setAutoCancel(true)
            .setOngoing(true)
            .setShowWhen(true)
            .setContentIntent(pending)
            .setFullScreenIntent(pending, true)
            .addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(context, R.drawable.ic_stat_job),
                    "Open request",
                    pending,
                ).build(),
            )
        if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter(TIMEOUT_MS)

        val notification = builder.build()
        notification.flags = notification.flags or Notification.FLAG_INSISTENT
        nm.notify(NOTIFICATION_ID, notification)
        return true
    }

    fun cancel() = nm.cancel(NOTIFICATION_ID)

    companion object {
        const val CHANNEL_ID = "job_requests_ring_v1"
        const val NOTIFICATION_ID = 8801
        const val REQUEST_CODE = 8801
        const val ACTION_INCOMING = "com.speedyservice.partner.INCOMING_REQUEST"
        const val EXTRA_BOOKING_ID = "speedy_booking_id"
        const val EXTRA_TOKEN = "speedy_alert_token"
        const val TIMEOUT_MS = 45_000L
        const val BRAND_COLOR = 0xFFFF5722.toInt()
        val VIBRATION = longArrayOf(0, 700, 500, 700, 1200)

        /** Token of the alert currently showing (process memory only). */
        @Volatile
        var activeToken: String? = null
    }
}
