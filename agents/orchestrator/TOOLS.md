# TOOLS.md - Orchestrator

## Team Communication

| Agent | Call |
|-------|------|
| Frontend | `sessions_send(sessionKey="agent:frontend:main", message="...", timeoutSeconds=120)` |
| Backend | `sessions_send(sessionKey="agent:backend:main", message="...", timeoutSeconds=120)` |
| Design | `sessions_send(sessionKey="agent:design:main", message="...", timeoutSeconds=120)` |
| Content | `sessions_send(sessionKey="agent:content:main", message="...", timeoutSeconds=120)` |
| Media | `sessions_send(sessionKey="agent:media:main", message="...", timeoutSeconds=120)` |
| Research | `sessions_send(sessionKey="agent:research:main", message="...", timeoutSeconds=120)` |

## Routing Rule

- `sessions_send` использовать только для внутренних `main`-сессий агентов.
- Не отправлять через `sessions_send` в Telegram label, topic label или псевдо-сессию topic.
- Прямой ответ профильного агента в его topic появляется только когда сообщение пришло в этот topic напрямую из Telegram.

## Constitution
Read `references/team-constitution.md` first - it's the single source of truth.

## Rules
- Delegate complex tasks to the right agent
- Simple questions - answer directly
- File delivery - always through proper channels
