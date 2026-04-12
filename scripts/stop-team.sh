#!/bin/bash
# stop-team.sh — Stop the shared OpenClaw gateway for the Personal Team profile

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="${ENV_FILE:-$REPO_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

OPENCLAW_PROFILE="${OPENCLAW_PROFILE:-personal}"

echo "🛑 Stopping Personal Team"
echo "================================"
echo "Profile: $OPENCLAW_PROFILE"
echo ""

openclaw --profile "$OPENCLAW_PROFILE" gateway stop >/dev/null 2>&1 || true

PORT="$(openclaw --profile "$OPENCLAW_PROFILE" config get gateway.port 2>/dev/null || echo 18789)"
for _ in 1 2 3 4 5; do
  if ! lsof -nP -iTCP:${PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "✅ Gateway stopped."
    exit 0
  fi
  sleep 1
done

LISTENER="$(lsof -nP -iTCP:${PORT} -sTCP:LISTEN -t 2>/dev/null | head -1 || true)"
if [ -n "$LISTENER" ]; then
  kill "$LISTENER"
  echo "✅ Stopped listener on port $PORT (PID $LISTENER)"
  exit 0
fi

echo "⚠️  No running gateway found for profile '$OPENCLAW_PROFILE'."
