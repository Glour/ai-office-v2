#!/usr/bin/env bash
# bootstrap-managed-team.sh — end-to-end managed-bot bootstrap + team startup
#
# Что делает:
# 1) Проверяет manager bot (can_manage_bots)
# 2) Генерит ссылки для создания субботов через /newbot
# 3) При необходимости ждёт managed_bot updates и вытягивает токены через getManagedBotToken
# 4) Рендерит openclaw конфиги, разворачивает воркспейсы и запускает агентов

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

source "$REPO_DIR/team-config.sh"

ENV_FILE="${ENV_FILE:-$REPO_DIR/.env}"
MANAGER_BOT_TOKEN="${MANAGER_BOT_TOKEN:-}"
MANAGER_BOT_USERNAME="${MANAGER_BOT_USERNAME:-}"
TELEGRAM_TIMEOUT_SECONDS="${TELEGRAM_TIMEOUT_SECONDS:-20}"
WAIT_FOR_TOKENS="${WAIT_FOR_TOKENS:-true}"
START_AGENTS="${START_AGENTS:-true}"
START_ORCHESTRATOR_ONLY="${START_ORCHESTRATOR_ONLY:-false}"
OPENCLAW_DIR="${OPENCLAW_DIR:-$HOME/.openclaw-personal}"
OPENCLAW_AGENTS_DIR="${OPENCLAW_AGENTS_DIR:-$HOME/openclaw-agents-personal}"
TEAM_BOT_PREFIX="${TEAM_BOT_PREFIX:-alex}"
WORKSPACE_PATH="${WORKSPACE_PATH:-$OPENCLAW_AGENTS_DIR}"
AUTO_START_DELAY="${AUTO_START_DELAY:-2}"
POLL_SECONDS="${POLL_SECONDS:-5}"

REQUIRED_CLI=("bash" "curl")
for cmd in "${REQUIRED_CLI[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "❌ Required tool not found: $cmd"
    exit 1
  }
done
command -v python3 >/dev/null 2>&1 || {
  echo "⚠️ python3 not found — некоторые функции будут ограничены."
}

TEAM_AGENTS=()
while IFS= read -r agent; do
  [ -z "$agent" ] && continue
  TEAM_AGENTS+=("$agent")
done < <(team_agent_ids)

TEAM_NAMES=()
while IFS= read -r name; do
  [ -z "$name" ] && continue
  TEAM_NAMES+=("$name")
done < <(team_agent_names)
if [ "${#TEAM_AGENTS[@]}" -ne "${#TEAM_NAMES[@]}" ]; then
  echo "⚠️ TEAM_AGENT_IDS и TEAM_AGENT_NAMES длины не совпадают."
fi

usage() {
  cat <<'EOF'
Usage:
  bootstrap-managed-team.sh [options]

Options:
  --env-file PATH            Path to .env (default: project/.env)
  --manager-token TOKEN      Manager bot token (or set MANAGER_BOT_TOKEN)
  --manager-username NAME    Manager bot username (or set MANAGER_BOT_USERNAME)
  --openclaw-dir PATH        OpenClaw config dir (default: ~/.openclaw-personal)
  --agents-dir PATH          OpenClaw agents workspaces (default: ~/openclaw-agents-personal)
  --workspace-path PATH      WORKSPACE_PATH for generated configs
  --team-prefix PREFIX       Base prefix for generated bot usernames
  --no-wait                  Do not wait for managed bot creation events
  --no-start                 Render/deploy only, do not start agents
  --orchestrator-only        Start only orchestrator after bootstrapping
  --non-interactive          Never prompt for tokens (requires all tokens already in .env)
  --help                     Show usage
EOF
}

NON_INTERACTIVE=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    --manager-token)
      MANAGER_BOT_TOKEN="$2"
      shift 2
      ;;
    --manager-username)
      MANAGER_BOT_USERNAME="$2"
      shift 2
      ;;
    --openclaw-dir)
      OPENCLAW_DIR="$2"
      shift 2
      ;;
    --agents-dir)
      OPENCLAW_AGENTS_DIR="$2"
      shift 2
      ;;
    --workspace-path)
      WORKSPACE_PATH="$2"
      shift 2
      ;;
    --team-prefix)
      TEAM_BOT_PREFIX="$2"
      shift 2
      ;;
    --no-wait)
      WAIT_FOR_TOKENS="false"
      shift
      ;;
    --no-start)
      START_AGENTS="false"
      shift
      ;;
    --orchestrator-only)
      START_ORCHESTRATOR_ONLY="true"
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "❌ Unknown arg: $1"
      usage
      exit 1
      ;;
  esac
done

if [ ! -f "$ENV_FILE" ]; then
  if [ -f "$ENV_FILE.example" ]; then
    cp "$ENV_FILE.example" "$ENV_FILE"
  else
    touch "$ENV_FILE"
  fi
