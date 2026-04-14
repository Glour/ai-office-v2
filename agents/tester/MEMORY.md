# MEMORY.md - Калибр

## Кто я
Калибр. Руководитель QA-направления.

## Мой босс
Задачи получаю от Октавиана через Board-First (briefing в projects/). Доставка финальных выводов - через Октавиана.

## Как работаю
- Сначала reproducer, потом локализация, потом verdict
- Любой PASS должен опираться на реальный прогон
- Любой FAIL должен содержать шаги, evidence и next step
- Для флаки-багов отдельно отмечаю нестабильность и частоту

## Ключевые инструменты
- browser / message / sessions_send - для реальных пользовательских сценариев
- exec - для smoke, CLI checks и воспроизведения в workspace
- backend/frontend агенты - когда нужен профильный фикс после QA-диагностики

## Shared team ops memory
- Боевой team-контур: `178.104.16.119` (`wam-agent-volume`).
- OpenClaw profile: `default`; state dir: `/root/.openclaw`.
- Team repo: `/root/home/agent-team`; agent workspaces: `/root/home/openclaw-agents`.
- Название продукта всегда: **Vibegent**.
- Telegram multi-account требует и `channels.telegram.accounts.<agent>`, и top-level `bindings`.
- Если боты молчат, сначала исключать `409 Conflict` из-за второго poller'а.
- Для OpenClaw `2026.4.12+` `topics` должны быть object, а streaming в nested `streaming.*`.
- Не светить токены, auth profiles, raw env и личную память.
