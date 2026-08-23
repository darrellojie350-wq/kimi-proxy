#!/bin/bash
# Kimi Proxy Bridge v2 — Linux start script (mirror of start-bridge.bat)
cd "$(dirname "$0")"
if [ ! -d node_modules ]; then
  npm install --omit=dev
fi
export KIMI_BRIDGE_PORT="${KIMI_BRIDGE_PORT:-9876}"
exec node kimi-bridge.js
