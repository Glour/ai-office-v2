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

OPENCLAW_PROFILE="${OPENCLAW_PROFILE:-personal}"
OPENCLAW_STATE_DIR="$HOME/.openclaw-${OPENCLAW_PROFILE}"
OPENCLAW_AGENTS_ROOT="$OPENCLAW_STATE_DIR/agents"
WORKSPACE_ROOT="${OPENCLAW_AGENTS_DIR:-$HOME/openclaw-agents-personal}"

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
for id in "${TEAM_AGENT_IDS[@]}"; do
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
      --workspace "$WORKSPACE_ROOT/$(team_orchestrator_id)"
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
      --workspace "$WORKSPACE_ROOT/$(team_orchestrator_id)"
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
    cp "$src"/*.md "$dest/" 2>/dev/null || true
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
for id in "${TEAM_AGENT_IDS[@]}"; do
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

  idx="$(agent_list_index "$id" || true)"
  if [ -n "$idx" ]; then
    openclaw --profile "$OPENCLAW_PROFILE" config set \
      "agents.list[$idx].model" \
      "$(json_string "$model")" \
      --strict-json >/dev/null
    openclaw --profile "$OPENCLAW_PROFILE" config set \
      "agents.list[$idx].thinkingDefault" \
      "$(json_string "$THINKING_DEFAULT")" \
      --strict-json >/dev/null
    openclaw --profile "$OPENCLAW_PROFILE" config set \
      "agents.list[$idx].reasoningDefault" \
      "$(json_string "$REASONING_DEFAULT")" \
      --strict-json >/dev/null
    echo "  ⚙ $id defaults synced"
  else
    echo "  ⚠ $id defaults not synced: agent index not found in agents.list"
  fi
done

echo ""

echo "🔐 Syncing auth profiles..."
bash "$REPO_DIR/scripts/sync-auth-profiles.sh"
echo ""

echo "🧵 Applying Telegram topic routing..."
bash "$REPO_DIR/scripts/configure-telegram-topics.sh"
echo ""

# Verify installation
echo "🔍 Verifying..."
AGENT_COUNT=$(find "$OPENCLAW_AGENTS_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
echo "  Agents installed: $AGENT_COUNT/${TEAM_AGENT_COUNT}"
if [ "$AGENT_COUNT" -lt "$TEAM_AGENT_COUNT" ]; then
  echo "  ⚠ Expected ${TEAM_AGENT_COUNT} agents. Check the output above for errors."
fi

# Check for remaining placeholders
PLACEHOLDER_COUNT=$(grep -rl '{{[A-Z_]*}}' "$REPO_DIR/agents" --include="*.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$PLACEHOLDER_COUNT" -gt 0 ]; then
  echo ""
  echo "  ⚠ $PLACEHOLDER_COUNT agent files still contain {{PLACEHOLDER}} values."
  echo "  Run the setup wizard to fill them: bash scripts/setup-wizard.sh"
fi

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
