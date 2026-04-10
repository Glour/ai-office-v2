#!/bin/bash
# start-team.sh — Start all Personal Team agents
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

# If agents specified as args, use those; otherwise start all
if [ $# -gt 0 ]; then
  AGENTS=("$@")
else
  AGENTS=("${ALL_AGENTS[@]}")
fi

echo "🚀 Starting Personal Team"
echo "================================"
echo "Base directory: $BASE_DIR"
echo "Agents: ${AGENTS[*]}"
echo ""

STARTED=0
FAILED=0
SKIPPED=0

for agent in "${AGENTS[@]}"; do
  AGENT_DIR="$BASE_DIR/$agent"

  # Check workspace exists
  if [ ! -d "$AGENT_DIR" ]; then
    echo "⚠️  $agent: workspace not found at $AGENT_DIR — skipping"
    echo "   Run: bash scripts/deploy-team.sh"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Check config exists
  if [ ! -f "$OPENCLAW_DIR/agents/$agent/openclaw.json" ]; then
    echo "⚠️  $agent: config not found at $OPENCLAW_DIR/agents/$agent/openclaw.json — skipping"
    echo "   Copy and edit: cp $AGENT_DIR/openclaw.json.example $OPENCLAW_DIR/agents/$agent/openclaw.json"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo -n "🚀 Starting $agent... "
  if cd "$AGENT_DIR" && openclaw gateway start --detach 2>/dev/null; then
    echo "✅"
    STARTED=$((STARTED + 1))
  else
    # openclaw gateway start might not have --detach, try without
    if cd "$AGENT_DIR" && openclaw gateway start &>/dev/null & then
      echo "✅ (background)"
      STARTED=$((STARTED + 1))
    else
      echo "❌ failed"
      FAILED=$((FAILED + 1))
    fi
  fi

  # Small delay to avoid port conflicts during startup
  sleep 1
done

echo ""
echo "================================"
echo "Started:  $STARTED"
echo "Skipped:  $SKIPPED"
echo "Failed:   $FAILED"
echo ""

if [ $STARTED -gt 0 ]; then
  echo "✅ Agents are running!"
  echo ""
  echo "Check status:"
  for agent in "${AGENTS[@]}"; do
    AGENT_DIR="$BASE_DIR/$agent"
    [ -d "$AGENT_DIR" ] && echo "  cd $AGENT_DIR && openclaw status"
  done
fi

if [ $FAILED -gt 0 ]; then
  echo ""
  echo "⚠️  Some agents failed to start. Check logs:"
  echo "  cd ${BASE_DIR}/<agent> && openclaw gateway logs"
fi
