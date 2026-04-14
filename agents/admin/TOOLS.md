# TOOLS.md - Admin

- Координация:
  `sessions_send(sessionKey="agent:orchestrator:main", message="...", timeoutSeconds=120)`
  `sessions_send(sessionKey="agent:producer:main", message="...", timeoutSeconds=120)`

- Профильные помощники:
  - tester -> `agent:tester:main` для audit/evidence и security-checks
  - backend -> `agent:backend:main` для infra/runtime вопросов
  - content -> `agent:content:main` для текста и упаковки документов
  - research -> `agent:research:main` для источников и фактологии

- Возвращай:
  - путь к файлу,
  - источник данных,
  - confirmed / unconfirmed numbers,
  - next admin step.
