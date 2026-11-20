#!/usr/bin/env bash
# Release-APK checks: Play Store basics + "is anything secret inside?"
# Usage: apk_checks.sh <apk>   (prints a report; exits 1 on a hard failure)
set -uo pipefail
APK="$1"
FAIL=0
BT=$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)
echo "== APK: $APK ($(du -h "$APK" | cut -f1))"
echo "== sha256: $(sha256sum "$APK" | cut -d' ' -f1)"

echo; echo "== Badging (package / sdk levels)"
"$BT/aapt2" dump badging "$APK" | grep -E "^(package|sdkVersion|targetSdkVersion|application-debuggable|uses-permission)" || true

echo; echo "== Manifest flags"
MANIFEST=$("$BT/aapt2" dump xmltree "$APK" --file AndroidManifest.xml)
if echo "$MANIFEST" | grep -q 'debuggable.*=true'; then echo "FAIL: app is debuggable"; FAIL=1; else echo "OK: not debuggable"; fi
if echo "$MANIFEST" | grep -q 'allowBackup.*=false'; then echo "OK: allowBackup=false"; else echo "WARN: allowBackup not false"; fi
if echo "$MANIFEST" | grep -q 'usesCleartextTraffic.*=false'; then echo "OK: cleartext (http) traffic blocked"; else echo "WARN: cleartext not explicitly blocked"; fi
echo "Exported components:"
echo "$MANIFEST" | grep -B2 -A1 'exported.*=true' | grep -E 'E: (activity|service|receiver|provider)|name' | sed 's/^/   /' || true

echo; echo "== 16 KB page-size alignment (required by Play for Android 15+ devices)"
if "$BT/zipalign" -c -P 16 -v 4 "$APK" > /tmp/zipalign.txt 2>&1; then echo "OK: 16 KB aligned"; else echo "WARN: zipalign -P 16 check failed"; tail -5 /tmp/zipalign.txt; fi

echo; echo "== Secret scan (must find nothing)"
TMP=$(mktemp -d)
unzip -q -o "$APK" -d "$TMP"
PATTERNS='sb_secret_|service_role|rzp_live_|RAZORPAY_KEY_SECRET|RAZORPAY_WEBHOOK_SECRET|BEGIN (RSA |EC )?PRIVATE KEY|SUPABASE_SERVICE_ROLE_KEY|AKIA[0-9A-Z]{16}'
HITS=$(grep -r -a -l -E "$PATTERNS" "$TMP" 2>/dev/null || true)
if [ -n "$HITS" ]; then echo "FAIL: possible secret found in:"; echo "$HITS"; FAIL=1; else echo "OK: no secret keys inside the APK"; fi
# The publishable key is expected (it is public by design, protected by RLS).
if grep -r -a -q -E 'sb_publishable_|eyJhbGciOi' "$TMP"; then echo "INFO: Supabase publishable key present (expected, public by design)"; fi

echo; echo "== Dart code obfuscation"
if strings "$TMP/lib/arm64-v8a/libapp.so" 2>/dev/null | grep -q -E 'IssueSummaryScreen|PartnerService|HomeScreen'; then
  echo "WARN: readable Dart class names found (obfuscation off?)"
else
  echo "OK: Dart class names are obfuscated"
fi
rm -rf "$TMP"
exit $FAIL
