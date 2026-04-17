#!/bin/bash
# Умный сброс тяжёлых сессий агента перед новой задачей.
# По умолчанию работает только с main-сессией.
# Флаг --all включает topic/direct/main-сессии этого агента.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_DIR/team-config.sh"
TEAM_AGENTS=( $(team_agent_ids) )

AGENT="${1:-}"
THRESHOLD=50000
FORCE=false
SCOPE="main"

if [ -n "$AGENT" ]; then
  shift
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --force)
      FORCE=true
      ;;
    --all|--all-sessions|--scope=all)
      SCOPE="all"
      ;;
    --main|--scope=main)
      SCOPE="main"
      ;;
    --threshold=*)
      THRESHOLD="${1#*=}"
      ;;
    *)
      echo "❌ Неизвестный флаг: $1"
      echo "Использование: bash trash-agent-session.sh <agent_id> [--force] [--all] [--threshold=N]"
      exit 1
      ;;
  esac
  shift
done

if [ -z "$AGENT" ]; then
  echo "Использование: bash trash-agent-session.sh <agent_id> [--force] [--all] [--threshold=N]"
  printf "Агенты: %s\n" "${TEAM_AGENTS[*]}"
  echo "Порог: ${THRESHOLD} токенов (--force игнорирует)"
  exit 1
fi

SESSION_DIR="$HOME/.openclaw/agents/$AGENT/sessions"
SESSION_FILE="$SESSION_DIR/sessions.json"
if [ ! -f "$SESSION_FILE" ]; then
  echo "❌ Файл не найден: $SESSION_FILE"
  exit 1
fi

SESSION_FILE="$SESSION_FILE" \
SESSION_DIR="$SESSION_DIR" \
AGENT="$AGENT" \
THRESHOLD="$THRESHOLD" \
FORCE="$FORCE" \
SCOPE="$SCOPE" \
python3 - <<'PY'
import json
import os
import shutil
import sys
from datetime import UTC, datetime
from pathlib import Path

session_file = Path(os.environ["SESSION_FILE"])
session_dir = Path(os.environ["SESSION_DIR"])
agent = os.environ["AGENT"]
threshold = int(os.environ["THRESHOLD"])
force = os.environ["FORCE"].lower() == "true"
scope = os.environ["SCOPE"]

with session_file.open(encoding="utf-8") as fh:
    data = json.load(fh)

main_key = f"agent:{agent}:main"
prefix = f"agent:{agent}:"

def is_relevant_key(key: str) -> bool:
    if scope == "main":
        return key == main_key
    if not key.startswith(prefix):
        return False
    return ":subagent:" not in key

matching = [(key, meta) for key, meta in data.items() if is_relevant_key(key)]
if not matching:
    scope_label = "main" if scope == "main" else "main/topic/direct"
    print(f"⏭️ {agent}: подходящих сессий нет ({scope_label})")
    raise SystemExit(0)

trash_dir = session_dir / "_trash" / datetime.now(UTC).strftime("%Y%m%d-%H%M%S")
removed = []
skipped = []

for key, meta in matching:
    tokens = int(meta.get("totalTokens", 0) or 0)
    status = str(meta.get("status", "unknown"))
    session_id = str(meta.get("sessionId", "")).strip()
    should_remove = force or status == "done" or tokens >= threshold

    if not should_remove:
        skipped.append((key, tokens, status))
        continue

    if status == "done" and not force:
        print(f"⚠️ {agent}: {key} завершена (done, {tokens} tokens) — сбрасываю")

    removed.append((key, tokens, status, session_id))
    del data[key]

    if session_id:
        trash_dir.mkdir(parents=True, exist_ok=True)
        for candidate in session_dir.glob(f"{session_id}*"):
            target = trash_dir / candidate.name
            if target.exists():
                target = trash_dir / f"{candidate.name}.{len(removed)}"
            try:
                shutil.move(str(candidate), str(target))
            except FileNotFoundError:
                pass

with session_file.open("w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
    fh.write("\n")

if not removed:
    for key, tokens, status in skipped:
        print(f"⏭️ {agent}: пропускаю {key} ({tokens} tokens, status={status})")
    raise SystemExit(0)

for key, tokens, status, session_id in removed:
    sid = f", sessionId={session_id}" if session_id else ""
    print(f"✅ {agent}: сброшена {key} ({tokens} tokens, status={status}{sid})")

if skipped:
    print(f"ℹ️ {agent}: оставлено {len(skipped)} лёгких сессий")
PY
