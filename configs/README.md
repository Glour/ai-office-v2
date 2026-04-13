# Agent Team Config Examples

В этой папке лежат только шаблоны конфигов OpenClaw.

## Файлы

| Файл | Агент | Модель |
|------|-------|--------|
| `orchestrator.openclaw.json.example` | orchestrator | `gpt-5.4` |
| `frontend.openclaw.json.example` | frontend | `gpt-5.4` |
| `backend.openclaw.json.example` | backend | `gpt-5.4` |
| `design.openclaw.json.example` | design | `gpt-5.4` |
| `content.openclaw.json.example` | content | `gpt-5.4` |
| `media.openclaw.json.example` | media | `gpt-5.4` |
| `research.openclaw.json.example` | research | `gpt-5.4` |

### Что внутри шаблонов

- отдельные `sessionKey` для каждого агента
- дефолтные `thinkingDefault=high` и `reasoningDefault=on`
- изоляция воркспейсов: `{{WORKSPACE_PATH}}/<agent>`
- отключение циклов и дефолтный heartbeat
- маршрутизация через `sessions_send`

## Применение

Лучший путь — через `scripts/render-openclaw-configs.sh`, который читает `.env` и сразу пишет готовые конфиги в `~/.openclaw/agents/<agent>/openclaw.json`.

Альтернатива вручную:

```bash
cp configs/orchestrator.openclaw.json.example ~/.openclaw/agents/orchestrator/openclaw.json
```
