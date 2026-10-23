#!/usr/bin/env bash
# Serves the offline demo to phones on the same Wi-Fi (no cable, no Apple account).
#
# On the iPhone: open the printed URL in Safari → Share → "Add to Home Screen".
# The Mac must stay awake and on the same Wi-Fi while you test.
#
#   scripts/serve_web_demo.sh            # builds if needed, serves on :8080
#   PORT=9000 scripts/serve_web_demo.sh
set -euo pipefail
cd "$(dirname "$0")/.."
PORT="${PORT:-8080}"

if [ ! -f build/web/index.html ]; then
  scripts/build_web_demo.sh
fi

IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
HOST="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
echo
echo "Open on the iPhone (same Wi-Fi):"
[ -n "$IP" ] && echo "   http://$IP:$PORT"
echo "   http://$HOST.local:$PORT"
echo
echo "Safari → Share → Add to Home Screen.   (Ctrl+C to stop)"
cd build/web
exec caffeinate -i python3 -m http.server "$PORT" --bind 0.0.0.0
