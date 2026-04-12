# Personal AI Team (Alex)

Клон шаблона с 7 персональными агентами. Идентификаторы и имена задаются через один файл: `team-config.sh`.

По умолчанию идентификаторы:
- `orchestrator`, `frontend`, `backend`, `design`, `content`, `media`, `research`

`TEAM_AGENT_IDS` + `TEAM_AGENT_NAMES` в `team-config.sh` используются всеми управленческими скриптами:
- `scripts/render-openclaw-configs.sh`
- `scripts/deploy-team.sh`
- `scripts/start-team.sh`
- `scripts/stop-team.sh`
- `scripts/sync-agent-references.sh`
- `scripts/agent-usage-tracker.sh`
- `scripts/agent-health-check.sh`
- `scripts/smoke-test.sh`

Переименовываешь в `team-config.sh` — ничего больше менять не нужно.

## Быстрый запуск

1. Подготовь `.env`:

```bash
cp .env.example .env
```

2. Выбери режим авторизации:
- через подписку Codex/OpenAI: ничего не вставляй в `ANTHROPIC_API_KEY`, можно явно задать `OPENCLAW_AUTH_CHOICE=openai-codex`
- через API key: заполни `ANTHROPIC_API_KEY` или `OPENAI_API_KEY`
- для Telegram-режима позже добавь `OWNER_TELEGRAM_ID` и `*_TELEGRAM_BOT_TOKEN`

3. Разверни воркспейсы:

```bash
bash scripts/deploy-team.sh
```

4. Инициализируй профиль OpenClaw `personal`, разложи agent dirs и зарегистрируй всех 7 агентов:

```bash
bash scripts/setup.sh
```

Что делает `setup.sh` на актуальном OpenClaw:
- создаёт профиль `personal` через `openclaw --profile personal onboard`
- если выбран `OPENCLAW_AUTH_CHOICE=openai-codex`, ведёт в Sign in with ChatGPT вместо требования API key
- копирует markdown-инструкции агентов в `~/.openclaw-personal/agents/<agent>/agent`
- рендерит agent configs
- ставит skills оркестратору
- регистрирует `orchestrator/frontend/backend/design/content/media/research` как isolated agents

5. Запусти общий gateway для профиля:

```bash
bash scripts/start-team.sh
```

6. Проверь статус:

```bash
openclaw --profile personal status
openclaw --profile personal agents list
```

7. Локальный smoke test без Telegram:

```bash
openclaw --profile personal agent --agent orchestrator --local --message "Привет, кто из команды должен сделать landing page?"
```

Если используешь подписку Codex/OpenAI, а раньше входил через API key, сначала перелогинься в клиенте Codex/OpenAI и пройди subscription-based auth.

8. Остановить gateway:

```bash
bash scripts/stop-team.sh
```

> Важно: на OpenClaw `2026.x` больше нельзя рассчитывать на старый сценарий `openclaw gateway start` без установленного system service.  
> Для локального теста этот репозиторий теперь использует профиль `personal` и foreground gateway, запущенный в фоне через `scripts/start-team.sh`.

## Архитектура общения

- По умолчанию любой запрос идёт в `orchestrator`.
- Прямой чат с любым агентным ботом разрешён для профильной работы.
- Межагентная маршрутизация идёт централизованно, через `sessions_send`.

Для безопасности добавлен контроль циклов и дедупликация/таймауты в правилах бота.
