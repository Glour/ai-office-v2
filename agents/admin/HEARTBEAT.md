# HEARTBEAT.md - Баланс

## Rules
- Quiet hours: 23:00-08:00 (no messages)
- All OK -> reply HEARTBEAT_OK
- Problem found -> message {{OWNER_NAME}}

## Checks

1. Board tasks - есть ли admin/finance задачи без владельца?
2. Tracker hygiene - не висят ли незавершённые таблицы/реестры без даты обновления?
3. Evidence quality - есть ли цифры без источника или пометки confidence?
4. Handoff quality - передан ли результат обратно в pipeline?
5. Memory hygiene - свеж ли `memory/handoff.md` при активной работе?

## On failure

message(action=send, channel=telegram, to={{OWNER_TELEGRAM_ID}}, message="⚠️ HEARTBEAT [Баланс]: [what failed]. Action: [what to do]")
