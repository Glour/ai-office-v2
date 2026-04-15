# TEAM_CONTEXT_VIBEGENT_2026-04-14.md

Расширенный safe-context для `agent-team`.
Только operational/project факты, без токенов, raw env и личных секретов.

## 1) Главные люди и стиль работы
- Главный человек: Александр Олегович Богданов.
- Обращаться к нему на `вы`.
- Ассистент: Ваня.
- Стиль ответов: коротко, прямо, без воды.
- Для долгих задач: короткий живой старт, потом работа, потом финал.
- Режим по умолчанию: action-first.

## 2) Полная карта известных серверов и ролей
- `178.104.16.119` — **Команда агентов**, prod host `agent-team`.
  - hostname: `wam-agent-volume`
  - OpenClaw state: `/root/.openclaw`
  - team repo: `/root/home/agent-team`
  - live team workspaces: `/root/home/openclaw-agents`
- `46.225.185.7` — **prod backend host** (`viably-prod`).
  - роль: prod backend / prod landing / prod infra
  - главный проектный путь: `/root/home/agent-platform/`
- `46.225.63.177` — **dev host** (`viably-dev`).
  - роль: dev / staging / ручные проверки / прежний personal-контур
  - важный риск: на нём мог оставаться старый Telegram polling-контур
- `95.217.20.174` — **Vibegent worker** (`vibegent-worker-01`).
  - роль: только worker для пользовательских agent containers
- `46.225.161.230` — занятый WAM/OpenClaw host.
  - правило: не использовать как чистую базу под новый team deploy поверх живого `/root/.openclaw`
- Дополнительные известные хосты из памяти:
  - `188.227.84.80` — Magnet
  - `78.111.86.194` — WBcon
  - `92.246.128.158` — Настин бот

## 3) Жёсткие infra-правила
- Пользовательские контейнеры Vibegent должны жить только на `95.217.20.174`.
- На backend-хостах `46.225.185.7` и `46.225.63.177` user-agent контейнеры держать нельзя.
- Перед любыми server/infra изменениями сначала подтверждать `hostname` и public IP.
- Все проектные директории держать только в `/root/home/`.
- На worker нельзя открывать наружу Docker TCP `2375`.

## 4) Главные проекты и где они лежат
### На основной infra-машине / в общей рабочей карте
- `agent-platform` — `/root/home/agent-platform`
  - Git remote: `git@github.com:viably-labs/vibegent.git`
  - backend, provisioning, workspace generation, landing, skills, grafana, bot-farm, support-bot, stress-test
- `agent-team` — `/root/home/agent-team`
  - Git remote: `git@github.com:Glour/agent-team.git`
  - multi-agent team repo, shared memory pack, setup/deploy logic
- `viably` — `/root/home/viably`
  - Git remote: `git@github.com:Glour/viably.git`
  - AI-powered platform for building Telegram bots and backend apps
- `viably-proxy` — `/root/home/viably-proxy`
- `vibegent-proxy` — `/root/home/vibegent-proxy`
- `vibegent-proxy-codex` — `/root/home/vibegent-proxy-codex`
- `vibegent-landing` — `/root/home/vibegent-landing`
- `vibegent-landing-v2` — `/root/home/vibegent-landing-v2`
- `vibegent-stress-test` — `/root/home/vibegent-stress-test`
  - E2E/stress scripts для проверки создания и работы агентов
- `openclaw-vk-plugin` — `/root/home/openclaw-vk-plugin`
  - отдельная разработка channel plugin для VK
- `agentforge-openclaw` — `/root/home/agentforge-openclaw`
  - Git remote: `https://github.com/AlekseiUL/agentforge-openclaw.git`
  - конструктор агентов и skills для OpenClaw
- `portfolio` — `/root/home/portfolio`
  - Git remote: `git@github.com:Glour/portfolio.git`
  - персональный Next.js portfolio Александра Олеговича
- `ai-gateway` — `/root/home/ai-gateway`
- `cliproxyapi` — `/root/home/cliproxyapi`
  - proxy API для OpenAI/Gemini/Claude/Codex-compatible CLI access
- `sprut-agent-kit` — `/root/home/sprut-agent-kit`
  - starter kit AI-агента с memory/skills/crons
- `tool-proxy` — `/root/home/tool-proxy`
- `token-pool` — `/root/home/token-pool`
- `vk-bridge` — `/root/home/vk-bridge`

