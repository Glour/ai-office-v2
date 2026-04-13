# Agent Team

Репозиторий для изолированной команды OpenClaw-агентов: `orchestrator`, `frontend`, `backend`, `design`, `content`, `media`, `research`.

Текущее базовое состояние:
- профиль OpenClaw: `personal`
- дефолтная модель: `gpt-5.4`
- дефолтный thinking: `high`
- дефолтный reasoning: `on`
- межагентная маршрутизация: `sessions_send`
- Telegram-группа и топики: опционально, но поддерживаются штатно

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

4. Инициализируй профиль `personal`, срендери конфиги и зарегистрируй агентов:

```bash
bash scripts/setup.sh
```

5. Подними общий gateway:

```bash
bash scripts/start-team.sh
```

6. Проверь состояние:

```bash
openclaw --profile personal status
openclaw --profile personal agents list
bash scripts/smoke-test.sh
```

## Telegram-режим

Если команда живёт в Telegram-группе с топиками, добавь в `.env`:

```bash
TEAM_TELEGRAM_GROUP_ID=-100...
ORCHESTRATOR_TOPIC_ID=1
FRONTEND_TOPIC_ID=13
BACKEND_TOPIC_ID=12
DESIGN_TOPIC_ID=16
CONTENT_TOPIC_ID=15
MEDIA_TOPIC_ID=17
RESEARCH_TOPIC_ID=14
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
- прямой запрос в конкретный топик агенту тоже допустим
- делегирование между агентами идёт через `sessions_send`, а не через хаотичную пересылку сообщений

## Операционный контур

Основные скрипты:
- `scripts/deploy-team.sh` — создаёт/обновляет workspaces агентов
- `scripts/render-openclaw-configs.sh` — рендерит `openclaw.json` из шаблонов
- `scripts/setup.sh` — регистрирует команду в профиле `personal`
- `scripts/start-team.sh` — поднимает gateway
- `scripts/stop-team.sh` — останавливает gateway
- `scripts/configure-telegram-topics.sh` — включает topic routing
- `scripts/send-team-topic.sh` — отправляет сообщение прямо в топик агента
- `scripts/smoke-test.sh` — быстрый контроль репозитория и установки

## Важно

- Не рассчитывай на старый сценарий `openclaw gateway start` «вручную из головы» без нормального профиля и service install.
- Не используй `openclaw gateway restart` внутри живой агентной сессии.
- Источник истины для команды — этот репозиторий и профиль `personal`, а не разрозненные ручные правки в агентных каталогах.
