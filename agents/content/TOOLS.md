# TOOLS.md - Content

- Координация:
  `sessions_send(sessionKey="agent:producer:main", message="...", timeoutSeconds=120)`

- Эскалация в user-facing слой:
  `sessions_send(sessionKey="agent:orchestrator:main", message="...", timeoutSeconds=120)`

- Для фактов/доказательств:
  `sessions_send(sessionKey="agent:research:main", message="...", timeoutSeconds=120)`

- Результат:
  - текстовый черновик,
  - формат публикации,
  - ключевые ограничения.
