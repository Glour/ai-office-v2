#!/usr/bin/env bash
# render-openclaw-configs.sh — render OpenClaw configs for all team agents

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${1:-$ROOT_DIR/.env}"
source "$ROOT_DIR/team-config.sh"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Env file not found: $ENV_FILE" >&2
  echo "Set it up with: cp .env.example .env" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

OPENCLAW_PROFILE="${OPENCLAW_PROFILE:-default}"
OPENCLAW_DIR="$(team_openclaw_state_dir "$OPENCLAW_PROFILE")"
AGENTS=( $(team_active_agent_ids) )

command -v python3 >/dev/null 2>&1 || {
  echo "❌ python3 is required for config rendering." >&2
  exit 1
}

is_real_secret() {
  local value="${1:-}"
  [[ -n "$value" ]] || return 1
  [[ "$value" != your-* ]] || return 1
  [[ "$value" != *placeholder* ]] || return 1
  [[ "$value" != *changeme* ]] || return 1
  return 0
}

normalize_bool() {
  case "$(printf '%s' "${1:-false}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on)
      printf 'true'
      ;;
    *)
      printf 'false'
      ;;
  esac
}

resolve_bot_token() {
  local agent_id="${1:-}"
  local upper_agent token_var
  local fallback="${RENDER_TELEGRAM_TOKEN_FALLBACK_ALLOWED:-false}"

  [ -n "$agent_id" ] || return 1
  upper_agent="$(printf '%s' "$agent_id" | tr '[:lower:]' '[:upper:]')"
  token_var="${upper_agent}_TELEGRAM_BOT_TOKEN"

  local token="${!token_var:-}"
  if is_real_secret "$token"; then
    printf '%s' "$token"
    return 0
  fi

  if [ "$(normalize_bool "$fallback")" = "true" ] && is_real_secret "${TELEGRAM_BOT_TOKEN:-}"; then
    printf '%s' "${TELEGRAM_BOT_TOKEN}"
    return 0
  fi

  return 1
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
  DEFAULT_TEAM_MODEL="openai-codex/gpt-5.5"
elif [[ "$OPENCLAW_AUTH_CHOICE" == "openai-api-key" ]]; then
  DEFAULT_TEAM_MODEL="openai/gpt-5.4"
else
  DEFAULT_TEAM_MODEL="openai-codex/gpt-5.5"
fi
export MAIN_MODEL="${MAIN_MODEL:-$DEFAULT_TEAM_MODEL}"
export AGENT_MODEL="${AGENT_MODEL:-$DEFAULT_TEAM_MODEL}"
export THINKING_DEFAULT="${THINKING_DEFAULT:-high}"
export REASONING_DEFAULT="${REASONING_DEFAULT:-on}"
export EMBEDDING_PROVIDER="${EMBEDDING_PROVIDER:-openai}"
export EMBEDDING_MODEL="${EMBEDDING_MODEL:-text-embedding-3-small}"
ACTIVE_AGENT_IDS_JSON="$(printf '%s\n' "${AGENTS[@]}" | python3 -c 'import json,sys; print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))')"

filter_remote_agents() {
  local config_path="$1"
  local self_agent="$2"

  ACTIVE_AGENT_IDS_JSON="$ACTIVE_AGENT_IDS_JSON" python3 - "$config_path" "$self_agent" <<'PY'
import json
import os
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
self_agent = sys.argv[2]
active_ids = set(json.loads(os.environ["ACTIVE_AGENT_IDS_JSON"]))

data = json.loads(config_path.read_text(encoding="utf-8"))
agents = data.get("agents") or {}
remote_agents = agents.get("remoteAgents")

if isinstance(remote_agents, dict):
    agents["remoteAgents"] = {
        agent_id: payload
        for agent_id, payload in remote_agents.items()
        if agent_id in active_ids and agent_id != self_agent
    }
    data["agents"] = agents
    config_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

STRICT_TOKENS="$(normalize_bool "${STRICT_TELEGRAM_TOKENS:-true}")"
if [ "$STRICT_TOKENS" = "true" ]; then
  export RENDER_TELEGRAM_TOKEN_FALLBACK_ALLOWED="false"
else
  export RENDER_TELEGRAM_TOKEN_FALLBACK_ALLOWED="${RENDER_TELEGRAM_TOKEN_FALLBACK_ALLOWED:-false}"
fi

MISSING_TOKEN_AGENTS=()
TOKEN_SPECS=""

for agent in "${AGENTS[@]}"; do
  TOKEN_VAR="$(printf '%s' "$agent" | tr '[:lower:]' '[:upper:]')_TELEGRAM_BOT_TOKEN"
  TOKEN_VALUE="$(resolve_bot_token "$agent" || true)"

  if [[ -n "$TOKEN_VALUE" ]]; then
    export "$TOKEN_VAR=$TOKEN_VALUE"
    TOKEN_SPECS="${TOKEN_SPECS}${agent}"$'\t'"${TOKEN_VALUE}"$'\n'
  else
    MISSING_TOKEN_AGENTS+=("$agent")
  fi
done

DUPLICATE_TOKEN_AGENTS=()
while IFS= read -r duplicate_entry; do
  [ -n "$duplicate_entry" ] || continue
  DUPLICATE_TOKEN_AGENTS+=("$duplicate_entry")
done < <(
  TOKEN_SPECS_PAYLOAD="$TOKEN_SPECS" python3 - <<'PY'
import collections
import os

items = []
for raw_line in os.environ.get("TOKEN_SPECS_PAYLOAD", "").splitlines():
    line = raw_line.strip()
    if not line:
        continue
    agent, token = line.split("\t", 1)
    items.append((agent, token))

owners = collections.defaultdict(list)
for agent, token in items:
    owners[token].append(agent)

for token, agents in owners.items():
    if len(agents) > 1:
        print(", ".join(agents))
PY
)

if [ "${#MISSING_TOKEN_AGENTS[@]}" -gt 0 ] || [ "${#DUPLICATE_TOKEN_AGENTS[@]}" -gt 0 ]; then
  echo ""
  if [ "${#MISSING_TOKEN_AGENTS[@]}" -gt 0 ]; then
    echo "❌ Missing Telegram bot tokens for active agents:"
    for agent in "${MISSING_TOKEN_AGENTS[@]}"; do
      echo "  - ${agent} (set ${agent^^}_TELEGRAM_BOT_TOKEN)"
    done
  fi
  if [ "${#DUPLICATE_TOKEN_AGENTS[@]}" -gt 0 ]; then
    echo "❌ Duplicate Telegram bot tokens detected (one token per bot):"
    for entry in "${DUPLICATE_TOKEN_AGENTS[@]}"; do
      echo "  - $entry"
    done
    echo "   Fix by assigning unique tokens in .env."
  fi
  echo ""
  echo "Set bot tokens, or if you must temporarily migrate:"
  echo "  RENDER_TELEGRAM_TOKEN_FALLBACK_ALLOWED=true"
  echo "but this is not safe for parallel runs."
  exit 1
fi

for agent in "${AGENTS[@]}"; do
  TOKEN_VAR="$(printf '%s' "$agent" | tr '[:lower:]' '[:upper:]')_TELEGRAM_BOT_TOKEN"
  TOKEN_VALUE="${!TOKEN_VAR:-}"

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

  filter_remote_agents "$DST" "$agent"

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
