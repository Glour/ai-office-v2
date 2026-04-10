#!/usr/bin/env bash
# render-openclaw-configs.sh — render OpenClaw configs for all personal agents

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${1:-$ROOT_DIR/.env}"
source "$ROOT_DIR/team-config.sh"
OPENCLAW_DIR="${OPENCLAW_DIR:-$HOME/.openclaw-personal}"
AGENTS=( $(team_agent_ids) )

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Env file not found: $ENV_FILE" >&2
  echo "Set it up with: cp .env.example .env" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

export OPENCLAW_AGENTS_DIR="${OPENCLAW_AGENTS_DIR:-$HOME/openclaw-agents-personal}"
export WORKSPACE_PATH="${WORKSPACE_PATH:-$OPENCLAW_AGENTS_DIR}"
export MAIN_MODEL="${MAIN_MODEL:-anthropic/claude-opus-4-5}"
export AGENT_MODEL="${AGENT_MODEL:-anthropic/claude-sonnet-4-5}"
export EMBEDDING_PROVIDER="${EMBEDDING_PROVIDER:-openai}"
export EMBEDDING_MODEL="${EMBEDDING_MODEL:-text-embedding-3-small}"

for agent in "${AGENTS[@]}"; do
  TOKEN_VAR="$(printf '%s' "$agent" | tr '[:lower:]' '[:upper:]')_TELEGRAM_BOT_TOKEN"

  TOKEN_VALUE="${!TOKEN_VAR:-}"

  if [[ -z "$TOKEN_VALUE" ]]; then
    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
      export "$TOKEN_VAR=$TELEGRAM_BOT_TOKEN"
      TOKEN_VALUE="$TELEGRAM_BOT_TOKEN"
    fi
  fi

  SRC="$ROOT_DIR/configs/${agent}.openclaw.json.example"
  DST_DIR="$OPENCLAW_DIR/agents/$agent"
  DST="$DST_DIR/openclaw.json"

  if [[ ! -f "$SRC" ]]; then
    echo "⚠️  Skip: missing $SRC"
    continue
  fi

  mkdir -p "$DST_DIR"

  # shellcheck disable=SC2016
  perl -pe 's/\{\{([A-Z0-9_]+)\}\}/(exists $ENV{$1} ? $ENV{$1} : "")/ge' \
    "$SRC" > "$DST"

  if rg -q '\{\{' "$DST"; then
    echo "⚠️  $agent: config still has unresolved placeholders"
    rg -n '\{\{' "$DST" || true
    continue
  fi

  if [[ -n "${TOKEN_VALUE}" ]]; then
    echo "✅ rendered: $agent (token set)"
  else
    echo "⚠️  rendered: $agent (token missing)"
  fi
done

printf '\nDone. Rendered configs are in %s/agents/<agent>/openclaw.json\n' "$OPENCLAW_DIR"
