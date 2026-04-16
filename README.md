# Agent Team

Репозиторий для изолированной команды OpenClaw-агентов: `orchestrator`, `producer`, `frontend`, `backend`, `tester`, `design`, `content`, `media`, `research`, `admin`.

Текущее базовое состояние:
- профиль OpenClaw: `default` (`~/.openclaw`)
- дефолтная модель: `gpt-5.4`
- дефолтный thinking: `high`
- дефолтный reasoning: `on`
- typing indicator: `instant`
- voice transcription chain: `Deepgram -> OpenAI`
- default web search provider: `Perplexity` (если задан `PERPLEXITY_API_KEY`)
- межагентная маршрутизация: `sessions_send`
- operating model: `orchestrator -> producer -> specialists`
- Telegram-группа и топики: опционально, но поддерживаются штатно

## Как правильно изолировать агентов на одном сервере

Не нужен отдельный сервер под каждого агента.

Правильная схема:
- один сервер
- один OpenClaw profile под одну команду или одно окружение
- один общий gateway на этот profile
- отдельный workspace на каждого агента
- отдельный `agent dir` и отдельная память/сессии на каждого агента внутри profile

Рекомендуемый server layout:

```bash
OPENCLAW_PROFILE=alex-team
OPENCLAW_DIR=$HOME/.openclaw-alex-team
OPENCLAW_AGENTS_DIR=$HOME/openclaw-agents-alex-team
WORKSPACE_PATH=$HOME/openclaw-agents-alex-team
```

То есть изоляция делается не отдельными серверами, а через:
- `profile` — изоляция состояния OpenClaw команды
- `OPENCLAW_AGENTS_DIR/<agent>` — изоляция рабочего каталога агента
- `OPENCLAW_DIR/agents/<agent>` — изоляция runtime-конфига, prompt pack и sessions

Для постепенного rollout есть `ENABLED_AGENT_IDS`:

```bash
ENABLED_AGENT_IDS=orchestrator
```

Потом расширяешь:

```bash
ENABLED_AGENT_IDS=orchestrator,producer
ENABLED_AGENT_IDS=orchestrator,producer,frontend
```

Если `ENABLED_AGENT_IDS` не задан, поднимется вся команда из `team-config.sh`.

Ролевая карта:
- `orchestrator` - пользовательский вход, маршрутизация, финальная доставка
- `producer` - board-first координация, briefing, декомпозиция, handoff между агентами
- `frontend` / `backend` - production delivery по коду и интеграциям
- `tester` - QA + security smoke, acceptance, воспроизведение, базовые security-checks
- `design` / `content` / `media` / `research` - профильные продуктовые функции
- `admin` - admin/finance/ops документы, таблицы, реестры, отчеты, контуры согласования

Идентификаторы и имена команды задаются в `team-config.sh`. Один файл управляет всеми основными скриптами и шаблонами конфигов.

## Быстрый старт

1. Подготовь `.env`:

```bash
cp .env.example .env
```

2. Выбери способ авторизации:
- `OPENCLAW_AUTH_CHOICE=openai-codex` — рекомендованный путь через `codex login`
- `OPENCLAW_AUTH_CHOICE=openai-api-key` + `OPENAI_API_KEY=...` — прямой OpenAI API

Для нормальной изоляции на сервере сразу задай:

```bash
OPENCLAW_PROFILE=alex-team
OPENCLAW_DIR=$HOME/.openclaw-alex-team
OPENCLAW_AGENTS_DIR=$HOME/openclaw-agents-alex-team
WORKSPACE_PATH=$HOME/openclaw-agents-alex-team
ENABLED_AGENT_IDS=orchestrator
```

Опциональные интеграции, которые `bash scripts/setup.sh` включит автоматически для всей команды, если ключи заданы в серверном `.env`:
- `DEEPGRAM_API_KEY=...` — автоматическая расшифровка voice/audio
- `PERPLEXITY_API_KEY=...` — web search по умолчанию через `Perplexity`
- setup не пишет эти ключи в git: он перекладывает их в приватный `~/.openclaw/.env` на хосте

3. Разверни рабочие каталоги агентов:

```bash
bash scripts/deploy-team.sh
```

4. Инициализируй обычный контур OpenClaw, срендери конфиги и зарегистрируй агентов:

```bash
bash scripts/setup.sh
```

Когда будешь подключать следующего агента, просто меняешь `ENABLED_AGENT_IDS` в `.env` и повторяешь:

```bash
bash scripts/setup.sh
```

Это не требует нового сервера. Агент просто добавляется в тот же profile, но со своим отдельным workspace.

5. Подними общий gateway:

```bash
bash scripts/start-team.sh
```

6. Проверь состояние:

```bash
openclaw status
openclaw agents list
bash scripts/smoke-test.sh
```

## Telegram-режим

Если команда живёт в Telegram-группе с топиками, добавь в `.env`:

