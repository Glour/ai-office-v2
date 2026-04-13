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

OPENCLAW_PROFILE="${OPENCLAW_PROFILE:-default}"
TEAM_TELEGRAM_GROUP_ID="${TEAM_TELEGRAM_GROUP_ID:-${TELEGRAM_TEAM_GROUP_ID:-}}"
OWNER_TELEGRAM_ID="${OWNER_TELEGRAM_ID:-}"
PROFILE_CONFIG_PATH="$(team_openclaw_state_dir "$OPENCLAW_PROFILE")/openclaw.json"

gateway_is_running() {
  openclaw --profile "$OPENCLAW_PROFILE" gateway status 2>/dev/null | grep -q 'RPC probe: ok'
}

reload_gateway_service() {
  if [ "$(uname -s)" = "Darwin" ]; then
    launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway" >/dev/null 2>&1 || \
    launchctl kickstart -k "gui/$(id -u)/com.openclaw.gateway" >/dev/null 2>&1 || \
    openclaw --profile "$OPENCLAW_PROFILE" gateway start >/dev/null 2>&1 || true
  elif [ "$(uname -s)" = "Linux" ]; then
    local service_name="openclaw-gateway"
    if [ "$OPENCLAW_PROFILE" != "default" ]; then
      service_name="openclaw-gateway-${OPENCLAW_PROFILE}"
    fi
    systemctl --user restart "${service_name}.service" >/dev/null 2>&1 || \
    openclaw --profile "$OPENCLAW_PROFILE" gateway start >/dev/null 2>&1 || true
  else
    openclaw --profile "$OPENCLAW_PROFILE" gateway start >/dev/null 2>&1 || true
  fi
}

detect_existing_group_id() {
  [ -f "$PROFILE_CONFIG_PATH" ] || return 0
  python3 - "$PROFILE_CONFIG_PATH" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as fh:
    data = json.load(fh)
accounts = (((data.get("channels") or {}).get("telegram") or {}).get("accounts") or {})
for account in accounts.values():
    groups = account.get("groups") or {}
    for group_id in groups.keys():
        print(group_id)
        raise SystemExit(0)
PY
}

detect_existing_topic_id() {
  [ -f "$PROFILE_CONFIG_PATH" ] || return 0
  python3 - "$PROFILE_CONFIG_PATH" "$1" <<'PY'
import json, sys
path, agent = sys.argv[1], sys.argv[2]
with open(path) as fh:
    data = json.load(fh)
account = ((((data.get("channels") or {}).get("telegram") or {}).get("accounts") or {}).get(agent) or {})
groups = account.get("groups") or {}
for group in groups.values():
    topics = group.get("topics") or {}
    for topic_id in topics.keys():
        print(topic_id)
        raise SystemExit(0)
PY
}

detect_existing_owner_telegram_id() {
  python3 - "$OPENCLAW_PROFILE" <<'PY'
import glob, json, os, sys
profile = sys.argv[1]

profile_config = os.path.expanduser(f'~/.openclaw-{profile}/openclaw.json')
if os.path.exists(profile_config):
    with open(profile_config) as fh:
        data = json.load(fh)
    tg = ((data.get("channels") or {}).get("telegram") or {})
    for key in ("groupAllowFrom", "allowFrom"):
        values = tg.get(key) or []
        if values:
            print(values[0])
            raise SystemExit(0)

for path in sorted(glob.glob(os.path.expanduser(f'~/.openclaw-{profile}/agents/*/openclaw.json'))):
    with open(path) as fh:
        data = json.load(fh)
    cfg = ((((data.get("plugins") or {}).get("entries") or {}).get("telegram") or {}).get("config") or {})
    values = cfg.get("authorizedSenders") or []
    if values:
        print(values[0])
        raise SystemExit(0)
PY
}

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

json_array_one() {
  printf '["%s"]' "$1"
}

