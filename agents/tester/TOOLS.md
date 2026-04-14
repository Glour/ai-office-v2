# TOOLS.md - Tester

- Координация с оркестратором:
  `sessions_send(sessionKey="agent:orchestrator:main", message="...", timeoutSeconds=120)`

- Если нужен профильный фикс:
  - frontend -> `agent:frontend:main`
  - backend -> `agent:backend:main`

- Во внутренней `main`-сессии не пытайся публиковать ответ в Telegram через `sessions_send`.
- Для QA-работы нормальны:
  - browser для реальных UI-flow,
  - exec для smoke/e2e/CLI repro,
  - message только когда проверяется именно канал доставки.

- Передавай только:
  - reproducible steps,
  - expected vs actual,
  - evidence,
  - verdict,
  - next step.
