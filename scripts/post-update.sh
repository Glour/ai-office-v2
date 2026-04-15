#!/usr/bin/env bash
# post-update.sh — refresh the local OpenClaw installation used by this repo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔄 Post-update routine"
echo "================================"

if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  OPENCLAW_DIR="$(npm root -g 2>/dev/null)/openclaw"
  if [ -d "$OPENCLAW_DIR" ] && ! node -e "require('playwright')" 2>/dev/null; then
    echo "📦 Installing Playwright into global OpenClaw package..."
    (cd "$OPENCLAW_DIR" && npm install playwright --no-save >/dev/null 2>&1 || true)
  fi
fi

echo "🛑 Restarting team gateway via repo scripts..."
bash "$SCRIPT_DIR/stop-team.sh" || true
sleep 2
bash "$SCRIPT_DIR/start-team.sh"

echo "🔎 Running post-update checks..."
bash "$SCRIPT_DIR/post-update-check.sh"

echo "✅ Post-update completed"
