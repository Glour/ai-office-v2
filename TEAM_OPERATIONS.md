# TEAM_OPERATIONS.md

Короткий runbook для team-агентов.

## Боевой контур
- Host: `178.104.16.119`
- Hostname: `wam-agent-volume`
- Repo: `/root/home/agent-team`
- State: `/root/.openclaw`
- Agent workspaces: `/root/home/openclaw-agents`
- OpenClaw profile: `default`

## Базовые проверки
- Статус: `openclaw --profile default status --deep`
- Список агентов: `openclaw --profile default agents list`
- Логи: `openclaw --profile default logs --limit 40 --plain`
- Локальный пинг: `openclaw --profile default agent --agent orchestrator --local -m ping`

## Telegram checks
- Если Telegram молчит, смотреть health в `status --deep` и искать `409 Conflict` в логах.
- Проверять, что `accounts 7/7` и `Telegram OK`.
- После routing/config changes делать reload/restart gateway и повторную health-проверку.

## Config hygiene
- Перед повторным team setup или routing на OpenClaw `2026.4.12+` полезно прогонять `openclaw --profile default doctor --fix`.
- В Telegram config `topics` должны быть object, не list.
- Для streaming использовать nested keys `streaming.mode`, а не legacy scalar `streaming`.

## Infra guardrails
- Не запускать пользовательских агентов на backend-серверах.
- Не открывать Docker TCP `2375` наружу на worker nodes.
- Любой target-server сначала идентифицировать через `hostname` + public IP.
