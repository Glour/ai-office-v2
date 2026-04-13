#!/usr/bin/env bash
# send-team-topic.sh — publish a message into the configured Telegram topic for a team agent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="${TEAM_REPO_DIR:-$DEFAULT_REPO_DIR}"

if [ ! -f "$REPO_DIR/team-config.sh" ] && [ -f "/root/home/agent-team/team-config.sh" ]; then
  REPO_DIR="/root/home/agent-team"
fi

if [ ! -f "$REPO_DIR/team-config.sh" ]; then
  echo "team-config.sh not found; set TEAM_REPO_DIR or place script inside the repo" >&2
  exit 78
fi

source "$REPO_DIR/team-config.sh"

ENV_FILE="${ENV_FILE:-$REPO_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

OPENCLAW_PROFILE="${OPENCLAW_PROFILE:-personal}"
OPENCLAW_BIN="${OPENCLAW_BIN:-$(command -v openclaw || true)}"
TEAM_TELEGRAM_GROUP_ID="${TEAM_TELEGRAM_GROUP_ID:-${TELEGRAM_TEAM_GROUP_ID:-}}"

usage() {
  cat <<'EOF'
Usage:
  send-team-topic.sh <agent-id> <message...>
  printf 'text' | send-team-topic.sh <agent-id>
EOF
}

resolve_topic_id() {
  case "$1" in
    orchestrator) printf '%s' "${ORCHESTRATOR_TOPIC_ID:-}" ;;
    frontend) printf '%s' "${FRONTEND_TOPIC_ID:-}" ;;
    backend) printf '%s' "${BACKEND_TOPIC_ID:-}" ;;
    design) printf '%s' "${DESIGN_TOPIC_ID:-}" ;;
    content) printf '%s' "${CONTENT_TOPIC_ID:-}" ;;
    media) printf '%s' "${MEDIA_TOPIC_ID:-}" ;;
    research) printf '%s' "${RESEARCH_TOPIC_ID:-}" ;;
    *) return 1 ;;
  esac
}

if [ $# -lt 1 ]; then
  usage >&2
  exit 64
fi

agent_id="$1"
shift || true

if ! team_agent_is_valid_id "$agent_id"; then
  echo "Unknown agent id: $agent_id" >&2
  exit 64
fi

if [ -n "$*" ]; then
  message="$*"
else
  message="$(cat)"
fi

if [ -z "${message//[$'\t\r\n ']}" ]; then
  echo "Message is empty" >&2
  exit 64
fi

if [ -z "${OPENCLAW_BIN:-}" ]; then
  echo "openclaw binary not found in PATH" >&2
  exit 69
fi

if [ -z "${TEAM_TELEGRAM_GROUP_ID:-}" ]; then
  echo "TEAM_TELEGRAM_GROUP_ID is not configured" >&2
  exit 78
fi

topic_id="$(resolve_topic_id "$agent_id" || true)"
if [ -z "${topic_id:-}" ]; then
  echo "Topic id is not configured for $agent_id" >&2
  exit 78
fi

"$OPENCLAW_BIN" --profile "$OPENCLAW_PROFILE" message send \
  --channel telegram \
  --account "$agent_id" \
  --target "$TEAM_TELEGRAM_GROUP_ID" \
  --thread-id "$topic_id" \
  --message "$message" \
  --json
