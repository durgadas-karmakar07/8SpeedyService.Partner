# 8Speedy Partner — Play Store listing (mechanic app)

Package: `com.speedyservice.partner` · Category: **Auto & Vehicles** · Free · Contains ads: **No**

Files in this folder:
- `play_store_icon_512.png` → App icon (512×512)
- `feature_graphic_1024x500.png` → Feature graphic
- Screenshots: Home (Online + requests), Job screen, OTP step, My Jobs — min 2.

## App name (max 30)
8Speedy Partner for Mechanics

## Short description (max 80)
For Durgapur mechanics: get nearby roadside repair jobs and earn more.

## Full description
8Speedy Partner is for two-wheeler, car, e-rickshaw and heavy-vehicle mechanics in Durgapur. Go online and receive roadside repair requests from customers near you, right on your phone.

• Go Online / Offline with one tap
• Live requests within 10 km — with vehicle model, problem and distance
• Accept, navigate with Google Maps and call the customer
• Start the job with the customer's 4-digit Start OTP
• See today's and this week's jobs and your rating in one place
• Repair charges are paid directly to you by the customer

New mechanics: register in the app; our team activates your account after verification.

Support: WhatsApp +91 96352 97320
Privacy Policy: https://durgadas-karmakar07.github.io/8SpeedyService/privacy.html

---

## App content

| Section | Answer |
|---|---|
| Privacy policy | `https://durgadas-karmakar07.github.io/8SpeedyService/privacy.html` |
| App access | Login + verified partner account required. Reviewer ke liye: ek test number (Supabase Test OTP) ko `mechanics` table mein `is_verified = true` ke saath add karein aur yahan number + OTP + "Tap the switch to go Online" likhein |
| Ads | No |
| Content rating | Everyone / 3+ |
| Target audience | 18+ |
| Account deletion | In-app: ⋮ menu → Account & Privacy → Delete my account. Web: `https://durgadas-karmakar07.github.io/8SpeedyService/delete-account.html` |

### Foreground service declaration (Location) — zaroori
Play Console → App content → **Foreground service permissions** → `FOREGROUND_SERVICE_LOCATION`:
- Task: **Location sharing / navigation for an active service**
- Description: "When a mechanic partner turns on Online mode or has an accepted job, the app shares the partner's live location so nearby customers' repair requests can be shown and the customer can track the assigned mechanic. A persistent notification is shown; turning Offline stops it immediately."
- Video: 30–60 sec screen recording: switch ON → notification dikhe → request accept → job screen. YouTube par *unlisted* upload karke link dein.

Background location (`ACCESS_BACKGROUND_LOCATION`) **nahi** maangi gayi hai, isliye uska alag declaration nahi chahiye.

### Full-screen intent declaration — zaroori (naya, call-style job alerts)
Play Console → App content → **Full-screen intent permission** (`USE_FULL_SCREEN_INTENT`):
- Sawal "Is your app's core functionality calling or alarms?" → **No** (job alerts) — honest jawab dein.
- Iska matlab: Android 14+ par Play Store yeh permission default *off* rakhega. App khud banner dikhati hai
  ("Allow full-screen alerts") jo seedha setting kholta hai; permission na mile to bhi job alert
  heads-up notification + looping ringtone ke saath bajta hai (graceful fallback — policy ki zaroorat).
- Sideload kiye test APK par permission pehle se on rehti hai.

## Data safety form

**Collected & shared?** Yes. **Encrypted in transit?** Yes. **Deletion?** Yes.

| Data type | Collected | Shared | Optional? | Purpose |
|---|---|---|---|---|
| Location → Precise location | Yes (also in background while Online) | Yes (with the customer of an active job) | Required | App functionality |
| Personal info → Name | Yes | Yes (customer sees first name) | Required | App functionality, Account management |
| Personal info → Phone number | Yes | Yes (customer of active job) | Required | App functionality, Account management |
| App activity → Other actions (jobs accepted/completed) | Yes | No | Required | App functionality, Analytics (internal stats) |

## Permissions used
- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` — Online rehte hue live location
- `POST_NOTIFICATIONS` — ongoing "Online" notification + new-job alerts
- `USE_FULL_SCREEN_INTENT` — new job request phone-call jaisa full screen (lock screen par bhi)
- `WAKE_LOCK`, `VIBRATE`, `INTERNET`
