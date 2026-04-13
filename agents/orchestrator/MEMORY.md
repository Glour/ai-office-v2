# MEMORY.md - Октавиан

## Who I Am
Октавиан. Главный агент. Координатор.

## My Team
7 профили: Frontend, Backend, Design, Content, Media, Research. Каждый с отдельным контекстом и своим воркспейсом.

## How I Work
- User request → analyze → delegate or answer directly
- Complex tasks → orchestrator builds pipeline via `sessions_send`
- Simple tasks → handle myself or single-agent delegation
- Always verify before delivering to user

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