```bash
TEAM_TELEGRAM_GROUP_ID=-100...
ORCHESTRATOR_TOPIC_ID=1
PRODUCER_TOPIC_ID=11
FRONTEND_TOPIC_ID=13
BACKEND_TOPIC_ID=12
TESTER_TOPIC_ID=18
DESIGN_TOPIC_ID=16
CONTENT_TOPIC_ID=15
MEDIA_TOPIC_ID=17
RESEARCH_TOPIC_ID=14
ADMIN_TOPIC_ID=19
```

После этого примени routing:

```bash
bash scripts/configure-telegram-topics.sh
```

Практические defaults для стабильной topic-команды:
- у каждого агента свой уникальный `*_TELEGRAM_BOT_TOKEN`
- `TEAM_TELEGRAM_GROUP_SENDER_POLICY=open` — любой участник разрешённой группы может писать в topic без `@mention`
- `TEAM_TELEGRAM_DM_POLICY=allowlist` — прямые DM остаются под контролем owner allowlist
- если хотите owner-only режим в группе, включайте `TEAM_TELEGRAM_OWNER_ONLY_GROUPS=true`

Полезные команды:

```bash
bash scripts/send-team-topic.sh orchestrator "Разбей задачу между агентами"
bash scripts/send-team-topic.sh backend "Проверь API-маршрут и логи"
```

Ожидаемая модель работы:
- входная точка для пользователя — `orchestrator`
- multi-step и multi-agent задачи сначала уходят в `producer`
- прямой запрос в конкретный топик агенту тоже допустим
- быстрый inline handoff идёт через `sessions_send`, длинная user-facing работа — через `sessions_spawn` / completion path
- `tester` отвечает за repro, smoke/e2e, acceptance, security smoke и внятные bug reports
- `admin` ведёт таблицы, бюджеты, документы, согласования, административные и финансовые контуры

## Как устроен repo и память

Если хотите понять, что лежит в repo, что живёт только в runtime, где общая память команды и как её переносить руками, читайте:

- `docs/repository-structure-and-memory.md`

Коротко:
- `TEAM_*.md` — общий safe-layer памяти команды
- `agents/*/MEMORY.md` — роль-специфичная память
- `~/.openclaw/agents/*` и `/root/home/openclaw-agents/*` — live установленная команда
- `sessions/` и runtime state не являются автоматически git-источником истины

## Операционный контур

Основные скрипты:
- `scripts/deploy-team.sh` — создаёт/обновляет workspaces агентов
- `scripts/render-openclaw-configs.sh` — рендерит `openclaw.json` из шаблонов
- `scripts/setup.sh` — регистрирует команду в обычном профиле OpenClaw, включает cross-agent delegation и безопасные queue defaults
- `scripts/start-team.sh` — поднимает gateway
- `scripts/stop-team.sh` — останавливает gateway
- `scripts/configure-telegram-topics.sh` — включает topic routing
- `scripts/send-team-topic.sh` — отправляет сообщение прямо в топик агента
- `scripts/smoke-test.sh` — быстрый контроль репозитория и установки

Board-first артефакты:
- `references/team-board.md.example` - каноническая доска задач
- `references/briefing-template.md` - шаблон briefing/handoff для `producer`
- `references/team-constitution.md` - правила маршрутизации, делегирования и recovery

## CI/CD автодеплой

В repo есть workflow:
- `.github/workflows/deploy.yml`

Как он работает:
- после успешного `Quality Check` на `main` запускается деплой по SSH на `178.104.16.119`
- workflow синхронизирует содержимое repo на сервер по SSH/`rsync`, не трогая серверный `.env` и `auth-profiles.json`
- на сервере выполняется `bash scripts/github-actions-deploy.sh`
- серверный скрипт затем делает `smoke-test`, `setup.sh`, `start-team.sh` и `post-update-check.sh`

Что нужно настроить в GitHub:
- Secret `DEPLOY_SSH_PRIVATE_KEY` — приватный SSH-ключ для доступа на сервер
- Secret `DEPLOY_KNOWN_HOSTS` — опционально, pinned `known_hosts`; если не задан, workflow сделает `ssh-keyscan`
- Variable `DEPLOY_USER` — опционально, по умолчанию `root`
- Variable `DEPLOY_PORT` — опционально, по умолчанию `22`
- Variable `DEPLOY_PATH` — опционально, по умолчанию `/root/home/agent-team`

Важно:
- сервер не обязан быть git clone; deploy идёт как sync repo payload -> apply runtime
- сервер должен хранить свой `.env` локально; CI его не передаёт и не генерирует
- workflow не трогает серверные `.env` и `auth-profiles.json`
- если хочешь запустить деплой руками, используй `workflow_dispatch` у `Deploy Team`

## Важно

- Не рассчитывай на старый сценарий `openclaw gateway start` «вручную из головы» без нормального профиля и service install.
- Не используй `openclaw gateway restart` внутри живой агентной сессии.
- Источник истины для команды — этот репозиторий и обычный контур OpenClaw, а не разрозненные ручные правки в агентных каталогах.
