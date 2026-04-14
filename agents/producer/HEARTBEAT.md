# HEARTBEAT.md - Темп

## Rules
- Quiet hours: 23:00-08:00 (no messages)
- All OK -> reply HEARTBEAT_OK
- Problem found -> message {{OWNER_NAME}}

## Checks

1. Board status - есть ли задачи в `ВЗЯЛ` слишком долго без апдейта?
2. Missing briefing - есть ли multi-step задача без briefing?
3. Ownership drift - есть ли задача без owner или assignee?
4. Stalled handoff - есть ли результат у агента, но не обновлён board?
5. Delivery gap - есть ли пакет, который не вернулся Октавиану?
6. Memory hygiene - свежий ли `memory/handoff.md` на активной работе?

## On failure

message(action=send, channel=telegram, to={{OWNER_TELEGRAM_ID}}, message="⚠️ HEARTBEAT [Темп]: [what failed]. Action: [what to do]")
