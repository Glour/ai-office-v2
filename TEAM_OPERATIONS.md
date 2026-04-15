# TEAM_OPERATIONS.md

Короткий runbook для team-агентов.

## Боевой контур
- Host: `178.104.16.119`
- Hostname: `wam-agent-volume`
- Repo: `/root/home/agent-team`
- State: `/root/.openclaw`
- Agent workspaces: `/root/home/openclaw-agents`
- OpenClaw profile: `default`
- Default agent: `orchestrator`
- Agent count: `10` (`orchestrator`, `producer`, `frontend`, `backend`, `tester`, `design`, `content`, `media`, `research`, `admin`)

## Базовые проверки
- Статус: `openclaw --profile default status --deep`
- Список агентов: `openclaw --profile default agents list`
- Логи: `openclaw --profile default logs --limit 40 --plain`
- Локальный пинг: `openclaw --profile default agent --agent orchestrator --local -m ping`

## Telegram checks
- Если Telegram молчит, смотреть health в `status --deep` и искать `409 Conflict` в логах.
- Проверять, что `accounts N/N` соответствует текущему составу команды из `team-config.sh`, и что `Telegram OK`.
- После routing/config changes делать reload/restart gateway и повторную health-проверку.

## Long-work handling
- Если задача потенциально дольше 2 минут или многошаговая, не держать пользователя в длинном foreground-ожидании.
- Сначала дать короткий стартовый ответ, затем уводить длинную работу в subagent, background path или owner-agent.
- Для user-facing async возврата по умолчанию использовать completion-capable path: `sessions_spawn(agentId="...")` или owner flow через `producer`.
- `sessions_send(..., timeoutSeconds=0)` не считать owner-return механизмом. Это fire-and-forget without completion handoff.
- Особенно строго это правило для orchestration layer.
- Producer-first routing сохраняется: orchestration не должно залипать в одной сессии, если работу можно вынести в owner flow.

## Config hygiene
- Перед повторным team setup или routing на OpenClaw `2026.4.12+` полезно прогонять `openclaw --profile default doctor --fix`.
- В Telegram config `topics` должны быть object, не list.
- Для streaming использовать nested keys `streaming.mode`, а не legacy scalar `streaming`.
- После изменения общей памяти и role files source-of-truth остаётся в repo, а в live-контур это должно доезжать через `bash scripts/setup.sh`.
- После изменения shared skills source-of-truth остаётся в `/root/home/agent-team/skills`, а live agents должны получить обновления через `bash scripts/setup.sh`.

## Где что живёт
- Repo source-of-truth: `/root/home/agent-team`.
- Live OpenClaw agent dirs: `/root/.openclaw/agents/<agent>/agent`.
- Live workspaces: `/root/home/openclaw-agents/<agent>`.
- Дополнительно помнить про legacy drift root: `/root/openclaw-agents/<agent>`.
- Live sessions: `/root/.openclaw/agents/<agent>/sessions`.
- Curated shared memory: `TEAM_MEMORY.md`, `TEAM_DECISIONS.md`, `TEAM_OPERATIONS.md`, `TEAM_INCIDENTS.md`.
- Role memory: `agents/<agent>/MEMORY.md`.

## Диагностика team runtime
- При расследовании сначала различать 4 слоя: repo truth, state dir truth, workspace root truth, stale leftovers.
- На боевом хосте уже встречались одновременно два workspace roots: `/root/openclaw-agents` и `/root/home/openclaw-agents`.
- В `/root/.openclaw/agents` может оставаться stale каталог `main`, который путает диагностику и создаёт ложное ощущение лишнего агента.

## Shared skills and runtime capabilities
- Shared skills library source-of-truth: `skills/README.md` и `skills/*/SKILL.md` в repo.
- В repo команды сейчас есть библиотека из `33` shared skills.
- Для новой общей skill-базы дополнительно использовать `/root/home/agent-team/skills/ru-text` и `/root/home/agent-team/skills/self-improvement`.
- В команде доступны ключевые capability-группы: documents, research, content, development, automation, quality/security, diagnostics, utilities.
- Практически важные shared skills: `deep-research-pro`, `researcher`, `systematic-debugging`, `quality-check`, `writing-plans`, `brainstorming`, `presentation`, `github-publisher`, `skill-and-agent-creator`, `healthcheck`, `weather`, `gemini`.
- Подтверждённые live capabilities team-контура: Telegram multi-account routing, shared memory (`memory-core`), OpenAI/Codex runtime (`gpt-5.4`), cross-agent delegation через `sessions_send`, group-topic routing.
- Живой team-контур на `178.104.16.119` сейчас должен подтверждаться как Telegram `OK`, accounts `10/10`, default model `gpt-5.4`, memory plugin active.

## Infra guardrails
- Не запускать пользовательских агентов на backend-серверах.
- Не открывать Docker TCP `2375` наружу на worker nodes.
- На worker `95.217.20.174` уже встречались и другие hardening-риски: выключенный `ufw` и сильный SSH-шум.
- Любой target-server сначала идентифицировать через `hostname` + public IP.
- Если переносится память, переносить именно curated information, а не токены, raw env, auth profiles или чувствительные личные данные.

## Полезные paths вне team repo
- Agent Platform source-of-truth: `/root/home/agent-platform/backend/`, `/root/home/agent-platform/generate-workspace.sh`, `/root/home/agent-platform/provision-agent.sh`, `/root/home/agent-platform/skills/`.
- Если проблема касается Vibegent provisioning или default skills новых агентов, сначала смотреть именно эти paths.
