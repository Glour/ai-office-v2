#!/bin/bash
# deploy-team.sh — Deploy the Personal Team
# Creates workspace directories and copies agent files
#
# Usage:
#   bash scripts/deploy-team.sh           # Create workspaces (skip existing)
#   bash scripts/deploy-team.sh --force   # Overwrite existing workspaces
#   OPENCLAW_AGENTS_DIR=/custom/path bash scripts/deploy-team.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_DIR/team-config.sh"
ENV_FILE="${ENV_FILE:-$REPO_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

AGENTS_DIR="$REPO_DIR/agents"
REFS_DIR="$REPO_DIR/references"
SCRIPTS_DIR="$REPO_DIR/scripts"
CONFIGS_DIR="$REPO_DIR/configs"

BASE_DIR="$(team_openclaw_agents_dir)"
OPENCLAW_DIR="$(team_openclaw_state_dir)"
FORCE=false

export OPENCLAW_AGENTS_DIR="${OPENCLAW_AGENTS_DIR:-$BASE_DIR}"
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

# Parse args
for arg in "$@"; do
  case $arg in
    --force) FORCE=true ;;
    --help|-h)
      echo "Usage: $0 [--force]"
      echo "  --force   Overwrite existing agent workspaces"
      echo ""
      echo "Environment:"
  echo "  OPENCLAW_AGENTS_DIR   Base directory for agent workspaces (default: ~/openclaw-agents)"
      exit 0
      ;;
  esac
done

echo "🚀 Agent Team Deployment"
echo "================================"
echo "Repo:           $REPO_DIR"
echo "Base directory: $BASE_DIR"
echo "Force:          $FORCE"
echo ""

# List of agents
AGENTS=( $(team_agent_ids) )
ORCHESTRATOR_ID="$(team_orchestrator_id)"

resolve_agent_workspace_dir() {
  local agent_id="$1"
  local config_path
  config_path="$(team_openclaw_state_dir)/openclaw.json"

  if [ -f "$config_path" ]; then
    python3 - "$config_path" "$agent_id" "$BASE_DIR" <<'PY'
import json
import sys
from pathlib import Path

config_path, agent_id, base_dir = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = json.loads(Path(config_path).read_text(encoding='utf-8'))
except Exception:
    print(f"{base_dir}/{agent_id}")
    raise SystemExit(0)

for entry in ((data.get("agents") or {}).get("list") or []):
    if isinstance(entry, dict) and entry.get("id") == agent_id and entry.get("workspace"):
        print(entry["workspace"])
        raise SystemExit(0)

print(f"{base_dir}/{agent_id}")
PY
  else
    echo "$BASE_DIR/$agent_id"
  fi
}

# ── Workspaces ──────────────────────────────────────────────────────────────
for agent in "${AGENTS[@]}"; do
  AGENT_DIR="$(resolve_agent_workspace_dir "$agent")"

  if [ -d "$AGENT_DIR" ]; then
    if [ "$FORCE" = true ]; then
      echo "📁 Rebuilding workspace for $agent..."
    else
      echo "📁 Ensuring workspace for $agent..."
    fi
  else
    echo "📁 Creating workspace for $agent..."
  fi

  mkdir -p "$AGENT_DIR"
  mkdir -p "$AGENT_DIR/memory"
  mkdir -p "$AGENT_DIR/memory/core"
  mkdir -p "$AGENT_DIR/memory/decisions"
  mkdir -p "$AGENT_DIR/memory/archive"
  mkdir -p "$AGENT_DIR/references"
  mkdir -p "$AGENT_DIR/scripts"

  # Copy agent markdown files to workspace root
  if [ -d "$AGENTS_DIR/$agent" ]; then
    shopt -s nullglob
    for template in "$AGENTS_DIR/$agent/"*.md; do
      target="$AGENT_DIR/$(basename "$template")"
      perl -pe 's/\{\{([A-Z0-9_]+)\}\}/(exists $ENV{$1} ? $ENV{$1} : "")/ge' \
        "$template" > "$target"
    done
    shopt -u nullglob
    echo "  ✓ Rendered agent files from agents/$agent/"
  else
    echo "  ⚠ No agent directory found at agents/$agent/ — skipping file copy"
  fi

  echo "✅ $agent workspace created at $AGENT_DIR"
done

