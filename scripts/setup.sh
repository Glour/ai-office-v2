#!/bin/bash
# setup.sh - One-command setup for Personal AI Team
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
source "$REPO_DIR/team-config.sh"
ENV_FILE="${ENV_FILE:-$REPO_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

OPENCLAW_PROFILE="${OPENCLAW_PROFILE:-default}"
OPENCLAW_STATE_DIR="$(team_openclaw_state_dir "$OPENCLAW_PROFILE")"
OPENCLAW_AGENTS_ROOT="$OPENCLAW_STATE_DIR/agents"
WORKSPACE_ROOT="$(team_openclaw_agents_dir)"

is_real_secret() {
  local value="${1:-}"
  [[ -n "$value" ]] || return 1
  [[ "$value" != your-* ]] || return 1
  [[ "$value" != *placeholder* ]] || return 1
  [[ "$value" != *changeme* ]] || return 1
  return 0
}

OPENCLAW_AUTH_CHOICE="${OPENCLAW_AUTH_CHOICE:-}"
if [ -z "$OPENCLAW_AUTH_CHOICE" ]; then
  if is_real_secret "${OPENAI_API_KEY:-}"; then
    OPENCLAW_AUTH_CHOICE="openai-api-key"
  else
    OPENCLAW_AUTH_CHOICE="openai-codex"
  fi
fi

if [ "$OPENCLAW_AUTH_CHOICE" = "openai-codex" ]; then
  DEFAULT_TEAM_MODEL="openai-codex/gpt-5.4"
elif [ "$OPENCLAW_AUTH_CHOICE" = "openai-api-key" ]; then
  DEFAULT_TEAM_MODEL="openai/gpt-5.4"
else
  DEFAULT_TEAM_MODEL="openai-codex/gpt-5.4"
fi

MAIN_MODEL="${MAIN_MODEL:-$DEFAULT_TEAM_MODEL}"
AGENT_MODEL="${AGENT_MODEL:-$DEFAULT_TEAM_MODEL}"
THINKING_DEFAULT="${THINKING_DEFAULT:-high}"
REASONING_DEFAULT="${REASONING_DEFAULT:-on}"

export OPENCLAW_AGENTS_DIR="${OPENCLAW_AGENTS_DIR:-$WORKSPACE_ROOT}"
export WORKSPACE_PATH="${WORKSPACE_PATH:-$OPENCLAW_AGENTS_DIR}"
export OWNER_NAME="${OWNER_NAME:-owner}"
export OWNER_USERNAME="${OWNER_USERNAME:-owner}"
export OWNER_TELEGRAM_ID="${OWNER_TELEGRAM_ID:-}"
export PAID_GROUP_NAME="${PAID_GROUP_NAME:-premium-group}"
export PAID_CHANNEL_ID="${PAID_CHANNEL_ID:-channel-id}"
export TELEGRAM_CHANNEL="${TELEGRAM_CHANNEL:-channel}"
export TRIBUTE_LINK_ID="${TRIBUTE_LINK_ID:-tribute}"
for agent in $(team_agent_ids); do
  upper_agent="$(printf '%s' "$agent" | tr '[:lower:]' '[:upper:]')"
  topic_var="${upper_agent}_TOPIC_ID"
  export "TOPIC_${upper_agent}=${!topic_var:-$agent}"
done

ACTIVE_AGENTS=( $(team_active_agent_ids) )
BOOTSTRAP_AGENT="${ACTIVE_AGENTS[0]}"
for agent in "${ACTIVE_AGENTS[@]}"; do
  if [ "$agent" = "$(team_orchestrator_id)" ]; then
    BOOTSTRAP_AGENT="$agent"
    break
  fi
done

json_string() {
  printf '"%s"' "$1"
}

