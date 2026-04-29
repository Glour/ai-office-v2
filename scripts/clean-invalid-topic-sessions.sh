#!/usr/bin/env bash
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
STATE_DIR="$(team_openclaw_state_dir "$OPENCLAW_PROFILE")"
MODE="${1:-apply}"
if [ "$MODE" != "apply" ] && [ "$MODE" != "check" ]; then
  echo "Usage: $0 [apply|check]" >&2
  exit 64
fi

STATE_DIR="$STATE_DIR" MODE="$MODE" python3 - <<'PY'
import json, os, re, shutil
from datetime import UTC, datetime
from pathlib import Path

state_dir = Path(os.environ['STATE_DIR'])
mode = os.environ['MODE']
config = json.loads((state_dir / 'openclaw.json').read_text(encoding='utf-8'))
accounts = (((config.get('channels') or {}).get('telegram') or {}).get('accounts') or {})
expected = {}
for agent_id, account in accounts.items():
    for group_id, group in (account.get('groups') or {}).items():
        topics = group.get('topics') or {}
        if topics:
            expected[agent_id] = (str(group_id), str(next(iter(topics.keys()))))
            break

removed = []
for agent_id in expected:
    session_dir = state_dir / 'agents' / agent_id / 'sessions'
    session_file = session_dir / 'sessions.json'
    if not session_file.exists():
        continue
    data = json.loads(session_file.read_text(encoding='utf-8'))
    changed = False
    trash_dir = session_dir / '_trash' / datetime.now(UTC).strftime('%Y%m%d-%H%M%S-invalid-topic')
    for key, meta in list(data.items()):
        if ':subagent:' in key or ':telegram:group:' not in key:
            continue
        m = re.search(r'group:([^:]+):topic:(\d+)', key)
        if not m:
            continue
        actual = (m.group(1), m.group(2))
        if actual == expected[agent_id]:
            continue
        removed.append((agent_id, key, actual, expected[agent_id], meta.get('sessionId', '')))
        if mode == 'apply':
            changed = True
            del data[key]
            sid = str(meta.get('sessionId') or '').strip()
            if sid:
                trash_dir.mkdir(parents=True, exist_ok=True)
                for candidate in session_dir.glob(f'{sid}*'):
                    target = trash_dir / candidate.name
                    if target.exists():
                        target = trash_dir / f'{candidate.name}.dup'
                    try:
                        shutil.move(str(candidate), str(target))
                    except FileNotFoundError:
                        pass
    if changed:
        session_file.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

if not removed:
    print('OK no invalid topic sessions')
else:
    for agent_id, key, actual, exp, sid in removed:
        prefix = 'CLEANED' if mode == 'apply' else 'FOUND'
        sidp = f' sessionId={sid}' if sid else ''
        print(f'{prefix} {agent_id} {key} actual={actual} expected={exp}{sidp}')
PY
