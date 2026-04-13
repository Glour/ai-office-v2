# TEAM_MEMORY.md

Безопасная общая память для всей команды агентов.
Только project-safe и ops-safe факты. Никаких токенов, приватных аккаунтов и личных секретов.

## Базовые правила работы
- Главный режим: action-first. Если запрос понятен, начинай делать сразу.
- Для infra/server задач сначала живо подтверждай цель через `hostname` + публичный IP.
- Перед потенциально destructive-действиями сначала read-only проверка.
- Если удалённый файл мог измениться, не правь вслепую локальную копию: сначала подтяни актуальное состояние, потом правь.
- Все рабочие директории проектов держать только в `/root/home/`.
- Не светить токены, auth profiles, raw env и приватные учётные данные.

## Команда agent-team
- Состав команды: `orchestrator`, `frontend`, `backend`, `design`, `content`, `media`, `research`.
- `orchestrator` — входная точка и диспетчер. Он делегирует через `sessions_send`.
- Если пользователь пишет прямо в topic профильного агента, отвечает сам профильный агент.
- Если пользователь пишет оркестратору и просит делегировать, итог пользователю возвращает оркестратор.

## Текущий team-контур
- Боевой team-контур развернут на `178.104.16.119`.
- Hostname этого контура: `wam-agent-volume`.
- Профиль OpenClaw для team-контурa: обычный `default`.
- State dir: `/root/.openclaw`.
- Agent workspaces: `/root/home/openclaw-agents`.
- Репозиторий team-контура: `/root/home/agent-team`.
- Default agent в team-контуре: `orchestrator`.
- Gateway поднимается через systemd.

## OpenClaw и Telegram: важные факты
- В team-контуре Telegram multi-account routing требует не только `channels.telegram.accounts.<agent>`, но и top-level `bindings`.
- Для DM через каждого бота одного account-конфига недостаточно, без binding возможен fallback не в того агента.
- Дублирование одних и тех же bot-token на двух живых контурах вызывает `409 Conflict: terminated by other getUpdates request`.
- После обновления OpenClaw до `2026.4.12` поле `topics` в Telegram group config должно быть object, не list.
- В legacy team-конфиге `topics` уже один раз ломались из-за хранения в виде массива с индексами topic-id. При миграциях это нужно проверять первым.

## Инфраструктурные ориентиры
- Название продукта всегда: **Vibegent**.
- Agent Platform: FastAPI + SQLAlchemy async + PostgreSQL + Redis.
- Backend контейнер платформы: `agentplatform-backend`, порт `8001`.
- PostgreSQL платформы: порт `5433`.
- Proxy endpoint для агентского трафика: `POST /api/proxy/v1/messages`.
- Пользовательских агентов нельзя запускать на backend-серверах, только на worker nodes.
- На worker nodes нельзя держать открытым наружу Docker TCP `2375`.

## Известные рабочие хосты
- `178.104.16.119` — текущий team host.
- `46.225.161.230` — отдельный занятый WAM/OpenClaw-хост, не использовать как чистый team state поверх существующего `/root/.openclaw`.

## Известные грабли
- Если после релиза/апдейта агенты «молчат», проверь не только routing, но и `getUpdates conflict` по Telegram.
- Если OpenClaw после апдейта не стартует, сначала читай полную ошибку валидации конфига, а не чини наугад.
- Если team setup отработал, но Telegram не жив, проверь root config, account-блоки, bindings и формат `topics`.

## Текущие полезные приоритеты
- Держать team-контур на `178.104.16.119` в рабочем состоянии.
- Не допускать повторного конфликта bot-token между старым personal-контуром и team-контуром.
- Для worker security отдельный приоритет: закрыть публичный `2375`, включить firewall, дочистить SSH audit.