agent_list_index() {
  local agent_id="$1"

  python3 - "$OPENCLAW_STATE_DIR/openclaw.json" "$agent_id" <<'PY'
import json
import sys

config_path, agent_id = sys.argv[1], sys.argv[2]
with open(config_path, 'r', encoding='utf-8') as fh:
    data = json.load(fh)

for idx, entry in enumerate(((data.get("agents") or {}).get("list") or [])):
    if isinstance(entry, dict) and entry.get("id") == agent_id:
        print(idx)
        raise SystemExit(0)
raise SystemExit(1)
PY
}

sync_registered_agent_defaults() {
  local spec_lines="$1"

  AGENT_DEFAULT_SPECS="$spec_lines" python3 - "$OPENCLAW_STATE_DIR/openclaw.json" <<'PY'
import json
import os
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
if not config_path.exists():
    raise SystemExit(0)

specs = {}
for raw_line in os.environ.get("AGENT_DEFAULT_SPECS", "").splitlines():
    line = raw_line.strip()
    if not line:
        continue
    agent_id, model, thinking, reasoning = line.split("\t")
    specs[agent_id] = {
        "model": model,
        "thinkingDefault": thinking,
        "reasoningDefault": reasoning,
    }

config = json.loads(config_path.read_text(encoding="utf-8"))
changed = []
for entry in (((config.get("agents") or {}).get("list") or [])):
    if not isinstance(entry, dict):
        continue
    agent_id = str(entry.get("id") or "").strip()
    desired = specs.get(agent_id)
    if not desired:
        continue
    for key, value in desired.items():
        entry[key] = value
    changed.append(agent_id)

if changed:
    config_path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for agent_id in changed:
        print(agent_id)
PY
}

write_runtime_provider_env() {
  local runtime_env="$OPENCLAW_STATE_DIR/.env"
  local tmp_env
  tmp_env="$(mktemp)"
  chmod 600 "$tmp_env"

  if [ -f "$runtime_env" ]; then
    grep -vE '^(DEEPGRAM_API_KEY|PERPLEXITY_API_KEY)=' "$runtime_env" >"$tmp_env" || true
  fi

  if is_real_secret "${DEEPGRAM_API_KEY:-}"; then
    printf 'DEEPGRAM_API_KEY=%s\n' "$DEEPGRAM_API_KEY" >>"$tmp_env"
  fi

  if is_real_secret "${PERPLEXITY_API_KEY:-}"; then
    printf 'PERPLEXITY_API_KEY=%s\n' "$PERPLEXITY_API_KEY" >>"$tmp_env"
  fi

  if [ -s "$tmp_env" ]; then
    mv "$tmp_env" "$runtime_env"
    chmod 600 "$runtime_env"
    echo "  ✓ Runtime provider env synced: $runtime_env"
  else
    rm -f "$tmp_env"
    rm -f "$runtime_env"
    echo "  ℹ No provider keys supplied for Deepgram / Perplexity"
  fi
}

