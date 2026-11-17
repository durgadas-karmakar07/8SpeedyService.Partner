# 8Speedy Partner — Mechanic App

Customer app wala hi Supabase backend use karta hai. Package: `com.speedyservice.partner`.

## Flow

1. **Login** — phone OTP (same Supabase Auth).
2. **Account check** (`mechanic_link_account`)
   - Admin ne Dashboard mein is phone ka mechanic row banaya hai → auto-link.
   - Nahi hai → **Registration form** (naam, shop, vehicle types) → *Verification pending*.
   - Admin `mechanics.is_verified = true` kare → mechanic Online ja sakta hai.
3. **Home** — Online switch. Online hote hi GPS location server par jaati hai (har 25 m / 60 sec),
   10 km ke andar ki requests har 8 sec refresh, nayi request par vibrate. **Accept Job** — jo pehle tap kare, job usi ki.
4. **Job screen** — Call customer, Google Maps navigate → *Arrived* → customer ka 4-digit **Start OTP** → *Complete*.
   Start se pehle "job chhodein" se booking wapas dusre mechanics ke paas chali jaati hai (customer app radar par wapas aa jaata hai).
   Customer cancel kare to 8 sec mein popup aa jaata hai.
5. **My Jobs** — aaj / 7 din / total jobs, rating, reviews.
6. **Account & Privacy** (⋮ menu) — Privacy Policy, Partner Terms, WhatsApp support, **Delete my account**
   (Google Play ki zaroorat; Pending aur Registration screen se bhi).

## Setup

1. Backend main repo (`8SpeedyService`) mein hai. Supabase SQL Editor mein migrations order mein run karein
   (`000001`, `000002`, `000003`) aur `delete-account` Edge Function deploy karein —
   poori list main repo ke `PRODUCTION_SETUP.md` mein hai.
2. Is folder mein:

```bash
cd D:\8SpeedyService.Partner
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=env/prod.json
```

`env/example.json` copy karke `env/prod.json` banayein (customer app wali file bhi chalegi; Razorpay key yahan use nahi hoti). Yeh file git mein nahi jaati.

## Release build

Customer app wala hi upload keystore use kar sakte hain (ya naya). `android/key.properties` banayein
(format customer app jaisa) phir:

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=env/prod.json
```

Play Console mein **naya app** banayein (`com.speedyservice.partner`). Listing text, icon, feature graphic,
Data safety aur Foreground-service declaration ke jawab: `store/PLAY_STORE_LISTING.md`.

### Play Console declarations (zaroori — details `store/PLAY_STORE_LISTING.md` mein)
- **Foreground service — Location**: app Online rehte hue location share karta hai (ongoing notification ke saath).
  Declaration form mein likhein: "Mechanic partners share live location while online so customers can track the
  assigned mechanic and receive nearby repair requests." + ek short screen-recording video.
- **Data safety**: Location (precise) — collected, shared with customers during an active job; Phone number — account.
- Background location permission **nahi** maangi gayi hai (sirf "While using the app" + foreground service).

## Limitations (v1) — aage ke kaam
- Nayi request ka alert sirf tab aata hai jab mechanic Online hai aur app chal raha hai (foreground service
  app ko zinda rakhta hai). App swipe karke band karne par requests nahi aayengi →
  **Phase 2: FCM push notifications** (Edge Function + `mechanics.fcm_token`).
- Mechanic ki kamai / commission tracking abhi nahi hai — repair charge mechanic customer se seedha leta hai.
