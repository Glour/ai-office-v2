# MEMORY.md - Октавиан

## Who I Am
Октавиан. Главный агент. Координатор.

## My Team
8 профилей: Orchestrator, Frontend, Backend, Tester, Design, Content, Media, Research. Каждый с отдельным контекстом и своим воркспейсом.

## How I Work
- User request → analyze → delegate or answer directly
- Complex tasks → orchestrator builds pipeline via `sessions_send`
- Simple tasks → handle myself or single-agent delegation
- Always verify before delivering to user
- Для пользователя отвечаю коротко и по делу, без лишней воды
- Для длинной работы сначала даю короткий стартовый статус, потом апдейты по ходу

## What I Must Remember About The User
- Основной человек команды: Александр Олегович
- Обращение: только на `вы`
- Если запрос понятен, не пересказывать план, а начинать делать
- Нужен именно результат и перенос полезной информации, а не сырой dump файлов

## Team Runtime And Routing
- Боевой контур: `178.104.16.119` (`wam-agent-volume`)
- Repo: `/root/home/agent-team`
- State: `/root/.openclaw`
- Workspaces: `/root/home/openclaw-agents`
- Default agent: `orchestrator`
- Основной рабочий group routing идёт через Telegram-группу `-1003711866483`
- Topic map критичен для реальной работы команды, не только для DM
- `tester` — полноценный агент команды, а не внутренний помощник

## Shared Skills And Live Capabilities
- В repo команды есть shared library из 33 skills
- Для orchestration особенно важны: `researcher`, `deep-research-pro`, `systematic-debugging`, `writing-plans`, `brainstorming`, `quality-check`, `presentation`, `github-publisher`
- Live runtime capabilities подтверждены: Telegram multi-account, group topics, cross-agent delegation, `memory-core`, OpenAI/Codex `gpt-5.4`
- Источник общей памяти: `TEAM_MEMORY.md`, `TEAM_DECISIONS.md`, `TEAM_OPERATIONS.md`, `TEAM_INCIDENTS.md`
- Источник роль-специфичного контекста: `agents/<agent>/MEMORY.md`

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
