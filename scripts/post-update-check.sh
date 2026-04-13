#!/usr/bin/env bash
# post-update-check.sh — lightweight validation after updating OpenClaw

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="${ENV_FILE:-$REPO_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

OPENCLAW_PROFILE="${OPENCLAW_PROFILE:-default}"
OPENCLAW_STATE_DIR="$(team_openclaw_state_dir "$OPENCLAW_PROFILE")"

echo "🔎 Post-update check"
echo "================================"
echo "Profile: $OPENCLAW_PROFILE"

command -v openclaw >/dev/null 2>&1 || {
  echo "❌ openclaw binary not found"
  exit 1
}

if [ ! -f "$OPENCLAW_STATE_DIR/openclaw.json" ]; then
  echo "❌ Profile '$OPENCLAW_PROFILE' is not initialized"
  echo "   Run: bash scripts/setup.sh"
  exit 1
fi

echo "✅ OpenClaw installed: $(openclaw --version 2>/dev/null || echo 'version unknown')"

if openclaw --profile "$OPENCLAW_PROFILE" gateway status 2>/dev/null | grep -q 'RPC probe: ok'; then
  echo "✅ Gateway responds"
else
  echo "⚠️  Gateway is not running"
fi

echo "✅ Agent list:"
openclaw --profile "$OPENCLAW_PROFILE" agents list 2>/dev/null || {
  echo "❌ Failed to list agents"
  exit 1
}

echo ""
echo "✅ Recommended follow-up:"
echo "   bash scripts/smoke-test.sh"
