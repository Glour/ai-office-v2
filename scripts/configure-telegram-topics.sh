#!/usr/bin/env bash
# configure-telegram-topics.sh — bind each bot to its Telegram topic with safer defaults

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

is_real_secret() {
  local value="${1:-}"
  [[ -n "$value" ]] || return 1
  [[ "$value" != your-* ]] || return 1
  [[ "$value" != *placeholder* ]] || return 1
  [[ "$value" != *changeme* ]] || return 1
  return 0
}

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
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
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
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)

account = ((((data.get("channels") or {}).get("telegram") or {}).get("accounts") or {}).get(sys.argv[2]) or {})
groups = account.get("groups") or {}
for group in groups.values():
    topics = group.get("topics") or {}
    for topic_id in topics.keys():
        print(topic_id)
        raise SystemExit(0)
PY
}

detect_existing_owner_telegram_id() {
  python3 - "$PROFILE_CONFIG_PATH" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1]).expanduser()
if not path.exists():
    raise SystemExit(0)

data = json.loads(path.read_text(encoding="utf-8"))
telegram = ((data.get("channels") or {}).get("telegram") or {})
for key in ("groupAllowFrom", "allowFrom"):
    values = telegram.get(key) or []
    if values:
        print(values[0])
        raise SystemExit(0)

for account in ((telegram.get("accounts") or {}).values()):
    for key in ("groupAllowFrom", "allowFrom"):
        values = account.get(key) or []
        if values:
            print(values[0])
            raise SystemExit(0)
PY
}

detect_existing_bot_token() {
  [ -f "$PROFILE_CONFIG_PATH" ] || return 0
  python3 - "$PROFILE_CONFIG_PATH" "$1" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)

account = ((((data.get("channels") or {}).get("telegram") or {}).get("accounts") or {}).get(sys.argv[2]) or {})
value = account.get("botToken")
if isinstance(value, str) and value.strip():
    print(value.strip())
PY
}

resolve_bot_token() {
  local agent_id="$1"
  local upper_agent token_var token
  upper_agent="$(printf '%s' "$agent_id" | tr '[:lower:]' '[:upper:]')"
  token_var="${upper_agent}_TELEGRAM_BOT_TOKEN"
  token="${!token_var:-}"

  if is_real_secret "$token"; then
    printf '%s' "$token"
    return 0
  fi

  if [ "$(normalize_bool "${TEAM_TELEGRAM_TOKEN_FALLBACK_ALLOWED:-false}")" = "true" ] && \
     is_real_secret "${TELEGRAM_BOT_TOKEN:-}"; then
    printf '%s' "${TELEGRAM_BOT_TOKEN}"
    return 0
  fi

  token="$(detect_existing_bot_token "$agent_id")"
  if is_real_secret "$token"; then
    printf '%s' "$token"
    return 0
  fi

  return 1
}