build_team_route_bindings_json() {
  ROUTE_SPECS_PAYLOAD="$1" TEAM_AGENT_IDS_PAYLOAD="$2" python3 - "$PROFILE_CONFIG_PATH" "$TEAM_TELEGRAM_GROUP_ID" <<'PY'
import json
import os
import sys

config_path, group_id = sys.argv[1], sys.argv[2]
route_specs = [line.strip() for line in os.environ.get("ROUTE_SPECS_PAYLOAD", "").splitlines() if line.strip()]
team_agents = {line.strip() for line in os.environ.get("TEAM_AGENT_IDS_PAYLOAD", "").splitlines() if line.strip()}

pairs = []
for spec in route_specs:
    agent_id, sep, topic_id = spec.partition(":")
    agent_id = agent_id.strip()
    topic_id = topic_id.strip()
    if not sep or not agent_id or not topic_id:
        continue
    pairs.append((agent_id, topic_id))
    team_agents.add(agent_id)

existing = []
try:
    with open(config_path, "r", encoding="utf-8") as fh:
        existing = (json.load(fh).get("bindings") or [])
except FileNotFoundError:
    existing = []

def is_replaced_team_topic_binding(entry):
    if not isinstance(entry, dict):
        return False
    if entry.get("type") != "route":
        return False
    agent_id = str(entry.get("agentId") or "").strip()
    if agent_id not in team_agents:
        return False
    match = entry.get("match") or {}
    if str(match.get("channel") or "").strip() != "telegram":
        return False
    if str(match.get("accountId") or "").strip() != agent_id:
        return False
    peer = match.get("peer") or {}
    if str(peer.get("kind") or "").strip() != "group":
        return False
    peer_id = str(peer.get("id") or "").strip()
    return peer_id.startswith(f"{group_id}:topic:")

def is_replaced_team_dm_binding(entry):
    if not isinstance(entry, dict):
        return False
    if entry.get("type") != "route":
        return False
    agent_id = str(entry.get("agentId") or "").strip()
    if agent_id not in team_agents:
        return False
    match = entry.get("match") or {}
    if str(match.get("channel") or "").strip() != "telegram":
        return False
    if str(match.get("accountId") or "").strip() != agent_id:
        return False
    peer = match.get("peer")
    return not isinstance(peer, dict)

merged = [
    entry for entry in existing
    if not is_replaced_team_topic_binding(entry) and not is_replaced_team_dm_binding(entry)
]
for agent_id in sorted(team_agents):
    merged.append({
        "type": "route",
        "agentId": agent_id,
        "match": {
            "channel": "telegram",
            "accountId": agent_id
        }
    })
for agent_id, topic_id in pairs:
    merged.append({
        "type": "route",
        "agentId": agent_id,
        "match": {
            "channel": "telegram",
            "accountId": agent_id,
            "peer": {
                "kind": "group",
                "id": f"{group_id}:topic:{topic_id}"
            }
        }
    })

print(json.dumps(merged, ensure_ascii=False))
PY
}

resolve_bot_token() {
  case "$1" in
    orchestrator) printf '%s' "${ORCHESTRATOR_TELEGRAM_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}" ;;
    frontend) printf '%s' "${FRONTEND_TELEGRAM_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}" ;;
    backend) printf '%s' "${BACKEND_TELEGRAM_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}" ;;
    design) printf '%s' "${DESIGN_TELEGRAM_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}" ;;
    content) printf '%s' "${CONTENT_TELEGRAM_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}" ;;
    media) printf '%s' "${MEDIA_TELEGRAM_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}" ;;
    research) printf '%s' "${RESEARCH_TELEGRAM_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}" ;;
    *) printf '' ;;
  esac
}

if [ -z "${TEAM_TELEGRAM_GROUP_ID:-}" ]; then
  TEAM_TELEGRAM_GROUP_ID="$(detect_existing_group_id)"
  if [ -n "${TEAM_TELEGRAM_GROUP_ID:-}" ]; then
    echo "ℹ️  TEAM_TELEGRAM_GROUP_ID is not set. Using existing profile group: $TEAM_TELEGRAM_GROUP_ID"
  else
    echo "ℹ️  Skip Telegram topic routing: TEAM_TELEGRAM_GROUP_ID is not set."
    exit 0
  fi
fi

if [ -z "${OWNER_TELEGRAM_ID:-}" ]; then
  OWNER_TELEGRAM_ID="$(detect_existing_owner_telegram_id)"
  if [ -n "${OWNER_TELEGRAM_ID:-}" ]; then
    echo "ℹ️  OWNER_TELEGRAM_ID is not set. Using existing sender id: $OWNER_TELEGRAM_ID"
  fi
fi

resolve_topic_id() {
  case "$1" in
    orchestrator) printf '%s' "${ORCHESTRATOR_TOPIC_ID:-$(detect_existing_topic_id orchestrator)}" ;;
    frontend) printf '%s' "${FRONTEND_TOPIC_ID:-$(detect_existing_topic_id frontend)}" ;;
    backend) printf '%s' "${BACKEND_TOPIC_ID:-$(detect_existing_topic_id backend)}" ;;
    design) printf '%s' "${DESIGN_TOPIC_ID:-$(detect_existing_topic_id design)}" ;;
    content) printf '%s' "${CONTENT_TOPIC_ID:-$(detect_existing_topic_id content)}" ;;
    media) printf '%s' "${MEDIA_TOPIC_ID:-$(detect_existing_topic_id media)}" ;;
    research) printf '%s' "${RESEARCH_TOPIC_ID:-$(detect_existing_topic_id research)}" ;;
    *) printf '' ;;
  esac
}

