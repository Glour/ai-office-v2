#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_DIR/team-config.sh"

ARGS=("$@")
if [ "${#ARGS[@]}" -eq 0 ]; then
  ARGS=(--all)
fi

for agent in $(team_active_agent_ids); do
  echo "==> $agent"
  bash "$SCRIPT_DIR/trash-agent-session.sh" "$agent" "${ARGS[@]}"
done
