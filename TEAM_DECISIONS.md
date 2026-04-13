# TEAM_DECISIONS.md

Ключевые рабочие решения команды. Только то, что влияет на действия агентов.

## Архитектурные решения
- Team-деплой работает на стандартном OpenClaw profile `default`, а не на `personal`.
- State dir team-контура: `/root/.openclaw`.
- Agent workspaces team-контура: `/root/home/openclaw-agents`.
- Default agent: `orchestrator`.
- Для новой установки не использовать занятый `/root/.openclaw` на `46.225.161.230` как базу под чистый team-deploy.

## Telegram routing
- Для multi-account Telegram обязательны и `channels.telegram.accounts.<agent>`, и top-level `bindings`.
- Если боты молчат, сначала проверять `409 Conflict` и второй polling-контур, а не только bindings.
- Для OpenClaw `2026.4.12+` хранить `topics` как object с string-key topic ids.
- Для `2026.4.12+` использовать новый nested-формат `streaming.*`, не legacy scalar `streaming`.

## Ops-решения
- На server/infra задачах сначала проверять `hostname` и публичный IP, только потом менять систему.
- На живом контуре сначала read-only диагностика, потом правки.
- Если удалённый файл мог дрейфовать, сначала читать/синхронизировать актуальное состояние, потом редактировать.
- Все проектные директории держать только в `/root/home/`.

## Memory-sharing policy
- Команде можно давать только operational/project memory.
- Нельзя раздавать `SOUL.md`, чувствительные части `USER.md`, токены, auth profiles, raw env, chat ids и сырую личную память.
- Общий safe-layer команды хранить в `TEAM_*.md` файлах внутри agent workspaces.
