#!/bin/bash
# start-team.sh — Start the shared OpenClaw gateway for the team profile
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_DIR/team-config.sh"

ENV_FILE="${ENV_FILE:-$REPO_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

OPENCLAW_PROFILE="${OPENCLAW_PROFILE:-default}"
OPENCLAW_STATE_DIR="$(team_openclaw_state_dir "$OPENCLAW_PROFILE")"

is_real_secret() {
  local value="${1:-}"
  [[ -n "$value" ]] || return 1
  [[ "$value" != your-* ]] || return 1
  [[ "$value" != *placeholder* ]] || return 1
  [[ "$value" != *changeme* ]] || return 1
  return 0
}

OPENCLAW_AUTH_CHOICE="${OPENCLAW_AUTH_CHOICE:-}"
if [ -z "$OPENCLAW_AUTH_CHOICE" ]; then
  if is_real_secret "${OPENAI_API_KEY:-}"; then
    OPENCLAW_AUTH_CHOICE="openai-api-key"
  else
    OPENCLAW_AUTH_CHOICE="openai-codex"
  fi
fi

echo "🚀 Starting Agent Team"
echo "================================"
echo "Profile: $OPENCLAW_PROFILE"
echo "Auth choice: $OPENCLAW_AUTH_CHOICE"
echo "Workspace root: ${OPENCLAW_AGENTS_DIR:-$(team_openclaw_agents_dir)}"
echo ""

if [ ! -f "$OPENCLAW_STATE_DIR/openclaw.json" ]; then
  echo "❌ OpenClaw profile '$OPENCLAW_PROFILE' is not initialized."
  echo "   Run: bash scripts/setup.sh"
  exit 1
fi

if ! grep -qv '^#' "$REPO_DIR/.env" 2>/dev/null; then
  echo "⚠️  .env looks empty."
fi

if [ "$OPENCLAW_AUTH_CHOICE" = "openai-codex" ]; then
  echo "ℹ️  Using OpenAI Codex subscription flow."
  echo "   If this is the first run, complete Sign in with ChatGPT during setup."
elif [ "$OPENCLAW_AUTH_CHOICE" = "openai-api-key" ] && grep -q '^OPENAI_API_KEY=your-' "$REPO_DIR/.env" 2>/dev/null; then
  echo "⚠️  OPENAI_API_KEY is still a placeholder."
  echo "   Gateway will start, but agent turns will fail until you set a real key."
fi

if openclaw --profile "$OPENCLAW_PROFILE" gateway status 2>/dev/null | grep -q 'RPC probe: ok'; then
  echo "✅ Gateway is already running."
  echo "Status: openclaw --profile $OPENCLAW_PROFILE status"
  exit 0
fi

echo "🪪 Ensuring LaunchAgent is installed..."
openclaw --profile "$OPENCLAW_PROFILE" gateway install >/dev/null

echo "🚀 Starting shared gateway service..."
openclaw --profile "$OPENCLAW_PROFILE" gateway start >/dev/null 2>&1 || true

for _ in 1 2 3 4 5 6 7 8 9 10; do
  if openclaw --profile "$OPENCLAW_PROFILE" gateway status 2>/dev/null | grep -q 'RPC probe: ok'; then
    echo "✅ Gateway is running."
    echo ""
    echo "Checks:"
    echo "  openclaw --profile $OPENCLAW_PROFILE status"
    echo "  openclaw --profile $OPENCLAW_PROFILE agents list"
    echo "  openclaw --profile $OPENCLAW_PROFILE logs --limit 40 --plain"
    exit 0
  fi
  sleep 1
done

echo "❌ Gateway failed to start."
echo "   Inspect:"
echo "   openclaw --profile $OPENCLAW_PROFILE logs --limit 80 --plain"
exit 1
