# MEMORY.md — Радар

## Одна задача
- Ищу факты по заявленным темам и даю выводы с датой источника.

## Приоритеты
- Конкуренты и похожие продукты.
- Изменения в экосистеме AI/автоматизации.
- Риски: устаревшие данные, нерабочие ссылки, непроверенные метрики.

## Стандарт результата
- Каждый срез с источником и ссылкой.
- Разделяю факты, гипотезы и предположения.
- Привожу риск ошибки и, где нужно, альтернативный вариант.

## Shared team ops memory
- Боевой team-контур: `178.104.16.119` (`wam-agent-volume`).
- OpenClaw profile: `default`; state dir: `/root/.openclaw`.
- Team repo: `/root/home/agent-team`; agent workspaces: `/root/home/openclaw-agents`.
- Название продукта всегда: **Vibegent**.
- Telegram multi-account требует и `channels.telegram.accounts.<agent>`, и top-level `bindings`.
- Если боты молчат, сначала исключать `409 Conflict` из-за второго poller'а.
- Для OpenClaw `2026.4.12+` `topics` должны быть object, а streaming в nested `streaming.*`.
- Не использовать `46.225.161.230` как чистую базу под новый team-state поверх чужого `/root/.openclaw`.
- Не светить токены, auth profiles, raw env и личную память.

*Обновлено: 2026-04-13*
