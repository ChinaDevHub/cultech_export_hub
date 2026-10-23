#!/usr/bin/env bash
# Installs the offline demo on a USB-connected iPhone in RELEASE mode, so it
# keeps working after you unplug the cable (debug builds do not).
#
# Before the first run (once, see README "Showing it on a real iPhone"):
#   1. iPhone: Settings → Privacy & Security → Developer Mode → On (restarts the phone)
#   2. Plug in the iPhone, tap "Trust This Computer"
#   3. Xcode → open ios/Runner.xcworkspace → Runner target → Signing & Capabilities
#      → pick your Team (Automatic signing)
#
# Usage:  scripts/install_iphone.sh            # first connected iPhone
#         scripts/install_iphone.sh <device-id>
set -euo pipefail
cd "$(dirname "$0")/.."

ID="${1:-}"
if [ -z "$ID" ]; then
  ID="$(flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
try:
    devices = json.load(sys.stdin)
except Exception:
    devices = []
for d in devices:
    if d.get("targetPlatform", "").startswith("ios") and not d.get("emulator", False):
        print(d["id"]); break
')"
fi

if [ -z "$ID" ]; then
  echo "No physical iPhone found."
  echo "  • Connect it with a cable, unlock it and tap 'Trust This Computer'."
  echo "  • Turn on Developer Mode: Settings → Privacy & Security → Developer Mode."
  echo "  • Check with: flutter devices"
  exit 1
fi

echo "Installing release build on device $ID …"
flutter pub get
flutter run --release -d "$ID"