fi

set -a
source "$ENV_FILE"
set +a

if [ -z "$MANAGER_BOT_TOKEN" ] && [ -n "${ORCHESTRATOR_TELEGRAM_BOT_TOKEN:-}" ]; then
  MANAGER_BOT_TOKEN="$ORCHESTRATOR_TELEGRAM_BOT_TOKEN"
fi

if [ -z "${MANAGER_BOT_TOKEN:-}" ]; then
  echo "❌ MANAGER_BOT_TOKEN не задан."
  echo "Укажи через --manager-token или в .env как MANAGER_BOT_TOKEN."
  exit 1
fi

API_BASE="https://api.telegram.org/bot${MANAGER_BOT_TOKEN}"

tg_api() {
  local method="$1"
  local params="$2"
  local url="$API_BASE/$method"
  if [ -n "$params" ]; then
    url="${url}?${params}"
  fi
  curl -sS --max-time "$TELEGRAM_TIMEOUT_SECONDS" "$url"
}

json_ok() {
  local payload="$1"
  python3 - "$payload" <<'PY'
import json,sys
obj = json.loads(sys.argv[1])
print("ok" if obj.get("ok") else "no")
PY
}

json_result() {
  local payload="$1"
  python3 - "$payload" <<'PY'
import json,sys
obj = json.loads(sys.argv[1])
if not obj.get("ok"):
  sys.exit(1)
print(json.dumps(obj.get("result")))
PY
}

