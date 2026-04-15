# TOOLS.md - Orchestrator

## Team Communication

### Fast inline specialist reply
Используй для быстрых одношаговых задач, когда current turn ещё открыт и нужен ответ сразу.

- Producer -> `sessions_send(sessionKey="agent:producer:main", message="...", timeoutSeconds=120)`
- Frontend -> `sessions_send(sessionKey="agent:frontend:main", message="...", timeoutSeconds=120)`
- Backend -> `sessions_send(sessionKey="agent:backend:main", message="...", timeoutSeconds=120)`
- Tester -> `sessions_send(sessionKey="agent:tester:main", message="...", timeoutSeconds=120)`
- Design -> `sessions_send(sessionKey="agent:design:main", message="...", timeoutSeconds=120)`
- Content -> `sessions_send(sessionKey="agent:content:main", message="...", timeoutSeconds=120)`
- Media -> `sessions_send(sessionKey="agent:media:main", message="...", timeoutSeconds=120)`
- Research -> `sessions_send(sessionKey="agent:research:main", message="...", timeoutSeconds=120)`
- Admin -> `sessions_send(sessionKey="agent:admin:main", message="...", timeoutSeconds=120)`

### Durable async owner-return
Используй для user-facing задач, которые не стоит держать в foreground. Это completion-capable path с возвратом результата в requester thread.

- Frontend async -> `sessions_spawn(agentId="frontend", task="...", label="frontend-async", cleanup="keep")`
- Backend async -> `sessions_spawn(agentId="backend", task="...", label="backend-async", cleanup="keep")`
- Design async -> `sessions_spawn(agentId="design", task="...", label="design-async", cleanup="keep")`
- Research async -> `sessions_spawn(agentId="research", task="...", label="research-async", cleanup="keep")`

## Routing Rule

- `sessions_send` использовать только для внутренних `main`-сессий агентов.
- Не отправлять через `sessions_send` в Telegram label, topic label или псевдо-сессию topic.
- Прямой ответ профильного агента в его topic появляется только когда сообщение пришло в этот topic напрямую из Telegram.
- `sessions_send(..., timeoutSeconds=0)` не использовать как user-facing async return flow. Это не completion path.
- Если нужен гарантированный async возврат результата без ручного пинга пользователя, использовать `sessions_spawn(agentId="...")` или вести работу через `producer`.
- Recurring cron в пользовательский тред для owner-return не использовать.

## Constitution
Read `references/team-constitution.md` first - it's the single source of truth.

## Rules
- Delegate complex multi-agent tasks through `producer`
- Delegate QA and security checks through `tester`
- Delegate finance/admin/docs through `admin`
- Simple questions - answer directly
- File delivery - always through proper channels
- Async user-facing delivery - through completion-capable path, not fire-and-forget