configured=0
route_specs=""
binding_agents=""

echo "🧭 Configuring Telegram topic routing"
echo "Profile: $OPENCLAW_PROFILE"
echo "Group:   $TEAM_TELEGRAM_GROUP_ID"

openclaw --profile "$OPENCLAW_PROFILE" config set \
  "channels.telegram.defaultAccount" \
  "$(json_string orchestrator)" \
  --strict-json >/dev/null

openclaw --profile "$OPENCLAW_PROFILE" config set \
  "channels.telegram.groupPolicy" \
  "$(json_string disabled)" \
  --strict-json >/dev/null

if [ -n "${OWNER_TELEGRAM_ID:-}" ]; then
  openclaw --profile "$OPENCLAW_PROFILE" config set \
    "channels.telegram.allowFrom" \
    "$(json_array_one "$OWNER_TELEGRAM_ID")" \
    --strict-json >/dev/null
fi

for agent in $(team_agent_ids); do
  topic_id="$(resolve_topic_id "$agent")"
  bot_token="$(resolve_bot_token "$agent")"

  if [ -z "$bot_token" ]; then
    echo "  ↺ $agent: no bot token configured, skipping account"
    continue
  fi

  binding_agents="${binding_agents}${agent}
"

  openclaw --profile "$OPENCLAW_PROFILE" config set \
    "channels.telegram.accounts.${agent}.botToken" \
    "$(json_string "$bot_token")" \
    --strict-json >/dev/null

  openclaw --profile "$OPENCLAW_PROFILE" config set \
    "channels.telegram.accounts.${agent}.dmPolicy" \
    "$(json_string allowlist)" \
    --strict-json >/dev/null

  openclaw --profile "$OPENCLAW_PROFILE" config set \
    "channels.telegram.accounts.${agent}.streaming" \
    "$(json_string partial)" \
    --strict-json >/dev/null

  openclaw --profile "$OPENCLAW_PROFILE" config set \
    "channels.telegram.accounts.${agent}.reactionLevel" \
    "$(json_string minimal)" \
    --strict-json >/dev/null

  openclaw --profile "$OPENCLAW_PROFILE" config set \
    "channels.telegram.accounts.${agent}.commands.nativeSkills" \
    "$(json_bool false)" \
    --strict-json >/dev/null

  openclaw --profile "$OPENCLAW_PROFILE" config set \
    "channels.telegram.accounts.${agent}.groupPolicy" \
    "$(json_string allowlist)" \
    --strict-json >/dev/null

  if [ -n "${OWNER_TELEGRAM_ID:-}" ]; then
    openclaw --profile "$OPENCLAW_PROFILE" config set \
      "channels.telegram.accounts.${agent}.allowFrom" \
      "$(json_array_one "$OWNER_TELEGRAM_ID")" \
      --strict-json >/dev/null

    openclaw --profile "$OPENCLAW_PROFILE" config set \
      "channels.telegram.accounts.${agent}.groupAllowFrom" \
      "$(json_array_one "$OWNER_TELEGRAM_ID")" \
      --strict-json >/dev/null
  fi

  if [ -z "$topic_id" ]; then
    echo "  ✓ $agent: DM account configured (topic not set)"
    configured=1
    continue
  fi

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

  route_specs="${route_specs}${agent}:${topic_id}
"
  echo "  ✓ $agent -> topic $topic_id"
  configured=1
done

if [ "$configured" -eq 0 ]; then
  echo "ℹ️  No Telegram accounts were configured. Gateway reload skipped."
  exit 0
fi

echo "🔗 Syncing route bindings..."
bindings_json="$(build_team_route_bindings_json "$route_specs" "$binding_agents")"
openclaw --profile "$OPENCLAW_PROFILE" config set \
  "bindings" \
  "$bindings_json" \
  --strict-json >/dev/null

if gateway_is_running; then
  echo "🔄 Reloading gateway service to apply routing changes..."
  reload_gateway_service
else
  echo "ℹ️  Gateway is currently down. Routing config was saved; start the gateway to apply it."
fi

echo "✅ Telegram topic routing applied."