### Важные подпроекты внутри `agent-platform`
- `backend/` — FastAPI backend платформы
- `frontend/` — mini app / UI
- `landing/` — отдельный landing
- `bot-farm/` — служебный бот-слой
- `support-bot/` — support bot для платформы
- `grafana/` — dashboards/monitoring
- `nginx/` — reverse proxy config
- `skills/` — shared skill library для агентных workspaces
- `agent-template/` — шаблон генерируемого workspace
- `agent-volumes/` — volume data агентных окружений
- `vibegent-proxy/` — proxy контур для агентских запросов
- `oauth-fuel/` — OAuth/auxiliary auth layer

### На `Команде агентов` (`178.104.16.119`)
- team repo: `/root/home/agent-team`
- expected curated workspaces root: `/root/home/openclaw-agents/<agent>`
- ещё существует второй root: `/root/openclaw-agents/<agent>`
- live OpenClaw agent state: `/root/.openclaw/agents/<agent>`
- global OpenClaw memory: `/root/.openclaw/memory`
- backups: `/root/home/openclaw-backups`

## 5) Команда agent-team, роли и живой runtime
### Состав команды
- `orchestrator`
- `producer`
- `frontend`
- `backend`
- `tester`
- `design`
- `content`
- `media`
- `research`
- `admin`

### Логика работы
- `orchestrator` — пользовательская входная точка и финальная доставка.
- `producer` — coordination layer: decomposition, plan, handoff.
- Профильные агенты отвечают в своих topic напрямую.
- Если пользователь пишет оркестратору и просит делегировать, схема работы: `orchestrator -> producer -> specialists -> orchestrator`.

### Где живёт truth для команды
- Repo source-of-truth: `/root/home/agent-team`
- Curated shared memory: `TEAM_MEMORY.md`, `TEAM_DECISIONS.md`, `TEAM_OPERATIONS.md`, `TEAM_INCIDENTS.md`, этот файл
- Live workspaces: `/root/home/openclaw-agents`
- Live sessions: `/root/.openclaw/agents/<agent>/sessions`

## 6) Что уже зафиксировано по team deploy
- Prod `agent-team` развернут на `178.104.16.119`.
- OpenClaw profile: `default`.
- Default agent: `orchestrator`.
- Gateway живёт в `/root/.openclaw` и поднимается через systemd.
- Telegram multi-account routing работает через `accounts` + top-level `bindings`.
- Для будущих deploy в `scripts/setup.sh` уже добавлен persistent config:
  - `tools.sessions.visibility="all"`
  - `tools.agentToAgent.enabled=true`
  - `tools.agentToAgent.allow=[orchestrator,frontend,backend,design,content,media,research]`

### Текущий live drift, который нельзя забывать
- На `178.104.16.119` сейчас видны **два разных workspace roots**:
  - `/root/openclaw-agents`
  - `/root/home/openclaw-agents`
- Они уже расходятся по составу: в `/root/openclaw-agents` есть `admin` и `producer`, а в `/root/home/openclaw-agents` их нет.
- В state dir `/root/.openclaw/agents` сейчас видно `11` каталогов вместо ожидаемых `10`, потому что там остаётся stale `main`.
- У stale `main` уже почти нет нормального agent payload, но directory всё ещё существует и может путать future-diagnosis.
- Вывод: при любой диагностике team-контура сначала различать:
  - repo truth,
  - state dir truth,
  - workspace root truth,
  - stale leftovers.

## 7) Подтверждённые боевые кейсы для agent-team
- На prod `178.104.16.119` после фиксов проходило межагентное делегирование через `sessions_send`.
- Проходил живой Telegram group-topic smoke-test:
  - group: `-1003711866483`
  - topic: `1`
  - orchestrator смог делегировать в backend и вернуть реальный ответ в группу.
- После repair-fix исчезала ошибка `pairing required` для cross-agent операций.

## 8) Важные Telegram и OpenClaw lessons learned
### Polling conflict
- Если Telegram-агенты молчат, одна из первых проверок: нет ли второго контура, который поллит те же bot tokens.
- Уже был реальный кейс: старый `personal`-контур на `46.225.63.177` создавал `409 Conflict: terminated by other getUpdates request`.
- После отключения старого polling контура и рестарта продового gateway на `178.104.16.119` team восстановился.