configure_runtime_integrations() {
  local deepgram_enabled=0
  local perplexity_enabled=0
  local openai_transcriber_enabled=0
  local broadcast_strategy="${OPENCLAW_BROADCAST_STRATEGY:-parallel}"
  local agents_max_concurrent="${OPENCLAW_AGENTS_MAX_CONCURRENT:-6}"
  local agents_subagents_max_concurrent="${OPENCLAW_AGENTS_SUBAGENTS_MAX_CONCURRENT:-8}"
  local queue_mode="${OPENCLAW_MESSAGES_QUEUE_MODE:-collect}"
  local queue_debounce_ms="${OPENCLAW_MESSAGES_QUEUE_DEBOUNCE_MS:-1000}"
  local queue_cap="${OPENCLAW_MESSAGES_QUEUE_CAP:-20}"
  local queue_drop="${OPENCLAW_MESSAGES_QUEUE_DROP:-summarize}"
  local telegram_queue_mode="${OPENCLAW_MESSAGES_QUEUE_TELEGRAM_MODE:-}"
  local audio_timeout="${OPENCLAW_AUDIO_TIMEOUT_SECONDS:-90}"

  if is_real_secret "${DEEPGRAM_API_KEY:-}"; then
    deepgram_enabled=1
  fi

  if is_real_secret "${PERPLEXITY_API_KEY:-}"; then
    perplexity_enabled=1
  fi

  if is_real_secret "${OPENAI_API_KEY:-}"; then
    openai_transcriber_enabled=1
  fi

  OPENCLAW_RUNTIME_DEEPGRAM="$deepgram_enabled" \
  OPENCLAW_RUNTIME_PERPLEXITY="$perplexity_enabled" \
  OPENCLAW_RUNTIME_OPENAI_TRANSCRIBE="$openai_transcriber_enabled" \
  OPENCLAW_RUNTIME_BROADCAST_STRATEGY="$broadcast_strategy" \
  OPENCLAW_RUNTIME_AGENTS_MAX_CONCURRENT="$agents_max_concurrent" \
  OPENCLAW_RUNTIME_AGENTS_SUBAGENTS_MAX_CONCURRENT="$agents_subagents_max_concurrent" \
  OPENCLAW_RUNTIME_QUEUE_MODE="$queue_mode" \
  OPENCLAW_RUNTIME_QUEUE_DEBOUNCE_MS="$queue_debounce_ms" \
  OPENCLAW_RUNTIME_QUEUE_CAP="$queue_cap" \
  OPENCLAW_RUNTIME_QUEUE_DROP="$queue_drop" \
  OPENCLAW_RUNTIME_TELEGRAM_QUEUE_MODE="$telegram_queue_mode" \
  OPENCLAW_RUNTIME_AUDIO_TIMEOUT="$audio_timeout" \
python3 - "$OPENCLAW_STATE_DIR/openclaw.json" <<'PY'
import json
import os
import sys
from pathlib import Path

ALLOWED_QUEUE_MODES = {
    "steer", "followup", "collect", "steer-backlog", "steer+backlog", "queue", "interrupt"
}
ALLOWED_BROADCAST_STRATEGY = {"parallel", "sequential"}
ALLOWED_QUEUE_DROP = {"old", "new", "summarize"}

def _to_int(value, fallback):
    try:
        return int(value)
    except (TypeError, ValueError):
        return fallback

config_path = Path(sys.argv[1])
if not config_path.exists():
    raise SystemExit(0)

config = json.loads(config_path.read_text(encoding="utf-8"))
deepgram_enabled = os.environ.get("OPENCLAW_RUNTIME_DEEPGRAM") == "1"
perplexity_enabled = os.environ.get("OPENCLAW_RUNTIME_PERPLEXITY") == "1"
openai_transcribe_enabled = os.environ.get("OPENCLAW_RUNTIME_OPENAI_TRANSCRIBE") == "1"

broadcast_strategy = (os.environ.get("OPENCLAW_RUNTIME_BROADCAST_STRATEGY") or "parallel").strip()
if broadcast_strategy not in ALLOWED_BROADCAST_STRATEGY:
    broadcast_strategy = "parallel"

agents_max_concurrent = _to_int(os.environ.get("OPENCLAW_RUNTIME_AGENTS_MAX_CONCURRENT"), 6)
agents_subagents_max_concurrent = _to_int(
    os.environ.get("OPENCLAW_RUNTIME_AGENTS_SUBAGENTS_MAX_CONCURRENT"),
    agents_max_concurrent,
)
queue_mode = (os.environ.get("OPENCLAW_RUNTIME_QUEUE_MODE") or "collect").strip()
if queue_mode not in ALLOWED_QUEUE_MODES:
    queue_mode = "collect"

queue_debounce_ms = _to_int(os.environ.get("OPENCLAW_RUNTIME_QUEUE_DEBOUNCE_MS"), 1000)
queue_cap = _to_int(os.environ.get("OPENCLAW_RUNTIME_QUEUE_CAP"), 20)

queue_drop = (os.environ.get("OPENCLAW_RUNTIME_QUEUE_DROP") or "summarize").strip()
if queue_drop not in ALLOWED_QUEUE_DROP:
    queue_drop = "summarize"

telegram_queue_mode = (os.environ.get("OPENCLAW_RUNTIME_TELEGRAM_QUEUE_MODE") or "").strip()
if telegram_queue_mode and telegram_queue_mode not in ALLOWED_QUEUE_MODES:
    telegram_queue_mode = ""

audio_timeout = _to_int(os.environ.get("OPENCLAW_RUNTIME_AUDIO_TIMEOUT"), 90)

tools = config.setdefault("tools", {})
media = tools.setdefault("media", {})
audio = media.setdefault("audio", {})
audio["enabled"] = True
audio["timeoutSeconds"] = audio_timeout
audio["echoTranscript"] = False
audio_models = []
if deepgram_enabled:
    audio_models.append({"provider": "deepgram", "model": "nova-3"})
elif openai_transcribe_enabled:
    audio_models.append({"provider": "openai", "model": "gpt-4o-transcribe"})
if audio_models:
    audio["models"] = audio_models
    provider_options = audio.setdefault("providerOptions", {})
    if deepgram_enabled:
        provider_options["deepgram"] = {"smart_format": True, "punctuate": True}
    else:
        provider_options.pop("deepgram", None)
    if not provider_options:
        audio.pop("providerOptions", None)
else:
    audio["enabled"] = False
    audio.pop("models", None)
    audio.pop("providerOptions", None)

web = tools.setdefault("web", {})
web_fetch = web.setdefault("fetch", {})
web_fetch["enabled"] = True
web_search = web.setdefault("search", {})
web_search["enabled"] = True
web_search["maxResults"] = 5
if perplexity_enabled:
    web_search["provider"] = "perplexity"
else:
    web_search.pop("provider", None)

plugins = config.setdefault("plugins", {}).setdefault("entries", {})
if perplexity_enabled:
    plugins.setdefault("perplexity", {})
    plugins["perplexity"]["enabled"] = True

agents = config.setdefault("agents", {})
defaults = agents.setdefault("defaults", {})
defaults["typingMode"] = "instant"
defaults["typingIntervalSeconds"] = 6
defaults["maxConcurrent"] = max(1, agents_max_concurrent)
defaults.setdefault("subagents", {})
defaults["subagents"]["maxConcurrent"] = max(1, agents_subagents_max_concurrent)
defaults["subagents"].setdefault("maxChildrenPerAgent", 8)
defaults["subagents"].setdefault("maxSpawnDepth", 2)
defaults["subagents"].setdefault("runTimeoutSeconds", 900)
defaults["subagents"].setdefault("archiveAfterMinutes", 180)
defaults["subagents"].setdefault("requireAgentId", True)
compaction = defaults.setdefault("compaction", {})
compaction["mode"] = "safeguard"
memory_flush = compaction.setdefault("memoryFlush", {})
memory_flush["enabled"] = True
memory_flush["softThresholdTokens"] = 6000
memory_flush["prompt"] = (
  "Контекст почти заполнен. Перед compaction тихо запиши durable handoff в memory/handoff.md: "
  "что подтверждено, что в работе, что блокирует, какие следующие шаги. "
  "Пиши кратко, без tool traces и служебного шума. После записи ответь NO_REPLY."
)

broadcast = config.setdefault("broadcast", {})
broadcast["strategy"] = broadcast_strategy

messages = config.setdefault("messages", {})
message_queue = {
  "mode": queue_mode,
  "debounceMs": queue_debounce_ms,
  "cap": queue_cap,
  "drop": queue_drop
}
if telegram_queue_mode:
  message_queue.setdefault("byChannel", {})
  message_queue["byChannel"]["telegram"] = telegram_queue_mode
messages["queue"] = message_queue

config_path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("tools.media.audio enabled")
print("tools.web.search enabled")
print("tools.web.fetch enabled")
print(f"broadcast.strategy = {broadcast_strategy}")
print(f"agents.defaults.maxConcurrent = {agents_max_concurrent}")
print(f"agents.defaults.subagents.maxConcurrent = {agents_subagents_max_concurrent}")
print(f"messages.queue.mode = {queue_mode}")
print("compaction.memoryFlush enabled")
if deepgram_enabled:
    print("deepgram audio configured")
if perplexity_enabled:
    print("perplexity web search configured")
print("typingMode=instant")
PY
}

