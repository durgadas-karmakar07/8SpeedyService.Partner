# 8Speedy Partner — Play Store listing (mechanic app)

Package: `com.speedyservice.partner` · Category: **Auto & Vehicles** · Free · Contains ads: **No**

Files in this folder:
- `play_store_icon_512.png` → App icon (512×512)
- `feature_graphic_1024x500.png` → Feature graphic
- Screenshots: Home (Online + requests + earnings strip), Incoming job call, Job screen with AI repair guide, Chat, Earnings & Jobs — min 2.

## App name (max 30)
8Speedy Partner for Mechanics

## Short description (max 80)
For Durgapur mechanics: get nearby roadside repair jobs and earn more.

## Full description
8Speedy Partner is for two-wheeler, car, e-rickshaw and heavy-vehicle mechanics in Durgapur. Go online and receive roadside repair requests from customers near you, right on your phone.

• Go Online / Offline with one tap
• New jobs ring like a phone call — even when the screen is off
• Live requests within 10 km — with vehicle model, problem, distance, the customer's voice note and a short AI summary
• Accept, navigate with Google Maps, chat in the app or call the customer
• AI repair guide in English, Hindi or Bengali: likely causes, a step-by-step checklist, tools to carry and safety tips
• Start the job with the customer's 4-digit Start OTP
• Enter the repair bill when you finish — the customer gets a digital bill
• Earnings dashboard: today, this week, 30 days, completion rate and rating
• Repair charges are paid directly to you by the customer

New mechanics: register in the app; our team activates your account after verification.

Support: WhatsApp +91 96352 97320
Privacy Policy: https://durgadas-karmakar07.github.io/8SpeedyService/privacy.html

---

## App content

| Section | Answer |
|---|---|
| Privacy policy | `https://durgadas-karmakar07.github.io/8SpeedyService/privacy.html` |
| App access | Login and a verified partner account are required. For the reviewer: add a test number (Supabase Test OTP) to the `mechanics` table with `is_verified = true`, and enter the number, the OTP and "Tap the switch to go Online" here |
| Ads | No |
| Content rating | Everyone / 3+ |
| Target audience | 18+ |
| Account deletion | In-app: ⋮ menu → Account & Privacy → Delete my account. Web: `https://durgadas-karmakar07.github.io/8SpeedyService/delete-account.html` |

### Foreground service declaration (Location), required
Play Console → App content → **Foreground service permissions** → `FOREGROUND_SERVICE_LOCATION`:
- Task: **Location sharing / navigation for an active service**
- Description: "When a mechanic partner turns on Online mode or has an accepted job, the app shares the partner's live location so nearby customers' repair requests can be shown and the customer can track the assigned mechanic. A persistent notification is shown; turning Offline stops it immediately."
- Video: a 30–60 second screen recording: switch Online → the notification appears → accept a request → job screen. Upload it to YouTube as *unlisted* and add the link.

Background location (`ACCESS_BACKGROUND_LOCATION`) is **not** requested, so no separate declaration is needed for it.

### Full-screen intent declaration (call-style job alerts), required
Play Console → App content → **Full-screen intent permission** (`USE_FULL_SCREEN_INTENT`):
- Question "Is your app's core functionality calling or alarms?" → answer **No** (these are job alerts).
- As a result, on Android 14+ the Play Store keeps this permission *off* by default. The app shows an "Allow full-screen alerts" banner that opens the setting directly; without the permission the job alert still rings as a heads-up notification with a looping ringtone (graceful fallback, as the policy requires).
- On sideloaded test APKs the permission is already on.

## Data safety form

**Collected & shared?** Yes. **Encrypted in transit?** Yes. **Deletion?** Yes.

| Data type | Collected | Shared | Optional? | Purpose |
|---|---|---|---|---|
| Location → Precise location | Yes (also in background while Online) | Yes (with the customer of an active job) | Required | App functionality |
| Personal info → Name | Yes | Yes (customer sees first name) | Required | App functionality, Account management |
| Personal info → Phone number | Yes | Yes (customer of active job) | Required | App functionality, Account management |
| Financial info → Other financial info (repair bill amounts, earnings) | Yes | Yes (the customer of that job sees the bill) | Optional | App functionality |
| Messages → Other in-app messages (chat with the customer) | Yes | Yes (the customer of that job) | Optional | App functionality |
| App activity → Other actions (jobs accepted/released/completed, AI guide use, security logs) | Yes | No | Required | App functionality, Analytics (internal stats), Fraud prevention, security & compliance |

Job details used by the AI repair guide (problem, vehicle model) are sent to Anthropic as a service provider, which does not count as "sharing". Every AI guide has *Helpful / Not helpful / Report* buttons (Google Play AI-generated content policy).

## Permissions used
- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`: live location while Online
- `POST_NOTIFICATIONS`: ongoing "Online" notification and new-job alerts
- `USE_FULL_SCREEN_INTENT`: full-screen, phone-call style alert for new job requests (also on the lock screen)
- `WAKE_LOCK`, `VIBRATE`, `INTERNET`
