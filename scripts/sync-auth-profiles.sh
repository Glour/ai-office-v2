#!/usr/bin/env bash
# sync-auth-profiles.sh — copy provider auth profiles into isolated personal agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
source "$REPO_DIR/team-config.sh"

ENV_FILE="${ENV_FILE:-$REPO_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

OPENCLAW_PROFILE="${OPENCLAW_PROFILE:-personal}"
OPENCLAW_STATE_DIR="$HOME/.openclaw-${OPENCLAW_PROFILE}"
OPENCLAW_AGENTS_ROOT="$OPENCLAW_STATE_DIR/agents"
AUTH_SOURCE="${OPENCLAW_AUTH_SOURCE:-$HOME/.openclaw/agents/main/agent/auth-profiles.json}"

if [ ! -f "$AUTH_SOURCE" ]; then
  echo "⚠️  Auth source not found: $AUTH_SOURCE"
  echo "   Skipping auth profile sync."
  exit 0
fi

SYNCED=0
for agent in "${TEAM_AGENT_IDS[@]}"; do
  target_dir="$OPENCLAW_AGENTS_ROOT/$agent/agent"
  [ -d "$target_dir" ] || continue

  install -d -m 700 "$target_dir"
  install -m 600 "$AUTH_SOURCE" "$target_dir/auth-profiles.json"
  SYNCED=$((SYNCED + 1))
done

echo "🔐 Synced auth profiles to $SYNCED agent dirs from $AUTH_SOURCE"
