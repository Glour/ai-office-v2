#!/usr/bin/env bash
# team-config.sh — единая конфигурация имен и состава персональной команды

# Canonical agent ids (used in file paths, sessionKeys, workspace dirs)
TEAM_AGENT_IDS=(
  "orchestrator"
  "frontend"
  "backend"
  "design"
  "content"
  "media"
  "research"
)

TEAM_ORCHESTRATOR_ID="orchestrator"

# Читаемые имена для команд и отчетов
TEAM_AGENT_NAMES=(
  "Октавиан"
  "Лея"
  "Пульсар"
  "Сеть"
  "Глас"
  "Блик"
  "Радар"
)

team_agent_ids() {
  printf '%s\n' "${TEAM_AGENT_IDS[@]}"
}

team_agent_names() {
  printf '%s\n' "${TEAM_AGENT_NAMES[@]}"
}

team_orchestrator_id() {
  echo "$TEAM_ORCHESTRATOR_ID"
}

team_agent_name() {
  local needle="$1"
  local idx=0

  for id in "${TEAM_AGENT_IDS[@]}"; do
    if [ "$id" = "$needle" ]; then
      echo "${TEAM_AGENT_NAMES[$idx]}"
      return 0
    fi
    idx=$((idx + 1))
  done

  echo "$needle"
}

TEAM_AGENT_COUNT="${#TEAM_AGENT_IDS[@]}"
TEAM_RESEARCH_AGENT_ID="research"

team_openclaw_profile() {
  echo "${OPENCLAW_PROFILE:-default}"
}

team_openclaw_state_dir() {
  local profile="${1:-$(team_openclaw_profile)}"

  if [ -n "${OPENCLAW_DIR:-}" ]; then
    echo "$OPENCLAW_DIR"
  elif [ -z "$profile" ] || [ "$profile" = "default" ]; then
    echo "$HOME/.openclaw"
  else
    echo "$HOME/.openclaw-$profile"
  fi
}

team_openclaw_agents_dir() {
  echo "${OPENCLAW_AGENTS_DIR:-$HOME/openclaw-agents}"
}

team_agent_is_valid_id() {
  local needle="$1"
  local candidate

  for candidate in "${TEAM_AGENT_IDS[@]}"; do
    if [ "$candidate" = "$needle" ]; then
      return 0
    fi
  done

  return 1
}
