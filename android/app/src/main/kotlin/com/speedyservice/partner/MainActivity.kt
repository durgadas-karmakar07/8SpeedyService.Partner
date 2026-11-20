package com.speedyservice.partner

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI and the `com.speedyservice.partner/alerts` channel:
 * call-style job alerts, ringtone, notification permissions and the voice
 * note player.
 */
class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null
    private var alerts: JobAlerts? = null
    private var ringer: Ringer? = null
    private var player: VoicePlayer? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var launchBookingId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        alerts = JobAlerts(applicationContext)
        ringer = Ringer(applicationContext)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = ch
        player = VoicePlayer { event -> runOnUiThread { ch.invokeMethod("onPlayer", event) } }
        ch.setMethodCallHandler { call, result -> handle(call, result) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        consumeIntent(intent, fromNewIntent = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeIntent(intent, fromNewIntent = true)
    }

    override fun onDestroy() {
        ringer?.stop()
        player?.dispose()
        channel?.setMethodCallHandler(null)
        super.onDestroy()
    }

    private fun consumeIntent(intent: Intent?, fromNewIntent: Boolean) {
        if (intent?.action != JobAlerts.ACTION_INCOMING) return
        val bookingId = intent.getStringExtra(JobAlerts.EXTRA_BOOKING_ID) ?: return
        // Make sure the same tap is not handled twice (e.g. on rotation).
        intent.action = null
        alerts?.cancel()
        showOverLockScreen(true)
        if (fromNewIntent && channel != null) {
            channel?.invokeMethod("onIncomingTap", bookingId)
        } else {
            launchBookingId = bookingId
        }
    }

    @Suppress("DEPRECATION")
    private fun showOverLockScreen(on: Boolean) {
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val a = alerts
        val p = player
        if (a == null || p == null) {
            result.error("not_ready", "Alerts are not ready yet", null)
            return
        }
        when (call.method) {
            "notificationsAllowed" -> result.success(a.notificationsAllowed())
            "requestNotifications" -> requestNotifications(result)
            "canFullScreen" -> result.success(a.canUseFullScreen())
            "openFullScreenSettings" -> {
                openFullScreenSettings()
                result.success(null)
            }
            "openNotificationSettings" -> {
                openNotificationSettings()
                result.success(null)
            }
            "showIncoming" -> {
                val id = call.argument<String>("bookingId")
                if (id.isNullOrBlank()) {
                    result.success(false)
                } else {
                    result.success(
                        a.show(
                            id,
                            call.argument<String>("title") ?: "New job request",
                            call.argument<String>("body") ?: "A customer near you needs a mechanic.",
                        ),
                    )
                }
            }
            "cancelIncoming" -> {
                a.cancel()
                result.success(null)
            }
            "startRinging" -> {
                ringer?.start()
                result.success(null)
            }
            "stopRinging" -> {
                ringer?.stop()
                result.success(null)
            }
            "takeLaunchRequest" -> {
                val id = launchBookingId
                launchBookingId = null
                result.success(id)
            }
            "setLockScreenMode" -> {
                showOverLockScreen(call.arguments == true)
                result.success(null)
            }
            "playAudio" -> {
                val src = call.arguments as? String
                if (src.isNullOrBlank() || !src.startsWith("https://")) {
                    result.error("bad_source", "Only HTTPS voice notes can be played", null)
                } else {
                    p.play(src)
                    result.success(null)
                }
            }
            "pauseAudio" -> {
                p.pause()
                result.success(null)
            }
            "resumeAudio" -> {
                p.resume()
                result.success(null)
            }
            "stopAudio" -> {
                p.stop()
                result.success(null)
            }
            "audioPosition" -> result.success(p.position())
            else -> result.notImplemented()
        }
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        val a = alerts
        if (Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(a?.notificationsAllowed() ?: false)
            return
        }
        if (pendingPermission != null) {
            result.success(false)
            return
        }
        pendingPermission = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIFICATIONS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_NOTIFICATIONS) {
            val r = pendingPermission
            pendingPermission = null
            r?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
        }
    }

    private fun openFullScreenSettings() {
        if (Build.VERSION.SDK_INT >= 34) {
            try {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                        Uri.parse("package:$packageName"),
                    ),
                )
                return
            } catch (_: Exception) {
            }
        }
        openNotificationSettings()
    }

    private fun openNotificationSettings() {
        try {
            val intent = if (Build.VERSION.SDK_INT >= 26) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
            }
            startActivity(intent)
        } catch (_: Exception) {
        }
    }

    companion object {
        private const val CHANNEL = "com.speedyservice.partner/alerts"
        private const val REQ_NOTIFICATIONS = 8812
    }
}
