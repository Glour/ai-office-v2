# Agent Team

Репозиторий для изолированной команды OpenClaw-агентов: `orchestrator`, `producer`, `frontend`, `backend`, `tester`, `design`, `content`, `media`, `research`, `admin`.

Текущее базовое состояние:
- профиль OpenClaw: `default` (`~/.openclaw`)
- дефолтная модель: `gpt-5.4`
- дефолтный thinking: `high`
- дефолтный reasoning: `on`
- межагентная маршрутизация: `sessions_send`
- operating model: `orchestrator -> producer -> specialists`
- Telegram-группа и топики: опционально, но поддерживаются штатно

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

3. Разверни рабочие каталоги агентов:

```bash
bash scripts/deploy-team.sh
```

4. Инициализируй обычный контур OpenClaw, срендери конфиги и зарегистрируй агентов:

```bash
bash scripts/setup.sh
```

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

Полезные команды:

```bash
bash scripts/send-team-topic.sh orchestrator "Разбей задачу между агентами"
bash scripts/send-team-topic.sh backend "Проверь API-маршрут и логи"
```

Ожидаемая модель работы:
- входная точка для пользователя — `orchestrator`
- multi-step и multi-agent задачи сначала уходят в `producer`
- прямой запрос в конкретный топик агенту тоже допустим
- делегирование между агентами идёт через `sessions_send`, а не через хаотичную пересылку сообщений
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
- `scripts/setup.sh` — регистрирует команду в обычном профиле OpenClaw
- `scripts/start-team.sh` — поднимает gateway
- `scripts/stop-team.sh` — останавливает gateway
- `scripts/configure-telegram-topics.sh` — включает topic routing
- `scripts/send-team-topic.sh` — отправляет сообщение прямо в топик агента
- `scripts/smoke-test.sh` — быстрый контроль репозитория и установки

Board-first артефакты:
- `references/team-board.md.example` - каноническая доска задач
- `references/briefing-template.md` - шаблон briefing/handoff для `producer`
- `references/team-constitution.md` - правила маршрутизации, делегирования и recovery

## Важно

- Не рассчитывай на старый сценарий `openclaw gateway start` «вручную из головы» без нормального профиля и service install.
- Не используй `openclaw gateway restart` внутри живой агентной сессии.
- Источник истины для команды — этот репозиторий и обычный контур OpenClaw, а не разрозненные ручные правки в агентных каталогах.
