#!/usr/bin/env bash
# Creates the Android Virtual Device used by test/multiplayer-e2e.sh.
#
# The AVD is an AOSP "automated test device" image (no Google apps, tuned for
# headless CI) at 540x1200 / hdpi, which keeps a software-emulated (TCG)
# emulator responsive enough to render Flutter frames on hosts without nested
# virtualization.
#
# Usage: tool/android-avd.sh [name]      (default: swapmate_atd)
# Env:   ANDROID_HOME (~/Library/Android/sdk)
set -euo pipefail

NAME="${1:-swapmate_atd}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
IMAGE="system-images;android-35;aosp_atd;arm64-v8a"
SDK="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
AVD="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"

[[ -x "$SDK" ]] || { echo "sdkmanager not found at $SDK" >&2; exit 1; }
yes | "$SDK" --licenses >/dev/null 2>&1 || true
"$SDK" --install "$IMAGE" "platform-tools" "emulator" >/dev/null
echo no | "$AVD" create avd -n "$NAME" -k "$IMAGE" -d pixel_6 --force >/dev/null

CONFIG="$HOME/.android/avd/$NAME.avd/config.ini"
set_ini() { # set_ini <key> <value>
  if grep -q "^$1=" "$CONFIG"; then
    sed -i '' "s|^$1=.*|$1=$2|" "$CONFIG"
  else
    echo "$1=$2" >> "$CONFIG"
  fi
}
set_ini hw.lcd.width 540
set_ini hw.lcd.height 1200
set_ini hw.lcd.density 240
set_ini hw.ramSize 2048
set_ini hw.cpu.ncore 4
# Host-side SwiftShader: guest-side GL has no ES 3, which surfaceflinger needs.
set_ini hw.gpu.enabled yes
set_ini hw.gpu.mode swiftshader_indirect
set_ini hw.keyboard yes
set_ini skin.name 540x1200
set_ini skin.path _no_skin

# The ATD image requests Android Virtualization Framework support, which the
# emulator cannot provide without a hypervisor; turn it off host-wide.
FEATURES="$HOME/.android/advancedFeatures.ini"
touch "$FEATURES"
grep -q '^AndroidVirtualizationFramework' "$FEATURES" ||
  echo 'AndroidVirtualizationFramework = off' >> "$FEATURES"

echo "created AVD $NAME ($IMAGE, 540x1200@240)"
