#!/usr/bin/env bash
# Publishes the offline demo as a public HTTPS link on YOUR Vercel account
# (free "Hobby" plan is enough). The link works on any phone, and after the first
# load it also works offline (service worker). Everything — data, images, fonts —
# is inside the app, nothing else is uploaded.
#
# First run asks you to log in (opens the browser). Use your personal account.
#   scripts/deploy_web_vercel.sh
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build_web_demo.sh

# Project name = folder name, so deploy from a copy with a nice name.
rm -rf build/cultural-export-hub
cp -R build/web build/cultural-export-hub
cd build/cultural-export-hub

npx --yes vercel@latest deploy --prod --yes
echo
echo "Open the printed URL in Safari on the iPhone → Share → Add to Home Screen."