echo "🧪 Personal AI Team - Setup"
echo "=========================="
echo ""
echo "Model defaults: main=$MAIN_MODEL agents=$AGENT_MODEL think=$THINKING_DEFAULT reasoning=$REASONING_DEFAULT"
echo ""

# Check prerequisites
command -v openclaw >/dev/null 2>&1 || { echo "❌ OpenClaw not installed. Run: npm install -g openclaw"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "❌ Node.js not installed."; exit 1; }

echo "✅ Prerequisites OK"
echo ""

# Check .env
if [ ! -f "$REPO_DIR/.env" ]; then
  echo "⚠️  No .env file found. Copy and configure:"
  echo "   cp .env.example .env"
  echo "   # Edit .env with your values"
  echo ""
  read -p "Continue without .env? [y/N] " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# Agent mapping: directory name -> OpenClaw agent name
AGENT_MAP=()
for id in "${ACTIVE_AGENTS[@]}"; do
  AGENT_MAP+=("$id:$id")
done

if [ ! -f "$OPENCLAW_STATE_DIR/openclaw.json" ]; then
  echo "🪪 Initializing OpenClaw profile: $OPENCLAW_PROFILE"

  if [ "$OPENCLAW_AUTH_CHOICE" = "openai-codex" ]; then
    echo "🔐 Auth mode: openai-codex (Sign in with ChatGPT)"
    openclaw --profile "$OPENCLAW_PROFILE" onboard \
      --mode local \
      --flow quickstart \
      --accept-risk \
      --no-install-daemon \
      --skip-channels \
      --skip-skills \
      --skip-ui \
      --skip-health \
      --auth-choice openai-codex \
      --workspace "$WORKSPACE_ROOT/$BOOTSTRAP_AGENT"
  else
    openclaw --profile "$OPENCLAW_PROFILE" onboard \
      --mode local \
      --flow quickstart \
      --non-interactive \
      --accept-risk \
      --no-install-daemon \
      --skip-channels \
      --skip-skills \
      --skip-ui \
      --skip-health \
      --auth-choice skip \
      --workspace "$WORKSPACE_ROOT/$BOOTSTRAP_AGENT"
  fi
  echo ""
