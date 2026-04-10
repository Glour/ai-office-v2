# HEARTBEAT.md — Блик

## Rules
- Quiet hours: 23:00-08:00 (no messages)
- All OK → reply HEARTBEAT_OK
- Problem found → message {{OWNER_NAME}}

## Checks

1. **Daily goals file** — Does `goals/` have today's entry? If missing on a workday — create from weekly plan
2. **OKR progress** — Check `goals/2-monthly.md` — any metric not updated in > 3 days? Run analytics
3. **Habit tracker** — `habits/tracker.md` — today's habits logged? If evening (after 20:00) and missing — gentle reminder
4. **Media check** — Есть ли незакрытый пакет в `projects/*/media/` дольше 24h?
5. **Asset freshness** — `media/` assets валидны по формату и отсутствуют ли битые файлы
6. **Prep** — Нужны ли доп. рендеры по ближайшему релизу проекта?

## On failure

```
message(action=send, channel=telegram, to={{OWNER_TELEGRAM_ID}},
  message="⚠️ HEARTBEAT [Блик]: [what failed]. Action: [what to do]")
```

## Schedule
Every 30 minutes (quiet hours excluded)
Payload: "Run heartbeat checks per HEARTBEAT.md. Report failures."
