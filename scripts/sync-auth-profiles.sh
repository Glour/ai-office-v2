#!/usr/bin/env bash
# sync-auth-profiles.sh — copy provider auth profiles into isolated team agents

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

OPENCLAW_PROFILE="${OPENCLAW_PROFILE:-default}"
OPENCLAW_STATE_DIR="$(team_openclaw_state_dir "$OPENCLAW_PROFILE")"
OPENCLAW_AGENTS_ROOT="$OPENCLAW_STATE_DIR/agents"

resolve_auth_source() {
  local candidate

  if [ -n "${OPENCLAW_AUTH_SOURCE:-}" ] && [ -f "${OPENCLAW_AUTH_SOURCE}" ]; then
    printf '%s' "${OPENCLAW_AUTH_SOURCE}"
    return 0
  fi

  for candidate in \
    "$OPENCLAW_AGENTS_ROOT/$(team_orchestrator_id)/agent/auth-profiles.json" \
    "$OPENCLAW_AGENTS_ROOT/main/agent/auth-profiles.json"
  do
    if [ -f "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  while IFS= read -r candidate; do
    [ -f "$candidate" ] || continue
    printf '%s' "$candidate"
    return 0
  done < <(find "$OPENCLAW_AGENTS_ROOT" -mindepth 3 -maxdepth 3 -path '*/agent/auth-profiles.json' -type f 2>/dev/null | sort)

  return 1
}

AUTH_SOURCE="$(resolve_auth_source || true)"

if [ ! -f "$AUTH_SOURCE" ]; then
  echo "⚠️  Auth source not found in $OPENCLAW_AGENTS_ROOT"
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