### Конфиг после апдейтов OpenClaw
- На OpenClaw `2026.4.12+` Telegram `topics` должны храниться как object, не list.
- Для streaming нужно использовать nested-формат `streaming.mode`, а не legacy scalar `streaming`.
- После апдейтов OpenClaw возможна ситуация, когда update-скрипт пугает restart-аномалией, но gateway потом сам нормально поднимается. Всегда перепроверять живой `status --deep`.

### Device auth / pairing required
- На prod `agent-team` был реальный кейс stale device auth.
- Симптом: `sessions_spawn` или межагентные вызовы падали с `pairing required`.
- Корень: локальный `gateway-client` имел урезанный scope set.
- Рабочий fix: обновить paired scope baseline, выпустить новый full-scope токен через `openclaw devices rotate`, синхронизировать `device-auth.json`, убрать stale pending repair.

## 9) Vibegent, главные зафиксированные факты
### Обязательные core skills
- `ru-text`
- `self-improving-agent`

Они должны существовать:
- в БД/дефолтах новых агентов,
- в provisioning,
- в live workspace агентов.

### AI-OPS-019 для Telegram
- ранний короткий ACK,
- self-closing финальный ответ,
- без сырой служебки в direct chat,
- один компактный ответ вместо простыни,
- если streaming ломает UX, не держать его включённым по инерции.

### Ключевой UX-урок
- `ru-text` и `self-improving-agent` сами по себе не гарантируют хороший Telegram UX.
- Нужны ещё runtime/prompt-ограничения и дисциплина вывода.

## 10) Nova, специальный кейс
- Агент: `Nova platform`
- Agent ID: `8787d80d-d9f5-456b-9722-798b5765044e`
- Bot: `@nova_platform_bot`
- Container: `vibegent-agent-8787d80dd9f5`
- Workspace: `/root/.vibegent-agent-8787d80dd9f5`

### Что ломалось
- длинные ответы,
- плохое форматирование,
- один ответ уходил несколькими Telegram-сообщениями.

### Что уже помогло
- добавлены правила `Telegram Output Discipline`,
- `streaming` для Nova переключён с `partial` на `off`,
- контейнер перезапущен,
- после фикса бот поднимался нормально.

### Практическое правило
- Для проблем Telegram UX сначала смотреть не только skills, но и:
  - session bloat,
  - partial streaming,
  - output rules,
  - live logs после рестарта.

## 11) Rollout по Vibegent, что уже было сделано
- Source of truth правился в:
  - `/root/home/agent-platform/backend/app/services/agent_service.py`
  - `/root/home/agent-platform/generate-workspace.sh`
  - `/root/home/agent-platform/provision-agent.sh`
  - `/root/home/agent-platform/skills/ru-text`
  - `/root/home/agent-platform/skills/self-improving-agent`
- В prod DB у 15 не удалённых агентов были оба core skill.
- На worker были пропатчены и перезапущены 17 `vibegent-agent-*` контейнеров.
- Важно помнить mismatch: `17 running` vs `15 non-deleted DB`, вероятно 2 stale/orphan контейнера.

## 12) История платформенных фич и важных результатов
### Agent Platform / Vibegent
- были внедрены уведомления прогресса при создании агента;
- был добавлен лимит агентов по тарифу;
- была добавлена `/stats` и статистика в боте;
- была внедрена реферальная система;
- был внедрён `Agent Health Check` через APScheduler;
- был добавлен support-бот `@vibegent_support_bot` с форвардом в support group;
- billing flow работал с credit packs и планами;
- heartbeat billing был отдельно исправлен, чтобы heartbeat не сжигал кредиты.

### Viably / Landing / B2B
- prod landing `agents.viably.dev` был переделан под B2B-позиционирование;
- добавлена lead-форма и новый оффер AI-отдела под ключ;
- Mini App на prod был приведён в рабочее состояние;
- Stripe integration и webhook `https://viably.dev/api/stripe/webhook` уже поднимались;
- later payment focus смещался в сторону ЮKassa/NowPayments.

### Monitoring / Ops surfaces
- На prod `46.225.185.7` уже поднимались:
  - `https://grafana.viably.dev`
  - `https://portainer.viably.dev`
- В памяти зафиксирован Dozzle:
  - prod `http://46.225.185.7:9999`
  - dev `http://46.225.63.177:9999`

