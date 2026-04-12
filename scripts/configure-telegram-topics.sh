#!/usr/bin/env bash
# configure-telegram-topics.sh — restrict each team bot to its own Telegram topic

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

OPENCLAW_PROFILE="${OPENCLAW_PROFILE:-personal}"
TEAM_TELEGRAM_GROUP_ID="${TEAM_TELEGRAM_GROUP_ID:-${TELEGRAM_TEAM_GROUP_ID:-}}"

json_bool() {
  if [ "$1" = "true" ]; then
    printf 'true'
  else
    printf 'false'
  fi
}

json_string() {
  printf '"%s"' "$1"
}

if [ -z "${TEAM_TELEGRAM_GROUP_ID:-}" ]; then
  echo "ℹ️  Skip Telegram topic routing: TEAM_TELEGRAM_GROUP_ID is not set."
  exit 0
fi

declare -A TOPIC_IDS=(
  [orchestrator]="${ORCHESTRATOR_TOPIC_ID:-}"
  [frontend]="${FRONTEND_TOPIC_ID:-}"
  [backend]="${BACKEND_TOPIC_ID:-}"
  [design]="${DESIGN_TOPIC_ID:-}"
  [content]="${CONTENT_TOPIC_ID:-}"
  [research]="${RESEARCH_TOPIC_ID:-}"
)

configured=0

echo "🧭 Configuring Telegram topic routing"
echo "Profile: $OPENCLAW_PROFILE"
echo "Group:   $TEAM_TELEGRAM_GROUP_ID"

openclaw --profile "$OPENCLAW_PROFILE" config set \
  "channels.telegram.groupPolicy" \
  "$(json_string disabled)" \
  --strict-json >/dev/null

for agent in $(team_agent_ids); do
  topic_id="${TOPIC_IDS[$agent]:-}"

  if [ -z "$topic_id" ]; then
    echo "  ↺ $agent: no topic id configured, skipping"
    continue
  fi

  openclaw --profile "$OPENCLAW_PROFILE" config set \
    "channels.telegram.accounts.${agent}.groupPolicy" \
    "$(json_string disabled)" \
    --strict-json >/dev/null

  openclaw --profile "$OPENCLAW_PROFILE" config set \
    "channels.telegram.accounts.${agent}.groups[$TEAM_TELEGRAM_GROUP_ID].enabled" \
    "$(json_bool true)" \
    --strict-json >/dev/null

  openclaw --profile "$OPENCLAW_PROFILE" config set \
    "channels.telegram.accounts.${agent}.groups[$TEAM_TELEGRAM_GROUP_ID].groupPolicy" \
    "$(json_string disabled)" \
    --strict-json >/dev/null

  openclaw --profile "$OPENCLAW_PROFILE" config set \
    "channels.telegram.accounts.${agent}.groups[$TEAM_TELEGRAM_GROUP_ID].requireMention" \
    "$(json_bool false)" \
    --strict-json >/dev/null

  openclaw --profile "$OPENCLAW_PROFILE" config set \
    "channels.telegram.accounts.${agent}.groups[$TEAM_TELEGRAM_GROUP_ID].topics[$topic_id].enabled" \
    "$(json_bool true)" \
    --strict-json >/dev/null

  openclaw --profile "$OPENCLAW_PROFILE" config set \
    "channels.telegram.accounts.${agent}.groups[$TEAM_TELEGRAM_GROUP_ID].topics[$topic_id].groupPolicy" \
    "$(json_string open)" \
    --strict-json >/dev/null

  openclaw --profile "$OPENCLAW_PROFILE" config set \
    "channels.telegram.accounts.${agent}.groups[$TEAM_TELEGRAM_GROUP_ID].topics[$topic_id].requireMention" \
    "$(json_bool false)" \
    --strict-json >/dev/null

  echo "  ✓ $agent -> topic $topic_id"
  configured=1
done

if [ "$configured" -eq 0 ]; then
  echo "ℹ️  No topic ids were configured. Gateway restart skipped."
  exit 0
fi

echo "🔄 Restarting gateway to apply routing changes..."
openclaw --profile "$OPENCLAW_PROFILE" gateway restart >/dev/null
echo "✅ Telegram topic routing applied."
