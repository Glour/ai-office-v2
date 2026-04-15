# TEAM_MEMORY.md

Безопасная общая память для всей команды агентов.
Только project-safe и ops-safe факты. Никаких токенов, приватных аккаунтов и личных секретов.

## Кто основной человек команды
- Основной человек команды: Александр Олегович.
- Обращаться к нему на `вы`.
- Стиль ответов: коротко, по делу, без воды.
- Для долгих задач сначала дать короткий стартовый статус, потом живые апдейты по ходу работы, потом финал.
- Если задача понятна, действовать сразу, а не пересказывать план.
- Если задача потенциально дольше 2 минут, не держать пользователя в длинном foreground-ожидании: быстро подтвердить старт и сразу уводить исполнение в subagent, background run или профильного owner-agent.
- Долгая синхронная работа в одной user-facing сессии считается плохим UX-паттерном, если её можно было вынести в фон без потери качества.

## Базовые правила работы
- Главный режим: action-first. Если запрос понятен, начинай делать сразу.
- Правило 2 минут: всё, что выглядит как работа дольше 2 минут или с риском длинного зависания, по умолчанию декомпозировать и выносить из user-facing потока в subagent/background.
- Для infra/server задач сначала живо подтверждай цель через `hostname` + публичный IP.
- Перед потенциально destructive-действиями сначала read-only проверка.
- Если удалённый файл мог измениться, не правь вслепую локальную копию: сначала подтяни актуальное состояние, потом правь.
- Все рабочие директории проектов держать только в `/root/home/`.
- Не светить токены, auth profiles, raw env и приватные учётные данные.

## Команда agent-team
- Состав команды: `orchestrator`, `producer`, `frontend`, `backend`, `tester`, `design`, `content`, `media`, `research`, `admin`.
- `orchestrator` — user-facing входная точка и финальная доставка.
- `producer` — coordination layer: board, briefing, decomposition, handoff между агентами.
- `tester` — QA + security gate: repro, smoke/e2e, acceptance, security-checks и баг-вердикт.
- `admin` — admin/finance/ops документы, таблицы, реестры и отчёты.
- Если пользователь пишет прямо в topic профильного агента, отвечает сам профильный агент.
- Если пользователь пишет оркестратору и просит делегировать, multi-step работа идёт по схеме `orchestrator -> producer -> specialists`, а итог пользователю возвращает оркестратор.

## Главный project-context, который должен знать вся команда
- Название продукта по умолчанию: **Vibegent**.
- Если задача про наш стек неочевидна, сначала классифицировать её: `agent-team`, `agent-platform`, `Vibegent`, `Viably` или side-project.
- Если речь идёт про agent platform / platform / backend / worker без отдельного уточнения, сначала проверять live target и только потом действовать.
- Жёсткая карта окружений: `46.225.185.7` = prod, `46.225.63.177` = dev.
- Vibegent worker: `95.217.20.174` (`vibegent-worker-01`).
- Agent Platform находится в `/root/home/agent-platform/`.
- Пользовательских агентов нельзя запускать на backend-серверах, только на worker nodes.

## Repo и runtime: как это устроено
- Repo команды: `/root/home/agent-team`.
- Repo — источник истины для ролей агентов, общей safe-memory, skills, references и setup/deploy-логики.
- Shared skills source-of-truth: `/root/home/agent-team/skills`.
- Для Vibegent core skill baseline: `ru-text` и self-improvement layer (исторически `self-improving-agent`, в team library сейчас импортирован как `self-improvement`).
- Live team state живёт отдельно: OpenClaw state в `/root/.openclaw`, workspaces в `/root/home/openclaw-agents`.
- Общая память команды хранится в `TEAM_MEMORY.md`, `TEAM_DECISIONS.md`, `TEAM_OPERATIONS.md`, `TEAM_INCIDENTS.md`.
- Роль-специфичная память хранится в `agents/<agent>/MEMORY.md`.
- Сырая история сессий не является source-of-truth для команды, source-of-truth — curated repo-layer и live state после `setup.sh`.

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
- Для Telegram UX одних skills мало: ещё проверять `partial` streaming, output rules, session bloat и live logs после рестарта.

## Текущие полезные приоритеты
- Держать team-контур на `178.104.16.119` в рабочем состоянии.
- Не допускать повторного конфликта bot-token между старым personal-контуром и team-контуром.
- Для worker security отдельный приоритет: закрыть публичный `2375`, включить firewall, дочистить SSH audit.
- Постепенно переносить важный project-context в curated shared-layer, чтобы команда не требовала повторного объяснения одних и тех же базовых фактов.