## 13) Технические lessons learned, которые уже стоили времени
- Если Vibegent-агенты молчат, проверять не только routing, но и падение рантайма из-за sandbox/config.
- Реальный корень молчания уже ловился: `sandbox.mode = all` внутри agent containers, где не было нормального Docker окружения.
- Для OpenClaw `2026.4.5` нельзя ставить `npm install -g openclaw@2026.4.5 --ignore-scripts`, иначе возможен сломанный install и агенты перестают стартовать.
- `uvicorn` не даёт хорошие access logs по умолчанию, для реального HTTP debug часто смотреть nginx logs или БД.
- Если backend код запечён в образ, одного `docker restart` мало, нужен rebuild + recreate.
- На слабом сервере с 2GB RAM нельзя запускать параллельные Docker build, можно поймать OOM.
- Если удалённый файл мог дрейфовать, сначала синхронизировать его реальное состояние, потом править.

## 14) Безопасность и риски
- На worker `95.217.20.174` уже находили критичные риски:
  - публичный Docker `2375`,
  - выключенный `ufw`,
  - сильный SSH-шум.
- Это не мелочь, а постоянный infra-риск.
- Любые новые работы на worker делать с мыслью о hardening, а не только о feature velocity.

## 15) Полезные operational paths
### Agent Platform
- `/root/home/agent-platform/backend/`
- `/root/home/agent-platform/frontend/`
- `/root/home/agent-platform/landing/`
- `/root/home/agent-platform/generate-workspace.sh`
- `/root/home/agent-platform/provision-agent.sh`
- `/root/home/agent-platform/skills/`

### Agent Team
- `/root/home/agent-team/scripts/setup.sh`
- `/root/home/agent-team/team-config.sh`
- `/root/home/agent-team/agents/`
- `/root/home/agent-team/skills/`
- `/root/home/agent-team/references/`

### Team live runtime
- `/root/.openclaw/agents/orchestrator/sessions/`
- `/root/.openclaw/agents/backend/sessions/`
- `/root/home/openclaw-agents/orchestrator/`
- `/root/home/openclaw-agents/backend/`

## 16) Дополнительные project markers
- Vibegent news channel chat id: `-1003773191950`.
- Support group для `@vibegent_support_bot` исторически фигурировала как `-1003808902398`.
- Telegram direct user ID Александра Олеговича не является shared-secret, но личные user-specific данные разносить только если они operationally нужны.
- Session string для platform backend исторически лежал в `/root/agent-platform/backend/.env` как `TELEGRAM_SESSION_STRING`.
- Auto-create и auto-delete ботов через BotFather уже доводились до рабочего состояния.
- Верификация ЮKassa упиралась не только в код, но и в описания продуктов/цен в самом боте.
- На `dev` использовался platform webhook `https://agents.dev.viably.dev/api/bot/webhook`.
- Исторический crypto webhook: `https://agents.dev.viably.dev/api/payments/crypto/webhook`.

## 17) Как действовать дальше, если задача про наш стек неясна
1. Определить: это `agent-team`, `agent-platform`, `Vibegent`, `Viably` или отдельный side-project.
2. Подтвердить целевой сервер через `hostname` + IP.
3. Уточнить: repo source-of-truth или live runtime.
4. Если Telegram проблема, первым делом исключить polling conflict и config drift.
5. Если агент молчит, проверить runtime, sandbox, sessions, memory bloat и live logs.

## 18) Что нельзя переносить даже в shared team memory
- токены,
- raw `.env`,
- auth profiles,
- device secrets,
- приватные личные заметки,
- сырую сессионную историю без sanitization.

## 19) Что уже синхронизировано в team runtime
- Этот файл должен жить в repo: `/root/home/agent-team/TEAM_CONTEXT_VIBEGENT_2026-04-14.md`.
- Копия также может лежать в `/root/.openclaw/memory/TEAM_CONTEXT_VIBEGENT_2026-04-14.md`.
- После sync через `bash scripts/setup.sh` файл должен появляться в `/root/.openclaw/agents/<agent>/agent/TEAM_CONTEXT_VIBEGENT_2026-04-14.md`.
- Если repo обновили, а agent dirs не видят новые факты, сначала проверять именно несделанный sync.

## 20) Практический смысл этого файла
- Это curated operational context.
- Его задача: ускорять работу команды, уменьшать повторные раскопки и не наступать на уже известные грабли.
- Если новый факт доказан live-проверкой и безопасен для shared-layer, его можно добавлять сюда или в соседние `TEAM_*.md`.
