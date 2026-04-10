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

2. Заполни `.env`:
- ключи LLM и `WORKSPACE_PATH`
- `OWNER_TELEGRAM_ID`
- `*_TELEGRAM_BOT_TOKEN` для всех 7 ботов
- для Manager Flow можно задать `MANAGER_BOT_TOKEN` и `MANAGER_BOT_USERNAME` (рекомендуется)

3. Прогон автозапуска через менеджер-бота:

```bash
bash scripts/bootstrap-managed-team.sh --manager-token=<MANAGER_TOKEN> --manager-username=<manager_bot_username>
```

Скрипт:
- проверит manager bot (`can_manage_bots`)
- покажет/создаст ссылки вида `/newbot/...`
- подтянет токены новых ботов через `getManagedBotToken`
- срендерит конфиги
- развернет воркспейсы
- запустит агентов

Альтернативный ручной путь:

4. Альтернативный ручной путь (если не используешь менеджер):

```bash
source .env
bash scripts/render-openclaw-configs.sh
```

> Важно для сервера: этот проект не обязан использовать глобальные пути `~/.openclaw`.  
> По умолчанию используется:
> - `OPENCLAW_DIR=$HOME/.openclaw-personal`
> - `OPENCLAW_AGENTS_DIR=$HOME/openclaw-agents-personal`
>
> Если у тебя уже работает другой OpenClaw на том же сервере, эти настройки уберегут тебя от перезаписи.

5. Создай воркспейсы:

```bash
bash scripts/deploy-team.sh
```

6. Запусти команду:

```bash
bash scripts/start-team.sh
```

7. Отправь первое сообщение Оркестратору:

```text
Привет, определи, кто из команды должен сделать landing page
```

## Архитектура общения

- По умолчанию любой запрос идёт в `orchestrator`.
- Прямой чат с любым агентным ботом разрешён для профильной работы.
- Межагентная маршрутизация идёт централизованно, через `sessions_send`.

Для безопасности добавлен контроль циклов и дедупликация/таймауты в правилах бота.