# ── Shared references ────────────────────────────────────────────────────────
echo ""
echo "📋 Copying shared references..."
for agent in "${AGENTS[@]}"; do
  AGENT_DIR="$BASE_DIR/$agent"
  [ -d "$AGENT_DIR/references" ] || mkdir -p "$AGENT_DIR/references"

  if [ -f "$REFS_DIR/team-constitution.md" ]; then
    if [ "$FORCE" = true ]; then
      cp -f "$REFS_DIR/team-constitution.md" "$AGENT_DIR/references/"
    else
      cp -n "$REFS_DIR/team-constitution.md" "$AGENT_DIR/references/" 2>/dev/null || true
    fi
  fi

  if [ -f "$REFS_DIR/team-board.md.example" ]; then
    if [ "$FORCE" = true ]; then
      cp -f "$REFS_DIR/team-board.md.example" "$AGENT_DIR/references/team-board.md"
    elif [ ! -f "$AGENT_DIR/references/team-board.md" ]; then
      cp "$REFS_DIR/team-board.md.example" "$AGENT_DIR/references/team-board.md"
    fi
  elif [ -f "$REFS_DIR/team-board.md" ]; then
    if [ "$FORCE" = true ]; then
      cp -f "$REFS_DIR/team-board.md" "$AGENT_DIR/references/"
    else
      cp -n "$REFS_DIR/team-board.md" "$AGENT_DIR/references/"
    fi
  fi
done
echo "  ✓ References copied"

# ── Shared scripts ───────────────────────────────────────────────────────────
echo "📜 Copying scripts..."
SHARED_SCRIPTS=("self-heal.sh" "trash-agent-session.sh" "agent-health-check.sh")
for agent in "${AGENTS[@]}"; do
  AGENT_DIR="$BASE_DIR/$agent"
  [ -d "$AGENT_DIR/scripts" ] || mkdir -p "$AGENT_DIR/scripts"

  for script in "${SHARED_SCRIPTS[@]}"; do
    if [ -f "$SCRIPTS_DIR/$script" ]; then
      if [ "$FORCE" = true ]; then
        cp -f "$SCRIPTS_DIR/$script" "$AGENT_DIR/scripts/"
      else
        cp -n "$SCRIPTS_DIR/$script" "$AGENT_DIR/scripts/" 2>/dev/null || true
      fi
      chmod +x "$AGENT_DIR/scripts/$script"
    fi
  done
done
echo "  ✓ Scripts copied"

# ── Config examples ──────────────────────────────────────────────────────────
echo "⚙️  Copying config examples..."
for agent in "${AGENTS[@]}"; do
  AGENT_DIR="$BASE_DIR/$agent"
  EXAMPLE="$CONFIGS_DIR/$agent.openclaw.json.example"

  if [ -f "$EXAMPLE" ]; then
    if [ "$FORCE" = true ]; then
      cp -f "$EXAMPLE" "$AGENT_DIR/openclaw.json.example"
    else
      cp -n "$EXAMPLE" "$AGENT_DIR/openclaw.json.example" 2>/dev/null || true
    fi
    echo "  ✓ $agent config example copied"
  else
    echo "  ⚠ No config example found for $agent at $EXAMPLE"
  fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "================================"
echo "✅ All workspaces created!"
echo ""
echo "Next steps:"
echo ""
echo "1. Create Telegram bots via @BotFather (one per agent)"
printf "   Use agent ids: %s\n" "${AGENTS[*]}"
echo ""
echo "2. Configure each agent:"
printf "   For each agent in: %s\n" "${AGENTS[*]}"
echo "   ┌──────────────────────────────────────────────────────────────────┐"
   echo "   │  mkdir -p ${OPENCLAW_DIR}/agents/<agent>                            │"
echo "   │  cp $BASE_DIR/<agent>/openclaw.json.example \\                  │"
   echo "   │     ${OPENCLAW_DIR}/agents/<agent>/openclaw.json                   │"
echo "   │  # Edit: replace bot tokens, OWNER_TELEGRAM_ID,             │"
echo "   │        OPENCLAW_AUTH_CHOICE / OPENAI_API_KEY, ...           │"
echo "   └──────────────────────────────────────────────────────────────────┘"
echo ""
echo "3. Start agents:"
echo "   bash $SCRIPT_DIR/start-team.sh"
echo ""
echo "4. Verify by messaging orchestrator ($ORCHESTRATOR_ID) in Telegram: 'Hello, are you there?'"
