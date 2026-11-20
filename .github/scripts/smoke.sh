#!/usr/bin/env bash
# Installs the APK on the emulator, opens it and records screenshots + crashes.
# Usage: smoke.sh <apk> <package>
set -x
APK="$1"; PKG="$2"
OUT=smoke; mkdir -p "$OUT"
adb wait-for-device
adb shell settings put global window_animation_scale 0 || true
adb install -r -g "$APK" | tee "$OUT/install.txt"
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
shot() { sleep "$2"; adb exec-out screencap -p > "$OUT/$1.png"; }
shot 01_splash 6
shot 02_after_20s 14
# Walk a little through the first screens (onboarding / login).
W=$(adb shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1 | cut -dx -f1)
H=$(adb shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1 | cut -dx -f2)
adb shell input tap $((W/2)) $((H*90/100)); shot 03_tap1 4
adb shell input tap $((W/2)) $((H*90/100)); shot 04_tap2 4
adb shell input tap $((W/2)) $((H*90/100)); shot 05_tap3 4
adb shell input keyevent KEYCODE_HOME; sleep 2
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1; shot 06_resume 5
adb logcat -d > "$OUT/logcat.txt"
grep -E "FATAL EXCEPTION|AndroidRuntime: |E/flutter|Unhandled Exception" "$OUT/logcat.txt" > "$OUT/crashes.txt" || true
if adb shell pidof "$PKG" > /dev/null; then echo "RUNNING" > "$OUT/status.txt"; else echo "NOT RUNNING (crashed?)" > "$OUT/status.txt"; fi
cat "$OUT/status.txt"; echo "crash lines: $(wc -l < "$OUT/crashes.txt")"
exit 0
