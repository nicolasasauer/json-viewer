#!/usr/bin/env bash
# Captures app screenshots on a running emulator. Called by
# .github/workflows/screenshots.yml; also works locally with `adb` and an
# emulator, after `flutter build apk --debug`.
set -uo pipefail

PKG=com.nicolas.json_viewer
APK=build/app/outputs/flutter-apk/app-debug.apk
DIR=$(cd "$(dirname "$0")" && pwd)
OUT=screenshots
mkdir -p "$OUT"

shot() { adb exec-out screencap -p > "$OUT/$1.png"; echo "captured $1"; }

# Taps the element with the given label (content-desc or text).
tap() {
  local pos
  for _ in 1 2 3 4 5; do
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    adb pull /sdcard/ui.xml /tmp/ui.xml >/dev/null 2>&1
    if pos=$(python3 "$DIR/ui.py" /tmp/ui.xml "$1" "${2:-exact}"); then
      adb shell input tap $pos
      sleep 2
      return 0
    fi
    sleep 2
  done
  echo "::warning::could not find '$1' on screen"
  cp /tmp/ui.xml "$OUT/ui-missing-$(echo "$1" | tr -c 'a-zA-Z0-9' '_').xml" 2>/dev/null
  return 1
}

open_sample() {
  adb shell am force-stop $PKG
  adb shell am start -W -n $PKG/.MainActivity \
    -a android.intent.action.VIEW -t application/json \
    -d "file:///data/user/0/$PKG/files/studiplan.json"
  sleep 8
}

adb install -r "$APK"

# Put the sample into the app's private storage so the VIEW intent can read it
# without storage permissions (run-as works because this is a debug build).
adb push "$DIR/sample.json" /data/local/tmp/studiplan.json
adb shell "cat /data/local/tmp/studiplan.json | run-as $PKG sh -c 'mkdir -p files && cat > files/studiplan.json'"

adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0

# --- Phone, light ------------------------------------------------------------
adb shell cmd uimode night no
open_sample
shot 01-phone-tree-light

tap "More" && tap "Expand all" && shot 02-phone-expanded-light

tap "Edit" && shot 03-phone-editor-light

# --- Phone, dark -------------------------------------------------------------
adb shell cmd uimode night yes
open_sample
shot 04-phone-tree-dark

tap "More" && tap "Search" && adb shell input text "Algebra" && sleep 2 && shot 05-phone-search-dark
adb shell input keyevent KEYCODE_BACK; sleep 1

tap "Split view" && shot 06-phone-split-dark

# --- Landscape (wide layout), dark --------------------------------------------
adb shell settings put system user_rotation 1
open_sample
shot 07-landscape-view-dark
tap "Split view" && shot 08-landscape-split-dark

adb shell settings put system user_rotation 0
adb shell cmd uimode night no

# --- Launcher icon -----------------------------------------------------------
adb shell input keyevent KEYCODE_HOME
sleep 2
adb shell input swipe 540 1800 540 600 300
sleep 2
shot 09-app-drawer

ls -la "$OUT"
