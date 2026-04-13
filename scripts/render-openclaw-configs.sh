#!/usr/bin/env bash
# render-openclaw-configs.sh — render OpenClaw configs for all team agents

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${1:-$ROOT_DIR/.env}"
source "$ROOT_DIR/team-config.sh"
OPENCLAW_DIR="$(team_openclaw_state_dir)"
AGENTS=( $(team_agent_ids) )

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Env file not found: $ENV_FILE" >&2
  echo "Set it up with: cp .env.example .env" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

is_real_secret() {
  local value="${1:-}"
  [[ -n "$value" ]] || return 1
  [[ "$value" != your-* ]] || return 1
  [[ "$value" != *placeholder* ]] || return 1
  [[ "$value" != *changeme* ]] || return 1
  return 0
}

OPENCLAW_AUTH_CHOICE="${OPENCLAW_AUTH_CHOICE:-}"
if [[ -z "$OPENCLAW_AUTH_CHOICE" ]]; then
  if is_real_secret "${OPENAI_API_KEY:-}"; then
    OPENCLAW_AUTH_CHOICE="openai-api-key"
  else
    OPENCLAW_AUTH_CHOICE="openai-codex"
  fi
fi

export OPENCLAW_AGENTS_DIR="${OPENCLAW_AGENTS_DIR:-$(team_openclaw_agents_dir)}"
export WORKSPACE_PATH="${WORKSPACE_PATH:-$OPENCLAW_AGENTS_DIR}"
if [[ "$OPENCLAW_AUTH_CHOICE" == "openai-codex" ]]; then
  DEFAULT_TEAM_MODEL="openai-codex/gpt-5.4"
elif [[ "$OPENCLAW_AUTH_CHOICE" == "openai-api-key" ]]; then
  DEFAULT_TEAM_MODEL="openai/gpt-5.4"
else
  DEFAULT_TEAM_MODEL="openai-codex/gpt-5.4"
fi
export MAIN_MODEL="${MAIN_MODEL:-$DEFAULT_TEAM_MODEL}"
export AGENT_MODEL="${AGENT_MODEL:-$DEFAULT_TEAM_MODEL}"
export THINKING_DEFAULT="${THINKING_DEFAULT:-high}"
export REASONING_DEFAULT="${REASONING_DEFAULT:-on}"
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

  if command -v rg >/dev/null 2>&1; then
    if rg -q '\{\{' "$DST"; then
      echo "⚠️  $agent: config still has unresolved placeholders"
      rg -n '\{\{' "$DST" || true
      continue
    fi
  elif grep -Fq '{{' "$DST"; then
    echo "⚠️  $agent: config still has unresolved placeholders"
    grep -Fn '{{' "$DST"
    continue
  fi

  if [[ -n "${TOKEN_VALUE}" ]]; then
    echo "✅ rendered: $agent (token set)"
  else
    echo "⚠️  rendered: $agent (token missing)"
  fi
done

printf '\nDone. Rendered configs are in %s/agents/<agent>/openclaw.json\n' "$OPENCLAW_DIR"
