# HEARTBEAT.md — Сеть

## Rules
- Quiet hours: 23:00-08:00 (no messages)
- All OK → reply HEARTBEAT_OK
- Problem found → message {{OWNER_NAME}}

## Checks

1. **UX debt** — Есть ли неразрешённые TODO в текущих прототипах?
2. **Handoff gaps** — Любой незакрытый `frontend` тикет от дизайна старше 2h?
3. **Design tokens** — Проверить последние значения design-system (spacing/цвет/типографика)
4. **A11y checks** — Есть ли нарушения контраста/читабельности?
5. **Prototype freshness** — Нет ли устаревшего прототипа без комментария > 7d?

## On failure

```
message(action=send, channel=telegram, to={{OWNER_TELEGRAM_ID}},
  message="⚠️ HEARTBEAT [Сеть]: [what failed]. Action: [what to do]")
```

## Schedule
Every 30 minutes (quiet hours excluded)
Payload: "Run heartbeat checks per HEARTBEAT.md. Report failures."