set_env_value() {
  local key="$1"
  local value="$2"

  if grep -qE "^${key}=" "$ENV_FILE" 2>/dev/null; then
    sed -i '' "s#^${key}=.*#${key}=${value}#" "$ENV_FILE" 2>/dev/null || \
    sed -i "s#^${key}=.*#${key}=${value}#" "$ENV_FILE"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

urlencode() {
  python3 - "$1" <<'PY'
import urllib.parse,sys
print(urllib.parse.quote(sys.argv[1]))
PY
}

slugify_bot_username() {
  local raw="$1"
  local slug

  slug="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_]/_/g')"
  slug="${slug#_}"
  if [ -z "$slug" ]; then
    slug="agent"
  fi
  if [[ "$slug" =~ ^[0-9] ]]; then
    slug="bot_${slug}"
  fi
  if [ ${#slug} -gt 27 ]; then
    slug="${slug:0:27}"
  fi
  if [ ${#slug} -lt 5 ]; then
    slug="${slug}_bot"
  elif [[ "$slug" != *_bot ]]; then
    slug="${slug}_bot"
  fi
  echo "$slug"
}

verify_manager() {
  local resp
  local username
  local can_manage

  resp="$(tg_api getMe "")"
  if [ "$(json_ok "$resp")" != "ok" ]; then
    echo "❌ Менеджер-бот не проходит Telegram API проверку (некорректный токен)."
    exit 1
  fi

  username="$(python3 - "$resp" <<'PY'
import json,sys
obj = json.loads(sys.argv[1])
print((obj.get("result",{}) or {}).get("username",""))
PY
)"
  can_manage="$(python3 - "$resp" <<'PY'
import json,sys
obj = json.loads(sys.argv[1])
val = (obj.get("result",{}) or {}).get("can_manage_bots", False)
print("true" if bool(val) else "false")
PY
)"
  if [ "$can_manage" != "True" ] && [ "$can_manage" != "true" ]; then
    echo "❌ can_manage_bots = false. Включи режим управления ботами в @BotFather."
    exit 1
  fi

  if [ -z "$MANAGER_BOT_USERNAME" ] && [ -n "$username" ]; then
    MANAGER_BOT_USERNAME="$username"
  fi

  echo "✅ Manager: @$MANAGER_BOT_USERNAME (can_manage_bots=true)"
}

load_pending_tokens() {
  if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
  fi
}

declare -A EXPECTED_USERNAME_TO_AGENT
declare -A EXPECTED_ID_TO_AGENT
MISSING_AGENTS=()
MISSING_VARS=()
AGENT_USERNAME_MAP=()

missing_tokens=0
for i in "${!TEAM_AGENTS[@]}"; do
  agent="${TEAM_AGENTS[$i]}"
  var="${agent^^}_TELEGRAM_BOT_TOKEN"
  curr_value="${!var:-}"
  if [ -z "$curr_value" ] || [[ "$curr_value" == your-* ]] ; then
    MISSING_AGENTS+=("$agent")
    MISSING_VARS+=("$var")
    missing_tokens=$((missing_tokens + 1))
  fi
done

if [ ${#MISSING_AGENTS[@]} -eq 0 ]; then
  echo "✅ В .env уже есть все токены агентов."
else
  echo "⚠️ Нет токенов для: ${MISSING_AGENTS[*]}"
fi

for i in "${!TEAM_AGENTS[@]}"; do
  agent="${TEAM_AGENTS[$i]}"
  name="${TEAM_NAMES[$i]:-${agent}}"
  suggest="$(slugify_bot_username "${TEAM_BOT_PREFIX}-${agent}-bot")"
  AGENT_USERNAME_MAP+=("${agent}|${suggest}|${name}")
done

build_expected_maps() {
  for row in "${AGENT_USERNAME_MAP[@]}"; do
    agent="${row%%|*}"
    rest="${row#*|}"
    username="${rest%%|*}"
    EXPECTED_USERNAME_TO_AGENT["$username"]="$agent"
  done
}
build_expected_maps

print_invitation_links() {
  if [ -z "$MANAGER_BOT_USERNAME" ]; then
    verify_manager
  fi

  if [ "${#MISSING_AGENTS[@]}" -eq 0 ]; then
    echo "✅ Все токены уже заданы — приглашения не нужны."
    return 0
  fi

  echo ""
  echo "🧭 Ссылки для создания/пересоздания ботов (через менеджер):"
  for agent in "${MISSING_AGENTS[@]}"; do
    display_name=""
    username=""
    for row in "${AGENT_USERNAME_MAP[@]}"; do
      if [ "${row%%|*}" = "$agent" ]; then
        rest="${row#*|}"
        username="${rest%%|*}"
        display_name="${rest#*|}"
      fi
    done
    display_name="${display_name:-${agent}}"
    username="${username:-$agent}"
    display_encoded="$(urlencode "$display_name")"
    echo "  $agent -> https://t.me/newbot/${MANAGER_BOT_USERNAME}/${username}?name=${display_encoded}"
  done
}

extract_managed_events() {
  local payload="$1"
  python3 - "$payload" <<'PY'
import json
import sys

obj = json.loads(sys.argv[1])
results = obj.get("result", [])
if not isinstance(results, list):
  raise SystemExit(0)

for upd in results:
  mb = upd.get("managed_bot")
  if not isinstance(mb, dict):
    continue
  user_id = mb.get("user_id", mb.get("id"))
  if not isinstance(user_id, int):
    continue

  username = mb.get("username") or mb.get("user", {}).get("username")
  first_name = mb.get("first_name") or mb.get("user", {}).get("first_name")
  print(f"{user_id}|{username}|{first_name}")
PY
}

extract_update_offset() {
  local payload="$1"
  python3 - "$payload" <<'PY'
import json
import sys

obj = json.loads(sys.argv[1])
updates = obj.get("result", [])
if not updates:
  print(0)
  raise SystemExit(0)
print(max((u.get("update_id", 0) for u in updates)) + 1)
PY
}

fetch_managed_token() {
  local user_id="$1"
  local token_resp
  token_resp="$(tg_api getManagedBotToken "user_id=${user_id}")"
  if [ "$(json_ok "$token_resp")" != "ok" ]; then
    return 1
  fi

  token="$(python3 - "$token_resp" <<'PY'
import json,sys
obj = json.loads(sys.argv[1])
if not obj.get("ok"):
  sys.exit(1)
res = obj.get("result")
if isinstance(res, str):
  print(res)
else:
  print(res.get("token", ""))
PY
)"
  echo "$token"
}

update_env_tokens_from_updates() {
  local payload="$1"
  local offset="$2"
  local found=0
  local line

  while IFS='|' read -r user_id username first_name; do
    [ -z "$user_id" ] && continue

    local key_for_agent=""
    if [ -n "$username" ] && [ -n "${EXPECTED_USERNAME_TO_AGENT[$username]:-}" ]; then
      key_for_agent="${EXPECTED_USERNAME_TO_AGENT[$username]}"
    elif [ -n "${EXPECTED_ID_TO_AGENT[$user_id]:-}" ]; then
      key_for_agent="${EXPECTED_ID_TO_AGENT[$user_id]}"
    fi

    if [ -z "$key_for_agent" ]; then
      if [ "${#MISSING_AGENTS[@]}" -eq 1 ]; then
        key_for_agent="${MISSING_AGENTS[0]}"
      else
        echo "⚠️ Получено managed_bot для @$username ($user_id), но я не знаю как сопоставить с конкретным агентом."
        continue
      fi
    fi

    token="$(fetch_managed_token "$user_id" || true)"
    if [ -z "$token" ] || [ "$token" = "" ]; then
      echo "❌ Не удалось получить токен для $key_for_agent через getManagedBotToken."
      continue
    fi

    token="${token%\"}"
    token="${token#\"}"
    var_name="${key_for_agent^^}_TELEGRAM_BOT_TOKEN"
    set_env_value "$var_name" "$token"
    echo "✅ Получен токен: $key_for_agent -> ${var_name}"
    EXPECTED_ID_TO_AGENT["$user_id"]="$key_for_agent"
    found=1
  done < <(extract_managed_events "$payload")

  if [ "$found" -eq 1 ]; then
    source "$ENV_FILE"
  fi

  local remaining=0
  for agent in "${MISSING_AGENTS[@]}"; do
    var="${agent^^}_TELEGRAM_BOT_TOKEN"
    [ -n "${!var:-}" ] && [ "${!var}" != " " ] || remaining=$((remaining+1))
  done

  return 0
}

wait_for_missing_tokens() {
  local offset=0
  local deadline
  deadline="$(date +%s)"

  # Skip old updates if they exist
  initial="$(tg_api getUpdates "limit=100")"
  if [ "$(json_ok "$initial")" = "ok" ]; then
    offset="$(extract_update_offset "$initial")"
  fi

  if [ "${#MISSING_AGENTS[@]}" -eq 0 ]; then
    return 0
  fi

  echo ""
  echo "🟡 Жду managed_bot события для недостающих агентов. Откройте ссылки и создайте ботов."
  echo "   Если токены должны быть выданы сразу и уже есть, можно использовать --no-wait."

  for (( ; ; )); do
    updates="$(tg_api getUpdates "offset=$offset&timeout=${POLL_SECONDS}&allowed_updates=%5B%22managed_bot%22%5D")"
    if [ "$(json_ok "$updates")" = "ok" ]; then
      new_offset="$(extract_update_offset "$updates")"
      if [ "$new_offset" -gt 0 ]; then
        offset="$new_offset"
        # shellcheck disable=SC2034
        has_new=1
        update_env_tokens_from_updates "$updates" "$offset" || true
      fi
    fi

    # recompute missing
    pending=0
    for agent in "${MISSING_AGENTS[@]}"; do
      var="${agent^^}_TELEGRAM_BOT_TOKEN"
      if [ -z "${!var:-}" ] || [[ "${!var}" == your-* ]]; then
        pending=$((pending + 1))
      fi
    done

    if [ "$pending" -eq 0 ]; then
      echo "✅ Все токены получены."
      return 0
    fi

    if [ "$WAIT_FOR_TOKENS" = "false" ] || [ "$NON_INTERACTIVE" = true ]; then
      break
    fi

    if [ "$(( $(date +%s) - deadline ))" -ge 900 ]; then
      echo "⏱ Timeout 15m: не все токены собраны."
      break
    fi

    sleep "$POLL_SECONDS"
  done
}

manual_fill_missing_tokens() {
  if [ "${#MISSING_AGENTS[@]}" -eq 0 ]; then
    return
  fi

  for agent in "${MISSING_AGENTS[@]}"; do
    var="${agent^^}_TELEGRAM_BOT_TOKEN"
    if [ -n "${!var:-}" ] && [ "${!var}" != "your-placeholder" ]; then
      continue
    fi

    if [ "$NON_INTERACTIVE" = true ]; then
      echo "❌ Нет токена для ${agent}. Укажи --non-interactive нельзя использовать без полного .env."
      exit 1
    fi

    read -r -p "Вставь токен для ${agent} (${var}): " token_value
    [ -n "$token_value" ] || continue
    set_env_value "$var" "$token_value"
  done

  source "$ENV_FILE"
}

render_and_deploy() {
  # keep namespace isolation
  set_env_value "OPENCLAW_DIR" "$OPENCLAW_DIR"
  set_env_value "OPENCLAW_AGENTS_DIR" "$OPENCLAW_AGENTS_DIR"
  set_env_value "WORKSPACE_PATH" "$WORKSPACE_PATH"

  export OPENCLAW_DIR OPENCLAW_AGENTS_DIR

  bash scripts/render-openclaw-configs.sh "$ENV_FILE"
  bash scripts/deploy-team.sh --force
}

start_runtime() {
  if [ "$START_AGENTS" != "true" ]; then
    echo "ℹ️ START_AGENTS=false: запуск агентов пропущен."
    return
  fi

  export OPENCLAW_DIR OPENCLAW_AGENTS_DIR
  if [ "$START_ORCHESTRATOR_ONLY" = "true" ]; then
    bash scripts/start-team.sh orchestrator
  else
    bash scripts/start-team.sh
  fi
}

verify_manager
load_pending_tokens
print_invitation_links

if [ "$WAIT_FOR_TOKENS" = "true" ] && [ "${#MISSING_AGENTS[@]}" -gt 0 ] && [ "$NON_INTERACTIVE" = false ]; then
  wait_for_missing_tokens
fi

manual_fill_missing_tokens
render_and_deploy
start_runtime

echo ""
echo "✅ bootstrap завершён."
