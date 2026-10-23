#!/usr/bin/env bash
# Builds the offline demo as a web app (PWA) in build/web. Open it in Safari on
# any iPhone/Android → Share → "Add to Home Screen" → it runs full-screen like an
# app, with no Apple account, TestFlight or cable. Everything (data, images,
# fonts) is inside the app, so after the first load it also works offline.
#
# Host build/web anywhere (Vercel, Netlify, GitHub Pages, or `python3 -m http.server`
# on your laptop — iPhone and laptop on the same Wi-Fi).
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
flutter build web --release --no-web-resources-cdn
echo
echo "Built: build/web"
echo "Quick local test:  (cd build/web && python3 -m http.server 8080 --bind 0.0.0.0)"
echo "then open  http://<your-laptop-ip>:8080  on the iPhone (same Wi-Fi)."
