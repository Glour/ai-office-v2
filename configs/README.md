# Personal Team Config Examples

В этой папке лежат только шаблоны конфигов OpenClaw.

## Файлы

| Файл | Агент | Модель |
|------|-------|--------|
| `orchestrator.openclaw.json.example` | orchestrator | claude-opus-4-5 |
| `frontend.openclaw.json.example` | frontend | claude-sonnet-4-5 |
| `backend.openclaw.json.example` | backend | claude-sonnet-4-5 |
| `design.openclaw.json.example` | design | claude-sonnet-4-5 |
| `content.openclaw.json.example` | content | claude-sonnet-4-5 |
| `media.openclaw.json.example` | media | claude-sonnet-4-5 |
| `research.openclaw.json.example` | research | claude-sonnet-4-5 |

### Что внутри шаблонов

- отдельные `sessionKey` для каждого агента
- изоляция воркспейсов: `{{WORKSPACE_PATH}}/<agent>`
- отключение циклов и дефолтный heartbeat
- маршрутизация через `sessions_send`

## Применение

Лучший путь — через скрипт `scripts/render-openclaw-configs.sh`, который читает `.env` и сразу пишет готовые конфиги в `~/.openclaw/agents/<agent>/openclaw.json`.

Альтернатива вручную:

```bash
cp configs/orchestrator.openclaw.json.example ~/.openclaw/agents/orchestrator/openclaw.json
```
