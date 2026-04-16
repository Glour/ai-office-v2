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

normalize_topics_to_objects() {
  [ -f "$PROFILE_CONFIG_PATH" ] || return 0
  python3 - "$PROFILE_CONFIG_PATH" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
accounts = (((data.get("channels") or {}).get("telegram") or {}).get("accounts") or {})
changed = False
for account in accounts.values():
    groups = account.get("groups") or {}
    for group in groups.values():
        topics = group.get("topics")
        if isinstance(topics, list):
            group["topics"] = {
                str(i): value
                for i, value in enumerate(topics)
                if value not in (None, {}, [])
            }
            changed = True
if changed:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
PY
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
  local upper_agent token_var
  upper_agent="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
  token_var="${upper_agent}_TELEGRAM_BOT_TOKEN"
  printf '%s' "${!token_var:-${TELEGRAM_BOT_TOKEN:-}}"
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

echo "🧭 Configuring Telegram topic routing"
echo "Profile: $OPENCLAW_PROFILE"
echo "Group:   $TEAM_TELEGRAM_GROUP_ID"

TEAM_AGENT_IDS_PAYLOAD="$(team_active_agent_ids)"
SUMMARY_PATH="$(mktemp)"

TEAM_AGENT_IDS_PAYLOAD="$TEAM_AGENT_IDS_PAYLOAD" \
TEAM_TELEGRAM_GROUP_ID="$TEAM_TELEGRAM_GROUP_ID" \
OWNER_TELEGRAM_ID="${OWNER_TELEGRAM_ID:-}" \
PROFILE_CONFIG_PATH="$PROFILE_CONFIG_PATH" \
SUMMARY_PATH="$SUMMARY_PATH" \
python3 - <<'PY'
import json
import os
from pathlib import Path

config_path = Path(os.environ["PROFILE_CONFIG_PATH"]).expanduser()
summary_path = Path(os.environ["SUMMARY_PATH"])
group_id = os.environ["TEAM_TELEGRAM_GROUP_ID"].strip()
owner_id = os.environ.get("OWNER_TELEGRAM_ID", "").strip()
agent_ids = [line.strip() for line in os.environ.get("TEAM_AGENT_IDS_PAYLOAD", "").splitlines() if line.strip()]

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

def route_binding_agents(bindings):
    result = set()
    for entry in bindings:
        if not isinstance(entry, dict):
            continue
        if entry.get("type") != "route":
            continue
        match = entry.get("match") or {}
        if str(match.get("channel") or "").strip() != "telegram":
            continue
        agent_id = str(entry.get("agentId") or "").strip()
        account_id = str(match.get("accountId") or "").strip()
        if agent_id and agent_id == account_id:
            result.add(agent_id)
    return result

config = {}
if config_path.exists():
    config = json.loads(config_path.read_text(encoding="utf-8"))

channels = config.setdefault("channels", {})
telegram = channels.setdefault("telegram", {})
accounts = telegram.setdefault("accounts", {})

telegram["defaultAccount"] = "orchestrator"
telegram["groupPolicy"] = "disabled"
if owner_id:
    telegram["allowFrom"] = [owner_id]

configured_agents = []
topic_routes = []

for agent_id in agent_ids:
    account = accounts.setdefault(agent_id, {})
    account["groups"] = normalize_groups(account.get("groups"))

    token_env_var = f"{agent_id.upper()}_TELEGRAM_BOT_TOKEN"
    bot_token = (os.environ.get(token_env_var, "") or os.environ.get("TELEGRAM_BOT_TOKEN", "")).strip()
    if not bot_token:
        bot_token = existing_bot_token(account)

    topic_env_var = f"{agent_id.upper()}_TOPIC_ID"
    topic_id = (os.environ.get(topic_env_var, "") or "").strip()
    if not topic_id:
        topic_id = first_existing_topic(account)

    if not bot_token:
        continue

    account["botToken"] = bot_token
    account["dmPolicy"] = "allowlist"
    account["groupPolicy"] = "allowlist"
    account["reactionLevel"] = "minimal"
    account["streaming"] = {"mode": "off"}
    account["commands"] = {"nativeSkills": False}
    if owner_id:
        account["allowFrom"] = [owner_id]
        account["groupAllowFrom"] = [owner_id]

    configured_agents.append(agent_id)

    if topic_id:
        groups = account.setdefault("groups", {})
        group = groups.setdefault(group_id, {})
        group["enabled"] = True
        group["groupPolicy"] = "open"
        group["requireMention"] = False
        group["topics"] = group.get("topics") or {}
        topic = {}
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
}
summary_path.write_text(json.dumps(summary, ensure_ascii=False), encoding="utf-8")
PY

configured_count="$(python3 - "$SUMMARY_PATH" <<'PY'
import json, sys
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
import json, sys
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