resolve_topic_id() {
  local upper_agent topic_var configured
  upper_agent="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
  topic_var="${upper_agent}_TOPIC_ID"
  configured="${!topic_var:-}"
  if [ -n "$configured" ]; then
    printf '%s' "$configured"
  else
    detect_existing_topic_id "$1"
  fi
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

TEAM_TELEGRAM_DM_POLICY="${TEAM_TELEGRAM_DM_POLICY:-allowlist}"
TEAM_TELEGRAM_GROUP_SENDER_POLICY="${TEAM_TELEGRAM_GROUP_SENDER_POLICY:-open}"
TEAM_TELEGRAM_ALLOW_OWNER_DM="$(normalize_bool "${TEAM_TELEGRAM_ALLOW_OWNER_DM:-true}")"
TEAM_TELEGRAM_OWNER_ONLY_GROUPS="$(normalize_bool "${TEAM_TELEGRAM_OWNER_ONLY_GROUPS:-false}")"
TEAM_TELEGRAM_ROUTE_DMS_IF_NO_TOPIC="$(normalize_bool "${TEAM_TELEGRAM_ROUTE_DMS_IF_NO_TOPIC:-true}")"
TEAM_TELEGRAM_GROUP_ALLOW_FROM="${TEAM_TELEGRAM_GROUP_ALLOW_FROM:-}"
TEAM_TELEGRAM_STREAMING_MODE="${TEAM_TELEGRAM_STREAMING_MODE:-progress}"

MISSING_TOKEN_AGENTS=()
TOKEN_SPECS=""

for agent in $(team_active_agent_ids); do
  token="$(resolve_bot_token "$agent" || true)"
  if [ -z "$token" ]; then
    MISSING_TOKEN_AGENTS+=("$agent")
    continue
  fi

  export "$(printf '%s' "$agent" | tr '[:lower:]' '[:upper:]')_TELEGRAM_BOT_TOKEN=$token"
  TOKEN_SPECS="${TOKEN_SPECS}${agent}"$'\t'"${token}"$'\n'
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
  echo "❌ Telegram topic routing was not applied."
  for agent in "${MISSING_TOKEN_AGENTS[@]}"; do
    echo "  - missing token: $agent"
  done
  for item in "${DUPLICATE_TOKEN_AGENTS[@]}"; do
    echo "  - duplicate token: $item"
  done
  exit 1
fi

echo "🧭 Configuring Telegram topic routing"
echo "Profile: $OPENCLAW_PROFILE"
echo "Group:   $TEAM_TELEGRAM_GROUP_ID"
echo "DM policy: $TEAM_TELEGRAM_DM_POLICY"
echo "Group sender policy: $TEAM_TELEGRAM_GROUP_SENDER_POLICY"

TEAM_AGENT_IDS_PAYLOAD="$(team_active_agent_ids)"
SUMMARY_PATH="$(mktemp)"

TEAM_AGENT_IDS_PAYLOAD="$TEAM_AGENT_IDS_PAYLOAD" \
TEAM_TELEGRAM_GROUP_ID="$TEAM_TELEGRAM_GROUP_ID" \
OWNER_TELEGRAM_ID="${OWNER_TELEGRAM_ID:-}" \
PROFILE_CONFIG_PATH="$PROFILE_CONFIG_PATH" \
SUMMARY_PATH="$SUMMARY_PATH" \
TEAM_TELEGRAM_DM_POLICY="$TEAM_TELEGRAM_DM_POLICY" \
TEAM_TELEGRAM_GROUP_SENDER_POLICY="$TEAM_TELEGRAM_GROUP_SENDER_POLICY" \
TEAM_TELEGRAM_ALLOW_OWNER_DM="$TEAM_TELEGRAM_ALLOW_OWNER_DM" \
TEAM_TELEGRAM_OWNER_ONLY_GROUPS="$TEAM_TELEGRAM_OWNER_ONLY_GROUPS" \
TEAM_TELEGRAM_ROUTE_DMS_IF_NO_TOPIC="$TEAM_TELEGRAM_ROUTE_DMS_IF_NO_TOPIC" \
TEAM_TELEGRAM_GROUP_ALLOW_FROM="$TEAM_TELEGRAM_GROUP_ALLOW_FROM" \
TEAM_TELEGRAM_STREAMING_MODE="$TEAM_TELEGRAM_STREAMING_MODE" \
python3 - <<'PY'
import json
import os
from pathlib import Path

config_path = Path(os.environ["PROFILE_CONFIG_PATH"]).expanduser()
summary_path = Path(os.environ["SUMMARY_PATH"])
group_id = os.environ["TEAM_TELEGRAM_GROUP_ID"].strip()
owner_id = os.environ.get("OWNER_TELEGRAM_ID", "").strip()
agent_ids = [line.strip() for line in os.environ.get("TEAM_AGENT_IDS_PAYLOAD", "").splitlines() if line.strip()]
dm_policy = (os.environ.get("TEAM_TELEGRAM_DM_POLICY") or "allowlist").strip()
group_sender_policy = (os.environ.get("TEAM_TELEGRAM_GROUP_SENDER_POLICY") or "open").strip()
allow_owner_dm = os.environ.get("TEAM_TELEGRAM_ALLOW_OWNER_DM") == "true"
owner_only_groups = os.environ.get("TEAM_TELEGRAM_OWNER_ONLY_GROUPS") == "true"
route_dms_if_no_topic = os.environ.get("TEAM_TELEGRAM_ROUTE_DMS_IF_NO_TOPIC") == "true"
group_allow_from = [item.strip() for item in (os.environ.get("TEAM_TELEGRAM_GROUP_ALLOW_FROM") or "").split(",") if item.strip()]
streaming_mode = (os.environ.get("TEAM_TELEGRAM_STREAMING_MODE") or "progress").strip()

if dm_policy not in {"pairing", "allowlist", "open", "disabled"}:
    dm_policy = "allowlist"
if group_sender_policy not in {"open", "allowlist", "disabled"}:
    group_sender_policy = "open"
if streaming_mode not in {"off", "partial", "block", "progress"}:
    streaming_mode = "progress"

def normalize_key(value):
    if isinstance(value, str) and len(value) >= 2 and value[0] == value[-1] == '"':
        return value[1:-1]
    return str(value)

def normalize_topics(value):
    if isinstance(value, list):
        return {
            str(idx): entry
            for idx, entry in enumerate(value)
            if entry not in (None, {}, [])
        }
    if not isinstance(value, dict):
        return {}
    result = {}
    for raw_key, raw_entry in value.items():
        result[normalize_key(raw_key)] = raw_entry if isinstance(raw_entry, dict) else {}
    return result

def normalize_groups(value):
    if not isinstance(value, dict):
        return {}
    result = {}
    for raw_key, raw_group in value.items():
        key = normalize_key(raw_key)
        group = raw_group if isinstance(raw_group, dict) else {}
        normalized = dict(group)
        normalized["topics"] = normalize_topics(group.get("topics"))
        existing = result.get(key)
        if isinstance(existing, dict):
            merged = dict(existing)
            merged.update({k: v for k, v in normalized.items() if k != "topics"})
            merged_topics = dict(existing.get("topics") or {})
            merged_topics.update(normalized["topics"])
            merged["topics"] = merged_topics
            result[key] = merged
        else:
            result[key] = normalized
    return result

def first_existing_topic(account):
    groups = normalize_groups(account.get("groups"))
    group = groups.get(group_id) or {}
    topics = group.get("topics") or {}
    for key in topics.keys():
        return str(key)
    return ""

def existing_bot_token(account):
    value = account.get("botToken")
    return value.strip() if isinstance(value, str) else ""

def existing_allow_from(account):
    values = account.get("allowFrom")
    if isinstance(values, list) and values:
        return values
    return None

def dm_allow_from():
    if dm_policy == "open":
        return ["*"]
    if dm_policy == "allowlist" and allow_owner_dm and owner_id:
        return [owner_id]
    return None

def group_allow_from_values():
    if group_sender_policy == "open":
        return None
    if group_allow_from:
        return group_allow_from
    if owner_only_groups and owner_id:
        return [owner_id]
    return ["*"]

config = {}
if config_path.exists():
    config = json.loads(config_path.read_text(encoding="utf-8"))

channels = config.setdefault("channels", {})
telegram = channels.setdefault("telegram", {})
accounts = telegram.setdefault("accounts", {})

telegram["defaultAccount"] = "orchestrator"
telegram["groupPolicy"] = "allowlist"
telegram["streaming"] = {"mode": streaming_mode}
telegram["commands"] = {"native": False}

top_level_dm_allow = dm_allow_from()
if top_level_dm_allow is not None:
    telegram["allowFrom"] = top_level_dm_allow
elif dm_policy == "open":
    telegram.pop("allowFrom", None)
elif dm_policy == "allowlist" and isinstance(telegram.get("allowFrom"), list) and telegram.get("allowFrom"):
    telegram["allowFrom"] = telegram.get("allowFrom")

configured_agents = []
topic_routes = []

for agent_id in agent_ids:
    account = accounts.setdefault(agent_id, {})
    account["groups"] = normalize_groups(account.get("groups"))

    token_env_var = f"{agent_id.upper()}_TELEGRAM_BOT_TOKEN"
    bot_token = (os.environ.get(token_env_var) or "").strip()
    if not bot_token:
        bot_token = existing_bot_token(account)

    topic_env_var = f"{agent_id.upper()}_TOPIC_ID"
    topic_id = (os.environ.get(topic_env_var) or "").strip()
    if not topic_id:
        topic_id = first_existing_topic(account)

    if not bot_token:
        continue

    account["botToken"] = bot_token
    account["dmPolicy"] = dm_policy
    account["groupPolicy"] = group_sender_policy
    account["reactionLevel"] = "minimal"
    account["streaming"] = {"mode": streaming_mode}
    account["commands"] = {"native": False, "nativeSkills": False}

    allow_from = dm_allow_from()
    if allow_from is not None:
        account["allowFrom"] = allow_from
    elif dm_policy == "open":
        account.pop("allowFrom", None)
    elif dm_policy == "allowlist" and existing_allow_from(account):
        account["allowFrom"] = existing_allow_from(account)

    group_allow = group_allow_from_values()
    if group_allow is not None:
        account["groupAllowFrom"] = group_allow
    else:
        account.pop("groupAllowFrom", None)

    configured_agents.append(agent_id)

    if topic_id:
        groups = account.setdefault("groups", {})
        group = groups.setdefault(group_id, {})
        group["enabled"] = True
        group["groupPolicy"] = "open"
        group["requireMention"] = False
        group["topics"] = group.get("topics") or {}
        topic = dict(group["topics"].get(str(topic_id)) or {})
        topic["enabled"] = True
        topic["groupPolicy"] = "open"
        topic["requireMention"] = False
        topic["agentId"] = agent_id
        group["topics"][str(topic_id)] = topic
        topic_routes.append((agent_id, str(topic_id)))

def is_team_topic_binding(entry):
    if not isinstance(entry, dict) or entry.get("type") != "route":
        return False
    agent_id = str(entry.get("agentId") or "").strip()
    if agent_id not in configured_agents:
        return False
    match = entry.get("match") or {}
    if str(match.get("channel") or "").strip() != "telegram":
        return False
    if str(match.get("accountId") or "").strip() != agent_id:
        return False
    peer = match.get("peer") or {}
    if str(peer.get("kind") or "").strip() != "group":
        return False
    return str(peer.get("id") or "").strip().startswith(f"{group_id}:topic:")

def is_team_dm_binding(entry):
    if not isinstance(entry, dict) or entry.get("type") != "route":
        return False
    agent_id = str(entry.get("agentId") or "").strip()
    if agent_id not in configured_agents:
        return False
    match = entry.get("match") or {}
    if str(match.get("channel") or "").strip() != "telegram":
        return False
    if str(match.get("accountId") or "").strip() != agent_id:
        return False
    return not isinstance(match.get("peer"), dict)

bindings = config.get("bindings") or []
merged_bindings = [
    entry for entry in bindings
    if not is_team_topic_binding(entry) and not is_team_dm_binding(entry)
]

for agent_id, topic_id in topic_routes:
    merged_bindings.append({
        "type": "route",
        "agentId": agent_id,
        "match": {
            "channel": "telegram",
            "accountId": agent_id,
            "peer": {
                "kind": "group",
                "id": f"{group_id}:topic:{topic_id}",
            },
        },
    })

if route_dms_if_no_topic:
    for agent_id in configured_agents:
        if not any(agent_id == current for current, _ in topic_routes):
            merged_bindings.append({
                "type": "route",
                "agentId": agent_id,
                "match": {
                    "channel": "telegram",
                    "accountId": agent_id,
                },
            })

config["bindings"] = merged_bindings
config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

summary = {
    "configured_agents": configured_agents,
    "topic_routes": topic_routes,
    "dm_policy": dm_policy,
    "group_sender_policy": group_sender_policy,
}
summary_path.write_text(json.dumps(summary, ensure_ascii=False), encoding="utf-8")
PY

configured_count="$(python3 - "$SUMMARY_PATH" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)

print(len(data.get("configured_agents") or []))
PY
)"

if [ "$configured_count" -eq 0 ]; then
  rm -f "$SUMMARY_PATH"
  echo "ℹ️  No Telegram accounts were configured. Gateway reload skipped."
  exit 0
fi

python3 - "$SUMMARY_PATH" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)

configured_agents = set(data.get("configured_agents") or [])
topic_routes = {agent: topic for agent, topic in (data.get("topic_routes") or [])}

for agent in sorted(configured_agents):
    topic = topic_routes.get(agent)
    if topic:
        print(f"  ✓ {agent} -> topic {topic}")
    else:
        print(f"  ✓ {agent}: DM account configured (topic not set)")
PY

rm -f "$SUMMARY_PATH"

if gateway_is_running; then
  echo "🔄 Reloading gateway service to apply routing changes..."
  reload_gateway_service
else
  echo "ℹ️  Gateway is currently down. Routing config was saved; start the gateway to apply it."
fi

echo "✅ Telegram topic routing applied."
