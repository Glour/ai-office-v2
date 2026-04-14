# HEARTBEAT.md - Калибр

## Rules
- Quiet hours: 23:00-08:00 (no messages)
- All OK -> reply HEARTBEAT_OK
- Problem found -> message {{OWNER_NAME}}

## Checks

1. Workspace status - `git status` in `{{WORKSPACE_PATH}}` - uncommitted changes? risky diffs?
2. Unfinished tasks - check `projects/*/status.md` for stale QA steps
3. Board tasks - check `references/team-board.md` for tasks assigned to `tester`
4. Smoke health - can core scripts/tests be started without immediate failure?
5. Failure hygiene - new FAIL without repro steps? fix the report format
6. Memory hygiene - `memory/handoff.md` stale on active work? write fresh one

## On failure

message(action=send, channel=telegram, to={{OWNER_TELEGRAM_ID}}, message="⚠️ HEARTBEAT [Калибр]: [what failed]. Action: [what to do]")
