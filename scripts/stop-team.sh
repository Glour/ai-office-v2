#!/bin/bash
# stop-team.sh — Stop all Personal Team agents

set -e

BASE_DIR="${OPENCLAW_AGENTS_DIR:-$HOME/openclaw-agents-personal}"
OPENCLAW_DIR="${OPENCLAW_DIR:-$HOME/.openclaw-personal}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_DIR/team-config.sh"

ENV_FILE="${ENV_FILE:-$REPO_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

BASE_DIR="${OPENCLAW_AGENTS_DIR:-$BASE_DIR}"
OPENCLAW_DIR="${OPENCLAW_DIR:-$OPENCLAW_DIR}"
export OPENCLAW_DIR

ALL_AGENTS=( $(team_agent_ids) )

# If agents specified as args, use those; otherwise stop all
if [ $# -gt 0 ]; then
  AGENTS=("$@")
else
  AGENTS=("${ALL_AGENTS[@]}")
fi

echo "🛑 Stopping Personal Team"
echo "================================"
echo "Agents: ${AGENTS[*]}"
echo ""

STOPPED=0
SKIPPED=0

for agent in "${AGENTS[@]}"; do
  AGENT_DIR="$BASE_DIR/$agent"

  if [ ! -d "$AGENT_DIR" ]; then
    echo "⚠️  $agent: workspace not found — skipping"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo -n "🔴 Stopping $agent... "
  if cd "$AGENT_DIR" && openclaw gateway stop 2>/dev/null; then
    echo "✅"
    STOPPED=$((STOPPED + 1))
  else
    echo "⚠️  (may not have been running)"
    SKIPPED=$((SKIPPED + 1))
  fi
done

echo ""
echo "================================"
echo "Stopped: $STOPPED"
echo "Skipped: $SKIPPED"
echo ""
echo "To restart: bash scripts/start-team.sh"