fi

echo "🧩 Rendering agent configs..."
bash "$REPO_DIR/scripts/render-openclaw-configs.sh" "$ENV_FILE"
echo ""

echo "🏗️  Ensuring agent workspaces..."
bash "$REPO_DIR/scripts/deploy-team.sh"
echo ""

echo "📦 Installing agents..."
for pair in "${AGENT_MAP[@]}"; do
  char_name="${pair%%:*}"
  agent_name="${pair##*:}"
  src="$REPO_DIR/agents/$char_name"
  dest="$OPENCLAW_AGENTS_ROOT/$agent_name/agent"
  
  if [ -d "$src" ]; then
    mkdir -p "$dest"
    shopt -s nullglob
    for template in "$src"/*.md; do
      perl -pe 's/\{\{([A-Z0-9_]+)\}\}/(exists $ENV{$1} ? $ENV{$1} : "")/ge' \
        "$template" > "$dest/$(basename "$template")"
    done
    shopt -u nullglob
    shopt -s nullglob
    for shared_md in "$REPO_DIR"/TEAM_*.md; do
      cp "$shared_md" "$dest/$(basename "$shared_md")"
    done
    shopt -u nullglob
    echo "  ✓ $char_name → $agent_name"
  else
    echo "  ⚠ $char_name directory not found, skipping"
  fi
done

echo ""
echo "📚 Installing skills..."
SKILLS_DEST="$OPENCLAW_AGENTS_ROOT/$(team_orchestrator_id)/agent/skills"
if [ -d "$REPO_DIR/skills" ]; then
  mkdir -p "$SKILLS_DEST"
  SKILL_OK=0
  SKILL_FAIL=0
  for skill_dir in "$REPO_DIR/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    if cp -r "$skill_dir" "$SKILLS_DEST/" 2>/dev/null; then
      SKILL_OK=$((SKILL_OK + 1))
    else
      echo "  ⚠ Failed to copy: $skill_name"
      SKILL_FAIL=$((SKILL_FAIL + 1))
    fi
  done
  echo "  ✓ $SKILL_OK skills installed"
  [ "$SKILL_FAIL" -gt 0 ] && echo "  ⚠ $SKILL_FAIL skills failed — check permissions"
else
  echo "  ❌ Skills directory not found!"
  exit 1
fi

echo ""
echo "📄 Installing references..."
if [ -d "$REPO_DIR/references" ]; then
  echo "  References are in $REPO_DIR/references/"
  echo "  Copy them to your workspace as needed."
fi

echo ""

# Register isolated agents in the active OpenClaw profile.
echo "🧭 Registering agents in OpenClaw profile..."
REGISTERED_AGENTS="$(openclaw --profile "$OPENCLAW_PROFILE" agents list 2>/dev/null || true)"
AGENT_DEFAULT_SPECS=""
for id in "${ACTIVE_AGENTS[@]}"; do
  if [ "$id" = "$(team_orchestrator_id)" ]; then
    model="$MAIN_MODEL"
  else
    model="$AGENT_MODEL"
  fi

  if printf '%s\n' "$REGISTERED_AGENTS" | grep -Fq -- "- $id"; then
    echo "  ↺ $id already registered"
  else
    openclaw --profile "$OPENCLAW_PROFILE" agents add "$id" \
      --workspace "$WORKSPACE_ROOT/$id" \
      --agent-dir "$OPENCLAW_AGENTS_ROOT/$id/agent" \
      --model "$model" \
      --non-interactive >/dev/null
    echo "  ✓ $id registered"
  fi

  AGENT_DEFAULT_SPECS="${AGENT_DEFAULT_SPECS}${id}	${model}	${THINKING_DEFAULT}	${REASONING_DEFAULT}
"
done

SYNCED_DEFAULTS="$(sync_registered_agent_defaults "$AGENT_DEFAULT_SPECS" || true)"
for id in "${ACTIVE_AGENTS[@]}"; do
  if printf '%s\n' "$SYNCED_DEFAULTS" | grep -Fxq "$id"; then
    echo "  ⚙ $id defaults synced"
  else
    echo "  ⚠ $id defaults not synced: agent entry not found in agents.list"
  fi
done

echo ""

echo "🔐 Syncing auth profiles..."
bash "$REPO_DIR/scripts/sync-auth-profiles.sh"
echo ""

echo "🗝️  Syncing provider secrets..."
write_runtime_provider_env
echo ""

echo "🔌 Enabling default media/web integrations..."
configure_runtime_integrations
echo ""

echo "🩺 Normalizing OpenClaw config for current CLI..."
openclaw --profile "$OPENCLAW_PROFILE" doctor --fix >/dev/null 2>&1 || true
echo ""

echo "🔗 Enabling cross-agent delegation..."
ALLOWED_AGENTS_JSON="$(printf '%s\n' "${ACTIVE_AGENTS[@]}" | python3 -c 'import json,sys; print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))')"
openclaw --profile "$OPENCLAW_PROFILE" config set \
  "tools.sessions.visibility" \
  '"all"' \
  --strict-json >/dev/null 2>&1 || true
openclaw --profile "$OPENCLAW_PROFILE" config set \
  "tools.agentToAgent.enabled" \
  true \
  --strict-json >/dev/null 2>&1 || true
openclaw --profile "$OPENCLAW_PROFILE" config set \
  "tools.agentToAgent.allow" \
  "$ALLOWED_AGENTS_JSON" \
  --strict-json >/dev/null 2>&1 || true
openclaw --profile "$OPENCLAW_PROFILE" config set \
  "agents.defaults.subagents.allowAgents" \
  "$ALLOWED_AGENTS_JSON" \
  --strict-json >/dev/null 2>&1 || true
openclaw --profile "$OPENCLAW_PROFILE" config set \
  "agents.defaults.subagents.maxSpawnDepth" \
  2 \
  --strict-json >/dev/null 2>&1 || true
openclaw --profile "$OPENCLAW_PROFILE" config set \
  "agents.defaults.subagents.maxChildrenPerAgent" \
  8 \
  --strict-json >/dev/null 2>&1 || true
openclaw --profile "$OPENCLAW_PROFILE" config set \
  "agents.defaults.subagents.runTimeoutSeconds" \
  900 \
  --strict-json >/dev/null 2>&1 || true
openclaw --profile "$OPENCLAW_PROFILE" config set \
  "agents.defaults.subagents.archiveAfterMinutes" \
  180 \
  --strict-json >/dev/null 2>&1 || true
openclaw --profile "$OPENCLAW_PROFILE" config set \
  "agents.defaults.subagents.requireAgentId" \
  true \
  --strict-json >/dev/null 2>&1 || true
openclaw --profile "$OPENCLAW_PROFILE" config set \
  "agents.defaults.compaction.mode" \
  '"safeguard"' \
  --strict-json >/dev/null 2>&1 || true
openclaw --profile "$OPENCLAW_PROFILE" config set \
  "agents.defaults.compaction.memoryFlush.enabled" \
  true \
  --strict-json >/dev/null 2>&1 || true
openclaw --profile "$OPENCLAW_PROFILE" config set \
  "agents.defaults.compaction.memoryFlush.softThresholdTokens" \
  6000 \
  --strict-json >/dev/null 2>&1 || true
MEMORY_FLUSH_PROMPT_JSON="$(python3 - <<'PY'
import json
print(json.dumps(
    "Контекст почти заполнен. Перед compaction тихо запиши durable handoff в memory/handoff.md: "
    "что подтверждено, что в работе, что блокирует, какие следующие шаги. "
    "Пиши кратко, без tool traces и служебного шума. После записи ответь NO_REPLY."
))
PY
)"
openclaw --profile "$OPENCLAW_PROFILE" config set \
  "agents.defaults.compaction.memoryFlush.prompt" \
  "$MEMORY_FLUSH_PROMPT_JSON" \
  --strict-json >/dev/null 2>&1 || true
echo ""

echo "🧵 Applying Telegram topic routing..."
bash "$REPO_DIR/scripts/configure-telegram-topics.sh"
echo ""

# Verify installation
echo "🔍 Verifying..."
AGENT_COUNT=$(find "$OPENCLAW_AGENTS_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
echo "  Agents installed: $AGENT_COUNT/${#ACTIVE_AGENTS[@]}"
if [ "$AGENT_COUNT" -lt "${#ACTIVE_AGENTS[@]}" ]; then
  echo "  ⚠ Expected ${#ACTIVE_AGENTS[@]} active agents. Check the output above for errors."
fi

# Source placeholders in repo templates are expected and rendered into workspaces.

echo ""
echo "=========================="
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
if [ "$OPENCLAW_AUTH_CHOICE" = "openai-codex" ]; then
  echo "  1. If prompted, complete Sign in with ChatGPT for Codex/OpenAI auth"
else
  echo "  1. Fill .env with a real LLM API key"
fi
echo "  2. Run: bash scripts/start-team.sh"
echo "  3. Verify: openclaw --profile $OPENCLAW_PROFILE status"
echo "  4. Test a turn: openclaw --profile $OPENCLAW_PROFILE agent --agent orchestrator --local --message 'ping'"
echo ""
echo "Profile: $OPENCLAW_PROFILE"
echo "Auth choice: $OPENCLAW_AUTH_CHOICE"
echo "Thinking default: $THINKING_DEFAULT"
echo "Reasoning default: $REASONING_DEFAULT"
echo "Agent state: $OPENCLAW_AGENTS_ROOT"
echo "Workspaces: $WORKSPACE_ROOT"
echo ""
echo "🧪 Say my name."
