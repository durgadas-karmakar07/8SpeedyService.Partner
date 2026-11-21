# 8Speedy Partner (mechanic app) — project memory for Claude Code

The full project hand-over (owner, backend, security rules, CI, open problems) is in the customer repo,
which also holds the Supabase migrations and Edge Functions:

@../8SpeedyService/CLAUDE.md

If that file is not found, the customer repo should be at `D:\8SpeedyService`
(`git clone https://github.com/durgadas-karmakar07/8SpeedyService`). Key points in short:
reply to the owner in simple **Hinglish**; commit + push to `main` yourself (he syncs his PC with
`git reset --hard origin/main`); import Material via `package:material_ui/material_ui.dart`;
every DB write goes through SECURITY DEFINER RPCs; never put secret keys in the app; DB changes =
new file in `8SpeedyService/supabase/migrations/` applied to Supabase project `mzxcbhiemdkhalslxwid`.

## This app
- Dart package `speedy_partner`, applicationId / Kotlin package `com.speedyservice.partner`.
- Constants: `lib/core/constants.dart` (`requestPollInterval` 8 s, `requestRadiusMeters`,
  `incomingRingTimeout` 40 s, `voiceNoteBucket`). Data access: `lib/services/partner_service.dart`
  (RPCs only). Models: `lib/models/models.dart`.
- Flow: login (phone OTP) → `account_gate.dart` (link account / self-register → admin sets
  `mechanics.is_verified = true` in Supabase) → `home_screen.dart` (Online/Offline, nearby requests on
  map + list) → `job_screen.dart` (navigate, arrived, start with customer's OTP, complete, release) →
  `history_screen.dart`, `account_screen.dart` (delete account).
- While Online, `location_service.dart` (geolocator) runs a **foreground service** with location
  updates + wake lock; that keeps the process (and the 8-second request poll) alive in the background.
  Play Console needs the Foreground-service declaration (see `store/PLAY_STORE_LISTING.md`).

## Call-style job alerts (built 20 Nov 2026)
New request while Online → the phone rings like an incoming call.
- Foreground: `HomeScreen._announce()` pushes `lib/screens/incoming_request_screen.dart` (ripples,
  vehicle, distance, issues, voice note, 40 s countdown, Accept / Decline) and starts the ringtone.
  Ringing stops when the app goes to background or the voice note is played; the screen closes itself
  if the request disappears (`liveIds` from the poll).
- Background / screen off: `AlertService.showIncoming()` → native `JobAlerts.kt` posts a
  CATEGORY_CALL notification with **full-screen intent** (over the lock screen), FLAG_INSISTENT
  (sound loops), 45 s timeout, channel `job_requests_ring_v1`, small icon `res/drawable/ic_stat_job.xml`.
  Tap → `MainActivity` checks a one-time token (`JobAlerts.activeToken`) → Dart `onIncomingTap` →
  call screen. Cold start from the alert → `takeLaunchRequest()`.
- Ringtone: original synthesized sound `android/app/src/main/res/raw/speedy_ring.ogg` (protected from
  resource shrinking by `res/raw/keep.xml`); regenerate with `tool/make_ringtone.py`.
  `Ringer.kt` loops it in-app and respects the phone's ringer mode (silent / vibrate).
- Native bridge: MethodChannel `com.speedyservice.partner/alerts` (`MainActivity.kt`), Dart wrapper
  `lib/services/alert_service.dart`. Native Kotlin was chosen over plugins on purpose (no plugin
  version risk, platform APIs only).
- Permissions: `POST_NOTIFICATIONS` (asked when going Online) and `USE_FULL_SCREEN_INTENT`.
  Android 14+ Play Store turns full-screen intent **off** for non-calling apps → home screen shows an
  "Allow full-screen alerts" banner that opens the setting; without it the alert is still a ringing
  heads-up notification. Play Console: Full-screen intent declaration → answer "No, not a calling/alarm app".
- Limitation: no FCM yet → no alert if the app was swiped away / killed (see open problems in the
  customer `CLAUDE.md`).

## Voice notes (listening side)
`lib/widgets/voice_note_player.dart` creates a 10-minute signed URL for the private `voice-notes`
bucket only when tapped (server RLS decides access) and plays it with native `VoicePlayer.kt`
(HTTPS only). Shown on request cards, the call screen and the job screen. Open requests come from
`mechanic_get_open_requests_v3` (falls back to `_v2` on PGRST202).

## Tests / previews
`test/partner_test.dart` (models incl. voice note fields), `test_preview/previews_test.dart`
(renders the call screen + loaders to PNG in CI). CI, APK links and checks: see the customer `CLAUDE.md`.
